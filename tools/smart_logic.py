"""Offline reference implementation of Smart Hold / Classify / Pricing.

Mirrors addon Lua engines for deterministic unit tests without WoW/Lua runtime.
Keep in sync with addon/WoWSmartTSM/Rules and Pricing modules.
"""
from __future__ import annotations

from dataclasses import dataclass, field
from typing import Any, Optional

COPPER_PER_GOLD = 10000
HOLD_MIN_MARKET = 10 * COPPER_PER_GOLD
HOLD_VENDOR_MULT = 5

QUALITY_UNCOMMON = 2
QUALITY_RARE = 3
QUALITY_EPIC = 4

STRATEGIES = {
    "QUICK_SELL": "QUICK_SELL",
    "PROFIT_SELL": "PROFIT_SELL",
    "RARE_SELL": "RARE_SELL",
    "VENDOR": "VENDOR",
    "HOLD": "HOLD",
    "MANUAL_REVIEW": "MANUAL_REVIEW",
}

GROUPS = {
    "QUICK": "Smart TSM`Smart Quick Sell",
    "PROFIT": "Smart TSM`Smart Profit Sell",
    "RARE": "Smart TSM`Smart Rare Sell",
    "VENDOR": "Smart TSM`Smart Vendor",
    "HOLD": "Smart TSM`Smart Hold",
    "REVIEW": "Smart TSM`Manual Review",
}


def resolve_hold_category(profile: dict) -> Optional[str]:
    q = profile.get("quality") or 0
    is_equip = profile.get("isEquipment") is True
    is_recipe = profile.get("isRecipe") is True
    if is_recipe and q >= QUALITY_UNCOMMON:
        return "RARE_RECIPE"
    if is_equip and q >= QUALITY_EPIC:
        return "EPIC_GEAR"
    if is_equip and q == QUALITY_RARE:
        return "BLUE_GEAR"
    if is_equip and q == QUALITY_UNCOMMON:
        return "EXPENSIVE_GREEN_GEAR"
    return None


def evaluate_hold(profile: dict) -> tuple[bool, dict]:
    reasons: list[str] = []
    market = profile.get("marketValue")
    vendor = profile.get("vendorSell") or 0
    if market is None:
        return False, {"eligible": False, "reasons": ["MISSING_MARKET"], "category": None}

    category = resolve_hold_category(profile)
    if not category:
        return False, {
            "eligible": False,
            "reasons": ["CATEGORY_NOT_ALLOWED"],
            "category": None,
            "marketValue": market,
            "vendorSell": vendor,
        }

    if market < HOLD_MIN_MARKET:
        reasons.append("MARKET_BELOW_10G")

    ratio = None
    if vendor == 0:
        reasons.append("VENDOR_SELL_ZERO_SPECIAL")
        ratio_ok = market >= HOLD_MIN_MARKET
    else:
        ratio = market / vendor
        ratio_ok = ratio >= HOLD_VENDOR_MULT
        if not ratio_ok:
            reasons.append("MARKET_BELOW_5X_VENDOR")

    market_ok = market >= HOLD_MIN_MARKET
    eligible = market_ok and ratio_ok and category is not None
    if eligible:
        reasons = ["HOLD_FILTER_PASS"]
    return eligible, {
        "eligible": eligible,
        "category": category,
        "marketValue": market,
        "vendorSell": vendor,
        "ratio": ratio,
        "vendorSellZero": vendor == 0,
        "reasons": reasons,
    }


def protect_evaluate(profile: dict, db: Optional[dict] = None) -> dict:
    reasons = []
    db = db or {}
    if profile.get("isBound"):
        reasons.append("BOUND")
    if profile.get("isEquipped"):
        reasons.append("EQUIPPED")
    if profile.get("isQuestItem"):
        reasons.append("QUEST")
    if profile.get("isLocked"):
        reasons.append("LOCKED")
    if profile.get("isProtectedFlag"):
        reasons.append("EXPLICIT_PROTECTED")
    item = profile.get("itemString")
    if item and (db.get("alwaysKeep") or {}).get(item):
        reasons.append("ALWAYS_KEEP")
    if item and (db.get("reservedCrafting") or {}).get(item):
        reasons.append("RESERVED_CRAFTING")
    if profile.get("unknownIdentity"):
        reasons.append("UNKNOWN_IDENTITY")
    return {"protected": len(reasons) > 0, "reasons": reasons}


@dataclass
class PricingConfig:
    ah_cut: float = 0.05
    deposit_rate_fallback: float = 0.15
    min_expected_net: float = 0
    sale_rate_discount: float = 0.65
    undercut: int = 1
    deposit_fail_weight: float = 1.0


def _estimate_deposit(profile: dict, cfg: PricingConfig, price: int) -> int:
    if profile.get("deposit"):
        return int(profile["deposit"])
    base = profile.get("vendorSell") or 0
    if base <= 0:
        base = int((price or 0) * 0.05)
    return max(1, int(base * cfg.deposit_rate_fallback * (profile.get("stackSize") or 1)))


def _sell_proxy(profile: dict, cfg: PricingConfig, price: int) -> tuple[float, bool]:
    p = 0.35
    unreliable = True
    if profile.get("saleRate") is not None:
        p = min(0.9, max(0.05, float(profile["saleRate"]) * cfg.sale_rate_discount))
        unreliable = False
    if profile.get("soldPerDay") is not None:
        spd = float(profile["soldPerDay"])
        if spd >= 5:
            p = min(0.92, p + 0.15)
        elif spd <= 0.2:
            p = max(0.05, p - 0.15)
        unreliable = False
    mb = profile.get("minBuyout")
    if mb and price:
        if price > mb * 1.15:
            p = max(0.05, p - 0.2)
        elif price <= mb:
            p = min(0.95, p + 0.1)
    if (profile.get("numAuctions") or 0) > 20:
        p = max(0.05, p - 0.1)
    return p, unreliable


def score_price(profile: dict, price: int, cfg: Optional[PricingConfig] = None) -> dict:
    cfg = cfg or PricingConfig()
    price = int(price or 0)
    if price <= 0:
        return {"price": price, "ev": None, "valid": False, "reason": "INVALID_PRICE"}
    deposit = _estimate_deposit(profile, cfg, price)
    p, unreliable = _sell_proxy(profile, cfg, price)
    nis = int(price * (1 - cfg.ah_cut))
    ev = p * nis - (1 - p) * cfg.deposit_fail_weight * deposit
    return {
        "price": price,
        "ev": ev,
        "pSellProxy": p,
        "pSellUnreliable": unreliable,
        "deposit": deposit,
        "netIfSold": nis,
        "valid": True,
    }


def evaluate_pricing(profile: dict, cfg: Optional[PricingConfig] = None) -> dict:
    cfg = cfg or PricingConfig()
    reasons: list[str] = []
    market = profile.get("marketValue")
    region = profile.get("regionMarket")
    min_buyout = profile.get("minBuyout")
    op_min = profile.get("operationMinPrice")
    vendor = profile.get("vendorSell") or 0

    if market is None and region is not None:
        market = region
        reasons.append("USING_REGION_AS_MARKET")
    if market is None and min_buyout is not None:
        market = min_buyout
        reasons.append("USING_MINBUYOUT_AS_MARKET")

    thin = (profile.get("dataQuality") or 0) < 0.4 or profile.get("stale")
    if thin:
        reasons.append("THIN_OR_STALE_DATA_CONSERVATIVE")

    candidates = []

    def add(price, tag):
        if price and price > 0:
            scored = score_price(profile, int(price), cfg)
            scored["tag"] = tag
            candidates.append(scored)

    if market:
        add(market, "DBMARKET")
        add(int(market * 0.95), "DBMARKET_95")
        add(int(market * 0.85), "DBMARKET_85")
    if min_buyout:
        add(max(1, int(min_buyout) - cfg.undercut), "UNDERCUT_MINBUYOUT")
    if op_min and min_buyout and min_buyout < op_min:
        add(max(1, int(min_buyout) - cfg.undercut), "BELOW_OP_MIN_CANDIDATE")
        reasons.append("COMPETITION_BELOW_OPERATION_MIN")
    if vendor > 0:
        add(int(vendor / max(0.01, (1 - cfg.ah_cut)) + 1), "VENDOR_FLOOR")

    best = None
    for c in candidates:
        if c.get("valid") and c.get("ev") is not None:
            if best is None or c["ev"] > best["ev"]:
                best = c

    should_post = False
    mode = "PROFIT"
    if best and best["ev"] is not None and best["ev"] >= cfg.min_expected_net:
        if vendor > 0 and best["ev"] < vendor * 0.5 and thin:
            reasons.append("EV_NOT_BETTER_THAN_VENDOR_CONSERVATIVE")
        elif best["netIfSold"] <= vendor and vendor > 0:
            reasons.append("NET_IF_SOLD_LEQ_VENDOR")
        elif best["deposit"] > (best["netIfSold"] * 0.8) and (best["pSellProxy"] or 0) < 0.25:
            reasons.append("DEPOSIT_RISK_TOO_HIGH")
        else:
            should_post = True
            if (profile.get("saleRate") or 1) >= 0.4 or (profile.get("soldPerDay") or 0) >= 2:
                mode = "QUICK"
            cat = resolve_hold_category(profile)
            if cat and (profile.get("quality") or 0) >= QUALITY_RARE:
                mode = "RARE"
            reasons.append("EV_POSITIVE")
    else:
        reasons.append("NO_POSITIVE_EV_CANDIDATE")

    if best and best.get("netIfSold") is not None and vendor > 0 and best["netIfSold"] < vendor:
        reasons.append("POTENTIAL_LOSS_VS_VENDOR")

    return {
        "shouldPost": should_post,
        "mode": mode,
        "suggestedBuyout": best["price"] if best else None,
        "expectedNet": best["ev"] if best else None,
        "estimatedDeposit": best["deposit"] if best else _estimate_deposit(profile, cfg, vendor),
        "candidates": candidates,
        "best": best,
        "reasons": reasons,
        "thinData": thin,
    }


def classify(profile: dict, db: Optional[dict] = None) -> dict:
    reasons: list[str] = []
    protect = protect_evaluate(profile, db)
    pricing = evaluate_pricing(profile)
    hold_ok, hold_details = evaluate_hold(profile)

    decision = {
        "itemString": profile.get("itemString"),
        "name": profile.get("name"),
        "quality": profile.get("quality"),
        "vendorSell": profile.get("vendorSell"),
        "marketValue": profile.get("marketValue"),
        "strategy": STRATEGIES["MANUAL_REVIEW"],
        "targetGroup": GROUPS["REVIEW"],
        "confidence": profile.get("dataQuality") or 0,
        "dataQuality": profile.get("dataQuality") or 0,
        "reasons": reasons,
        "pricing": pricing,
        "hold": hold_details,
        "protect": protect,
        "expectedNet": pricing.get("expectedNet"),
        "suggestedPrice": pricing.get("suggestedBuyout"),
    }

    if profile.get("unknownIdentity"):
        reasons.append("UNKNOWN_ITEM")
        return decision

    if (
        profile.get("marketValue") is None
        and profile.get("regionMarket") is None
        and (profile.get("vendorSell") or 0) == 0
    ) or (profile.get("dataQuality") or 0) < 0.25:
        reasons.append("INSUFFICIENT_MARKET_DATA")
        return decision

    if pricing["shouldPost"]:
        reasons.append("AH_PROFITABLE")
        if pricing["mode"] == "QUICK":
            decision["strategy"] = STRATEGIES["QUICK_SELL"]
            decision["targetGroup"] = GROUPS["QUICK"]
        elif pricing["mode"] == "RARE":
            decision["strategy"] = STRATEGIES["RARE_SELL"]
            decision["targetGroup"] = GROUPS["RARE"]
        else:
            decision["strategy"] = STRATEGIES["PROFIT_SELL"]
            decision["targetGroup"] = GROUPS["PROFIT"]
        return decision

    reasons.append("AH_NOT_PROFITABLE")
    if hold_ok:
        reasons.append("HOLD_FILTER_APPLIED")
        decision["strategy"] = STRATEGIES["HOLD"]
        decision["targetGroup"] = GROUPS["HOLD"]
        return decision

    if protect["protected"]:
        reasons.append("VENDOR_BLOCKED_PROTECTED")
        return decision

    if (profile.get("vendorSell") or 0) <= 0:
        reasons.append("VENDOR_SELL_ZERO_NO_BLIND")
        return decision

    if profile.get("stale") and profile.get("marketValue") is None:
        reasons.append("STALE_OR_MISSING_MARKET_NO_BLIND_VENDOR")
        return decision

    reasons.append("VENDOR_CANDIDATE")
    decision["strategy"] = STRATEGIES["VENDOR"]
    decision["targetGroup"] = GROUPS["VENDOR"]
    decision["expectedNet"] = (profile.get("vendorSell") or 0) * (profile.get("quantity") or 1)
    return decision


SKIP_CODES = {
    "BELOW_MIN": "COMPETITION_BELOW_MIN",
    "DISABLED": "DISABLED",
    "NOT_ENOUGH": "NOT_ENOUGH",
    "MAX_EXPIRES": "MAX_EXPIRES",
    "ABOVE_MAX": "ABOVE_MAX_NO_POST",
    "POST_CAP": "POST_CAP",
}


def map_tsm_skip(token: Optional[str]) -> str:
    if not token:
        return "UNKNOWN"
    t = str(token)
    for k, v in SKIP_CODES.items():
        if k in t:
            return v
    if "MIN_PRICE" in t or "MAX_PRICE" in t or "NORMAL_PRICE" in t:
        return "INVALID_OPERATION"
    return "UNKNOWN"


def fingerprint(code: str, module: str, func: str, message: str, stack: str = "") -> str:
    import re

    def norm(s: str) -> str:
        s = re.sub(r"\d+", "N", s or "")
        s = re.sub(r"\s+", " ", s)
        return s[:160]

    stack_sig = re.sub(r"\d+", "N", stack or "")
    stack_sig = re.sub(r":\d+", ":N", stack_sig)[:200]
    return "|".join([code or "", module or "", func or "", norm(message), stack_sig])
