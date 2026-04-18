#!/usr/bin/env python3
"""Deprecated — forwards to scripts/docs-index.py.

Kept for backward compat with v0.2.0 tests/scripts. New code should
call docs-index.py directly.
"""

import os
import subprocess
import sys


def main() -> int:
    here = os.path.dirname(os.path.abspath(__file__))
    target = os.path.join(here, "docs-index.py")
    return subprocess.call([sys.executable, target, *sys.argv[1:]])


if __name__ == "__main__":
    sys.exit(main())
