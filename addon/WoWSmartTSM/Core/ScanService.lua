local Smart = WoWSmartTSM
local Engine = Smart:Module("Engine")
local Prices = Smart:Module("Prices")
local Groups = Smart:Module("Groups")
local ItemUtil = Smart:Module("ItemUtil")
local ItemAPI = Smart:Module("ItemAPI")
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
		status = "NEVER_RUN",
		error = nil,
	},
}

local function buildRawFromSlot(bag, slot)
	local slotInfo = ItemAPI.GetBagSlot(bag, slot)
	if not slotInfo or not slotInfo.link then
		return nil
	end
	local link = slotInfo.link
	local count = slotInfo.count or 1
	local itemString = Prices.ToItemString(link) or ItemUtil.GetItemString(link)
	local info = ItemAPI.GetInfo(link)
	local name = info and info.name or nil
	local quality = (info and info.quality) or slotInfo.quality
	local className = info and info.className or nil
	local subclassName = info and info.subclassName or nil
	local equipSlot = info and info.equipSlot or nil
	local vendorFallback = (info and info.vendorSell) or 0
	local metaIncomplete = not (info and info.complete)

	-- Prefer TSM VendorSell; client vendor is fallback only
	local prices = Prices.Collect(itemString)
	local currentGroup = Groups.GetPathByItem(itemString)
	local opMin = Prices.GetOperationMin(itemString)
	local opNormal = Prices.GetOperationNormal(itemString)

	local raw = {
		itemString = itemString,
		itemId = slotInfo.itemId or ItemUtil.GetItemID(itemString),
		link = link,
		name = name or (itemString and ("#" .. tostring(ItemUtil.GetItemID(itemString))) or "?"),
		quality = quality,
		className = className,
		subclassName = subclassName,
		equipSlot = equipSlot,
		isEquipment = ItemUtil.IsEquipmentSlot(equipSlot),
		isRecipe = ItemUtil.IsRecipeClass(className, subclassName, name),
		isBound = slotInfo.isBound and true or false,
		isLocked = slotInfo.isLocked and true or false,
		metaIncomplete = metaIncomplete,
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
		itemInfoSource = info and info.source or "none",
	}
	PostingCache.ApplyToRaw(raw)
	return raw
end

local function iterBags()
	local items = {}
	local skippedSlots = 0
	local pendingMeta = 0
	local maxBag = NUM_BAG_SLOTS or 4
	for bag = 0, maxBag do
		local slots = ItemAPI.GetBagNumSlots(bag)
		for slot = 1, slots do
			local ok, rawOrErr = pcall(buildRawFromSlot, bag, slot)
			if not ok then
				skippedSlots = skippedSlots + 1
				Logger.Warning("CLASSIFY_FAILED", "ScanService", "iterBags", tostring(rawOrErr), {
					state = { bag = bag, slot = slot },
				})
			elseif rawOrErr then
				if rawOrErr.metaIncomplete then
					pendingMeta = pendingMeta + 1
				end
				items[#items + 1] = rawOrErr
			end
		end
	end
	return items, skippedSlots, pendingMeta
end

---Reevaluate bags using existing TSM AuctionDB / AppHelper data via TSM_API.
---Never starts an Auction House scan.
function ScanService.ReevaluateBags(opts)
	opts = opts or {}
	local reason = opts.reason or "manual"
	ItemAPI.ProbeCapabilities()
	local Resolver = Smart:GetModule("CharacterResolver")
	if Resolver and Resolver.Snapshot and Logger and Logger.Info then
		local snap = Resolver.Snapshot()
		Logger.Info("CHARACTER_ROLE_RESOLVED", "ScanService", "ReevaluateBags", tostring(snap.role), {
			state = snap,
		})
		if snap.bankKey then
			Logger.Info("BANK_CHARACTER_RESOLVED", "ScanService", "ReevaluateBags", tostring(snap.bankKey), {
				state = { canMail = snap.canMailToBank, block = snap.mailBlockCode },
			})
		end
	end

	local pack = { ok = false }
	local okCall, callErr = pcall(function()
		local items, skippedSlots, pendingMeta = iterBags()
		pack.ok = true
		pack.items = items
		pack.skippedSlots = skippedSlots
		pack.pendingMeta = pendingMeta
	end)
	if not okCall or not pack.ok then
		local errMsg = tostring(callErr or "iterBags failed")
		Logger.Error("CLASSIFY_FAILED", "ScanService", "ReevaluateBags", errMsg)
		private.lastResults = {}
		private.lastMeta = {
			at = Time.Now(),
			reason = reason,
			count = 0,
			startedAhScan = false,
			usedTsmApi = Prices.IsApiReady(),
			postingCacheHits = 0,
			needsLiveCompetition = 0,
			incremental = opts.incremental and true or false,
			status = "FAILED",
			error = errMsg,
		}
		return {}
	end
	local items = pack.items or {}
	local skippedSlots = pack.skippedSlots or 0
	local pendingMeta = pack.pendingMeta or 0

	local decisions = Engine.EvaluateMany(items)
	local cacheHits, needLive, missingPrices = 0, 0, 0
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
			if raw and raw.freshness and raw.freshness.missing and #raw.freshness.missing > 0 then
				missingPrices = missingPrices + 1
			end
			d.sourceMeta = raw and raw.sourceMeta or d.sourceMeta
			d.freshness = raw and raw.freshness or d.freshness
			d.minBuyout = raw and raw.minBuyout or d.minBuyout
			d.numAuctions = raw and raw.numAuctions or d.numAuctions
			d.currentGroup = raw and raw.currentGroup
			d.metaIncomplete = raw and raw.metaIncomplete
			PostingCache.RememberDecision(d)
		end
	end

	local status
	if not Prices.IsApiReady() and #decisions == 0 then
		status = "TSM_DATA_MISSING"
	elseif #decisions == 0 then
		status = "NO_ITEMS"
	elseif missingPrices == #decisions and not Prices.IsApiReady() then
		status = "TSM_DATA_MISSING"
	else
		status = "OK"
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
		status = status,
		error = nil,
		missingPriceStacks = missingPrices,
		skippedSlots = skippedSlots,
		pendingMeta = pendingMeta,
		itemApi = ItemAPI.GetCapabilities().preferredInfoAPI,
		bagApi = ItemAPI.GetCapabilities().preferredBagAPI,
	}
	if WoWSmartTSM_DB then
		WoWSmartTSM_DB.lastScan = {
			at = private.lastMeta.at,
			count = private.lastMeta.count,
			reason = reason,
			startedAhScan = false,
			mode = "TSM_DATA_REEVAL",
			status = status,
		}
	end
	Logger.Info(
		"UNKNOWN",
		"ScanService",
		"ReevaluateBags",
		string.format(
			"Reevaluated %d stacks via TSM data (reason=%s, status=%s, ahScan=false, pendingMeta=%d, skipped=%d, itemApi=%s)",
			#decisions,
			reason,
			status,
			pendingMeta,
			skippedSlots,
			tostring(private.lastMeta.itemApi)
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

local EVAL_LABELS = {
	NEVER_RUN = "Noch keine Bewertung durchgeführt",
	NO_ITEMS = "Keine Items in den Taschen gefunden",
	FAILED = "Inventarbewertung fehlgeschlagen",
	TSM_DATA_MISSING = "TSM-Daten fehlen oder API nicht bereit",
	OK = "Erfolgreich bewertet",
}

function ScanService.GetEvalStatus()
	local meta = private.lastMeta or {}
	local status = meta.status or "NEVER_RUN"
	local label = EVAL_LABELS[status] or status
	if status == "OK" then
		local sum = ScanService.Summarize(private.lastResults)
		if (sum.toPost + sum.vendor + sum.hold + sum.optimizable) == 0 then
			label = "Erfolgreich bewertet — keine Verkaufskandidaten"
		else
			label = string.format("Erfolgreich bewertet (%d Stacks)", meta.count or 0)
		end
		if (meta.pendingMeta or 0) > 0 then
			label = label .. string.format(" — %d Items mit unvollständigen Metadaten", meta.pendingMeta)
		end
	elseif status == "FAILED" and meta.error then
		label = "Inventarbewertung fehlgeschlagen: " .. tostring(meta.error)
	end
	return {
		status = status,
		label = label,
		at = meta.at,
		reason = meta.reason,
		count = meta.count or 0,
		error = meta.error,
		pendingMeta = meta.pendingMeta or 0,
	}
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
