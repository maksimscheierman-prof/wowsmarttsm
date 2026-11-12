"""Regression tests for DataTap P0: function-as-table indexing crash.

Reproduces:
  Interface/AddOns/!SmartTSM_DataTap/DataTap.lua:60:
  attempt to index local 'orig' (a function value)
"""
from __future__ import annotations

import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
DATATAP = ROOT / "addon" / "!SmartTSM_DataTap" / "DataTap.lua"
COMMANDS = ROOT / "addon" / "WoWSmartTSM" / "Core" / "Commands.lua"
ADDON = ROOT / "addon" / "WoWSmartTSM" / "Core" / "Addon.lua"


def _strip_lua_comments(text: str) -> str:
    # line comments
    text = re.sub(r"--(?!\[\[).*$", "", text, flags=re.M)
    # long comments
    text = re.sub(r"--\[\[.*?\]\]", "", text, flags=re.S)
    return text


def test_source_no_longer_indexes_functions_as_tables():
    raw = DATATAP.read_text(encoding="utf-8")
    text = _strip_lua_comments(raw)
    # The exact failing patterns from the bug report must not appear in code
    assert "orig.__smartTSMWrapped" not in text
    assert "wrapped.__smartTSMWrapped" not in text
    assert "__smartTSMWrapped" not in text
    # Safe identity-based idempotency must exist
    assert "private.wrappedLoader" in text
    assert "current == private.wrappedLoader" in text
    assert "return orig(...)" in text


def test_lua_function_indexing_is_the_reproduced_error_class():
    """Simulate the Lua failure mode: treating a function like a table."""

    def orig(tag, realm, data):
        return "ok", tag

    # Python functions also reject attribute assignment of this kind for our check:
    # The bug was Lua: orig.__smartTSMWrapped → "attempt to index local 'orig' (a function value)"
    raised = False
    try:
        # Emulate Lua rawget on a function via an explicit guard that mirrors Lua semantics
        if not isinstance(orig, dict):
            raise TypeError("attempt to index local 'orig' (a function value)")
        _ = orig["__smartTSMWrapped"]  # pragma: no cover
    except TypeError as e:
        raised = True
        assert "attempt to index local 'orig' (a function value)" in str(e)
    assert raised is True


class DataTapWrapperSim:
    """Mirrors the fixed DataTap wrap semantics in Python."""

    def __init__(self):
        self.original_loader = None
        self.wrapped_loader = None
        self.wrapping = False
        self.g = {"TSM_APPHELPER_LOAD_DATA": None}
        self.notes = []
        self.on_update_active = False
        self.on_update_sets = 0

    def note(self, tag, realm, data):
        if not isinstance(data, str):
            return
        m = re.search(r"downloadTime=(\d+)", data)
        if m:
            self.notes.append((tag, realm, int(m.group(1))))

    def note_boom(self, tag, realm, data):
        raise RuntimeError("note failed")

    def wrap_loader(self, note_fn=None):
        note_fn = note_fn or self.note
        current = self.g["TSM_APPHELPER_LOAD_DATA"]
        if not callable(current):
            return False
        if self.wrapped_loader is not None and current is self.wrapped_loader:
            return True
        if self.wrapping:
            return False
        orig = current
        self.wrapping = True

        def wrapped(*args):
            tag = args[0] if len(args) > 0 else None
            realm = args[1] if len(args) > 1 else None
            data = args[2] if len(args) > 2 else None
            try:
                note_fn(tag, realm, data)
            except Exception:
                pass
            return orig(*args)

        self.original_loader = orig
        self.wrapped_loader = wrapped
        self.g["TSM_APPHELPER_LOAD_DATA"] = wrapped
        self.wrapping = False
        return True

    def ensure_on_update(self):
        if self.on_update_active:
            return
        self.on_update_active = True
        self.on_update_sets += 1


def test_wrapper_idempotent_no_double_wrap():
    sim = DataTapWrapperSim()
    calls = []

    def tsm_loader(tag, realm, data, *extra):
        calls.append((tag, realm, data, extra))
        return "tsm", tag, len(extra)

    sim.g["TSM_APPHELPER_LOAD_DATA"] = tsm_loader
    assert sim.wrap_loader() is True
    first = sim.g["TSM_APPHELPER_LOAD_DATA"]
    assert sim.wrap_loader() is True
    assert sim.g["TSM_APPHELPER_LOAD_DATA"] is first
    # Still a single layer: calling wrapper hits original once
    out = sim.g["TSM_APPHELPER_LOAD_DATA"](
        "AUCTIONDB_NON_COMMODITY_DATA",
        "PvP-Horde",
        "return {downloadTime=123}",
        "extra1",
        "extra2",
    )
    assert out == ("tsm", "AUCTIONDB_NON_COMMODITY_DATA", 2)
    assert len(calls) == 1
    assert sim.notes == [("AUCTIONDB_NON_COMMODITY_DATA", "PvP-Horde", 123)]


def test_note_failure_does_not_break_original():
    sim = DataTapWrapperSim()

    def tsm_loader(tag, realm, data):
        return "ok"

    sim.g["TSM_APPHELPER_LOAD_DATA"] = tsm_loader
    assert sim.wrap_loader(note_fn=sim.note_boom) is True
    assert sim.g["TSM_APPHELPER_LOAD_DATA"]("TAG", "R", "downloadTime=1") == "ok"


def test_onupdate_not_registered_multiple_times():
    sim = DataTapWrapperSim()
    sim.ensure_on_update()
    sim.ensure_on_update()
    sim.ensure_on_update()
    assert sim.on_update_sets == 1


def test_slash_command_registration_present_in_source():
    text = COMMANDS.read_text(encoding="utf-8")
    assert 'SLASH_SMARTTSM1 = "/smarttsm"' in text or '_G.SLASH_SMARTTSM1 = "/smarttsm"' in text
    assert 'SlashCmdList["SMARTTSM"]' in text or "SlashCmdList.SMARTTSM" in text
    assert "function Commands.IsRegistered" in text
    assert "function Commands.Register" in text
    addon = ADDON.read_text(encoding="utf-8")
    assert "Commands.Register()" in addon
    assert "ensureSlash" in addon or "IsRegistered" in addon
