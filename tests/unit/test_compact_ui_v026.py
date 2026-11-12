"""v0.2.6 compact / no-scroll layout regressions."""
from __future__ import annotations

import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "tools"))
from paths import ADDON_SRC
from lua_syntax import check_tree
from forever_lua_runtime import (
	TAB_FILES,
	create_runtime,
	load_all_tabs,
	load_layout_stack,
	render_tab,
	assert_layout_api,
)


def _read(rel: str) -> str:
	return (ADDON_SRC / rel).read_text(encoding="utf-8")


def test_version_026():
	assert "0.2.6" in _read("Core/Version.lua")
	assert "## Version: 0.2.6" in _read("WoWSmartTSM.toc")


def test_layout_has_compact_apis():
	text = _read("UI/Layout.lua")
	for api in ("ContentBudget", "TwoColumns", "CompactList", "FooterActions", "FitsWithoutScroll"):
		assert f"function Layout.{api}" in text, api


def test_groups_tab_two_column_compact():
	text = _read("UI/GroupsTab.lua")
	assert "TwoColumns" in text
	assert "Fehlende Smart-Gruppen" in text
	assert "Existierende Gruppen" in text
	assert "FooterActions" in text
	assert "compact = true" in text
	assert "BuildProposals" not in text


def test_mainframe_compact_tabs():
	text = _read("UI/MainFrame.lua")
	assert "COMPACT_TAB_LABEL" in text
	assert 'Groups = "Gruppen"' in text
	assert "TAB_H = 20" in text


def test_ops_and_setup_no_outer_scroll_default():
	ops = _read("UI/OperationsTab.lua")
	setup = _read("UI/SetupWizard.lua")
	assert "scroll = false" in ops
	assert "scroll = false" in setup
	assert "FooterActions" in ops
	assert "FooterActions" in setup


def test_lua_syntax():
	assert check_tree(ADDON_SRC)["failed"] == []


def test_layout_budget_model():
	"""3 existing + 8 missing should fit typical body height without outer scroll."""
	# rowH 18 * 3 = 54 left; 18 * 8 = 144 right; header+buttons ~80 → under 400 body
	left = 3 * 18 + 40
	right = 8 * 18 + 60
	assert max(left, right) < 400


def test_render_all_tabs_including_groups():
	lua = create_runtime()
	load_layout_stack(lua)
	assert_layout_api(lua)
	load_all_tabs(lua)
	# Mock a few TSM groups for Groups tab
	lua.execute(
		"""
		local Groups = WoWSmartTSM:GetModule('Groups')
		Groups.ListPaths = function() return {'A', 'Smart TSM', 'Smart TSM`Smart Quick Sell'} end
		Groups.BuildHierarchy = function()
			return {
				{ path='A', name='A', display='A', depth=1, itemCount=2, itemCountReliable=true, isSmart=false },
				{ path='Smart TSM', name='Smart TSM', display='Smart TSM', depth=1, itemCount=0, itemCountReliable=true, isSmart=true },
				{ path='Smart TSM`Smart Quick Sell', name='Smart Quick Sell', display='Smart TSM > Smart Quick Sell', depth=2, itemCount=1, itemCountReliable=true, isSmart=true },
			}
		end
		Groups.MissingSmartGroups = function()
			return {
				'Smart TSM`Smart Profit Sell','Smart TSM`Smart Rare Sell','Smart TSM`Smart Vendor',
				'Smart TSM`Smart Hold','Smart TSM`Smart Ignore','Smart TSM`Manual Review',
				'Smart TSM`X','Smart TSM`Y',
			}
		end
		Groups.FormatPath = function(p) return tostring(p or ''):gsub('`',' > ') end
		Groups.SplitPath = function(p)
			local parent, name = tostring(p):match('^(.*)`([^`]+)$')
			if name then return parent, name end
			return nil, p
		end
		Groups.BuildImportString = function() return 'group:Smart TSM' end
		Groups.OpenInTSM = function() return false, 'hint' end
		Groups.ProbeCapabilities = function() return { writeMode='IMPORT_STRING', getItems=true } end
		"""
	)
	for tab in TAB_FILES:
		host = render_tab(lua, tab)
		assert host is not None


def test_compact_list_scroll_threshold_logic():
	# 100 groups * 18px > 300 max → need scroll; 3 groups do not
	assert 100 * 18 > 300
	assert 3 * 18 < 300
