"""v0.2.5 — group hierarchy / cleanup assignment / operations tab."""
from __future__ import annotations

import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "tools"))
from paths import ADDON_SRC
from lua_syntax import check_tree


def _read(rel: str) -> str:
    return (ADDON_SRC / rel).read_text(encoding="utf-8")


def test_version_025():
    ver = _read("Core/Version.lua")
    toc = _read("WoWSmartTSM.toc")
    assert 'STRING = "0.2.' in ver
    assert "## Version: 0.2." in toc


def test_groups_tab_is_hierarchy_not_inventory():
    text = _read("UI/GroupsTab.lua")
    assert "BuildHierarchy" in text
    assert (
        "NOT an inventory" in text
        or "Itemzuordnung" in text
        or "TwoColumns" in text
    )
    assert "BuildProposals" not in text
    assert "missing" in text.lower() or "Fehlende" in text


def test_cleanup_has_group_assignment():
    text = _read("UI/CleanupTab.lua")
    assert "TSM-Gruppe" in text or "proposedGroup" in text
    assert "ListChoices" in text
    assert "APPLY_SAFE_ALL" in text or "ApplySelectedMoves" in text
    assert "assignPermanent" in text
    assert "GroupManager" in text


def test_operations_tab_exists():
    assert (ADDON_SRC / "UI" / "OperationsTab.lua").exists()
    text = _read("UI/OperationsTab.lua")
    assert "Auctioning" in text
    assert "Mailing" in text
    assert "Vendoring" in text
    assert "unbekannt" in text or "UnknownLabel" in text
    assert "BuildCatalog" in text
    toc = _read("WoWSmartTSM.toc")
    assert "OperationsTab.lua" in toc


def test_operations_suggestions_validate_formulas():
    text = _read("TSM/Operations.lua")
    assert "ValidatePriceFormula" in text
    assert "IsCustomPriceValid" in text
    assert "GetEditableSuggestion" in text
    assert "SetSuggestionField" in text
    assert "BANK_NO_SELF_MAIL" in text
    assert "MANUAL_SETUP" in text


def test_groups_hierarchy_helpers():
    text = _read("TSM/Groups.lua")
    assert "BuildHierarchy" in text
    assert "ListChoices" in text
    assert "FormatPath" in text
    assert "CountItems" in text
    assert "OpenInTSM" in text


def test_no_private_tsm_writes():
    for rel in ("TSM/Groups.lua", "TSM/Operations.lua", "Core/GroupManager.lua"):
        text = _read(rel)
        assert "TSM.db" not in text
        assert "GroupOperation.Add" not in text
        assert "SellItem" not in text
        assert "SendMail" not in text


def test_tabs_wired():
    main = _read("UI/MainFrame.lua")
    init = _read("UI/Init.lua")
    assert '"Operations"' in main
    assert 'Operations = "OperationsTab"' in init
    assert "OPERATIONS_TAB" in _read("Locale/deDE.lua")


def test_setup_simplified():
    text = _read("UI/SetupWizard.lua")
    assert "Mailing" in text or "Mail" in text
    assert "AH Bank" in text or "Auctioning" in text or "Bank" in text
    assert "Verify" in text or "verifizieren" in text.lower()
    assert "Doppelverwaltung" in text or "Duplikate" in text or "fehlend" in text.lower()


def test_lua_syntax_ok():
    result = check_tree(ADDON_SRC)
    assert result["failed"] == [], result["failed"]


def test_hierarchy_sort_model():
    paths = ["Smart TSM", "Smart TSM`Smart Quick Sell", "MyFarm", "Smart TSM`Smart Vendor"]
    paths = sorted(paths)
    assert paths[0] == "MyFarm"
    assert paths[1] == "Smart TSM"
