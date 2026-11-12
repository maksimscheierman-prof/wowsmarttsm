local Smart = WoWSmartTSM
local Logger = Smart:Module("Logger")
local Coverage = Smart:Module("Coverage")

function Coverage.GetReport()
	local cov = Logger.GetCoverage() or {}
	local hasBugSack = (_G.BugSack ~= nil) or (C_AddOns and C_AddOns.IsAddOnLoaded and C_AddOns.IsAddOnLoaded("BugSack"))
	return {
		ownErrors = cov.ownErrors or 0,
		capturedLuaErrors = cov.capturedLuaErrors or 0,
		suppressedDuplicates = cov.suppressedDuplicates or 0,
		bugSackPresent = hasBugSack and true or false,
		coverageNote = "SmartTSM captures its own logged errors and chained seterrorhandler messages. It cannot guarantee capture of all third-party addon errors.",
		limitation = "If WoW crashes before SavedVariables flush, in-memory errors are lost.",
	}
end
