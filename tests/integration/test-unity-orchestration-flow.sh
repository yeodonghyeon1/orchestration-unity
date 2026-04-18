#!/usr/bin/env bash
# Simulates the path through unity-orchestration without invoking actual Claude
# skills or unity-mcp. Verifies that the SCRIPT LAYER (code-doc-updater.sh
# + code-to-docs.py + provenance.py + docs-index.py) behaves correctly as
# a pipeline.
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

# Seed mini project
mkdir -p "$TMP/Assets/Scripts/Combat" "$TMP/ProjectSettings"
cd "$TMP"

# Seed develop_docs with existing unity doc
mkdir -p develop_docs/tech/unity/scripts develop_docs/_meta
cat > develop_docs/tech/unity/scripts/combat-system.md <<'EOF'
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

<!-- source: code:Assets/Scripts/Combat/CombatSystem.cs -->
## Implementation

(empty)
<!-- /source -->
EOF

# Write initial C# (Step 6 simulated outcome)
cat > Assets/Scripts/Combat/CombatSystem.cs <<'EOF'
public sealed class CombatSystem
{
    public void StartCombat() {}
    public int MaxActionPoints => 3;
}
EOF

# Step 9 simulated: verification passed. Step 10 runs updater.
bash "$REPO_ROOT/scripts/code-doc-updater.sh" Assets/Scripts/Combat/CombatSystem.cs

# Verify develop_docs was updated
grep -q "StartCombat" develop_docs/tech/unity/scripts/combat-system.md \
    || fail "develop_docs not updated after Step 10"
pass "Step 10 updated develop_docs"

# Rebuild index after changes
python3 "$REPO_ROOT/scripts/docs-index.py" develop_docs
[ -f develop_docs/_meta/index.json ] || fail "index not rebuilt"
pass "index rebuilt"

# Simulate a code change — add a new method
cat > Assets/Scripts/Combat/CombatSystem.cs <<'EOF'
public sealed class CombatSystem
{
    public void StartCombat() {}
    public void EndCombat() {}
    public int MaxActionPoints => 3;
}
EOF

# Run updater again
bash "$REPO_ROOT/scripts/code-doc-updater.sh" Assets/Scripts/Combat/CombatSystem.cs

# Verify EndCombat is now in develop_docs
grep -q "EndCombat" develop_docs/tech/unity/scripts/combat-system.md \
    || fail "develop_docs did not reflect new method"
pass "subsequent Step 10 reflects code changes"

echo "All unity-orchestration flow integration tests passed"
