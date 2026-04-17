#!/usr/bin/env python3
"""docs-index.py — build _meta/index.json for a develop_docs/ tree.

Usage:
    python3 scripts/docs-index.py <develop_docs_root>

Outputs:
    <root>/_meta/index.json with schema_version=2, tree, reverse_index.

Fixes v0.2.0 _self bug: parent entries with children now store their
own fields under a _self key rather than mingling with child keys.
"""

import json
import os
import re
import sys
from pathlib import Path

FM_RE = re.compile(r"^---\s*$(.*?)^---\s*$", re.MULTILINE | re.DOTALL)


def parse_frontmatter(text: str) -> dict:
    """Minimal YAML-ish frontmatter parser for our fixed schema."""
    m = FM_RE.search(text)
    if not m:
        return {}
    fm = {}
    current_key = None
    list_buffer = []
    for raw in m.group(1).splitlines():
        line = raw.rstrip()
        if not line or line.startswith("#"):
            continue
        if line.startswith("  - "):
            item = line[4:].strip()
            list_buffer.append(item)
            continue
        if list_buffer and current_key:
            fm[current_key] = list_buffer
            list_buffer = []
            current_key = None
        if ":" in line:
            key, _, val = line.partition(":")
            key = key.strip()
            val = val.strip()
            if val == "":
                current_key = key
                list_buffer = []
            else:
                fm[key] = val.strip('"')
                current_key = None
    if list_buffer and current_key:
        fm[current_key] = list_buffer
    return fm


def collect_files(root: Path):
    """Yield (rel_path, frontmatter_dict) for each .md under root (excluding _meta/)."""
    for p in root.rglob("*.md"):
        if "_meta" in p.parts:
            continue
        fm = parse_frontmatter(p.read_text(encoding="utf-8"))
        if "id" in fm:
            rel = p.relative_to(root).as_posix()
            yield rel, fm


def build_tree(entries):
    """Build nested tree with _self for parents, children list."""
    tree = {}
    for rel, fm in entries:
        node_id = fm["id"]
        tree[node_id] = {
            "_self": {
                "path": rel,
                "title": fm.get("title", ""),
                "status": fm.get("status", "draft"),
            },
            "children": [],
        }
    ids = sorted(tree.keys(), key=lambda x: x.count("."))
    for node_id in ids:
        parent = ".".join(node_id.split(".")[:-1])
        if parent in tree and parent != node_id:
            tree[parent]["children"].append(node_id)
    return tree


def build_reverse_index(entries):
    """notion id → [develop_docs id, ...]"""
    rev = {}
    for _, fm in entries:
        dev_id = fm["id"]
        for notion_ref in fm.get("source_notion_docs", []):
            notion_key = notion_ref.split("#")[0]
            rev.setdefault(notion_key, []).append(dev_id)
    return rev


def main() -> int:
    if len(sys.argv) != 2:
        print("usage: docs-index.py <develop_docs_root>", file=sys.stderr)
        return 2
    root = Path(sys.argv[1])
    if not root.is_dir():
        print(f"error: {root} is not a directory", file=sys.stderr)
        return 2
    try:
        entries = list(collect_files(root))
        index = {
            "schema_version": 2,
            "tree": build_tree(entries),
            "reverse_index": build_reverse_index(entries),
        }
        meta = root / "_meta"
        meta.mkdir(parents=True, exist_ok=True)
        out = meta / "index.json"
        tmp = out.with_suffix(".json.tmp")
        tmp.write_text(json.dumps(index, indent=2, ensure_ascii=False), encoding="utf-8")
        os.replace(tmp, out)
        print(f"wrote {out}")
        return 0
    except (OSError, ValueError, KeyError) as e:
        print(f"error: {e}", file=sys.stderr)
        return 2


if __name__ == "__main__":
    sys.exit(main())
