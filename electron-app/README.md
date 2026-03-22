# Glazer AI -- Electron (Cross-Platform)

Cross-platform desktop app for screen capture + AI-powered research. Works on **Windows**, **macOS**, and **Linux**.

This is the Electron port of the native macOS Glazer AI app.

## How It Works

```
System Tray -> Snipping Overlay -> Screen Capture -> OCR/Vision -> Claude API -> Results Window
```

1. Click the tray icon (or press **Ctrl+Shift+2** / **Cmd+Shift+2**)
2. Drag to select a screen region
3. The app either:
   - **OCR mode**: Extracts text via Tesseract.js, sends to Claude API
   - **Vision mode**: Sends the image directly to Claude's vision API (skips OCR)
4. Results appear in a new window with the captured image, extracted text, and Claude's response

## Requirements

- **Node.js** 18+
- **Anthropic API key** (entered on first launch via Settings)
- **Linux only**: ImageMagick (`sudo apt install imagemagick`)

## Setup

```bash
cd electron-app
npm install
```

## Development

```bash
# Start Vite dev server + TypeScript watch
npm run dev

# In another terminal, launch Electron
npm start
```

## Build & Package

```bash
# Build for current platform
npm run package

# Build for specific platform
npm run package:win
npm run package:mac
npm run package:linux
```

Outputs go to `release/`.

## Testing

```bash
npm test              # Run all tests
npm run test:watch    # Watch mode
npm run typecheck     # TypeScript type checking
```

## Architecture

```
Main Process (Node.js)
  +-- Tray (system tray icon + context menu)
  +-- GlobalShortcut (Cmd/Ctrl+Shift+2)
  +-- IPC Handlers (pipeline orchestration)
  +-- Services
  |     +-- ScreenCapture (screenshot-desktop + sharp crop)
  |     +-- OCR (tesseract.js)
  |     +-- AnthropicClient (text + vision modes)
  |     +-- PromptAssembler (template substitution)
  +-- Windows
        +-- SnippingWindow (transparent, fullscreen)
        +-- ResultsWindow (React app)

Renderer: Snipping (Canvas API, vanilla TS)
Renderer: Results (React, progressive updates via IPC)
```

## Key Differences from macOS Native

| Feature | macOS (Swift) | Electron |
|---|---|---|
| Screen capture | ScreenCaptureKit | screenshot-desktop + sharp |
| OCR | Apple Vision | Tesseract.js (WASM) |
| AI backend | `claude -p` CLI | Anthropic SDK (direct API) |
| UI framework | AppKit + SwiftUI | HTML Canvas + React |
| Vision mode | Not available | Send image directly to Claude |
| App size | ~5 MB | ~150 MB (Chromium bundled) |
| Platforms | macOS only | Windows, macOS, Linux |

## Tech Stack

- **Electron 33+** -- cross-platform desktop framework
- **TypeScript** -- type safety throughout
- **React 19** -- results window UI
- **Vite** -- renderer bundling and dev server
- **screenshot-desktop** -- cross-platform screen capture
- **sharp** -- image cropping and processing
- **Tesseract.js 5** -- WASM-based OCR (100+ languages)
- **@anthropic-ai/sdk** -- official Anthropic API client
- **electron-store** -- encrypted persistent config
- **electron-builder** -- packaging for all platforms
