local Smart = WoWSmartTSM
local C = Smart:Module("Constants")
local Money = Smart:Module("MoneyUtil")
local HoldPolicy = Smart:Module("HoldPolicy")

--[[
Smart Hold is a FILTER for rare valuable exceptions, never a default.
Both market thresholds must pass AND category must be allowed.
AH-profitable listings take precedence over Hold (checked by Classify).
]]

local ALLOWED = {
	EXPENSIVE_GREEN_GEAR = true,
	BLUE_GEAR = true,
	EPIC_GEAR = true,
	RARE_RECIPE = true,
}

function HoldPolicy.IsCategoryAllowed(category)
	return ALLOWED[category] == true
end

---Determine hold category from item profile fields (no name-only classification).
---@param profile table
---@return string|nil category
function HoldPolicy.ResolveCategory(profile)
	local q = profile.quality or 0
	local isEquip = profile.isEquipment == true
	local isRecipe = profile.isRecipe == true

	if isRecipe and q >= C.QUALITY.UNCOMMON then
		return "RARE_RECIPE"
	end
	if isEquip and q >= C.QUALITY.EPIC then
		return "EPIC_GEAR"
	end
	if isEquip and q == C.QUALITY.RARE then
		return "BLUE_GEAR"
	end
	if isEquip and q == C.QUALITY.UNCOMMON then
		return "EXPENSIVE_GREEN_GEAR"
	end
	return nil
end

---Evaluate whether Hold filter passes (not an instruction to keep forever).
---@param profile table must include marketValue, vendorSell, quality, isEquipment, isRecipe
---@return boolean eligible
---@return table details
function HoldPolicy.Evaluate(profile)
	local reasons = {}
	local market = profile.marketValue
	local vendor = profile.vendorSell or 0

	if market == nil then
		reasons[#reasons + 1] = "MISSING_MARKET"
		return false, { eligible = false, reasons = reasons, category = nil }
	end

	local category = HoldPolicy.ResolveCategory(profile)
	if not category then
		reasons[#reasons + 1] = "CATEGORY_NOT_ALLOWED"
		return false, { eligible = false, reasons = reasons, category = nil, marketValue = market, vendorSell = vendor }
	end

	if market < C.HOLD_MIN_MARKET_COPPER then
		reasons[#reasons + 1] = "MARKET_BELOW_10G"
	end

	-- VendorSell = 0: do NOT compute ratio via division by zero; special handling
	local ratio = nil
	if vendor == 0 then
		reasons[#reasons + 1] = "VENDOR_SELL_ZERO_SPECIAL"
		-- Still allow Hold if market threshold + category pass; ratio treated as satisfied via market-only path
		-- but mark data quality reduced — Classify will avoid blind vendor.
		ratio = math.huge
	else
		ratio = Money.SafeDiv(market, vendor)
		if not ratio or ratio < C.HOLD_VENDOR_MULTIPLIER then
			reasons[#reasons + 1] = "MARKET_BELOW_5X_VENDOR"
		end
	end

	local marketOk = market >= C.HOLD_MIN_MARKET_COPPER
	local ratioOk = (vendor == 0 and marketOk) or (ratio and ratio >= C.HOLD_VENDOR_MULTIPLIER)
	local eligible = marketOk and ratioOk and HoldPolicy.IsCategoryAllowed(category)

	if eligible then
		reasons = { "HOLD_FILTER_PASS" }
	end

	return eligible, {
		eligible = eligible,
		category = category,
		marketValue = market,
		vendorSell = vendor,
		ratio = (ratio == math.huge) and nil or ratio,
		vendorSellZero = vendor == 0,
		reasons = reasons,
	}
end

HoldPolicy.ALLOWED_CATEGORIES = ALLOWED
