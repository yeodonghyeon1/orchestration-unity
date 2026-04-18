#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
UP="$REPO_ROOT/scripts/code-doc-updater.sh"

pass() { echo "  ✓ $1"; }
fail() { echo "  ✗ $1" >&2; exit 1; }

TMP="$(mktemp -d)"
if command -v cygpath >/dev/null 2>&1; then
    TMP="$(cygpath -m "$TMP")"
fi
trap 'rm -rf "$TMP"' EXIT

mkdir -p "$TMP/Assets/Scripts/Combat"
cat > "$TMP/Assets/Scripts/Combat/CombatSystem.cs" <<'EOF'
public sealed class CombatSystem {
    public void StartCombat() {}
}
EOF

mkdir -p "$TMP/develop_docs/tech/unity/scripts"
cat > "$TMP/develop_docs/tech/unity/scripts/combat-system.md" <<'EOF'
---
id: tech.unity.scripts.combat-system
title: CombatSystem
source_notion_docs: []
code_references:
  - path: Assets/Scripts/Combat/CombatSystem.cs
    kind: class
    symbol: CombatSystem
---
# CombatSystem

<!-- source: notion:plan.combat-system -->
## Overview

Notion content.
<!-- /source -->

<!-- source: code:Assets/Scripts/Combat/CombatSystem.cs -->
## Implementation

(stale)
<!-- /source -->
EOF

(cd "$TMP" && bash "$UP" Assets/Scripts/Combat/CombatSystem.cs)

grep -q "StartCombat" "$TMP/develop_docs/tech/unity/scripts/combat-system.md" || fail "code section did not update"
pass "code section regenerated"

grep -q "Notion content" "$TMP/develop_docs/tech/unity/scripts/combat-system.md" || fail "notion section wiped"
pass "notion section preserved"

if grep -q "(stale)" "$TMP/develop_docs/tech/unity/scripts/combat-system.md"; then
    fail "stale code content not replaced"
fi
pass "stale content removed"

echo "All code-doc-updater tests passed"
