#!/usr/bin/env python3
"""sync-state.py — manage notion_docs/_meta/sync-state.json

Subcommands:
    init <path>
    upsert <path> <page_id> <file_path> <hash> <notion_last_edited>
    get-hash <path> <page_id>
    move-to-orphans <path> <page_id>
    list-orphans <path>
    list-pages <path>
"""

import json
import os
import sys
from pathlib import Path


def load(path: str) -> dict:
    return json.loads(Path(path).read_text(encoding="utf-8"))


def atomic_write(path: str, data: dict) -> None:
    tmp = f"{path}.tmp"
    Path(path).parent.mkdir(parents=True, exist_ok=True)
    Path(tmp).write_text(
        json.dumps(data, indent=2, ensure_ascii=False),
        encoding="utf-8",
    )
    os.replace(tmp, path)


def cmd_init(path: str) -> int:
    data = {
        "schema_version": 1,
        "last_sync": None,
        "pages": {},
        "orphans": [],
    }
    atomic_write(path, data)
    return 0


def cmd_upsert(path: str, page_id: str, file_path: str, hash_: str, edited: str) -> int:
    data = load(path)
    data["pages"][page_id] = {
        "path": file_path,
        "hash": hash_,
        "notion_last_edited": edited,
    }
    atomic_write(path, data)
    return 0


def cmd_get_hash(path: str, page_id: str) -> int:
    data = load(path)
    entry = data["pages"].get(page_id)
    if not entry:
        print(f"error: page not found: {page_id}", file=sys.stderr)
        return 1
    print(entry["hash"])
    return 0


def cmd_move_to_orphans(path: str, page_id: str) -> int:
    data = load(path)
    entry = data["pages"].pop(page_id, None)
    if entry:
        data["orphans"].append({"notion_page_id": page_id, **entry})
        atomic_write(path, data)
    return 0


def cmd_list_orphans(path: str) -> int:
    data = load(path)
    for o in data["orphans"]:
        print(o["notion_page_id"])
    return 0


def cmd_list_pages(path: str) -> int:
    data = load(path)
    for pid, entry in data["pages"].items():
        print(f"{pid}\t{entry['path']}\t{entry['hash']}")
    return 0


def main() -> int:
    if len(sys.argv) < 2:
        print(__doc__, file=sys.stderr)
        return 2
    sub = sys.argv[1]
    try:
        if sub == "init":
            return cmd_init(sys.argv[2])
        if sub == "upsert":
            return cmd_upsert(sys.argv[2], sys.argv[3], sys.argv[4], sys.argv[5], sys.argv[6])
        if sub == "get-hash":
            return cmd_get_hash(sys.argv[2], sys.argv[3])
        if sub == "move-to-orphans":
            return cmd_move_to_orphans(sys.argv[2], sys.argv[3])
        if sub == "list-orphans":
            return cmd_list_orphans(sys.argv[2])
        if sub == "list-pages":
            return cmd_list_pages(sys.argv[2])
    except (IndexError, ValueError, KeyError, FileNotFoundError, OSError, json.JSONDecodeError) as e:
        print(f"error: {e}", file=sys.stderr)
        return 2
    print(f"unknown subcommand: {sub}", file=sys.stderr)
    return 2


if __name__ == "__main__":
    sys.exit(main())
