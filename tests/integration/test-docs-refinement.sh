#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

pass() { echo "  ✓ $1"; }
fail() { echo "  ✗ $1" >&2; exit 1; }

TMP="$(mktemp -d)"
if command -v cygpath >/dev/null 2>&1; then
    TMP="$(cygpath -m "$TMP")"
fi
trap 'rm -rf "$TMP"' EXIT

# Copy fixture into develop_docs layout
mkdir -p "$TMP/develop_docs"
cp -r "$REPO_ROOT/tests/fixture/develop-docs-sample/"* "$TMP/develop_docs/"

# Build index
python3 "$REPO_ROOT/scripts/docs-index.py" "$TMP/develop_docs"
INDEX="$TMP/develop_docs/_meta/index.json"
[ -f "$INDEX" ] || fail "index.json not created"
pass "index.json created from fixture"

# Verify _self structure
python3 -c "
import json
idx = json.load(open('$INDEX'))
assert idx['schema_version'] == 2
node = idx['tree']['game.systems.combat']
assert '_self' in node
assert node['_self']['path'] == 'game/systems/combat.md'
" || fail "_self structure wrong"
pass "_self structure correct"

# Verify reverse_index
python3 -c "
import json
idx = json.load(open('$INDEX'))
assert 'uuid-plan' in idx['reverse_index']
assert 'game.systems.combat' in idx['reverse_index']['uuid-plan']
" || fail "reverse_index missing uuid-plan"
pass "reverse_index populated"

# BFS impact lookup
affected="$(python3 "$REPO_ROOT/scripts/bfs-impact.py" "$INDEX" "uuid-plan")"
echo "$affected" | grep -q "game.systems.combat" || fail "BFS did not find combat"
pass "BFS finds affected file"

echo "All docs-refinement integration tests passed"
