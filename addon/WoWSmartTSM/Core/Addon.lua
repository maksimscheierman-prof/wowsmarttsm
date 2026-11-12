local Smart = WoWSmartTSM
local SV = Smart:Module("SavedVariables")
local Logger = Smart:Module("Logger")
local Commands = Smart:Module("Commands")
local Detect = Smart:Module("Detect")
local UI = Smart:Module("UI")
local Version = Smart:Module("Version")
local AutoEval = Smart:Module("AutoEval")
local PostingCache = Smart:Module("PostingCache")
local Prices = Smart:Module("Prices")
local ItemAPI = Smart:Module("ItemAPI")
local CharacterProfiles = Smart:Module("CharacterProfiles")

local private = {
	loaded = false,
	loadError = nil,
}

local frame = CreateFrame("Frame", "WoWSmartTSMEventFrame")
frame:RegisterEvent("ADDON_LOADED")
frame:RegisterEvent("PLAYER_LOGIN")
frame:RegisterEvent("AUCTION_HOUSE_SHOW")
frame:RegisterEvent("AUCTION_HOUSE_CLOSED")

local function ensureSlash()
	if not Commands.IsRegistered or not Commands.IsRegistered() then
		Commands.Register()
	end
end

local function recordLoadFailure(err)
	private.loadError = tostring(err)
	print("|cffff6666[WoW Smart TSM]|r load failed: " .. tostring(err))
	-- Persist into diagnostics SV if already available so UI does not show a clean state
	WoWSmartTSM_Diagnostics = WoWSmartTSM_Diagnostics or {}
	WoWSmartTSM_Diagnostics.loadError = private.loadError
	WoWSmartTSM_Diagnostics.initStatus = {
		ok = false,
		failed = true,
		error = private.loadError,
	}
	pcall(function()
		if Logger and Logger.Error then
			Logger.Error("UNKNOWN", "Addon", "ADDON_LOADED", tostring(err), {
				state = { phase = "bootstrap" },
			})
		end
	end)
	pcall(Commands.Register)
end

local function onLoaded()
	if private.loaded then
		return
	end
	private.loaded = true

	-- SavedVariables first so Logger can persist early failures
	local okSV, errSV = pcall(SV.Init)
	if not okSV then
		recordLoadFailure("SavedVariables.Init: " .. tostring(errSV))
	end

	local okLog, errLog = pcall(Logger.Init)
	if not okLog then
		recordLoadFailure("Logger.Init: " .. tostring(errLog))
	elseif Logger.GetInitStatus then
		local st = Logger.GetInitStatus()
		if st and st.failed then
			-- Soft fail: logging still works via fallback buffer — surface in diagnostics, continue boot
			WoWSmartTSM_Diagnostics = WoWSmartTSM_Diagnostics or {}
			WoWSmartTSM_Diagnostics.initStatus = st
			print("|cffffcc00[SmartTSM]|r Logger soft-fail: " .. tostring(st.error))
		end
	end

	pcall(Logger.InstallErrorHandler)
	pcall(ItemAPI.Init)
	ItemAPI.SetPendingResolvedHandler(function(itemId)
		if AutoEval and AutoEval.Request then
			AutoEval.Request("item_info_received", { "item:" .. tostring(itemId) })
		end
	end)
	pcall(CharacterProfiles.EnsureCurrent)
	pcall(Commands.Register)
	pcall(UI.Init)
	pcall(PostingCache.Init)
	local ch = CharacterProfiles.GetCurrent and CharacterProfiles.GetCurrent()
	if not ch or ch.autoEval ~= false then
		pcall(AutoEval.Init)
	end
	pcall(Prices.VerifyRegisteredSources)

	if not private.loadError then
		Logger.Info(
			"UNKNOWN",
			"Addon",
			"ADDON_LOADED",
			"WoW Smart TSM " .. Version.GetAddonVersion() .. " loaded (TSM-data reeval, no AH scan)"
		)
	end
end

function Smart.GetLoadError()
	return private.loadError
end

frame:SetScript("OnEvent", function(_, event, arg1)
	if event == "ADDON_LOADED" and arg1 == Smart.ADDON_NAME then
		local ok, err = pcall(onLoaded)
		if not ok then
			recordLoadFailure(err)
		end
	elseif event == "PLAYER_LOGIN" then
		ensureSlash()
		if Commands.IsRegistered and Commands.IsRegistered() then
			-- ok
		else
			print("|cffff6666[SmartTSM]|r WARN: /smarttsm nicht registriert — Commands.Register fehlgeschlagen")
		end
		-- Catch-up AutoEval if Init ran before login events
		if AutoEval and AutoEval.Request then
			local st = AutoEval.GetState and AutoEval.GetState() or {}
			if not st.bootstrapped or st.lastStatus == "IDLE" then
				AutoEval.Request("player_login_catchup")
			end
		end
		pcall(Detect.Diagnose)
		local Groups = Smart:GetModule("Groups")
		if Groups and Groups.RegisterRefreshCallback then
			pcall(Groups.RegisterRefreshCallback, function()
				local ScanService = Smart:GetModule("ScanService")
				if ScanService and ScanService.ReevaluateBags then
					ScanService.ReevaluateBags({ reason = "tsm_group_callback", incremental = true })
				end
			end)
		end
		local tap = _G.SmartTSM_AppDataFreshness
		local realmTs = tap and tap.realmDownloadTime or 0
		local regionTs = tap and tap.regionDownloadTime or 0
		print("|cff4ecdc4[WoW Smart TSM]|r " .. Version.GetAddonVersion() .. " — /smarttsm (nutzt TSM AuctionDB, startet keinen AH-Scan)")
		print("|cff4ecdc4[SmartTSM]|r Slash OK=" .. tostring(Commands.IsRegistered and Commands.IsRegistered()))
		if private.loadError then
			print("|cffff6666[SmartTSM]|r Bootstrap-Fehler: " .. tostring(private.loadError))
		end
		if realmTs == 0 and regionTs == 0 then
			print("|cffffcc00[SmartTSM]|r Kein AppHelper-downloadTime erfasst — DataTap/AppHelper prüfen. Preise ggf. trotzdem via TSM_API.")
		end
	elseif event == "AUCTION_HOUSE_SHOW" then
		if WoWSmartTSM_DB and WoWSmartTSM_DB.settings and WoWSmartTSM_DB.settings.debug then
			print("|cff4ecdc4[SmartTSM]|r AH geöffnet — Daten aus TSM; /smarttsm scan = Neubewertung ohne AH-Scan")
		end
	end
end)
