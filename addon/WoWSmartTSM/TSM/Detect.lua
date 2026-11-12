local Smart = WoWSmartTSM
local Logger = Smart:Module("Logger")
local Version = Smart:Module("Version")
local Prices = Smart:Module("Prices")
local Detect = Smart:Module("Detect")

local function isAddOnLoaded(name)
	if C_AddOns and C_AddOns.IsAddOnLoaded then
		return C_AddOns.IsAddOnLoaded(name)
	end
	if IsAddOnLoaded then
		return IsAddOnLoaded(name)
	end
	return false
end

function Detect.GetStatus()
	local tsmLoaded = isAddOnLoaded("TradeSkillMaster")
	local appHelper = isAddOnLoaded("TradeSkillMaster_AppHelper")
	local dataTap = isAddOnLoaded("!SmartTSM_DataTap")
	local ver = Version.GetTSMVersion()
	local supported = false
	if ver then
		local major, minor = ver:match("v?(%d+)%.(%d+)")
		major, minor = tonumber(major), tonumber(minor)
		if major and minor and (major > 4 or (major == 4 and minor >= 15)) then
			supported = true
		end
	end
	local tap = _G.SmartTSM_AppDataFreshness
	local sources = Prices.VerifyRegisteredSources and Prices.VerifyRegisteredSources() or {}
	return {
		tsmLoaded = tsmLoaded,
		appHelperLoaded = appHelper,
		dataTapLoaded = dataTap,
		tsmVersion = ver,
		supported = supported,
		tsmApiReady = Prices.IsApiReady and Prices.IsApiReady() or false,
		realmDownloadTime = tap and tap.realmDownloadTime or 0,
		regionDownloadTime = tap and tap.regionDownloadTime or 0,
		priceSources = sources,
	}
end

function Detect.Diagnose()
	local st = Detect.GetStatus()
	if not st.tsmLoaded then
		Logger.Warning("TSM_NOT_FOUND", "Detect", "Diagnose", "TradeSkillMaster not loaded")
	elseif not st.supported then
		Logger.Warning("TSM_VERSION_UNSUPPORTED", "Detect", "Diagnose", "TSM version may be unsupported: " .. tostring(st.tsmVersion))
	end
	if not st.appHelperLoaded then
		Logger.Warning("APPHELPER_MISSING", "Detect", "Diagnose", "TradeSkillMaster_AppHelper not loaded — market data may be missing")
	end
	if not st.dataTapLoaded then
		Logger.Warning("UNKNOWN", "Detect", "Diagnose", "!SmartTSM_DataTap not loaded — AuctionDB downloadTime may be unknown")
	end
	if not st.tsmApiReady then
		Logger.Warning("TSM_NOT_FOUND", "Detect", "Diagnose", "TSM_API.GetCustomPriceValue unavailable")
	end
	print(string.format(
		"|cff4ecdc4[SmartTSM]|r Detect: TSM=%s ver=%s AppHelper=%s DataTap=%s API=%s realmDT=%s regionDT=%s",
		tostring(st.tsmLoaded),
		tostring(st.tsmVersion),
		tostring(st.appHelperLoaded),
		tostring(st.dataTapLoaded),
		tostring(st.tsmApiReady),
		tostring(st.realmDownloadTime),
		tostring(st.regionDownloadTime)
	))
	return st
end
