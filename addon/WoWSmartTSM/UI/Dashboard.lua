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
	local _, bw = Layout.HeaderButton(root.header, L("SCAN"), function()
		ScanService.ReevaluateBags({ reason = "ui_button" })
		Dashboard.Render(parent)
	end)
	Layout.HeaderTitle(root.header, L("DASHBOARD"), (bw or 160) + 12)

	local results = ScanService.GetLastResults() or {}
	local C = Smart:Module("Constants")
	local quick, profit, rare = 0, 0, 0
	for _, d in ipairs(results) do
		if d and d.strategy == C.STRATEGIES.QUICK_SELL then
			quick = quick + 1
		elseif d and d.strategy == C.STRATEGIES.PROFIT_SELL then
			profit = profit + 1
		elseif d and d.strategy == C.STRATEGIES.RARE_SELL then
			rare = rare + 1
		end
	end

	local stack = Layout.BodyStack(root)
	local CleanupService = Smart:GetModule("CleanupService")
	local CP = Smart:GetModule("CharacterProfiles")
	local clean = CleanupService and CleanupService.Summarize and CleanupService.Summarize(results) or {}
	Layout.AddText(stack, eval.label or "Status unbekannt", "GameFontHighlight", Theme.COLORS.accent)
	Layout.AddText(
		stack,
		string.format("Rolle=%s | Bank=%s", tostring(CP and CP.GetRole and CP.GetRole()), tostring(CP and CP.GetPrimaryBankDisplay and CP.GetPrimaryBankDisplay() or "—")),
		"GameFontHighlightSmall",
		Theme.COLORS.muted
	)
	Layout.AddGap(stack, 6)
	Layout.AddMetricGrid(stack, {
		{ "Mail→Bank", clean.mailToBank or 0, Theme.COLORS.post },
		{ "Vendor", clean.vendor or 0, Theme.COLORS.vendor },
		{ "Keep", clean.keep or 0, Theme.COLORS.muted },
		{ "Hold→Bank", clean.holdAtBank or 0, Theme.COLORS.hold },
		{ "Prüfung", clean.review or 0, Theme.COLORS.warn },
		{ "Quick", quick, Theme.COLORS.post },
		{ "Profit", profit, Theme.COLORS.post },
		{ "Rare", rare, Theme.COLORS.hold },
		{ L("EXPECTED_NET"), Money.Format(sum.ahNet, true) },
		{ "Need Live AH", sum.needsLiveCompetition or 0, Theme.COLORS.warn },
	}, 5)

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
