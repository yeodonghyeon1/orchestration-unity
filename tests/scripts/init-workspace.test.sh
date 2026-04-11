#!/usr/bin/env bash
# Tests for scripts/init-workspace.sh
set -euo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$HERE/../.." && pwd)"
SCRIPT="$ROOT/skills/unity-orchestration/scripts/init-workspace.sh"
TEMPLATES="$ROOT/skills/unity-orchestration/templates/docs-tree"

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

FAILED=0
assert_file() { [[ -f "$1" ]] || { echo "FAIL: missing file $1"; FAILED=1; }; }
assert_dir()  { [[ -d "$1" ]] || { echo "FAIL: missing dir  $1"; FAILED=1; }; }

# --- Case 1: empty project, session + docs both scaffolded ----------------
mkdir -p "$TMP/proj1"
bash "$SCRIPT" "$TMP/proj1" "test-task-slug" >/dev/null

# session dir should exist under .orchestration/sessions/<timestamp>-slug
session_dir="$(find "$TMP/proj1/.orchestration/sessions" -mindepth 1 -maxdepth 1 -type d | head -1)"
assert_dir  "$session_dir"
assert_file "$session_dir/state.json"
assert_dir  "$session_dir/proposals"
assert_dir  "$session_dir/votes"
assert_file "$session_dir/transcript.md"
assert_file "$session_dir/mcp-log.md"

# docs/ should be seeded from template
assert_file "$TMP/proj1/docs/README.md"
assert_file "$TMP/proj1/docs/_meta/index.json"
assert_file "$TMP/proj1/docs/game/README.md"
assert_file "$TMP/proj1/docs/CHANGELOG.md"

# --- Case 2: project with existing docs, docs preserved -------------------
mkdir -p "$TMP/proj2/docs"
echo "# existing" > "$TMP/proj2/docs/README.md"
bash "$SCRIPT" "$TMP/proj2" "another-slug" >/dev/null
existing="$(cat "$TMP/proj2/docs/README.md")"
if [[ "$existing" != "# existing" ]]; then
  echo "FAIL: existing docs/README.md was overwritten"
  FAILED=1
fi

# --- Case 3: state.json is valid JSON with required fields ---------------
session_dir2="$(find "$TMP/proj1/.orchestration/sessions" -mindepth 1 -maxdepth 1 -type d | head -1)"
# Use cygpath for Windows python3 compatibility
if command -v cygpath >/dev/null 2>&1; then
  sjson="$(cygpath -m "$session_dir2/state.json")"
else
  sjson="$session_dir2/state.json"
fi
python3 -c "
import json, sys
d = json.load(open('$sjson'))
for k in ('session_id','task_slug','phase','round','created_at'):
    if k not in d: sys.exit('missing key: ' + k)
if d['phase'] != 'boot': sys.exit('phase should be boot, got ' + d['phase'])
" || FAILED=1

if [[ $FAILED -eq 0 ]]; then
  echo "init-workspace.test.sh: PASS"
else
  echo "init-workspace.test.sh: FAIL"
  exit 1
fi
