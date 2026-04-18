#!/usr/bin/env bash
# migrate-v02-to-v1.sh — migrate an existing v0.2.0 orchestration-unity
# Unity project to the v1.0 layout.
#
# Behavior:
#   1. Detect existing `docs/` tree (v0.2.0 style). If present, move
#      its content into `develop_docs/`.
#   2. Scaffold `notion_docs/` (via init-workspace.sh).
#   3. Preserve `.orchestration/sessions/` untouched (historical).
#   4. Print a summary.
#
# Flags:
#   --yes         skip interactive prompts (for CI/tests)
#   --dry-run     print what would be done, do not modify anything
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

YES=0
DRY=0
for arg in "$@"; do
    case "$arg" in
        --yes) YES=1 ;;
        --dry-run) DRY=1 ;;
    esac
done

confirm() {
    if [ "$YES" -eq 1 ]; then return 0; fi
    read -r -p "$1 [y/N] " ans
    [[ "$ans" =~ ^[Yy]$ ]]
}

log() { echo "  ▸ $*"; }
act() { [ "$DRY" -eq 1 ] && log "DRY: $*" || { log "$*"; eval "$@"; }; }

echo "=== orchestration-unity v0.2 → v1.0 migration ==="

# 1. docs/ → develop_docs/
if [ -d docs ] && [ ! -d develop_docs ]; then
    echo "Detected v0.2.0 docs/ tree."
    if confirm "Move docs/ → develop_docs/ ?"; then
        act "mkdir -p develop_docs"
        for d in game design tech decisions tasks _meta; do
            if [ -d "docs/$d" ]; then
                act "mv docs/$d develop_docs/"
            fi
        done
        log "moved docs/ content → develop_docs/"
    else
        log "skipped docs/ migration"
    fi
else
    log "no v0.2.0 docs/ tree found (or develop_docs already exists); skipping"
fi

# 2. Scaffold notion_docs via Python scripts
if [ ! -d notion_docs ]; then
    if confirm "Scaffold notion_docs/ and _meta/ files?"; then
        act "mkdir -p notion_docs/_meta develop_docs/_meta"
        act "python3 $SCRIPT_DIR/sync-state.py init notion_docs/_meta/sync-state.json"
        act "python3 $SCRIPT_DIR/page-map.py init notion_docs/_meta/page-map.json"
        log "notion_docs/ scaffolded with _meta files"
    else
        log "skipped notion_docs scaffold"
    fi
fi

# 3. .orchestration/ preserved as-is
if [ -d .orchestration ]; then
    log "preserving .orchestration/ as historical (no action)"
fi

# 4. Summary
echo ""
echo "=== migration complete ==="
echo "next steps:"
echo "  - fill notion_docs/_meta/page-map.json via /notion-sync (or manually)"
echo "  - review CHANGELOG for v1.0 breaking changes"
echo "  - run: bash tests/structure-check.sh"
