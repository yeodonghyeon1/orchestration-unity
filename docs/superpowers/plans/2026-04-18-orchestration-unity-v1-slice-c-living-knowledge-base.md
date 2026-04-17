# orchestration-unity v1.0 — Slice C: Living Knowledge Base Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Implement section-level provenance (Section 17 of the spec) so `develop_docs/` becomes a living knowledge base with three content sources (`notion`, `code`, `manual`) coexisting in the same file. `/docs-refinement` preserves non-Notion sections; `/unity-orchestration` (Slice D) updates `code:*` sections during game development.

**Architecture:** HTML comment markers (`<!-- source: notion:... -->`) wrap each section. A new parser (`scripts/provenance.py`) reads markers, splits a develop_doc into sections, and reassembles after selective regeneration. `docs-refinement` is modified to use the parser. A new `scripts/code-to-docs.py` extracts C# class/method signatures for the `code:*` sections (used by Slice D).

**Tech Stack:** Python 3.9+ (regex for markers, C# lexer-lite for signatures), bash, Claude Code Skill markdown.

**Delivers:**
- `scripts/provenance.py` — parse/write provenance-marked markdown sections
- `scripts/code-to-docs.py` — extract C# signatures into markdown sections
- `skills/docs-refinement/SKILL.md` updated to preserve non-Notion sections
- Updated frontmatter template with `section_sources` + `code_references`
- Unit tests for parser and code extractor
- Integration test demonstrating preservation

**Reads from spec:** Section 17 (all subsections)

**Prerequisites:** Slices A and B complete.

---

## File Structure Map

### Create

| Path | Purpose |
|------|---------|
| `scripts/provenance.py` | Parse/merge HTML-comment provenance markers in markdown |
| `scripts/code-to-docs.py` | Extract C# class/method signatures → markdown |
| `tests/sync-engine-tests/test-provenance.sh` | provenance parser tests |
| `tests/sync-engine-tests/test-code-to-docs.sh` | code extractor tests |
| `tests/fixture/csharp-samples/CombatSystem.cs` | Sample C# for extractor tests |
| `tests/fixture/csharp-samples/DamageFormula.cs` | Sample static utility |
| `tests/fixture/provenance-sample.md` | Sample develop_doc with mixed provenance |
| `tests/integration/test-preservation.sh` | End-to-end preservation demo |

### Modify

| Path | Change |
|------|--------|
| `skills/docs-refinement/SKILL.md` | Document section-preservation rules |
| `skills/docs-refinement/cross-ref-rules.md` | Add provenance section |
| `skills/docs-refinement/templates/develop-doc-frontmatter.md` | Fill in `section_sources` + `code_references` |
| `CHANGELOG.md` | Append Slice C entries |
| `.claude-plugin/plugin.json` | Bump to `1.0.0-alpha.3` |

---

## Phase C-1: Provenance Parser

### Task 1: `scripts/provenance.py` — parser + writer (TDD)

**Files:**
- Create: `scripts/provenance.py`
- Test: `tests/sync-engine-tests/test-provenance.sh`

- [ ] **Step 1: Write the failing test**

Create `tests/sync-engine-tests/test-provenance.sh`:

```bash
#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
P="$REPO_ROOT/scripts/provenance.py"

pass() { echo "  ✓ $1"; }
fail() { echo "  ✗ $1" >&2; exit 1; }

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

# Build sample
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

# List sources
sources="$(python3 "$P" sources "$TMP/doc.md")"
echo "$sources" | grep -q "notion:plan.combat-system" || fail "missing notion source"
echo "$sources" | grep -q "code:Assets/Scripts/Combat.cs" || fail "missing code source"
echo "$sources" | grep -q "^manual$" || fail "missing manual source"
pass "sources extracted"

# Extract notion section only
notion_body="$(python3 "$P" extract "$TMP/doc.md" "notion:plan.combat-system")"
echo "$notion_body" | grep -q "Notion-sourced text" || fail "notion content missing"
echo "$notion_body" | grep -q "Code-sourced" && fail "should NOT include code section"
pass "extract isolates notion section"

# Replace notion section with new content
cat > "$TMP/new-notion.md" <<'EOF'
## Combat Mechanics

UPDATED Notion content.
EOF
python3 "$P" replace "$TMP/doc.md" "notion:plan.combat-system" "$TMP/new-notion.md"
grep -q "UPDATED Notion content" "$TMP/doc.md" || fail "replace did not write new content"
grep -q "Code-sourced signatures" "$TMP/doc.md" || fail "code section destroyed by replace!"
grep -q "User notes" "$TMP/doc.md" || fail "manual section destroyed by replace!"
pass "replace preserves non-target sections"

# Append new section
python3 "$P" append "$TMP/doc.md" "code:Assets/Scripts/New.cs" - <<'EOF'
## New Class

class Foo {}
EOF
grep -q "code:Assets/Scripts/New.cs" "$TMP/doc.md" || fail "append did not add new source"
pass "append adds new section with marker"

echo "All provenance tests passed"
```

Make executable.

- [ ] **Step 2: Run to verify failure**

```bash
bash tests/sync-engine-tests/test-provenance.sh
```

Expected: FAIL (script missing).

- [ ] **Step 3: Implement `scripts/provenance.py`**

```python
#!/usr/bin/env python3
"""provenance.py — parse/merge HTML-comment provenance markers in markdown.

Section grammar:
    <!-- source: <tag> -->
    ...content...
    <!-- /source -->

Tags are either:
    notion:<path-id>        e.g. notion:plan.combat-system
    code:<path>             e.g. code:Assets/Scripts/Combat.cs
    manual                  (literal)

Subcommands:
    sources <file>                   — list all source tags
    extract <file> <tag>             — print the section body for the tag
    replace <file> <tag> <new-body>  — replace section body (preserves others)
    append <file> <tag> <new-body>   — add a new section (new-body can be '-' for stdin)
    strip <file> <tag>               — remove the section entirely
"""

import re
import sys
from pathlib import Path

START_RE = re.compile(r"<!--\s*source:\s*(\S+)\s*-->")
END_RE = re.compile(r"<!--\s*/source\s*-->")


def parse(text: str):
    """Yield (tag, start_idx, content, end_idx) for each section."""
    lines = text.splitlines(keepends=True)
    i = 0
    while i < len(lines):
        m = START_RE.search(lines[i])
        if m:
            tag = m.group(1)
            start = i
            content_start = i + 1
            # find matching end
            j = content_start
            while j < len(lines):
                if END_RE.search(lines[j]):
                    yield tag, start, "".join(lines[content_start:j]), j
                    i = j + 1
                    break
                j += 1
            else:
                i = len(lines)  # unclosed marker; stop
        else:
            i += 1


def cmd_sources(path: str) -> int:
    text = Path(path).read_text(encoding="utf-8")
    for tag, _, _, _ in parse(text):
        print(tag)
    return 0


def cmd_extract(path: str, tag: str) -> int:
    text = Path(path).read_text(encoding="utf-8")
    for t, _, content, _ in parse(text):
        if t == tag:
            sys.stdout.write(content)
            return 0
    return 1


def cmd_replace(path: str, tag: str, body_src: str) -> int:
    new_body = sys.stdin.read() if body_src == "-" else Path(body_src).read_text(encoding="utf-8")
    text = Path(path).read_text(encoding="utf-8")
    lines = text.splitlines(keepends=True)
    for t, start, _, end in parse(text):
        if t == tag:
            rebuilt = (
                "".join(lines[:start + 1])
                + (new_body if new_body.endswith("\n") else new_body + "\n")
                + "".join(lines[end:])
            )
            Path(path).write_text(rebuilt, encoding="utf-8")
            return 0
    print(f"error: tag not found: {tag}", file=sys.stderr)
    return 2


def cmd_append(path: str, tag: str, body_src: str) -> int:
    new_body = sys.stdin.read() if body_src == "-" else Path(body_src).read_text(encoding="utf-8")
    if not new_body.endswith("\n"):
        new_body += "\n"
    block = f"\n<!-- source: {tag} -->\n{new_body}<!-- /source -->\n"
    existing = Path(path).read_text(encoding="utf-8")
    if not existing.endswith("\n"):
        existing += "\n"
    Path(path).write_text(existing + block, encoding="utf-8")
    return 0


def cmd_strip(path: str, tag: str) -> int:
    text = Path(path).read_text(encoding="utf-8")
    lines = text.splitlines(keepends=True)
    for t, start, _, end in parse(text):
        if t == tag:
            rebuilt = "".join(lines[:start]) + "".join(lines[end + 1:])
            Path(path).write_text(rebuilt, encoding="utf-8")
            return 0
    return 1


def main() -> int:
    if len(sys.argv) < 3:
        print(__doc__, file=sys.stderr)
        return 2
    sub = sys.argv[1]
    if sub == "sources":
        return cmd_sources(sys.argv[2])
    if sub == "extract":
        return cmd_extract(sys.argv[2], sys.argv[3])
    if sub == "replace":
        return cmd_replace(sys.argv[2], sys.argv[3], sys.argv[4])
    if sub == "append":
        return cmd_append(sys.argv[2], sys.argv[3], sys.argv[4] if len(sys.argv) > 4 else "-")
    if sub == "strip":
        return cmd_strip(sys.argv[2], sys.argv[3])
    print(f"unknown subcommand: {sub}", file=sys.stderr)
    return 2


if __name__ == "__main__":
    sys.exit(main())
```

Make executable.

- [ ] **Step 4: Run test to verify pass**

```bash
bash tests/sync-engine-tests/test-provenance.sh
```

Expected: 4 `✓` marks.

- [ ] **Step 5: Commit**

```bash
git add scripts/provenance.py tests/sync-engine-tests/test-provenance.sh
git commit -m "feat(scripts): add provenance.py for section-level source markers"
```

---

## Phase C-2: C# Signature Extractor

### Task 2: `scripts/code-to-docs.py` — extract C# signatures (TDD)

**Files:**
- Create: `scripts/code-to-docs.py`
- Create: `tests/fixture/csharp-samples/CombatSystem.cs`
- Create: `tests/fixture/csharp-samples/DamageFormula.cs`
- Test: `tests/sync-engine-tests/test-code-to-docs.sh`

- [ ] **Step 1: Create sample C# files**

`tests/fixture/csharp-samples/CombatSystem.cs`:

```csharp
using UnityEngine;

namespace Game.Combat
{
    /// <summary>
    /// Main combat controller. Handles damage resolution.
    /// </summary>
    public sealed class CombatSystem : MonoBehaviour
    {
        [SerializeField] private int maxActionPoints = 3;

        public int MaxActionPoints => maxActionPoints;

        public CombatResult StartCombat(Entity attacker, Entity defender)
        {
            return new CombatResult();
        }

        private void ApplyDamage(Entity e, int amount) { }
    }
}
```

`tests/fixture/csharp-samples/DamageFormula.cs`:

```csharp
namespace Game.Combat
{
    public static class DamageFormula
    {
        public static int Calculate(int baseDamage, int modifier)
        {
            return baseDamage + modifier;
        }
    }
}
```

- [ ] **Step 2: Write the failing test**

Create `tests/sync-engine-tests/test-code-to-docs.sh`:

```bash
#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
C2D="$REPO_ROOT/scripts/code-to-docs.py"
FIX="$REPO_ROOT/tests/fixture/csharp-samples"

pass() { echo "  ✓ $1"; }
fail() { echo "  ✗ $1" >&2; exit 1; }

# Class extraction
out="$(python3 "$C2D" "$FIX/CombatSystem.cs")"
echo "$out" | grep -q "class.*CombatSystem" || fail "missing class"
echo "$out" | grep -q "StartCombat" || fail "missing public method"
echo "$out" | grep -q "MaxActionPoints" || fail "missing public property"
pass "class/methods/properties extracted"

# Private methods should NOT appear
if echo "$out" | grep -q "ApplyDamage"; then
    fail "private method leaked into output"
fi
pass "private members excluded"

# Static class
out="$(python3 "$C2D" "$FIX/DamageFormula.cs")"
echo "$out" | grep -q "static.*DamageFormula" || fail "static class not detected"
echo "$out" | grep -q "Calculate" || fail "static method missing"
pass "static class/methods extracted"

# YAML frontmatter snippet output mode
out="$(python3 "$C2D" --frontmatter "$FIX/CombatSystem.cs")"
echo "$out" | grep -q "kind: class" || fail "frontmatter missing kind"
echo "$out" | grep -q "symbol: CombatSystem" || fail "frontmatter missing symbol"
pass "frontmatter mode works"

echo "All code-to-docs tests passed"
```

- [ ] **Step 3: Run to verify failure**

```bash
bash tests/sync-engine-tests/test-code-to-docs.sh
```

Expected: FAIL.

- [ ] **Step 4: Implement `scripts/code-to-docs.py`**

```python
#!/usr/bin/env python3
"""code-to-docs.py — extract C# public surface into markdown.

Intentionally a LINE-LEVEL regex scanner, not a full parser. Handles
the 80% case of Unity C# game code: classes, structs, enums, public
methods, public properties, serialized fields. Private members are
excluded. Generics and nested types are best-effort.

Usage:
    python3 scripts/code-to-docs.py <file.cs>                  — markdown output
    python3 scripts/code-to-docs.py --frontmatter <file.cs>    — YAML code_references snippet
"""

import re
import sys
from pathlib import Path

CLASS_RE = re.compile(
    r"^\s*(public\s+)?(static\s+|sealed\s+|abstract\s+|partial\s+)*"
    r"(class|struct|enum|interface)\s+(\w+)"
)
METHOD_RE = re.compile(
    r"^\s*public\s+(static\s+|virtual\s+|override\s+|async\s+)*"
    r"[\w<>,\[\]\s]+?\s+(\w+)\s*\([^;{]*\)\s*[{=]"
)
PROPERTY_RE = re.compile(
    r"^\s*public\s+[\w<>,\[\]\s]+\s+(\w+)\s*\{[^}]*get"
)
EXPR_BODY_PROP_RE = re.compile(
    r"^\s*public\s+[\w<>,\[\]\s]+\s+(\w+)\s*=>"
)
SERIALIZED_FIELD_RE = re.compile(
    r"\[SerializeField\][^;]*?(\w+)\s*;"
)


def extract(source: str):
    classes = []
    current = None
    class_modifiers = {}

    for raw in source.splitlines():
        line = raw.rstrip()

        mclass = CLASS_RE.match(line)
        if mclass:
            modifiers = (mclass.group(1) or "") + (mclass.group(2) or "")
            kind = mclass.group(3)
            name = mclass.group(4)
            current = {
                "name": name,
                "kind": kind,
                "modifiers": modifiers.strip(),
                "methods": [],
                "properties": [],
                "fields": [],
            }
            classes.append(current)
            continue

        if current is None:
            continue

        mm = METHOD_RE.match(line)
        if mm:
            current["methods"].append(mm.group(2))
            continue

        mp = PROPERTY_RE.match(line) or EXPR_BODY_PROP_RE.match(line)
        if mp:
            current["properties"].append(mp.group(1))
            continue

        msf = SERIALIZED_FIELD_RE.search(line)
        if msf:
            current["fields"].append(msf.group(1))

    return classes


def render_markdown(path: str, classes: list) -> str:
    lines = [f"## {path}", ""]
    for c in classes:
        modifier_str = c["modifiers"] or "public"
        header = f"### `{modifier_str} {c['kind']} {c['name']}`"
        lines.append(header)
        if c["properties"]:
            lines.append("")
            lines.append("**Properties:**")
            for p in c["properties"]:
                lines.append(f"- `{p}`")
        if c["methods"]:
            lines.append("")
            lines.append("**Public methods:**")
            for m in c["methods"]:
                lines.append(f"- `{m}(...)`")
        if c["fields"]:
            lines.append("")
            lines.append("**Serialized fields:**")
            for f in c["fields"]:
                lines.append(f"- `{f}`")
        lines.append("")
    return "\n".join(lines)


def render_frontmatter(path: str, classes: list) -> str:
    out = []
    for c in classes:
        kind_str = "class" if c["kind"] == "class" else c["kind"]
        if "static" in c["modifiers"]:
            kind_str = "static-utility"
        out.append(f"- path: {path}")
        out.append(f"  kind: {kind_str}")
        out.append(f"  symbol: {c['name']}")
    return "\n".join(out)


def main() -> int:
    args = sys.argv[1:]
    frontmatter_mode = False
    if args and args[0] == "--frontmatter":
        frontmatter_mode = True
        args = args[1:]
    if not args:
        print("usage: code-to-docs.py [--frontmatter] <file.cs>", file=sys.stderr)
        return 2
    src_path = args[0]
    source = Path(src_path).read_text(encoding="utf-8")
    classes = extract(source)
    if frontmatter_mode:
        print(render_frontmatter(src_path, classes))
    else:
        print(render_markdown(src_path, classes))
    return 0


if __name__ == "__main__":
    sys.exit(main())
```

- [ ] **Step 5: Run test to verify pass**

```bash
bash tests/sync-engine-tests/test-code-to-docs.sh
```

Expected: 4 `✓` marks.

- [ ] **Step 6: Commit**

```bash
git add scripts/code-to-docs.py tests/fixture/csharp-samples/ tests/sync-engine-tests/test-code-to-docs.sh
git commit -m "feat(scripts): add code-to-docs.py for C# signature extraction"
```

---

## Phase C-3: Skill Integration

### Task 3: Update `docs-refinement/SKILL.md` for preservation rule

**Files:**
- Modify: `skills/docs-refinement/SKILL.md`

- [ ] **Step 1: Open the file and append a new section**

After the existing "Refinement rules" section, add:

```markdown
## Section preservation (Living Knowledge Base)

As of v1.0 Slice C, `develop_docs/` files may contain sections from
non-Notion sources (code, manual). These are marked with HTML provenance
comments:

```
<!-- source: notion:<id> -->
<!-- source: code:<path> -->
<!-- source: manual -->
```

**Critical rule:** When refining, ONLY regenerate sections with
`source: notion:*`. Preserve `code:*` and `manual` sections verbatim.

### Algorithm update

For each affected develop_docs file:

1. `sources="$(python3 scripts/provenance.py sources path/to/file.md)"`
2. For each `source` matching `notion:*`:
   - Load the referenced notion_doc
   - Dispatch sub-agent to produce new section content
   - `python3 scripts/provenance.py replace path/to/file.md "$source" new-content.md`
3. Do NOT touch `code:*` or `manual` sections.

### Orphaned sections

If a `notion:*` source is no longer in `source_notion_docs[]`:
- Replace body with: `> DEPRECATED: source page removed from Notion (was: <id>)`
- Keep the marker so future runs don't re-create it.

### User-edited notion sections (conflict case)

If the file has been manually edited inside a `notion:*` section (detected
via `refinement_hash` mismatch for notion-only content):
- Pause and ask user: `[o]verwrite, [p]reserve (treat as manual), [a]bort`
- On "preserve", change marker to `source: manual`
- On "abort", skip this file and log
```

- [ ] **Step 2: Update `skills/docs-refinement/cross-ref-rules.md`**

Append:

```markdown
## Provenance markers (v1.0 Slice C)

See `scripts/provenance.py` for manipulation. Section sources are stored
both inline (HTML comments) and in the frontmatter `section_sources:` map.
Keep them consistent — `docs-refinement` reads comments first and updates
frontmatter on write.
```

- [ ] **Step 3: Update frontmatter template**

`skills/docs-refinement/templates/develop-doc-frontmatter.md`:

```markdown
---
id: {{path_id}}
title: "{{title}}"
status: draft

source_notion_docs:
{{source_notion_list}}

refs:
{{refs_list}}

# Section-level provenance (Slice C)
section_sources:
{{section_sources_yaml}}    # e.g., "  \"Combat Mechanics\": notion:plan.combat-system"

code_references:
{{code_references_yaml}}    # output of: code-to-docs.py --frontmatter *.cs

owner: claude
last_refined: "{{last_refined}}"
refinement_hash: "{{refinement_hash}}"   # SHA256 over notion:* sections only
---

{{markdown_body}}
```

- [ ] **Step 4: Commit**

```bash
git add skills/docs-refinement/
git commit -m "feat(skills): docs-refinement preserves non-Notion sections via provenance markers"
```

---

### Task 4: Integration test — preservation demo

**Files:**
- Create: `tests/integration/test-preservation.sh`
- Create: `tests/fixture/provenance-sample.md`

- [ ] **Step 1: Create the fixture**

`tests/fixture/provenance-sample.md`:

```markdown
---
id: game.systems.combat
title: Combat System
---
# Combat

<!-- source: notion:plan.combat-system -->
## Combat Mechanics

Original Notion content.
<!-- /source -->

<!-- source: code:Assets/Scripts/CombatSystem.cs -->
## Implementation

### `public sealed class CombatSystem`

**Public methods:**
- `StartCombat(...)`
<!-- /source -->

<!-- source: manual -->
## Design Notes

Hand-written by the designer.
<!-- /source -->
```

- [ ] **Step 2: Write integration test**

`tests/integration/test-preservation.sh`:

```bash
#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
P="$REPO_ROOT/scripts/provenance.py"
FIXTURE="$REPO_ROOT/tests/fixture/provenance-sample.md"

pass() { echo "  ✓ $1"; }
fail() { echo "  ✗ $1" >&2; exit 1; }

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

cp "$FIXTURE" "$TMP/doc.md"

# Simulate Notion re-refine: replace only notion section
cat > "$TMP/new-content.md" <<'EOF'
## Combat Mechanics

UPDATED by refinement.
EOF
python3 "$P" replace "$TMP/doc.md" "notion:plan.combat-system" "$TMP/new-content.md"

# Verify notion section changed
grep -q "UPDATED by refinement" "$TMP/doc.md" || fail "notion section not updated"
pass "notion section regenerated"

# Verify code section preserved
grep -q "public sealed class CombatSystem" "$TMP/doc.md" || fail "code section wiped!"
pass "code section preserved"

# Verify manual section preserved
grep -q "Hand-written by the designer" "$TMP/doc.md" || fail "manual section wiped!"
pass "manual section preserved"

# Simulate code update: append a new method signature section
cat > "$TMP/new-code-section.md" <<'EOF'
## New API

- `ApplyCritical(...)`
EOF
python3 "$P" append "$TMP/doc.md" "code:Assets/Scripts/NewFile.cs" "$TMP/new-code-section.md"

# All original markers still present
for marker in "notion:plan.combat-system" "code:Assets/Scripts/CombatSystem.cs" "manual" "code:Assets/Scripts/NewFile.cs"; do
    grep -q "source: $marker" "$TMP/doc.md" || fail "missing marker: $marker"
done
pass "append adds new marker without disturbing others"

echo "All preservation integration tests passed"
```

Make executable.

- [ ] **Step 3: Run test**

```bash
bash tests/integration/test-preservation.sh
```

Expected: 4 `✓` marks.

- [ ] **Step 4: Commit**

```bash
git add tests/fixture/provenance-sample.md tests/integration/test-preservation.sh
git commit -m "test(integration): preservation test for Living Knowledge Base"
```

---

## Phase C-4: Release Metadata

### Task 5: Update CHANGELOG and version

**Files:**
- Modify: `CHANGELOG.md`
- Modify: `.claude-plugin/plugin.json`

- [ ] **Step 1: Bump version to `1.0.0-alpha.3`**

- [ ] **Step 2: Append to CHANGELOG `[Unreleased]`**

```markdown
### Slice C (Living Knowledge Base) — this release candidate
- Added `scripts/provenance.py` — HTML comment provenance markers (parse/replace/append/strip)
- Added `scripts/code-to-docs.py` — C# public surface extractor (classes, methods, properties, serialized fields)
- `docs-refinement` now preserves `code:*` and `manual` sections; regenerates only `notion:*`
- Frontmatter extended with `section_sources` and `code_references`
- Tests: provenance parser, code extractor, preservation integration
```

- [ ] **Step 3: Commit**

```bash
git add CHANGELOG.md .claude-plugin/plugin.json
git commit -m "chore: bump to 1.0.0-alpha.3 with Slice C CHANGELOG entry"
```

---

## Completion Criteria (Slice C Done)

- [ ] `bash tests/structure-check.sh` passes
- [ ] `bash tests/sync-engine-tests/test-provenance.sh` passes
- [ ] `bash tests/sync-engine-tests/test-code-to-docs.sh` passes
- [ ] `bash tests/integration/test-preservation.sh` passes
- [ ] `.claude-plugin/plugin.json` version = `1.0.0-alpha.3`
- [ ] 5 commits on main branch (Tasks 1-5)
- [ ] Updated `docs-refinement/SKILL.md` documents the preservation rule
- [ ] Updated frontmatter template includes `section_sources` and `code_references`

Proceed to Slice D: Unity Orchestration v1.0.
