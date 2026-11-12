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

local private = {
	loaded = false,
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

local function onLoaded()
	if private.loaded then
		return
	end
	private.loaded = true
	SV.Init()
	Logger.Init()
	Logger.InstallErrorHandler()
	Commands.Register()
	UI.Init()
	PostingCache.Init()
	AutoEval.Init()
	Prices.VerifyRegisteredSources()
	Logger.Info("UNKNOWN", "Addon", "ADDON_LOADED", "WoW Smart TSM " .. Version.GetAddonVersion() .. " loaded (TSM-data reeval, no AH scan)")
end

frame:SetScript("OnEvent", function(_, event, arg1)
	if event == "ADDON_LOADED" and arg1 == Smart.ADDON_NAME then
		local ok, err = pcall(onLoaded)
		if not ok then
			print("|cffff6666[WoW Smart TSM]|r load failed: " .. tostring(err))
			-- Still try to expose slash for diagnostics
			pcall(Commands.Register)
		end
	elseif event == "PLAYER_LOGIN" then
		-- Fallback: ensure slash exists even if ADDON_LOADED path had issues
		ensureSlash()
		if Commands.IsRegistered and Commands.IsRegistered() then
			-- ok
		else
			print("|cffff6666[SmartTSM]|r WARN: /smarttsm nicht registriert — Commands.Register fehlgeschlagen")
		end
		Detect.Diagnose()
		local tap = _G.SmartTSM_AppDataFreshness
		local realmTs = tap and tap.realmDownloadTime or 0
		local regionTs = tap and tap.regionDownloadTime or 0
		print("|cff4ecdc4[WoW Smart TSM]|r " .. Version.GetAddonVersion() .. " — /smarttsm (nutzt TSM AuctionDB, startet keinen AH-Scan)")
		print("|cff4ecdc4[SmartTSM]|r Slash OK=" .. tostring(Commands.IsRegistered and Commands.IsRegistered()))
		if realmTs == 0 and regionTs == 0 then
			print("|cffffcc00[SmartTSM]|r Kein AppHelper-downloadTime erfasst — DataTap/AppHelper prüfen. Preise ggf. trotzdem via TSM_API.")
		end
	elseif event == "AUCTION_HOUSE_SHOW" then
		if WoWSmartTSM_DB and WoWSmartTSM_DB.settings and WoWSmartTSM_DB.settings.debug then
			print("|cff4ecdc4[SmartTSM]|r AH geöffnet — Daten aus TSM; /smarttsm scan = Neubewertung ohne AH-Scan")
		end
	end
end)
