#!/usr/bin/env bash
# Tallies votes from a directory of per-agent JSON files and writes a
# markdown report. Exits 0 on pass (>=5 approvals / 9), 1 on fail, 2 on
# usage / input errors.
#
# Usage:
#   tally-votes.sh --round N --type plan|accept --task "<task>" \
#                  --input <dir> --output <file>
set -euo pipefail

round=""; type=""; task=""; input=""; output=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    --round)  round="$2";  shift 2 ;;
    --type)   type="$2";   shift 2 ;;
    --task)   task="$2";   shift 2 ;;
    --input)  input="$2";  shift 2 ;;
    --output) output="$2"; shift 2 ;;
    *) echo "unknown arg: $1" >&2; exit 2 ;;
  esac
done

for req in round type task input output; do
  if [[ -z "${!req}" ]]; then
    echo "missing required: --$req" >&2
    exit 2
  fi
done

if [[ ! -d "$input" ]]; then
  echo "error: input dir not found: $input" >&2
  exit 2
fi

# Normalize paths for Windows native python3
if command -v cygpath >/dev/null 2>&1; then
  input="$(cygpath -m "$input")"
  output="$(cygpath -m "$output")"
fi

# Use python for JSON parsing (jq may be unavailable on Windows git-bash).
python3 - "$input" "$output" "$round" "$type" "$task" <<'PY'
import json, os, sys
from datetime import datetime, timezone

input_dir = sys.argv[1]
output    = sys.argv[2]
round_n   = sys.argv[3]
vtype     = sys.argv[4]
task      = sys.argv[5]

entries = []
for fname in sorted(os.listdir(input_dir)):
    if not fname.endswith('.json'):
        continue
    agent = fname[:-5]
    path  = os.path.join(input_dir, fname)
    try:
        d = json.load(open(path, encoding='utf-8'))
    except Exception as e:
        sys.stderr.write(f"bad json in {fname}: {e}\n")
        sys.exit(2)
    for k in ('vote', 'reason', 'blocking_issues', 'suggestions'):
        if k not in d:
            sys.stderr.write(f"{fname} missing key: {k}\n")
            sys.exit(2)
    if d['vote'] not in ('approve', 'reject', 'abstain'):
        sys.stderr.write(f"{fname} invalid vote: {d['vote']}\n")
        sys.exit(2)
    entries.append((agent, d))

if len(entries) != 9:
    sys.stderr.write(f"expected 9 votes, got {len(entries)}\n")
    sys.exit(2)

approve = sum(1 for _, d in entries if d['vote'] == 'approve')
reject  = sum(1 for _, d in entries if d['vote'] == 'reject')
abstain = sum(1 for _, d in entries if d['vote'] == 'abstain')
result  = "PASS" if approve >= 5 else "FAIL"
date    = datetime.now(timezone.utc).strftime("%Y-%m-%d")

header = f"# {vtype.capitalize()} Vote — Round {round_n}\n\n"
header += f"- **Task:** {task}\n"
header += f"- **Date:** {date}\n"
header += f"- **Result:** {result} ({approve} approve / {reject} reject / {abstain} abstain)\n\n"

table = "| Agent | Vote | Reason |\n|-------|------|--------|\n"
for agent, d in entries:
    reason = d['reason'].replace('|', '\\|')
    table += f"| {agent} | {d['vote']} | {reason} |\n"
table += "\n"

issues = []
for _, d in entries:
    issues.extend(d.get('blocking_issues', []))
suggestions = []
for _, d in entries:
    suggestions.extend(d.get('suggestions', []))

body = ""
if issues:
    body += "## Blocking issues\n" + "".join(f"- {i}\n" for i in issues) + "\n"
if suggestions:
    body += "## Suggestions\n"   + "".join(f"- {s}\n" for s in suggestions) + "\n"

os.makedirs(os.path.dirname(output) or '.', exist_ok=True)
with open(output, 'w', encoding='utf-8') as f:
    f.write(header + table + body)

sys.exit(0 if result == "PASS" else 1)
PY
