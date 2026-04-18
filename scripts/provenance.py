#!/usr/bin/env python3
"""provenance.py — parse/merge HTML-comment provenance markers in markdown.

Section grammar:
    <!-- source: <tag> -->
    ...content...
    <!-- /source -->

Tags are either:
    notion:<path-id>        e.g. notion:plan.combat-system
    code:<path>             e.g. code:Assets/Scripts/Combat.cs
    manual                  (literal)

Subcommands:
    sources <file>                   — list all source tags
    extract <file> <tag>             — print the section body for the tag
    replace <file> <tag> <new-body>  — replace section body (preserves others)
    append <file> <tag> <new-body>   — add a new section (new-body can be '-' for stdin)
    strip <file> <tag>               — remove the section entirely
"""

import re
import sys
from pathlib import Path

START_RE = re.compile(r"<!--\s*source:\s*(\S+)\s*-->")
END_RE = re.compile(r"<!--\s*/source\s*-->")


def parse(text: str):
    lines = text.splitlines(keepends=True)
    i = 0
    while i < len(lines):
        m = START_RE.search(lines[i])
        if m:
            tag = m.group(1)
            start = i
            content_start = i + 1
            j = content_start
            while j < len(lines):
                if END_RE.search(lines[j]):
                    yield tag, start, "".join(lines[content_start:j]), j
                    i = j + 1
                    break
                j += 1
            else:
                i = len(lines)
        else:
            i += 1


def cmd_sources(path: str) -> int:
    text = Path(path).read_text(encoding="utf-8")
    for tag, _, _, _ in parse(text):
        print(tag)
    return 0


def cmd_extract(path: str, tag: str) -> int:
    text = Path(path).read_text(encoding="utf-8")
    for t, _, content, _ in parse(text):
        if t == tag:
            sys.stdout.write(content)
            return 0
    return 1


def cmd_replace(path: str, tag: str, body_src: str) -> int:
    new_body = sys.stdin.read() if body_src == "-" else Path(body_src).read_text(encoding="utf-8")
    text = Path(path).read_text(encoding="utf-8")
    lines = text.splitlines(keepends=True)
    for t, start, _, end in parse(text):
        if t == tag:
            rebuilt = (
                "".join(lines[:start + 1])
                + (new_body if new_body.endswith("\n") else new_body + "\n")
                + "".join(lines[end:])
            )
            Path(path).write_text(rebuilt, encoding="utf-8")
            return 0
    print(f"error: tag not found: {tag}", file=sys.stderr)
    return 2


def cmd_append(path: str, tag: str, body_src: str) -> int:
    new_body = sys.stdin.read() if body_src == "-" else Path(body_src).read_text(encoding="utf-8")
    if not new_body.endswith("\n"):
        new_body += "\n"
    block = f"\n<!-- source: {tag} -->\n{new_body}<!-- /source -->\n"
    existing = Path(path).read_text(encoding="utf-8")
    if not existing.endswith("\n"):
        existing += "\n"
    Path(path).write_text(existing + block, encoding="utf-8")
    return 0


def cmd_strip(path: str, tag: str) -> int:
    text = Path(path).read_text(encoding="utf-8")
    lines = text.splitlines(keepends=True)
    for t, start, _, end in parse(text):
        if t == tag:
            rebuilt = "".join(lines[:start]) + "".join(lines[end + 1:])
            Path(path).write_text(rebuilt, encoding="utf-8")
            return 0
    return 1


def main() -> int:
    if len(sys.argv) < 3:
        print(__doc__, file=sys.stderr)
        return 2
    sub = sys.argv[1]
    try:
        if sub == "sources":
            return cmd_sources(sys.argv[2])
        if sub == "extract":
            return cmd_extract(sys.argv[2], sys.argv[3])
        if sub == "replace":
            return cmd_replace(sys.argv[2], sys.argv[3], sys.argv[4])
        if sub == "append":
            return cmd_append(sys.argv[2], sys.argv[3], sys.argv[4] if len(sys.argv) > 4 else "-")
        if sub == "strip":
            return cmd_strip(sys.argv[2], sys.argv[3])
    except (IndexError, ValueError, FileNotFoundError, OSError, KeyError) as e:
        print(f"error: {e}", file=sys.stderr)
        return 2
    print(f"unknown subcommand: {sub}", file=sys.stderr)
    return 2


if __name__ == "__main__":
    sys.exit(main())
