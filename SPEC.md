# GlazerAI — Software Requirements Specification

**Version:** 4.0.0
**Date:** 2026-03-23
**Status:** Living Document — update on every new requirement

---

## 1. Overview

| Field | Value |
|---|---|
| App name | GlazerAI |
| Purpose | macOS menu bar utility that captures a LinkedIn profile screenshot, extracts text via OCR, researches the person via Claude CLI (with web search), and generates a personalised ≤300-char connection note |
| Target platform | macOS 15.0+ (Sequoia) |
| Language | Swift 6 strict concurrency |
| UI framework | AppKit (menu bar, overlay) + SwiftUI (all windows) |
| Architecture | Coordinator pattern — `AppCoordinator` owns all subsystems, wires them via protocol delegates |
| Persistence | SQLite via GRDB.swift — `~/Library/Application Support/GlazerAI/glazes.db` |
| Distribution | Local build / direct install (no App Store in v1) |

---

## 2. Pipeline

```
Snip → OCR → Prompt Assembly → claude -p (stdin) → JSON Parse → Results Window → SQLite
```

1. User left-clicks menu bar icon (requires resume uploaded; prompts if not)
2. Full-screen snipping overlay with crosshair cursor
3. `ScreenCaptureService` captures selected region → PNG `Data`
4. `OCRService` extracts text via Vision framework; throws `OCRError.noTextFound` if blank
5. `PromptAssembler` builds a research + ice-breaker prompt including sender's resume
6. `ClaudeRunner` invokes `claude -p --output-format json --allowedTools web_search` via stdin
7. Claude researches the person (web search), extracts profile fields, generates ice-breaker note
8. Response parsed from JSON envelope → `ClaudeResponse`
9. `ResultsWindowController` shows results; on success, record saved to SQLite
10. User can optionally paste a job description to regenerate a targeted note

---

## 3. Features

### 3.1 Menu Bar Presence
- Runs as a menu bar agent (`LSUIElement = YES`); no Dock icon.
- Left-click → activate snipping (or show "upload resume" alert if not configured).
- Right-click → context menu: **History…**, **Settings…**, separator, **Quit GlazerAI**.

### 3.2 Candidate Profile (Settings → Profile tab)
- User uploads a resume PDF via drag-and-drop or file browser.
- PDFKit extracts text from all pages.
- Stored in `UserDefaults` as JSON-encoded `CandidateProfile { name, resumeText }`.
- `isConfigured` = `!resumeText.isEmpty`.
- If not configured when capture is triggered: modal alert with **Open Settings** / **Cancel**.
- If already showing that alert and icon clicked again: focuses settings window instead of stacking.

### 3.3 Snipping Overlay
- Full-screen `SnippingWindow` (custom `NSWindow` subclass, `canBecomeKey = true`) at screen-saver level.
- `NSApp.activate(ignoringOtherApps: true)` on present to steal focus.
- Crosshair cursor via `NSCursor.crosshair.push()` + `NSTrackingArea`.
- Instruction card overlay ("Drag to select a LinkedIn profile / Press Esc to cancel") shown before drag.
- Click-drag draws selection rect with dimmed overlay (clear hole = selected region).
- Mouse-up → confirms, triggers pipeline.
- Escape → cancels (via `cancelOperation(_:)` override + `NSEvent.addLocalMonitorForEvents`).
- `reset()` called on each presentation to clear previous rect.

### 3.4 Screen Capture
- `SCScreenshotManager.captureImage` (ScreenCaptureKit).
- Excludes the snipping overlay window from capture.
- Retina-aware coordinate conversion (AppKit → ScreenCaptureKit).
- DEBUG builds: copies PNG to clipboard.

### 3.5 OCR
- `VNRecognizeTextRequest`, level `.accurate`, `automaticallyDetectsLanguage = true`.
- Returns joined text observations; throws `OCRError.noTextFound` if empty → `NSAlert`.

### 3.6 Prompt Assembly
- `PromptAssembler` with two templates:
  - **Default** (`defaultTemplate`): full research + ice-breaker prompt using `{ocr_text}` + `{candidate_profile}`. Instructs Claude to extract profile, web-search the person, generate ≤300-char note, return strict JSON.
  - **Refinement** (`iceBreakerRefinementTemplate`): focused prompt using `{profile_summary}` + `{candidate_profile}` + `{job_description}`. Regenerates only the ice-breaker note. Returns minimal JSON `{"status","iceBreakerNote","message"}`.

### 3.7 Claude CLI Invocation
- `ClaudeRunner` actor wraps `Process` / `Foundation.Pipe`.
- Prompt written to **stdin**; process launched via `/bin/zsh -l -c`.
- Command: `claude -p --output-format json --allowedTools web_search`
- 120-second timeout (web search requires more time than plain inference).
- `ClaudeOutputEnvelope { is_error, result, usage { input_tokens, output_tokens } }` parsed from stdout JSON.
- On success: token counts forwarded to `SessionUsage.shared`.
- On `is_error: true`: throws `ClaudeError.executionFailed`.

### 3.8 Response Parsing
- `ClaudeResponse` Codable schema:
  ```
  { status, profile, research, iceBreakerNote, summary, message }
  ```
- `status`: `"success"` or `"no_profile_found"`.
- `profile`: `{ name, headline, company, location, connections, about, experience[], education[], skills[] }`.
- `research`: `{ recentActivity[], publications[], companyContext, conversationAngles[] }`.
- `ClaudeResponse.parse(from:)` strips markdown fences before decoding.

### 3.9 Results Window
- Shows: snip thumbnail, collapsible OCR text, ice-breaker card (char counter, Copy Note), profile fields, research, summary.
- **Tailor to Job** section: optional TextEditor + "Regenerate Note" button. Triggers `assembleRefinement` + re-run → patches the displayed note and updates the DB record.
- On `no_profile_found`: closes results window, shows `NSAlert`.
- Each snip opens a new results window (windows stack).

### 3.10 History
- Right-click → **History…** opens `HistoryWindowController`.
- `NavigationSplitView`: sidebar lists glazes (name, company, date) with `.searchable` filter by name/company/headline.
- Sidebar reloads on `NSWindow.didBecomeKeyNotification`.
- Detail panel shows: ice-breaker card, tailored note (if present, with job description), profile summary, research bullets, delete button.

### 3.11 SQLite Persistence (`GlazeStore`)
- Database: `~/Library/Application Support/GlazerAI/glazes.db`.
- `GlazeRecord` schema:

| Column | Type | Notes |
|---|---|---|
| `id` | INTEGER PK | auto-increment |
| `createdAt` | DATETIME | pipeline completion time |
| `name` | TEXT | from profile |
| `headline` | TEXT | from profile |
| `company` | TEXT | from profile |
| `location` | TEXT | from profile |
| `iceBreakerNote` | TEXT | generated note |
| `summary` | TEXT | 2-3 sentence narrative |
| `ocrText` | TEXT | raw OCR input |
| `researchJSON` | TEXT | `ResearchData` as JSON blob |
| `imageData` | BLOB | PNG screenshot |
| `jobDescription` | TEXT | optional, from Tailor section |
| `tailoredNote` | TEXT | regenerated note with JD |

- Migrations: `v1_create_glazes`, `v2_add_job_description`.
- Methods: `insert(_:)`, `update(_:)`, `delete(id:)`, `fetchAll()`.

### 3.12 Settings Window
- Two tabs:
  - **Profile** — name field + resume PDF upload (drag-and-drop or browse).
  - **Usage** — session token stats (glazes, input tokens, output tokens, total). Resets on app restart.
- Save disabled until name + resumeText both non-empty.
- `SettingsWindowController` lazy-init (singleton per session).

### 3.13 Token Tracking (`SessionUsage`)
- `@MainActor @Observable` singleton.
- `record(inputTokens:outputTokens:)` is `nonisolated` — callable from `ClaudeRunner` actor.
- Counts: `glazeCount`, `inputTokens`, `outputTokens`, `totalTokens`.
- Displayed in Settings → Usage tab.

### 3.14 Debug Console
- `--debug` launch flag: `./scripts/launch.sh --debug`
- Enables `DebugLogger.shared.isEnabled = true` and opens `DebugConsoleWindowController`.
- Floating monospaced window with timestamp / tag / message columns.
- Filter bar (text search + tag picker), Clear button, auto-scroll to latest.
- Tags: `GlazerAI`, `Claude` (prompt/response text), `CLI`, `OCR`, `DB`, `Error`, `Debug`, `App`.
- All `print(...)` calls replaced with `debugLog(_:tag:)` throughout codebase.

### 3.15 Claude CLI Check
- On launch: `which claude` via interactive login shell; fallbacks to well-known paths.
- Not found → `NSAlert` with **Install** button → `https://claude.ai/download` → `NSApp.terminate`.
- Found → `claude auth status --json` → parses `{ loggedIn, email, subscriptionType }`.
- Not logged in → `NSAlert` warning (non-fatal, proceeds).
- Path cached in `CLIEnvironment.shared.claudePath`.

### 3.16 Screen Recording Permission
- On launch: briefly sets activation policy to `.regular`, calls `SCShareableContent.current` to trigger TCC prompt, then reverts to `.accessory`.

---

## 4. Error Handling

| Error | Handling |
|---|---|
| Resume not configured | Modal alert "Upload Your Resume First" + Open Settings button |
| Screen capture permission denied | `NSAlert` with instructions |
| claude CLI not found | `NSAlert` + Install button + `NSApp.terminate` |
| claude not authenticated | `NSAlert` warning (non-fatal) |
| claude timeout (120s) | `ClaudeError.timeout` → pipeline error alert |
| claude non-zero exit | stderr content in alert |
| OCR no text found | `NSAlert` before results window opens |
| `no_profile_found` JSON status | Close results window + `NSAlert` |
| DB write failure | Logged via `debugLog`, not shown to user |

---

## 5. Data Flow

```
User (left-click icon)
        │
        ▼
AppCoordinator.startCapture()
        │  guard candidateProfile.isConfigured
        ▼
SnippingWindowController.present()
        │  (user drags rect, releases mouse)
        ▼
ScreenCaptureService.capture(rect:) → Data (PNG)
        │
        ▼
OCRService.recognizeText(in:) → String
        │  throws OCRError.noTextFound → NSAlert
        ▼
ResultsWindowController.show()   ← opens immediately with spinner
        │
        ▼
PromptAssembler.assemble(ocrText:candidateProfile:) → String
        │
        ▼
ClaudeRunner.run(prompt:) → String   [stdin, 120s timeout, web_search]
        │  → ClaudeOutputEnvelope → SessionUsage.record(tokens)
        ▼
ClaudeResponse.parse(from:) → ClaudeResponse
        │  no_profile_found → close results + NSAlert
        │  success →
        ▼
ResultsWindowController update + GlazeStore.insert()

Optional refinement:
User pastes JD → "Regenerate Note" →
PromptAssembler.assembleRefinement(...) →
ClaudeRunner.run(...) →
vm.applyRefinedNote(_:) + GlazeStore.update(_:)
```

---

## 6. File & Folder Structure

```
GlazerAI/
├── GlazerAI.xcodeproj/
├── GlazerAI/
│   ├── App/
│   │   ├── GlazerAIApp.swift            # @main, AppDelegate, --debug flag detection
│   │   └── AppCoordinator.swift         # Owns and wires all subsystems
│   ├── MenuBar/
│   │   └── MenuBarController.swift      # NSStatusItem; left=snip, right=context menu
│   ├── Snipping/
│   │   ├── SnippingWindowController.swift
│   │   └── SnippingView.swift
│   ├── Capture/
│   │   └── ScreenCaptureService.swift
│   ├── OCR/
│   │   └── OCRService.swift
│   ├── Prompt/
│   │   └── PromptAssembler.swift        # defaultTemplate + iceBreakerRefinementTemplate
│   ├── CLI/
│   │   ├── CLIEnvironment.swift
│   │   ├── ClaudeRunner.swift           # stdin prompt, envelope parse, token tracking
│   │   └── ClaudeResponse.swift         # Codable JSON schema
│   ├── Results/
│   │   ├── ResultsWindowController.swift
│   │   ├── ResultsView.swift            # ice-breaker card + Tailor to Job section
│   │   └── ResultsViewModel.swift       # ResultsViewModelDelegate protocol
│   ├── History/
│   │   ├── GlazeRecord.swift            # GRDB FetchableRecord + MutablePersistableRecord
│   │   ├── GlazeStore.swift             # Repository (insert/update/delete/fetchAll)
│   │   └── HistoryWindowController.swift # NavigationSplitView with search
│   ├── Settings/
│   │   ├── SettingsWindowController.swift
│   │   ├── SettingsView.swift           # TabView: Profile + Usage tabs
│   │   ├── UsageView.swift              # Session token stats grid
│   │   ├── CandidateProfile.swift
│   │   └── ShortcutRecorderView.swift   # (unused, kept for future)
│   ├── Debug/
│   │   ├── DebugLogger.swift            # ObservableObject singleton + debugLog()
│   │   └── DebugConsoleWindowController.swift
│   ├── Support/
│   │   ├── Constants.swift
│   │   └── SessionUsage.swift           # @Observable token counter
│   ├── Backend/
│   │   ├── AIBackendService.swift       # (kept for testing)
│   │   └── MockAIBackendService.swift
│   ├── Hotkey/
│   │   └── GlobalHotkeyManager.swift    # (disabled, not wired)
│   └── Resources/
│       ├── Assets.xcassets/
│       └── Info.plist
├── GlazerAITests/
├── scripts/
│   ├── launch.sh        # --debug and --reset flags supported
│   ├── lint.sh
│   ├── test.sh
│   ├── build.sh
│   └── ci.sh
├── project.yml          # xcodegen; includes GRDB SPM package
├── .swiftlint.yml
└── SPEC.md
```

---

## 7. Build & Run

### Prerequisites
- macOS 15.0+ (Sequoia)
- Xcode 16+, Swift 6
- SwiftLint (`brew install swiftlint`)
- xcodegen (`brew install xcodegen`) — only needed when modifying `project.yml`
- `claude` CLI installed and authenticated

### Launch
```bash
./scripts/launch.sh           # normal
./scripts/launch.sh --debug   # with floating debug console
./scripts/launch.sh --reset   # wipe TCC permissions + launch
```

### CLI
```bash
make ci       # lint → test → build
make build
make test
make lint
```

### xcodegen Note
`xcodegen generate` wipes three Info.plist keys. Always restore after regenerating:
- `CFBundleDisplayName` = `GlazerAI`
- `LSUIElement` = `<true/>`
- `NSScreenCaptureUsageDescription` = `GlazerAI needs Screen Recording permission to capture the selected screen region.`

---

## 8. Testing

| Test file | What is tested |
|---|---|
| `RectCalculationTests` | Rectangle normalisation, small-rect rejection |
| `CoordinateConversionTests` | AppKit → CG coordinate conversion |
| `OCRServiceTests` | Text extraction, empty-result error |
| `PromptAssemblerTests` | Placeholder substitution (ocrText + candidateProfile) |
| `ClaudeRunnerTests` | notFound error, timeout message, executionFailed |
| `ClaudeResponseTests` | JSON parsing, no_profile_found status |
| `ResultsViewModelTests` | State transitions (loading → success → error) |
| `MockAIBackendServiceTests` | Empty-payload error, success byte count |
| `IntegrationSmokeTest` | Pipeline smoke test with mocked dependencies |

Target coverage: ≥ 80% of non-UI source lines.

---

## 9. Linting

`.swiftlint.yml` rules:

| Rule | Threshold |
|---|---|
| `force_cast` | error |
| `force_try` | error |
| `implicitly_unwrapped_optional` | warning |
| `line_length` | warning 120, error 200 |
| `file_length` | warning 400, error 800 |
| `function_body_length` | warning 40, error 60 |
| `cyclomatic_complexity` | warning 10, error 20 |
| `identifier_name` excluded | `db`, `id`, `vm`, `jd`, `n` |

---

## 10. Open Items / Future Work

- Re-enable global keyboard shortcut with Accessibility permission handling.
- Streaming Claude output to results window (progressive rendering).
- Multi-monitor snipping overlay.
- Export history to CSV / JSON.
- Sandboxing / App Store distribution.
- Persist token usage across sessions (currently resets on restart).
- Annotation tools (arrows, blur) before capture.
