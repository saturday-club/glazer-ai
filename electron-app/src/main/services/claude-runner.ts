import { execFile } from 'child_process';
import { promisify } from 'util';
import { resolve as resolvePath } from 'path';

const execFileAsync = promisify(execFile);

/** JSON envelope that `claude -p --output-format json` returns. */
interface ClaudeOutputEnvelope {
  is_error: boolean;
  result: string;
  usage?: {
    input_tokens: number;
    output_tokens: number;
  };
}

/** Timeout for the claude process in milliseconds. */
const TIMEOUT_MS = 120_000;

/**
 * Resolves the path to the `claude` CLI binary.
 * Checks common install locations, then falls back to PATH.
 */
export function findClaudePath(): string | null {
  const candidates = [
    resolvePath(process.env.HOME || '~', '.local', 'bin', 'claude'),
    '/usr/local/bin/claude',
    '/opt/homebrew/bin/claude',
  ];

  // On Windows, check AppData
  if (process.platform === 'win32') {
    const appData = process.env.LOCALAPPDATA || '';
    if (appData) {
      candidates.push(resolvePath(appData, 'Programs', 'claude', 'claude.exe'));
    }
    candidates.push('claude.exe');
  }

  // Try each candidate
  const { execFileSync } = require('child_process');
  for (const candidate of candidates) {
    try {
      execFileSync(candidate, ['--version'], { timeout: 5000, stdio: 'pipe' });
      return candidate;
    } catch {
      // Not found at this path, try next.
    }
  }

  // Fall back to `which` / `where`
  try {
    const cmd = process.platform === 'win32' ? 'where' : 'which';
    const result = execFileSync(cmd, ['claude'], { timeout: 5000, stdio: 'pipe' });
    const path = result.toString().trim().split('\n')[0];
    if (path) return path;
  } catch {
    // Not on PATH.
  }

  return null;
}

/**
 * Runs `claude -p --output-format json --allowedTools web_search` with
 * the prompt piped via stdin. Returns the result text from the JSON envelope.
 *
 * Mirrors the Swift ClaudeRunner exactly.
 */
export async function runClaude(prompt: string): Promise<string> {
  const claudePath = findClaudePath();
  if (!claudePath) {
    throw new Error(
      'Claude CLI not found. Install it from https://claude.ai/download'
    );
  }

  // Use a shell to invoke claude so it picks up the user's login environment.
  const shell = process.platform === 'win32' ? 'cmd.exe' : '/bin/zsh';
  const shellArgs =
    process.platform === 'win32'
      ? ['/c', `"${claudePath}" -p --output-format json --allowedTools web_search`]
      : ['-l', '-c', `${claudePath} -p --output-format json --allowedTools web_search`];

  return new Promise<string>((resolve, reject) => {
    const { spawn } = require('child_process');
    const proc = spawn(shell, shellArgs, {
      timeout: TIMEOUT_MS,
      stdio: ['pipe', 'pipe', 'pipe'],
      env: { ...process.env },
    });

    let stdout = '';
    let stderr = '';

    proc.stdout.on('data', (data: Buffer) => {
      stdout += data.toString();
    });

    proc.stderr.on('data', (data: Buffer) => {
      stderr += data.toString();
    });

    proc.on('error', (err: Error) => {
      reject(new Error(`Failed to start Claude CLI: ${err.message}`));
    });

    proc.on('close', (code: number | null, signal: string | null) => {
      if (signal === 'SIGTERM' || signal === 'SIGKILL') {
        reject(new Error('Claude CLI did not respond within 120 seconds.'));
        return;
      }

      if (code !== 0) {
        reject(
          new Error(`Claude CLI failed: ${stderr || 'Unknown error'}`)
        );
        return;
      }

      try {
        const result = extractResult(stdout);
        resolve(result);
      } catch (err) {
        reject(err);
      }
    });

    // Write prompt to stdin, then close to signal EOF.
    proc.stdin.write(prompt);
    proc.stdin.end();
  });
}

/**
 * Decodes the JSON envelope and returns the result field.
 * Falls back to raw output if the envelope is not parseable.
 */
function extractResult(envelopeJSON: string): string {
  const trimmed = envelopeJSON.trim();

  let envelope: ClaudeOutputEnvelope;
  try {
    envelope = JSON.parse(trimmed);
  } catch {
    // Envelope not parseable, return raw text.
    return trimmed;
  }

  if (envelope.is_error) {
    throw new Error(`Claude CLI error: ${envelope.result}`);
  }

  return envelope.result;
}
