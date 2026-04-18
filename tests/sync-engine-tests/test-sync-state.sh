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
    python3 "$SS" get-hash "$f" "uuid-1" >/dev/null 2>&1 && fail "deleted page should not be in pages"
    python3 "$SS" list-orphans "$f" | grep -q "uuid-1" || fail "should be in orphans"
    pass "delete moves to orphans"
}

test_atomic_write() {
    local f="$TMPDIR/ss-atomic.json"
    python3 "$SS" init "$f"
    [ ! -f "$f.tmp" ] || fail "tmp file should not remain"
    pass "atomic write leaves no tmp file"
}

test_list_pages_output() {
    local f="$TMPDIR/ss-listpages.json"
    python3 "$SS" init "$f"
    python3 "$SS" upsert "$f" "uuid-A" "dev/a.md" "sha256:1" "2026-04-18T10:00:00Z"
    python3 "$SS" upsert "$f" "uuid-B" "art/b.md" "sha256:2" "2026-04-18T10:01:00Z"
    local count
    count="$(python3 "$SS" list-pages "$f" | wc -l)"
    [ "$count" -eq 2 ] || fail "list-pages should print 2 lines, got $count"
    python3 "$SS" list-pages "$f" | grep -q "uuid-A" || fail "missing uuid-A"
    python3 "$SS" list-pages "$f" | grep -q "dev/a.md" || fail "missing path"
    python3 "$SS" list-pages "$f" | grep -q "sha256:2" || fail "missing hash"
    pass "list-pages TSV output correct"
}

test_init
test_upsert_page
test_delete_to_orphan
test_atomic_write
test_list_pages_output

echo "All sync-state tests passed"
