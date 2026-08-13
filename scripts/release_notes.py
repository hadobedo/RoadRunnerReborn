#!/usr/bin/env python3
"""Parse and validate the tracked release notes used by release automation."""

from __future__ import annotations

import argparse
import re
from pathlib import Path

_VERSION = re.compile(r"^##\s+(?:What's new in\s+)?(\S+)\s*$")
_BULLET = re.compile(r"^-\s+(.+\S)\s*$")


def parse(path: Path) -> tuple[str, list[str]]:
    version = None
    bullets: list[str] = []
    for line in path.read_text(encoding="utf-8").splitlines():
        stripped = line.strip()
        match = _VERSION.match(stripped)
        if match and version is None:
            version = match.group(1)
            continue
        if version is not None:
            if stripped.startswith("## "):
                break
            bullet = _BULLET.match(stripped)
            if bullet:
                bullets.append(bullet.group(1))
    if not version or not bullets:
        raise ValueError(f"{path} must contain a version heading and changelog bullets")
    return version, bullets


def validate(path: Path, expected: str | None = None) -> tuple[str, list[str]]:
    version, bullets = parse(path)
    if expected and version != expected:
        raise ValueError(f"{path} declares {version}, expected {expected}")
    return version, bullets


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("path", type=Path)
    parser.add_argument("--expected-version")
    args = parser.parse_args()
    version, bullets = validate(args.path, args.expected_version)
    print(f"{version}: {len(bullets)} release notes")


if __name__ == "__main__":
    main()
