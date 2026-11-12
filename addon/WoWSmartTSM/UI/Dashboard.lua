local Smart = WoWSmartTSM
local Locale = Smart:Module("Locale")
local Money = Smart:Module("MoneyUtil")
local Widgets = Smart:Module("Widgets")
local Time = Smart:Module("TimeUtil")
local Dashboard = Smart:Module("Dashboard")

local function fmtTs(ts)
	if not ts or ts == 0 then
		return "unbekannt"
	end
	local age = Time.AgeSeconds(ts)
	if not age then
		return Time.ISO(ts)
	end
	if age < 3600 then
		return string.format("%d min alt", math.floor(age / 60))
	end
	if age < 86400 then
		return string.format("%.1fh alt", age / 3600)
	end
	return string.format("%.1fd alt", age / 86400)
end

function Dashboard.Render(parent)
	for _, child in ipairs({ parent:GetChildren() }) do
		child:Hide()
		child:SetParent(nil)
	end
	parent._smartClean = true

	local L = Locale.T
	local ScanService = Smart:GetModule("ScanService")
	local Freshness = Smart:GetModule("Freshness")
	local sum = ScanService.Summarize(ScanService.GetLastResults())
	local meta = ScanService.GetLastMeta and ScanService.GetLastMeta() or {}

	local title = Widgets.Label(parent, L("DASHBOARD"), 14)
	title:SetPoint("TOPLEFT", 16, -16)

	local scanBtn = Widgets.Button(parent, L("SCAN"), 160, 26, function()
		-- Neubewertung anhand TSM-Daten — kein AH-Scan
		ScanService.ReevaluateBags({ reason = "ui_button" })
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
		{ "Need Live AH", sum.needsLiveCompetition or 0 },
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

	local realmTs = Freshness and select(1, Freshness.GetCategoryTimestamp("realm"))
	local regionTs = Freshness and select(1, Freshness.GetCategoryTimestamp("region"))
	local freshLine = string.format(
		"TSM AuctionDB: Realm %s | Region %s | Letzte Neubewertung: %s | AH-Scan gestartet: %s",
		fmtTs(realmTs),
		fmtTs(regionTs),
		meta.at and fmtTs(meta.at) or "noch keine",
		tostring(meta.startedAhScan == true)
	)
	local freshLabel = Widgets.Label(parent, freshLine, 11)
	freshLabel:SetPoint("TOPLEFT", 16, -210)
	freshLabel:SetWidth(860)
	freshLabel:SetJustifyH("LEFT")

	local note = Widgets.Label(parent, "Quellen: DBMarket/DBMinBuyout/DBNumAuctions/DBRegion*/VendorSell via TSM_API — kein doppelter AH-Scan. " .. L("VISUAL_ACCEPTANCE"), 11)
	note:SetPoint("BOTTOMLEFT", 16, 16)
	note:SetWidth(860)
end
