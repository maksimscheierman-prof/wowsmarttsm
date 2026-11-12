local Smart = WoWSmartTSM
local C = Smart:Module("Constants")
local HoldPolicy = Smart:Module("HoldPolicy")
local Protect = Smart:Module("Protect")
local Classify = Smart:Module("Classify")

local function reason(list, code)
	list[#list + 1] = code
end

---Deterministic classification. Sell first, hold rarely.
---@param profile table
---@return table decision
function Classify.Decide(profile)
	local Pricing = Smart:GetModule("PricingModel")
	local reasons = {}
	local protect = Protect.Evaluate(profile)
	local pricing = Pricing.Evaluate(profile)
	local holdEligible, holdDetails = HoldPolicy.Evaluate(profile)

	local decision = {
		itemString = profile.itemString,
		itemId = profile.itemId,
		name = profile.name,
		quality = profile.quality,
		className = profile.className,
		subclassName = profile.subclassName,
		vendorSell = profile.vendorSell,
		marketValue = profile.marketValue,
		minBuyout = profile.minBuyout,
		regionMarket = profile.regionMarket,
		saleRate = profile.saleRate,
		soldPerDay = profile.soldPerDay,
		numAuctions = profile.numAuctions,
		deposit = profile.deposit or pricing.estimatedDeposit,
		quantity = profile.quantity,
		strategy = C.STRATEGIES.MANUAL_REVIEW,
		targetGroup = C.GROUPS.REVIEW,
		confidence = profile.dataQuality or 0,
		dataQuality = profile.dataQuality or 0,
		reasons = reasons,
		pricing = pricing,
		hold = holdDetails,
		protect = protect,
		timestamp = profile.dataTimestamp,
		expectedNet = pricing.expectedNet,
		suggestedPrice = pricing.suggestedBuyout,
	}

	-- Insufficient data → protection, no blind vendor
	if profile.unknownIdentity then
		reason(reasons, "UNKNOWN_ITEM")
		decision.strategy = C.STRATEGIES.MANUAL_REVIEW
		decision.targetGroup = C.GROUPS.REVIEW
		return decision
	end

	if (profile.marketValue == nil and profile.regionMarket == nil and (profile.vendorSell or 0) == 0)
		or (profile.dataQuality or 0) < 0.25 then
		reason(reasons, "INSUFFICIENT_MARKET_DATA")
		decision.strategy = C.STRATEGIES.MANUAL_REVIEW
		decision.targetGroup = C.GROUPS.REVIEW
		return decision
	end

	-- Prefer AH when economically sensible
	if pricing.shouldPost then
		reason(reasons, "AH_PROFITABLE")
		if pricing.mode == "QUICK" then
			decision.strategy = C.STRATEGIES.QUICK_SELL
			decision.targetGroup = C.GROUPS.QUICK
			reason(reasons, "STRATEGY_QUICK_SELL")
		elseif pricing.mode == "RARE" then
			decision.strategy = C.STRATEGIES.RARE_SELL
			decision.targetGroup = C.GROUPS.RARE
			reason(reasons, "STRATEGY_RARE_SELL")
		else
			decision.strategy = C.STRATEGIES.PROFIT_SELL
			decision.targetGroup = C.GROUPS.PROFIT
			reason(reasons, "STRATEGY_PROFIT_SELL")
		end
		return decision
	end

	reason(reasons, "AH_NOT_PROFITABLE")

	-- Hold filter only when AH not sensible
	if holdEligible then
		reason(reasons, "HOLD_FILTER_APPLIED")
		decision.strategy = C.STRATEGIES.HOLD
		decision.targetGroup = C.GROUPS.HOLD
		return decision
	end

	-- Vendor path
	local canVendor, prot = Protect.CanAutoVendor(profile)
	decision.protect = prot
	if not canVendor then
		reason(reasons, "VENDOR_BLOCKED_PROTECTED")
		decision.strategy = C.STRATEGIES.MANUAL_REVIEW
		decision.targetGroup = C.GROUPS.REVIEW
		return decision
	end

	if (profile.vendorSell or 0) <= 0 then
		reason(reasons, "VENDOR_SELL_ZERO_NO_BLIND")
		-- If hold didn't apply and no vendor value → review
		decision.strategy = C.STRATEGIES.MANUAL_REVIEW
		decision.targetGroup = C.GROUPS.REVIEW
		return decision
	end

	if profile.stale and (profile.marketValue == nil) then
		reason(reasons, "STALE_OR_MISSING_MARKET_NO_BLIND_VENDOR")
		decision.strategy = C.STRATEGIES.MANUAL_REVIEW
		decision.targetGroup = C.GROUPS.REVIEW
		return decision
	end

	reason(reasons, "VENDOR_CANDIDATE")
	decision.strategy = C.STRATEGIES.VENDOR
	decision.targetGroup = C.GROUPS.VENDOR
	decision.expectedNet = (profile.vendorSell or 0) * (profile.quantity or 1)
	return decision
end
