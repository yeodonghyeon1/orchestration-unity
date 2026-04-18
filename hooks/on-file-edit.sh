#!/usr/bin/env bash
# orchestration-unity post-edit router (thin)
# Reads Claude Code hook payload on stdin; surfaces a system message when a
# file edit is relevant to the llm-wiki pipeline. Intentionally does NOT
# auto-invoke slash commands — only suggests.
set -euo pipefail

payload=$(cat 2>/dev/null || true)
file=$(printf '%s' "$payload" | jq -r '.tool_input.file_path // empty' 2>/dev/null || true)
[ -z "$file" ] && exit 0

case "$file" in
  */Assets/*.cs|*/Assets/**/*.cs)
    msg="[orchestration-unity] Assets C# edit detected ($file). Run /wiki-sync-code to update docs/llm_wiki/tech/."
    ;;
  */llm_wiki/*.md|*/llm_wiki/**/*.md)
    msg="[orchestration-unity] llm_wiki edit detected ($file). Run /notion-push --dry-run to review before pushing."
    ;;
  *)
    exit 0
    ;;
esac

printf '{"systemMessage": %s}\n' "$(printf '%s' "$msg" | jq -R -s .)" 2>/dev/null || printf '{"systemMessage": "%s"}\n' "$msg"
exit 0
