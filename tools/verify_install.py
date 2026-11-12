#!/usr/bin/env python3
from __future__ import annotations

import hashlib
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from paths import ADDON_SRC, addon_install_dir, tsm_dir


def file_set(root: Path) -> dict[str, str]:
    out = {}
    for f in root.rglob("*"):
        if f.is_file():
            rel = f.relative_to(root).as_posix()
            h = hashlib.sha256(f.read_bytes()).hexdigest()
            out[rel] = h
    return out


def main():
    dest = addon_install_dir()
    if not dest.exists():
        print("FAIL: not installed at", dest)
        return 1
    src = file_set(ADDON_SRC)
    dst = file_set(dest)
    missing = [k for k in src if k not in dst]
    differ = [k for k in src if k in dst and src[k] != dst[k]]
    extra = [k for k in dst if k not in src]
    print(f"src={len(src)} dest={len(dst)} missing={len(missing)} differ={len(differ)} extra={len(extra)}")
    if missing or differ:
        print("FAIL content mismatch", missing[:5], differ[:5])
        return 1
    # Ensure TSM still present and untouched by us (existence only)
    if not tsm_dir().exists():
        print("WARNING: TSM missing")
    print("PASS install matches source")
    print("NOTE: In-game load verification is separate / OPEN until smoke-tested.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
