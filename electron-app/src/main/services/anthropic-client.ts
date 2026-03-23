import Anthropic from '@anthropic-ai/sdk';
import { Constants } from '../config/constants';

interface QueryOptions {
  apiKey: string;
  model?: string;
  maxTokens?: number;
  timeoutMs?: number;
}

function createClient(apiKey: string): Anthropic {
  return new Anthropic({ apiKey });
}

/**
 * Sends a text prompt to Claude and returns the response.
 */
export async function queryWithText(
  prompt: string,
  opts: QueryOptions
): Promise<string> {
  const client = createClient(opts.apiKey);
  const model = opts.model ?? Constants.anthropic.defaultModel;
  const maxTokens = opts.maxTokens ?? Constants.anthropic.maxTokens;

  const response = await client.messages.create({
    model,
    max_tokens: maxTokens,
    messages: [{ role: 'user', content: prompt }],
  });

  const textBlock = response.content.find((b) => b.type === 'text');
  if (!textBlock || textBlock.type !== 'text') {
    throw new Error('No text response received from Claude.');
  }
  return textBlock.text;
}

/**
 * Sends an image (base64 PNG) with a text prompt to Claude using vision.
 */
export async function queryWithVision(
  imageBase64: string,
  prompt: string,
  opts: QueryOptions
): Promise<string> {
  const client = createClient(opts.apiKey);
  const model = opts.model ?? Constants.anthropic.defaultModel;
  const maxTokens = opts.maxTokens ?? Constants.anthropic.maxTokens;

  const response = await client.messages.create({
    model,
    max_tokens: maxTokens,
    messages: [
      {
        role: 'user',
        content: [
          {
            type: 'image',
            source: {
              type: 'base64',
              media_type: 'image/png',
              data: imageBase64,
            },
          },
          { type: 'text', text: prompt },
        ],
      },
    ],
  });

  const textBlock = response.content.find((b) => b.type === 'text');
  if (!textBlock || textBlock.type !== 'text') {
    throw new Error('No text response received from Claude.');
  }
  return textBlock.text;
}
