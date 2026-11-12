from __future__ import annotations

import os
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
ADDON_SRC = ROOT / "addon" / "WoWSmartTSM"
DATATAP_SRC = ROOT / "addon" / "!SmartTSM_DataTap"
DIAG = ROOT / "diagnostics"
DIAG_LOCAL = DIAG / "local"
DEFAULT_WOW = Path(r"E:\WoW\World of Warcraft\_forever_")


def wow_root() -> Path:
    env = os.environ.get("WOW_FOREVER_ROOT")
    if env:
        return Path(env)
    if DEFAULT_WOW.exists():
        return DEFAULT_WOW
    # heuristic
    candidates = [
        Path(r"E:\WoW\World of Warcraft\_forever_"),
        Path(r"C:\Program Files (x86)\World of Warcraft\_forever_"),
        Path(r"D:\World of Warcraft\_forever_"),
    ]
    for c in candidates:
        if c.exists():
            return c
    return DEFAULT_WOW


def addon_install_dir() -> Path:
    return wow_root() / "Interface" / "AddOns" / "WoWSmartTSM"


def datatap_install_dir() -> Path:
    return wow_root() / "Interface" / "AddOns" / "!SmartTSM_DataTap"


def tsm_dir() -> Path:
    return wow_root() / "Interface" / "AddOns" / "TradeSkillMaster"


def saved_vars_glob() -> list[Path]:
    wtf = wow_root() / "WTF" / "Account"
    if not wtf.exists():
        return []
    found = []
    for p in wtf.rglob("WoWSmartTSM*.lua"):
        found.append(p)
    return found
