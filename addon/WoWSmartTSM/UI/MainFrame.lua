local Smart = WoWSmartTSM
local Locale = Smart:Module("Locale")
local Theme = Smart:Module("Theme")
local Widgets = Smart:Module("Widgets")
local MainFrame = Smart:Module("MainFrame")

local private = {
	frame = nil,
	tabs = {},
	active = nil,
	content = nil,
	tabBar = nil,
}

local TAB_ORDER = {
	"Dashboard",
	"Posting",
	"Skipped",
	"Vendor",
	"Hold",
	"History",
	"Settings",
	"Diagnostics",
}

local function labelKeyFor(name)
	local map = {
		Dashboard = "DASHBOARD",
		Posting = "POSTING",
		Skipped = "SKIPPED",
		Vendor = "VENDOR",
		Hold = "HOLD",
		History = "HISTORY",
		Settings = "SETTINGS",
		Diagnostics = "DIAGNOSTICS",
	}
	return map[name] or name:upper()
end

function MainFrame.Get()
	return private.frame
end

function MainFrame.GetContent()
	return private.content
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
	f:SetSize(s.width or 960, s.height or 640)
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
		f:SetResizeBounds(760, 500, 1400, 900)
	elseif f.SetMinResize then
		f:SetMinResize(760, 500)
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
	tabBar:SetHeight(26)
	private.tabBar = tabBar

	local x = 0
	for _, name in ipairs(TAB_ORDER) do
		local btn = CreateFrame("Button", nil, tabBar, "UIPanelButtonTemplate")
		btn:SetSize(108, 24)
		btn:SetPoint("LEFT", tabBar, "LEFT", x, 0)
		btn:SetText(L(labelKeyFor(name)))
		btn:SetScript("OnClick", function()
			MainFrame.SelectTab(name)
		end)
		private.tabs[name] = btn
		x = x + 110
	end

	local content = CreateFrame("Frame", nil, f, BackdropTemplateMixin and "BackdropTemplate" or nil)
	content:SetPoint("TOPLEFT", 12, -80)
	content:SetPoint("BOTTOMRIGHT", -12, 12)
	if BackdropTemplateMixin then
		Widgets.AddBackdrop(content, Theme.COLORS.panel)
	end
	private.content = content
	private.frame = f

	f:SetScript("OnSizeChanged", function()
		MainFrame.SavePosition()
		if private.active then
			MainFrame.SelectTab(private.active)
		end
	end)

	local scale = (WoWSmartTSM_DB and WoWSmartTSM_DB.settings and WoWSmartTSM_DB.settings.frame.scale) or 1
	f:SetScale(scale)

	MainFrame.SelectTab("Dashboard")
	return f
end

function MainFrame.Toggle()
	local f = MainFrame.Create()
	if f:IsShown() then
		f:Hide()
	else
		f:Show()
		MainFrame.SelectTab(private.active or "Dashboard")
	end
end
