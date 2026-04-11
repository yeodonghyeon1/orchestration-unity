#!/usr/bin/env bash
# tests/structure-check.sh
# Validates plugin structure. Exits 0 on success, 1 on failure.
# Usage: ./tests/structure-check.sh [plugin-root]
set -euo pipefail

ROOT="${1:-$(cd "$(dirname "$0")/.." && pwd)}"
# Normalize MSYS/Cygwin paths so native python3 on Windows can read them.
if command -v cygpath >/dev/null 2>&1; then
  ROOT="$(cygpath -m "$ROOT")"
fi
ERRORS=0

err() { echo "FAIL: $1" >&2; ERRORS=$((ERRORS + 1)); }
ok()  { echo "OK:   $1"; }

# --- plugin.json --------------------------------------------------------
if [[ ! -f "$ROOT/.claude-plugin/plugin.json" ]]; then
  err ".claude-plugin/plugin.json missing"
else
  if ! python3 -c "
import json, sys
d = json.load(open('$ROOT/.claude-plugin/plugin.json'))
for k in ('name','description','version'):
    if k not in d: sys.exit('missing key: ' + k)
" 2>/dev/null; then
    err ".claude-plugin/plugin.json invalid or missing required keys (name/description/version)"
  else
    ok ".claude-plugin/plugin.json"
  fi
fi

# --- root files ---------------------------------------------------------
for f in README.md LICENSE CHANGELOG.md .gitignore; do
  if [[ -f "$ROOT/$f" ]]; then
    ok "$f"
  else
    err "$f missing"
  fi
done

# --- report -------------------------------------------------------------
if [[ $ERRORS -gt 0 ]]; then
  echo
  echo "structure-check: $ERRORS error(s)" >&2
  exit 1
fi
echo
echo "structure-check: passed"
