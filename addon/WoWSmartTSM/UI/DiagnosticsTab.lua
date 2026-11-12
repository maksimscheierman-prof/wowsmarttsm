local Smart = WoWSmartTSM
local Locale = Smart:Module("Locale")
local Widgets = Smart:Module("Widgets")
local Coverage = Smart:Module("Coverage")
local Logger = Smart:Module("Logger")
local Version = Smart:Module("Version")
local Detect = Smart:Module("Detect")
local DiagnosticsTab = Smart:Module("DiagnosticsTab")

function DiagnosticsTab.Render(parent)
	for _, child in ipairs({ parent:GetChildren() }) do
		child:Hide()
		child:SetParent(nil)
	end
	local title = Widgets.Label(parent, Locale.T("DIAGNOSTICS"), 14)
	title:SetPoint("TOPLEFT", 16, -16)

	local st = Detect.GetStatus()
	local cov = Coverage.GetReport()
	local y = -48
	local lines = {
		"Addon " .. Version.GetAddonVersion(),
		"TSM " .. tostring(st.tsmVersion) .. " loaded=" .. tostring(st.tsmLoaded) .. " supported=" .. tostring(st.supported),
		"AppHelper " .. tostring(st.appHelperLoaded),
		string.format("Errors own=%d lua=%d dupes=%d", cov.ownErrors, cov.capturedLuaErrors, cov.suppressedDuplicates),
		cov.coverageNote,
		cov.limitation,
		"Session " .. tostring(Logger.GetSessionId()),
	}
	for _, text in ipairs(lines) do
		local l = Widgets.Label(parent, text, 11)
		l:SetPoint("TOPLEFT", 16, y)
		l:SetWidth(850)
		l:SetJustifyH("LEFT")
		y = y - 18
	end

	local entries = Logger.GetEntries()
	y = y - 10
	local h = Widgets.Label(parent, "Letzte Fehler:", 12)
	h:SetPoint("TOPLEFT", 16, y)
	y = y - 20
	for i = math.max(1, #entries - 8), #entries do
		local e = entries[i]
		if e then
			local l = Widgets.Label(parent, string.format("[%s] %s %s — %s", e.severity, e.code, e.module or "", e.message or ""), 10)
			l:SetPoint("TOPLEFT", 16, y)
			l:SetWidth(850)
			y = y - 14
		end
	end
end
