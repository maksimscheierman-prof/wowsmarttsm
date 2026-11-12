local Smart = WoWSmartTSM
local ItemUtil = Smart:Module("ItemUtil")
local Time = Smart:Module("TimeUtil")
local C = Smart:Module("Constants")
local ItemProfile = Smart:Module("ItemProfile")

local function confidenceFrom(sources, maxAge)
	local score = 0
	local present = 0
	local keys = { "dbMarket", "dbMinBuyout", "dbRegionMarketAvg", "vendorSell" }
	for _, k in ipairs(keys) do
		if sources[k] ~= nil then
			present = present + 1
		end
	end
	score = present / #keys
	if sources.dataTimestamp then
		local age = Time.AgeSeconds(sources.dataTimestamp)
		if age and maxAge and age > maxAge then
			score = score * 0.5
		end
	else
		score = score * 0.8
	end
	if sources.dbMarket and sources.dbRegionMarketAvg and sources.dbRegionMarketAvg > 0 then
		local ratio = sources.dbMarket / sources.dbRegionMarketAvg
		if ratio > 5 or ratio < 0.2 then
			score = score * 0.6 -- implausible divergence
		end
	end
	return math.max(0, math.min(1, score))
end

---Build a normalized decision profile from raw inputs (testable offline).
function ItemProfile.Build(raw)
	raw = raw or {}
	local settings = (WoWSmartTSM_DB and WoWSmartTSM_DB.settings) or {}
	local maxAge = settings.dataMaxAgeSeconds or C.DATA_MAX_AGE_SECONDS

	local itemString = raw.itemString or ItemUtil.GetItemString(raw.link or raw.itemId)
	local vendorSell = raw.vendorSell or 0
	local market = raw.dbMarket or raw.marketValue
	local minBuyout = raw.dbMinBuyout or raw.minBuyout
	local region = raw.dbRegionMarketAvg or raw.regionMarket
	local saleRate = raw.dbRegionSaleRate -- NOT a direct duration probability
	local soldPerDay = raw.dbRegionSoldPerDay
	local numAuctions = raw.numAuctions
	local quantity = raw.quantity or 1
	local deposit = raw.deposit
	local crafting = raw.craftingValue

	local dataQuality = confidenceFrom({
		dbMarket = market,
		dbMinBuyout = minBuyout,
		dbRegionMarketAvg = region,
		vendorSell = vendorSell,
		dataTimestamp = raw.dataTimestamp,
	}, maxAge)

	local stale = false
	if raw.dataTimestamp then
		local age = Time.AgeSeconds(raw.dataTimestamp)
		stale = age ~= nil and age > maxAge
	elseif market == nil and region == nil then
		stale = true
	end

	return {
		itemString = itemString,
		itemId = raw.itemId or ItemUtil.GetItemID(itemString),
		name = raw.name,
		quality = raw.quality or 0,
		className = raw.className,
		subclassName = raw.subclassName,
		equipSlot = raw.equipSlot,
		isEquipment = raw.isEquipment,
		isRecipe = raw.isRecipe,
		isBound = raw.isBound,
		isEquipped = raw.isEquipped,
		isQuestItem = raw.isQuestItem,
		isLocked = raw.isLocked,
		isProtectedFlag = raw.isProtectedFlag,
		unknownIdentity = itemString == nil,
		vendorSell = vendorSell,
		marketValue = market,
		minBuyout = minBuyout,
		regionMarket = region,
		saleRate = saleRate,
		soldPerDay = soldPerDay,
		numAuctions = numAuctions,
		quantity = quantity,
		stackSize = raw.stackSize or 1,
		deposit = deposit,
		craftingValue = crafting,
		currentGroup = raw.currentGroup,
		operationMinPrice = raw.operationMinPrice,
		operationNormalPrice = raw.operationNormalPrice,
		dataTimestamp = raw.dataTimestamp or Time.Now(),
		dataQuality = dataQuality,
		stale = stale,
		variantKey = raw.variantKey, -- bonus IDs / suffixes when available
	}
end
