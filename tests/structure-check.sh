#!/usr/bin/env bash
# tests/structure-check.sh
# Validates plugin structure. Exits 0 on success, 1 on failure.
# Usage: ./tests/structure-check.sh [plugin-root]
set -euo pipefail

ROOT="${1:-$(cd "$(dirname "$0")/.." && pwd)}"

# Windows git-bash: native python3 needs Windows-style paths.
if command -v cygpath >/dev/null 2>&1; then
  ROOT="$(cygpath -m "$ROOT")"
fi

ERRORS=0

err() { echo "FAIL: $1" >&2; ERRORS=$((ERRORS + 1)); }
ok()  { echo "OK:   $1"; }

check_file() {
  local rel="$1"
  if [[ -f "$ROOT/$rel" ]]; then
    ok "$rel"
  else
    err "$rel missing"
  fi
}

# Validate a file has docs-tree frontmatter (id/title/owner/status/updated/version)
check_frontmatter() {
  local rel="$1"
  local path="$ROOT/$rel"
  if [[ ! -f "$path" ]]; then
    err "$rel missing"
    return
  fi
  if ! head -1 "$path" | grep -q '^---$'; then
    err "$rel: no frontmatter start"
    return
  fi
  local fm
  fm="$(awk '/^---$/{c++; next} c==1{print} c==2{exit}' "$path")"
  local missing=""
  for k in id title owner status updated version; do
    if ! printf '%s\n' "$fm" | grep -q "^${k}:"; then
      missing="$missing $k"
    fi
  done
  if [[ -n "$missing" ]]; then
    err "$rel: missing frontmatter field(s):$missing"
  else
    ok "$rel"
  fi
}

# --- plugin.json --------------------------------------------------------
if [[ ! -f "$ROOT/.claude-plugin/plugin.json" ]]; then
  err ".claude-plugin/plugin.json missing"
else
  if python3 -c "
import json, sys
d = json.load(open('$ROOT/.claude-plugin/plugin.json'))
for k in ('name','description','version'):
    if k not in d: sys.exit('missing key: ' + k)
if d['name'] != 'unity-orchestration':
    sys.exit('name must be unity-orchestration, got: ' + d['name'])
" 2>/tmp/sc_err; then
    ok ".claude-plugin/plugin.json"
  else
    err ".claude-plugin/plugin.json: $(cat /tmp/sc_err 2>/dev/null)"
  fi
  rm -f /tmp/sc_err
fi

# --- root files ---------------------------------------------------------
for f in README.md LICENSE CHANGELOG.md .gitignore; do
  check_file "$f"
done

# --- SKILL.md (Claude Code skill frontmatter: name + description only) --
if [[ -f "$ROOT/skills/unity-orchestration/SKILL.md" ]]; then
  fm="$(awk '/^---$/{c++; next} c==1{print} c==2{exit}' \
    "$ROOT/skills/unity-orchestration/SKILL.md")"
  skill_missing=""
  for k in name description; do
    if ! printf '%s\n' "$fm" | grep -q "^${k}:"; then
      skill_missing="$skill_missing $k"
    fi
  done
  if [[ -n "$skill_missing" ]]; then
    err "skills/unity-orchestration/SKILL.md: missing frontmatter field(s):$skill_missing"
  else
    ok "skills/unity-orchestration/SKILL.md"
  fi
else
  err "skills/unity-orchestration/SKILL.md missing"
fi

# --- Docs-tree-schema files (full 6-field frontmatter) -----------------
for f in \
  skills/unity-orchestration/workflow.md \
  skills/unity-orchestration/voting.md \
  skills/unity-orchestration/consultation-table.md \
  skills/unity-orchestration/docs-tree-spec.md \
  skills/unity-orchestration/agents/team-lead.md \
  skills/unity-orchestration/agents/planner.md \
  skills/unity-orchestration/agents/designer.md \
  skills/unity-orchestration/agents/developer.md \
  skills/unity-orchestration/agents/recorder.md \
  skills/unity-orchestration/agents/tester.md \
  skills/unity-orchestration/templates/docs-tree/README.md \
  skills/unity-orchestration/templates/docs-tree/_meta/glossary.md \
  skills/unity-orchestration/templates/docs-tree/_meta/conventions.md \
  skills/unity-orchestration/templates/docs-tree/game/README.md \
  skills/unity-orchestration/templates/docs-tree/design/README.md \
  skills/unity-orchestration/templates/docs-tree/tech/README.md \
  docs/getting-started.md \
  docs/architecture.md \
  docs/troubleshooting.md; do
  check_frontmatter "$f"
done

# --- Files that must simply exist ---------------------------------------
for f in \
  commands/unity-orchestration.md \
  commands/notion-sync.md \
  agents/unity-orchestrator.md \
  skills/unity-orchestration/templates/task-table.template.md \
  skills/unity-orchestration/templates/vote-message.template.json \
  skills/unity-orchestration/templates/adr.template.md \
  skills/unity-orchestration/templates/doc-frontmatter.template.yaml \
  skills/unity-orchestration/templates/docs-tree/_meta/index.json \
  skills/unity-orchestration/templates/docs-tree/decisions/.gitkeep \
  skills/unity-orchestration/templates/docs-tree/tasks/.gitkeep \
  skills/unity-orchestration/templates/docs-tree/CHANGELOG.md \
  scripts/init-workspace.sh \
  skills/unity-orchestration/scripts/tally-votes.sh \
  skills/unity-orchestration/scripts/update-docs-index.py \
  tests/scripts/init-workspace.test.sh \
  tests/scripts/tally-votes.test.sh \
  tests/scripts/update-docs-index.test.sh; do
  check_file "$f"
done

# --- JSON validity ------------------------------------------------------
for f in \
  skills/unity-orchestration/templates/vote-message.template.json \
  skills/unity-orchestration/templates/docs-tree/_meta/index.json; do
  if [[ -f "$ROOT/$f" ]]; then
    if python3 -c "import json; json.load(open('$ROOT/$f'))" 2>/dev/null; then
      ok "$f (json)"
    else
      err "$f: invalid JSON"
    fi
  fi
done

# --- Script executable bits --------------------------------------------
for s in \
  scripts/init-workspace.sh \
  skills/unity-orchestration/scripts/tally-votes.sh \
  skills/unity-orchestration/scripts/update-docs-index.py \
  tests/structure-check.sh \
  tests/scripts/init-workspace.test.sh \
  tests/scripts/tally-votes.test.sh \
  tests/scripts/update-docs-index.test.sh \
  tests/integration/test-notion-sync.sh; do
  if [[ -f "$ROOT/$s" && ! -x "$ROOT/$s" ]]; then
    err "$s: not executable (run: chmod +x $s)"
  fi
done

# --- v1.0 dual-tree init test ---
test_dual_tree_init() {
    local tmp
    tmp="$(mktemp -d)"
    # Convert to Windows-style path for python3 if on git-bash
    if command -v cygpath >/dev/null 2>&1; then
        tmp="$(cygpath -m "$tmp")"
    fi
    bash "$ROOT/scripts/init-workspace.sh" "$tmp" "test-slug" >/dev/null 2>&1 || true
    if [[ ! -d "$tmp/notion_docs/_meta" ]]; then
        err "dual-tree init: notion_docs/_meta missing"
        return 1
    fi
    if [[ ! -d "$tmp/develop_docs/_meta" ]]; then
        err "dual-tree init: develop_docs/_meta missing"
        return 1
    fi
    if [[ ! -f "$tmp/notion_docs/_meta/sync-state.json" ]]; then
        err "dual-tree init: sync-state.json not seeded"
        return 1
    fi
    if [[ ! -f "$tmp/notion_docs/_meta/page-map.json" ]]; then
        err "dual-tree init: page-map.json not seeded"
        return 1
    fi
    rm -rf "$tmp"
    ok "dual-tree init (notion_docs + develop_docs + _meta files)"
}
test_dual_tree_init

# --- v1.0 notion-sync skill scaffold ---
check_file "skills/notion-sync/SKILL.md"
check_file "skills/notion-sync/change-detection.md"
check_file "skills/notion-sync/templates/notion-doc-frontmatter.md"

# --- v1.0 integration tests ---
check_file "tests/integration/test-notion-sync.sh"

# --- Report -------------------------------------------------------------
if [[ $ERRORS -gt 0 ]]; then
  echo
  echo "structure-check: $ERRORS error(s)" >&2
  exit 1
fi
echo
echo "structure-check: passed"
