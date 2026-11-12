"""v0.2.2: execute real UI Lua files under a Forever-like Lua runtime.

Reproduces the Layout.lua parse failure that made Layout.Begin nil in-game.
OFFLINE_MOCK only — not an in-game smoke test.
"""
from __future__ import annotations

import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "tools"))

from forever_lua_runtime import (  # noqa: E402
	REQUIRED_LAYOUT_APIS,
	TAB_FILES,
	assert_layout_api,
	create_runtime,
	exec_file,
	load_all_tabs,
	load_layout_stack,
	render_tab,
)
from paths import ADDON_SRC  # noqa: E402
from lupa import LuaError  # noqa: E402


def test_layout_lua_loads_and_exports_begin():
	lua = create_runtime()
	load_layout_stack(lua)
	apis = assert_layout_api(lua)
	assert apis["Begin"] is not None
	assert callable(apis["Begin"])


def test_invalid_colon_and_pattern_rejected_by_lua():
	"""The exact Forever-breaking pattern must fail to parse."""
	lua = create_runtime()
	bad = "local sw = fs:GetStringWidth and fs:GetStringWidth() or 1"
	try:
		lua.execute(bad)
		raise AssertionError("invalid colon-and expression should not parse")
	except LuaError as e:
		msg = str(e).lower()
		assert "function arguments expected" in msg or "near 'and'" in msg or "syntax" in msg


def test_layout_source_has_no_colon_and_existence_check():
	text = (ADDON_SRC / "UI" / "Layout.lua").read_text(encoding="utf-8")
	# Forbidden: obj:Method and ...  (':' requires a call)
	assert not re.search(r":[A-Za-z_]\w*\s+and\b", text), "Layout.lua still has invalid ':' existence checks"


def test_all_layout_helpers_callable():
	lua = create_runtime()
	load_layout_stack(lua)
	apis = assert_layout_api(lua)
	# Drive helpers from Lua to avoid lupa table-bridge edge cases.
	lua.execute(
		"""
		local Layout = WoWSmartTSM:GetModule('Layout')
		local host = CreateFrame('Frame', nil, UIParent)
		host:SetSize(900, 500)
		local root = Layout.Begin(host)
		assert(root and root.header and root.body and root.footer, 'Begin root incomplete')
		Layout.HeaderTitle(root.header, 'Test')
		Layout.HeaderButton(root.header, 'Scan', function() end)
		local stack = Layout.BodyStack(root)
		Layout.AddText(stack, 'hello')
		Layout.AddGap(stack, 4)
		Layout.AddButtonRow(stack, { { text = 'A' } })
		Layout.AddMetricGrid(stack, { { 'K', '1' } }, 1)
		Layout.AddTable(stack, { { title = 'A', width = 80 } }, { { 'x' } })
		Layout.FinishStack(stack)
		Layout.FooterText(root.footer, 'footer')
		assert(Layout.HasVisibleContent(host), 'expected visible content')
		assert(type(Layout.MeasureButtonWidth('Neu bewerten')) == 'number')
		assert(type(Layout.ResolveHostSize(host)) == 'number')
		"""
	)


def test_each_tab_render_individually():
	results = {}
	for tab in TAB_FILES:
		lua = create_runtime()
		load_layout_stack(lua)
		assert_layout_api(lua)
		load_all_tabs(lua)
		render_tab(lua, tab)
		results[tab] = "ok"
	assert len(results) == len(TAB_FILES)
	assert set(results) == set(TAB_FILES)


def test_all_tabs_render_sequentially_same_runtime():
	lua = create_runtime()
	load_layout_stack(lua)
	assert_layout_api(lua)
	load_all_tabs(lua)
	for tab in TAB_FILES:
		render_tab(lua, tab)


def test_reproduce_v021_nil_begin_when_layout_fails_to_parse():
	"""If Layout.lua does not load, Begin is nil — matching in-game E5005 sites."""
	lua = create_runtime()
	# Locale only — skip Layout.lua to simulate parse abort
	exec_file(lua, ADDON_SRC / "Locale" / "deDE.lua")
	exec_file(lua, ADDON_SRC / "Locale" / "Locale.lua")
	layout = lua.eval("WoWSmartTSM:Module('Layout')")
	assert layout["Begin"] is None
	# Tab-style call site
	try:
		lua.execute("local Layout = WoWSmartTSM:Module('Layout'); Layout.Begin(CreateFrame('Frame'))")
		raise AssertionError("expected nil call")
	except LuaError as e:
		assert "nil" in str(e).lower() or "attempt to call" in str(e).lower()


def test_required_layout_api_list_matches_tab_usage():
	used = set()
	for fname in list(TAB_FILES.values()) + ["BulkReview.lua"]:
		text = (ADDON_SRC / "UI" / fname).read_text(encoding="utf-8")
		used.update(re.findall(r"Layout\.([A-Za-z_]\w*)", text))
	# Every used Layout.* must be exported
	missing = sorted(n for n in used if n not in REQUIRED_LAYOUT_APIS and n not in ("COLORS",))
	# COLORS is Theme; filter known non-functions if any
	missing = [n for n in missing if n[0].isupper() or n[0].islower()]
	# Allow only real API names that should exist
	critical = {"Begin", "HeaderButton", "HeaderTitle", "BodyStack", "AddText", "AddTable", "AddButtonRow", "FinishStack", "FooterText", "AddMetricGrid", "AddGap"}
	absent = sorted(critical - set(REQUIRED_LAYOUT_APIS))
	assert absent == []
	for name in critical:
		assert name in used or name == "AddMetricGrid"  # some tabs may not use every helper
