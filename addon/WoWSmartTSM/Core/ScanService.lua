local Smart = WoWSmartTSM
local Engine = Smart:Module("Engine")
local Prices = Smart:Module("Prices")
local Groups = Smart:Module("Groups")
local ItemUtil = Smart:Module("ItemUtil")
local Logger = Smart:Module("Logger")
local Time = Smart:Module("TimeUtil")
local ScanService = Smart:Module("ScanService")

local private = {
	lastResults = {},
}

local function iterBags()
	local items = {}
	for bag = 0, NUM_BAG_SLOTS or 4 do
		local slots = C_Container and C_Container.GetContainerNumSlots and C_Container.GetContainerNumSlots(bag) or GetContainerNumSlots and GetContainerNumSlots(bag) or 0
		for slot = 1, slots do
			local info
			if C_Container and C_Container.GetContainerItemInfo then
				info = C_Container.GetContainerItemInfo(bag, slot)
			end
			local link, count
			if info then
				link = info.hyperlink or (info.itemID and ("item:" .. info.itemID))
				count = info.stackCount or 1
			elseif GetContainerItemLink then
				link = GetContainerItemLink(bag, slot)
				local _, c = GetContainerItemInfo(bag, slot)
				count = c or 1
			end
			if link then
				local itemString = ItemUtil.GetItemString(link)
				local name, _, quality, _, _, className, subclassName, _, equipSlot = GetItemInfo(link)
				local vendorSell = select(11, GetItemInfo(link)) or 0
				local prices = Prices.Collect(itemString)
				local currentGroup = Groups.GetPathByItem(itemString)
				items[#items + 1] = {
					itemString = itemString,
					link = link,
					name = name,
					quality = quality,
					className = className,
					subclassName = subclassName,
					equipSlot = equipSlot,
					isEquipment = ItemUtil.IsEquipmentSlot(equipSlot),
					isRecipe = ItemUtil.IsRecipeClass(className, subclassName, name),
					vendorSell = prices.vendorSell or vendorSell or 0,
					dbMarket = prices.dbMarket,
					dbMinBuyout = prices.dbMinBuyout,
					dbRegionMarketAvg = prices.dbRegionMarketAvg,
					dbRegionSaleRate = prices.dbRegionSaleRate,
					dbRegionSoldPerDay = prices.dbRegionSoldPerDay,
					craftingValue = prices.craftingValue,
					quantity = count,
					currentGroup = currentGroup,
					dataTimestamp = Time.Now(),
					bag = bag,
					slot = slot,
				}
			end
		end
	end
	return items
end

function ScanService.RunBagScan()
	local ok, items = pcall(iterBags)
	if not ok then
		Logger.Error("CLASSIFY_FAILED", "ScanService", "RunBagScan", tostring(items))
		return {}
	end
	local decisions = Engine.EvaluateMany(items)
	private.lastResults = decisions
	if WoWSmartTSM_DB then
		WoWSmartTSM_DB.lastScan = { at = Time.Now(), count = #decisions }
	end
	Logger.Info("UNKNOWN", "ScanService", "RunBagScan", "Scanned " .. tostring(#decisions) .. " stacks")
	return decisions
end

function ScanService.GetLastResults()
	return private.lastResults
end

function ScanService.Summarize(results)
	results = results or private.lastResults
	local sum = {
		toPost = 0,
		optimizable = 0,
		vendor = 0,
		hold = 0,
		review = 0,
		ahNet = 0,
		vendorValue = 0,
		dataQualitySum = 0,
		n = #results,
	}
	local C = Smart:Module("Constants")
	for _, d in ipairs(results) do
		if not d then
			-- skip
		elseif d.strategy == C.STRATEGIES.QUICK_SELL or d.strategy == C.STRATEGIES.PROFIT_SELL or d.strategy == C.STRATEGIES.RARE_SELL then
			sum.toPost = sum.toPost + 1
			sum.ahNet = sum.ahNet + (d.expectedNet or 0)
		elseif d.strategy == C.STRATEGIES.VENDOR then
			sum.vendor = sum.vendor + 1
			sum.vendorValue = sum.vendorValue + (d.expectedNet or 0)
		elseif d.strategy == C.STRATEGIES.HOLD then
			sum.hold = sum.hold + 1
		else
			sum.review = sum.review + 1
		end
		if d.skip then
			sum.optimizable = sum.optimizable + 1
		end
		sum.dataQualitySum = sum.dataQualitySum + (d.dataQuality or 0)
	end
	sum.dataQualityAvg = sum.n > 0 and (sum.dataQualitySum / sum.n) or 0
	return sum
end
