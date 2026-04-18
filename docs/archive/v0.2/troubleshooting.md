---
id: plugin-docs.troubleshooting
title: Troubleshooting
owner: developer
status: stable
updated: 2026-04-11
version: 1
tags: [troubleshooting]
---

# Troubleshooting

## `/unity-orchestration` says "Unknown skill"

Claude Code hasn't loaded this plugin. Check:
- `.claude-plugin/plugin.json` parses (run
  `python3 -c "import json; json.load(open('.claude-plugin/plugin.json'))"`).
- The plugin directory is discoverable by Claude Code (consult Claude
  Code's plugin loader docs).
- You restarted Claude Code after installing.

## Unity MCP is unreachable

Symptoms: developer/designer agents report `mcp_lock acquire` timing out
or HTTP errors when calling `unity-mcp` tools.

Fixes:
1. Make sure Unity editor is running.
2. `curl http://localhost:8090/health` — if this fails, the `unity-mcp`
   server is down; toggle the editor window or reinstall.
3. Check for port conflicts — `unity-mcp` scans 8090–8100.
4. If the editor is in the middle of a Domain Reload, wait 10s and retry.

## Plan vote fails three rounds in a row

The team lead escalates to the user and writes an ADR. Read
`docs/decisions/<latest>.md` for the forced decision and comment on the
team lead's escalation message if you want to override it.

## Accept vote fails twice

The recorder archive might be insufficient or the cross-review exposed
real defects. Read `.orchestration/sessions/<id>/votes/accept-round-*.md`
for details. Options:
- Let the team re-enter Phase 2 one more time.
- Terminate the session and start a smaller task.

## `structure-check.sh` complains about frontmatter

Run the check on the specific file it names; fix missing fields per
`skills/unity-orchestration/docs-tree-spec.md`. Re-run until it passes.

## Recorder says `_meta/index.json` is stale

Run `python3 skills/unity-orchestration/scripts/update-docs-index.py
<docs-dir>` and commit the result.

## Scripts fail with "permission denied" on Windows

Make sure the executable bit is tracked in git:
```
git update-index --chmod=+x <script-path>
```
Rerun via `bash <script-path>` explicitly if the shim still refuses.

## Session is stuck and I want out

Close Claude Code. The session state is on disk at
`.orchestration/sessions/<id>/state.json`; you can resume later (manual in
v1) or delete the directory to start fresh.
