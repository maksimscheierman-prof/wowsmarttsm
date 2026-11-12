#!/usr/bin/env python3
from __future__ import annotations

import hashlib
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from paths import ADDON_SRC, DATATAP_SRC, addon_install_dir, datatap_install_dir, tsm_dir


def file_set(root: Path) -> dict[str, str]:
    out = {}
    for f in root.rglob("*"):
        if f.is_file():
            rel = f.relative_to(root).as_posix()
            h = hashlib.sha256(f.read_bytes()).hexdigest()
            out[rel] = h
    return out


def compare(src_root: Path, dest_root: Path, label: str) -> int:
    if not dest_root.exists():
        print(f"FAIL: {label} not installed at", dest_root)
        return 1
    src = file_set(src_root)
    dst = file_set(dest_root)
    missing = [k for k in src if k not in dst]
    differ = [k for k in src if k in dst and src[k] != dst[k]]
    print(f"{label}: src={len(src)} dest={len(dst)} missing={len(missing)} differ={len(differ)}")
    if missing or differ:
        print("FAIL content mismatch", missing[:5], differ[:5])
        return 1
    return 0


def main():
    rc = 0
    rc |= compare(ADDON_SRC, addon_install_dir(), "WoWSmartTSM")
    rc |= compare(DATATAP_SRC, datatap_install_dir(), "!SmartTSM_DataTap")
    if not tsm_dir().exists():
        print("WARNING: TSM missing")
    if rc == 0:
        print("PASS install matches source")
        print("NOTE: In-game load verification is separate / OPEN until smoke-tested.")
    return rc


if __name__ == "__main__":
    raise SystemExit(main())
