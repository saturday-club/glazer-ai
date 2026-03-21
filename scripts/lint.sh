#!/usr/bin/env bash
# lint.sh — Glazer AI
#
# Runs SwiftLint in strict mode against all app and test sources.
# Exits non-zero if any violation is found.
#
# Usage: ./scripts/lint.sh

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(dirname "$SCRIPT_DIR")"

echo "==> Running SwiftLint..."
cd "$ROOT_DIR"
swiftlint lint --strict --config .swiftlint.yml
echo "==> SwiftLint passed."
