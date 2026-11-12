#!/usr/bin/env python3
from __future__ import annotations

import argparse
import json
import shutil
import subprocess
import sys
from datetime import datetime, timezone
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from paths import ROOT, ADDON_SRC, addon_install_dir, wow_root, tsm_dir
import doctor


def is_wow_running() -> bool:
    try:
        out = subprocess.check_output(["tasklist"], text=True, stderr=subprocess.STDOUT)
        return "Wow.exe" in out
    except Exception:
        return False


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--dev", action="store_true", help="Copy addon into Forever AddOns (dev install)")
    ap.add_argument("--uninstall", action="store_true")
    ap.add_argument("--force", action="store_true")
    args = ap.parse_args()

    dest = addon_install_dir()
    backups = ROOT / "backups"
    backups.mkdir(exist_ok=True)
    running = is_wow_running()
    stamp = datetime.now(timezone.utc).strftime("%Y%m%dT%H%M%SZ")

    state = {
        "at": stamp,
        "wowRoot": str(wow_root()),
        "dest": str(dest),
        "wowRunning": running,
        "tsmPresent": tsm_dir().exists(),
    }
    (backups / f"install-state-{stamp}.json").write_text(json.dumps(state, indent=2), encoding="utf-8")

    if args.uninstall:
        if dest.exists():
            archive = backups / f"WoWSmartTSM-uninstall-{stamp}"
            shutil.copytree(dest, archive)
            shutil.rmtree(dest)
            print(f"Uninstalled. Backup at {archive}")
            print("Original TSM untouched.")
        else:
            print("Not installed.")
        return 0

    if not args.dev:
        print("Use --dev for development install or package+manual extract.")
        return 1

    if not ADDON_SRC.exists():
        print("Addon source missing")
        return 1
    if not wow_root().exists():
        print("WoW Forever root not found:", wow_root())
        return 1

    dest.parent.mkdir(parents=True, exist_ok=True)
    if dest.exists():
        archive = backups / f"WoWSmartTSM-preinstall-{stamp}"
        shutil.copytree(dest, archive)
        shutil.rmtree(dest)
        print("Backed up previous install to", archive)

    shutil.copytree(ADDON_SRC, dest)
    print("Installed to", dest)
    if running:
        print("WARNING: WoW is running. Files copied, but addon is NOT active until /reload or restart.")
        print("Doctor will NOT claim successful activation while WoW is running.")
    else:
        print("WoW not running. Enable addon in character select / addon list, then login.")

    # Never touch TradeSkillMaster files
    doctor.main()
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
