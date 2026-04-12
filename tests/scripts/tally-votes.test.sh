#!/usr/bin/env bash
# Tests for scripts/tally-votes.sh
set -euo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$HERE/../.." && pwd)"
SCRIPT="$ROOT/skills/unity-orchestration/scripts/tally-votes.sh"

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

FAILED=0

# --- Case 1: passing round (7 approve / 2 reject / 1 abstain) ------------
out="$TMP/pass.md"
bash "$SCRIPT" \
  --round 1 \
  --type plan \
  --task "test enemy ai" \
  --input "$ROOT/tests/fixtures/votes/round-pass" \
  --output "$out"

grep -q "Result:.*PASS" "$out" || { echo "FAIL: pass round did not produce PASS"; FAILED=1; }
grep -q "7 approve" "$out"     || { echo "FAIL: tally count wrong"; FAILED=1; }
grep -q "2 reject"  "$out"     || { echo "FAIL: reject count wrong"; FAILED=1; }
grep -q "1 abstain" "$out"     || { echo "FAIL: abstain count wrong"; FAILED=1; }
grep -q "planner-a" "$out"     || { echo "FAIL: row missing"; FAILED=1; }

# Exit code should be 0 on pass (run a second time to capture clean status)
set +e
bash "$SCRIPT" --round 1 --type plan --task t \
  --input "$ROOT/tests/fixtures/votes/round-pass" \
  --output "$TMP/pass2.md"
pass_exit=$?
set -e
[[ $pass_exit -eq 0 ]] || { echo "FAIL: expected exit 0 on pass, got $pass_exit"; FAILED=1; }

# --- Case 2: failing round (4 approve / 4 reject / 2 abstain) ------------
set +e
bash "$SCRIPT" \
  --round 2 \
  --type plan \
  --task "test enemy ai" \
  --input "$ROOT/tests/fixtures/votes/round-fail" \
  --output "$TMP/fail.md"
fail_exit=$?
set -e

grep -q "Result:.*FAIL" "$TMP/fail.md" || { echo "FAIL: fail round did not produce FAIL"; FAILED=1; }
grep -q "4 approve" "$TMP/fail.md"     || { echo "FAIL: fail approve count"; FAILED=1; }
[[ $fail_exit -eq 1 ]]                 || { echo "FAIL: expected exit 1 on fail, got $fail_exit"; FAILED=1; }

# --- Case 3: bad input directory ------------------------------------------
set +e
bash "$SCRIPT" --round 1 --type plan --task t \
    --input "$TMP/does-not-exist" --output "$TMP/err.md" 2>/dev/null
bad_exit=$?
set -e
[[ $bad_exit -ne 0 ]] || { echo "FAIL: expected non-zero exit on missing input"; FAILED=1; }

if [[ $FAILED -eq 0 ]]; then
  echo "tally-votes.test.sh: PASS"
else
  echo "tally-votes.test.sh: FAIL"
  exit 1
fi
