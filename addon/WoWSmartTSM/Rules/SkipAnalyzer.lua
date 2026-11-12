local Smart = WoWSmartTSM
local Money = Smart:Module("MoneyUtil")
local Recommend = Smart:Module("Recommend")
local SkipAnalyzer = Smart:Module("SkipAnalyzer")

--[[
Structured reason codes — never generic "Not posted" alone.
Maps known TSM AuctioningOperation.RESULT semantics when provided.
]]

SkipAnalyzer.CODES = {
	COMPETITION_BELOW_MIN = "COMPETITION_BELOW_MIN",
	MARKET_MISSING = "MARKET_MISSING",
	MARKET_STALE = "MARKET_STALE",
	PRICE_SOURCE_INVALID = "PRICE_SOURCE_INVALID",
	LOW_EXPECTED_MARGIN = "LOW_EXPECTED_MARGIN",
	DEPOSIT_RISK_HIGH = "DEPOSIT_RISK_HIGH",
	LOW_DEMAND = "LOW_DEMAND",
	ENOUGH_AUCTIONS = "ENOUGH_AUCTIONS",
	POST_CAP = "POST_CAP",
	NOT_GROUPED = "NOT_GROUPED",
	INVALID_OPERATION = "INVALID_OPERATION",
	PROTECTED = "PROTECTED",
	AH_UNAVAILABLE = "AH_UNAVAILABLE",
	API_LIMIT = "API_LIMIT",
	DISABLED = "DISABLED",
	NOT_ENOUGH = "NOT_ENOUGH",
	MAX_EXPIRES = "MAX_EXPIRES",
	ABOVE_MAX_NO_POST = "ABOVE_MAX_NO_POST",
	UNKNOWN = "UNKNOWN",
	INSUFFICIENT_DATA = "INSUFFICIENT_DATA",
}

---Map TSM-like result tokens to Smart reason codes.
function SkipAnalyzer.MapTSMResult(token)
	if not token then
		return SkipAnalyzer.CODES.UNKNOWN
	end
	local t = tostring(token)
	if t:find("BELOW_MIN") then
		return SkipAnalyzer.CODES.COMPETITION_BELOW_MIN
	end
	if t:find("DISABLED") then
		return SkipAnalyzer.CODES.DISABLED
	end
	if t:find("NOT_ENOUGH") then
		return SkipAnalyzer.CODES.NOT_ENOUGH
	end
	if t:find("MAX_EXPIRES") then
		return SkipAnalyzer.CODES.MAX_EXPIRES
	end
	if t:find("ABOVE_MAX") then
		return SkipAnalyzer.CODES.ABOVE_MAX_NO_POST
	end
	if t:find("POST_CAP") then
		return SkipAnalyzer.CODES.POST_CAP
	end
	if t:find("MIN_PRICE") or t:find("MAX_PRICE") or t:find("NORMAL_PRICE") then
		return SkipAnalyzer.CODES.INVALID_OPERATION
	end
	return SkipAnalyzer.CODES.UNKNOWN
end

function SkipAnalyzer.Analyze(profile, decision, tsmSkipToken)
	local code = SkipAnalyzer.CODES.UNKNOWN
	local details = {}
	local insufficient = false

	if tsmSkipToken then
		code = SkipAnalyzer.MapTSMResult(tsmSkipToken)
	elseif decision and decision.pricing then
		local pr = decision.pricing.reasons or {}
		for _, r in ipairs(pr) do
			if r == "COMPETITION_BELOW_OPERATION_MIN" then
				code = SkipAnalyzer.CODES.COMPETITION_BELOW_MIN
			elseif r == "DEPOSIT_RISK_TOO_HIGH" then
				code = SkipAnalyzer.CODES.DEPOSIT_RISK_HIGH
			elseif r == "NO_POSITIVE_EV_CANDIDATE" or r == "LOW_EXPECTED_MARGIN" then
				code = SkipAnalyzer.CODES.LOW_EXPECTED_MARGIN
			elseif r == "THIN_OR_STALE_DATA_CONSERVATIVE" then
				code = SkipAnalyzer.CODES.MARKET_STALE
				insufficient = true
			end
		end
	end

	if profile then
		if profile.marketValue == nil and profile.regionMarket == nil then
			if code == SkipAnalyzer.CODES.UNKNOWN then
				code = SkipAnalyzer.CODES.MARKET_MISSING
			end
			insufficient = true
		end
		if profile.stale then
			if code == SkipAnalyzer.CODES.UNKNOWN then
				code = SkipAnalyzer.CODES.MARKET_STALE
			end
		end
		if (profile.saleRate or 1) < 0.05 and (profile.soldPerDay or 0) < 0.2 then
			if code == SkipAnalyzer.CODES.LOW_EXPECTED_MARGIN or code == SkipAnalyzer.CODES.UNKNOWN then
				code = SkipAnalyzer.CODES.LOW_DEMAND
			end
		end
		details.operationMin = profile.operationMinPrice
		details.competition = profile.minBuyout
		details.marketValue = profile.marketValue
		details.deposit = profile.deposit
	end

	if insufficient then
		details.insufficientData = true
	end

	local tips = Recommend.FromDecision(decision or { strategy = "MANUAL_REVIEW" })
	if code == SkipAnalyzer.CODES.COMPETITION_BELOW_MIN then
		tips[#tips + 1] = "EVALUATE_LOWER_PRICE_OR_QUICK_SELL"
	end

	return {
		status = "SKIPPED",
		code = code,
		details = details,
		recommendations = tips,
		formatted = SkipAnalyzer.Format(profile, code, details, tips),
	}
end

function SkipAnalyzer.Format(profile, code, details, tips)
	local name = (profile and profile.name) or "?"
	local lines = {
		name,
		"Status: SKIPPED",
		"Grund: " .. tostring(code),
	}
	if details.operationMin then
		lines[#lines + 1] = "Bisheriges Minimum: " .. Money.Format(details.operationMin, true)
	end
	if details.competition then
		lines[#lines + 1] = "Konkurrenz: " .. Money.Format(details.competition, true)
	end
	if details.marketValue then
		lines[#lines + 1] = "Marktwert: " .. Money.Format(details.marketValue, true)
	end
	if details.insufficientData then
		lines[#lines + 1] = "Datenlage: UNZUREICHEND — Empfehlung vorsichtig interpretieren"
	end
	if tips and tips[1] then
		lines[#lines + 1] = "Empfehlung: " .. tips[1]
	end
	return table.concat(lines, "\n")
end
