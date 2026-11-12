from pathlib import Path
import sys

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "tools"))
from lua_syntax import check_tree
from paths import ADDON_SRC


REQUIRED = [
    "WoWSmartTSM.toc",
    "Core/Addon.lua",
    "Diagnostics/Logger.lua",
    "Rules/HoldPolicy.lua",
    "Rules/Classify.lua",
    "Pricing/Model.lua",
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
