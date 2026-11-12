local Smart = WoWSmartTSM
local Health = Smart:Module("Health")

local function isAddOnLoaded(name)
	if C_AddOns and C_AddOns.IsAddOnLoaded then
		return C_AddOns.IsAddOnLoaded(name)
	end
	if IsAddOnLoaded then
		return IsAddOnLoaded(name)
	end
	return false
end

function Health.GetReport()
	local Detect = Smart:GetModule("Detect")
	local Prices = Smart:GetModule("Prices")
	local Logger = Smart:GetModule("Logger")
	local ScanService = Smart:GetModule("ScanService")
	local AutoEval = Smart:GetModule("AutoEval")
	local Freshness = Smart:GetModule("Freshness")
	local Commands = Smart:GetModule("Commands")
	local Coverage = Smart:GetModule("Coverage")
	local ItemAPI = Smart:GetModule("ItemAPI")

	local detect = Detect and Detect.GetStatus and Detect.GetStatus() or {}
	local itemCaps = ItemAPI and ItemAPI.GetCapabilities and ItemAPI.GetCapabilities() or {}
	local loggerInit = Logger and Logger.GetInitStatus and Logger.GetInitStatus() or {}
	local meta = ScanService and ScanService.GetLastMeta and ScanService.GetLastMeta() or {}
	local evalState = ScanService and ScanService.GetEvalStatus and ScanService.GetEvalStatus() or {}
	local auto = AutoEval and AutoEval.GetState and AutoEval.GetState() or {}
	local cov = Coverage and Coverage.GetReport and Coverage.GetReport() or (Logger and Logger.GetCoverage and Logger.GetCoverage()) or {}
	local entries = Logger and Logger.GetEntries and Logger.GetEntries() or {}
	local lastErr = nil
	for i = #entries, 1, -1 do
		local e = entries[i]
		if e and (e.severity == "ERROR" or e.severity == "CRITICAL") then
			lastErr = e
			break
		end
	end

	local realmTs = Freshness and select(1, Freshness.GetCategoryTimestamp("realm")) or nil
	local regionTs = Freshness and select(1, Freshness.GetCategoryTimestamp("region")) or nil

	local loadError = (Smart.GetLoadError and Smart.GetLoadError())
		or (WoWSmartTSM_Diagnostics and WoWSmartTSM_Diagnostics.loadError)
		or nil
	if loadError and not lastErr then
		lastErr = { code = "LOAD", message = loadError }
	end

	return {
		addonLoaded = true,
		loggerOk = loggerInit.ok == true and not loadError,
		loggerError = loggerInit.error or loadError,
		loadError = loadError,
		slashOk = Commands and Commands.IsRegistered and Commands.IsRegistered() or false,
		tsmApi = Prices and Prices.IsApiReady and Prices.IsApiReady() or false,
		tsmLoaded = detect.tsmLoaded,
		appHelper = detect.appHelperLoaded,
		dataTap = detect.dataTapLoaded or isAddOnLoaded("!SmartTSM_DataTap"),
		evalStatus = evalState.status or "NEVER_RUN",
		evalLabel = evalState.label or "Noch keine Bewertung durchgeführt",
		lastEvalAt = meta.at,
		lastEvalReason = meta.reason,
		lastEvalCount = meta.count or 0,
		lastError = lastErr and (tostring(lastErr.code) .. " " .. tostring(lastErr.message)) or nil,
		realmDataAge = realmTs,
		regionDataAge = regionTs,
		coverage = cov,
		autoEval = auto,
		itemApi = itemCaps.preferredInfoAPI,
		bagApi = itemCaps.preferredBagAPI,
		itemCaps = itemCaps,
	}
end
