local Smart = WoWSmartTSM
local Version = Smart:Module("Version")

Version.STRING = "0.2.2"
Version.BUILD = 9

function Version.GetAddonVersion()
	return Version.STRING
end

function Version.GetClientInfo()
	local version, build, date, toc = GetBuildInfo()
	return {
		version = version,
		build = build,
		date = date,
		tocversion = toc,
	}
end

function Version.GetTSMVersion()
	local GetAddOnMetadata = C_AddOns and C_AddOns.GetAddOnMetadata or GetAddOnMetadata
	if not GetAddOnMetadata then
		return nil
	end
	local ok, ver = pcall(GetAddOnMetadata, "TradeSkillMaster", "Version")
	if ok then
		return ver
	end
	return nil
end
