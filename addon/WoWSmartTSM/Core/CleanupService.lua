local Smart = WoWSmartTSM
local C = Smart:Module("Constants")
local CleanupService = Smart:Module("CleanupService")

function CleanupService.Summarize(results)
	results = results or (Smart:GetModule("ScanService").GetLastResults() or {})
	local sum = {
		mailToBank = 0,
		vendor = 0,
		keep = 0,
		holdAtBank = 0,
		review = 0,
		ignore = 0,
		needsBankConfig = false,
		n = #results,
	}
	for _, d in ipairs(results) do
		if not d then
			-- skip
		elseif d.needsBankConfig then
			sum.needsBankConfig = true
		end
		local a = d and d.inventoryAction
		if a == C.ACTIONS.MAIL_TO_BANK then
			sum.mailToBank = sum.mailToBank + 1
		elseif a == C.ACTIONS.VENDOR then
			sum.vendor = sum.vendor + 1
		elseif a == C.ACTIONS.KEEP then
			sum.keep = sum.keep + 1
		elseif a == C.ACTIONS.HOLD_AT_BANK then
			sum.holdAtBank = sum.holdAtBank + 1
		elseif a == C.ACTIONS.IGNORE then
			sum.ignore = sum.ignore + 1
		else
			sum.review = sum.review + 1
		end
	end
	return sum
end

function CleanupService.Filter(results, actionFilter)
	results = results or {}
	if not actionFilter or actionFilter == "ALL" then
		return results
	end
	local out = {}
	for _, d in ipairs(results) do
		if d and d.inventoryAction == actionFilter then
			out[#out + 1] = d
		elseif actionFilter == "UNSAFE" and d and (d.inventoryAction == C.ACTIONS.MANUAL_REVIEW or (d.actionConfidence or 1) < 0.5) then
			out[#out + 1] = d
		end
	end
	return out
end

function CleanupService.ActionLabel(action)
	local map = {
		MAIL_TO_BANK = "An Bank senden",
		VENDOR = "Händler",
		KEEP = "Behalten",
		IGNORE = "Ignorieren",
		HOLD_AT_BANK = "Hold → Bank",
		MANUAL_REVIEW = "Prüfung",
	}
	return map[action] or tostring(action or "?")
end
