#!/usr/bin/env python3
from __future__ import annotations

import json
import subprocess
import sys
from datetime import datetime, timezone
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from paths import ROOT, ADDON_SRC, wow_root, tsm_dir, addon_install_dir, DIAG
from lua_syntax import check_tree


def git_status():
    try:
        out = subprocess.check_output(["git", "status", "-sb"], cwd=ROOT, text=True, stderr=subprocess.STDOUT)
        return {"ok": True, "status": out.strip()}
    except Exception as e:
        return {"ok": False, "error": str(e)}


def wow_running():
    try:
        import psutil  # optional
    except Exception:
        # fallback tasklist
        try:
            out = subprocess.check_output(["tasklist"], text=True, stderr=subprocess.STDOUT)
            return "Wow.exe" in out
        except Exception:
            return None
    return any(p.name().lower() == "wow.exe" for p in psutil.process_iter(attrs=["name"]))


def main():
    DIAG.mkdir(parents=True, exist_ok=True)
    issues = []
    report = {
        "generatedAt": datetime.now(timezone.utc).isoformat(),
        "projectRoot": str(ROOT),
        "wowRoot": str(wow_root()),
        "wowExists": wow_root().exists(),
        "tsmExists": tsm_dir().exists(),
        "addonSrcExists": ADDON_SRC.exists(),
        "addonInstalled": addon_install_dir().exists(),
        "wowRunning": wow_running(),
        "git": git_status(),
        "luaSyntax": None,
        "issues": issues,
    }

    if not wow_root().exists():
        issues.append({"severity": "ERROR", "code": "WOW_ROOT_MISSING", "msg": str(wow_root())})
    if not tsm_dir().exists():
        issues.append({"severity": "ERROR", "code": "TSM_MISSING", "msg": "TradeSkillMaster not found"})
    else:
        toc = tsm_dir() / "TradeSkillMaster.toc"
        if toc.exists():
            text = toc.read_text(encoding="utf-8", errors="replace")
            for line in text.splitlines():
                if line.startswith("## Version:"):
                    report["tsmVersion"] = line.split(":", 1)[1].strip()
    if not ADDON_SRC.exists():
        issues.append({"severity": "CRITICAL", "code": "ADDON_SRC_MISSING", "msg": str(ADDON_SRC)})
    else:
        syn = check_tree(ADDON_SRC)
        report["luaSyntax"] = {"checked": syn["checked"], "failedCount": len(syn["failed"])}
        if syn["failed"]:
            issues.append({"severity": "ERROR", "code": "LUA_SYNTAX", "msg": syn["failed"]})

    if report["wowRunning"]:
        issues.append(
            {
                "severity": "WARNING",
                "code": "WOW_RUNNING",
                "msg": "WoW is running — SavedVariables may be stale; install activation needs /reload",
            }
        )

    status = "healthy"
    if any(i["severity"] == "CRITICAL" for i in issues):
        status = "critical"
    elif any(i["severity"] == "ERROR" for i in issues):
        status = "degraded"
    elif issues:
        status = "warning"

    health = {
        "status": status,
        "issues": issues,
        "updatedAt": report["generatedAt"],
        "tsmVersion": report.get("tsmVersion"),
        "addonInstalled": report["addonInstalled"],
        "wowRunning": report["wowRunning"],
    }
    (DIAG / "health-status.json").write_text(json.dumps(health, indent=2), encoding="utf-8")
    issue_lines = [f"- [{i['severity']}] {i['code']}: {i['msg']}" for i in issues]
    if not issue_lines:
        issue_lines = ["- none"]
    md_lines = [
        f"# Doctor report — {report['generatedAt']}",
        "",
        f"- Status: **{status}**",
        f"- WoW root: `{report['wowRoot']}` exists={report['wowExists']}",
        f"- TSM: exists={report['tsmExists']} version={report.get('tsmVersion')}",
        f"- Addon src: {report['addonSrcExists']}",
        f"- Addon installed: {report['addonInstalled']}",
        f"- WoW running: {report['wowRunning']}",
        f"- Git: {report['git']}",
        f"- Lua syntax failed: {report['luaSyntax']}",
        "",
        "## Issues",
        *issue_lines,
        "",
        "> Offline doctor only. In-game smoke test remains OWNER/OPEN until executed.",
    ]
    (DIAG / "latest-report.md").write_text("\n".join(md_lines), encoding="utf-8")
    print(json.dumps(health, indent=2))
    return 0 if status in ("healthy", "warning") else 1


if __name__ == "__main__":
    raise SystemExit(main())
