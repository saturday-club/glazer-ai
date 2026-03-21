#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$SCRIPT_DIR/.."
BUNDLE_ID="com.glazerai.app"

# Kill any running instance before replacing it.
pkill -x GlazerAI 2>/dev/null || true

echo "Building GlazerAI..."
xcodebuild \
  -project "$ROOT/GlazerAI.xcodeproj" \
  -scheme GlazerAI \
  -destination 'platform=macOS' \
  -quiet \
  build

APP=$(find ~/Library/Developer/Xcode/DerivedData/GlazerAI-*/Build/Products/Debug -name "GlazerAI.app" -maxdepth 1 | head -1)

if [[ -z "$APP" ]]; then
  echo "Error: could not find built GlazerAI.app" >&2
  exit 1
fi

if [[ "${1:-}" == "--reset" ]]; then
  echo "Resetting permissions for $BUNDLE_ID..."
  tccutil reset Accessibility "$BUNDLE_ID"
  tccutil reset ScreenCapture "$BUNDLE_ID"
fi

echo "Launching $APP"
open "$APP"
