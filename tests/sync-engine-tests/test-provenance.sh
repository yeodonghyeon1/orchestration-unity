#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
P="$REPO_ROOT/scripts/provenance.py"

pass() { echo "  ✓ $1"; }
fail() { echo "  ✗ $1" >&2; exit 1; }

TMP="$(mktemp -d)"
if command -v cygpath >/dev/null 2>&1; then
    TMP="$(cygpath -m "$TMP")"
fi
trap 'rm -rf "$TMP"' EXIT

cat > "$TMP/doc.md" <<'EOF'
---
id: game.systems.combat
---
# Combat

<!-- source: notion:plan.combat-system -->
## Combat Mechanics

Notion-sourced text.
<!-- /source -->

<!-- source: code:Assets/Scripts/Combat.cs -->
## Implementation

Code-sourced signatures.
<!-- /source -->

<!-- source: manual -->
## Design Notes

User notes.
<!-- /source -->
EOF

sources="$(python3 "$P" sources "$TMP/doc.md")"
echo "$sources" | grep -q "notion:plan.combat-system" || fail "missing notion source"
echo "$sources" | grep -q "code:Assets/Scripts/Combat.cs" || fail "missing code source"
echo "$sources" | grep -q "^manual$" || fail "missing manual source"
pass "sources extracted"

notion_body="$(python3 "$P" extract "$TMP/doc.md" "notion:plan.combat-system")"
echo "$notion_body" | grep -q "Notion-sourced text" || fail "notion content missing"
echo "$notion_body" | grep -q "Code-sourced" && fail "should NOT include code section"
pass "extract isolates notion section"

cat > "$TMP/new-notion.md" <<'EOF'
## Combat Mechanics

UPDATED Notion content.
EOF
python3 "$P" replace "$TMP/doc.md" "notion:plan.combat-system" "$TMP/new-notion.md"
grep -q "UPDATED Notion content" "$TMP/doc.md" || fail "replace did not write new content"
grep -q "Code-sourced signatures" "$TMP/doc.md" || fail "code section destroyed by replace!"
grep -q "User notes" "$TMP/doc.md" || fail "manual section destroyed by replace!"
pass "replace preserves non-target sections"

cat > "$TMP/new-code-section.md" <<'EOF'
## New Class

class Foo {}
EOF
python3 "$P" append "$TMP/doc.md" "code:Assets/Scripts/New.cs" "$TMP/new-code-section.md"
grep -q "code:Assets/Scripts/New.cs" "$TMP/doc.md" || fail "append did not add new source"
pass "append adds new section with marker"

echo "All provenance tests passed"
