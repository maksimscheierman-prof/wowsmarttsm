local Smart = WoWSmartTSM
local Locale = Smart:Module("Locale")

function Locale.Get()
	local code = (WoWSmartTSM_DB and WoWSmartTSM_DB.settings and WoWSmartTSM_DB.settings.locale) or "deDE"
	local data = Smart:GetModule("LocaleData_" .. code) or Smart:GetModule("LocaleData_deDE")
	return data, code
end

function Locale.T(key)
	local data = Locale.Get()
	return data[key] or key
end
