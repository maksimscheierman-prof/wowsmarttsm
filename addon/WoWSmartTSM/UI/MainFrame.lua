local Smart = WoWSmartTSM
local Locale = Smart:Module("Locale")
local Theme = Smart:Module("Theme")
local Widgets = Smart:Module("Widgets")
local C = Smart:Module("Constants")
local MainFrame = Smart:Module("MainFrame")

local private = {
	frame = nil,
	tabs = {},
	active = nil,
	panel = nil,
	content = nil,
	tabBar = nil,
	renderGen = 0,
	sizeDirty = false,
}

-- Extended tab set for v0.2; role picks default
local TAB_ORDER = {
	"Cleanup",
	"Dashboard",
	"Groups",
	"Operations",
	"Posting",
	"Mail",
	"Vendor",
	"Hold",
	"Skipped",
	"Characters",
	"Rules",
	"Setup",
	"History",
	"Settings",
	"Diagnostics",
}

local function labelKeyFor(name)
	local map = {
		Cleanup = "CLEANUP",
		Dashboard = "DASHBOARD",
		Groups = "GROUPS_TAB",
		Operations = "OPERATIONS_TAB",
		Posting = "POSTING",
		Mail = "MAIL",
		Skipped = "SKIPPED",
		Vendor = "VENDOR",
		Hold = "HOLD",
		Characters = "CHARACTERS",
		Rules = "RULES",
		Setup = "SETUP_WIZARD",
		History = "HISTORY",
		Settings = "SETTINGS",
		Diagnostics = "DIAGNOSTICS",
	}
	return map[name] or name:upper()
end

local function defaultTabForRole()
	local CP = Smart:GetModule("CharacterProfiles")
	local role = CP and CP.GetRole and CP.GetRole() or C.ROLES.MAIN
	if role == C.ROLES.BANK then
		return "Posting"
	end
	if role == C.ROLES.MAIN then
		return "Cleanup"
	end
	return "Dashboard"
end

function MainFrame.Get()
	return private.frame
end

function MainFrame.GetContent()
	return private.content
end

function MainFrame.GetActiveTab()
	return private.active
end

function MainFrame.SavePosition()
	local f = private.frame
	if not f or not WoWSmartTSM_DB then
		return
	end
	local point, _, _, x, y = f:GetPoint(1)
	local s = WoWSmartTSM_DB.settings.frame
	s.point = point or "CENTER"
	s.x = x or 0
	s.y = y or 0
	s.width = f:GetWidth()
	s.height = f:GetHeight()
end

function MainFrame.SelectTab(name)
	if not name then
		return
	end
	private.active = name
	for id, btn in pairs(private.tabs) do
		if id == name then
			btn:LockHighlight()
		else
			btn:UnlockHighlight()
		end
	end
	local UI = Smart:GetModule("UI")
	if UI and UI.RenderTab and private.content then
		UI.RenderTab(name, private.content)
	end
end

function MainFrame.Create()
	if private.frame then
		return private.frame
	end
	local L = Locale.T
	local s = (WoWSmartTSM_DB and WoWSmartTSM_DB.settings and WoWSmartTSM_DB.settings.frame) or {}
	local f = CreateFrame("Frame", "WoWSmartTSMFrame", UIParent, BackdropTemplateMixin and "BackdropTemplate" or nil)
	f:SetSize(s.width or 980, s.height or 660)
	f:SetPoint(s.point or "CENTER", UIParent, s.point or "CENTER", s.x or 0, s.y or 0)
	f:SetFrameStrata("HIGH")
	f:SetMovable(true)
	f:EnableMouse(true)
	f:RegisterForDrag("LeftButton")
	f:SetScript("OnDragStart", f.StartMoving)
	f:SetScript("OnDragStop", function(self)
		self:StopMovingOrSizing()
		MainFrame.SavePosition()
	end)
	f:SetResizable(true)
	if f.SetResizeBounds then
		f:SetResizeBounds(780, 520, 1400, 900)
	elseif f.SetMinResize then
		f:SetMinResize(780, 520)
	end
	if BackdropTemplateMixin then
		Widgets.AddBackdrop(f, Theme.COLORS.bg)
	end
	f:Hide()
	tinsert(UISpecialFrames, "WoWSmartTSMFrame")

	local title = f:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
	title:SetPoint("TOPLEFT", 16, -12)
	title:SetText(L("APP_NAME"))
	title:SetTextColor(Theme.COLORS.accent[1], Theme.COLORS.accent[2], Theme.COLORS.accent[3], 1)

	local subtitle = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
	subtitle:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -2)
	subtitle:SetText(L("SELL_FIRST"))
	subtitle:SetTextColor(Theme.COLORS.muted[1], Theme.COLORS.muted[2], Theme.COLORS.muted[3], 1)

	local close = CreateFrame("Button", nil, f, "UIPanelCloseButton")
	close:SetPoint("TOPRIGHT", -2, -2)

	local tabBar = CreateFrame("Frame", nil, f)
	tabBar:SetPoint("TOPLEFT", 12, -48)
	tabBar:SetPoint("TOPRIGHT", -12, -48)
	tabBar:SetHeight(48)
	private.tabBar = tabBar

	-- Two rows of tabs to avoid overlap with many tabs
	local x, yRow = 0, 0
	for _, name in ipairs(TAB_ORDER) do
		local btn = CreateFrame("Button", nil, tabBar, "UIPanelButtonTemplate")
		local label = L(labelKeyFor(name))
		local tw = math.min(108, math.max(72, (#label * 6) + 16))
		btn:SetSize(tw, 22)
		if x + tw > (tabBar:GetWidth() > 0 and tabBar:GetWidth() or 900) then
			yRow = 24
			x = 0
		end
		btn:SetPoint("TOPLEFT", tabBar, "TOPLEFT", x, -yRow)
		btn:SetText(label)
		btn:SetScript("OnClick", function()
			MainFrame.SelectTab(name)
		end)
		private.tabs[name] = btn
		x = x + tw + 4
	end

	-- Visual panel (backdrop). Render host is a SEPARATE child so ClearHost
	-- never touches BackdropTemplate NineSlice / edge children.
	local panel = CreateFrame("Frame", nil, f, BackdropTemplateMixin and "BackdropTemplate" or nil)
	panel:SetPoint("TOPLEFT", 12, -100)
	panel:SetPoint("BOTTOMRIGHT", -12, 12)
	if BackdropTemplateMixin then
		Widgets.AddBackdrop(panel, Theme.COLORS.panel)
	end
	private.panel = panel

	local content = CreateFrame("Frame", "WoWSmartTSMContentHost", panel)
	content:SetPoint("TOPLEFT", 6, -6)
	content:SetPoint("BOTTOMRIGHT", -6, 6)
	content:SetFrameLevel((panel.GetFrameLevel and panel:GetFrameLevel() or 0) + 10)
	content:Show()
	private.content = content
	private.frame = f

	f:SetScript("OnShow", function()
		local tab = private.active or defaultTabForRole()
		MainFrame.SelectTab(tab)
	end)

	f:SetScript("OnSizeChanged", function()
		MainFrame.SavePosition()
		if not f:IsShown() or not private.active then
			return
		end
		-- Debounce: one re-render per size gesture, not per pixel.
		private.sizeDirty = true
		private.renderGen = (private.renderGen or 0) + 1
		local gen = private.renderGen
		if C_Timer and C_Timer.After then
			C_Timer.After(0.05, function()
				if gen == private.renderGen and private.sizeDirty and f:IsShown() then
					private.sizeDirty = false
					MainFrame.SelectTab(private.active)
				end
			end)
		else
			private.sizeDirty = false
			MainFrame.SelectTab(private.active)
		end
	end)

	local scale = (WoWSmartTSM_DB and WoWSmartTSM_DB.settings and WoWSmartTSM_DB.settings.frame.scale) or 1
	f:SetScale(scale)

	-- Defer first paint until OnShow so host width/height are valid.
	private.active = defaultTabForRole()
	return f
end

function MainFrame.Toggle()
	local f = MainFrame.Create()
	if f:IsShown() then
		f:Hide()
	else
		f:Show()
	end
end
