local Smart = WoWSmartTSM
local C = Smart:Module("Constants")
local Time = Smart:Module("TimeUtil")
local Freshness = Smart:Module("Freshness")

local SOURCE_CATEGORY = {
	DBMarket = "realm",
	DBMinBuyout = "realm",
	DBNumAuctions = "realm",
	DBRecent = "realm",
	DBHistorical = "realm",
	DBRegionMarketAvg = "region",
	DBRegionSaleRate = "region",
	DBRegionSoldPerDay = "region",
	DBRegionSaleAvg = "region",
	DBRegionHistorical = "region",
	VendorSell = "vendor",
	Crafting = "crafting",
	AuctioningOpMin = "operation",
	AuctioningOpNormal = "operation",
	AuctioningOpMax = "operation",
}

function Freshness.GetTap()
	return _G.SmartTSM_AppDataFreshness
end

function Freshness.GetCategoryTimestamp(category)
	local tap = Freshness.GetTap()
	if not tap then
		return nil, "NO_DATATAP"
	end
	if category == "realm" then
		local t = tap.realmDownloadTime
		return (t and t > 0) and t or nil, t and t > 0 and "APPHELPER_DOWNLOAD" or "MISSING_REALM_SYNC"
	end
	if category == "region" then
		local t = tap.regionDownloadTime
		return (t and t > 0) and t or nil, t and t > 0 and "APPHELPER_DOWNLOAD" or "MISSING_REGION_SYNC"
	end
	if category == "vendor" then
		return Time.Now(), "LIVE_ITEMINFO"
	end
	if category == "crafting" or category == "operation" then
		return Time.Now(), "SESSION"
	end
	return nil, "UNKNOWN_CATEGORY"
end

function Freshness.DescribeSource(sourceKey, valuePresent)
	local category = SOURCE_CATEGORY[sourceKey] or "unknown"
	local ts, origin = Freshness.GetCategoryTimestamp(category)
	local maxAge = (WoWSmartTSM_DB and WoWSmartTSM_DB.settings and WoWSmartTSM_DB.settings.dataMaxAgeSeconds) or C.DATA_MAX_AGE_SECONDS
	local age = ts and Time.AgeSeconds(ts) or nil
	local stale = false
	local status
	if not valuePresent then
		status = "MISSING"
	elseif not ts and (category == "realm" or category == "region") then
		status = "PRESENT_AGE_UNKNOWN"
	elseif age and age > maxAge then
		status = "STALE"
		stale = true
	else
		status = "FRESH"
	end
	return {
		source = sourceKey,
		category = category,
		present = valuePresent and true or false,
		updatedAt = ts,
		ageSeconds = age,
		stale = stale,
		status = status,
		origin = origin,
	}
end

function Freshness.Summarize(sourceMeta)
	local out = {
		realmUpdatedAt = select(1, Freshness.GetCategoryTimestamp("realm")),
		regionUpdatedAt = select(1, Freshness.GetCategoryTimestamp("region")),
		sources = sourceMeta or {},
		missing = {},
		stale = {},
		fresh = {},
		unknownAge = {},
	}
	for _, meta in pairs(sourceMeta or {}) do
		if meta.status == "MISSING" then
			out.missing[#out.missing + 1] = meta.source
		elseif meta.status == "STALE" then
			out.stale[#out.stale + 1] = meta.source
		elseif meta.status == "FRESH" then
			out.fresh[#out.fresh + 1] = meta.source
		elseif meta.status == "PRESENT_AGE_UNKNOWN" then
			out.unknownAge[#out.unknownAge + 1] = meta.source
		end
	end
	return out
end

Freshness.SOURCE_CATEGORY = SOURCE_CATEGORY
