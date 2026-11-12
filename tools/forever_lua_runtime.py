"""Minimal Forever/WoW Lua runtime for offline execution of addon UI files.

Uses lupa (Lua 5.x). This is OFFLINE_MOCK — not an in-game smoke test.
"""
from __future__ import annotations

from pathlib import Path
from typing import Any

from lupa import LuaRuntime

from paths import ADDON_SRC, ROOT

BOOTSTRAP = r"""
WoWSmartTSM = { _modules = {}, ADDON_NAME = 'WoWSmartTSM' }
function WoWSmartTSM.Module(self, name)
  if self._modules[name] == nil then
    self._modules[name] = {}
  end
  return self._modules[name]
end
function WoWSmartTSM.GetModule(self, name)
  return self._modules[name]
end

local function newFS()
  local fs = { _text = '', _shown = true }
  function fs:SetPoint() end
  function fs:SetText(t) self._text = t or '' end
  function fs:GetText() return self._text end
  function fs:SetTextColor() end
  function fs:SetJustifyH() end
  function fs:SetJustifyV() end
  function fs:SetWordWrap() end
  function fs:SetNonSpaceWrap() end
  function fs:SetWidth() end
  function fs:SetHeight() end
  function fs:SetFont() end
  function fs:GetFont() return 'Fonts\\FRIZQT__.TTF', 12 end
  function fs:Show() self._shown = true end
  function fs:Hide() self._shown = false end
  function fs:IsShown() return self._shown end
  function fs:GetStringHeight() return 14 end
  function fs:GetStringWidth() return math.max(1, #(self._text or '') * 7) end
  function fs:GetObjectType() return 'FontString' end
  return fs
end

local function newFrame(ftype, name, parent, template)
  local f = {
    _type = ftype or 'Frame',
    _name = name,
    _parent = parent,
    _template = template,
    _shown = true,
    _alpha = 1,
    _w = 800,
    _h = 500,
    _level = 1,
    _children = {},
    _regions = {},
    _scripts = {},
    _points = {},
  }
  if parent and parent._children then
    table.insert(parent._children, f)
  end
  function f:SetParent(p)
    if self._parent and self._parent._children then
      for i, c in ipairs(self._parent._children) do
        if c == self then table.remove(self._parent._children, i) break end
      end
    end
    self._parent = p
    if p and p._children then table.insert(p._children, self) end
  end
  function f:GetParent() return self._parent end
  function f:GetChildren()
    return table.unpack(self._children)
  end
  function f:GetRegions()
    return table.unpack(self._regions)
  end
  function f:CreateFontString()
    local fs = newFS()
    table.insert(self._regions, fs)
    return fs
  end
  function f:CreateTexture()
    local tex = {
      SetAllPoints = function() end,
      SetTexture = function() end,
      SetVertexColor = function() end,
      SetPoint = function() end,
      SetSize = function() end,
      Show = function() end,
      Hide = function() end,
    }
    table.insert(self._regions, tex)
    return tex
  end
  function f:CreateFrame(t, n, tmpl)
    return CreateFrame(t, n, self, tmpl)
  end
  function f:SetAllPoints(other)
    if other then
      self._w = other._w or self._w
      self._h = other._h or self._h
    end
  end
  function f:SetSize(w, h) self._w = w or self._w; self._h = h or self._h end
  function f:SetWidth(w) self._w = w end
  function f:SetHeight(h) self._h = h end
  function f:GetWidth() return self._w end
  function f:GetHeight() return self._h end
  function f:SetPoint(...) table.insert(self._points, {...}) end
  function f:ClearAllPoints() self._points = {} end
  function f:SetFrameLevel(l) self._level = l end
  function f:GetFrameLevel() return self._level end
  function f:SetFrameStrata() end
  function f:SetAlpha(a) self._alpha = a end
  function f:Show() self._shown = true end
  function f:Hide() self._shown = false end
  function f:IsShown() return self._shown end
  function f:EnableMouse() end
  function f:RegisterForDrag() end
  function f:SetMovable() end
  function f:SetResizable() end
  function f:SetResizeBounds() end
  function f:SetMinResize() end
  function f:SetScale() end
  function f:StartMoving() end
  function f:StopMovingOrSizing() end
  function f:GetPoint() return 'CENTER', nil, 'CENTER', 0, 0 end
  function f:SetScript(ev, fn) self._scripts[ev] = fn end
  function f:GetScript(ev) return self._scripts[ev] end
  function f:SetBackdrop() end
  function f:SetBackdropColor() end
  function f:SetBackdropBorderColor() end
  function f:SetText(t) self._text = t end
  function f:GetText() return self._text end
  function f:LockHighlight() end
  function f:UnlockHighlight() end
  function f:IsObjectType(t) return t == self._type or t == 'Frame' or t == 'Button' end
  function f:Enable() end
  function f:Disable() end
  function f:SetScrollChild(child)
    self._scrollChild = child
    if child then
      child._parent = self
    end
  end
  function f:GetScrollChild() return self._scrollChild end
  function f:SetHorizontalScroll() end
  function f:SetVerticalScroll() end
  return f
end

function CreateFrame(ftype, name, parent, template)
  return newFrame(ftype, name, parent, template)
end

UIParent = CreateFrame('Frame', 'UIParent')
UIParent._w = 1920
UIParent._h = 1080

GameTooltip = {
  SetOwner = function() end,
  SetText = function() end,
  AddLine = function() end,
  Show = function() end,
  Hide = function() end,
}

BackdropTemplateMixin = {}
UISpecialFrames = {}
function tinsert(t, v) table.insert(t, v) end
function time() return 1700000000 end
function GetTime() return 100.5 end
function GetBuildInfo() return '1.60.1', '70888', 'Nov 12 2026', 16001 end
C_Timer = { After = function(sec, fn) end }
C_AddOns = { GetAddOnMetadata = function() return nil end }
function GetAddOnMetadata() return nil end
function print(...) end
function debugstack() return 'stack' end
function wipe(t)
  for k in pairs(t) do t[k] = nil end
  return t
end
function IsShiftKeyDown() return false end
function IsControlKeyDown() return false end
function UnitName() return 'Azamat' end
function GetRealmName() return 'CAMWOW EU4 Realm 6 PvP' end
function UnitFactionGroup() return 'Horde' end

WoWSmartTSM_DB = {
  settings = {
    locale = 'deDE',
    ahCut = 0.05,
    depositRateFallback = 0.15,
    auctionHours = 24,
    dataMaxAgeSeconds = 86400,
    dryRunVendor = true,
    openUIAfterScan = false,
    debug = false,
    frame = { point = 'CENTER', x = 0, y = 0, width = 980, height = 660, scale = 1 },
  },
  characters = {},
  itemRules = { ignore = {}, sessionIgnore = {} },
}
WoWSmartTSM_Diagnostics = { entries = {}, dedupe = {} }
"""


def create_runtime() -> Any:
	lua = LuaRuntime(unpack_returned_tuples=True)
	lua.execute(BOOTSTRAP)
	# Theme colors before Layout
	lua.execute(
		"""
		local Theme = WoWSmartTSM:Module('Theme')
		Theme.COLORS = {
			bg = {0.07,0.09,0.11,0.96},
			panel = {0.11,0.14,0.17,0.98},
			accent = {0.35,0.72,0.70,1},
			text = {0.90,0.92,0.93,1},
			muted = {0.62,0.67,0.70,1},
			post = {0.42,0.72,0.50,1},
			vendor = {0.82,0.70,0.40,1},
			hold = {0.55,0.65,0.85,1},
			skip = {0.85,0.55,0.48,1},
			review = {0.75,0.75,0.55,1},
			ok = {0.45,0.75,0.55,1},
			warn = {0.85,0.70,0.35,1},
			bad = {0.85,0.45,0.42,1},
		}
		function Theme.StrategyColor() return Theme.COLORS.text end
		"""
	)
	return lua


def exec_file(lua: Any, path: Path) -> None:
	src = path.read_text(encoding="utf-8")
	# lupa execute needs a string; keep filename in error via prefix comment
	lua.execute(src)


def load_layout_stack(lua: Any) -> None:
	"""Load Locale + Layout (the shared helpers tabs depend on)."""
	exec_file(lua, ADDON_SRC / "Locale" / "enUS.lua")
	exec_file(lua, ADDON_SRC / "Locale" / "deDE.lua")
	exec_file(lua, ADDON_SRC / "Locale" / "Locale.lua")
	exec_file(lua, ADDON_SRC / "UI" / "Layout.lua")


REQUIRED_LAYOUT_APIS = (
	"Begin",
	"ClearHost",
	"HeaderTitle",
	"HeaderButton",
	"BodyStack",
	"AddText",
	"AddGap",
	"AddButtonRow",
	"AddMetricGrid",
	"AddTable",
	"FinishStack",
	"FooterText",
	"MeasureButtonWidth",
	"HasVisibleContent",
	"ResolveHostSize",
	"ContentBudget",
	"TwoColumns",
	"CompactList",
	"FooterActions",
	"FitsWithoutScroll",
)


def assert_layout_api(lua: Any) -> dict:
	layout = lua.eval("WoWSmartTSM._modules.Layout")
	missing = [name for name in REQUIRED_LAYOUT_APIS if layout[name] is None]
	if missing:
		raise AssertionError(f"Layout APIs missing (file failed to load?): {missing}")
	return {name: layout[name] for name in REQUIRED_LAYOUT_APIS}


def stub_tab_dependencies(lua: Any) -> None:
	"""Lightweight stubs so tab Render bodies can run without full Core."""
	lua.execute(
		"""
		local function emptyMod(name, fields)
			local m = WoWSmartTSM:Module(name)
			for k,v in pairs(fields or {}) do m[k] = v end
			return m
		end
		emptyMod('Constants', {
			ROLES = { MAIN='MAIN', BANK='BANK', MANUAL='MANUAL' },
			ACTIONS = {
				MAIL_TO_BANK='MAIL_TO_BANK', HOLD_AT_BANK='HOLD_AT_BANK',
				POST_AH='POST_AH', HOLD='HOLD', VENDOR='VENDOR', KEEP='KEEP',
				IGNORE='IGNORE', MANUAL_REVIEW='MANUAL_REVIEW',
			},
			STRATEGIES = {
				VENDOR='VENDOR', HOLD='HOLD', MANUAL_REVIEW='MANUAL_REVIEW',
				QUICK_SELL='QUICK_SELL', PROFIT_SELL='PROFIT_SELL', RARE_SELL='RARE_SELL',
			},
			SEVERITY = { INFO='INFO', ERROR='ERROR', WARNING='WARNING', CRITICAL='CRITICAL', DEBUG='DEBUG' },
			LOG_RING_SIZE = 500,
		})
		emptyMod('MoneyUtil', { Format = function(v) return tostring(v or 0) end })
		emptyMod('TimeUtil', {
			Now = function() return 1700000000 end,
			ISO = function() return '2026-11-12T00:00:00Z' end,
			AgeSeconds = function() return 0 end,
		})
		emptyMod('ScanService', {
			GetLastResults = function() return {} end,
			Summarize = function() return { toPost=0, vendor=0, hold=0, optimizable=0, ahNet=0, vendorValue=0, mailToBank=0, skipped=0 } end,
			GetEvalStatus = function() return { status='NEVER_RUN', label='Noch keine Bewertung' } end,
			ReevaluateBags = function() end,
		})
		emptyMod('CleanupService', {
			Summarize = function() return { mailToBank=0, vendor=0, hold=0, post=0, skipped=0, review=0 } end,
			Filter = function(results) return results or {} end,
		})
		emptyMod('MailService', {
			BuildPlan = function() return { ok=false, code='BANK_CHARACTER_NOT_CONFIGURED', messages={}, items={} } end,
			PrepareMessage = function() return { ok=false } end,
		})
		emptyMod('VendorService', {
			BuildCandidates = function() return {} end,
			Preview = function() return { ok=true, lines={} } end,
		})
		emptyMod('CharacterProfiles', {
			EnsureCurrent = function() return { key='Realm-Char', role='MAIN', autoEval=true } end,
			GetCurrent = function() return { key='Realm-Char', role='MAIN', autoEval=true } end,
			GetRole = function() return 'MAIN' end,
			IsBankConfigured = function() return false end,
			GetPrimaryBankKey = function() return nil end,
			GetPrimaryBankDisplay = function() return nil end,
			CanMailToBank = function() return false, 'BANK_CHARACTER_NOT_CONFIGURED' end,
			List = function() return {} end,
			SetRole = function() end,
			SetPrimaryBank = function() end,
			ApplyMainDefaults = function() end,
		})
		emptyMod('ItemRules', {
			List = function() return {} end,
			ListAll = function() return {} end,
			ClearSessionIgnores = function() end,
		})
		emptyMod('Consumables', { Describe = function() return 'ok' end })
		emptyMod('CraftingReserve', { Describe = function() return 'ok' end })
		emptyMod('History', {
			List = function() return {} end,
			Get = function() return {} end,
			Add = function() end,
		})
		emptyMod('Undo', {
			CanUndo = function() return false end,
			Undo = function() end,
			UndoLast = function() return false end,
			Push = function() end,
		})
		emptyMod('Groups', {
			PreviewAssign = function() return {} end,
			ApplyAssign = function() end,
			ProbeCapabilities = function() return { writeMode='IMPORT_STRING', claim='mock', apiPresent=false, getItems=false } end,
			GetPathByItem = function() return nil end,
			ListPaths = function() return {} end,
			MissingSmartGroups = function() return {} end,
			BuildImportString = function() return '' end,
			GetLastImportString = function() return nil end,
			ApplyMoves = function() return true, {}, { mode='IMPORT_STRING', importString='' } end,
			VerifyMoves = function() return {}, {} end,
			IsSmartGroup = function() return false end,
			OpenTSMGroupsHint = function() return 'mock hint' end,
			OpenInTSM = function() return false, 'mock hint' end,
			EnsureSmartGroups = function() return false, 'NEED_IMPORT', {} end,
			FormatPath = function(p) if not p or p == '' then return 'Keine Gruppe' end; return tostring(p):gsub('`', ' > ') end,
			SplitPath = function(p) return nil, p end,
			CountItems = function() return 0, {} end,
			BuildHierarchy = function() return {} end,
			ListChoices = function() return { { path='', label='Keine Gruppe' } } end,
			SMART_GROUPS = {},
			STRATEGY_TO_GROUP = {},
		})
		emptyMod('GroupManager', {
			BuildProposals = function() return {} end,
			Preview = function() return {
				safeCount=0, reviewCount=0, protectedCount=0, alreadyOk=0,
				moves={}, missingGroups={}, capabilities={ writeMode='IMPORT_STRING' },
			} end,
			FilterSafe = function() return {} end,
			StageSafeApply = function() return { safeCount=0, moves={}, capabilities={} } end,
			ConfirmSafeApply = function() return false, {}, { error='NO_MOVES' } end,
			ApplySelectedMoves = function() return false, {}, { error='NO_MOVES' } end,
			GetLastPreview = function() return nil end,
			GetLastProposals = function() return {} end,
			GetPreferredGroup = function() return nil end,
			SetPreferredGroup = function() return true end,
			StatusLabel = function(s) return tostring(s or '?') end,
			GroupLabel = function(p) if not p or p == '' then return 'Keine Gruppe' end; return p end,
			STATUS = { SAFE='SAFE', REVIEW='REVIEW', PROTECTED='PROTECTED' },
		})
		emptyMod('Operations', {
			ProbeCapabilities = function() return { writeMode='MANUAL_SETUP', claim='mock' } end,
			GetAuctioningContext = function() return {} end,
			RecommendAuctioningOp = function() return nil end,
			RecommendMailingOp = function() return nil, 'BANK_NOT_CONFIGURED', 'mock' end,
			BuildCatalog = function() return {
				liveAvailable=false, auctioning={}, mailing={}, vendoring={}, suggestions={},
				warnings={'mock'}, capabilities={ writeMode='MANUAL_SETUP', claim='mock' },
			} end,
			GetEditableSuggestion = function() return nil end,
			ResetSuggestion = function() end,
			ValidatePriceFormula = function() return nil, 'API_UNAVAILABLE' end,
			SetupChecklist = function() return {
				{ id='groups_detect', title='Gruppen', detail='mock', manual=false, ok=true },
				{ id='groups_missing', title='Fehlend', detail='mock', manual=false, ok=true },
				{ id='ops_assign', title='Ops', detail='mock', manual=true, ok=false },
				{ id='ops_mailing', title='Mailing', detail='mock', manual=true, ok=false },
				{ id='ops_auctioning_bank', title='Auctioning', detail='mock', manual=true, ok=false },
			} end,
			OpenTSMHint = function() return 'mock ops hint' end,
			UnknownLabel = function() return 'unbekannt' end,
		})
		emptyMod('MainFrame', { SelectTab = function() end, Get = function() return nil end })
		emptyMod('SkipMap', {})
		emptyMod('Freshness', {
			GetReport = function() return {} end,
			GetCategoryTimestamp = function() return 0, 'none' end,
			GetAgeSeconds = function() return nil end,
		})
		emptyMod('Health', { GetReport = function() return {
			addonLoaded=true, loggerOk=true, slashOk=true, tsmApi=true,
			itemApi='C_Item', bagApi='C_Container', appHelper=true,
			autoEval={}, coverage={}
		} end })
		-- select() is a Lua builtin; ensure present
		if select == nil then
			function select(index, ...)
				local t = {...}
				if index == '#' then return #t end
				return t[index]
			end
		end
		emptyMod('Coverage', { GetReport = function() return { note='offline mock', coverageNote='mock' } end })
		emptyMod('Logger', {
			Init = function() return true end,
			GetInitStatus = function() return { ok=true } end,
			GetSessionId = function() return 'mock-session' end,
			GetEntries = function() return {} end,
			Info = function() end,
			Error = function() end,
			Warning = function() end,
			Log = function() end,
		})
		emptyMod('Version', { STRING='0.2.2', GetAddonVersion=function() return '0.2.2' end })
		emptyMod('ErrorCodes', { Get = function(k) return k end, CODES = {} })
		emptyMod('Privacy', { SanitizeString = function(s) return s end, SanitizeTable = function(t) return t end })
		emptyMod('RingBuffer', { New = function() return { _d = {} } end, Push = function() end, ToArray = function() return {} end })
		"""
	)


TAB_FILES = {
	"Cleanup": "CleanupTab.lua",
	"Dashboard": "Dashboard.lua",
	"Groups": "GroupsTab.lua",
	"Operations": "OperationsTab.lua",
	"Posting": "PostingTab.lua",
	"Mail": "MailTab.lua",
	"Vendor": "VendorTab.lua",
	"Hold": "HoldTab.lua",
	"Skipped": "SkippedTab.lua",
	"Characters": "CharactersTab.lua",
	"Rules": "RulesTab.lua",
	"Setup": "SetupWizard.lua",
	"History": "HistoryTab.lua",
	"Settings": "SettingsTab.lua",
	"Diagnostics": "DiagnosticsTab.lua",
}

MODULE_FOR_TAB = {
	"Cleanup": "CleanupTab",
	"Dashboard": "Dashboard",
	"Groups": "GroupsTab",
	"Operations": "OperationsTab",
	"Posting": "PostingTab",
	"Mail": "MailTab",
	"Vendor": "VendorTab",
	"Hold": "HoldTab",
	"Skipped": "SkippedTab",
	"Characters": "CharactersTab",
	"Rules": "RulesTab",
	"Setup": "SetupWizard",
	"History": "HistoryTab",
	"Settings": "SettingsTab",
	"Diagnostics": "DiagnosticsTab",
}


def load_core_decision_stack(lua: Any) -> None:
	"""Load CharacterResolver + profiles + ActionDecide + Cleanup helpers."""
	stub_tab_dependencies(lua)
	exec_file(lua, ADDON_SRC / "Core" / "CharacterResolver.lua")
	exec_file(lua, ADDON_SRC / "Core" / "CharacterProfiles.lua")
	exec_file(lua, ADDON_SRC / "Core" / "CleanupService.lua")
	exec_file(lua, ADDON_SRC / "Rules" / "ActionDecide.lua")
	exec_file(lua, ADDON_SRC / "UI" / "ItemExplain.lua")


def load_all_tabs(lua: Any) -> None:
	stub_tab_dependencies(lua)
	# Prefer real resolver/profiles when testing full UI
	try:
		exec_file(lua, ADDON_SRC / "Core" / "CharacterResolver.lua")
		exec_file(lua, ADDON_SRC / "Core" / "CharacterProfiles.lua")
		exec_file(lua, ADDON_SRC / "Core" / "CleanupService.lua")
		exec_file(lua, ADDON_SRC / "UI" / "ItemExplain.lua")
		exec_file(lua, ADDON_SRC / "UI" / "ItemContextMenu.lua")
	except Exception:
		pass
	exec_file(lua, ADDON_SRC / "UI" / "BulkReview.lua")
	for tab, fname in TAB_FILES.items():
		if fname == "BulkReview.lua":
			continue
		exec_file(lua, ADDON_SRC / "UI" / fname)


def render_tab(lua: Any, tab: str):
	mod_name = MODULE_FOR_TAB[tab]
	mod = lua.eval(f"WoWSmartTSM._modules['{mod_name}']")
	if mod is None or mod["Render"] is None:
		raise AssertionError(f"{mod_name}.Render missing")
	host = lua.eval("CreateFrame('Frame', 'TestHost', UIParent)")
	host["_w"] = 900
	host["_h"] = 500
	# Call Render(parent)
	render = mod["Render"]
	render(host)
	layout = lua.eval("WoWSmartTSM._modules.Layout")
	has = layout["HasVisibleContent"]
	ok = bool(has(host))
	if not ok:
		raise AssertionError(f"{tab}: render produced no visible content")
	return host
