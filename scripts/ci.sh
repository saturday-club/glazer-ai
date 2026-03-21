#!/usr/bin/env bash
# ci.sh — Glazer AI
#
# Local CI pipeline: lint → test → build.
# Stops immediately on the first failure (set -e).
#
# Usage: ./scripts/ci.sh

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "=============================="
echo " Glazer AI — Local CI"
echo "=============================="

"$SCRIPT_DIR/lint.sh"
"$SCRIPT_DIR/test.sh"
"$SCRIPT_DIR/build.sh"

echo ""
echo "=============================="
echo " All checks passed."
echo "=============================="
