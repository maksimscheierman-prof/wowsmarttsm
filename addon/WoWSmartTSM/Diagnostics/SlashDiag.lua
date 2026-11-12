local Smart = WoWSmartTSM
local Logger = Smart:Module("Logger")
local Coverage = Smart:Module("Coverage")
local Version = Smart:Module("Version")
local Detect = nil -- filled later / lazy
local SlashDiag = Smart:Module("SlashDiag")

local pendingReset = false

local function printMsg(msg)
	print("|cff4ecdc4[SmartTSM]|r " .. tostring(msg))
end

function SlashDiag.Status()
	Detect = Smart:GetModule("Detect")
	local client = Version.GetClientInfo()
	printMsg("Version " .. Version.GetAddonVersion())
	printMsg("Client " .. tostring(client and client.version) .. " build " .. tostring(client and client.build))
	printMsg("TSM " .. tostring(Version.GetTSMVersion() or "not found"))
	if Detect and Detect.GetStatus then
		local st = Detect.GetStatus()
		printMsg("TSM loaded=" .. tostring(st.tsmLoaded) .. " AppHelper=" .. tostring(st.appHelperLoaded))
	end
	local cov = Coverage.GetReport()
	local init = Logger.GetInitStatus and Logger.GetInitStatus() or {}
	local loadError = (Smart.GetLoadError and Smart.GetLoadError())
		or (WoWSmartTSM_Diagnostics and WoWSmartTSM_Diagnostics.loadError)
	printMsg(string.format(
		"Errors own=%d lua=%d dupes=%d early=%d | loggerInitOk=%s",
		cov.ownErrors or 0,
		cov.capturedLuaErrors or 0,
		cov.suppressedDuplicates or 0,
		cov.earlyErrors or 0,
		tostring(cov.loggerInitOk)
	))
	if init.failed or loadError then
		printMsg("|cffff6666WARN|r Logger/Bootstrap-Fehler — Zähler allein bedeuten keinen fehlerfreien Zustand")
		if init.error then
			printMsg("Logger.Init error: " .. tostring(init.error))
		end
		if loadError then
			printMsg("Load error: " .. tostring(loadError))
		end
	end
end

function SlashDiag.Errors(limit)
	limit = limit or 10
	local entries = Logger.GetEntries()
	local n = #entries
	printMsg("Showing last " .. tostring(math.min(limit, n)) .. " / " .. tostring(n) .. " entries")
	for i = math.max(1, n - limit + 1), n do
		local e = entries[i]
		printMsg(string.format("%s [%s] %s %s/%s — %s (x%d)", e.iso or "?", e.severity, e.code, e.module or "-", e.func or "-", e.message or "", e.count or 1))
	end
end

function SlashDiag.Diagnose()
	SlashDiag.Status()
	local cov = Coverage.GetReport()
	printMsg(cov.coverageNote)
	printMsg(cov.limitation)
	Detect = Smart:GetModule("Detect")
	if Detect and Detect.Diagnose then
		Detect.Diagnose()
	end
end

function SlashDiag.DebugToggle()
	local db = WoWSmartTSM_DB
	if not db or not db.settings then
		printMsg("DB not ready")
		return
	end
	db.settings.debug = not db.settings.debug
	printMsg("Debug=" .. tostring(db.settings.debug))
end

function SlashDiag.Reset(arg)
	local SV = Smart:GetModule("SavedVariables")
	if arg == "confirm" and pendingReset then
		SV.DoReset()
		pendingReset = false
		printMsg("SavedVariables reset.")
		return
	end
	pendingReset = true
	printMsg(SV.ResetWithBackupHint())
	printMsg("To confirm: /smarttsm reset confirm")
end
