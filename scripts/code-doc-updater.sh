#!/usr/bin/env bash
# code-doc-updater.sh — after code changes, update develop_docs/tech/unity/**
# with fresh C# signatures via code-to-docs.py + provenance.py.
#
# Usage:
#     scripts/code-doc-updater.sh <file1.cs> [<file2.cs> ...]
#
# For each input file:
#   1. Find develop_docs/tech/unity/**/*.md that references this file in
#      code_references[].path frontmatter (grep-based; no YAML parser).
#   2. Run code-to-docs.py on the file to generate the new code section.
#   3. Run provenance.py replace (or append if marker missing) to merge.
#
# Non-fatal on errors — logs and continues so it doesn't block Step 11.
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
C2D="$SCRIPT_DIR/code-to-docs.py"
PROV="$SCRIPT_DIR/provenance.py"

DEV_DOCS="${DEVELOP_DOCS:-develop_docs}"
if [ ! -d "$DEV_DOCS/tech/unity" ]; then
    echo "warn: $DEV_DOCS/tech/unity not found — nothing to update" >&2
    exit 0
fi

for cs_file in "$@"; do
    if [ ! -f "$cs_file" ]; then
        echo "skip: $cs_file (not a file)" >&2
        continue
    fi

    matches=$(grep -rl "path: $cs_file" "$DEV_DOCS/tech/unity" 2>/dev/null || true)
    if [ -z "$matches" ]; then
        echo "info: no develop_docs references $cs_file — skipping" >&2
        continue
    fi

    tmp_section=$(mktemp)
    python3 "$C2D" "$cs_file" > "$tmp_section" || {
        echo "warn: code-to-docs.py failed on $cs_file" >&2
        rm -f "$tmp_section"
        continue
    }

    marker="code:$cs_file"

    for doc in $matches; do
        if python3 "$PROV" sources "$doc" | grep -qx "$marker"; then
            python3 "$PROV" replace "$doc" "$marker" "$tmp_section" \
                && echo "updated: $doc ($marker)" \
                || echo "warn: replace failed for $doc" >&2
        else
            python3 "$PROV" append "$doc" "$marker" "$tmp_section" \
                && echo "appended: $doc ($marker)" \
                || echo "warn: append failed for $doc" >&2
        fi
    done

    rm -f "$tmp_section"
done

exit 0
