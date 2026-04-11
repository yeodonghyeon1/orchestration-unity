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
PLUGIN_ROOT="$(cd "$(dirname "$0")/../../.." && pwd)"
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
