local Smart = WoWSmartTSM
local Logger = Smart:Module("Logger")
local Coverage = Smart:Module("Coverage")

function Coverage.GetReport()
	local cov = Logger.GetCoverage() or {}
	local hasBugSack = (_G.BugSack ~= nil) or (C_AddOns and C_AddOns.IsAddOnLoaded and C_AddOns.IsAddOnLoaded("BugSack"))
	local init = Logger.GetInitStatus and Logger.GetInitStatus() or {}
	return {
		ownErrors = cov.ownErrors or 0,
		capturedLuaErrors = cov.capturedLuaErrors or 0,
		suppressedDuplicates = cov.suppressedDuplicates or 0,
		earlyErrors = cov.earlyErrors or 0,
		loggerInitOk = init.ok == true,
		loggerInitError = init.error,
		bugSackPresent = hasBugSack and true or false,
		coverageNote = "SmartTSM captures own Logger.Error/Critical entries and chained seterrorhandler messages. Load-time failures before InstallErrorHandler are stored as earlyErrors/loadError when possible.",
		limitation = "Errors during file parse (before ADDON_LOADED) or crashes before SavedVariables flush are not always visible. Coverage own/lua/dupes=0 does NOT prove a clean load if loadError/initStatus.failed is set.",
		note = cov.note,
	}
end
