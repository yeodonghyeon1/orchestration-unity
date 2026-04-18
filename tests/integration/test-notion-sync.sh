#!/usr/bin/env bash
# test-notion-sync.sh — end-to-end test using fixtures (no real Notion)
#
# Simulates a /notion-sync run by driving the scripts directly with
# fixture JSON. Does NOT exercise the skill markdown or Claude loop.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
FIXTURE="$REPO_ROOT/tests/fixture/mock-notion-responses"

pass() { echo "  ✓ $1"; }
fail() { echo "  ✗ $1" >&2; exit 1; }

TMP="$(mktemp -d)"
if command -v cygpath >/dev/null 2>&1; then
    TMP="$(cygpath -m "$TMP")"
fi
trap 'rm -rf "$TMP"' EXIT

cd "$TMP"
bash "$REPO_ROOT/scripts/init-workspace.sh" "$TMP" "test-sync" >/dev/null 2>&1 || true

SS="$TMP/notion_docs/_meta/sync-state.json"
PM="$TMP/notion_docs/_meta/page-map.json"

[ -f "$SS" ] || fail "sync-state.json not seeded by init-workspace.sh"
[ -f "$PM" ] || fail "page-map.json not seeded by init-workspace.sh"
pass "init-workspace seeded both meta files"

# Add mappings for the three starter pages
python3 "$REPO_ROOT/scripts/page-map.py" add "$PM" "uuid-dev" "개발" "dev"
python3 "$REPO_ROOT/scripts/page-map.py" add "$PM" "uuid-art" "아트" "art"
python3 "$REPO_ROOT/scripts/page-map.py" add "$PM" "uuid-plan" "기획" "plan"

mappings="$(python3 "$REPO_ROOT/scripts/page-map.py" list "$PM" | wc -l)"
[ "$mappings" -eq 3 ] || fail "expected 3 mappings, got $mappings"
pass "page-map has 3 mappings after seed"

# Compute hashes from fixtures (exercises notion-hash.py)
hash_dev="$(python3 "$REPO_ROOT/scripts/notion-hash.py" "$FIXTURE/page-dev.json")"
hash_art="$(python3 "$REPO_ROOT/scripts/notion-hash.py" "$FIXTURE/page-art.json")"
hash_plan="$(python3 "$REPO_ROOT/scripts/notion-hash.py" "$FIXTURE/page-plan.json")"

[[ "$hash_dev" == sha256:* ]] || fail "bad hash format: $hash_dev"
[[ "$hash_art" == sha256:* ]] || fail "bad hash format: $hash_art"
[[ "$hash_plan" == sha256:* ]] || fail "bad hash format: $hash_plan"
pass "3 fixture hashes computed correctly"

# Upsert into sync-state (exercises sync-state.py)
python3 "$REPO_ROOT/scripts/sync-state.py" upsert "$SS" "uuid-dev" "dev/page-dev.md" "$hash_dev" "2026-04-18T09:00:00Z"
python3 "$REPO_ROOT/scripts/sync-state.py" upsert "$SS" "uuid-art" "art/page-art.md" "$hash_art" "2026-04-18T09:05:00Z"
python3 "$REPO_ROOT/scripts/sync-state.py" upsert "$SS" "uuid-plan" "plan/page-plan.md" "$hash_plan" "2026-04-18T09:10:00Z"

lines="$(python3 "$REPO_ROOT/scripts/sync-state.py" list-pages "$SS" | wc -l)"
[ "$lines" -eq 3 ] || fail "expected 3 pages in sync-state, got $lines"
pass "sync-state has 3 pages after upsert"

# Idempotency: hash identical payloads twice → same result
h1="$(python3 "$REPO_ROOT/scripts/notion-hash.py" "$FIXTURE/page-dev.json")"
h2="$(python3 "$REPO_ROOT/scripts/notion-hash.py" "$FIXTURE/page-dev.json")"
[ "$h1" = "$h2" ] || fail "fixture hash not stable across runs"
pass "fixture hash stable across runs"

# Retrieve stored hash back via get-hash
stored="$(python3 "$REPO_ROOT/scripts/sync-state.py" get-hash "$SS" "uuid-dev")"
[ "$stored" = "$hash_dev" ] || fail "get-hash roundtrip failed"
pass "hash roundtrip through sync-state"

# Deletion flow
python3 "$REPO_ROOT/scripts/sync-state.py" move-to-orphans "$SS" "uuid-plan"
orphan_count="$(python3 "$REPO_ROOT/scripts/sync-state.py" list-orphans "$SS" | wc -l)"
[ "$orphan_count" -eq 1 ] || fail "expected 1 orphan after delete, got $orphan_count"

remaining="$(python3 "$REPO_ROOT/scripts/sync-state.py" list-pages "$SS" | wc -l)"
[ "$remaining" -eq 2 ] || fail "expected 2 remaining pages, got $remaining"
pass "deletion moves to orphans correctly (1 orphan, 2 remain)"

echo "All integration tests passed (7/7)"
