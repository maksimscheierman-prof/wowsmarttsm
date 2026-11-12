local Smart = WoWSmartTSM
local SlashDiag = Smart:Module("SlashDiag")
local Time = Smart:Module("TimeUtil")
local Commands = Smart:Module("Commands")

local private = {
	registered = false,
}

local function openUI()
	local UI = Smart:GetModule("UI")
	if UI and UI.Toggle then
		UI.Toggle()
	else
		print("|cff4ecdc4[SmartTSM]|r UI not ready")
	end
end

function Commands.Handle(msg)
	msg = (msg or ""):match("^%s*(.-)%s*$") or ""
	local cmd, rest = msg:match("^(%S+)%s*(.*)$")
	cmd = cmd and cmd:lower() or ""
	if cmd == "" or cmd == "show" or cmd == "toggle" then
		openUI()
	elseif cmd == "status" then
		SlashDiag.Status()
		local ScanService = Smart:GetModule("ScanService")
		local AutoEval = Smart:GetModule("AutoEval")
		local Health = Smart:GetModule("Health")
		local meta = ScanService.GetLastMeta and ScanService.GetLastMeta() or {}
		local eval = ScanService.GetEvalStatus and ScanService.GetEvalStatus() or {}
		local auto = AutoEval and AutoEval.GetState and AutoEval.GetState() or {}
		if eval.status == "NEVER_RUN" or meta.reason == nil then
			print("|cffffcc00[SmartTSM]|r Last reeval: noch keine Bewertung (status=NEVER_RUN) — AutoEval pending=" .. tostring(auto.pending) .. " lastStatus=" .. tostring(auto.lastStatus))
		else
			print(string.format(
				"|cff4ecdc4[SmartTSM]|r Last reeval: status=%s reason=%s ahScan=%s count=%s",
				tostring(eval.status),
				tostring(meta.reason),
				tostring(meta.startedAhScan),
				tostring(meta.count)
			))
			print("|cff4ecdc4[SmartTSM]|r " .. tostring(eval.label))
		end
		if Health and Health.GetReport then
			local h = Health.GetReport()
			if h.loadError or h.loggerOk == false then
				print("|cffff6666[SmartTSM]|r Bootstrap/Logger-Problem: " .. tostring(h.loadError or h.loggerError or "unknown"))
			end
		end
		local Freshness = Smart:GetModule("Freshness")
		local realm = Freshness and select(1, Freshness.GetCategoryTimestamp("realm"))
		local region = Freshness and select(1, Freshness.GetCategoryTimestamp("region"))
		print(string.format(
			"|cff4ecdc4[SmartTSM]|r AuctionDB freshness: realm=%s region=%s",
			realm and Time.ISO(realm) or "unknown",
			region and Time.ISO(region) or "unknown"
		))
		print("|cff4ecdc4[SmartTSM]|r Slash registered=" .. tostring(Commands.IsRegistered()))
	elseif cmd == "errors" then
		SlashDiag.Errors(tonumber(rest) or 15)
	elseif cmd == "diagnose" then
		SlashDiag.Diagnose()
		print("|cff4ecdc4[SmartTSM]|r Slash registered=" .. tostring(Commands.IsRegistered()))
	elseif cmd == "debug" then
		SlashDiag.DebugToggle()
	elseif cmd == "reset" then
		SlashDiag.Reset(rest)
	elseif cmd == "scan" or cmd == "reeval" or cmd == "reevaluate" then
		-- Manual reevaluation of bag items using existing TSM data — NEVER starts an AH scan.
		local ScanService = Smart:GetModule("ScanService")
		local PostingCache = Smart:GetModule("PostingCache")
		if rest == "invalidate" then
			PostingCache.InvalidateAll()
			print("|cff4ecdc4[SmartTSM]|r Posting-Cache geleert")
		end
		local results = ScanService.ReevaluateBags({ reason = "manual_command", incremental = false })
		local sum = ScanService.Summarize(results)
		local meta = ScanService.GetLastMeta()
		local quick = 0
		local profit = 0
		local rare = 0
		local C = Smart:Module("Constants")
		for _, d in ipairs(results or {}) do
			if d and d.strategy == C.STRATEGIES.QUICK_SELL then
				quick = quick + 1
			elseif d and d.strategy == C.STRATEGIES.PROFIT_SELL then
				profit = profit + 1
			elseif d and d.strategy == C.STRATEGIES.RARE_SELL then
				rare = rare + 1
			end
		end
		print(string.format(
			"|cff4ecdc4[SmartTSM]|r Neubewertung (kein AH-Scan): quick=%d profit=%d rare=%d vendor=%d hold=%d review=%d needLive=%d",
			quick,
			profit,
			rare,
			sum.vendor,
			sum.hold,
			sum.review,
			sum.needsLiveCompetition
		))
		local settings = WoWSmartTSM_DB and WoWSmartTSM_DB.settings
		local openUi = settings and settings.openUIAfterScan
		if rest == "show" or rest == "ui" then
			openUi = true
		end
		if openUi then
			openUI()
		else
			print("|cff4ecdc4[SmartTSM]|r UI nicht geöffnet (openUIAfterScan=false). /smarttsm show oder /smarttsm scan show")
		end
	elseif cmd == "importstring" or cmd == "import" then
		local str = WoWSmartTSM_DB and WoWSmartTSM_DB.lastGroupImportString
		if not str or str == "" then
			local Groups = Smart:GetModule("Groups")
			str = Groups and Groups.GetLastImportString and Groups.GetLastImportString()
		end
		if not str or str == "" then
			print("|cffffcc00[SmartTSM]|r Kein Import-String gespeichert. Zuerst TSM-Gruppen → sichere Vorschläge.")
		else
			print("|cff4ecdc4[SmartTSM]|r TSM Groups Import-String (" .. tostring(#str) .. " Zeichen):")
			-- chunk print for chat limits
			local i = 1
			while i <= #str do
				print(str:sub(i, i + 240))
				i = i + 241
			end
			print("|cff4ecdc4[SmartTSM]|r → TSM öffnen → Groups → Import")
		end
	elseif cmd == "groups" then
		openUI()
		local MainFrame = Smart:GetModule("MainFrame")
		if MainFrame and MainFrame.SelectTab then
			MainFrame.SelectTab("Groups")
		end
	elseif cmd == "operations" or cmd == "ops" then
		openUI()
		local MainFrame = Smart:GetModule("MainFrame")
		if MainFrame and MainFrame.SelectTab then
			MainFrame.SelectTab("Operations")
		end
	elseif cmd == "groupsearch" then
		local GroupsTab = Smart:GetModule("GroupsTab")
		if GroupsTab and GroupsTab.SetSearch then
			GroupsTab.SetSearch(rest or "")
			print("|cff4ecdc4[SmartTSM]|r Gruppensuche:", rest ~= "" and rest or "(leer)")
		end
		openUI()
		local MainFrame = Smart:GetModule("MainFrame")
		if MainFrame and MainFrame.SelectTab then
			MainFrame.SelectTab("Groups")
		end
	elseif cmd == "setup" then
		openUI()
		local MainFrame = Smart:GetModule("MainFrame")
		if MainFrame and MainFrame.SelectTab then
			MainFrame.SelectTab("Setup")
		end
	elseif cmd == "help" then
		print("|cff4ecdc4[SmartTSM]|r /smarttsm [show|scan|reeval|groups|operations|groupsearch|setup|importstring|status|errors|diagnose|debug|reset|help]")
		print("|cff4ecdc4[SmartTSM]|r scan/reeval = Taschen anhand TSM-Daten neu bewerten (kein AH-Scan)")
		print("|cff4ecdc4[SmartTSM]|r groups/operations/setup | groupsearch <text> | importstring")
		print("|cff4ecdc4[SmartTSM]|r scan show = Neubewertung und UI öffnen; Einstellung: openUIAfterScan")
	else
		print("|cff4ecdc4[SmartTSM]|r Unknown command. /smarttsm help")
	end
end

function Commands.IsRegistered()
	return private.registered == true
		and type(_G.SlashCmdList) == "table"
		and type(_G.SlashCmdList.SMARTTSM) == "function"
		and _G.SLASH_SMARTTSM1 == "/smarttsm"
end

function Commands.Register()
	-- Idempotent: safe to call from ADDON_LOADED and PLAYER_LOGIN fallback
	_G.SLASH_SMARTTSM1 = "/smarttsm"
	_G.SLASH_SMARTTSM2 = "/wsmarttsm"
	if type(_G.SlashCmdList) ~= "table" then
		-- Extremely defensive: should always exist in WoW
		_G.SlashCmdList = _G.SlashCmdList or {}
	end
	_G.SlashCmdList["SMARTTSM"] = function(msg)
		local ok, err = pcall(Commands.Handle, msg)
		if not ok then
			print("|cffff6666[SmartTSM]|r slash error: " .. tostring(err))
			local Logger = Smart:GetModule("Logger")
			if Logger and Logger.Error then
				Logger.Error("UI_ERROR", "Commands", "SlashCmd", tostring(err))
			end
		end
	end
	private.registered = true
	return true
end
