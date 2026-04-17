#!/usr/bin/env bash
# Initializes a Unity-orchestration workspace in a target project.
# Creates .orchestration/sessions/<timestamp>-<slug>/ and seeds docs/
# from the plugin's docs-tree template if docs/ is missing.
#
# Usage: init-workspace.sh <project-root> <task-slug>
set -euo pipefail

if [[ $# -lt 2 ]]; then
  echo "usage: init-workspace.sh <project-root> <task-slug>" >&2
  exit 2
fi

PROJECT_ROOT="$1"
TASK_SLUG="$2"
PLUGIN_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
TEMPLATE_DIR="$PLUGIN_ROOT/skills/unity-orchestration/templates/docs-tree"

if [[ ! -d "$PROJECT_ROOT" ]]; then
  echo "error: project root not found: $PROJECT_ROOT" >&2
  exit 1
fi
if [[ ! -d "$TEMPLATE_DIR" ]]; then
  echo "error: template not found: $TEMPLATE_DIR" >&2
  exit 1
fi

TS="$(date -u +%Y%m%dT%H%M%SZ)"
SESSION_ID="${TS}-${TASK_SLUG}"
SESSION_DIR="$PROJECT_ROOT/.orchestration/sessions/$SESSION_ID"

mkdir -p "$SESSION_DIR/proposals" "$SESSION_DIR/votes"

# state.json
cat > "$SESSION_DIR/state.json" <<EOF
{
  "session_id": "$SESSION_ID",
  "task_slug": "$TASK_SLUG",
  "phase": "boot",
  "round": 0,
  "created_at": "$TS",
  "mcp_lock_holder": null,
  "task_id": null
}
EOF

# transcript + mcp-log (empty but present)
: > "$SESSION_DIR/transcript.md"
: > "$SESSION_DIR/mcp-log.md"

# Seed docs/ if missing
if [[ ! -d "$PROJECT_ROOT/docs" ]]; then
  cp -R "$TEMPLATE_DIR" "$PROJECT_ROOT/docs"
fi

echo "$SESSION_DIR"

# --- v1.0 dual-tree additions ---
init_dual_trees() {
    local root="$1"
    mkdir -p "$root/notion_docs/_meta" "$root/develop_docs/_meta"

    local script_dir
    script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

    local sync_state="$root/notion_docs/_meta/sync-state.json"
    local page_map="$root/notion_docs/_meta/page-map.json"

    if [ ! -f "$sync_state" ]; then
        python3 "$script_dir/sync-state.py" init "$sync_state"
        echo "seeded $sync_state"
    fi
    if [ ! -f "$page_map" ]; then
        python3 "$script_dir/page-map.py" init "$page_map"
        echo "seeded $page_map"
    fi
}

init_dual_trees "${1:-.}"
