local Smart = WoWSmartTSM
local Logger = Smart:Module("Logger")
local Version = Smart:Module("Version")
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
	local ver = Version.GetTSMVersion()
	local supported = false
	if ver then
		local major, minor = ver:match("v?(%d+)%.(%d+)")
		major, minor = tonumber(major), tonumber(minor)
		if major and minor and (major > 4 or (major == 4 and minor >= 15)) then
			supported = true
		end
	end
	return {
		tsmLoaded = tsmLoaded,
		appHelperLoaded = appHelper,
		tsmVersion = ver,
		supported = supported,
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
	print("|cff4ecdc4[SmartTSM]|r Detect: TSM=" .. tostring(st.tsmLoaded) .. " ver=" .. tostring(st.tsmVersion) .. " AppHelper=" .. tostring(st.appHelperLoaded))
	return st
end
