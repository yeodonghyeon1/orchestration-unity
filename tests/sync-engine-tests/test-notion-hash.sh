#!/usr/bin/env bash
# test-notion-hash.sh — unit tests for scripts/notion-hash.py
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
H="$REPO_ROOT/scripts/notion-hash.py"

pass() { echo "  ✓ $1"; }
fail() { echo "  ✗ $1" >&2; exit 1; }

test_identical_content_same_hash() {
    local h1 h2
    h1="$(echo '{"type":"page","content":"hello"}' | python3 "$H")"
    h2="$(echo '{"type":"page","content":"hello"}' | python3 "$H")"
    [ "$h1" = "$h2" ] || fail "identical inputs should hash equal: $h1 vs $h2"
    pass "identical content → same hash"
}

test_volatile_fields_ignored() {
    local h1 h2
    h1="$(echo '{"type":"page","last_edited_time":"2026-01-01T00:00:00Z","content":"x"}' | python3 "$H")"
    h2="$(echo '{"type":"page","last_edited_time":"2026-04-18T12:00:00Z","content":"x"}' | python3 "$H")"
    [ "$h1" = "$h2" ] || fail "different last_edited_time should NOT affect hash"
    pass "volatile fields ignored"
}

test_different_content_different_hash() {
    local h1 h2
    h1="$(echo '{"content":"a"}' | python3 "$H")"
    h2="$(echo '{"content":"b"}' | python3 "$H")"
    [ "$h1" != "$h2" ] || fail "different content should hash differently"
    pass "different content → different hash"
}

test_key_order_independent() {
    local h1 h2
    h1="$(echo '{"a":1,"b":2}' | python3 "$H")"
    h2="$(echo '{"b":2,"a":1}' | python3 "$H")"
    [ "$h1" = "$h2" ] || fail "key order should not matter"
    pass "key order independent"
}

test_output_prefix() {
    local out
    out="$(echo '{"x":1}' | python3 "$H")"
    [[ "$out" == sha256:* ]] || fail "output must start with sha256: (got '$out')"
    pass "output has sha256: prefix"
}

test_identical_content_same_hash
test_volatile_fields_ignored
test_different_content_different_hash
test_key_order_independent
test_output_prefix

echo "All notion-hash tests passed"
