#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
IDX="$REPO_ROOT/scripts/docs-index.py"

pass() { echo "  ✓ $1"; }
fail() { echo "  ✗ $1" >&2; exit 1; }

TMP="$(mktemp -d)"
if command -v cygpath >/dev/null 2>&1; then
    TMP="$(cygpath -m "$TMP")"
fi
trap 'rm -rf "$TMP"' EXIT

mkdir -p "$TMP/develop_docs/game/systems" "$TMP/develop_docs/_meta" "$TMP/develop_docs/game/entities"

cat > "$TMP/develop_docs/game/systems/combat.md" <<'EOF'
---
id: game.systems.combat
title: Combat System
status: stable
source_notion_docs:
  - plan.combat-system
refs:
  - id: game.entities.player
    rel: uses
---
# Combat
EOF

cat > "$TMP/develop_docs/game/entities/player.md" <<'EOF'
---
id: game.entities.player
title: Player
status: stable
source_notion_docs: []
refs: []
---
# Player
EOF

python3 "$IDX" "$TMP/develop_docs"

INDEX="$TMP/develop_docs/_meta/index.json"
[ -f "$INDEX" ] || fail "index.json should exist"

# _self bug fix: parent with children must have _self key
grep -q '"_self"' "$INDEX" || fail "index.json must use _self for parent fields"
pass "_self key present"

# reverse_index must contain plan.combat-system → game.systems.combat
grep -q '"plan.combat-system"' "$INDEX" || fail "reverse_index missing notion id"
pass "reverse_index has notion mappings"

# schema_version must be 2
grep -q '"schema_version": 2' "$INDEX" || fail "schema_version should be 2"
pass "schema_version 2"

echo "All docs-index tests passed"
