#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
BFS="$REPO_ROOT/scripts/bfs-impact.py"

pass() { echo "  ✓ $1"; }
fail() { echo "  ✗ $1" >&2; exit 1; }

TMP="$(mktemp -d)"
if command -v cygpath >/dev/null 2>&1; then
    TMP="$(cygpath -m "$TMP")"
fi
trap 'rm -rf "$TMP"' EXIT

cat > "$TMP/index.json" <<'EOF'
{
  "schema_version": 2,
  "tree": {
    "game.systems.combat": {"_self": {"path": "game/systems/combat.md"}, "children": []},
    "game.entities.player": {"_self": {"path": "game/entities/player.md"}, "children": []},
    "tech.unity.scripting": {"_self": {"path": "tech/unity/scripting.md"}, "children": []}
  },
  "reverse_index": {
    "plan.combat-system": ["game.systems.combat"],
    "plan.player-stats": ["game.entities.player"]
  }
}
EOF

out="$(python3 "$BFS" "$TMP/index.json" "plan.combat-system")"
echo "$out" | grep -q "game.systems.combat" || fail "BFS should find game.systems.combat"
pass "direct reverse lookup"

out="$(python3 "$BFS" "$TMP/index.json" "plan.combat-system,plan.player-stats")"
echo "$out" | grep -q "game.systems.combat" || fail "missing combat"
echo "$out" | grep -q "game.entities.player" || fail "missing player"
pass "multi-seed BFS"

out="$(python3 "$BFS" "$TMP/index.json" "plan.nonexistent" 2>/dev/null)" || true
[ -z "$out" ] || fail "unknown seed should produce no output"
pass "unknown seed → empty"

echo "All bfs-impact tests passed"
