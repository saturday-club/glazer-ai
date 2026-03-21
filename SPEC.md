# Glazer AI — Software Requirements Specification

**Version:** 2.0.0
**Date:** 2026-03-21
**Status:** Living Document — update on every new requirement

---

## 1. Overview

| Field | Value |
|---|---|
| App name | Glazer AI |
| Purpose | macOS menu bar utility that captures a user-defined screen region and forwards the image to an AI backend pipeline |
| Target platform | macOS 14.0+ (ScreenCaptureKit required) |
| Language | Swift 6 strict concurrency |
| UI framework | AppKit (menu bar, overlay window) |
| Architecture | Coordinator pattern — `AppCoordinator` owns all major subsystems and wires them together via protocol-based dependency injection |
| Distribution | Local build / direct install (no App Store in v1) |

---

## 2. Features

### 2.1 Menu Bar Presence
- The app runs exclusively as a menu bar agent (`LSUIElement = YES`); no Dock icon, no app switcher entry.
- A single `NSStatusItem` is created at launch and persists for the lifetime of the process.
- The status item displays a bundled donut icon (mingcute:donut-line) rendered as a template image (adapts to light/dark menu bar).
- Clicking the status item opens the action menu.

### 2.2 Action Menu

| Item | Action |
|---|---|
| **Capture Region** | Activates the snipping overlay |
| *(separator)* | — |
| **Quit Glazer AI** | Terminates the process |

### 2.3 Permission Handling
- **Screen Recording:** On launch, the app briefly sets activation policy to `.regular` and calls `SCShareableContent.current` (ScreenCaptureKit) to register with TCC and trigger the native macOS permission dialog. This is necessary because LSUIElement (background) apps have TCC dialogs suppressed. The policy reverts to `.accessory` after the prompt completes.
- **Preflight check:** Before every capture, `CGPreflightScreenCaptureAccess()` is called. If permission has been revoked, a clear error message is shown instead of silently returning blank content.
- Keyboard shortcuts and Accessibility permission are not currently used (feature disabled).

### 2.4 Snipping Overlay
- Full-screen `NSWindow` covering all connected displays (one window per screen in a future release; v1 covers the main screen).
- Window level: `NSWindow.Level.screenSaver` so it appears above all normal windows.
- On presentation: screen dims (black fill, 40% opacity) over the entire display.
- Cursor: crosshair (`NSCursor.crosshair`).
- User click-drags to define a rectangular selection:
  - The region inside the drag rect is rendered at full brightness (clear of the dim layer).
  - A 1 pt blue (`#007AFF`) border outlines the selection.
  - A label showing `W × H` (integer pixel dimensions) appears near the bottom-right handle of the rect.
- **Cancel:** `Escape` key dismisses the overlay with no capture.
- **Confirm:** releasing the mouse button (mouse-up) confirms the selection and triggers capture.

### 2.5 Screen Capture
- On confirmation, `SCScreenshotManager.captureImage` (ScreenCaptureKit, macOS 14+) captures the selected region.
- The capture excludes the Glazer AI overlay window via `SCContentFilter(display:excludingApplications:)`.
- Coordinate conversion from AppKit screen coordinates (origin bottom-left) to display-local ScreenCaptureKit coordinates (origin top-left) follows the same approach as [ScrollSnap](https://github.com/Brkgng/ScrollSnap).
- Handles Retina (HiDPI) scaling via `filter.pointPixelScale`.
- Output: PNG `Data` blob.

### 2.6 AI Backend Integration
- Captured `Data` is handed to an `AIBackendService` implementor.
- v1 ships `MockAIBackendService`: logs image byte-count to console, copies image to clipboard (DEBUG only), shows a success `NSAlert`.
- The protocol is the extension point; a real backend (HTTP upload, local model, etc.) replaces the mock without touching call sites.

---

## 3. UI/UX Details

### 3.1 Menu Bar Icon
- Bundled icon: `mingcute:donut-line` (Iconify) rendered as 18×18pt / 36×36px PNG with `template-rendering-intent: template`.
- Fallback: SF Symbol `circle.dashed` if bundled asset is missing.
- Size: 18 × 18 pt, explicitly set on `NSImage.size` to prevent overflow.

### 3.2 Snipping Surface Behaviour
1. Menu item fires → overlay window appears instantly (no animation).
2. User moves mouse → crosshair cursor shown.
3. Mouse-down → anchor point recorded.
4. Mouse-drag → live rect drawn; dim layer has a clear hole matching the rect; blue border and dimension label update in real time.
5. Mouse-up → rect finalised → overlay dismissed → capture begins.
6. Escape at any point → overlay dismissed → no capture.

---

## 4. Keyboard Shortcuts

| Shortcut | Action | Configurable |
|---|---|---|
| Escape | Cancel snipping overlay | No |

Global keyboard shortcut feature (⌘⇧2 via CGEvent tap) is currently disabled. The `GlobalHotkeyManager` code remains in the repo but is not wired into `AppCoordinator`.

---

## 5. AI Backend Integration

### 5.1 Protocol Contract

```swift
protocol AIBackendService: AnyObject, Sendable {
    /// Sends a PNG image to the AI backend.
    func send(image: Data) async throws
}
```

### 5.2 Error Type

```swift
enum AIBackendError: LocalizedError {
    case emptyPayload
    case networkFailure(underlying: Error)
    case unexpectedResponse(statusCode: Int)
}
```

### 5.3 Mock Implementation
`MockAIBackendService` (v1):
- Validates `image` is non-empty; throws `AIBackendError.emptyPayload` otherwise.
- Prints `"[Glazer AI] Captured \(image.count) bytes"` to stdout.
- In DEBUG builds: copies captured image to system clipboard for visual verification.
- Shows `NSAlert` with title "Capture Sent" and message "Image size: \(image.count) bytes".

> **TODO:** Replace `MockAIBackendService` with a real backend implementation. See §9.

---

## 6. Data Flow

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
        │   (SCScreenshotManager.captureImage via ScreenCaptureKit)
        ▼
 AIBackendService.send(image:)
        │
        ▼
 MockAIBackendService → clipboard + NSAlert + console log
```

---

## 7. File & Folder Structure

```
GlazerAI/
├── GlazerAI.xcodeproj/
│   └── project.pbxproj
├── GlazerAI/                        # App target sources
│   ├── App/
│   │   ├── GlazerAIApp.swift          # @main entry point, creates AppCoordinator
│   │   └── AppCoordinator.swift     # Owns status item, window controllers
│   ├── MenuBar/
│   │   └── MenuBarController.swift  # NSStatusItem setup and menu construction
│   ├── Snipping/
│   │   ├── SnippingWindowController.swift  # Full-screen overlay NSWindow
│   │   └── SnippingView.swift              # NSView subclass drawing dim+rect+label
│   ├── Capture/
│   │   └── ScreenCaptureService.swift      # SCScreenshotManager wrapper
│   ├── Backend/
│   │   ├── AIBackendService.swift          # Protocol + error enum
│   │   └── MockAIBackendService.swift      # Mock implementation
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
│   ├── GlobalHotkeyManagerTests.swift
│   ├── MockAIBackendServiceTests.swift
│   ├── UserDefaultsShortcutTests.swift
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
├── SPEC.md                          # This document
└── BE-SPEC.md                       # (planned) Python LLM backend spec
```

---

## 8. Build & Run Instructions

### Prerequisites
- macOS 14.0+ (ScreenCaptureKit `SCScreenshotManager` required)
- Xcode 15.0+ (Xcode 26 confirmed working)
- SwiftLint (`brew install swiftlint`)
- xcodegen (`brew install xcodegen`) — only needed when modifying `project.yml`

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

## 9. Open Questions / Future Work

- **TODO:** Replace `MockAIBackendService` with a Python LLM-based research pipeline (see `BE-SPEC.md`).
- **TODO:** Re-enable global keyboard shortcut (⌘⇧2) with proper Accessibility permission handling.
- Multi-monitor support: extend snipping overlay to span all screens.
- Annotation tools: arrows, text, blur before sending.
- Capture history: local log of previous snips.
- Sandboxing / App Store distribution: requires entitlement changes.
- Accessibility: VoiceOver support.

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
| `GlobalHotkeyManagerTests` | Registration / deregistration lifecycle |
| `MockAIBackendServiceTests` | Empty-payload error, success path byte count |
| `UserDefaultsShortcutTests` | UserDefaults encode/decode round-trip for shortcut struct |
| `IntegrationSmokeTest` | Full coordinator → mock backend pipeline |

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
