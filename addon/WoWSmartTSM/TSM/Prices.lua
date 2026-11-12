local Smart = WoWSmartTSM
local Logger = Smart:Module("Logger")
local Safe = Smart:Module("SafeCall")
local Prices = Smart:Module("Prices")

local SOURCES = {
	"DBMarket",
	"DBMinBuyout",
	"DBRegionMarketAvg",
	"DBRegionSaleRate",
	"DBRegionSoldPerDay",
	"VendorSell",
	"Crafting",
}

local function getCustomString()
	-- TSM 4.15 modular access — try common globals carefully
	if TSM_API and TSM_API.GetCustomPriceValue then
		return "TSM_API"
	end
	return nil
end

function Prices.GetSourceValue(source, itemString)
	if not itemString then
		return nil
	end
	-- Official-ish TSM_API path when present
	if TSM_API and TSM_API.GetCustomPriceValue then
		local ok, val = pcall(TSM_API.GetCustomPriceValue, source, itemString)
		if ok then
			return val
		end
		Logger.Debug("PRICE_SOURCE_INVALID", "Prices", "GetSourceValue", tostring(val), { priceSources = { source } })
		return nil
	end
	return nil
end

function Prices.Collect(itemString)
	local out = {
		itemString = itemString,
		available = {},
		missing = {},
		api = getCustomString(),
	}
	for _, src in ipairs(SOURCES) do
		local v = Prices.GetSourceValue(src, itemString)
		local key = src:gsub("^DB", "db"):gsub("^Vendor", "vendor"):gsub("^Crafting", "crafting")
		-- normalize keys used by ItemProfile
		local map = {
			DBMarket = "dbMarket",
			DBMinBuyout = "dbMinBuyout",
			DBRegionMarketAvg = "dbRegionMarketAvg",
			DBRegionSaleRate = "dbRegionSaleRate",
			DBRegionSoldPerDay = "dbRegionSoldPerDay",
			VendorSell = "vendorSell",
			Crafting = "craftingValue",
		}
		local field = map[src]
		if v ~= nil then
			out[field] = v
			out.available[#out.available + 1] = src
		else
			out.missing[#out.missing + 1] = src
		end
	end
	return out
end

Prices.SOURCES = SOURCES
