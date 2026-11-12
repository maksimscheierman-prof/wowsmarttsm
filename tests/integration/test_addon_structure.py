from pathlib import Path
import sys

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "tools"))
from lua_syntax import check_tree
from paths import ADDON_SRC, DATATAP_SRC


REQUIRED = [
    "WoWSmartTSM.toc",
    "Core/Addon.lua",
    "Core/AutoEval.lua",
    "Diagnostics/Logger.lua",
    "Rules/HoldPolicy.lua",
    "Rules/Classify.lua",
    "Pricing/Model.lua",
    "TSM/Prices.lua",
    "TSM/Freshness.lua",
    "TSM/PostingCache.lua",
    "UI/MainFrame.lua",
]


def test_required_files_exist():
    for rel in REQUIRED:
        assert (ADDON_SRC / rel).exists(), rel


def test_toc_lists_saved_vars():
    toc = (ADDON_SRC / "WoWSmartTSM.toc").read_text(encoding="utf-8")
    assert "WoWSmartTSM_DB" in toc
    assert "WoWSmartTSM_Diagnostics" in toc
    assert "16001" in toc


def test_lua_syntax_tree():
    result = check_tree(ADDON_SRC)
    assert result["checked"] > 20
    assert result["failed"] == [], result["failed"]
    tap = check_tree(DATATAP_SRC)
    assert tap["failed"] == [], tap["failed"]


def test_scan_command_does_not_imply_ah_scan():
    text = (ADDON_SRC / "Core" / "ScanService.lua").read_text(encoding="utf-8")
    assert "startedAhScan = false" in text
    assert "Never starts an Auction House scan" in text or "Never starts" in text
    cmd = (ADDON_SRC / "Core" / "Commands.lua").read_text(encoding="utf-8")
    assert "kein AH-Scan" in cmd or "Never starts an AH scan" in cmd


def test_prices_use_tsm_api_sources():
    text = (ADDON_SRC / "TSM" / "Prices.lua").read_text(encoding="utf-8")
    for src in (
        "DBMarket",
        "DBMinBuyout",
        "DBNumAuctions",
        "DBRegionMarketAvg",
        "DBRegionSaleRate",
        "DBRegionSoldPerDay",
        "VendorSell",
    ):
        assert src in text
    assert "GetCustomPriceValue" in text
    assert "ToItemString" in text
