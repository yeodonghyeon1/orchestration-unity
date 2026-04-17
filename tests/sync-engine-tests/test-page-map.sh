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

test_list_output() {
    local f="$TMPDIR/page-map-list.json"
    python3 "$PM" init "$f"
    python3 "$PM" add "$f" "uuid-A" "개발" "dev"
    python3 "$PM" add "$f" "uuid-B" "아트" "art"
    local count
    count="$(python3 "$PM" list "$f" | wc -l)"
    [ "$count" -eq 2 ] || fail "list should return 2 lines, got $count"
    python3 "$PM" list "$f" | grep -q "uuid-A" || fail "list missing uuid-A"
    python3 "$PM" list "$f" | grep -q "uuid-B" || fail "list missing uuid-B"
    pass "list prints TSV of all mappings"
}

test_duplicate_folder_rejected() {
    local f="$TMPDIR/page-map-dup.json"
    python3 "$PM" init "$f"
    python3 "$PM" add "$f" "uuid-A" "개발" "dev"
    if python3 "$PM" add "$f" "uuid-B" "뭔가다른거" "dev" 2>/dev/null; then
        fail "should reject folder 'dev' mapped to different page"
    fi
    pass "duplicate folder rejected for different page"
}

test_get_missing_returns_nonzero() {
    local f="$TMPDIR/page-map-getmiss.json"
    python3 "$PM" init "$f"
    local exit_code=0
    python3 "$PM" get "$f" "nonexistent-uuid" 2>&1 >/dev/null || exit_code=$?
    [ "$exit_code" -eq 1 ] || fail "get on missing page should exit 1 (got $exit_code)"
    pass "get missing page → exit 1"
}

test_init_creates_empty_map
test_add_mapping
test_slugify_korean
test_reserved_names_rejected
test_list_output
test_duplicate_folder_rejected
test_get_missing_returns_nonzero

echo "All page-map tests passed"
