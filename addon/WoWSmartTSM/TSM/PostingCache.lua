local Smart = WoWSmartTSM
local Time = Smart:Module("TimeUtil")
local Logger = Smart:Module("Logger")
local PostingCache = Smart:Module("PostingCache")

--[[
  Reuses observations from TSM Auctioning UI sessions and prior Smart evaluations.
  Does not start AH scans. When Auctioning UI is visible, we mark a posting session
  active and retain last decision snapshots keyed by itemString.
]]

local private = {
	byItem = {},
	sessionActive = false,
	sessionStartedAt = nil,
	lastUi = nil,
}

local CACHE_TTL = 30 * 60

function PostingCache.Init()
	if not TSM_API or not TSM_API.RegisterUICallback then
		return
	end
	pcall(TSM_API.RegisterUICallback, "AUCTION", "WoWSmartTSM", function(visible)
		private.lastUi = visible and true or false
		if visible then
			private.sessionActive = true
			private.sessionStartedAt = Time.Now()
			Logger.Debug("UNKNOWN", "PostingCache", "UI", "Auction UI visible — reuse mode on")
		end
	end)
end

function PostingCache.IsSessionActive()
	return private.sessionActive == true
end

function PostingCache.Put(itemString, payload)
	if not itemString then
		return
	end
	private.byItem[itemString] = {
		at = Time.Now(),
		payload = payload,
	}
end

function PostingCache.Get(itemString)
	local e = private.byItem[itemString]
	if not e then
		return nil
	end
	if Time.AgeSeconds(e.at) > CACHE_TTL then
		private.byItem[itemString] = nil
		return nil
	end
	return e.payload, e.at
end

function PostingCache.Invalidate(itemString)
	if itemString then
		private.byItem[itemString] = nil
	else
		wipe(private.byItem)
	end
end

function PostingCache.InvalidateAll()
	wipe(private.byItem)
end

---Merge cached posting observation into raw item profile inputs when still valid.
function PostingCache.ApplyToRaw(raw)
	if not raw or not raw.itemString then
		return raw
	end
	local cached = PostingCache.Get(raw.itemString)
	if not cached then
		return raw
	end
	raw.tsmSkipToken = raw.tsmSkipToken or cached.tsmSkipToken
	raw.operationMinPrice = raw.operationMinPrice or cached.operationMinPrice
	raw.minBuyout = raw.minBuyout or cached.minBuyout
	raw.numAuctions = raw.numAuctions or cached.numAuctions
	raw.postingCacheHit = true
	raw.postingCacheAt = cached.at
	return raw
end

function PostingCache.RememberDecision(decision)
	if not decision or not decision.itemString then
		return
	end
	PostingCache.Put(decision.itemString, {
		at = Time.Now(),
		tsmSkipToken = decision.skip and decision.skip.code or nil,
		operationMinPrice = decision.pricing and decision.pricing.operationMin or nil,
		minBuyout = decision.minBuyout,
		numAuctions = decision.numAuctions,
		strategy = decision.strategy,
	})
end
