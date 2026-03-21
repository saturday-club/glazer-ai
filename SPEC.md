# Glazer AI — Software Requirements Specification

**Version:** 1.0.0
**Date:** 2026-03-21
**Status:** Living Document — update on every new requirement

---

## 1. Overview

| Field | Value |
|---|---|
| App name | Glazer AI |
| Purpose | macOS menu bar utility that captures a user-defined screen region and forwards the image to an AI backend pipeline |
| Target platform | macOS 13.0 (Ventura) and later |
| Language | Swift 5.9+ / Swift 6 strict concurrency |
| UI framework | SwiftUI (settings panel); AppKit (menu bar, overlay window) |
| Architecture | Coordinator pattern — `AppCoordinator` owns all major subsystems and wires them together via protocol-based dependency injection |
| Distribution | Local build / direct install (no App Store in v1) |

---

## 2. Features

### 2.1 Menu Bar Presence
- The app runs exclusively as a menu bar agent (`LSUIElement = YES`); no Dock icon, no app switcher entry.
- A single `NSStatusItem` is created at launch and persists for the lifetime of the process.
- The status item displays a template-rendered icon (see §4).
- Clicking the status item opens the action menu.

### 2.2 Action Menu
Menu items (in order):

| Item | Action |
|---|---|
| **Capture Region** | Activates the snipping overlay (same as global shortcut) |
| *(separator)* | — |
| **Settings…** | Opens the Settings panel |
| **Quit Glazer AI** | Terminates the process |

### 2.3 Global Keyboard Shortcut
- Default shortcut: **⌘⇧2**
- Registered as a global hotkey so it fires even when Glazer AI is not the frontmost app.
- Activating the shortcut is equivalent to clicking **Capture Region**.
- The shortcut is user-configurable via the Settings panel and persisted to `UserDefaults`.

### 2.4 Snipping Overlay
- Full-screen `NSWindow` covering all connected displays (one window per screen in a future release; v1 covers the main screen).
- Window level: `NSWindow.Level.screenSaver` so it appears above all normal windows.
- On presentation: screen dims (black fill, 40 % opacity) over the entire display.
- Cursor: crosshair (`NSCursor.crosshair`).
- User click-drags to define a rectangular selection:
  - The region inside the drag rect is rendered at full brightness (clear of the dim layer).
  - A 1 pt blue (`#007AFF`) border outlines the selection.
  - A label showing `W × H` (integer pixel dimensions) appears near the bottom-right handle of the rect.
- **Cancel:** `Escape` key dismisses the overlay with no capture.
- **Confirm:** releasing the mouse button (mouse-up) confirms the selection and triggers capture.

### 2.5 Screen Capture
- On confirmation, `CGWindowListCreateImage` captures the selected rect in screen coordinates.
- Output: PNG `Data` blob.
- Coordinate conversion handles Retina (HiDPI) scaling and multi-monitor origin differences.

### 2.6 AI Backend Integration
- Captured `Data` is handed to an `AIBackendService` implementor.
- v1 ships `MockAIBackendService`: logs image byte-count to console, shows a success `NSAlert`.
- The protocol is the extension point; a real backend (HTTP upload, local model, etc.) replaces the mock without touching call sites.

### 2.7 Settings Panel
- Presented as a floating `NSWindow` (SwiftUI content).
- Fields:
  - **Keyboard Shortcut** — recorder control showing current binding; user clicks and presses a new combo to change it.
- Changes take effect on **Save**; **Cancel** discards edits.
- Shortcut is persisted to `UserDefaults` key `"globalShortcut"`.

---

## 3. UI/UX Details

### 3.1 Menu Bar Icon
- SF Symbol: `circle.dashed` rendered as a template image (adapts to light/dark menu bar).
- Size: 18 × 18 pt.
- Fallback: bundled `MenuBarIcon.png` (18 × 18 pt, template mode) if SF Symbol is unavailable on older OS.

### 3.2 Snipping Surface Behaviour
1. Shortcut / menu item fires → overlay window appears instantly (no animation).
2. User moves mouse → crosshair cursor shown.
3. Mouse-down → anchor point recorded.
4. Mouse-drag → live rect drawn; dim layer has a clear hole matching the rect; blue border and dimension label update in real time.
5. Mouse-up → rect finalised → overlay dismissed → capture begins.
6. Escape at any point → overlay dismissed → no capture.

### 3.3 Settings Panel Layout
```
┌─────────────────────────────────────┐
│  Glazer AI Settings                    │
├─────────────────────────────────────┤
│  Keyboard Shortcut  [ ⌘⇧2       ▾ ] │
│                                     │
│              [Cancel]  [Save]        │
└─────────────────────────────────────┘
```

---

## 4. Keyboard Shortcuts

| Shortcut | Action | Configurable |
|---|---|---|
| ⌘⇧2 | Activate snipping overlay | Yes — Settings panel |
| Escape | Cancel snipping overlay | No |
| Return | (reserved for future confirm-without-mouse) | — |

Persistence mechanism: `UserDefaults.standard.set(_:forKey:)` with key `"globalShortcut"`. Stored as a `Data` blob (encoded `KeyboardShortcut` struct). On launch, the stored value is decoded and re-registered.

---

## 5. AI Backend Integration

### 5.1 Protocol Contract

```swift
protocol AIBackendService: AnyObject {
    /// Sends a PNG image to the AI backend.
    /// - Parameter image: Raw PNG data of the captured region.
    /// - Throws: `AIBackendError` on failure.
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
- Shows `NSAlert` with title "Capture Sent" and message "Image size: \(image.count) bytes".

> **TODO:** Replace `MockAIBackendService` with a real backend implementation. See §9.

---

## 6. Data Flow

```
User (shortcut / menu)
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
        │
        ▼
 AIBackendService.send(image:)
        │
        ▼
 MockAIBackendService → NSAlert + console log
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
│   │   └── AppCoordinator.swift     # Owns status item, hotkey, window controllers
│   ├── MenuBar/
│   │   └── MenuBarController.swift  # NSStatusItem setup and menu construction
│   ├── Snipping/
│   │   ├── SnippingWindowController.swift  # Full-screen overlay NSWindow
│   │   └── SnippingView.swift              # NSView subclass drawing dim+rect+label
│   ├── Capture/
│   │   └── ScreenCaptureService.swift      # CGWindowListCreateImage wrapper
│   ├── Backend/
│   │   ├── AIBackendService.swift          # Protocol + error enum
│   │   └── MockAIBackendService.swift      # Mock implementation
│   ├── Settings/
│   │   ├── SettingsWindowController.swift  # NSWindowController wrapper
│   │   ├── SettingsView.swift              # SwiftUI settings form
│   │   └── ShortcutRecorderView.swift      # Key combo recorder control
│   ├── Hotkey/
│   │   └── GlobalHotkeyManager.swift       # CGEvent tap registration
│   ├── Resources/
│   │   ├── Assets.xcassets/
│   │   │   └── MenuBarIcon.imageset/
│   │   └── Info.plist
│   └── Support/
│       └── Constants.swift                 # App-wide named constants
├── GlazerAITests/                     # Unit test target
│   ├── RectCalculationTests.swift
│   ├── CoordinateConversionTests.swift
│   ├── GlobalHotkeyManagerTests.swift
│   ├── MockAIBackendServiceTests.swift
│   ├── UserDefaultsShortcutTests.swift
│   └── IntegrationSmokeTest.swift
├── scripts/
│   ├── lint.sh
│   ├── test.sh
│   ├── build.sh
│   └── ci.sh
├── Makefile
├── .swiftlint.yml
├── .gitignore
└── SPEC.md                          # This document
```

---

## 8. Build & Run Instructions

### Prerequisites
- macOS 13.0+
- Xcode 15.0+ (Xcode 26 confirmed working)
- SwiftLint (`brew install swiftlint`)

### Steps
```bash
# 1. Clone / enter the repo
cd glazer-ai

# 2. Open in Xcode
open GlazerAI.xcodeproj

# 3. Select scheme "Glazer AI" → any Mac destination
# 4. ⌘R to build and run
# 5. Grant Screen Recording permission when prompted (required for CGWindowListCreateImage)
```

### CLI build
```bash
make ci        # lint → test → build
make build     # build only
make test      # unit tests only
make lint      # SwiftLint only
```

---

## 9. Open Questions / Future Work

- **TODO:** Replace `MockAIBackendService` with a real HTTP/gRPC/local-model backend.
- Multi-monitor support: extend snipping overlay to span all screens.
- Annotation tools: arrows, text, blur before sending.
- Capture history: local log of previous snips.
- Sandboxing / App Store distribution: requires entitlement changes.
- Accessibility: VoiceOver support for Settings panel.
- Retina label rendering: verify dimension label sharpness at 2× and 3× scales.

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
| `lint.sh` | Runs `swiftlint lint --strict`; exits 1 on any violation |
| `test.sh` | Runs `xcodebuild test -scheme GlazerAITests`; exits 1 on failure |
| `build.sh` | Runs `xcodebuild build -scheme GlazerAI`; exits 1 on failure |
| `ci.sh` | Chains lint → test → build |

---

## 11. Commit Strategy

- Conventional commits: `feat:`, `fix:`, `chore:`, `docs:`, `test:`, `refactor:`, `perf:`
- One atomic feature per commit (see Phase 2–3 commit plan)
- Each commit must pass `make ci` before being recorded

---

## 12. Testing Strategy

| Test file | What is tested |
|---|---|
| `RectCalculationTests` | Rectangle normalisation (negative width/height), clamping to screen bounds |
| `CoordinateConversionTests` | CGRect → screen coordinate conversion, Retina scale factor |
| `GlobalHotkeyManagerTests` | Registration / deregistration lifecycle (mock CGEvent tap) |
| `MockAIBackendServiceTests` | Empty-payload error, success path byte count |
| `UserDefaultsShortcutTests` | UserDefaults encode/decode round-trip for shortcut struct |
| `IntegrationSmokeTest` | Full coordinator → mock capture → mock backend pipeline |

Target coverage: ≥ 80 % of non-UI source lines.

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

## 14. `.gitignore` Contents

```
.DS_Store
*.xcuserstate
xcuserdata/
DerivedData/
*.swp
Pods/
.build/
*.ipa
*.dSYM.zip
```
