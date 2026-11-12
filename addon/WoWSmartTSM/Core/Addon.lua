local Smart = WoWSmartTSM
local SV = Smart:Module("SavedVariables")
local Logger = Smart:Module("Logger")
local Commands = Smart:Module("Commands")
local Detect = Smart:Module("Detect")
local UI = Smart:Module("UI")
local Version = Smart:Module("Version")

local frame = CreateFrame("Frame", "WoWSmartTSMEventFrame")
frame:RegisterEvent("ADDON_LOADED")
frame:RegisterEvent("PLAYER_LOGIN")
frame:RegisterEvent("AUCTION_HOUSE_SHOW")
frame:RegisterEvent("AUCTION_HOUSE_CLOSED")

frame:SetScript("OnEvent", function(_, event, arg1)
	if event == "ADDON_LOADED" and arg1 == Smart.ADDON_NAME then
		SV.Init()
		Logger.Init()
		Logger.InstallErrorHandler()
		Commands.Register()
		UI.Init()
		Logger.Info("UNKNOWN", "Addon", "ADDON_LOADED", "WoW Smart TSM " .. Version.GetAddonVersion() .. " loaded")
	elseif event == "PLAYER_LOGIN" then
		Detect.Diagnose()
		print("|cff4ecdc4[WoW Smart TSM]|r " .. Version.GetAddonVersion() .. " — /smarttsm")
	elseif event == "AUCTION_HOUSE_SHOW" then
		-- Soft integration: do not patch TSM frames
		if WoWSmartTSM_DB and WoWSmartTSM_DB.settings and WoWSmartTSM_DB.settings.debug then
			print("|cff4ecdc4[SmartTSM]|r AH geöffnet — /smarttsm scan")
		end
	end
end)
