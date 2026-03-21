# Glazer AI

A macOS menu bar utility that captures screen regions, extracts text via OCR, and pipes it through the Claude CLI for AI-powered research summaries.

```
Snip -> OCR -> Prompt Assembly -> claude -p -> Results Window
```

## Features

- **Menu bar agent** -- runs entirely in the menu bar (no Dock icon, no app switcher)
- **Snipping overlay** -- full-screen region selector with live rectangle preview, dimension labels, and dimmed backdrop
- **OCR extraction** -- Apple Vision framework with accurate recognition level and auto language detection
- **Claude integration** -- sends extracted text to `claude -p` with a research prompt template, captures the response
- **Results window** -- displays captured image thumbnail, extracted text (collapsible), and Claude's response with copy support
- **Permission handling** -- guides users through Screen Recording permission with actionable error messages

## Requirements

| Requirement | Version |
|---|---|
| macOS | 15.0+ (Sequoia) |
| Xcode | 16.0+ |
| Swift | 6.0 (strict concurrency) |
| Claude CLI | Installed and authenticated (`claude -p` must work) |

Optional tooling:

```bash
brew install swiftlint    # Linting (required for CI)
brew install xcodegen     # Only if modifying project.yml
```

## Quick Start

```bash
git clone https://github.com/saturday-club/glazer-ai.git
cd glazer-ai

# Build and launch
./scripts/launch.sh

# Or build and reset TCC permissions first
./scripts/launch.sh --reset
```

On first launch, macOS will prompt for **Screen Recording** permission. Grant it in System Settings > Privacy & Security > Screen Recording.

## Usage

1. Click the donut icon in the menu bar
2. Select **Capture Region**
3. Click and drag to select a screen region (Escape to cancel)
4. Wait for OCR + Claude processing ("Thinking..." indicator)
5. View results -- copy the response or close the window

Each capture opens a new results window, so you can run multiple queries side by side.

## Build & CI

The project uses a Makefile wrapping shell scripts in `scripts/`:

```bash
make ci        # Full pipeline: lint -> test -> build
make build     # Build only (Debug configuration)
make test      # Run unit tests
make lint      # SwiftLint strict mode
```

Individual scripts:

| Script | Purpose |
|---|---|
| `scripts/launch.sh` | Build + launch (`--reset` to wipe TCC) |
| `scripts/build.sh` | `xcodebuild` Debug build |
| `scripts/test.sh` | `xcodebuild test` with xcpretty fallback |
| `scripts/lint.sh` | SwiftLint strict mode |
| `scripts/ci.sh` | Lint -> test -> build pipeline |

## Architecture

The app follows the **Coordinator pattern** with protocol-based dependency injection:

```
GlazerAIApp (@main)
  -> AppDelegate
    -> AppCoordinator (MainActor, owns all subsystems)
         |
         +-- MenuBarController        (NSStatusItem, action menu)
         +-- SnippingWindowController  (full-screen overlay)
         +-- ScreenCaptureService      (ScreenCaptureKit wrapper)
         +-- OCRService                (Vision framework)
         +-- PromptAssembler           (template-based prompt construction)
         +-- ClaudeRunner              (actor, Process wrapper, 60s timeout)
         +-- ResultsWindowController   (NSWindowController + SwiftUI)
```

### Key design decisions

- **Swift 6 strict concurrency** throughout -- `async/await`, actors, `Sendable` types
- **No external dependencies** -- pure Apple system frameworks (AppKit, SwiftUI, Vision, ScreenCaptureKit, Foundation)
- **Protocol abstraction** for AI backend (`AIBackendService`) enables mock injection for tests
- **Coordinate conversion** handles AppKit (origin bottom-left) to ScreenCaptureKit (origin top-left) and Retina scaling
- **Shell escaping** uses single-quote wrapping with `'\''` for safe prompt passthrough

## Project Structure

```
GlazerAI/
  App/                  Entry point, AppCoordinator, constants
  MenuBar/              NSStatusItem and menu construction
  Snipping/             Full-screen overlay (NSWindow + NSView)
  Capture/              ScreenCaptureKit wrapper
  OCR/                  Vision framework text recognition
  Prompt/               Research prompt template assembly
  CLI/                  Claude path resolution + process invocation
  Results/              Results window (NSWindowController + SwiftUI)
  Backend/              AI backend protocol + mock
  Settings/             Settings panel (disabled, kept for future)
  Hotkey/               Global keyboard shortcut (disabled, kept for future)
  Resources/            Assets.xcassets, Info.plist

GlazerAITests/          Unit + integration tests (~80% coverage target)
scripts/                Build, test, lint, CI shell scripts
```

## Testing

Tests cover business logic, coordinate math, OCR, prompt assembly, CLI invocation, and view model state transitions:

```bash
make test
```

Test files:

| Test | Coverage |
|---|---|
| `RectCalculationTests` | Rectangle normalization, small-rect rejection |
| `CoordinateConversionTests` | AppKit to CG coordinate conversion |
| `OCRServiceTests` | Text extraction, empty-result errors |
| `PromptAssemblerTests` | Placeholder substitution, custom templates |
| `ClaudeRunnerTests` | stdout capture, shell escaping, path resolution |
| `ResultsViewModelTests` | State transitions (loading/success/error) |
| `MockAIBackendServiceTests` | Mock backend paths |
| `GlobalHotkeyManagerTests` | Event tap lifecycle, shortcut encoding |
| `UserDefaultsShortcutTests` | Shortcut JSON round-trip |
| `IntegrationSmokeTest` | Full pipeline with spy backend |

## Error Handling

All errors surface via native `NSAlert` dialogs with actionable guidance:

| Scenario | User sees |
|---|---|
| Screen Recording denied | Link to System Settings > Privacy & Security |
| Claude CLI not found | Install prompt with download link |
| Claude timeout (60s) | Timeout message |
| No text detected | "No text was detected in the captured region" |
| Selection too small | "The selected region is too small to capture" |
| Claude non-zero exit | stderr content |

## Roadmap

- [ ] Global keyboard shortcut (Cmd+Shift+2) -- implemented, pending Accessibility permission UX
- [ ] Settings panel -- implemented, pending menu bar wiring
- [ ] Streaming Claude output (progressive rendering)
- [ ] Multi-monitor support
- [ ] Annotation tools (arrows, text, blur)
- [ ] Capture history
- [ ] App Store distribution (sandboxing)
- [ ] VoiceOver accessibility

## License

All rights reserved. Local build and direct install only.
