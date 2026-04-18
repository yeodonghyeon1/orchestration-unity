---
name: wiki-sync-code
description: Use when the user invokes /wiki-sync-code or asks to update the wiki with recent code changes. Scans git-modified C# files (or a user-specified glob), extracts signatures and doc comments, and regenerates the `<!-- source: code:<path> -->` sections in docs/llm_wiki/tech/**. Does NOT push to Notion — proposes /notion-push afterwards.
---

# wiki-sync-code

Keep docs/llm_wiki/tech/** in sync with the Unity C# source tree. Triggered
manually or suggested by the file-edit hook after an `Assets/**/*.cs` edit.

**Announce at start:** "I'm using the wiki-sync-code skill to sync code changes into docs/llm_wiki/tech/."

## Pre-flight

1. Current directory is the project root. `docs/llm_wiki/tech/` exists
   (created by `/init-wiki`).
2. At least one of:
   - `git status` shows modified `Assets/**/*.cs`, OR
   - User passed `--files <path>...` or `--glob <pattern>`.
3. `docs/llm_wiki/_meta/wiki-state.json` exists.

## Algorithm

### Phase 1 — Collect changed C# files

1. Default: run `git diff --name-only HEAD` (via Bash). Filter to
   `Assets/**/*.cs`.
2. If the list is empty, also consider `git diff --name-only` (unstaged)
   and `git ls-files --others --exclude-standard Assets/*.cs` (new
   untracked). Report which set was used.
3. With `--files` or `--glob`, skip git and use the explicit list.
4. If still zero files, exit with "no C# files to sync" (not an error).

### Phase 2 — Parse each C# file

For every file, use Read and extract:
- File-level XML doc comment (`///` block at top) if present.
- All `public` or `internal` types (class/struct/interface/enum) with
  their XML doc and accessibility modifier.
- All `public` members (methods, properties, fields, events) of those
  types with signatures and XML docs.
- MonoBehaviour lifecycle methods (`Awake`, `Start`, `Update`, etc.) even
  if private — they describe runtime behavior.

Do **not** include method bodies. Signatures + docstrings only.

### Phase 3 — Locate the wiki page for each file

For each C# file path, look for `docs/llm_wiki/tech/**/*.md` containing a
marker exactly `<!-- source: code:<path> -->` where `<path>` is the
repo-relative file path (forward slashes).

- **Match found** → plan to update that block only.
- **No match** → plan to create `docs/llm_wiki/tech/auto/<slug>.md` where
  `<slug>` = relative path with `/` replaced by `_` and `.cs` stripped.

### Phase 4 — Generate section content

For each target, render a markdown block following this template:

```markdown
<!-- source: code:<path> -->
### `<Namespace.Type>` <!-- {type-kind} -->

<file-level doc comment if any>

#### Public API

- `<signature>` — <doc summary or "—">
- ...

#### Lifecycle (if MonoBehaviour)

- `Awake()` — <doc or "—">
- ...

_Last synced from `<path>` at <timestamp>._
<!-- /source: code:<path> -->
```

Use stable ordering: types by declaration order in the file, members by
declaration order within each type. This keeps diffs readable.

### Phase 5 — Apply changes

1. For **match found** files: use the Edit tool with the whole block
   between `<!-- source: code:<path> -->` and the closing `<!-- /source ... -->`
   as `old_string`. If the closing marker is missing (legacy files),
   fall back to the next `<!-- source:` marker or end of file.
2. For **new files**: use the Write tool with a fresh page:
   ```
   ---
   id: tech.auto.<slug>
   title: "<Type name or file name>"
   source_code_paths: ["<path>"]
   generated_by: wiki-sync-code
   updated: <iso8601>
   ---

   # <Type name or file name>

   <!-- source: code:<path> -->
   ...
   <!-- /source: code:<path> -->
   ```

### Phase 6 — Append to log.md

Write one entry to `docs/llm_wiki/log.md`:
```
## [YYYY-MM-DD HH:MM] code-sync | <N> files
- <path> → <wiki-file>
- ...
```

### Phase 7 — Refresh index.md Tech section

Rebuild only the `## Tech` section of `docs/llm_wiki/index.md` from the
current set of `docs/llm_wiki/tech/**/*.md` titles.

### Phase 8 — Propose /notion-push

Emit:
```
wiki-sync-code complete:
  files synced: <N>
  pages updated: <M>
  pages created: <K>
  next: /notion-push --dry-run  (to review before pushing to Notion)
```

**Do not auto-invoke `/notion-push`** — user must approve.

## Forbidden

- Do NOT execute C# — static analysis only.
- Do NOT touch pages without `<!-- source: code:* -->` markers.
- Do NOT overwrite `<!-- source: manual -->` or `<!-- source: notion:* -->`
  blocks on the same page.
- Do NOT call Notion MCP. This skill is code→wiki only.
- Do NOT edit the C# source.

## Arguments

- (no args) — use `git diff --name-only HEAD` + unstaged + untracked.
- `--files <path> [<path>...]` — explicit list.
- `--glob <pattern>` — glob relative to project root (e.g.
  `Assets/Scripts/**/*.cs`).
- `--dry-run` — stop after Phase 4; print the generated blocks without
  writing.
