local Smart = WoWSmartTSM
local Locale = Smart:Module("Locale")
local Money = Smart:Module("MoneyUtil")
local Widgets = Smart:Module("Widgets")
local Dashboard = Smart:Module("Dashboard")

function Dashboard.Render(parent)
	for _, child in ipairs({ parent:GetChildren() }) do
		child:Hide()
		child:SetParent(nil)
	end
	-- clear fontstrings
	parent._smartClean = true

	local L = Locale.T
	local ScanService = Smart:GetModule("ScanService")
	local sum = ScanService.Summarize(ScanService.GetLastResults())

	local title = Widgets.Label(parent, L("DASHBOARD"), 14)
	title:SetPoint("TOPLEFT", 16, -16)

	local scanBtn = Widgets.Button(parent, L("SCAN"), 140, 26, function()
		ScanService.RunBagScan()
		local UI = Smart:GetModule("UI")
		UI.RenderTab("Dashboard", parent)
	end)
	scanBtn:SetPoint("TOPRIGHT", -16, -14)

	local metrics = {
		{ L("POSTING"), sum.toPost },
		{ "Optimierbar", sum.optimizable },
		{ L("VENDOR"), sum.vendor },
		{ L("HOLD"), sum.hold },
		{ L("EXPECTED_NET"), Money.Format(sum.ahNet, true) },
		{ "Vendorwert", Money.Format(sum.vendorValue, true) },
		{ L("DATA_QUALITY"), string.format("%.0f%%", (sum.dataQualityAvg or 0) * 100) },
		{ "Review", sum.review },
	}

	local y = -50
	for i, m in ipairs(metrics) do
		local col = ((i - 1) % 4)
		local row = math.floor((i - 1) / 4)
		local box = CreateFrame("Frame", nil, parent, BackdropTemplateMixin and "BackdropTemplate" or nil)
		box:SetSize(200, 64)
		box:SetPoint("TOPLEFT", 16 + col * 220, y - row * 76)
		if BackdropTemplateMixin then
			Widgets.AddBackdrop(box)
		end
		local k = Widgets.Label(box, m[1], 11)
		k:SetPoint("TOPLEFT", 10, -10)
		local v = Widgets.Label(box, tostring(m[2]), 16)
		v:SetPoint("BOTTOMLEFT", 10, 12)
	end

	local hint = Widgets.Label(parent, L("VISUAL_ACCEPTANCE"), 11)
	hint:SetPoint("BOTTOMLEFT", 16, 16)
end
