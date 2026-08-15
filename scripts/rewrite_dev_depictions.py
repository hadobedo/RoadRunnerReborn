#!/usr/bin/env python3
"""Point the dev feed's package index at the dev-scoped depiction files.

The deb control carries the stable depiction URLs. Dev publishes rewrite
them (for our package only) to the dev subdirectory so dev users see the
dev changelog while the stable depiction is never overwritten.
"""

import sys
from pathlib import Path

STABLE_PREFIX = "https://hadobedo.github.io/repo/depictions/"
DEV_PREFIX = "https://hadobedo.github.io/repo/dev/depictions/"


def main() -> None:
    if len(sys.argv) != 3:
        raise SystemExit(f"usage: {sys.argv[0]} <package> <Packages file>")
    package, packages_path = sys.argv[1], Path(sys.argv[2])
    blocks = packages_path.read_text(encoding="utf-8").split("\n\n")
    rewritten = []
    for block in blocks:
        if block.startswith("Package: " + package + "\n"):
            block = block.replace(STABLE_PREFIX, DEV_PREFIX)
        rewritten.append(block)
    packages_path.write_text("\n\n".join(rewritten), encoding="utf-8")


if __name__ == "__main__":
    main()
