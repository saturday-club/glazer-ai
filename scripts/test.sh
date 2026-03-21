#!/usr/bin/env bash
# test.sh — Glazer AI
#
# Runs the GlazerAITests unit test scheme via xcodebuild.
# Exits non-zero if any test fails or the build cannot be performed.
#
# Usage: ./scripts/test.sh

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(dirname "$SCRIPT_DIR")"

echo "==> Running unit tests..."
cd "$ROOT_DIR"
xcodebuild test \
  -project GlazerAI.xcodeproj \
  -scheme GlazerAI \
  -destination "platform=macOS" \
  -resultBundlePath /tmp/GlazerAITestResults \
  | xcpretty || xcodebuild test \
    -project GlazerAI.xcodeproj \
    -scheme GlazerAI \
    -destination "platform=macOS"
echo "==> Tests passed."
