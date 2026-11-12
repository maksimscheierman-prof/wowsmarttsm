"""Regression: Logger must not use Forever-incompatible Lua APIs."""
from pathlib import Path
import re
import sys

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "tools"))
from paths import ADDON_SRC


def _strip_lua_comments(text: str) -> str:
    text = re.sub(r"--\[\[.*?\]\]", "", text, flags=re.S)
    text = re.sub(r"--(?!\[\[).*$", "", text, flags=re.M)
    return text


def test_logger_has_no_randomseed():
    logger = (ADDON_SRC / "Diagnostics" / "Logger.lua").read_text(encoding="utf-8")
    code = _strip_lua_comments(logger)
    assert "math.randomseed" not in code
    assert "randomseed" not in code
    # Session id must use time/GetTime/seq style
    assert "newSessionId" in logger
    assert "GetTime" in logger
    assert "sessionSeq" in logger


def test_no_randomseed_anywhere_in_addon():
    offenders = []
    for path in ADDON_SRC.rglob("*.lua"):
        code = _strip_lua_comments(path.read_text(encoding="utf-8"))
        if "math.randomseed" in code or re.search(r"(?<![\w.])randomseed\s*\(", code):
            offenders.append(str(path.relative_to(ADDON_SRC)))
    assert offenders == [], offenders


def test_logger_init_has_fallback_and_status():
    logger = (ADDON_SRC / "Diagnostics" / "Logger.lua").read_text(encoding="utf-8")
    assert "function Logger.Init" in logger
    assert "initFailed" in logger
    assert "GetInitStatus" in logger
    assert "earlyErrors" in logger
    assert "fallback-" in logger or "fallback" in logger
    # Soft-fail must not raise through ADDON_LOADED uncaught
    assert "pcall" in logger


def test_prices_no_unpack_star():
    prices = _strip_lua_comments((ADDON_SRC / "TSM" / "Prices.lua").read_text(encoding="utf-8"))
    assert "unpack(SOURCES)" not in prices
    assert "table.unpack" not in prices


def test_addon_bootstrap_order_surfaces_load_errors():
    addon = (ADDON_SRC / "Core" / "Addon.lua").read_text(encoding="utf-8")
    assert "SV.Init" in addon
    assert "Logger.Init" in addon
    assert "InstallErrorHandler" in addon
    assert "recordLoadFailure" in addon or "loadError" in addon
    assert "AutoEval.Init" in addon
    # PLAYER_LOGIN catch-up for missed eval
    assert "player_login_catchup" in addon or "AutoEval.Request" in addon
