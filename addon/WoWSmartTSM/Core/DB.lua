local Smart = WoWSmartTSM
local SV = Smart:Module("SavedVariables")
local DB = Smart:Module("DB")

function DB.Settings()
	return SV.GetDB().settings
end

function DB.AlwaysKeep()
	return SV.GetDB().alwaysKeep
end

function DB.IsAlwaysKeep(itemString)
	return SV.GetDB().alwaysKeep[itemString] == true
end

function DB.SetAlwaysKeep(itemString, enabled)
	SV.GetDB().alwaysKeep[itemString] = enabled and true or nil
end
