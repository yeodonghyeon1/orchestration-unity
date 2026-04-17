#!/usr/bin/env python3
"""page-map.py — manage notion_docs/_meta/page-map.json

Subcommands:
    init <path>                            — create empty map
    add <path> <page_id> <title> <folder>  — add or update mapping
    get <path> <page_id>                   — print folder for page_id
    list <path>                            — print all mappings as TSV
    slugify <text>                         — ASCII kebab-case slug
"""

import json
import re
import sys
from pathlib import Path

RESERVED_FOLDERS = {"_meta"}


def slugify(text: str) -> str:
    """ASCII kebab-case. Non-ASCII collapsed to dashes; empty result → 'page'."""
    t = text.strip().lower()
    t = re.sub(r"[^\x00-\x7f]+", "-", t)
    t = re.sub(r"[^a-z0-9]+", "-", t)
    t = t.strip("-")
    return t or "page"


def ensure_not_reserved(folder: str) -> None:
    if folder in RESERVED_FOLDERS or folder.startswith("_"):
        raise ValueError(f"folder name '{folder}' is reserved (no _ prefix)")


def cmd_init(path: str) -> int:
    data = {"schema_version": 1, "mappings": [], "auto_slugify": True}
    Path(path).parent.mkdir(parents=True, exist_ok=True)
    Path(path).write_text(json.dumps(data, indent=2, ensure_ascii=False), encoding="utf-8")
    return 0


def cmd_add(path: str, page_id: str, title: str, folder: str) -> int:
    ensure_not_reserved(folder)
    data = json.loads(Path(path).read_text(encoding="utf-8"))
    for m in data["mappings"]:
        if m["folder"] == folder and m["notion_page_id"] != page_id:
            raise ValueError(f"folder '{folder}' already mapped to a different page")
    for m in data["mappings"]:
        if m["notion_page_id"] == page_id:
            m["notion_title"] = title
            m["folder"] = folder
            break
    else:
        data["mappings"].append({
            "notion_page_id": page_id,
            "notion_title": title,
            "folder": folder,
        })
    Path(path).write_text(json.dumps(data, indent=2, ensure_ascii=False), encoding="utf-8")
    return 0


def cmd_get(path: str, page_id: str) -> int:
    data = json.loads(Path(path).read_text(encoding="utf-8"))
    for m in data["mappings"]:
        if m["notion_page_id"] == page_id:
            print(m["folder"])
            return 0
    print("", end="")
    return 1


def cmd_list(path: str) -> int:
    data = json.loads(Path(path).read_text(encoding="utf-8"))
    for m in data["mappings"]:
        print(f"{m['notion_page_id']}\t{m['notion_title']}\t{m['folder']}")
    return 0


def cmd_slugify(text: str) -> int:
    print(slugify(text))
    return 0


def main() -> int:
    if len(sys.argv) < 2:
        print(__doc__, file=sys.stderr)
        return 2
    sub = sys.argv[1]
    try:
        if sub == "init":
            return cmd_init(sys.argv[2])
        if sub == "add":
            return cmd_add(sys.argv[2], sys.argv[3], sys.argv[4], sys.argv[5])
        if sub == "get":
            return cmd_get(sys.argv[2], sys.argv[3])
        if sub == "list":
            return cmd_list(sys.argv[2])
        if sub == "slugify":
            return cmd_slugify(sys.argv[2])
    except (IndexError, ValueError, FileNotFoundError, OSError, json.JSONDecodeError) as e:
        print(f"error: {e}", file=sys.stderr)
        return 2
    print(f"unknown subcommand: {sub}", file=sys.stderr)
    return 2


if __name__ == "__main__":
    sys.exit(main())
