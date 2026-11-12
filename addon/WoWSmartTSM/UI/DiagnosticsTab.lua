local Smart = WoWSmartTSM
local Locale = Smart:Module("Locale")
local Layout = Smart:Module("Layout")
local Theme = Smart:Module("Theme")
local Time = Smart:Module("TimeUtil")
local DiagnosticsTab = Smart:Module("DiagnosticsTab")

local function lineColor(ok)
	return ok and Theme.COLORS.ok or Theme.COLORS.bad
end

function DiagnosticsTab.Render(parent)
	local L = Locale.T
	local Health = Smart:GetModule("Health")
	local Logger = Smart:GetModule("Logger")
	local Coverage = Smart:GetModule("Coverage")
	local h = Health.GetReport()
	local cov = Coverage and Coverage.GetReport and Coverage.GetReport() or h.coverage or {}
	local init = Logger.GetInitStatus and Logger.GetInitStatus() or {}

	local root = Layout.Begin(parent)
	Layout.HeaderTitle(root.header, L("DIAGNOSTICS"))

	local stack = Layout.BodyStack(root)
	Layout.AddText(stack, "Gesundheitsstatus", "GameFontNormal")
	Layout.AddGap(stack, 4)

	local auto = h.autoEval or {}
	local rows = {
		{ "Addon geladen", tostring(h.addonLoaded), h.addonLoaded },
		{ "Logger OK", tostring(h.loggerOk) .. (init.error and (" (" .. init.error .. ")") or ""), h.loggerOk },
		{ "Slash /smarttsm", tostring(h.slashOk), h.slashOk },
		{ "TSM API", tostring(h.tsmApi), h.tsmApi },
		{ "Item-API", tostring(h.itemApi or "?"), h.itemApi ~= nil and h.itemApi ~= "NONE" },
		{ "Bag-API", tostring(h.bagApi or "?"), h.bagApi ~= nil and h.bagApi ~= "NONE" },
		{ "AppHelper", tostring(h.appHelper), h.appHelper },
		{ "DataTap", tostring(h.dataTap), h.dataTap },
		{ "Inventarbewertung", h.evalLabel or "—", h.evalStatus == "OK" or h.evalStatus == "NO_ITEMS" },
		{ "Letzte Bewertung", h.lastEvalAt and Time.ISO(h.lastEvalAt) or "—", h.lastEvalAt ~= nil },
		{ "AutoEval", string.format("status=%s reason=%s boot=%s", tostring(auto.lastStatus), tostring(auto.reason or "—"), tostring(auto.bootstrapped)), auto.lastStatus == "OK" or auto.lastStatus == "SCHEDULED" or auto.lastStatus == "RUNNING" },
		{ "Letzter Fehler", h.lastError or h.loadError or "keiner", (h.lastError == nil and h.loadError == nil) },
		{ "Coverage own/lua/dupes/early", string.format("%s / %s / %s / %s", tostring(cov.ownErrors or 0), tostring(cov.capturedLuaErrors or 0), tostring(cov.suppressedDuplicates or 0), tostring(cov.earlyErrors or 0)), (cov.loggerInitOk ~= false) },
		{ "Realm-Datenalter", h.realmDataAge and Time.ISO(h.realmDataAge) or "unbekannt", h.realmDataAge ~= nil },
		{ "Region-Datenalter", h.regionDataAge and Time.ISO(h.regionDataAge) or "unbekannt", h.regionDataAge ~= nil },
	}

	for _, r in ipairs(rows) do
		Layout.AddText(stack, r[1] .. ":  " .. r[2], "GameFontHighlight", lineColor(r[3]))
	end

	Layout.AddGap(stack, 10)
	Layout.AddText(stack, "Logging-Abdeckung", "GameFontNormal")
	Layout.AddText(stack, cov.coverageNote or cov.note or "", "GameFontHighlightSmall", Theme.COLORS.muted)
	Layout.AddText(stack, cov.limitation or "Crash vor SavedVariables-Flush kann Fehler verwerfen.", "GameFontHighlightSmall", Theme.COLORS.muted)

	Layout.AddGap(stack, 10)
	Layout.AddText(stack, "Letzte Log-Einträge", "GameFontNormal")
	local entries = Logger.GetEntries()
	local start = math.max(1, #entries - 8)
	if #entries == 0 then
		Layout.AddText(stack, "Keine Einträge.", "GameFontHighlightSmall", Theme.COLORS.muted)
	else
		for i = start, #entries do
			local e = entries[i]
			Layout.AddText(
				stack,
				string.format("[%s] %s %s/%s — %s", e.severity or "?", e.code or "?", e.module or "-", e.func or "-", e.message or ""),
				"GameFontHighlightSmall",
				(e.severity == "ERROR" or e.severity == "CRITICAL") and Theme.COLORS.bad or Theme.COLORS.text
			)
		end
	end
	Layout.FinishStack(stack)
	Layout.FooterText(root.footer, "Session " .. tostring(Logger.GetSessionId() or "—"))
end
