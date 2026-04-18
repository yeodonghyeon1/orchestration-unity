#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
P="$REPO_ROOT/scripts/provenance.py"
FIXTURE="$REPO_ROOT/tests/fixture/provenance-sample.md"

pass() { echo "  ✓ $1"; }
fail() { echo "  ✗ $1" >&2; exit 1; }

TMP="$(mktemp -d)"
if command -v cygpath >/dev/null 2>&1; then
    TMP="$(cygpath -m "$TMP")"
fi
trap 'rm -rf "$TMP"' EXIT

cp "$FIXTURE" "$TMP/doc.md"

cat > "$TMP/new-content.md" <<'EOF'
## Combat Mechanics

UPDATED by refinement.
EOF
python3 "$P" replace "$TMP/doc.md" "notion:plan.combat-system" "$TMP/new-content.md"

grep -q "UPDATED by refinement" "$TMP/doc.md" || fail "notion section not updated"
pass "notion section regenerated"

grep -q "public sealed class CombatSystem" "$TMP/doc.md" || fail "code section wiped!"
pass "code section preserved"

grep -q "Hand-written by the designer" "$TMP/doc.md" || fail "manual section wiped!"
pass "manual section preserved"

cat > "$TMP/new-code-section.md" <<'EOF'
## New API

- `ApplyCritical(...)`
EOF
python3 "$P" append "$TMP/doc.md" "code:Assets/Scripts/NewFile.cs" "$TMP/new-code-section.md"

for marker in "notion:plan.combat-system" "code:Assets/Scripts/CombatSystem.cs" "manual" "code:Assets/Scripts/NewFile.cs"; do
    grep -q "source: $marker" "$TMP/doc.md" || fail "missing marker: $marker"
done
pass "append adds new marker without disturbing others"

echo "All preservation integration tests passed"
