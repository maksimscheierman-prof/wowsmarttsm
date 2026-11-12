local Smart = WoWSmartTSM
local Engine = Smart:Module("Engine")
local Prices = Smart:Module("Prices")
local Groups = Smart:Module("Groups")
local ItemUtil = Smart:Module("ItemUtil")
local Logger = Smart:Module("Logger")
local Time = Smart:Module("TimeUtil")
local PostingCache = Smart:Module("PostingCache")
local ScanService = Smart:Module("ScanService")

local private = {
	lastResults = {},
	lastMeta = {
		at = nil,
		reason = nil,
		count = 0,
		startedAhScan = false,
		usedTsmApi = false,
		postingCacheHits = 0,
		needsLiveCompetition = 0,
	},
}

local function getBagSlots(bag)
	if C_Container and C_Container.GetContainerNumSlots then
		return C_Container.GetContainerNumSlots(bag) or 0
	end
	if GetContainerNumSlots then
		return GetContainerNumSlots(bag) or 0
	end
	return 0
end

local function getSlotLinkCount(bag, slot)
	if C_Container and C_Container.GetContainerItemInfo then
		local info = C_Container.GetContainerItemInfo(bag, slot)
		if info then
			return info.hyperlink or (info.itemID and ("item:" .. info.itemID)), info.stackCount or 1
		end
	end
	if GetContainerItemLink then
		local link = GetContainerItemLink(bag, slot)
		local _, count = GetContainerItemInfo(bag, slot)
		return link, count or 1
	end
	return nil, 0
end

local function iterBags()
	local items = {}
	local maxBag = NUM_BAG_SLOTS or 4
	for bag = 0, maxBag do
		local slots = getBagSlots(bag)
		for slot = 1, slots do
			local link, count = getSlotLinkCount(bag, slot)
			if link then
				local itemString = Prices.ToItemString(link) or ItemUtil.GetItemString(link)
				local name, _, quality, _, _, className, subclassName, _, equipSlot = GetItemInfo(link)
				local vendorFallback = select(11, GetItemInfo(link)) or 0
				local prices = Prices.Collect(itemString)
				local currentGroup = Groups.GetPathByItem(itemString)
				local opMin = Prices.GetOperationMin(itemString)
				local opNormal = Prices.GetOperationNormal(itemString)

				local raw = {
					itemString = itemString,
					link = link,
					name = name,
					quality = quality,
					className = className,
					subclassName = subclassName,
					equipSlot = equipSlot,
					isEquipment = ItemUtil.IsEquipmentSlot(equipSlot),
					isRecipe = ItemUtil.IsRecipeClass(className, subclassName, name),
					vendorSell = prices.vendorSell or vendorFallback or 0,
					dbMarket = prices.dbMarket,
					dbMinBuyout = prices.dbMinBuyout,
					dbRegionMarketAvg = prices.dbRegionMarketAvg,
					dbRegionSaleRate = prices.dbRegionSaleRate,
					dbRegionSoldPerDay = prices.dbRegionSoldPerDay,
					craftingValue = prices.craftingValue,
					numAuctions = prices.numAuctions,
					minBuyout = prices.dbMinBuyout,
					marketValue = prices.dbMarket,
					regionMarket = prices.dbRegionMarketAvg,
					saleRate = prices.dbRegionSaleRate,
					soldPerDay = prices.dbRegionSoldPerDay,
					quantity = count,
					currentGroup = currentGroup,
					operationMinPrice = opMin,
					operationNormalPrice = opNormal,
					dataTimestamp = prices.dataTimestamp or Time.Now(),
					sourceMeta = prices.sourceMeta,
					freshness = prices.freshness,
					needsLiveCompetition = prices.needsLiveCompetition,
					fromAuctionDB = true,
					bag = bag,
					slot = slot,
				}
				PostingCache.ApplyToRaw(raw)
				items[#items + 1] = raw
			end
		end
	end
	return items
end

---Reevaluate bags using existing TSM AuctionDB / AppHelper data via TSM_API.
---Never starts an Auction House scan.
function ScanService.ReevaluateBags(opts)
	opts = opts or {}
	local reason = opts.reason or "manual"
	local ok, items = pcall(iterBags)
	if not ok then
		Logger.Error("CLASSIFY_FAILED", "ScanService", "ReevaluateBags", tostring(items))
		return {}
	end

	local decisions = Engine.EvaluateMany(items)
	local cacheHits, needLive = 0, 0
	for i, d in ipairs(decisions) do
		if d then
			local raw = items[i]
			if raw and raw.postingCacheHit then
				cacheHits = cacheHits + 1
				d.postingCacheHit = true
			end
			if raw and raw.needsLiveCompetition then
				needLive = needLive + 1
				d.needsLiveCompetition = true
			end
			d.sourceMeta = raw and raw.sourceMeta or d.sourceMeta
			d.freshness = raw and raw.freshness or d.freshness
			d.minBuyout = raw and raw.minBuyout or d.minBuyout
			d.numAuctions = raw and raw.numAuctions or d.numAuctions
			d.currentGroup = raw and raw.currentGroup
			PostingCache.RememberDecision(d)
		end
	end

	private.lastResults = decisions
	private.lastMeta = {
		at = Time.Now(),
		reason = reason,
		count = #decisions,
		startedAhScan = false,
		usedTsmApi = Prices.IsApiReady(),
		postingCacheHits = cacheHits,
		needsLiveCompetition = needLive,
		incremental = opts.incremental and true or false,
	}
	if WoWSmartTSM_DB then
		WoWSmartTSM_DB.lastScan = {
			at = private.lastMeta.at,
			count = private.lastMeta.count,
			reason = reason,
			startedAhScan = false,
			mode = "TSM_DATA_REEVAL",
		}
	end
	Logger.Info(
		"UNKNOWN",
		"ScanService",
		"ReevaluateBags",
		string.format(
			"Reevaluated %d stacks via TSM data (reason=%s, ahScan=false, cacheHits=%d, needLiveCompetition=%d)",
			#decisions,
			reason,
			cacheHits,
			needLive
		)
	)
	return decisions
end

-- Back-compat alias: historical name; does NOT scan the AH.
function ScanService.RunBagScan()
	return ScanService.ReevaluateBags({ reason = "manual_scan_command" })
end

function ScanService.GetLastResults()
	return private.lastResults
end

function ScanService.GetLastMeta()
	return private.lastMeta
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
		needsLiveCompetition = 0,
		missingData = 0,
		staleData = 0,
		startedAhScan = false,
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
		if d.needsLiveCompetition then
			sum.needsLiveCompetition = sum.needsLiveCompetition + 1
		end
		if d.freshness then
			sum.missingData = sum.missingData + #(d.freshness.missing or {})
			sum.staleData = sum.staleData + #(d.freshness.stale or {})
		end
		sum.dataQualitySum = sum.dataQualitySum + (d.dataQuality or 0)
	end
	sum.dataQualityAvg = sum.n > 0 and (sum.dataQualitySum / sum.n) or 0
	return sum
end
