# Glazer AI — Software Requirements Specification

**Version:** 3.0.0
**Date:** 2026-03-21
**Status:** Living Document — update on every new requirement

---

## 1. Overview

| Field | Value |
|---|---|
| App name | Glazer AI |
| Purpose | macOS menu bar utility that captures a user-defined screen region, extracts text via OCR, and pipes the result through the `claude -p` CLI to produce AI-powered research output |
| Target platform | macOS 15.0+ (Sequoia) |
| Language | Swift 6 strict concurrency |
| UI framework | AppKit (menu bar, overlay, results window) + SwiftUI (results view) |
| Architecture | Coordinator pattern — `AppCoordinator` owns all major subsystems and wires them together via protocol-based dependency injection |
| Distribution | Local build / direct install (no App Store in v1) |

---

## 2. Pipeline

```
Snip → OCR → Prompt Assembly → claude -p CLI → Results Window
```

1. User triggers capture via menu bar item (or future keyboard shortcut)
2. Full-screen snipping overlay captures a rectangular region
3. `ScreenCaptureService` produces a PNG `Data` blob
4. `OCRService` extracts text from the image using Vision framework
5. `PromptAssembler` wraps OCR text in a research prompt template
6. `ClaudeRunner` invokes `claude -p "<prompt>"` and captures stdout
7. `ResultsWindowController` displays the snip thumbnail, OCR text, and Claude response

---

## 3. Features

### 3.1 Menu Bar Presence
- The app runs exclusively as a menu bar agent (`LSUIElement = YES`); no Dock icon, no app switcher entry.
- A single `NSStatusItem` is created at launch and persists for the lifetime of the process.
- The status item displays a bundled donut icon (mingcute:donut-line) rendered as a template image (adapts to light/dark menu bar).
- Clicking the status item opens the action menu.

### 3.2 Action Menu

| Item | Action |
|---|---|
| **Capture Region** | Activates the snipping overlay |
| *(separator)* | — |
| **Quit Glazer AI** | Terminates the process |

### 3.3 Permission Handling
- **Screen Recording:** On launch, the app briefly sets activation policy to `.regular` and calls `SCShareableContent.current` (ScreenCaptureKit) to register with TCC and trigger the native macOS permission dialog. This is necessary because LSUIElement (background) apps have TCC dialogs suppressed. The policy reverts to `.accessory` after the prompt completes.
- **Preflight check:** Before every capture, `CGPreflightScreenCaptureAccess()` is called. If permission has been revoked, a clear error message is shown instead of silently returning blank content.

### 3.4 Claude CLI Check
- On launch, the app runs `which claude` via `Process` to verify the CLI is installed.
- If not found: shows `NSAlert` with title **Glazer AI**, message explaining the CLI is required, and an **Install Claude CLI** button that opens `https://claude.ai/download`.
- If found: the resolved path is stored in `CLIEnvironment.shared.claudePath` for use by `ClaudeRunner`.
- The `claude` CLI is assumed to be installed and authenticated on the user's machine. Glazer AI does NOT manage authentication or API keys.

### 3.5 Snipping Overlay
- Full-screen `NSWindow` covering the main screen (multi-monitor in a future release).
- Window level: `NSWindow.Level.screenSaver` so it appears above all normal windows.
- On presentation: screen dims (black fill, 40% opacity) over the entire display.
- Cursor: crosshair (`NSCursor.crosshair`).
- User click-drags to define a rectangular selection:
  - The region inside the drag rect is rendered at full brightness (clear of the dim layer).
  - A 1 pt blue (`#007AFF`) border outlines the selection.
  - A label showing `W × H` (integer pixel dimensions) appears near the bottom-right handle of the rect.
- **Cancel:** `Escape` key dismisses the overlay with no capture.
- **Confirm:** releasing the mouse button (mouse-up) confirms the selection and triggers the pipeline.

### 3.6 Screen Capture
- On confirmation, `SCScreenshotManager.captureImage` (ScreenCaptureKit) captures the selected region.
- The capture excludes the Glazer AI overlay window via `SCContentFilter(display:excludingApplications:)`.
- Coordinate conversion from AppKit screen coordinates (origin bottom-left) to display-local ScreenCaptureKit coordinates (origin top-left) follows the same approach as [ScrollSnap](https://github.com/Brkgng/ScrollSnap).
- Handles Retina (HiDPI) scaling via `filter.pointPixelScale`.
- Output: PNG `Data` blob.
- In DEBUG builds: copies the captured PNG to the system clipboard for visual verification.

### 3.7 OCR (Optical Character Recognition)
- Uses Vision framework `VNRecognizeTextRequest`.
- Recognition level: `.accurate`.
- `automaticallyDetectsLanguage = true`.
- Runs on a background actor (`async`/`await`, Swift 6 concurrency).
- Returns recognised text observations joined by newline.
- Throws `OCRError.noTextFound` if no text is detected (shown via `NSAlert`).

### 3.8 Research Prompt Assembly
- `PromptAssembler` struct with a `static let defaultTemplate` constant.
- Default template:
  ```
  The following text was extracted from a screenshot. Please research this topic thoroughly
  and provide a concise, well-structured summary with key facts and relevant context:

  {ocr_text}
  ```
- `func assemble(ocrText: String) -> String` replaces the `{ocr_text}` placeholder.

### 3.9 Claude CLI Invocation
- `ClaudeRunner` actor wraps `Process` / `Foundation.Pipe`.
- Runs: `claude -p "<assembled prompt>"` using the path from `CLIEnvironment`.
- Captures `stdout` (response text) and `stderr` (error detail).
- 60-second timeout; kills process and throws `ClaudeError.timeout` if exceeded.
- Non-zero exit code throws `ClaudeError.executionFailed(stderr: String)`.
- Entire pipeline is `async throws`.

### 3.10 Results Window
- `ResultsWindowController` (`NSWindowController`) hosting a SwiftUI `ResultsView`.
- Window title: **Glazer AI — Results**.
- Layout:
  - Top: thumbnail of snipped image (max 200pt tall, aspect-fit, rounded corners).
  - Middle (collapsible `DisclosureGroup`): **Extracted Text** — raw OCR output, monospaced, selectable.
  - Bottom (scrollable): **Claude's Response** — full stdout, selectable, monospaced font.
  - Toolbar buttons: **Copy Response** (copies stdout to clipboard), **Close**.
- Each snip opens a new results window (windows stack; user closes manually).
- Shows a `ProgressView` with label "Thinking…" while the pipeline is running.

### 3.11 Debug / Clipboard
- The captured PNG is copied to the macOS clipboard on every snip in DEBUG builds for visual verification.

---

## 4. UI/UX Details

### 4.1 Menu Bar Icon
- Bundled icon: `mingcute:donut-line` (Iconify) rendered as 18×18pt / 36×36px PNG with `template-rendering-intent: template`.
- Fallback: SF Symbol `circle.dashed` if bundled asset is missing.
- Size: 18 × 18 pt, explicitly set on `NSImage.size` to prevent overflow.

### 4.2 Snipping Surface Behaviour
1. Menu item fires → overlay window appears instantly (no animation).
2. User moves mouse → crosshair cursor shown.
3. Mouse-down → anchor point recorded.
4. Mouse-drag → live rect drawn; dim layer has a clear hole matching the rect; blue border and dimension label update in real time.
5. Mouse-up → rect finalised → overlay dismissed → pipeline begins.
6. Escape at any point → overlay dismissed → no capture.

### 4.3 Results Window Layout
```
┌─────────────────────────────────────┐
│  Glazer AI — Results           [×]  │
├─────────────────────────────────────┤
│  ┌─────────────────────────────┐    │
│  │     Snip Thumbnail          │    │
│  │     (max 200pt tall)        │    │
│  └─────────────────────────────┘    │
│                                     │
│  ▶ Extracted Text                   │
│  ┌─────────────────────────────┐    │
│  │ (collapsed OCR text)        │    │
│  └─────────────────────────────┘    │
│                                     │
│  Claude's Response                  │
│  ┌─────────────────────────────┐    │
│  │ (scrollable, monospaced)    │    │
│  │ ...                         │    │
│  └─────────────────────────────┘    │
│                                     │
│  [Copy Response]        [Close]     │
└─────────────────────────────────────┘
```

---

## 5. Keyboard Shortcuts

| Shortcut | Action | Configurable |
|---|---|---|
| Escape | Cancel snipping overlay | No |

Global keyboard shortcut feature (⌘⇧2) is currently disabled. The `GlobalHotkeyManager` code remains in the repo but is not wired into `AppCoordinator`. Re-enabling is planned for a future release.

---

## 6. Error Handling

All errors are surfaced via `NSAlert` with title **Glazer AI** and actionable recovery text:

| Error | Message |
|---|---|
| Screen Recording not granted | "Go to System Settings → Privacy & Security → Screen Recording and enable Glazer AI" |
| claude CLI not found | "The Claude CLI is required. Click Install to download it." |
| claude non-zero exit | stderr content displayed |
| claude timeout (60s) | "The Claude CLI did not respond within 60 seconds." |
| OCR no text found | "No text was detected in the captured region." |
| Empty capture | "The selected region is too small to capture." |

---

## 7. Data Flow

```
User (menu item)
        │
        ▼
 AppCoordinator.startCapture()
        │
        ▼
 SnippingWindowController.present()
        │  (user drags rect)
        ▼
 SnippingWindowController.confirm(rect: CGRect)
        │
        ▼
 ScreenCaptureService.capture(rect:) → Data (PNG)
        │   (SCScreenshotManager.captureImage)
        │   (DEBUG: copy to clipboard)
        ▼
 OCRService.recognizeText(in:) → String
        │   (VNRecognizeTextRequest)
        ▼
 PromptAssembler.assemble(ocrText:) → String
        │
        ▼
 ClaudeRunner.run(prompt:) → String
        │   (claude -p "<prompt>")
        ▼
 ResultsWindowController
 ├─ snip thumbnail
 ├─ OCR text (collapsible)
 └─ Claude response (scrollable, copyable)
```

---

## 8. File & Folder Structure

```
GlazerAI/
├── GlazerAI.xcodeproj/
│   └── project.pbxproj
├── GlazerAI/                            # App target sources
│   ├── App/
│   │   ├── GlazerAIApp.swift            # @main entry point, creates AppCoordinator
│   │   └── AppCoordinator.swift         # Owns and wires all subsystems
│   ├── MenuBar/
│   │   └── MenuBarController.swift      # NSStatusItem setup and menu construction
│   ├── Snipping/
│   │   ├── SnippingWindowController.swift  # Full-screen overlay NSWindow
│   │   └── SnippingView.swift              # NSView subclass drawing dim+rect+label
│   ├── Capture/
│   │   └── ScreenCaptureService.swift      # SCScreenshotManager wrapper
│   ├── OCR/
│   │   └── OCRService.swift                # Vision framework text recognition
│   ├── Prompt/
│   │   └── PromptAssembler.swift           # Research prompt template + assembly
│   ├── CLI/
│   │   ├── CLIEnvironment.swift            # claude CLI path resolution
│   │   └── ClaudeRunner.swift              # Process wrapper for claude -p
│   ├── Results/
│   │   ├── ResultsWindowController.swift   # NSWindowController for results
│   │   ├── ResultsView.swift               # SwiftUI view
│   │   └── ResultsViewModel.swift          # Observable state for results
│   ├── Backend/
│   │   ├── AIBackendService.swift          # Protocol + error enum (kept for testing)
│   │   └── MockAIBackendService.swift      # Mock implementation (kept for testing)
│   ├── Settings/                           # (disabled — files kept for future use)
│   │   ├── SettingsWindowController.swift
│   │   ├── SettingsView.swift
│   │   └── ShortcutRecorderView.swift
│   ├── Hotkey/                             # (disabled — not wired into coordinator)
│   │   └── GlobalHotkeyManager.swift
│   ├── Resources/
│   │   ├── Assets.xcassets/
│   │   │   └── MenuBarIcon.imageset/       # Donut icon (1x + 2x PNG, template)
│   │   └── Info.plist
│   └── Support/
│       └── Constants.swift
├── GlazerAITests/                     # Unit test target
│   ├── RectCalculationTests.swift
│   ├── CoordinateConversionTests.swift
│   ├── OCRServiceTests.swift
│   ├── PromptAssemblerTests.swift
│   ├── ClaudeRunnerTests.swift
│   ├── ResultsViewModelTests.swift
│   ├── MockAIBackendServiceTests.swift
│   └── IntegrationSmokeTest.swift
├── scripts/
│   ├── launch.sh                    # Build + launch (--reset to wipe TCC)
│   ├── lint.sh
│   ├── test.sh
│   ├── build.sh
│   └── ci.sh
├── Makefile
├── project.yml                      # xcodegen project definition
├── .swiftlint.yml
├── .gitignore
└── SPEC.md                          # This document
```

---

## 9. Build & Run Instructions

### Prerequisites
- macOS 15.0+ (Sequoia)
- Xcode 16.0+ (Xcode 26 confirmed working)
- Swift 6
- SwiftLint (`brew install swiftlint`)
- xcodegen (`brew install xcodegen`) — only needed when modifying `project.yml`
- `claude` CLI installed and authenticated (`https://claude.ai/download`)

### Quick Launch
```bash
./scripts/launch.sh          # Build and launch
./scripts/launch.sh --reset  # Build, wipe TCC permissions, launch
```

### CLI build
```bash
make ci        # lint → test → build
make build     # build only
make test      # unit tests only
make lint      # SwiftLint only
```

### xcodegen Note
Running `xcodegen generate` overwrites `Info.plist`, removing custom keys (`LSUIElement`, `NSScreenCaptureUsageDescription`, `CFBundleDisplayName`). Always restore them after regeneration.

---

## 10. CI/CD

### Local Pipeline (`scripts/ci.sh`)
```
lint → test → build
```
Each step exits non-zero on failure; the pipeline stops immediately.

### Script Descriptions
| Script | What it does |
|---|---|
| `launch.sh` | Kills existing instance, builds, optionally resets TCC (`--reset`), launches |
| `lint.sh` | Runs `swiftlint lint --strict`; exits 1 on any violation |
| `test.sh` | Runs `xcodebuild test -scheme GlazerAITests`; exits 1 on failure |
| `build.sh` | Runs `xcodebuild build -scheme GlazerAI`; exits 1 on failure |
| `ci.sh` | Chains lint → test → build |

---

## 11. Commit Strategy

- Conventional commits: `feat:`, `fix:`, `chore:`, `docs:`, `test:`, `refactor:`, `perf:`
- One atomic feature per commit
- Each commit must pass `make ci` before being recorded

---

## 12. Testing Strategy

| Test file | What is tested |
|---|---|
| `RectCalculationTests` | Rectangle normalisation (negative width/height), small-rect rejection |
| `CoordinateConversionTests` | AppKit → CG coordinate conversion formula |
| `OCRServiceTests` | Text extraction, empty-result error handling |
| `PromptAssemblerTests` | Placeholder substitution, empty OCR text handling |
| `ClaudeRunnerTests` | stdout capture, timeout, non-zero exit error |
| `ResultsViewModelTests` | State transitions (loading → success → error) |
| `MockAIBackendServiceTests` | Empty-payload error, success path byte count |
| `IntegrationSmokeTest` | Full pipeline smoke test with mocked dependencies |

Target coverage: ≥ 80% of non-UI source lines.

---

## 13. Linting

`.swiftlint.yml` rules enabled:

| Rule | Threshold |
|---|---|
| `force_cast` | error |
| `force_try` | error |
| `implicitly_unwrapped_optional` | warning |
| `line_length` | warning at 120, error at 200 |
| `file_length` | warning at 400, error at 800 |
| `function_body_length` | warning at 40, error at 60 |
| `cyclomatic_complexity` | warning at 10, error at 20 |

SwiftLint runs as a build phase Run Script in Xcode and via `scripts/lint.sh`.

---

## 14. Open Questions / Future Work

- **TODO:** Re-enable global keyboard shortcut (⌘⇧2) with proper Accessibility permission handling.
- **TODO:** Add Settings panel with shortcut recorder, editable research prompt, CLI path display.
- **TODO:** Streaming Claude output to results window (progressive rendering).
- Multi-monitor support: extend snipping overlay to span all screens.
- Annotation tools: arrows, text, blur before sending.
- Capture history: local log of previous snips.
- Sandboxing / App Store distribution: requires entitlement changes.
- Accessibility: VoiceOver support.
