local Smart = WoWSmartTSM
local Locale = Smart:Module("Locale")
local Money = Smart:Module("MoneyUtil")
local Layout = Smart:Module("Layout")
local Theme = Smart:Module("Theme")
local Time = Smart:Module("TimeUtil")
local Dashboard = Smart:Module("Dashboard")

local function fmtAge(ts)
	if not ts or ts == 0 then
		return "unbekannt"
	end
	local age = Time.AgeSeconds(ts)
	if not age then
		return Time.ISO(ts)
	end
	if age < 3600 then
		return string.format("%d min", math.floor(age / 60))
	end
	if age < 86400 then
		return string.format("%.1f h", age / 3600)
	end
	return string.format("%.1f d", age / 86400)
end

function Dashboard.Render(parent)
	local L = Locale.T
	local ScanService = Smart:GetModule("ScanService")
	local Freshness = Smart:GetModule("Freshness")
	local Health = Smart:GetModule("Health")
	local sum = ScanService.Summarize(ScanService.GetLastResults())
	local eval = ScanService.GetEvalStatus and ScanService.GetEvalStatus() or {}
	local health = Health and Health.GetReport and Health.GetReport() or {}

	local root = Layout.Begin(parent)
	Layout.HeaderTitle(root.header, L("DASHBOARD"))
	Layout.HeaderButton(root.header, L("SCAN"), function()
		ScanService.ReevaluateBags({ reason = "ui_button" })
		Dashboard.Render(parent)
	end)

	local stack = Layout.BodyStack(root)
	Layout.AddText(stack, eval.label or "Status unbekannt", "GameFontHighlight", Theme.COLORS.accent)
	Layout.AddGap(stack, 6)
	Layout.AddMetricGrid(stack, {
		{ L("POSTING"), sum.toPost, Theme.COLORS.post },
		{ "Optimierbar", sum.optimizable, Theme.COLORS.skip },
		{ L("VENDOR"), sum.vendor, Theme.COLORS.vendor },
		{ L("HOLD"), sum.hold, Theme.COLORS.hold },
		{ L("EXPECTED_NET"), Money.Format(sum.ahNet, true) },
		{ "Vendorwert", Money.Format(sum.vendorValue, true) },
		{ L("DATA_QUALITY"), string.format("%.0f%%", (sum.dataQualityAvg or 0) * 100) },
		{ "Need Live AH", sum.needsLiveCompetition or 0, Theme.COLORS.warn },
	}, 4)

	Layout.AddGap(stack, 8)
	local realmTs = Freshness and select(1, Freshness.GetCategoryTimestamp("realm"))
	local regionTs = Freshness and select(1, Freshness.GetCategoryTimestamp("region"))
	Layout.AddText(stack, "Datenquellen (TSM AuctionDB, kein AH-Scan)", "GameFontNormal")
	Layout.AddText(
		stack,
		string.format(
			"Realm-Datenalter: %s  |  Region: %s  |  Letzte Bewertung: %s (%s)",
			fmtAge(realmTs),
			fmtAge(regionTs),
			eval.at and fmtAge(eval.at) or "—",
			tostring(eval.reason or "—")
		),
		"GameFontHighlightSmall",
		Theme.COLORS.muted
	)
	Layout.AddText(
		stack,
		string.format(
			"Gesundheit: Logger=%s  Slash=%s  TSM API=%s  AppHelper=%s  DataTap=%s",
			tostring(health.loggerOk),
			tostring(health.slashOk),
			tostring(health.tsmApi),
			tostring(health.appHelper),
			tostring(health.dataTap)
		),
		"GameFontHighlightSmall",
		Theme.COLORS.muted
	)
	Layout.FinishStack(stack)

	Layout.FooterText(root.footer, L("VISUAL_ACCEPTANCE") .. " — Layout v0.1.3")
end
