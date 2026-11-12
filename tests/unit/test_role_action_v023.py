"""v0.2.3: MAIN/BANK inventory actions + CharacterResolver (real Lua).

OFFLINE_MOCK — not an in-game smoke test.
"""
from __future__ import annotations

import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "tools"))

from forever_lua_runtime import (  # noqa: E402
	create_runtime,
	exec_file,
	load_core_decision_stack,
	load_layout_stack,
	load_all_tabs,
	render_tab,
)
from paths import ADDON_SRC  # noqa: E402


def _setup(role: str, bank_key: str | None, current_key: str | None = None):
	lua = create_runtime()
	load_layout_stack(lua)
	load_core_decision_stack(lua)
	# Override live identity if needed
	if current_key:
		# current_key = Name-Realm|Faction
		name_realm, faction = current_key.split("|", 1)
		name, realm = name_realm.split("-", 1)
		lua.execute(
			f"""
			function UnitName() return '{name}' end
			function GetRealmName() return '{realm}' end
			function UnitFactionGroup() return '{faction}' end
			"""
		)
		# Reload resolver after identity change
		exec_file(lua, ADDON_SRC / "Core" / "CharacterResolver.lua")
		exec_file(lua, ADDON_SRC / "Core" / "CharacterProfiles.lua")
		exec_file(lua, ADDON_SRC / "Rules" / "ActionDecide.lua")

	lua.execute(
		f"""
		local CP = WoWSmartTSM:GetModule('CharacterProfiles')
		local Resolver = WoWSmartTSM:GetModule('CharacterResolver')
		CP.EnsureCurrent()
		local key = CP.GetCurrentKey()
		CP.SetRole(key, '{role}')
		"""
	)
	if bank_key is None:
		lua.execute(
			"""
			local CP = WoWSmartTSM:GetModule('CharacterProfiles')
			CP.SetPrimaryBankKey(nil)
			"""
		)
	else:
		lua.execute(
			f"""
			local CP = WoWSmartTSM:GetModule('CharacterProfiles')
			CP.SetPrimaryBankKey('{bank_key}')
			"""
		)
	# Avoid reeval side effects from Notify during setup — clear is fine
	return lua


def _decide(lua, strategy: str, qty: int = 1):
	lua.execute(
		f"""
		local ActionDecide = WoWSmartTSM:GetModule('ActionDecide')
		local C = WoWSmartTSM:GetModule('Constants')
		_G.__lastDecision = ActionDecide.Assign({{
			strategy = '{strategy}',
			quantity = {qty},
			confidence = 0.8,
			itemId = 10940,
			name = 'Strange Dust',
			itemString = 'i:10940',
			marketValue = 50000,
			vendorSell = 100,
			pricing = {{}},
		}}, {{
			quantity = {qty},
			itemString = 'i:10940',
			itemId = 10940,
		}})
		"""
	)
	return lua.eval("_G.__lastDecision")


def test_constants_have_post_ah_and_hold():
	text = (ADDON_SRC / "Core" / "Constants.lua").read_text(encoding="utf-8")
	assert "POST_AH" in text
	assert 'HOLD = "HOLD"' in text or "HOLD =" in text


def test_main_with_bank_mails_rentable():
	lua = _setup("MAIN", "Banko-CAMWOW EU4 Realm 6 PvP|Horde", "Azamat-CAMWOW EU4 Realm 6 PvP|Horde")
	d = _decide(lua, "QUICK_SELL")
	assert d["inventoryAction"] == "MAIL_TO_BANK"
	assert d["needsBankConfig"] is False or d["needsBankConfig"] == False


def test_main_without_bank_blocks_only_mail():
	lua = _setup("MAIN", None, "Azamat-CAMWOW EU4 Realm 6 PvP|Horde")
	d = _decide(lua, "PROFIT_SELL")
	assert d["inventoryAction"] == "MANUAL_REVIEW"
	reasons = lua.eval(
		"{(function() local t={} for i,v in ipairs(_G.__lastDecision.actionReasons or {}) do t[i]=v end return t end)()}"
	)
	# Simpler: ask Lua
	has = lua.eval(
		"(function() for _,v in ipairs(_G.__lastDecision.actionReasons or {}) do if v=='BANK_CHARACTER_NOT_CONFIGURED' then return true end end return false end)()"
	)
	assert has is True


def test_bank_self_as_primary_posts_ah_never_mails():
	key = "Banko-CAMWOW EU4 Realm 6 PvP|Horde"
	lua = _setup("BANK", key, key)
	d = _decide(lua, "RARE_SELL")
	assert d["inventoryAction"] == "POST_AH"
	assert d["inventoryAction"] != "MAIL_TO_BANK"
	assert d["inventoryAction"] != "HOLD_AT_BANK"
	role = lua.eval("(function() local r = WoWSmartTSM:GetModule('CharacterProfiles').GetRole(); return r end)()")
	assert role == "BANK"


def test_bank_without_bank_config_still_posts():
	"""POST_AH must not require a mail recipient."""
	lua = _setup("BANK", None, "Banko-CAMWOW EU4 Realm 6 PvP|Horde")
	# Force stored role BANK even without primary key
	lua.execute(
		"""
		local CP = WoWSmartTSM:GetModule('CharacterProfiles')
		CP.SetRole(CP.GetCurrentKey(), 'BANK')
		local Resolver = WoWSmartTSM:GetModule('CharacterResolver')
		Resolver.Invalidate()
		"""
	)
	d = _decide(lua, "QUICK_SELL")
	assert d["inventoryAction"] == "POST_AH"


def test_bank_hold_and_vendor():
	key = "Banko-CAMWOW EU4 Realm 6 PvP|Horde"
	lua = _setup("BANK", key, key)
	d_hold = _decide(lua, "HOLD")
	assert d_hold["inventoryAction"] == "HOLD"
	d_vendor = _decide(lua, "VENDOR")
	assert d_vendor["inventoryAction"] == "VENDOR"


def test_primary_bank_login_forces_effective_bank_role():
	"""Even if stored role drifted to MAIN, primary bank login acts as BANK."""
	key = "Banko-CAMWOW EU4 Realm 6 PvP|Horde"
	lua = _setup("BANK", key, key)
	# Drift stored role back to MAIN after bank assignment
	lua.execute(
		"""
		local CP = WoWSmartTSM:GetModule('CharacterProfiles')
		local db = WoWSmartTSM_DB
		db.characters[CP.GetCurrentKey()].role = 'MAIN'
		WoWSmartTSM:GetModule('CharacterResolver').Invalidate()
		"""
	)
	role = lua.eval("(function() local r = WoWSmartTSM:GetModule('CharacterResolver').GetEffectiveRole(); return r end)()")
	assert role == "BANK"
	d = _decide(lua, "QUICK_SELL")
	assert d["inventoryAction"] == "POST_AH"


def test_manual_role_disables_automation():
	lua = _setup("MANUAL", "Banko-CAMWOW EU4 Realm 6 PvP|Horde", "Alt-CAMWOW EU4 Realm 6 PvP|Horde")
	d = _decide(lua, "QUICK_SELL")
	assert d["automationAllowed"] is False or d["automationAllowed"] == False


def test_key_normalization_collapses_spaces():
	lua = create_runtime()
	load_core_decision_stack(lua)
	a = lua.eval("WoWSmartTSM:GetModule('CharacterResolver').NormalizeKey('Banko-CAMWOW  EU4 Realm 6 PvP|Horde')")
	b = lua.eval("WoWSmartTSM:GetModule('CharacterResolver').NormalizeKey('Banko-CAMWOW EU4 Realm 6 PvP|Horde')")
	assert a == b


def test_aggregate_stacks():
	lua = create_runtime()
	load_core_decision_stack(lua)
	lua.execute(
		"""
		local CS = WoWSmartTSM:GetModule('CleanupService')
		local rows = {
			{ itemString='i:10940', name='Strange Dust', quantity=20, actionQty=20, inventoryAction='POST_AH', strategy='QUICK_SELL', bag=0, slot=1 },
			{ itemString='i:10940', name='Strange Dust', quantity=20, actionQty=20, inventoryAction='POST_AH', strategy='QUICK_SELL', bag=0, slot=2 },
			{ itemString='i:10940', name='Strange Dust', quantity=5, actionQty=5, inventoryAction='POST_AH', strategy='QUICK_SELL', bag=1, slot=1 },
		}
		_G.__agg = CS.Aggregate(rows)
		"""
	)
	agg = lua.eval("_G.__agg")
	assert len(list(agg.values())) == 1 or len(agg) == 1
	# lupa tables: count via lua
	n = lua.eval("#_G.__agg")
	assert n == 1
	qty = lua.eval("_G.__agg[1].actionQty")
	assert qty == 45
	stacks = lua.eval("#_G.__agg[1].stacks")
	assert stacks == 3


def test_human_reasons():
	lua = create_runtime()
	load_layout_stack(lua)
	load_core_decision_stack(lua)
	lua.execute(
		"""
		local E = WoWSmartTSM:GetModule('ItemExplain')
		local human = E.HumanReason({ inventoryAction='POST_AH', actionReasons={'BANK_READY_TO_POST'} })
		assert(human:find('Auktionshaus') or human:find('vorbereiten'), human)
		human = E.HumanReason({ inventoryAction='MANUAL_REVIEW', actionReasons={'BANK_CHARACTER_NOT_CONFIGURED'}, needsBankConfig=true })
		assert(human:find('Bankcharakter'), human)
		"""
	)


def test_cleanup_tab_renders_for_bank_and_main():
	for role, bank, cur in (
		("MAIN", "Banko-CAMWOW EU4 Realm 6 PvP|Horde", "Azamat-CAMWOW EU4 Realm 6 PvP|Horde"),
		("BANK", "Banko-CAMWOW EU4 Realm 6 PvP|Horde", "Banko-CAMWOW EU4 Realm 6 PvP|Horde"),
	):
		lua = _setup(role, bank, cur)
		load_layout_stack(lua)
		# ItemExplain/Context already via load_core; load cleanup deps
		exec_file(lua, ADDON_SRC / "UI" / "ItemContextMenu.lua")
		exec_file(lua, ADDON_SRC / "UI" / "CleanupTab.lua")
		host = lua.eval("CreateFrame('Frame', 'Host', UIParent)")
		host["_w"] = 900
		host["_h"] = 600
		render = lua.eval("WoWSmartTSM:GetModule('CleanupTab').Render")
		render(host)


def test_toc_loads_resolver_before_profiles():
	toc = (ADDON_SRC / "WoWSmartTSM.toc").read_text(encoding="utf-8")
	assert "Core\\CharacterResolver.lua" in toc
	assert toc.index("CharacterResolver.lua") < toc.index("CharacterProfiles.lua")
	assert "UI\\ItemExplain.lua" in toc
	assert "UI\\ItemContextMenu.lua" in toc
	assert "## Version: 0.2." in toc
	assert "0.2.5" in toc or "0.2.4" in toc or "0.2.3" in toc
