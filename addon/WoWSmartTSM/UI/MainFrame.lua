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

function MainFrame.Get()
	return private.frame
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
	if UI and UI.RenderTab then
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
	f:SetSize(s.width or 920, s.height or 620)
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
		f:SetResizeBounds(720, 480, 1400, 900)
	end
	if BackdropTemplateMixin then
		Widgets.AddBackdrop(f, Theme.COLORS.bg)
	end
	f:Hide()
	tinsert(UISpecialFrames, "WoWSmartTSMFrame")

	local title = Widgets.Label(f, L("APP_NAME"), 16)
	title:SetPoint("TOPLEFT", 16, -14)

	local subtitle = Widgets.Label(f, L("SELL_FIRST") .. " — " .. L("VISUAL_ACCEPTANCE"), 11)
	subtitle:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -4)
	subtitle:SetTextColor(Theme.COLORS.muted[1], Theme.COLORS.muted[2], Theme.COLORS.muted[3], 1)

	local close = CreateFrame("Button", nil, f, "UIPanelCloseButton")
	close:SetPoint("TOPRIGHT", -4, -4)

	local tabBar = CreateFrame("Frame", nil, f)
	tabBar:SetPoint("TOPLEFT", 12, -52)
	tabBar:SetPoint("TOPRIGHT", -12, -52)
	tabBar:SetHeight(28)

	local x = 0
	for _, name in ipairs(TAB_ORDER) do
		local labelKey = name:upper()
		if name == "Dashboard" then labelKey = "DASHBOARD"
		elseif name == "Posting" then labelKey = "POSTING"
		elseif name == "Skipped" then labelKey = "SKIPPED"
		elseif name == "Vendor" then labelKey = "VENDOR"
		elseif name == "Hold" then labelKey = "HOLD"
		elseif name == "History" then labelKey = "HISTORY"
		elseif name == "Settings" then labelKey = "SETTINGS"
		elseif name == "Diagnostics" then labelKey = "DIAGNOSTICS"
		end
		local btn = Widgets.Button(tabBar, L(labelKey), 100, 24, function()
			MainFrame.SelectTab(name)
		end)
		btn:SetPoint("LEFT", tabBar, "LEFT", x, 0)
		private.tabs[name] = btn
		x = x + 102
	end

	local content = CreateFrame("Frame", nil, f, BackdropTemplateMixin and "BackdropTemplate" or nil)
	content:SetPoint("TOPLEFT", 12, -86)
	content:SetPoint("BOTTOMRIGHT", -12, 14)
	if BackdropTemplateMixin then
		Widgets.AddBackdrop(content, Theme.COLORS.panel)
	end
	private.content = content
	private.frame = f

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
