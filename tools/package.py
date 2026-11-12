#!/usr/bin/env python3
from __future__ import annotations

import json
import zipfile
from datetime import datetime, timezone
from pathlib import Path
import sys

sys.path.insert(0, str(Path(__file__).resolve().parent))
from paths import ROOT, ADDON_SRC, DATATAP_SRC
from lua_syntax import check_tree


def add_tree(z: zipfile.ZipFile, src: Path, arc_root: str) -> int:
    n = 0
    for f in src.rglob("*"):
        if f.is_file():
            arc = Path(arc_root) / f.relative_to(src)
            z.write(f, arc.as_posix())
            n += 1
    return n


def main():
    syn = check_tree(ADDON_SRC)
    syn2 = check_tree(DATATAP_SRC)
    failed = syn["failed"] + syn2["failed"]
    if failed:
        print("Refusing to package: Lua syntax issues", failed)
        return 1
    dist = ROOT / "dist"
    dist.mkdir(exist_ok=True)
    version = "0.1.1"
    toc = (ADDON_SRC / "WoWSmartTSM.toc").read_text(encoding="utf-8")
    for line in toc.splitlines():
        if line.startswith("## Version:"):
            version = line.split(":", 1)[1].strip()
    name = f"WoWSmartTSM-{version}.zip"
    out = dist / name
    if out.exists():
        out.unlink()
    with zipfile.ZipFile(out, "w", zipfile.ZIP_DEFLATED) as z:
        n1 = add_tree(z, ADDON_SRC, "WoWSmartTSM")
        n2 = add_tree(z, DATATAP_SRC, "!SmartTSM_DataTap")
    meta = {
        "file": str(out),
        "version": version,
        "createdAt": datetime.now(timezone.utc).isoformat(),
        "luaChecked": syn["checked"] + syn2["checked"],
        "files": n1 + n2,
    }
    (dist / "latest.json").write_text(json.dumps(meta, indent=2), encoding="utf-8")
    print(json.dumps(meta, indent=2))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
