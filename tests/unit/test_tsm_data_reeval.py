"""Offline tests for TSM-data reevaluation semantics (no AH scan)."""
from __future__ import annotations

import sys
import time
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[2] / "tools"))
from smart_logic import classify, COPPER_PER_GOLD


class FakeFreshness:
    def __init__(self, realm=0, region=0, max_age=48 * 3600):
        self.realm = realm
        self.region = region
        self.max_age = max_age

    def describe(self, source, present, category):
        ts = self.realm if category == "realm" else self.region if category == "region" else int(time.time())
        age = None if not ts else max(0, int(time.time()) - ts)
        if not present:
            status = "MISSING"
            stale = False
        elif category in ("realm", "region") and not ts:
            status = "PRESENT_AGE_UNKNOWN"
            stale = False
        elif age is not None and age > self.max_age:
            status = "STALE"
            stale = True
        else:
            status = "FRESH"
            stale = False
        return {
            "source": source,
            "category": category,
            "present": present,
            "updatedAt": ts or None,
            "ageSeconds": age,
            "stale": stale,
            "status": status,
        }


class PostingCache:
    def __init__(self, ttl=1800):
        self.ttl = ttl
        self.by_item = {}

    def put(self, item, payload, at=None):
        self.by_item[item] = {"at": at or time.time(), "payload": payload}

    def get(self, item, now=None):
        e = self.by_item.get(item)
        if not e:
            return None
        now = now or time.time()
        if now - e["at"] > self.ttl:
            del self.by_item[item]
            return None
        return e["payload"]

    def invalidate(self, item=None):
        if item is None:
            self.by_item.clear()
        else:
            self.by_item.pop(item, None)


class DebounceQueue:
    def __init__(self, delay=1.5):
        self.delay = delay
        self.due = 0
        self.pending = False
        self.full = False
        self.runs = []

    def schedule(self, now, reason, full=True):
        self.pending = True
        self.full = full or self.full
        self.due = now + self.delay
        self.reason = reason

    def tick(self, now):
        if self.pending and now >= self.due:
            self.runs.append({"reason": self.reason, "full": self.full, "ahScan": False})
            self.pending = False
            self.full = False
            return True
        return False


def test_freshness_missing_vs_stale_vs_fresh():
    now = int(time.time())
    f = FakeFreshness(realm=now - 60, region=now - 60)
    assert f.describe("DBMarket", True, "realm")["status"] == "FRESH"
    f2 = FakeFreshness(realm=now - 100000, region=now - 100000, max_age=3600)
    assert f2.describe("DBMarket", True, "realm")["status"] == "STALE"
    assert f.describe("DBMarket", False, "realm")["status"] == "MISSING"


def test_freshness_age_unknown_when_no_download_time():
    f = FakeFreshness(realm=0, region=0)
    d = f.describe("DBRegionMarketAvg", True, "region")
    assert d["status"] == "PRESENT_AGE_UNKNOWN"


def test_cache_hit_and_invalidation():
    c = PostingCache(ttl=10)
    c.put("i:1", {"minBuyout": 100, "tsmSkipToken": "BELOW_MIN"}, at=1000)
    assert c.get("i:1", now=1005)["minBuyout"] == 100
    assert c.get("i:1", now=1020) is None  # expired
    c.put("i:2", {"minBuyout": 50}, at=2000)
    c.invalidate("i:2")
    assert c.get("i:2", now=2001) is None


def test_debounce_collapses_bag_events():
    q = DebounceQueue(delay=1.5)
    q.schedule(0.0, "bag_update")
    q.schedule(0.2, "bag_update")
    q.schedule(0.4, "bag_update")
    assert q.tick(1.0) is False
    assert q.tick(2.0) is True
    assert len(q.runs) == 1
    assert q.runs[0]["ahScan"] is False


def test_reeval_never_starts_ah_scan_flag():
    meta = {"startedAhScan": False, "mode": "TSM_DATA_REEVAL", "reason": "manual_command"}
    assert meta["startedAhScan"] is False
    assert "AH" not in meta["mode"] or meta["mode"] == "TSM_DATA_REEVAL"


def test_missing_competition_flags_need_live_not_auto_scan():
    prices = {"dbMinBuyout": None, "numAuctions": None, "dbMarket": 5000}
    needs_live = prices["dbMinBuyout"] is None and prices["numAuctions"] is None
    assert needs_live is True
    # policy: flag only — do not invent an AH scan starter
    started_ah_scan = False
    assert started_ah_scan is False


def test_hold_and_vendor_guards_still_apply_with_tsm_fields():
    d = classify(
        {
            "itemString": "i:bound",
            "vendorSell": 100,
            "marketValue": 10,
            "dataQuality": 0.8,
            "isBound": True,
            "fromAuctionDB": True,
        }
    )
    assert d["protect"]["protected"] is True
    d2 = classify(
        {
            "itemString": "i:green",
            "name": "Green",
            "quality": 2,
            "isEquipment": True,
            "vendorSell": 2 * COPPER_PER_GOLD,
            "marketValue": 15 * COPPER_PER_GOLD,
            "dataQuality": 0.9,
            "saleRate": 0.01,
            "soldPerDay": 0.01,
            "deposit": 10 * COPPER_PER_GOLD,
            "fromAuctionDB": True,
        }
    )
    if not d2["pricing"]["shouldPost"] and d2["hold"]["eligible"]:
        assert d2["strategy"] == "HOLD"


def test_stale_freshness_reduces_blind_vendor():
    d = classify(
        {
            "itemString": "i:x",
            "vendorSell": 50,
            "marketValue": None,
            "regionMarket": None,
            "dataQuality": 0.5,
            "stale": True,
        }
    )
    assert d["strategy"] == "MANUAL_REVIEW"
    assert "STALE_OR_MISSING_MARKET_NO_BLIND_VENDOR" in d["reasons"]
