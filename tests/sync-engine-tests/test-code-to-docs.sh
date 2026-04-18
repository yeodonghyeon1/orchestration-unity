#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
C2D="$REPO_ROOT/scripts/code-to-docs.py"
FIX="$REPO_ROOT/tests/fixture/csharp-samples"

pass() { echo "  ✓ $1"; }
fail() { echo "  ✗ $1" >&2; exit 1; }

out="$(python3 "$C2D" "$FIX/CombatSystem.cs")"
echo "$out" | grep -q "class.*CombatSystem" || fail "missing class"
echo "$out" | grep -q "StartCombat" || fail "missing public method"
echo "$out" | grep -q "MaxActionPoints" || fail "missing public property"
pass "class/methods/properties extracted"

if echo "$out" | grep -q "ApplyDamage"; then
    fail "private method leaked into output"
fi
pass "private members excluded"

out="$(python3 "$C2D" "$FIX/DamageFormula.cs")"
echo "$out" | grep -q "static.*DamageFormula" || fail "static class not detected"
echo "$out" | grep -q "Calculate" || fail "static method missing"
pass "static class/methods extracted"

out="$(python3 "$C2D" --frontmatter "$FIX/CombatSystem.cs")"
echo "$out" | grep -q "kind: class" || fail "frontmatter missing kind"
echo "$out" | grep -q "symbol: CombatSystem" || fail "frontmatter missing symbol"
pass "frontmatter mode works"

echo "All code-to-docs tests passed"
