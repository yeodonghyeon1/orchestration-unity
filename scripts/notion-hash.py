#!/usr/bin/env python3
"""notion-hash.py — deterministic SHA256 hash of Notion page content.

Excludes volatile fields (created_time, last_edited_time, etc.) so
identical content always hashes to the same value.

Usage:
    python3 scripts/notion-hash.py < page.json
    python3 scripts/notion-hash.py page.json

Output (stdout):
    sha256:<hex>
"""

import hashlib
import json
import sys

VOLATILE_KEYS = {
    "created_time",
    "last_edited_time",
    "created_by",
    "last_edited_by",
    "request_id",
    "has_more",
    "next_cursor",
    "cursor",
}


def normalize(obj):
    """Recursively drop volatile keys and normalize string whitespace.

    String normalization rules:
      - Trailing whitespace is stripped from each line.
      - Trailing newlines are removed (splitlines() discards them).

    This means 'hello\\n' and 'hello' normalize identically — intentional
    for Notion block content where trailing newlines are structural
    (block boundaries) rather than semantic.
    """
    if isinstance(obj, dict):
        return {
            k: normalize(v)
            for k, v in obj.items()
            if k not in VOLATILE_KEYS
        }
    if isinstance(obj, list):
        return [normalize(item) for item in obj]
    if isinstance(obj, str):
        return "\n".join(line.rstrip() for line in obj.splitlines())
    return obj


def compute_hash(payload: str) -> str:
    try:
        data = json.loads(payload)
    except json.JSONDecodeError as e:
        raise ValueError(f"invalid JSON: {e}") from e
    canonical = json.dumps(
        normalize(data),
        sort_keys=True,
        ensure_ascii=False,
        separators=(",", ":"),
    )
    digest = hashlib.sha256(canonical.encode("utf-8")).hexdigest()
    return f"sha256:{digest}"


def main() -> int:
    if len(sys.argv) > 1:
        with open(sys.argv[1], "r", encoding="utf-8") as f:
            payload = f.read()
    else:
        payload = sys.stdin.read()
    if not payload.strip():
        print("error: empty input", file=sys.stderr)
        return 1
    try:
        print(compute_hash(payload))
    except ValueError as e:
        print(f"error: {e}", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
