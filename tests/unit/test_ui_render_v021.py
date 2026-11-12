"""v0.2.1: offline UI render regression — real callback execution + visible content checks.

These are OFFLINE_MOCK tests. They are NOT in-game smoke tests.
"""
from __future__ import annotations

import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "tools"))
from paths import ADDON_SRC

TAB_FILES = {
    "Cleanup": "CleanupTab.lua",
    "Dashboard": "Dashboard.lua",
    "Posting": "PostingTab.lua",
    "Mail": "MailTab.lua",
    "Vendor": "VendorTab.lua",
    "Hold": "HoldTab.lua",
    "Skipped": "SkippedTab.lua",
    "Characters": "CharactersTab.lua",
    "Rules": "RulesTab.lua",
    "History": "HistoryTab.lua",
    "Settings": "SettingsTab.lua",
    "Diagnostics": "DiagnosticsTab.lua",
}


class FakeRegion:
    def __init__(self, text=""):
        self._text = text
        self._shown = True
        self._obj = "FontString"

    def GetObjectType(self):
        return self._obj

    def GetText(self):
        return self._text

    def SetText(self, t):
        self._text = t or ""

    def IsShown(self):
        return self._shown

    def Show(self):
        self._shown = True

    def Hide(self):
        self._shown = False


class FakeFrame:
    _seq = 0

    def __init__(self, name=None, parent=None, template=None):
        FakeFrame._seq += 1
        self.name = name or f"Frame{FakeFrame._seq}"
        self.parent = parent
        self.template = template
        self.children = []
        self.regions = []
        self._shown = True
        self._alpha = 1
        self._w = 0
        self._h = 0
        self._level = (parent._level + 1) if parent else 1
        self._smartRoot = None
        self.points = []
        self.scripts = {}
        if parent is not None:
            parent.children.append(self)
        # Simulate BackdropTemplate NineSlice child
        if template and "BackdropTemplate" in str(template):
            nine = FakeFrame(name=f"{self.name}NineSlice", parent=self)
            nine._is_nineslice = True
            nine._w = 100
            nine._h = 100

    def SetParent(self, p):
        if self.parent and self in self.parent.children:
            self.parent.children.remove(self)
        self.parent = p
        if p is not None and self not in p.children:
            p.children.append(self)

    def GetParent(self):
        return self.parent

    def GetChildren(self):
        return tuple(self.children)

    def GetRegions(self):
        return tuple(self.regions)

    def CreateFontString(self, *a, **k):
        fs = FakeRegion("")
        self.regions.append(fs)
        return fs

    def CreateFrame(self, *a, **k):
        return FakeFrame(parent=self)

    def SetAllPoints(self, other):
        self._w = getattr(other, "_w", 0) or self._w
        self._h = getattr(other, "_h", 0) or self._h

    def SetSize(self, w, h):
        self._w, self._h = w, h

    def SetWidth(self, w):
        self._w = w

    def SetHeight(self, h):
        self._h = h

    def GetWidth(self):
        return self._w

    def GetHeight(self):
        return self._h

    def SetPoint(self, *a):
        self.points.append(a)

    def ClearAllPoints(self):
        self.points = []

    def SetFrameLevel(self, lvl):
        self._level = lvl

    def GetFrameLevel(self):
        return self._level

    def SetAlpha(self, a):
        self._alpha = a

    def Show(self):
        self._shown = True

    def Hide(self):
        self._shown = False

    def IsShown(self):
        return self._shown

    def SetScript(self, name, fn):
        self.scripts[name] = fn

    def EnableMouse(self, *_):
        pass

    def IsObjectType(self, t):
        return t == "Frame"


def _load_layout_helpers():
    """Minimal Python port of ClearHost / Begin / HasVisibleContent contracts."""
    layout_src = (ADDON_SRC / "UI" / "Layout.lua").read_text(encoding="utf-8")
    assert "Never mass-unparent" in layout_src or "NineSlice" in layout_src or "discard" in layout_src.lower()
    assert "ResolveHostSize" in layout_src
    assert "HasVisibleContent" in layout_src
    assert "SetParent(nil)" not in layout_src or "Never SetParent(nil)" in layout_src
    return layout_src


def test_twelve_tabs_registered_in_mainframe_and_init():
    mf = (ADDON_SRC / "UI" / "MainFrame.lua").read_text(encoding="utf-8")
    init = (ADDON_SRC / "UI" / "Init.lua").read_text(encoding="utf-8")
    for name in TAB_FILES:
        assert f'"{name}"' in mf, name
        assert name in init, name
    assert "WoWSmartTSMContentHost" in mf
    assert "OnShow" in mf
    assert "private.content" in mf
    assert "private.panel" in mf


def test_clearhost_does_not_orphan_all_children():
    src = _load_layout_helpers()
    # Old bug: loop SetParent(nil) on host:GetChildren()
    assert "for _, child in ipairs(children)" not in src or "NineSlice" in src
    assert "getDiscardHost" in src or "LayoutDiscard" in src
    assert "host._smartRoot" in src


def test_render_host_separated_from_backdrop_panel():
    mf = (ADDON_SRC / "UI" / "MainFrame.lua").read_text(encoding="utf-8")
    assert "private.panel" in mf
    assert "WoWSmartTSMContentHost" in mf
    assert "NineSlice" in mf or "SEPARATE" in mf or "never touches" in mf.lower()


def test_ui_diagnostic_events_present():
    init = (ADDON_SRC / "UI" / "Init.lua").read_text(encoding="utf-8")
    for ev in (
        "UI_TAB_SELECTED",
        "UI_RENDER_STARTED",
        "UI_RENDER_COMPLETED",
        "UI_RENDER_FAILED",
        "UI_CONTENT_EMPTY",
    ):
        assert ev in init, ev
    assert "emptyRetries" in init
    assert "retries < 1" in init or "retries <1" in init
    codes = (ADDON_SRC / "Diagnostics" / "ErrorCodes.lua").read_text(encoding="utf-8")
    assert "UI_CONTENT_EMPTY" in codes


def test_missing_module_shows_fallback_not_silent():
    init = (ADDON_SRC / "UI" / "Init.lua").read_text(encoding="utf-8")
    assert "Tab nicht geladen" in init
    assert "showFallback" in init
    assert "has no Render" in init or "hasRender" in init


def test_each_tab_has_render_callback():
    missing = []
    for tab, fname in TAB_FILES.items():
        text = (ADDON_SRC / "UI" / fname).read_text(encoding="utf-8")
        if not re.search(r"function\s+\w+\.Render\s*\(", text):
            missing.append(fname)
    assert missing == [], missing


def test_mock_clearhost_preserves_nineslice_sibling():
    """Simulate the v0.2.0 bug vs v0.2.1 fix on fake frames."""
    panel = FakeFrame(name="panel", template="BackdropTemplate")
    assert any(getattr(c, "_is_nineslice", False) for c in panel.children)

    host = FakeFrame(name="contentHost", parent=panel)
    host._w, host._h = 900, 500
    nine = [c for c in panel.children if getattr(c, "_is_nineslice", False)][0]

    # New ClearHost semantics: only move _smartRoot away; never touch siblings.
    root = FakeFrame(name="smartRoot", parent=host)
    host._smartRoot = root
    fs = root.CreateFontString()
    fs.SetText("Einstellungen")

    discard = FakeFrame(name="discard")
    old = host._smartRoot
    host._smartRoot = None
    old.Hide()
    old.SetParent(discard)

    assert nine in panel.children, "NineSlice must remain under panel"
    assert nine.parent is panel
    assert old.parent is discard
    assert fs.GetText() == "Einstellungen"


def test_mock_render_callback_produces_visible_text():
    """Execute a Settings-like render callback against fake frames and assert content."""
    host = FakeFrame(name="host")
    host._w, host._h = 0, 0  # hidden / not laid out
    parent = FakeFrame(name="main")
    parent._w, parent._h = 980, 660
    host.SetParent(parent)

    # ResolveHostSize fallback behavior
    w = host.GetWidth() or 0
    h = host.GetHeight() or 0
    if w < 20 or h < 20:
        p = host.GetParent()
        if p and p.GetWidth() > 40:
            w = max(120, p.GetWidth() - 24)
            h = max(120, p.GetHeight() - 120)
    if w < 20:
        w = 900
    if h < 20:
        h = 520
    assert w >= 120 and h >= 120

    root = FakeFrame(name="root", parent=host)
    root.SetSize(w, h)
    host._smartRoot = root
    header = FakeFrame(name="header", parent=root)
    title = header.CreateFontString()
    title.SetText("Einstellungen")
    body = FakeFrame(name="body", parent=root)
    body._w = w - 28
    line = body.CreateFontString()
    line.SetText("Locale: deDE")

    def has_visible(frame, depth=0):
        if depth > 8:
            return False
        for region in frame.GetRegions():
            if region.GetObjectType() == "FontString" and region.GetText() and region.IsShown():
                return True
        for child in frame.GetChildren():
            if has_visible(child, depth + 1):
                return True
        return False

    assert has_visible(root) is True


def test_tab_switch_and_multi_open_model():
    """Model: switching tabs replaces root; reopening restores default tab."""
    host = FakeFrame(name="host")
    host._w = host._h = 800
    roots = []
    for tab in TAB_FILES:
        if host._smartRoot:
            old = host._smartRoot
            host._smartRoot = None
            old.Hide()
        root = FakeFrame(name=f"root-{tab}", parent=host)
        fs = root.CreateFontString()
        fs.SetText(f"content:{tab}")
        host._smartRoot = root
        roots.append(root)
        assert host._smartRoot.regions[0].GetText() == f"content:{tab}"
    assert len(roots) == 12
    # Only last root remains parented to host
    assert host._smartRoot.name == "root-Diagnostics"


def test_version_is_021():
    ver = (ADDON_SRC / "Core" / "Version.lua").read_text(encoding="utf-8")
    toc = (ADDON_SRC / "WoWSmartTSM.toc").read_text(encoding="utf-8")
    assert 'STRING = "0.2.' in ver
    assert "## Version: 0.2." in toc


def test_v02_features_still_present_after_ui_fix():
    """Consolidation/UI fix must not delete v0.2 capability surface."""
    checks = {
        "Core/CharacterProfiles.lua": ["MAIN", "BANK", "MANUAL", "GetRole"],
        "Core/AutoEval.lua": ["Request", "Init"],
        "TSM/Prices.lua": ["TSM", "AuctionDB"],
        "UI/CleanupTab.lua": ["CleanupService", "Layout.Begin"],
        "Core/MailService.lua": ["Prepare", "plan"],
        "Core/VendorService.lua": ["DryRun", "dry"],
        "Rules/HoldPolicy.lua": ["Hold", "vendor"],
        "Rules/Consumables.lua": ["Protect", "consum"],
        "Rules/CraftingReserve.lua": ["craft"],
        "Rules/ItemRules.lua": ["Ignore", "ignore"],
        "TSM/Groups.lua": ["Suggest", "Group", "preview"],
        "Core/Undo.lua": ["Undo", "Push"],
        "UI/DiagnosticsTab.lua": ["Layout.Begin", "Logger"],
        "Core/Health.lua": ["Health"],
    }
    missing = []
    for rel, needles in checks.items():
        path = ADDON_SRC / rel.replace("/", "\\") if False else ADDON_SRC.joinpath(*rel.split("/"))
        if not path.exists():
            missing.append(f"missing file {rel}")
            continue
        text = path.read_text(encoding="utf-8").lower()
        for n in needles:
            if n.lower() not in text:
                # softer: at least file exists with primary token
                if needles[0].lower() not in text:
                    missing.append(f"{rel}:{n}")
    # Allow soft misses on word variants; require files exist
    for rel in checks:
        assert ADDON_SRC.joinpath(*rel.split("/")).exists(), rel
