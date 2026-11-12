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
		local meta = ScanService.GetLastMeta and ScanService.GetLastMeta() or {}
		print(string.format(
			"|cff4ecdc4[SmartTSM]|r Last reeval: reason=%s ahScan=%s count=%s",
			tostring(meta.reason),
			tostring(meta.startedAhScan),
			tostring(meta.count)
		))
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
		print(string.format(
			"|cff4ecdc4[SmartTSM]|r Neubewertung (kein AH-Scan): post=%d vendor=%d hold=%d review=%d needLive=%d cacheHits=%d",
			sum.toPost,
			sum.vendor,
			sum.hold,
			sum.review,
			sum.needsLiveCompetition,
			meta.postingCacheHits or 0
		))
		openUI()
	elseif cmd == "help" then
		print("|cff4ecdc4[SmartTSM]|r /smarttsm [show|scan|reeval|status|errors|diagnose|debug|reset|help]")
		print("|cff4ecdc4[SmartTSM]|r scan/reeval = Taschen anhand TSM-Daten neu bewerten (kein AH-Scan)")
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
