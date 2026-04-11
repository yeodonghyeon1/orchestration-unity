#!/usr/bin/env bash
# Tests for scripts/update-docs-index.py
set -euo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$HERE/../.." && pwd)"
SCRIPT="$ROOT/skills/unity-orchestration/scripts/update-docs-index.py"

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

DOCS="$TMP/docs"
mkdir -p "$DOCS/_meta" "$DOCS/game/systems" "$DOCS/tech/modules"

# Seed minimal index.json so the script's idempotent update path is exercised
cat > "$DOCS/_meta/index.json" <<'EOF'
{"version":1,"generated_at":null,"generator":"scripts/update-docs-index.py","project":{"name":"","engine":"","genre":""},"tree":{},"by_tag":{},"by_owner":{},"dangling_references":[],"orphans":[]}
EOF

cat > "$DOCS/README.md" <<'EOF'
---
id: root
title: Project Documentation
owner: recorder
status: stable
updated: 2026-04-11
version: 1
tags: [index]
---
# root
EOF

cat > "$DOCS/game/README.md" <<'EOF'
---
id: game
title: Game
owner: recorder
status: stable
updated: 2026-04-11
version: 1
tags: [index]
---
# game
EOF

cat > "$DOCS/game/systems/combat.md" <<'EOF'
---
id: game.systems.combat
title: Combat
owner: planner
status: stable
updated: 2026-04-11
version: 1
depends_on: [game.overview, tech.modules.input]
tags: [combat]
---
# combat
EOF

cat > "$DOCS/tech/README.md" <<'EOF'
---
id: tech
title: Tech
owner: recorder
status: stable
updated: 2026-04-11
version: 1
tags: [index]
---
# tech
EOF

cat > "$DOCS/tech/modules/input.md" <<'EOF'
---
id: tech.modules.input
title: Input
owner: developer
status: stable
updated: 2026-04-11
version: 1
depends_on: []
tags: []
---
# input
EOF

# Normalize paths for Windows native python3
if command -v cygpath >/dev/null 2>&1; then
  DOCS_ARG="$(cygpath -m "$DOCS")"
  SCRIPT_ARG="$(cygpath -m "$SCRIPT")"
  IDX_ARG="$(cygpath -m "$DOCS/_meta/index.json")"
else
  DOCS_ARG="$DOCS"
  SCRIPT_ARG="$SCRIPT"
  IDX_ARG="$DOCS/_meta/index.json"
fi

python3 "$SCRIPT_ARG" "$DOCS_ARG"

FAILED=0

python3 - "$IDX_ARG" <<'PY'
import json, sys
d = json.load(open(sys.argv[1], encoding='utf-8'))

def fail(msg):
    print("FAIL:", msg)
    sys.exit(1)

# tree has entries we expect
if 'game' not in d['tree']:
    fail("tree missing 'game'")
if 'systems' not in d['tree']['game']:
    fail("tree missing 'game.systems'")
if 'combat' not in d['tree']['game']['systems']:
    fail("combat not in tree")

combat = d['tree']['game']['systems']['combat']
if combat['id']    != 'game.systems.combat':       fail("combat id wrong")
if combat['owner'] != 'planner':                   fail("combat owner wrong")
if 'combat' not in combat['tags']:                 fail("combat tags wrong")

# depends_on preserved
if combat['depends_on'] != ['game.overview', 'tech.modules.input']:
    fail(f"depends_on wrong: {combat['depends_on']}")

# referenced_by populated on tech.modules.input from the combat dependency
inp = d['tree']['tech']['modules']['input']
if 'game.systems.combat' not in inp['referenced_by']:
    fail("referenced_by back-link missing on tech.modules.input")

# by_tag populated
if 'combat' not in d['by_tag'] or 'game.systems.combat' not in d['by_tag']['combat']:
    fail("by_tag missing combat entry")

# by_owner populated
if 'planner' not in d['by_owner']:
    fail("by_owner missing planner")

# dangling: game.overview doesn't exist
if 'game.overview' not in d['dangling_references']:
    fail("dangling_references should contain game.overview")

print("PASS")
PY
status=$?
if [[ $status -ne 0 ]]; then FAILED=1; fi

if [[ $FAILED -eq 0 ]]; then
  echo "update-docs-index.test.sh: PASS"
else
  echo "update-docs-index.test.sh: FAIL"
  exit 1
fi
