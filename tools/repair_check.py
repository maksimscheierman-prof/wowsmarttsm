#!/usr/bin/env python3
"""Inspect repair queue. Does NOT auto-invoke Cursor agents (disabled by default)."""
from __future__ import annotations

import json
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from paths import DIAG, ROOT

CONFIG = ROOT / "tools" / "repair_runner.local.json"


def main():
    queue_path = DIAG / "repair-queue.json"
    if not queue_path.exists():
        print("No repair queue. Run diagnose first.")
        return 0
    queue = json.loads(queue_path.read_text(encoding="utf-8"))
    enabled = False
    if CONFIG.exists():
        cfg = json.loads(CONFIG.read_text(encoding="utf-8"))
        enabled = bool(cfg.get("enabled"))
    print(f"Cursor repair runner enabled={enabled} (default false)")
    print("No invented Cursor API. Manual: open Cursor chat and paste fingerprint + repro.")
    for item in queue.get("items", []):
        status = item.get("status")
        attempts = item.get("attempts", 0)
        max_a = item.get("maxAttempts", 3)
        stop = attempts >= max_a
        print(f"- {item.get('fingerprint')[:80]} status={status} attempts={attempts}/{max_a} stop={stop}")
        if stop and status != "fixed":
            item["status"] = "gave_up"
    queue_path.write_text(json.dumps(queue, indent=2), encoding="utf-8")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
