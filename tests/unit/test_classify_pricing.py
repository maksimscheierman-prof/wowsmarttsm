import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[2] / "tools"))
from smart_logic import classify, evaluate_pricing, map_tsm_skip, COPPER_PER_GOLD


def test_common_material_not_hold_goes_vendor_or_post():
    d = classify(
        {
            "itemString": "i:123",
            "name": "Silk Cloth",
            "quality": 1,
            "isEquipment": False,
            "vendorSell": 100,
            "marketValue": 50,  # AH worse than vendor after cut likely
            "dataQuality": 0.8,
            "saleRate": 0.01,
            "soldPerDay": 0.05,
            "quantity": 20,
        }
    )
    assert d["strategy"] != "HOLD"


def test_competition_below_min_flagged_in_pricing():
    p = evaluate_pricing(
        {
            "marketValue": 4209,
            "minBuyout": 2100,
            "operationMinPrice": 2946,
            "vendorSell": 50,
            "dataQuality": 0.9,
            "saleRate": 0.5,
            "soldPerDay": 3,
        }
    )
    assert "COMPETITION_BELOW_OPERATION_MIN" in p["reasons"]


def test_profitable_lower_price_can_post():
    p = evaluate_pricing(
        {
            "marketValue": 50000,
            "minBuyout": 45000,
            "operationMinPrice": 48000,
            "vendorSell": 100,
            "dataQuality": 0.9,
            "saleRate": 0.6,
            "soldPerDay": 4,
        }
    )
    assert p["shouldPost"] is True


def test_deposit_risk_high():
    p = evaluate_pricing(
        {
            "marketValue": 1000,
            "vendorSell": 900,
            "deposit": 800,
            "dataQuality": 0.9,
            "saleRate": 0.05,
            "soldPerDay": 0.01,
        }
    )
    # may not post due to deposit / vendor
    assert p["shouldPost"] is False or "DEPOSIT_RISK_TOO_HIGH" in p["reasons"] or "NET_IF_SOLD_LEQ_VENDOR" in p["reasons"]


def test_loss_vs_vendor():
    p = evaluate_pricing(
        {
            "marketValue": 200,
            "vendorSell": 500,
            "dataQuality": 0.9,
            "saleRate": 0.8,
        }
    )
    assert p["shouldPost"] is False


def test_region_without_local():
    p = evaluate_pricing(
        {
            "regionMarket": 20000,
            "vendorSell": 100,
            "dataQuality": 0.7,
            "saleRate": 0.5,
            "soldPerDay": 2,
        }
    )
    assert "USING_REGION_AS_MARKET" in p["reasons"]


def test_protected_no_vendor():
    d = classify(
        {
            "itemString": "i:1",
            "vendorSell": 100,
            "marketValue": 10,
            "dataQuality": 0.8,
            "saleRate": 0.01,
            "isBound": True,
        }
    )
    assert d["strategy"] == "MANUAL_REVIEW"
    assert "VENDOR_BLOCKED_PROTECTED" in d["reasons"] or d["protect"]["protected"]


def test_equipped_protected():
    d = classify(
        {
            "itemString": "i:2",
            "vendorSell": 100,
            "marketValue": 10,
            "dataQuality": 0.8,
            "isEquipped": True,
        }
    )
    assert d["protect"]["protected"]


def test_always_keep():
    d = classify(
        {
            "itemString": "i:99",
            "vendorSell": 100,
            "marketValue": 10,
            "dataQuality": 0.8,
        },
        db={"alwaysKeep": {"i:99": True}},
    )
    assert "ALWAYS_KEEP" in d["protect"]["reasons"]


def test_hold_when_ah_bad_green():
    d = classify(
        {
            "itemString": "i:green",
            "name": "Green Pants",
            "quality": 2,
            "isEquipment": True,
            "vendorSell": 2 * COPPER_PER_GOLD,
            "marketValue": 15 * COPPER_PER_GOLD,
            "minBuyout": 100,  # nonsense low competition but thin demand
            "dataQuality": 0.9,
            "saleRate": 0.01,
            "soldPerDay": 0.01,
            "deposit": 10 * COPPER_PER_GOLD,
        }
    )
    # Either HOLD or VENDOR/REVIEW depending on EV; green with bad AH should prefer HOLD over vendor when eligible
    if not d["pricing"]["shouldPost"]:
        assert d["strategy"] in ("HOLD", "VENDOR", "MANUAL_REVIEW")
        if d["hold"]["eligible"]:
            assert d["strategy"] == "HOLD"


def test_skip_map_below_min():
    assert map_tsm_skip("NOT_POSTING.BELOW_MIN") == "COMPETITION_BELOW_MIN"


def test_insufficient_data_review():
    d = classify(
        {
            "itemString": "i:x",
            "vendorSell": 0,
            "marketValue": None,
            "regionMarket": None,
            "dataQuality": 0.1,
        }
    )
    assert d["strategy"] == "MANUAL_REVIEW"
