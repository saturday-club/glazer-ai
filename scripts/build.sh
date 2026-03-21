#!/usr/bin/env bash
# build.sh — Glazer AI
#
# Builds the GlazerAI app scheme via xcodebuild.
# Exits non-zero if the build fails.
#
# Usage: ./scripts/build.sh

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(dirname "$SCRIPT_DIR")"

echo "==> Building GlazerAI..."
cd "$ROOT_DIR"
xcodebuild build \
  -project GlazerAI.xcodeproj \
  -scheme GlazerAI \
  -destination "platform=macOS" \
  -configuration Debug
echo "==> Build succeeded."
