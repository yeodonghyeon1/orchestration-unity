# orchestration-unity v1.0 — Slice B: Refinement + /docs-update Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Ship `/docs-refinement` (transforms `notion_docs/` into `develop_docs/`) and `/docs-update` (meta command: sync + refine + commit + push to sync branch), using BFS impact graph for efficient incremental updates.

**Architecture:** New skill `docs-refinement` orchestrates three subsystems: (1) reverse-index construction from `develop_docs/*.md` frontmatter, (2) BFS traversal from changed `notion_docs/*.md` to find affected `develop_docs` files, (3) sub-agent dispatch for parallel refinement. A new `/docs-update` meta command chains `/notion-sync` → `/docs-refinement` → git branch commit + push.

**Tech Stack:** Python 3.9+ (for BFS script), bash (git automation), Claude Code Skill/Command markdown.

**Delivers:**
- `/docs-refinement` slash command
- `/docs-update` meta command (full pipeline + git push to branch)
- `develop_docs/` populated with refined, cross-referenced markdown
- `_meta/index.json` with `reverse_index` for O(1) affected-file lookup
- Unit tests for BFS graph traversal
- Integration test for full pipeline against fixtures

**Reads from spec:** `docs/superpowers/specs/2026-04-18-orchestration-unity-v1-design.md` (Sections 6.2 Step 3, 7.5, 7.6, 8, 9)

**Prerequisites:** Slice A must be complete (scripts + `/notion-sync` working).

---

## File Structure Map

### Create

| Path | Purpose |
|------|---------|
| `scripts/docs-index.py` | Build `_meta/index.json` with tree + reverse_index |
| `scripts/bfs-impact.py` | BFS traversal from changed notion ids → affected develop ids |
| `skills/docs-refinement/SKILL.md` | Skill entry point |
| `skills/docs-refinement/cross-ref-rules.md` | refs[] semantics |
| `skills/docs-refinement/templates/develop-doc-frontmatter.md` | Frontmatter template |
| `commands/docs-refinement.md` | `/docs-refinement` slash command |
| `commands/docs-update.md` | `/docs-update` meta command |
| `tests/sync-engine-tests/test-bfs-impact.sh` | BFS unit tests |
| `tests/sync-engine-tests/test-docs-index.sh` | index builder tests |
| `tests/fixture/develop-docs-sample/` | Sample `develop_docs/` tree for tests |
| `tests/integration/test-docs-refinement.sh` | End-to-end refinement test |
| `tests/integration/test-docs-update.sh` | End-to-end meta command test |

### Modify

| Path | Change |
|------|--------|
| `scripts/update-docs-index.py` | Replace with (or forward to) `scripts/docs-index.py`; fixes `_self` bug |
| `tests/structure-check.sh` | Assert new files exist |
| `CHANGELOG.md` | Append Slice B entries under `[Unreleased]` |
| `.claude-plugin/plugin.json` | Bump to `1.0.0-alpha.2` |

---

## Phase B-1: Index Builder and BFS

### Task 1: `scripts/docs-index.py` — build `_meta/index.json` (TDD)

**Files:**
- Create: `scripts/docs-index.py`
- Test: `tests/sync-engine-tests/test-docs-index.sh`

- [ ] **Step 1: Write the failing test**

Create `tests/sync-engine-tests/test-docs-index.sh`:

```bash
#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
IDX="$REPO_ROOT/scripts/docs-index.py"

pass() { echo "  ✓ $1"; }
fail() { echo "  ✗ $1" >&2; exit 1; }

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

mkdir -p "$TMP/develop_docs/game/systems" "$TMP/develop_docs/_meta"
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

mkdir -p "$TMP/develop_docs/game/entities"
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
```

Make executable.

- [ ] **Step 2: Run to verify failure**

```bash
bash tests/sync-engine-tests/test-docs-index.sh
```

Expected: FAIL (script doesn't exist).

- [ ] **Step 3: Implement `scripts/docs-index.py`**

```python
#!/usr/bin/env python3
"""docs-index.py — build _meta/index.json for a develop_docs/ tree.

Usage:
    python3 scripts/docs-index.py <develop_docs_root>

Outputs:
    <root>/_meta/index.json with schema_version=2, tree, reverse_index.

Fixes v0.2.0 _self bug: parent entries with children now store their
own fields under a _self key rather than mingling with child keys.
"""

import json
import os
import re
import sys
from pathlib import Path

FM_RE = re.compile(r"^---\s*$(.*?)^---\s*$", re.MULTILINE | re.DOTALL)


def parse_frontmatter(text: str) -> dict:
    """Minimal YAML-ish frontmatter parser for our fixed schema."""
    m = FM_RE.search(text)
    if not m:
        return {}
    fm = {}
    current_key = None
    list_buffer = []
    for raw in m.group(1).splitlines():
        line = raw.rstrip()
        if not line or line.startswith("#"):
            continue
        if line.startswith("  - "):
            # list item
            item = line[4:].strip()
            list_buffer.append(item)
            continue
        if list_buffer and current_key:
            fm[current_key] = list_buffer
            list_buffer = []
            current_key = None
        if ":" in line:
            key, _, val = line.partition(":")
            key = key.strip()
            val = val.strip()
            if val == "":
                current_key = key
                list_buffer = []
            else:
                fm[key] = val.strip('"')
                current_key = None
    if list_buffer and current_key:
        fm[current_key] = list_buffer
    return fm


def collect_files(root: Path):
    """Yield (rel_path, frontmatter_dict) for each .md under root (excluding _meta/)."""
    for p in root.rglob("*.md"):
        if "_meta" in p.parts:
            continue
        fm = parse_frontmatter(p.read_text(encoding="utf-8"))
        if "id" in fm:
            rel = p.relative_to(root).as_posix()
            yield rel, fm


def build_tree(entries):
    """Build nested tree with _self for parents, children list."""
    tree = {}
    # First pass: create nodes
    for rel, fm in entries:
        node_id = fm["id"]
        tree[node_id] = {
            "_self": {
                "path": rel,
                "title": fm.get("title", ""),
                "status": fm.get("status", "draft"),
            },
            "children": [],
        }
    # Second pass: link children by id prefix
    ids = sorted(tree.keys(), key=lambda x: x.count("."))
    for node_id in ids:
        parent = ".".join(node_id.split(".")[:-1])
        if parent in tree and parent != node_id:
            tree[parent]["children"].append(node_id)
    return tree


def build_reverse_index(entries):
    """notion id → [develop_docs id, ...]"""
    rev = {}
    for _, fm in entries:
        dev_id = fm["id"]
        for notion_ref in fm.get("source_notion_docs", []):
            # Strip any #anchor suffix
            notion_key = notion_ref.split("#")[0]
            rev.setdefault(notion_key, []).append(dev_id)
    return rev


def main() -> int:
    if len(sys.argv) != 2:
        print("usage: docs-index.py <develop_docs_root>", file=sys.stderr)
        return 2
    root = Path(sys.argv[1])
    if not root.is_dir():
        print(f"error: {root} is not a directory", file=sys.stderr)
        return 2
    entries = list(collect_files(root))
    index = {
        "schema_version": 2,
        "tree": build_tree(entries),
        "reverse_index": build_reverse_index(entries),
    }
    meta = root / "_meta"
    meta.mkdir(parents=True, exist_ok=True)
    out = meta / "index.json"
    tmp = out.with_suffix(".json.tmp")
    tmp.write_text(json.dumps(index, indent=2, ensure_ascii=False), encoding="utf-8")
    os.replace(tmp, out)
    print(f"wrote {out}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
```

Make executable.

- [ ] **Step 4: Run test to verify pass**

```bash
bash tests/sync-engine-tests/test-docs-index.sh
```

Expected: all 3 `✓` marks.

- [ ] **Step 5: Commit**

```bash
git add scripts/docs-index.py tests/sync-engine-tests/test-docs-index.sh
git commit -m "feat(scripts): add docs-index.py with _self bug fix and reverse_index"
```

---

### Task 2: `scripts/bfs-impact.py` — BFS traversal (TDD)

**Files:**
- Create: `scripts/bfs-impact.py`
- Test: `tests/sync-engine-tests/test-bfs-impact.sh`

- [ ] **Step 1: Write the failing test**

Create `tests/sync-engine-tests/test-bfs-impact.sh`:

```bash
#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
BFS="$REPO_ROOT/scripts/bfs-impact.py"

pass() { echo "  ✓ $1"; }
fail() { echo "  ✗ $1" >&2; exit 1; }

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

# Create a minimal index.json with known graph
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

# No refs graph yet — just test reverse_index lookup
out="$(python3 "$BFS" "$TMP/index.json" "plan.combat-system")"
echo "$out" | grep -q "game.systems.combat" || fail "BFS should find game.systems.combat"
pass "direct reverse lookup"

# Multiple seeds
out="$(python3 "$BFS" "$TMP/index.json" "plan.combat-system,plan.player-stats")"
echo "$out" | grep -q "game.systems.combat" || fail "missing combat"
echo "$out" | grep -q "game.entities.player" || fail "missing player"
pass "multi-seed BFS"

# Unknown seed → empty (exit 0)
out="$(python3 "$BFS" "$TMP/index.json" "plan.nonexistent" || true)"
[ -z "$out" ] || fail "unknown seed should produce no output"
pass "unknown seed → empty"

echo "All bfs-impact tests passed"
```

Make executable.

- [ ] **Step 2: Run to verify failure**

```bash
bash tests/sync-engine-tests/test-bfs-impact.sh
```

Expected: FAIL (script missing).

- [ ] **Step 3: Implement `scripts/bfs-impact.py`**

```python
#!/usr/bin/env python3
"""bfs-impact.py — BFS over reverse_index to find impacted develop_docs ids.

Given a list of changed notion_docs ids, traverse the reverse_index and
(optionally in v1) refs-graph forward edges to determine which develop_docs
files must be re-refined.

Usage:
    python3 scripts/bfs-impact.py <index.json> <id1,id2,...>

Prints affected develop_docs ids, one per line.
"""

import json
import sys
from collections import deque


def bfs(index: dict, seeds: list) -> list:
    reverse = index.get("reverse_index", {})
    visited = set()
    queue = deque()

    # Seed from reverse_index
    for seed in seeds:
        for dev_id in reverse.get(seed, []):
            if dev_id not in visited:
                visited.add(dev_id)
                queue.append(dev_id)

    # v1: direct reverse lookup only. refs-graph forward edges in v2.
    # (Cycle safety via visited set.)
    while queue:
        _ = queue.popleft()  # future: follow refs[] edges here
    return sorted(visited)


def main() -> int:
    if len(sys.argv) != 3:
        print("usage: bfs-impact.py <index.json> <id1,id2,...>", file=sys.stderr)
        return 2
    index = json.loads(open(sys.argv[1], "r", encoding="utf-8").read())
    seeds = [s.strip() for s in sys.argv[2].split(",") if s.strip()]
    for impacted in bfs(index, seeds):
        print(impacted)
    return 0


if __name__ == "__main__":
    sys.exit(main())
```

Make executable.

- [ ] **Step 4: Run test to verify pass**

```bash
bash tests/sync-engine-tests/test-bfs-impact.sh
```

Expected: 3 `✓` marks.

- [ ] **Step 5: Commit**

```bash
git add scripts/bfs-impact.py tests/sync-engine-tests/test-bfs-impact.sh
git commit -m "feat(scripts): add bfs-impact.py for reverse-index traversal"
```

---

### Task 3: Retire legacy `update-docs-index.py`

**Files:**
- Modify: `scripts/update-docs-index.py`

- [ ] **Step 1: Replace body with forward-shim**

Open `scripts/update-docs-index.py`. Replace its entire contents with:

```python
#!/usr/bin/env python3
"""Deprecated — forwards to scripts/docs-index.py.

Kept for backward compat with v0.2.0 tests/scripts. New code should
call docs-index.py directly.
"""

import os
import subprocess
import sys


def main() -> int:
    here = os.path.dirname(os.path.abspath(__file__))
    target = os.path.join(here, "docs-index.py")
    return subprocess.call([sys.executable, target, *sys.argv[1:]])


if __name__ == "__main__":
    sys.exit(main())
```

- [ ] **Step 2: Verify no regression**

```bash
bash tests/structure-check.sh
```

Expected: all existing checks pass.

- [ ] **Step 3: Commit**

```bash
git add scripts/update-docs-index.py
git commit -m "refactor(scripts): update-docs-index.py forwards to docs-index.py"
```

---

## Phase B-2: docs-refinement Skill

### Task 4: Scaffold skill + frontmatter template

**Files:**
- Create: `skills/docs-refinement/SKILL.md`
- Create: `skills/docs-refinement/cross-ref-rules.md`
- Create: `skills/docs-refinement/templates/develop-doc-frontmatter.md`

- [ ] **Step 1: Add structure-check assertions**

Append to `tests/structure-check.sh`:

```bash
for f in skills/docs-refinement/SKILL.md \
         skills/docs-refinement/cross-ref-rules.md \
         skills/docs-refinement/templates/develop-doc-frontmatter.md; do
    [ -f "$f" ] || { echo "missing $f"; exit 1; }
done
echo "  ✓ docs-refinement skill scaffold present"
```

- [ ] **Step 2: Run to verify failure**

```bash
bash tests/structure-check.sh
```

Expected: FAIL "missing skills/docs-refinement/SKILL.md".

- [ ] **Step 3: Create `skills/docs-refinement/SKILL.md`**

```markdown
---
name: docs-refinement
description: Use when the user invokes /docs-refinement or asks to transform notion_docs/ into develop_docs/. Reads notion_docs, runs BFS impact graph, dispatches sub-agents to refine affected develop_docs files.
---

# docs-refinement

Transform `notion_docs/` (raw Notion mirror) into `develop_docs/` (refined,
cross-referenced, modular dev tree). Only files whose source Notion pages
changed get regenerated — tracked via `_meta/index.json` reverse_index.

**Announce at start:** "I'm using the docs-refinement skill to rebuild develop_docs/ from notion_docs/."

## Pre-flight

1. `notion_docs/_meta/sync-state.json` exists and has at least one entry.
2. `develop_docs/` directory exists (init-workspace.sh seeds it).

## Three-phase algorithm

### Phase 1: Index
Run `python3 scripts/docs-index.py develop_docs` to produce the current
`develop_docs/_meta/index.json` (tree + reverse_index).

### Phase 2: Impact
Determine the set of changed `notion_docs` ids from the most recent
`/notion-sync` run. (Passed as argument or inferred from git diff of
`notion_docs/`.) Run `python3 scripts/bfs-impact.py` with these ids.
Output: affected `develop_docs` ids.

### Phase 3: Refine (parallel dispatch)
For each affected id:
1. Resolve its file path from the index.
2. Load the source `notion_docs` files via `source_notion_docs[]`.
3. Dispatch a sub-agent with the prompt from `cross-ref-rules.md` and the
   source content.
4. Sub-agent produces the refined file content.
5. Main writes the file atomically.

After all files are written, re-run `docs-index.py` to refresh the index.

## Refinement rules

The sub-agent transforming notion content into develop_docs must follow:
1. Preserve structure (H2/H3 hierarchy)
2. No creative rewrite — structural reorganization and summarization only
3. Fill frontmatter per template (`templates/develop-doc-frontmatter.md`)
4. Populate `refs[]` by detecting @mentions and cross-page references
5. Compute `refinement_hash` = SHA256 of concatenated `source_notion_docs` hashes

See `cross-ref-rules.md` for detailed cross-reference semantics.

## Forbidden actions

- Do NOT call Notion MCP directly — only read from `notion_docs/`
- Do NOT write to `notion_docs/` — it's sync-engine-owned
- Do NOT modify `_meta/sync-state.json` — that's notion-sync's responsibility
- Do NOT refine files that are not in the affected list (YAGNI — those are unchanged)
```

- [ ] **Step 4: Create `skills/docs-refinement/cross-ref-rules.md`**

```markdown
---
id: skills.docs-refinement.cross-ref-rules
title: Cross-Reference Rules for develop_docs
status: stable
updated: 2026-04-18
---

# Cross-Reference Rules

## refs[] relationship types

| rel | Meaning | BFS propagation |
|-----|---------|-----------------|
| `uses` | A consumes B's API or data | B changes → A re-refine |
| `extends` | A specializes B | B changes → A re-refine |
| `contradicts` | A and B conflict | No propagation; warning only |
| `supersedes` | A replaces B (B deprecated) | Reverse only |

## Detection

- `@mention` in Notion → `refs: [{id: <mentioned-page-id>, rel: uses}]` (default rel: uses)
- Explicit "extends X" or "based on X" in body → rel: extends
- Explicit "conflicts with X" → rel: contradicts
- Explicit "replaces X" or "deprecates X" → rel: supersedes

## source_notion_docs semantics

Every refined section must declare its source(s). Format:

```yaml
source_notion_docs:
  - plan.combat-system              # whole page
  - plan.combat-system#damage       # specific section by anchor
```

## Hash scoping (from spec Section 17.8)

`refinement_hash` is computed only over `source: notion:*` sections to keep
refinement idempotent under dual-origin content. Code-derived and
manual sections are excluded.
```

- [ ] **Step 5: Create `skills/docs-refinement/templates/develop-doc-frontmatter.md`**

```markdown
---
id: {{path_id}}
title: "{{title}}"
status: draft

source_notion_docs:
{{source_notion_list}}

refs:
{{refs_list}}

owner: claude
last_refined: "{{last_refined}}"
refinement_hash: "{{refinement_hash}}"

section_sources:
{{section_sources}}

code_references:
{{code_references}}
---

{{markdown_body}}
```

Slice C will populate `section_sources` and `code_references`; Slice B leaves
them empty `{}` / `[]`.

- [ ] **Step 6: Run structure-check**

```bash
bash tests/structure-check.sh
```

Expected: pass including `✓ docs-refinement skill scaffold present`.

- [ ] **Step 7: Commit**

```bash
git add skills/docs-refinement/ tests/structure-check.sh
git commit -m "feat(skills): scaffold docs-refinement skill with cross-ref rules"
```

---

### Task 5: Create `/docs-refinement` slash command

**Files:**
- Create: `commands/docs-refinement.md`

- [ ] **Step 1: Add structure-check assertion**

```bash
[ -f "commands/docs-refinement.md" ] || { echo "missing"; exit 1; }
echo "  ✓ /docs-refinement command present"
```

- [ ] **Step 2: Verify failure**

```bash
bash tests/structure-check.sh
```

Expected: FAIL.

- [ ] **Step 3: Create the command**

```markdown
---
description: Refine notion_docs/ into develop_docs/ via BFS impact graph
argument-hint: (optional) comma-separated notion_docs ids to force-refine
---

# /docs-refinement

Transform `notion_docs/` into `develop_docs/` using the docs-refinement skill.

Invoke via:

```
Skill('docs-refinement')
```

If the user passes arguments (notion_docs ids), treat them as forced seeds
for BFS (useful for partial refresh).

The skill will:
1. Run `scripts/docs-index.py` to refresh the index
2. Determine changed ids (from git diff of `notion_docs/` since last refinement)
3. Run `scripts/bfs-impact.py` to find affected develop_docs
4. Dispatch sub-agents to refine each affected file
5. Re-run `docs-index.py` to update the index

Does NOT commit or push — that's `/docs-update`'s job.
```

- [ ] **Step 4: Run structure-check**

```bash
bash tests/structure-check.sh
```

Expected: pass.

- [ ] **Step 5: Commit**

```bash
git add commands/docs-refinement.md tests/structure-check.sh
git commit -m "feat(commands): add /docs-refinement slash command"
```

---

## Phase B-3: /docs-update Meta Command

### Task 6: Create `/docs-update` with git automation

**Files:**
- Create: `commands/docs-update.md`

- [ ] **Step 1: Add structure-check assertion**

```bash
[ -f "commands/docs-update.md" ] || { echo "missing"; exit 1; }
echo "  ✓ /docs-update command present"
```

- [ ] **Step 2: Verify failure**

```bash
bash tests/structure-check.sh
```

- [ ] **Step 3: Create the command**

```markdown
---
description: Full pipeline — /notion-sync + /docs-refinement + git branch commit and push
argument-hint: (no arguments)
---

# /docs-update

Run the complete docs pipeline as one atomic operation:

1. **Pre-check** — `git status` must show clean `notion_docs/` and `develop_docs/`.
   If dirty, abort and ask user to commit or stash first.

2. **Create sync branch** — branch name format: `sync/notion-YYYYMMDD-HHMM`.
   ```bash
   ts=$(date -u '+%Y%m%d-%H%M')
   git checkout -b "sync/notion-$ts"
   ```

3. **Run `/notion-sync`** — invoke the notion-sync skill.

4. **Commit `notion_docs/` changes** (if any) —
   ```bash
   git add notion_docs/
   git diff --cached --quiet || git commit -m "sync(notion): mirror Notion pages to notion_docs/"
   ```

5. **Run `/docs-refinement`** — invoke the docs-refinement skill.

6. **Commit `develop_docs/` changes** (if any) —
   ```bash
   git add develop_docs/
   git diff --cached --quiet || git commit -m "refine(docs): regenerate affected develop_docs"
   ```

7. **Push to origin** —
   ```bash
   git push -u origin "sync/notion-$ts"
   ```
   On push failure: keep local branch, print recovery command, do NOT rollback.

8. **Report** — emit summary:
   ```
   sync branch: sync/notion-YYYYMMDD-HHMM
   commits: 2 (notion_docs, develop_docs)
   pushed: yes/no (with PR URL if available via gh)
   next: review and merge via PR; main is untouched.
   ```

## Forbidden

- Do NOT switch to `main` or merge the sync branch — human does that.
- Do NOT force-push.
- Do NOT skip the pre-check (must have clean working tree).
```

- [ ] **Step 4: Run structure-check**

```bash
bash tests/structure-check.sh
```

Expected: pass.

- [ ] **Step 5: Commit**

```bash
git add commands/docs-update.md tests/structure-check.sh
git commit -m "feat(commands): add /docs-update meta command with git branch automation"
```

---

## Phase B-4: Integration Tests

### Task 7: Sample `develop_docs/` fixture + end-to-end refinement test

**Files:**
- Create: `tests/fixture/develop-docs-sample/game/systems/combat.md`
- Create: `tests/fixture/develop-docs-sample/game/entities/player.md`
- Create: `tests/integration/test-docs-refinement.sh`

- [ ] **Step 1: Write the two sample develop_docs files**

`tests/fixture/develop-docs-sample/game/systems/combat.md`:
```markdown
---
id: game.systems.combat
title: Combat System
status: stable
source_notion_docs:
  - uuid-plan
refs:
  - id: game.entities.player
    rel: uses
---
# Combat System

(sample)
```

`tests/fixture/develop-docs-sample/game/entities/player.md`:
```markdown
---
id: game.entities.player
title: Player
status: stable
source_notion_docs: []
refs: []
---
# Player
```

- [ ] **Step 2: Write integration test**

`tests/integration/test-docs-refinement.sh`:

```bash
#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

pass() { echo "  ✓ $1"; }
fail() { echo "  ✗ $1" >&2; exit 1; }

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

# Copy fixture
cp -r "$REPO_ROOT/tests/fixture/develop-docs-sample/"* "$TMP/"
mkdir -p "$TMP/develop_docs"
mv "$TMP/game" "$TMP/develop_docs/"

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
```

Make executable.

- [ ] **Step 3: Run test**

```bash
bash tests/integration/test-docs-refinement.sh
```

Expected: 4 `✓` marks.

- [ ] **Step 4: Commit**

```bash
git add tests/fixture/develop-docs-sample/ tests/integration/test-docs-refinement.sh
git commit -m "test(integration): docs-refinement end-to-end with sample develop_docs"
```

---

## Phase B-5: Release Metadata

### Task 8: Update CHANGELOG and version

**Files:**
- Modify: `CHANGELOG.md`
- Modify: `.claude-plugin/plugin.json`

- [ ] **Step 1: Bump plugin.json**

Change `"version": "1.0.0-alpha.1"` to `"version": "1.0.0-alpha.2"`.

- [ ] **Step 2: Append to CHANGELOG `[Unreleased]` section**

Under Slice A entries, add:

```markdown
### Slice B (Refinement + /docs-update) — this release candidate
- Added `scripts/docs-index.py` with `_self` bug fix and reverse_index
- Added `scripts/bfs-impact.py` for reverse-index BFS traversal
- Added `skills/docs-refinement/` — notion_docs → develop_docs pipeline
- Added `commands/docs-refinement.md` — `/docs-refinement` slash command
- Added `commands/docs-update.md` — `/docs-update` meta command with git branch automation
- Added sample develop_docs fixture + integration test
- `scripts/update-docs-index.py` now forwards to `docs-index.py` (backward compat shim)
```

- [ ] **Step 3: Commit**

```bash
git add CHANGELOG.md .claude-plugin/plugin.json
git commit -m "chore: bump to 1.0.0-alpha.2 with Slice B CHANGELOG entry"
```

---

## Completion Criteria (Slice B Done)

- [ ] `bash tests/structure-check.sh` passes
- [ ] `bash tests/sync-engine-tests/test-docs-index.sh` passes
- [ ] `bash tests/sync-engine-tests/test-bfs-impact.sh` passes
- [ ] `bash tests/integration/test-docs-refinement.sh` passes
- [ ] `.claude-plugin/plugin.json` version = `1.0.0-alpha.2`
- [ ] 8 commits on main branch (one per Task 1-8)
- [ ] Manual smoke test: running `/docs-update` on a Unity project with a simulated Notion state produces a sync branch and no errors

Proceed to Slice C: Living Knowledge Base (provenance markers + code→docs).
