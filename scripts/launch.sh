#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$SCRIPT_DIR/.."

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

echo "Launching $APP"
open "$APP"
