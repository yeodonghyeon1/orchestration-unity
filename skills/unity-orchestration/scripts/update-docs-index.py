#!/usr/bin/env python3
"""Walk a docs/ tree, parse .md frontmatter, and update _meta/index.json.

Usage: update-docs-index.py <docs-dir>

Reads frontmatter from every .md file recursively. Builds a nested `tree`
keyed by path-ID components, plus `by_tag`, `by_owner`, `dangling_references`,
and `orphans` aggregates. Populates `referenced_by` back-links from each
doc's `depends_on`.

Intentionally a tiny YAML parser: we only support flat key: value pairs
and simple inline lists (`[a, b, c]`) for `depends_on` and `tags`. No
anchors, no multi-line, no nested maps. This keeps the script dependency-
free on stock Python.
"""
from __future__ import annotations

import json
import os
import re
import sys
from datetime import datetime, timezone


REQUIRED_FIELDS = ("id", "title", "owner", "status", "updated", "version")


def parse_frontmatter(text: str):
    """Return the frontmatter dict or None if the file has none."""
    if not text.startswith("---"):
        return None
    end = text.find("\n---", 3)
    if end == -1:
        return None
    block = text[3:end].strip("\n")
    data = {}
    for raw in block.splitlines():
        line = raw.rstrip()
        if not line or line.startswith("#"):
            continue
        m = re.match(r"^([A-Za-z_][\w-]*)\s*:\s*(.*)$", line)
        if not m:
            continue
        key, val = m.group(1), m.group(2).strip()
        if val == "":
            data[key] = ""
            continue
        if val.startswith("[") and val.endswith("]"):
            inner = val[1:-1].strip()
            if not inner:
                data[key] = []
            else:
                items = [x.strip().strip("'\"") for x in inner.split(",")]
                data[key] = [x for x in items if x]
            continue
        if val in ("true", "false"):
            data[key] = val == "true"
            continue
        if re.match(r"^-?\d+$", val):
            data[key] = int(val)
            continue
        data[key] = val.strip("'\"")
    return data


def validate(fm, rel_path):
    missing = [f for f in REQUIRED_FIELDS if f not in fm]
    if missing:
        return [f"{rel_path}: missing frontmatter fields: {', '.join(missing)}"]
    return []


def set_in_tree(tree, parts, value):
    node = tree
    for p in parts[:-1]:
        node = node.setdefault(p, {})
    node[parts[-1]] = value


def _set_ref(tree, target_id, src_id):
    parts = target_id.split(".")
    node = tree
    for p in parts:
        if not isinstance(node, dict) or p not in node:
            return
        node = node[p]
    if isinstance(node, dict) and "referenced_by" in node:
        if src_id not in node["referenced_by"]:
            node["referenced_by"].append(src_id)


def main():
    if len(sys.argv) != 2:
        print("usage: update-docs-index.py <docs-dir>", file=sys.stderr)
        return 2

    docs_dir = os.path.abspath(sys.argv[1])
    if not os.path.isdir(docs_dir):
        print(f"error: not a directory: {docs_dir}", file=sys.stderr)
        return 2

    index_path = os.path.join(docs_dir, "_meta", "index.json")
    prior = {}
    if os.path.isfile(index_path):
        try:
            with open(index_path, encoding="utf-8") as f:
                prior = json.load(f)
        except Exception:
            prior = {}

    tree = {}
    by_tag = {}
    by_owner = {}
    all_ids = set()
    dep_map = {}
    errors = []

    for root, _, files in os.walk(docs_dir):
        for name in files:
            if not name.endswith(".md"):
                continue
            full = os.path.join(root, name)
            rel = os.path.relpath(full, docs_dir).replace("\\", "/")
            try:
                with open(full, encoding="utf-8") as f:
                    text = f.read()
            except Exception as e:
                errors.append(f"{rel}: read error: {e}")
                continue
            fm = parse_frontmatter(text)
            if fm is None:
                errors.append(f"{rel}: no frontmatter")
                continue
            errors.extend(validate(fm, rel))
            if "id" not in fm:
                continue

            entry = {
                "id": fm["id"],
                "title": fm.get("title", ""),
                "owner": fm.get("owner", ""),
                "status": fm.get("status", ""),
                "updated": fm.get("updated", ""),
                "tags": fm.get("tags", []) or [],
                "depends_on": fm.get("depends_on", []) or [],
                "referenced_by": [],
            }
            all_ids.add(fm["id"])
            dep_map[fm["id"]] = entry["depends_on"]
            parts = fm["id"].split(".")
            set_in_tree(tree, parts, entry)

            for t in entry["tags"]:
                by_tag.setdefault(t, []).append(fm["id"])
            if entry["owner"]:
                by_owner.setdefault(entry["owner"], []).append(fm["id"])

    # Populate referenced_by and detect danglers / orphans
    dangling = []
    referenced = set()
    for src_id, deps in dep_map.items():
        for dep in deps:
            if dep in all_ids:
                _set_ref(tree, dep, src_id)
                referenced.add(dep)
            else:
                dangling.append(dep)
    orphans = sorted(all_ids - referenced - {"root"})

    out = {
        "version": 1,
        "generated_at": datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ"),
        "generator": "scripts/update-docs-index.py",
        "project": prior.get("project", {"name": "", "engine": "", "genre": ""}),
        "tree": tree,
        "by_tag": {k: sorted(v) for k, v in sorted(by_tag.items())},
        "by_owner": {k: sorted(v) for k, v in sorted(by_owner.items())},
        "dangling_references": sorted(set(dangling)),
        "orphans": orphans,
    }

    os.makedirs(os.path.dirname(index_path), exist_ok=True)
    with open(index_path, "w", encoding="utf-8") as f:
        json.dump(out, f, indent=2, ensure_ascii=False)
        f.write("\n")

    for e in errors:
        print(f"warn: {e}", file=sys.stderr)
    return 0


if __name__ == "__main__":
    sys.exit(main())
