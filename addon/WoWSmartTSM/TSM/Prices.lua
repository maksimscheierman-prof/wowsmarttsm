local Smart = WoWSmartTSM
local Logger = Smart:Module("Logger")
local Freshness = Smart:Module("Freshness")
local Prices = Smart:Module("Prices")

--[[
  VERIFIED (TSM v4.15.6 App/API.lua):
    TSM_API.GetCustomPriceValue(customPriceStr, itemString)
    TSM_API.ToItemString(item)
    TSM_API.GetPriceSourceKeys(result)
    TSM_API.IsCustomPriceValid(customPriceStr)

  AuctionDB sources registered in AuctionDBConfig.lua (via AppHelper sync):
    DBMarket, DBMinBuyout, DBNumAuctions, DBRegionMarketAvg,
    DBRegionSaleRate, DBRegionSoldPerDay, ...
  VendorSell registered in Price/Item.lua.

  Smart TSM does NOT start AH scans. Competition uses DBMinBuyout + DBNumAuctions
  from AuctionDB. Live AH is only flagged as needed when those are missing.
]]

local SOURCES = {
	"DBMarket",
	"DBMinBuyout",
	"DBNumAuctions",
	"DBRegionMarketAvg",
	"DBRegionSaleRate",
	"DBRegionSoldPerDay",
	"VendorSell",
	"Crafting",
}

local FIELD_MAP = {
	DBMarket = "dbMarket",
	DBMinBuyout = "dbMinBuyout",
	DBNumAuctions = "numAuctions",
	DBRegionMarketAvg = "dbRegionMarketAvg",
	DBRegionSaleRate = "dbRegionSaleRate",
	DBRegionSoldPerDay = "dbRegionSoldPerDay",
	VendorSell = "vendorSell",
	Crafting = "craftingValue",
}

local private = {
	sourceKeysCache = nil,
	sourceKeysChecked = false,
}

function Prices.IsApiReady()
	return TSM_API ~= nil and type(TSM_API.GetCustomPriceValue) == "function"
end

function Prices.ToItemString(item)
	if not item then
		return nil
	end
	if type(item) == "string" and item:match("^i:") then
		return item
	end
	if Prices.IsApiReady() and TSM_API.ToItemString then
		local ok, val = pcall(TSM_API.ToItemString, item)
		if ok and val then
			return val
		end
	end
	local id = tostring(item):match("item:(%d+)") or tostring(item):match("^(%d+)$")
	return id and ("i:" .. id) or nil
end

function Prices.VerifyRegisteredSources()
	if private.sourceKeysChecked then
		return private.sourceKeysCache
	end
	private.sourceKeysChecked = true
	private.sourceKeysCache = { available = {}, missing = {}, api = Prices.IsApiReady() }
	if not Prices.IsApiReady() or not TSM_API.GetPriceSourceKeys then
		for _, src in ipairs(SOURCES) do
			private.sourceKeysCache.missing[#private.sourceKeysCache.missing + 1] = src
		end
		return private.sourceKeysCache
	end
	local keys = {}
	local ok = pcall(TSM_API.GetPriceSourceKeys, keys)
	local set = {}
	if ok then
		for _, k in ipairs(keys) do
			set[k] = true
		end
	end
	for _, src in ipairs(SOURCES) do
		if set[src] then
			private.sourceKeysCache.available[#private.sourceKeysCache.available + 1] = src
		else
			-- Crafting may be absent until profession data exists — still try GetCustomPriceValue
			private.sourceKeysCache.missing[#private.sourceKeysCache.missing + 1] = src
		end
	end
	return private.sourceKeysCache
end

function Prices.GetSourceValue(source, itemString)
	if not itemString or not source then
		return nil, "NO_ITEM"
	end
	if not Prices.IsApiReady() then
		return nil, "TSM_API_MISSING"
	end
	itemString = Prices.ToItemString(itemString) or itemString
	local ok, valOrErr = pcall(TSM_API.GetCustomPriceValue, source, itemString)
	if not ok then
		Logger.Debug("PRICE_SOURCE_INVALID", "Prices", "GetSourceValue", tostring(valOrErr), {
			priceSources = { source },
			itemId = itemString,
		})
		return nil, "PCALL_FAILED"
	end
	-- API returns (number)|(nil, errMessage)
	if valOrErr == nil then
		return nil, "NO_VALUE"
	end
	if type(valOrErr) ~= "number" then
		return nil, "NON_NUMERIC"
	end
	return valOrErr, nil
end

function Prices.Collect(itemString)
	itemString = Prices.ToItemString(itemString)
	local out = {
		itemString = itemString,
		available = {},
		missing = {},
		sourceMeta = {},
		api = Prices.IsApiReady() and "TSM_API" or nil,
		needsLiveCompetition = false,
		fromAuctionDB = true, -- values come from AppHelper AuctionDB via TSM_API, not a new AH scan
	}

	if not itemString then
		out.missing = { unpack(SOURCES) }
		return out
	end

	for _, src in ipairs(SOURCES) do
		local v = Prices.GetSourceValue(src, itemString)
		local field = FIELD_MAP[src]
		local present = v ~= nil
		if present then
			out[field] = v
			out.available[#out.available + 1] = src
		else
			out.missing[#out.missing + 1] = src
		end
		out.sourceMeta[src] = Freshness.DescribeSource(src, present)
	end

	-- Competition from AuctionDB (synced) — not a live AH query
	if out.dbMinBuyout == nil and out.numAuctions == nil then
		out.needsLiveCompetition = true
	end

	out.freshness = Freshness.Summarize(out.sourceMeta)
	out.dataTimestamp = out.freshness.realmUpdatedAt or out.freshness.regionUpdatedAt
	return out
end

function Prices.GetOperationMin(itemString)
	itemString = Prices.ToItemString(itemString)
	if not itemString then
		return nil
	end
	return Prices.GetSourceValue("AuctioningOpMin", itemString)
end

function Prices.GetOperationNormal(itemString)
	itemString = Prices.ToItemString(itemString)
	if not itemString then
		return nil
	end
	return Prices.GetSourceValue("AuctioningOpNormal", itemString)
end

Prices.SOURCES = SOURCES
Prices.FIELD_MAP = FIELD_MAP
