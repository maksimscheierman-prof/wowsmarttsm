"""QUICK / PROFIT / RARE mode assignment regressions."""
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[2] / "tools"))
from smart_logic import classify, evaluate_pricing, COPPER_PER_GOLD


def test_missing_salerate_is_profit_not_quick():
    p = evaluate_pricing(
        {
            "marketValue": 50000,
            "minBuyout": 48000,
            "vendorSell": 100,
            "dataQuality": 0.9,
            # saleRate intentionally absent
            "soldPerDay": None,
        }
    )
    assert p["shouldPost"] is True
    assert p["mode"] == "PROFIT"
    assert "MODE_PROFIT_DEFAULT" in p["reasons"]


def test_high_salerate_is_quick():
    p = evaluate_pricing(
        {
            "marketValue": 50000,
            "minBuyout": 48000,
            "vendorSell": 100,
            "dataQuality": 0.9,
            "saleRate": 0.55,
            "soldPerDay": 1,
        }
    )
    assert p["shouldPost"] is True
    assert p["mode"] == "QUICK"


def test_blue_gear_posts_as_rare_not_quick():
    p = evaluate_pricing(
        {
            "marketValue": 25 * COPPER_PER_GOLD,
            "minBuyout": 24 * COPPER_PER_GOLD,
            "vendorSell": 2 * COPPER_PER_GOLD,
            "dataQuality": 0.9,
            "saleRate": 0.8,
            "soldPerDay": 5,
            "quality": 3,
            "isEquipment": True,
        }
    )
    assert p["shouldPost"] is True
    assert p["mode"] == "RARE"


def test_vendor_when_ah_not_profitable():
    d = classify(
        {
            "itemString": "i:vendor1",
            "name": "Junk",
            "quality": 1,
            "isEquipment": False,
            "vendorSell": 500,
            "marketValue": 200,
            "dataQuality": 0.9,
            "saleRate": 0.01,
            "soldPerDay": 0.01,
            "quantity": 5,
        }
    )
    assert d["strategy"] == "VENDOR"


def test_no_artificial_vendor_when_ah_wins():
    d = classify(
        {
            "itemString": "i:cloth",
            "name": "Silk Cloth",
            "quality": 1,
            "vendorSell": 100,
            "marketValue": 8000,
            "dataQuality": 0.9,
            "saleRate": 0.5,
            "soldPerDay": 3,
            "quantity": 20,
        }
    )
    assert d["strategy"] in ("QUICK_SELL", "PROFIT_SELL")
    assert d["strategy"] != "VENDOR"


def test_commands_scan_open_ui_default_documented():
    from paths import ADDON_SRC

    cmd = (ADDON_SRC / "Core" / "Commands.lua").read_text(encoding="utf-8")
    assert "openUIAfterScan" in cmd
    assert 'rest == "show"' in cmd
    sv = (ADDON_SRC / "Diagnostics" / "SavedVariables.lua").read_text(encoding="utf-8")
    assert "openUIAfterScan = false" in sv


def test_layout_table_no_nested_scroll_template():
    from paths import ADDON_SRC
    import re

    layout = (ADDON_SRC / "UI" / "Layout.lua").read_text(encoding="utf-8")
    # AddTable section should not create UIPanelScrollFrameTemplate
    add_table = layout.split("function Layout.AddTable", 1)[1].split("function Layout.FinishStack", 1)[0]
    assert "UIPanelScrollFrameTemplate" not in add_table
    assert "truncateTextToWidth" in layout
    assert "fullText" in layout


def test_vendor_tab_is_dry_run_ui():
    from paths import ADDON_SRC

    text = (ADDON_SRC / "UI" / "VendorTab.lua").read_text(encoding="utf-8")
    assert "BulkReview.Render" not in text
    assert "VendorService.SellSelected" in text
    assert "DRY_RUN" in text or "Dry-Run" in text
    assert "Keine Händler-Kandidaten" in text
    assert "APPLY" not in text or "Gruppen" in text
