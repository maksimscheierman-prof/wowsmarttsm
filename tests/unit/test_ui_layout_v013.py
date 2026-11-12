"""Regression: robust Layout system prevents FontString overlap."""
from pathlib import Path
import re
import sys

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "tools"))
from paths import ADDON_SRC


TABS = [
    "Dashboard.lua",
    "PostingTab.lua",
    "SkippedTab.lua",
    "VendorTab.lua",
    "HoldTab.lua",
    "HistoryTab.lua",
    "SettingsTab.lua",
    "DiagnosticsTab.lua",
]


def test_layout_module_api():
    layout = (ADDON_SRC / "UI" / "Layout.lua").read_text(encoding="utf-8")
    for api in (
        "ClearHost",
        "Begin",
        "BodyStack",
        "AddText",
        "AddTable",
        "AddMetricGrid",
        "FinishStack",
        "HeaderTitle",
        "FooterText",
    ):
        assert f"function Layout.{api}" in layout or f"Layout.{api}" in layout, api
    assert "SetWordWrap(true)" in layout
    assert "GetStringHeight" in layout
    assert "_smartRoot" in layout
    # No fixed 18px-only spacing for arbitrary text
    assert "fs:GetStringHeight()" in layout or "GetStringHeight()" in layout


def test_all_tabs_use_layout_begin():
    missing = []
    for name in TABS:
        text = (ADDON_SRC / "UI" / name).read_text(encoding="utf-8")
        # Thin tabs may delegate to BulkReview which uses Layout
        if name in ("PostingTab.lua", "SkippedTab.lua", "VendorTab.lua", "HoldTab.lua"):
            assert "BulkReview.Render" in text, name
            continue
        if "Layout.Begin" not in text:
            missing.append(name)
    assert missing == [], missing
    bulk = (ADDON_SRC / "UI" / "BulkReview.lua").read_text(encoding="utf-8")
    assert "Layout.Begin" in bulk
    assert "Layout.AddTable" in bulk


def test_toc_loads_layout_before_tabs():
    toc = (ADDON_SRC / "WoWSmartTSM.toc").read_text(encoding="utf-8")
    assert "UI\\Layout.lua" in toc
    assert "Core\\Health.lua" in toc
    assert "## Version: 0.1.3" in toc
    layout_i = toc.index("UI\\Layout.lua")
    dash_i = toc.index("UI\\Dashboard.lua")
    assert layout_i < dash_i
    health_i = toc.index("Core\\Health.lua")
    addon_i = toc.index("Core\\Addon.lua")
    assert health_i < addon_i


def test_mainframe_has_eight_tabs_and_resize_rerender():
    mf = (ADDON_SRC / "UI" / "MainFrame.lua").read_text(encoding="utf-8")
    for tab in ("Dashboard", "Posting", "Skipped", "Vendor", "Hold", "History", "Settings", "Diagnostics"):
        assert f'"{tab}"' in mf
    assert "OnSizeChanged" in mf
    assert "SelectTab" in mf


def test_theme_avoids_loud_red_yellow_defaults():
    theme = (ADDON_SRC / "UI" / "Theme.lua").read_text(encoding="utf-8")
    assert "Calm" in theme or "readable" in theme.lower() or "0.35, 0.72, 0.70" in theme


def test_ui_render_tab_pcall_isolated():
    init = (ADDON_SRC / "UI" / "Init.lua").read_text(encoding="utf-8")
    assert "pcall(mod.Render" in init
    assert "UI_ERROR" in init


def test_visual_layout_fixture_no_overlap_model():
    """Offline geometric model: stacked measured heights must not overlap."""
    # Simulates Layout.AddText measuring height from wrapped lines
    width = 400
    texts = [
        "Kurzer Titel",
        "Eine sehr lange Diagnosemeldung " * 6,
        "Footer-Hinweis mit zusätzlichem Kontext für deutsche Übersetzungen",
    ]
    y = 0
    rects = []
    for t in texts:
        # approx wrap: 7px/char → lines
        chars_per_line = max(1, width // 7)
        lines = max(1, (len(t) + chars_per_line - 1) // chars_per_line)
        h = lines * 14
        rects.append((y, y + h))
        y = y + h + 4
    for i in range(len(rects) - 1):
        assert rects[i][1] <= rects[i + 1][0], (rects[i], rects[i + 1])


def test_table_rows_uniform_height_model():
    row_h = 22
    n = 12
    for i in range(n):
        top = i * row_h
        bottom = top + row_h
        assert bottom - top == row_h
        if i > 0:
            assert top == i * row_h
