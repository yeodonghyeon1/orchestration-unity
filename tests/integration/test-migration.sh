#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
MIG="$REPO_ROOT/scripts/migrate-v02-to-v1.sh"

pass() { echo "  ✓ $1"; }
fail() { echo "  ✗ $1" >&2; exit 1; }

TMP="$(mktemp -d)"
if command -v cygpath >/dev/null 2>&1; then
    TMP="$(cygpath -m "$TMP")"
fi
trap 'rm -rf "$TMP"' EXIT

cp -r "$REPO_ROOT/tests/fixture/v0.2-layout/"* "$TMP/"
cp -r "$REPO_ROOT/tests/fixture/v0.2-layout/".orchestration "$TMP/" 2>/dev/null || true

(cd "$TMP" && bash "$MIG" --yes)

[ -f "$TMP/develop_docs/game/systems/combat.md" ] \
    || fail "docs/game was not moved to develop_docs/game"
pass "docs/ tree moved to develop_docs/"

[ -d "$TMP/notion_docs/_meta" ] || fail "notion_docs/_meta missing"
pass "notion_docs scaffolded"

[ -d "$TMP/.orchestration/sessions/2026-04-11-sample" ] \
    || fail ".orchestration was deleted (should be preserved)"
pass ".orchestration preserved"

[ ! -d "$TMP/docs/game" ] || fail "docs/game should have been moved, not copied"
pass "docs/ source removed after move"

echo "All migration tests passed"
