#!/usr/bin/env bash
# Headless authorized scan of the attached private subnet. Results stay local.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
OUT="${SCANNER_DOGFOOD_DIR:-$HOME/Library/Application Support/Scanner/dogfood}"
PROFILE="${SCANNER_DOGFOOD_PROFILE:-standard}"
LOG="$OUT/launchd.log"

mkdir -p "$OUT"
{
  echo "==> $(date -u +%Y-%m-%dT%H:%M:%SZ) dogfood scan profile=$PROFILE"
  cd "$ROOT"
  swift run --package-path Packages/ScanEngine -c release scanctl dogfood \
    --i-am-authorized \
    --profile "$PROFILE" \
    --out "$OUT"
} >>"$LOG" 2>&1
echo "log: $LOG"
echo "summary: $OUT/summary.md"
