#!/usr/bin/env python3
"""bfs-impact.py — BFS over reverse_index to find impacted develop_docs ids.

Given a list of changed notion_docs ids, traverse the reverse_index (and
optionally in future versions the refs-graph forward edges) to determine
which develop_docs files must be re-refined.

Usage:
    python3 scripts/bfs-impact.py <index.json> <id1,id2,...>

Prints affected develop_docs ids, one per line.
"""

import json
import sys
from collections import deque


def bfs(index: dict, seeds: list) -> list:
    reverse = index.get("reverse_index", {})
    visited = set()
    queue = deque()

    for seed in seeds:
        for dev_id in reverse.get(seed, []):
            if dev_id not in visited:
                visited.add(dev_id)
                queue.append(dev_id)

    # v1: direct reverse lookup only. refs-graph forward edges in v2.
    while queue:
        _ = queue.popleft()
    return sorted(visited)


def main() -> int:
    if len(sys.argv) != 3:
        print("usage: bfs-impact.py <index.json> <id1,id2,...>", file=sys.stderr)
        return 2
    try:
        index = json.loads(open(sys.argv[1], "r", encoding="utf-8").read())
    except (OSError, json.JSONDecodeError) as e:
        print(f"error: {e}", file=sys.stderr)
        return 2
    seeds = [s.strip() for s in sys.argv[2].split(",") if s.strip()]
    for impacted in bfs(index, seeds):
        print(impacted)
    return 0


if __name__ == "__main__":
    sys.exit(main())
