#!/usr/bin/env python3
"""Verify the Mach-O slices shipped in a package."""

from __future__ import annotations

import argparse
import struct
from pathlib import Path

CPU_TYPE_ARM64 = 0x0100000C
CPU_SUBTYPE_ARM64 = 0x00000000
CPU_SUBTYPE_ARM64E_PAC00 = 0x80000002
FAT_MAGIC = b"\xca\xfe\xba\xbe"
FAT_MAGIC_64 = b"\xca\xfe\xba\xbf"
THIN_MAGIC_32_LE = b"\xce\xfa\xed\xfe"
THIN_MAGIC_32_BE = b"\xfe\xed\xfa\xce"
THIN_MAGIC_64_LE = b"\xcf\xfa\xed\xfe"
THIN_MAGIC_64_BE = b"\xfe\xed\xfa\xcf"


def _thin_header(data: bytes, offset: int = 0) -> tuple[int, int]:
    magic = data[offset : offset + 4]
    if magic in (THIN_MAGIC_32_LE, THIN_MAGIC_64_LE):
        endian = "<"
    elif magic in (THIN_MAGIC_32_BE, THIN_MAGIC_64_BE):
        endian = ">"
    else:
        raise ValueError(f"unsupported Mach-O magic {magic!r}")
    cputype, cpusubtype = struct.unpack_from(f"{endian}II", data, offset + 4)
    return cputype, cpusubtype


def _slices(data: bytes) -> list[tuple[int, int]]:
    magic = data[:4]
    if magic not in (FAT_MAGIC, FAT_MAGIC_64):
        return [_thin_header(data)]

    _, count = struct.unpack_from(">II", data, 0)
    slices: list[tuple[int, int]] = []
    cursor = 8
    for _ in range(count):
        if magic == FAT_MAGIC:
            cputype, cpusubtype, offset, size, _align = struct.unpack_from(
                ">IIIII", data, cursor
            )
            cursor += 20
        else:
            cputype, cpusubtype, offset, size, _align, _reserved = struct.unpack_from(
                ">IIQQII", data, cursor
            )
            cursor += 32
        if offset + size > len(data):
            raise ValueError("fat Mach-O slice extends past end of file")
        header_cpu, header_subtype = _thin_header(data, offset)
        if (header_cpu, header_subtype) != (cputype, cpusubtype):
            raise ValueError("fat header does not match its Mach-O slice header")
        slices.append((cputype, cpusubtype))
    return slices


def verify(path: Path) -> None:
    slices = _slices(path.read_bytes())
    expected = {
        (CPU_TYPE_ARM64, CPU_SUBTYPE_ARM64),
        (CPU_TYPE_ARM64, CPU_SUBTYPE_ARM64E_PAC00),
    }
    actual = set(slices)
    if len(slices) != 2 or actual != expected:
        rendered = ", ".join(f"{cpu:#x}/{subtype:#x}" for cpu, subtype in slices)
        raise ValueError(f"{path}: expected arm64 + arm64e PAC00, got {rendered}")
    print(f"verified {path}: arm64 + arm64e PAC00")


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("paths", nargs="+", type=Path)
    args = parser.parse_args()
    for path in args.paths:
        verify(path)


if __name__ == "__main__":
    main()
