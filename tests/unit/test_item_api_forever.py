"""Item/Bag API Forever compatibility regressions."""
from pathlib import Path
import re
import sys

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "tools"))
from paths import ADDON_SRC


def _strip(text: str) -> str:
    text = re.sub(r"--\[\[.*?\]\]", "", text, flags=re.S)
    text = re.sub(r"--(?!\[\[).*$", "", text, flags=re.M)
    return text


def test_itemapi_module_exists_and_probes():
    path = ADDON_SRC / "Util" / "ItemAPI.lua"
    assert path.exists()
    text = path.read_text(encoding="utf-8")
    for api in (
        "ProbeCapabilities",
        "GetInfo",
        "GetInfoInstant",
        "GetBagSlot",
        "GetBagNumSlots",
        "RequestLoad",
        "Init",
    ):
        assert f"function ItemAPI.{api}" in text, api
    assert "C_Item.GetItemInfo" in text
    assert "C_Container.GetContainerItemInfo" in text
    assert "VERIFIED" in text
    assert "UNSUPPORTED" in text
    assert "GET_ITEM_INFO_RECEIVED" in text


def test_no_bare_getiteminfo_calls_in_scan_or_itemutil():
    """ScanService/ItemUtil must not call global GetItemInfo as a required path."""
    for rel in ("Core/ScanService.lua", "Util/ItemUtil.lua"):
        code = _strip((ADDON_SRC / rel).read_text(encoding="utf-8"))
        # Disallow direct GetItemInfo( — ItemAPI may mention in comments only (stripped)
        assert "GetItemInfo(" not in code, rel
        assert "GetItemInfoInstant(" not in code, rel


def test_scan_service_uses_itemapi_and_per_slot_pcall():
    text = (ADDON_SRC / "Core" / "ScanService.lua").read_text(encoding="utf-8")
    assert "ItemAPI.GetBagSlot" in text
    assert "ItemAPI.GetInfo" in text
    assert "pcall(buildRawFromSlot" in text
    assert "metaIncomplete" in text
    assert 'status = "FAILED"' in text
    assert 'status = "OK"' in text


def test_itemprofile_blocks_incomplete_meta_from_vendor():
    text = (ADDON_SRC / "Rules" / "ItemProfile.lua").read_text(encoding="utf-8")
    assert "metaIncomplete" in text
    assert "unknownIdentity" in text


def test_toc_loads_itemapi_before_itemutil():
    toc = (ADDON_SRC / "WoWSmartTSM.toc").read_text(encoding="utf-8")
    assert "Util\\ItemAPI.lua" in toc
    assert toc.index("Util\\ItemAPI.lua") < toc.index("Util\\ItemUtil.lua")
    assert "## Version: 0.1.4" in toc


def test_offline_getiteminfo_absent_simulation():
    """Simulate Forever: global GetItemInfo missing; C_Item present → still produce info."""

    class FakeCItem:
        @staticmethod
        def GetItemInfo(item):
            return ("Copper Ore", "|Hitem:2770|h[Copper Ore]|h", 1, 1, 0, "Trade Goods", "Metal & Stone", 20, "", 134566, 20)

        @staticmethod
        def GetItemInfoInstant(item_id):
            return (2770, "Trade Goods", "Metal & Stone", "", 134566, 7, 7)

    # Minimal Python mirror of preferred path
    def get_info(item, get_item_info=None, c_item=None):
        if c_item and hasattr(c_item, "GetItemInfo"):
            name, link, quality, *_rest = c_item.GetItemInfo(item)
            return {"name": name, "link": link, "quality": quality, "complete": name is not None}
        if get_item_info:
            name, link, quality, *_rest = get_item_info(item)
            return {"name": name, "link": link, "quality": quality, "complete": True}
        return {"name": None, "complete": False, "pending": True}

    # Forever case: GetItemInfo is None
    out = get_info("item:2770", get_item_info=None, c_item=FakeCItem)
    assert out["complete"] is True
    assert out["name"] == "Copper Ore"

    # Total absence
    out2 = get_info("item:2770", get_item_info=None, c_item=None)
    assert out2["complete"] is False
    assert out2.get("pending") is True


def test_reeval_continues_when_one_slot_raises():
    """Per-slot isolation model: one failure does not abort the bag walk."""
    slots = [0, 1, 2, 3]

    def build(slot):
        if slot == 2:
            raise RuntimeError("boom")
        return {"slot": slot}

    items = []
    skipped = 0
    for s in slots:
        try:
            items.append(build(s))
        except Exception:
            skipped += 1
    assert len(items) == 3
    assert skipped == 1
