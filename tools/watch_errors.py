#!/usr/bin/env python3
"""Watchdog: poll SavedVariables mtimes and diagnose on change. Default interval 60s."""
from __future__ import annotations

import argparse
import json
import sys
import time
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from paths import DIAG, saved_vars_glob
import diagnose


def snapshot():
    data = {}
    for p in saved_vars_glob():
        try:
            data[str(p)] = p.stat().st_mtime
        except OSError:
            pass
    # also WoWSmartTSM if present after install usage
    return data


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--interval", type=int, default=60)
    ap.add_argument("--once", action="store_true")
    args = ap.parse_args()
    DIAG.mkdir(parents=True, exist_ok=True)
    last = snapshot()
    print(f"Watching {len(last)} SV files; interval={args.interval}s")
    diagnose.main()
    if args.once:
        return 0
    while True:
        time.sleep(max(5, args.interval))
        cur = snapshot()
        if cur != last:
            print("Change detected — diagnosing")
            diagnose.main()
            last = cur
        else:
            # no full re-analysis
            pass


if __name__ == "__main__":
    raise SystemExit(main())
