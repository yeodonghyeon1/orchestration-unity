#!/usr/bin/env python3
"""code-to-docs.py — extract C# public surface into markdown.

Intentionally a LINE-LEVEL regex scanner, not a full parser. Handles
the 80% case of Unity C# game code: classes, structs, enums, public
methods, public properties, serialized fields. Private members are
excluded. Generics and nested types are best-effort.

Usage:
    python3 scripts/code-to-docs.py <file.cs>                  — markdown output
    python3 scripts/code-to-docs.py --frontmatter <file.cs>    — YAML code_references snippet
"""

import re
import sys
from pathlib import Path

CLASS_RE = re.compile(
    r"^\s*(public\s+)?(static\s+|sealed\s+|abstract\s+|partial\s+)*"
    r"(class|struct|enum|interface)\s+(\w+)"
)
METHOD_RE = re.compile(
    r"^\s*public\s+(static\s+|virtual\s+|override\s+|async\s+)*"
    r"[\w<>,\[\]\s]+?\s+(\w+)\s*\([^;{]*\)\s*[{=]"
)
PROPERTY_RE = re.compile(
    r"^\s*public\s+[\w<>,\[\]\s]+\s+(\w+)\s*\{[^}]*get"
)
EXPR_BODY_PROP_RE = re.compile(
    r"^\s*public\s+[\w<>,\[\]\s]+\s+(\w+)\s*=>"
)
SERIALIZED_FIELD_RE = re.compile(
    r"\[SerializeField\][^;]*?(\w+)\s*;"
)


def extract(source: str):
    classes = []
    current = None

    for raw in source.splitlines():
        line = raw.rstrip()

        mclass = CLASS_RE.match(line)
        if mclass:
            modifiers = (mclass.group(1) or "") + (mclass.group(2) or "")
            kind = mclass.group(3)
            name = mclass.group(4)
            current = {
                "name": name,
                "kind": kind,
                "modifiers": modifiers.strip(),
                "methods": [],
                "properties": [],
                "fields": [],
            }
            classes.append(current)
            continue

        if current is None:
            continue

        mm = METHOD_RE.match(line)
        if mm:
            current["methods"].append(mm.group(2))
            continue

        mp = PROPERTY_RE.match(line) or EXPR_BODY_PROP_RE.match(line)
        if mp:
            current["properties"].append(mp.group(1))
            continue

        msf = SERIALIZED_FIELD_RE.search(line)
        if msf:
            current["fields"].append(msf.group(1))

    return classes


def render_markdown(path: str, classes: list) -> str:
    lines = [f"## {path}", ""]
    for c in classes:
        modifier_str = c["modifiers"] or "public"
        header = f"### `{modifier_str} {c['kind']} {c['name']}`"
        lines.append(header)
        if c["properties"]:
            lines.append("")
            lines.append("**Properties:**")
            for p in c["properties"]:
                lines.append(f"- `{p}`")
        if c["methods"]:
            lines.append("")
            lines.append("**Public methods:**")
            for m in c["methods"]:
                lines.append(f"- `{m}(...)`")
        if c["fields"]:
            lines.append("")
            lines.append("**Serialized fields:**")
            for f in c["fields"]:
                lines.append(f"- `{f}`")
        lines.append("")
    return "\n".join(lines)


def render_frontmatter(path: str, classes: list) -> str:
    out = []
    for c in classes:
        kind_str = "class" if c["kind"] == "class" else c["kind"]
        if "static" in c["modifiers"]:
            kind_str = "static-utility"
        out.append(f"- path: {path}")
        out.append(f"  kind: {kind_str}")
        out.append(f"  symbol: {c['name']}")
    return "\n".join(out)


def main() -> int:
    args = sys.argv[1:]
    frontmatter_mode = False
    if args and args[0] == "--frontmatter":
        frontmatter_mode = True
        args = args[1:]
    if not args:
        print("usage: code-to-docs.py [--frontmatter] <file.cs>", file=sys.stderr)
        return 2
    try:
        source = Path(args[0]).read_text(encoding="utf-8")
    except (OSError, FileNotFoundError) as e:
        print(f"error: {e}", file=sys.stderr)
        return 2
    classes = extract(source)
    if frontmatter_mode:
        print(render_frontmatter(args[0], classes))
    else:
        print(render_markdown(args[0], classes))
    return 0


if __name__ == "__main__":
    sys.exit(main())
