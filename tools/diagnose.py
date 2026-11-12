#!/usr/bin/env python3
from __future__ import annotations

import json
import re
import sys
from datetime import datetime, timezone
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from paths import DIAG, DIAG_LOCAL, saved_vars_glob, wow_root
from smart_logic import fingerprint
import doctor


def parse_lua_diag(path: Path) -> list[dict]:
    """Best-effort extract of severity/code/message from SavedVariables dump."""
    text = path.read_text(encoding="utf-8", errors="replace")
    entries = []
    # Very loose: look for ["severity"] = "ERROR" blocks — optional
    for m in re.finditer(r'\["code"\]\s*=\s*"([^"]+)".{0,200}\["message"\]\s*=\s*"([^"]*)"', text, re.S):
        entries.append({"code": m.group(1), "message": m.group(2), "module": "sv", "func": "import"})
    return entries


def main():
    doctor.main()
    DIAG.mkdir(parents=True, exist_ok=True)
    DIAG_LOCAL.mkdir(parents=True, exist_ok=True)

    errors_path = DIAG / "errors.json"
    history_path = DIAG / "error-history.json"
    queue_path = DIAG / "repair-queue.json"

    history = {"fingerprints": {}, "updatedAt": None}
    if history_path.exists():
        history = json.loads(history_path.read_text(encoding="utf-8"))

    new_errors = []
    for sv in saved_vars_glob():
        # Copy to local ignored area (may contain character context)
        target = DIAG_LOCAL / sv.name
        target.write_bytes(sv.read_bytes())
        for e in parse_lua_diag(sv):
            fp = fingerprint(e.get("code"), e.get("module"), e.get("func"), e.get("message", ""))
            e["fingerprint"] = fp
            e["source"] = str(sv)
            prev = history["fingerprints"].get(fp)
            if not prev:
                e["state"] = "new"
                new_errors.append(e)
                history["fingerprints"][fp] = {"firstSeen": datetime.now(timezone.utc).isoformat(), "count": 1, "status": "open"}
            else:
                prev["count"] = prev.get("count", 1) + 1
                if prev.get("status") == "fixed":
                    e["state"] = "regressed"
                    prev["status"] = "open"
                    new_errors.append(e)
                else:
                    e["state"] = "known"

    history["updatedAt"] = datetime.now(timezone.utc).isoformat()
    history_path.write_text(json.dumps(history, indent=2), encoding="utf-8")
    errors_path.write_text(json.dumps({"errors": new_errors, "note": "Personal SV copies live under diagnostics/local/"}, indent=2), encoding="utf-8")

    queue = {"items": [], "updatedAt": history["updatedAt"]}
    if queue_path.exists():
        queue = json.loads(queue_path.read_text(encoding="utf-8"))
    known = {i.get("fingerprint") for i in queue.get("items", [])}
    for e in new_errors:
        if e["fingerprint"] not in known:
            queue.setdefault("items", []).append(
                {
                    "fingerprint": e["fingerprint"],
                    "code": e.get("code"),
                    "message": e.get("message"),
                    "attempts": 0,
                    "maxAttempts": 3,
                    "status": "queued",
                }
            )
    queue["updatedAt"] = history["updatedAt"]
    queue_path.write_text(json.dumps(queue, indent=2), encoding="utf-8")

    print(f"Diagnose complete. New/regressed={len(new_errors)} wow={wow_root()}")
    print("NOTE: If WoW crashed before SV flush, errors may be missing.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
