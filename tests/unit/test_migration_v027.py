"""v0.2.7 TSM sell-group migration — offline."""
from __future__ import annotations

import json
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "tools"))
from paths import ADDON_SRC
from lua_syntax import check_tree


def _read(rel: str) -> str:
    return (ADDON_SRC / rel).read_text(encoding="utf-8")


def test_version_027():
    assert "0.2.7" in _read("Core/Version.lua")
    assert "## Version: 0.2.7" in _read("WoWSmartTSM.toc")
    assert "Migration.lua" in _read("WoWSmartTSM.toc")


def test_migration_module_safety():
    text = _read("Core/Migration.lua")
    assert "1er Group" in text
    assert "20er AH Sell" in text
    assert "Auto Vendeor ALL" in text
    assert "createSmartVendor = false" in text or "Create Smart Vendor: NO" in text or "NOT Smart Vendor" in text
    assert "OWNER_CONFIRM_DELETE_OLD_SELL_GROUPS" in text
    assert "IMPORT_STRING" in text
    assert "TSM.db" not in text
    assert "DeleteGroup" not in text or "no safe public DeleteGroup" in text
    assert "VENDOR_REMAPPED_TO_PROFIT" in text


def test_ops_use_owner_formulas():
    text = _read("TSM/Operations.lua")
    assert "2.11*vendorsell" in text
    assert "AHeqVendorPriceAutoSell" in text
    assert "Auto Vendeor ALL" in text


def test_commands_migrate():
    text = _read("Core/Commands.lua")
    assert 'cmd == "migrate"' in text
    assert "migrate import" in text or "migrate" in text


def test_offline_backup_report_exists():
    mig = ROOT / "diagnostics" / "migration"
    assert (mig / "MIGRATION_REPORT.md").exists()
    assert (mig / "tsm-groups-backup-latest.json").exists()
    assert (mig / "import-string.txt").exists()
    data = json.loads((mig / "tsm-groups-backup-latest.json").read_text(encoding="utf-8"))
    assert data["ownerDecision"]["createSmartVendor"] is False
    assert "1er Group" in data["ownerDecision"]["replace"]
    assert "Auto Vendeor ALL" in data["ownerDecision"]["keep"]
    assert data["deleteMarkers"]["1er Group"]["confirmedByOwner"] is False
    assert data["counts"]["replaceItems"] == 94
    assert data["counts"]["keepVendorItems"] == 7


def test_import_string_has_smart_groups_not_vendor_smart():
    s = (ROOT / "diagnostics" / "migration" / "import-string.txt").read_text(encoding="utf-8")
    assert "group:Smart TSM`Smart Quick Sell" in s
    assert "group:Smart TSM`Smart Rare Sell" in s
    assert "Smart Vendor" not in s
    assert "Auto Vendeor ALL" not in s  # vendor items not moved


def test_lua_syntax():
    assert check_tree(ADDON_SRC)["failed"] == []


def test_migration_tool_script():
    assert (ROOT / "tools" / "tsm_group_migration.py").exists()
