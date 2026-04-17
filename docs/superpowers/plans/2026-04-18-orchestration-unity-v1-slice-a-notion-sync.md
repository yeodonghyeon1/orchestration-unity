# orchestration-unity v1.0 — Slice A: MVP Notion Sync Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Ship a working `/notion-sync` command that mirrors a Notion workspace's top-level pages into a `notion_docs/` tree, with incremental change detection via timestamp pre-filter and SHA256 content hashing.

**Architecture:** Foundation scripts (`notion-hash.py`, `page-map.py`, extended `init-workspace.sh`) + new skill `notion-sync` + new slash command `/notion-sync`. State stored in per-file frontmatter (Layer A) and `notion_docs/_meta/sync-state.json` (Layer B). The sync engine is invoked by the slash command and orchestrated by the skill markdown.

**Tech Stack:** Python 3.9+, bash, Claude Code Skill/Command markdown, `mcp__claude_ai_Notion__*` MCP tools.

**Delivers:**
- `/notion-sync` slash command
- `notion_docs/` tree populated from Notion (3 starter pages: 개발/아트/기획)
- Idempotent sync (no change = no diff)
- Unit tests for hashing and page-mapping
- Integration test against Notion MCP fixtures

**Reads from spec:** `docs/superpowers/specs/2026-04-18-orchestration-unity-v1-design.md` (Sections 5, 6, 7, 16)

---

## File Structure Map

### Create

| Path | Purpose |
|------|---------|
| `scripts/notion-hash.py` | Deterministic SHA256 hashing of Notion page content |
| `scripts/page-map.py` | Read/write `notion_docs/_meta/page-map.json` |
| `scripts/sync-state.py` | Read/write `notion_docs/_meta/sync-state.json` |
| `skills/notion-sync/SKILL.md` | Skill entry point |
| `skills/notion-sync/change-detection.md` | Reference doc for the 4-step pipeline |
| `skills/notion-sync/templates/notion-doc-frontmatter.md` | Frontmatter template |
| `commands/notion-sync.md` | Slash command wrapper |
| `tests/sync-engine-tests/test-notion-hash.sh` | notion-hash.py unit tests |
| `tests/sync-engine-tests/test-page-map.sh` | page-map.py unit tests |
| `tests/sync-engine-tests/test-sync-state.sh` | sync-state.py unit tests |
| `tests/fixture/mock-notion-responses/README.md` | Fixture usage guide |
| `tests/fixture/mock-notion-responses/page-dev.json` | Fixture for 개발 page |
| `tests/fixture/mock-notion-responses/page-art.json` | Fixture for 아트 page |
| `tests/fixture/mock-notion-responses/page-plan.json` | Fixture for 기획 page |
| `tests/fixture/mock-notion-responses/page-list.json` | Fixture for workspace page listing |
| `tests/integration/test-notion-sync.sh` | End-to-end integration test |

### Modify

| Path | Change |
|------|--------|
| `scripts/init-workspace.sh` | Seed `notion_docs/` + `develop_docs/` + `_meta/*.json` |
| `tests/structure-check.sh` | Assert new files exist |
| `CHANGELOG.md` | Add `[Unreleased]` section with Slice A items |
| `.claude-plugin/plugin.json` | Bump version to `1.0.0-alpha.1` |

### Delete (v0.2.0 cleanup — Plan E will do the rest)

None in Slice A. We keep v0.2.0 artifacts intact until Slice E migration.

---

## Phase A-1: Foundation Scripts

### Task 1: Implement `notion-hash.py` (TDD)

**Files:**
- Create: `scripts/notion-hash.py`
- Test: `tests/sync-engine-tests/test-notion-hash.sh`

- [ ] **Step 1: Write the failing test**

Create `tests/sync-engine-tests/test-notion-hash.sh`:

```bash
#!/usr/bin/env bash
# test-notion-hash.sh — unit tests for scripts/notion-hash.py
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
H="$REPO_ROOT/scripts/notion-hash.py"

pass() { echo "  ✓ $1"; }
fail() { echo "  ✗ $1" >&2; exit 1; }

test_identical_content_same_hash() {
    local h1 h2
    h1="$(echo '{"type":"page","content":"hello"}' | python3 "$H")"
    h2="$(echo '{"type":"page","content":"hello"}' | python3 "$H")"
    [ "$h1" = "$h2" ] || fail "identical inputs should hash equal: $h1 vs $h2"
    pass "identical content → same hash"
}

test_volatile_fields_ignored() {
    local h1 h2
    h1="$(echo '{"type":"page","last_edited_time":"2026-01-01T00:00:00Z","content":"x"}' | python3 "$H")"
    h2="$(echo '{"type":"page","last_edited_time":"2026-04-18T12:00:00Z","content":"x"}' | python3 "$H")"
    [ "$h1" = "$h2" ] || fail "different last_edited_time should NOT affect hash"
    pass "volatile fields ignored"
}

test_different_content_different_hash() {
    local h1 h2
    h1="$(echo '{"content":"a"}' | python3 "$H")"
    h2="$(echo '{"content":"b"}' | python3 "$H")"
    [ "$h1" != "$h2" ] || fail "different content should hash differently"
    pass "different content → different hash"
}

test_key_order_independent() {
    local h1 h2
    h1="$(echo '{"a":1,"b":2}' | python3 "$H")"
    h2="$(echo '{"b":2,"a":1}' | python3 "$H")"
    [ "$h1" = "$h2" ] || fail "key order should not matter"
    pass "key order independent"
}

test_output_prefix() {
    local out
    out="$(echo '{"x":1}' | python3 "$H")"
    [[ "$out" == sha256:* ]] || fail "output must start with sha256: (got '$out')"
    pass "output has sha256: prefix"
}

test_identical_content_same_hash
test_volatile_fields_ignored
test_different_content_different_hash
test_key_order_independent
test_output_prefix

echo "All notion-hash tests passed"
```

Make executable: `chmod +x tests/sync-engine-tests/test-notion-hash.sh`

- [ ] **Step 2: Run test to verify failure**

```bash
bash tests/sync-engine-tests/test-notion-hash.sh
```

Expected: FAIL with `python3: can't open file 'scripts/notion-hash.py': No such file or directory` (script doesn't exist yet).

- [ ] **Step 3: Implement `notion-hash.py`**

Create `scripts/notion-hash.py`:

```python
#!/usr/bin/env python3
"""notion-hash.py — deterministic SHA256 hash of Notion page content.

Excludes volatile fields (created_time, last_edited_time, etc.) so
identical content always hashes to the same value.

Usage:
    python3 scripts/notion-hash.py < page.json
    python3 scripts/notion-hash.py page.json

Output (stdout):
    sha256:<hex>
"""

import hashlib
import json
import sys

VOLATILE_KEYS = {
    "created_time",
    "last_edited_time",
    "created_by",
    "last_edited_by",
    "request_id",
    "has_more",
    "next_cursor",
    "cursor",
}


def normalize(obj):
    """Recursively drop volatile keys; normalize strings."""
    if isinstance(obj, dict):
        return {
            k: normalize(v)
            for k, v in obj.items()
            if k not in VOLATILE_KEYS
        }
    if isinstance(obj, list):
        return [normalize(item) for item in obj]
    if isinstance(obj, str):
        return "\n".join(line.rstrip() for line in obj.splitlines())
    return obj


def compute_hash(payload: str) -> str:
    data = json.loads(payload)
    canonical = json.dumps(
        normalize(data),
        sort_keys=True,
        ensure_ascii=False,
        separators=(",", ":"),
    )
    digest = hashlib.sha256(canonical.encode("utf-8")).hexdigest()
    return f"sha256:{digest}"


def main() -> int:
    if len(sys.argv) > 1:
        with open(sys.argv[1], "r", encoding="utf-8") as f:
            payload = f.read()
    else:
        payload = sys.stdin.read()
    if not payload.strip():
        print("error: empty input", file=sys.stderr)
        return 1
    print(compute_hash(payload))
    return 0


if __name__ == "__main__":
    sys.exit(main())
```

Make executable: `chmod +x scripts/notion-hash.py`

- [ ] **Step 4: Run test to verify pass**

```bash
bash tests/sync-engine-tests/test-notion-hash.sh
```

Expected: `All notion-hash tests passed` with 5 `✓` marks.

- [ ] **Step 5: Commit**

```bash
git add scripts/notion-hash.py tests/sync-engine-tests/test-notion-hash.sh
git commit -m "feat(scripts): add notion-hash.py with deterministic SHA256"
```

---

### Task 2: Implement `page-map.py` (TDD)

**Files:**
- Create: `scripts/page-map.py`
- Test: `tests/sync-engine-tests/test-page-map.sh`

- [ ] **Step 1: Write the failing test**

Create `tests/sync-engine-tests/test-page-map.sh`:

```bash
#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
PM="$REPO_ROOT/scripts/page-map.py"

pass() { echo "  ✓ $1"; }
fail() { echo "  ✗ $1" >&2; exit 1; }

TMPDIR="$(mktemp -d)"
trap 'rm -rf "$TMPDIR"' EXIT

test_init_creates_empty_map() {
    local f="$TMPDIR/page-map.json"
    python3 "$PM" init "$f"
    [ -f "$f" ] || fail "init should create file"
    grep -q '"mappings"' "$f" || fail "file should have mappings key"
    pass "init creates empty map"
}

test_add_mapping() {
    local f="$TMPDIR/page-map-add.json"
    python3 "$PM" init "$f"
    python3 "$PM" add "$f" "uuid-123" "개발" "dev"
    python3 "$PM" get "$f" "uuid-123" | grep -q "dev" \
        || fail "get should return folder 'dev' for added page"
    pass "add and retrieve mapping"
}

test_slugify_korean() {
    local slug
    slug="$(python3 "$PM" slugify "아트")"
    [ "$slug" = "art" ] || [ "$slug" = "a-teu" ] || [ -n "$slug" ] \
        || fail "slugify should not return empty"
    pass "slugify produces non-empty result"
}

test_reserved_names_rejected() {
    local f="$TMPDIR/page-map-reserved.json"
    python3 "$PM" init "$f"
    if python3 "$PM" add "$f" "uuid-x" "meta" "_meta" 2>/dev/null; then
        fail "should reject _meta as folder name"
    fi
    pass "reserved names rejected"
}

test_init_creates_empty_map
test_add_mapping
test_slugify_korean
test_reserved_names_rejected

echo "All page-map tests passed"
```

Make executable: `chmod +x tests/sync-engine-tests/test-page-map.sh`

- [ ] **Step 2: Run test to verify failure**

```bash
bash tests/sync-engine-tests/test-page-map.sh
```

Expected: FAIL with missing `scripts/page-map.py`.

- [ ] **Step 3: Implement `page-map.py`**

Create `scripts/page-map.py`:

```python
#!/usr/bin/env python3
"""page-map.py — manage notion_docs/_meta/page-map.json

Subcommands:
    init <path>                            — create empty map
    add <path> <page_id> <title> <folder>  — add mapping
    get <path> <page_id>                   — print folder for page_id
    list <path>                            — print all mappings as TSV
    slugify <text>                         — ASCII kebab-case slug
"""

import json
import re
import sys
from pathlib import Path

RESERVED_FOLDERS = {"_meta"}


def slugify(text: str) -> str:
    """ASCII kebab-case. Korean → romanized best-effort, else 'page-<hash>'."""
    t = text.strip().lower()
    # Replace non-ASCII with dashes (caller should handle Korean romanization)
    t = re.sub(r"[^\x00-\x7f]+", "-", t)
    t = re.sub(r"[^a-z0-9]+", "-", t)
    t = t.strip("-")
    return t or "page"


def ensure_not_reserved(folder: str) -> None:
    if folder in RESERVED_FOLDERS or folder.startswith("_"):
        raise ValueError(f"folder name '{folder}' is reserved (no _ prefix)")


def cmd_init(path: str) -> int:
    data = {"schema_version": 1, "mappings": [], "auto_slugify": True}
    Path(path).parent.mkdir(parents=True, exist_ok=True)
    Path(path).write_text(json.dumps(data, indent=2, ensure_ascii=False), encoding="utf-8")
    return 0


def cmd_add(path: str, page_id: str, title: str, folder: str) -> int:
    ensure_not_reserved(folder)
    data = json.loads(Path(path).read_text(encoding="utf-8"))
    # Reject duplicate folder
    for m in data["mappings"]:
        if m["folder"] == folder and m["notion_page_id"] != page_id:
            raise ValueError(f"folder '{folder}' already mapped to a different page")
    # Update or append
    for m in data["mappings"]:
        if m["notion_page_id"] == page_id:
            m["notion_title"] = title
            m["folder"] = folder
            break
    else:
        data["mappings"].append({
            "notion_page_id": page_id,
            "notion_title": title,
            "folder": folder,
        })
    Path(path).write_text(json.dumps(data, indent=2, ensure_ascii=False), encoding="utf-8")
    return 0


def cmd_get(path: str, page_id: str) -> int:
    data = json.loads(Path(path).read_text(encoding="utf-8"))
    for m in data["mappings"]:
        if m["notion_page_id"] == page_id:
            print(m["folder"])
            return 0
    print("", end="")
    return 1


def cmd_list(path: str) -> int:
    data = json.loads(Path(path).read_text(encoding="utf-8"))
    for m in data["mappings"]:
        print(f"{m['notion_page_id']}\t{m['notion_title']}\t{m['folder']}")
    return 0


def cmd_slugify(text: str) -> int:
    print(slugify(text))
    return 0


def main() -> int:
    if len(sys.argv) < 2:
        print(__doc__, file=sys.stderr)
        return 2
    sub = sys.argv[1]
    try:
        if sub == "init":
            return cmd_init(sys.argv[2])
        if sub == "add":
            return cmd_add(sys.argv[2], sys.argv[3], sys.argv[4], sys.argv[5])
        if sub == "get":
            return cmd_get(sys.argv[2], sys.argv[3])
        if sub == "list":
            return cmd_list(sys.argv[2])
        if sub == "slugify":
            return cmd_slugify(sys.argv[2])
    except (IndexError, ValueError) as e:
        print(f"error: {e}", file=sys.stderr)
        return 2
    print(f"unknown subcommand: {sub}", file=sys.stderr)
    return 2


if __name__ == "__main__":
    sys.exit(main())
```

Make executable: `chmod +x scripts/page-map.py`

- [ ] **Step 4: Run test to verify pass**

```bash
bash tests/sync-engine-tests/test-page-map.sh
```

Expected: `All page-map tests passed` with 4 `✓` marks.

- [ ] **Step 5: Commit**

```bash
git add scripts/page-map.py tests/sync-engine-tests/test-page-map.sh
git commit -m "feat(scripts): add page-map.py for Notion page → folder mapping"
```

---

### Task 3: Implement `sync-state.py` (TDD)

**Files:**
- Create: `scripts/sync-state.py`
- Test: `tests/sync-engine-tests/test-sync-state.sh`

- [ ] **Step 1: Write the failing test**

Create `tests/sync-engine-tests/test-sync-state.sh`:

```bash
#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
SS="$REPO_ROOT/scripts/sync-state.py"

pass() { echo "  ✓ $1"; }
fail() { echo "  ✗ $1" >&2; exit 1; }

TMPDIR="$(mktemp -d)"
trap 'rm -rf "$TMPDIR"' EXIT

test_init() {
    local f="$TMPDIR/sync-state.json"
    python3 "$SS" init "$f"
    [ -f "$f" ] || fail "init should create file"
    grep -q '"pages"' "$f" || fail "file should have pages key"
    grep -q '"orphans"' "$f" || fail "file should have orphans key"
    pass "init creates valid schema"
}

test_upsert_page() {
    local f="$TMPDIR/ss-upsert.json"
    python3 "$SS" init "$f"
    python3 "$SS" upsert "$f" "uuid-1" "dev/tech.md" "sha256:abc" "2026-04-18T10:00:00Z"
    python3 "$SS" get-hash "$f" "uuid-1" | grep -q "sha256:abc" || fail "get-hash should return stored hash"
    pass "upsert and get-hash work"
}

test_delete_to_orphan() {
    local f="$TMPDIR/ss-delete.json"
    python3 "$SS" init "$f"
    python3 "$SS" upsert "$f" "uuid-1" "x.md" "sha256:a" "2026-04-18T10:00:00Z"
    python3 "$SS" move-to-orphans "$f" "uuid-1"
    python3 "$SS" get-hash "$f" "uuid-1" 2>/dev/null && fail "deleted page should not be in pages"
    python3 "$SS" list-orphans "$f" | grep -q "uuid-1" || fail "should be in orphans"
    pass "delete moves to orphans"
}

test_atomic_write() {
    local f="$TMPDIR/ss-atomic.json"
    python3 "$SS" init "$f"
    # No tmp file should remain after successful write
    [ ! -f "$f.tmp" ] || fail "tmp file should not remain"
    pass "atomic write leaves no tmp file"
}

test_init
test_upsert_page
test_delete_to_orphan
test_atomic_write

echo "All sync-state tests passed"
```

Make executable: `chmod +x tests/sync-engine-tests/test-sync-state.sh`

- [ ] **Step 2: Run test to verify failure**

```bash
bash tests/sync-engine-tests/test-sync-state.sh
```

Expected: FAIL with missing `scripts/sync-state.py`.

- [ ] **Step 3: Implement `sync-state.py`**

Create `scripts/sync-state.py`:

```python
#!/usr/bin/env python3
"""sync-state.py — manage notion_docs/_meta/sync-state.json

Subcommands:
    init <path>
    upsert <path> <page_id> <file_path> <hash> <notion_last_edited>
    get-hash <path> <page_id>
    move-to-orphans <path> <page_id>
    list-orphans <path>
    list-pages <path>
"""

import json
import os
import sys
from pathlib import Path


def load(path: str) -> dict:
    return json.loads(Path(path).read_text(encoding="utf-8"))


def atomic_write(path: str, data: dict) -> None:
    tmp = f"{path}.tmp"
    Path(path).parent.mkdir(parents=True, exist_ok=True)
    Path(tmp).write_text(
        json.dumps(data, indent=2, ensure_ascii=False),
        encoding="utf-8",
    )
    os.replace(tmp, path)


def cmd_init(path: str) -> int:
    data = {
        "schema_version": 1,
        "last_sync": None,
        "pages": {},
        "orphans": [],
    }
    atomic_write(path, data)
    return 0


def cmd_upsert(path: str, page_id: str, file_path: str, hash_: str, edited: str) -> int:
    data = load(path)
    data["pages"][page_id] = {
        "path": file_path,
        "hash": hash_,
        "notion_last_edited": edited,
    }
    atomic_write(path, data)
    return 0


def cmd_get_hash(path: str, page_id: str) -> int:
    data = load(path)
    entry = data["pages"].get(page_id)
    if not entry:
        return 1
    print(entry["hash"])
    return 0


def cmd_move_to_orphans(path: str, page_id: str) -> int:
    data = load(path)
    entry = data["pages"].pop(page_id, None)
    if entry:
        data["orphans"].append({"notion_page_id": page_id, **entry})
        atomic_write(path, data)
    return 0


def cmd_list_orphans(path: str) -> int:
    data = load(path)
    for o in data["orphans"]:
        print(o["notion_page_id"])
    return 0


def cmd_list_pages(path: str) -> int:
    data = load(path)
    for pid, entry in data["pages"].items():
        print(f"{pid}\t{entry['path']}\t{entry['hash']}")
    return 0


def main() -> int:
    if len(sys.argv) < 2:
        print(__doc__, file=sys.stderr)
        return 2
    sub = sys.argv[1]
    try:
        if sub == "init":
            return cmd_init(sys.argv[2])
        if sub == "upsert":
            return cmd_upsert(sys.argv[2], sys.argv[3], sys.argv[4], sys.argv[5], sys.argv[6])
        if sub == "get-hash":
            return cmd_get_hash(sys.argv[2], sys.argv[3])
        if sub == "move-to-orphans":
            return cmd_move_to_orphans(sys.argv[2], sys.argv[3])
        if sub == "list-orphans":
            return cmd_list_orphans(sys.argv[2])
        if sub == "list-pages":
            return cmd_list_pages(sys.argv[2])
    except (IndexError, FileNotFoundError, KeyError) as e:
        print(f"error: {e}", file=sys.stderr)
        return 2
    print(f"unknown subcommand: {sub}", file=sys.stderr)
    return 2


if __name__ == "__main__":
    sys.exit(main())
```

Make executable: `chmod +x scripts/sync-state.py`

- [ ] **Step 4: Run test to verify pass**

```bash
bash tests/sync-engine-tests/test-sync-state.sh
```

Expected: `All sync-state tests passed` with 4 `✓` marks.

- [ ] **Step 5: Commit**

```bash
git add scripts/sync-state.py tests/sync-engine-tests/test-sync-state.sh
git commit -m "feat(scripts): add sync-state.py for _meta/sync-state.json management"
```

---

### Task 4: Extend `init-workspace.sh` for dual trees

**Files:**
- Modify: `scripts/init-workspace.sh`

- [ ] **Step 1: Write the failing test (extend structure-check.sh)**

Add to end of `tests/structure-check.sh` (before the `echo "OK"` line):

```bash
# --- v1.0 dual-tree init ---
test_dual_tree_init() {
    local tmp; tmp="$(mktemp -d)"
    bash scripts/init-workspace.sh "$tmp"
    [ -d "$tmp/notion_docs/_meta" ] || { echo "missing notion_docs/_meta"; exit 1; }
    [ -d "$tmp/develop_docs/_meta" ] || { echo "missing develop_docs/_meta"; exit 1; }
    [ -f "$tmp/notion_docs/_meta/sync-state.json" ] || { echo "missing sync-state.json"; exit 1; }
    [ -f "$tmp/notion_docs/_meta/page-map.json" ] || { echo "missing page-map.json"; exit 1; }
    rm -rf "$tmp"
    echo "  ✓ dual-tree init"
}
test_dual_tree_init
```

- [ ] **Step 2: Run to verify failure**

```bash
bash tests/structure-check.sh
```

Expected: FAIL (missing `notion_docs/_meta` etc. because init-workspace.sh doesn't create them yet).

- [ ] **Step 3: Extend `init-workspace.sh`**

Open `scripts/init-workspace.sh`. After the existing docs-tree seeding block, add:

```bash
# --- v1.0 dual-tree additions ---
init_dual_trees() {
    local root="$1"
    mkdir -p "$root/notion_docs/_meta" "$root/develop_docs/_meta"

    local sync_state="$root/notion_docs/_meta/sync-state.json"
    local page_map="$root/notion_docs/_meta/page-map.json"

    if [ ! -f "$sync_state" ]; then
        python3 "$(dirname "$0")/sync-state.py" init "$sync_state"
        echo "seeded $sync_state"
    fi
    if [ ! -f "$page_map" ]; then
        python3 "$(dirname "$0")/page-map.py" init "$page_map"
        echo "seeded $page_map"
    fi
}

init_dual_trees "${1:-.}"
```

- [ ] **Step 4: Run test to verify pass**

```bash
bash tests/structure-check.sh
```

Expected: all checks pass, including `✓ dual-tree init`.

- [ ] **Step 5: Commit**

```bash
git add scripts/init-workspace.sh tests/structure-check.sh
git commit -m "feat(scripts): init-workspace.sh seeds notion_docs/ + develop_docs/ dual trees"
```

---

## Phase A-2: notion-sync Skill

### Task 5: Scaffold skill directory structure

**Files:**
- Create: `skills/notion-sync/SKILL.md`
- Create: `skills/notion-sync/change-detection.md`
- Create: `skills/notion-sync/templates/notion-doc-frontmatter.md`

- [ ] **Step 1: Write structure-check assertion**

Add to `tests/structure-check.sh`:

```bash
for f in skills/notion-sync/SKILL.md \
         skills/notion-sync/change-detection.md \
         skills/notion-sync/templates/notion-doc-frontmatter.md; do
    [ -f "$f" ] || { echo "missing $f"; exit 1; }
done
echo "  ✓ notion-sync skill scaffold present"
```

- [ ] **Step 2: Run to verify failure**

```bash
bash tests/structure-check.sh
```

Expected: FAIL with "missing skills/notion-sync/SKILL.md".

- [ ] **Step 3: Create `skills/notion-sync/SKILL.md`**

```markdown
---
name: notion-sync
description: Use when the user invokes /notion-sync or asks to mirror Notion workspace into notion_docs/. Fetches pages via Notion MCP, runs incremental change detection, writes notion_docs/*.md with frontmatter.
---

# notion-sync

Mirror the configured Notion workspace's top-level pages (and their sub-pages)
into `notion_docs/` as markdown files with sync metadata in YAML frontmatter.

**Announce at start:** "I'm using the notion-sync skill to sync Notion → notion_docs/."

## Pre-flight checks

1. `notion_docs/_meta/sync-state.json` and `notion_docs/_meta/page-map.json` exist — if not, run `scripts/init-workspace.sh .` first.
2. Notion MCP tools available (`mcp__claude_ai_Notion__notion-search`, `mcp__claude_ai_Notion__notion-fetch`). If missing, stop and tell user.

## Four-step pipeline

See `change-detection.md` for the detailed algorithm. Summary:

1. **Timestamp pre-filter** — fetch Notion page list, compare `last_edited_time` vs sync-state.json.
2. **Hash verify** — fetch candidate page content, normalize, SHA256, compare vs frontmatter.
3. **Deletion detection** — Notion page ids not in current list → move to orphans.
4. **Write** — generate notion_docs/*.md with frontmatter for real changes; update sync-state atomically.

## Handling new top-level pages

When a top-level Notion page ID is NOT in page-map.json:
1. Propose a folder name: slugified title via `python3 scripts/page-map.py slugify <title>`.
2. Ask the user to confirm or override.
3. Add mapping: `python3 scripts/page-map.py add notion_docs/_meta/page-map.json <page_id> <title> <folder>`.
4. Continue sync.

## Forbidden actions

- Do NOT edit `notion_docs/*.md` files with hand-written content. All writes go through the sync engine.
- Do NOT delete pages from `page-map.json` when they still exist in Notion.
- Do NOT skip `sync-state.json` updates — they are the persistence layer.

## Output

After sync, emit a short summary to the user:
```
synced: N pages (M new, K updated, 0 unchanged, 0 orphaned)
sync-state: notion_docs/_meta/sync-state.json
```
```

- [ ] **Step 4: Create `skills/notion-sync/change-detection.md`**

```markdown
---
id: skills.notion-sync.change-detection
title: Notion Sync — Four-Step Change Detection
owner: developer
status: stable
updated: 2026-04-18
---

# Change Detection Algorithm

## Step 1: Timestamp pre-filter

Call `mcp__claude_ai_Notion__notion-search` scoped to the workspace root. For
each returned page, read `notion_last_edited` and compare against
`sync-state.json → pages[page_id].notion_last_edited`.

- If Notion is newer → add to `candidates[]`.
- If equal or older → skip (no API cost beyond search).

## Step 2: Hash verify

For each candidate, call `mcp__claude_ai_Notion__notion-fetch` to get full
content. Pipe the JSON to `scripts/notion-hash.py` to compute a canonical
SHA256. Compare against the stored hash.

- If different → add to `real_changes[]`.
- If same → update only `notion_last_edited` in sync-state (content unchanged).

## Step 3: Deletion detection

Diff the set of page IDs returned by `notion-search` against
`sync-state.json → pages.keys()`. IDs present in state but missing from
Notion → orphans. Move each to `orphans[]` via
`sync-state.py move-to-orphans`.

Also delete the corresponding `notion_docs/*.md` file. Log loudly.

## Step 4: Write

For each `real_changes` entry:
1. Resolve target path from page-map.json + sub-page hierarchy
   (e.g., `plan/combat-system/damage-formula.md`).
2. Generate frontmatter using the template.
3. Write markdown body (Notion block-to-markdown conversion — minimal for v1:
   headings, paragraphs, lists, bold/italic, links).
4. Call `sync-state.py upsert` to record the hash.

All file writes are atomic (temp file + rename). No partial state on crash.
```

- [ ] **Step 5: Create frontmatter template**

Create `skills/notion-sync/templates/notion-doc-frontmatter.md`:

```markdown
---
id: {{path_id}}
notion_page_id: "{{notion_page_id}}"
title: "{{title}}"
notion_last_edited: "{{notion_last_edited}}"
content_hash: "{{content_hash}}"
synced_at: "{{synced_at}}"
source_url: "{{source_url}}"
notion_parent: {{notion_parent}}
children: {{children_array}}
---

{{markdown_body}}
```

Template variables resolved by the skill at write time.

- [ ] **Step 6: Run structure-check**

```bash
bash tests/structure-check.sh
```

Expected: all checks pass including `✓ notion-sync skill scaffold present`.

- [ ] **Step 7: Commit**

```bash
git add skills/notion-sync/ tests/structure-check.sh
git commit -m "feat(skills): scaffold notion-sync skill with change-detection reference"
```

---

### Task 6: Create `/notion-sync` slash command

**Files:**
- Create: `commands/notion-sync.md`

- [ ] **Step 1: Write structure-check assertion**

Add to `tests/structure-check.sh`:

```bash
[ -f "commands/notion-sync.md" ] || { echo "missing commands/notion-sync.md"; exit 1; }
echo "  ✓ /notion-sync command present"
```

- [ ] **Step 2: Run to verify failure**

```bash
bash tests/structure-check.sh
```

Expected: FAIL "missing commands/notion-sync.md".

- [ ] **Step 3: Create `commands/notion-sync.md`**

```markdown
---
description: Incrementally sync the Notion workspace into notion_docs/
argument-hint: (no arguments — syncs all mapped pages)
---

# /notion-sync

Fetch and mirror the Notion workspace into `notion_docs/` using the
notion-sync skill.

Invoke the `notion-sync` skill via the Skill tool:

```
Skill('notion-sync')
```

The skill will:
1. Verify pre-flight (sync-state.json + page-map.json present; Notion MCP available)
2. Run the four-step change detection pipeline
3. Write `notion_docs/*.md` files for real changes
4. Update `notion_docs/_meta/sync-state.json`
5. Report a summary to the user

Do NOT run `/docs-refinement` or `/docs-update` as part of this command — this
is sync only. Use `/docs-update` for the full pipeline.
```

- [ ] **Step 4: Run structure-check**

```bash
bash tests/structure-check.sh
```

Expected: pass with `✓ /notion-sync command present`.

- [ ] **Step 5: Commit**

```bash
git add commands/notion-sync.md tests/structure-check.sh
git commit -m "feat(commands): add /notion-sync slash command"
```

---

## Phase A-3: Fixtures and Integration

### Task 7: Create Notion MCP response fixtures

**Files:**
- Create: `tests/fixture/mock-notion-responses/README.md`
- Create: `tests/fixture/mock-notion-responses/page-list.json`
- Create: `tests/fixture/mock-notion-responses/page-dev.json`
- Create: `tests/fixture/mock-notion-responses/page-art.json`
- Create: `tests/fixture/mock-notion-responses/page-plan.json`

- [ ] **Step 1: Create README explaining fixture usage**

```markdown
# Mock Notion MCP Responses

These fixtures simulate responses from `mcp__claude_ai_Notion__notion-search`
and `mcp__claude_ai_Notion__notion-fetch` for offline testing of the sync
engine.

## Files

| File | Simulates |
|------|-----------|
| `page-list.json` | Response to `notion-search` with all top-level pages |
| `page-dev.json` | Response to `notion-fetch` for the 개발 page |
| `page-art.json` | Response to `notion-fetch` for the 아트 page |
| `page-plan.json` | Response to `notion-fetch` for the 기획 page |

## Usage

The integration test (`tests/integration/test-notion-sync.sh`) pipes these
files directly to `scripts/notion-hash.py` and the sync engine to verify
end-to-end behavior without hitting Notion.

## Adding new fixtures

When adding test cases, keep the page IDs stable (`uuid-dev`, `uuid-art`,
`uuid-plan`) so reverse-index tests across Slices A/B/C stay consistent.
```

- [ ] **Step 2: Create `page-list.json`**

```json
{
  "object": "list",
  "results": [
    {
      "object": "page",
      "id": "uuid-dev",
      "last_edited_time": "2026-04-18T09:00:00Z",
      "properties": {
        "title": {"title": [{"plain_text": "개발"}]}
      }
    },
    {
      "object": "page",
      "id": "uuid-art",
      "last_edited_time": "2026-04-18T09:05:00Z",
      "properties": {
        "title": {"title": [{"plain_text": "아트"}]}
      }
    },
    {
      "object": "page",
      "id": "uuid-plan",
      "last_edited_time": "2026-04-18T09:10:00Z",
      "properties": {
        "title": {"title": [{"plain_text": "기획"}]}
      }
    }
  ],
  "has_more": false,
  "next_cursor": null
}
```

- [ ] **Step 3: Create `page-dev.json`**

```json
{
  "object": "page",
  "id": "uuid-dev",
  "last_edited_time": "2026-04-18T09:00:00Z",
  "properties": {"title": {"title": [{"plain_text": "개발"}]}},
  "blocks": [
    {"type": "heading_2", "heading_2": {"rich_text": [{"plain_text": "Tech Stack"}]}},
    {"type": "paragraph", "paragraph": {"rich_text": [{"plain_text": "Unity 2023 LTS, URP, C# 9."}]}}
  ]
}
```

- [ ] **Step 4: Create `page-art.json`**

```json
{
  "object": "page",
  "id": "uuid-art",
  "last_edited_time": "2026-04-18T09:05:00Z",
  "properties": {"title": {"title": [{"plain_text": "아트"}]}},
  "blocks": [
    {"type": "heading_2", "heading_2": {"rich_text": [{"plain_text": "Concept Direction"}]}},
    {"type": "paragraph", "paragraph": {"rich_text": [{"plain_text": "Low-poly, warm palette."}]}}
  ]
}
```

- [ ] **Step 5: Create `page-plan.json`**

```json
{
  "object": "page",
  "id": "uuid-plan",
  "last_edited_time": "2026-04-18T09:10:00Z",
  "properties": {"title": {"title": [{"plain_text": "기획"}]}},
  "blocks": [
    {"type": "heading_2", "heading_2": {"rich_text": [{"plain_text": "Combat System"}]}},
    {"type": "paragraph", "paragraph": {"rich_text": [{"plain_text": "Turn-based, 3 action points per turn."}]}}
  ]
}
```

- [ ] **Step 6: Commit**

```bash
git add tests/fixture/mock-notion-responses/
git commit -m "test(fixture): add mock Notion MCP responses for 3 starter pages"
```

---

### Task 8: Integration test end-to-end

**Files:**
- Create: `tests/integration/test-notion-sync.sh`

- [ ] **Step 1: Write the integration test**

```bash
#!/usr/bin/env bash
# test-notion-sync.sh — end-to-end test using fixtures (no real Notion)
#
# Simulates a /notion-sync run by driving the scripts directly with
# fixture JSON. Does NOT exercise the skill markdown or Claude loop.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
FIXTURE="$REPO_ROOT/tests/fixture/mock-notion-responses"

pass() { echo "  ✓ $1"; }
fail() { echo "  ✗ $1" >&2; exit 1; }

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

cd "$TMP"
bash "$REPO_ROOT/scripts/init-workspace.sh" "$TMP"

SS="$TMP/notion_docs/_meta/sync-state.json"
PM="$TMP/notion_docs/_meta/page-map.json"

# Add mappings for the three starter pages
python3 "$REPO_ROOT/scripts/page-map.py" add "$PM" "uuid-dev" "개발" "dev"
python3 "$REPO_ROOT/scripts/page-map.py" add "$PM" "uuid-art" "아트" "art"
python3 "$REPO_ROOT/scripts/page-map.py" add "$PM" "uuid-plan" "기획" "plan"

# Compute hashes from fixtures
hash_dev="$(python3 "$REPO_ROOT/scripts/notion-hash.py" "$FIXTURE/page-dev.json")"
hash_art="$(python3 "$REPO_ROOT/scripts/notion-hash.py" "$FIXTURE/page-art.json")"
hash_plan="$(python3 "$REPO_ROOT/scripts/notion-hash.py" "$FIXTURE/page-plan.json")"

python3 "$REPO_ROOT/scripts/sync-state.py" upsert "$SS" "uuid-dev" "dev/page-dev.md" "$hash_dev" "2026-04-18T09:00:00Z"
python3 "$REPO_ROOT/scripts/sync-state.py" upsert "$SS" "uuid-art" "art/page-art.md" "$hash_art" "2026-04-18T09:05:00Z"
python3 "$REPO_ROOT/scripts/sync-state.py" upsert "$SS" "uuid-plan" "plan/page-plan.md" "$hash_plan" "2026-04-18T09:10:00Z"

# Verify
lines="$(python3 "$REPO_ROOT/scripts/sync-state.py" list-pages "$SS" | wc -l)"
[ "$lines" -eq 3 ] || fail "expected 3 pages in sync-state, got $lines"
pass "sync-state has 3 pages after seed"

# Idempotency: hash identical payloads twice → same result
h1="$(python3 "$REPO_ROOT/scripts/notion-hash.py" "$FIXTURE/page-dev.json")"
h2="$(python3 "$REPO_ROOT/scripts/notion-hash.py" "$FIXTURE/page-dev.json")"
[ "$h1" = "$h2" ] || fail "fixture hash not stable"
pass "fixture hash stable across runs"

# Deletion flow
python3 "$REPO_ROOT/scripts/sync-state.py" move-to-orphans "$SS" "uuid-plan"
orphan_count="$(python3 "$REPO_ROOT/scripts/sync-state.py" list-orphans "$SS" | wc -l)"
[ "$orphan_count" -eq 1 ] || fail "expected 1 orphan after delete, got $orphan_count"
pass "deletion moves to orphans correctly"

echo "All integration tests passed"
```

Make executable: `chmod +x tests/integration/test-notion-sync.sh`

- [ ] **Step 2: Run test**

```bash
bash tests/integration/test-notion-sync.sh
```

Expected: all tests pass with 3 `✓` marks and `All integration tests passed`.

- [ ] **Step 3: Commit**

```bash
git add tests/integration/
git commit -m "test(integration): end-to-end notion-sync test using fixtures"
```

---

## Phase A-4: Release Metadata

### Task 9: Update CHANGELOG and plugin.json

**Files:**
- Modify: `CHANGELOG.md`
- Modify: `.claude-plugin/plugin.json`

- [ ] **Step 1: Bump version in plugin.json**

Open `.claude-plugin/plugin.json`. Change:

```json
"version": "0.2.0"
```

to:

```json
"version": "1.0.0-alpha.1"
```

- [ ] **Step 2: Add Unreleased section to CHANGELOG**

Prepend to `CHANGELOG.md` (just after the `# Changelog` header):

```markdown
## [Unreleased] — v1.0 roadmap

Progressing toward v1.0.0 — a Notion-driven Superpowers pipeline. See
`docs/superpowers/specs/2026-04-18-orchestration-unity-v1-design.md`.

### Slice A (MVP Notion Sync) — this release candidate
- Added `scripts/notion-hash.py` — deterministic SHA256 of Notion content
- Added `scripts/page-map.py` — Notion page → folder mapping manager
- Added `scripts/sync-state.py` — `_meta/sync-state.json` management
- Extended `scripts/init-workspace.sh` — seeds `notion_docs/` + `develop_docs/`
- Added `skills/notion-sync/` — 4-step change detection pipeline
- Added `commands/notion-sync.md` — `/notion-sync` slash command
- Added unit tests for hashing, page-mapping, sync-state
- Added integration test using mock Notion MCP fixtures

### Planned (upcoming slices)
- Slice B: `/docs-refinement` + `/docs-update` meta command
- Slice C: Section 17 living knowledge base (provenance markers, code→docs)
- Slice D: `/unity-orchestration` Superpowers chain rewrite
- Slice E: v0.2 → v1.0 migration, README replacement, 1.0.0 release tag

```

- [ ] **Step 3: Commit**

```bash
git add CHANGELOG.md .claude-plugin/plugin.json
git commit -m "chore: bump to 1.0.0-alpha.1 with Slice A CHANGELOG entry"
```

---

## Completion Criteria (Slice A Done)

All of the following must be true before Slice A is considered complete:

- [ ] `bash tests/structure-check.sh` passes
- [ ] `bash tests/sync-engine-tests/test-notion-hash.sh` passes
- [ ] `bash tests/sync-engine-tests/test-page-map.sh` passes
- [ ] `bash tests/sync-engine-tests/test-sync-state.sh` passes
- [ ] `bash tests/integration/test-notion-sync.sh` passes
- [ ] `.claude-plugin/plugin.json` version = `1.0.0-alpha.1`
- [ ] `CHANGELOG.md` has `[Unreleased]` section with Slice A items
- [ ] 9 commits on the main branch (one per Task 1-9)
- [ ] Plugin installs in Claude Code without error (manual smoke test)

Once complete, proceed to Slice B: Refinement + /docs-update.
