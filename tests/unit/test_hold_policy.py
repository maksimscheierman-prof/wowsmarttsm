import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[2] / "tools"))
from smart_logic import evaluate_hold, HOLD_MIN_MARKET, COPPER_PER_GOLD


def test_normal_material_never_hold():
    ok, det = evaluate_hold(
        {
            "marketValue": 20 * COPPER_PER_GOLD,
            "vendorSell": 1 * COPPER_PER_GOLD,
            "quality": 1,
            "isEquipment": False,
            "isRecipe": False,
        }
    )
    assert ok is False
    assert "CATEGORY_NOT_ALLOWED" in det["reasons"]


def test_green_meets_both_conditions():
    ok, det = evaluate_hold(
        {
            "marketValue": 15 * COPPER_PER_GOLD,
            "vendorSell": 2 * COPPER_PER_GOLD,
            "quality": 2,
            "isEquipment": True,
            "isRecipe": False,
        }
    )
    assert ok is True
    assert det["category"] == "EXPENSIVE_GREEN_GEAR"


def test_green_only_one_condition_market_low():
    ok, _ = evaluate_hold(
        {
            "marketValue": 8 * COPPER_PER_GOLD,
            "vendorSell": 1 * COPPER_PER_GOLD,
            "quality": 2,
            "isEquipment": True,
        }
    )
    assert ok is False


def test_green_only_one_condition_ratio_low():
    ok, det = evaluate_hold(
        {
            "marketValue": 15 * COPPER_PER_GOLD,
            "vendorSell": 5 * COPPER_PER_GOLD,  # only 3x
            "quality": 2,
            "isEquipment": True,
        }
    )
    assert ok is False
    assert "MARKET_BELOW_5X_VENDOR" in det["reasons"]


def test_blue_under_10g():
    ok, det = evaluate_hold(
        {
            "marketValue": 8 * COPPER_PER_GOLD,
            "vendorSell": 1 * COPPER_PER_GOLD,
            "quality": 3,
            "isEquipment": True,
        }
    )
    assert ok is False
    assert "MARKET_BELOW_10G" in det["reasons"]


def test_epic_over_10g():
    ok, det = evaluate_hold(
        {
            "marketValue": 50 * COPPER_PER_GOLD,
            "vendorSell": 5 * COPPER_PER_GOLD,
            "quality": 4,
            "isEquipment": True,
        }
    )
    assert ok is True
    assert det["category"] == "EPIC_GEAR"


def test_rare_recipe():
    ok, det = evaluate_hold(
        {
            "marketValue": 50 * COPPER_PER_GOLD,
            "vendorSell": 5 * COPPER_PER_GOLD,
            "quality": 2,
            "isEquipment": False,
            "isRecipe": True,
        }
    )
    assert ok is True
    assert det["category"] == "RARE_RECIPE"


def test_vendor_sell_zero_no_div_by_zero():
    ok, det = evaluate_hold(
        {
            "marketValue": 20 * COPPER_PER_GOLD,
            "vendorSell": 0,
            "quality": 3,
            "isEquipment": True,
        }
    )
    assert ok is True
    assert det["vendorSellZero"] is True
    assert det["ratio"] is None


def test_missing_market():
    ok, det = evaluate_hold({"vendorSell": 100, "quality": 4, "isEquipment": True})
    assert ok is False
    assert "MISSING_MARKET" in det["reasons"]


def test_hold_min_constant():
    assert HOLD_MIN_MARKET == 10 * COPPER_PER_GOLD
