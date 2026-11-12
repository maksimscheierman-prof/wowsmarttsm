#!/usr/bin/env python3
from __future__ import annotations

import json
import shutil
import zipfile
from datetime import datetime, timezone
from pathlib import Path
import sys

sys.path.insert(0, str(Path(__file__).resolve().parent))
from paths import ROOT, ADDON_SRC
from lua_syntax import check_tree


def main():
    syn = check_tree(ADDON_SRC)
    if syn["failed"]:
        print("Refusing to package: Lua syntax issues", syn["failed"])
        return 1
    dist = ROOT / "dist"
    dist.mkdir(exist_ok=True)
    version = "0.1.0"
    toc = (ADDON_SRC / "WoWSmartTSM.toc").read_text(encoding="utf-8")
    for line in toc.splitlines():
        if line.startswith("## Version:"):
            version = line.split(":", 1)[1].strip()
    name = f"WoWSmartTSM-{version}.zip"
    out = dist / name
    if out.exists():
        out.unlink()
    with zipfile.ZipFile(out, "w", zipfile.ZIP_DEFLATED) as z:
        for f in ADDON_SRC.rglob("*"):
            if f.is_file():
                arc = Path("WoWSmartTSM") / f.relative_to(ADDON_SRC)
                z.write(f, arc.as_posix())
    meta = {
        "file": str(out),
        "version": version,
        "createdAt": datetime.now(timezone.utc).isoformat(),
        "luaChecked": syn["checked"],
    }
    (dist / "latest.json").write_text(json.dumps(meta, indent=2), encoding="utf-8")
    print(json.dumps(meta, indent=2))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
