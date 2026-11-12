--[[
  Early tap: wraps TSM_APPHELPER_LOAD_DATA after TSM loads and before/while
  AppHelper feeds AuctionDB payloads, so Smart TSM can show downloadTime freshness.
  Does not alter TSM behavior beyond observing timestamps.
]]

SmartTSM_AppDataFreshness = SmartTSM_AppDataFreshness or {
	realmDownloadTime = 0,
	regionDownloadTime = 0,
	tags = {},
	lastCapture = 0,
}

local REALM_TAGS = {
	AUCTIONDB_NON_COMMODITY_DATA = true,
	AUCTIONDB_NON_COMMODITY_SCAN_STAT = true,
	AUCTIONDB_NON_COMMODITY_HISTORICAL = true,
	AUCTIONDB_COMMODITY_DATA = true,
	AUCTIONDB_COMMODITY_SCAN_STAT = true,
	AUCTIONDB_COMMODITY_HISTORICAL = true,
}

local REGION_TAGS = {
	AUCTIONDB_REGION_STAT = true,
	AUCTIONDB_REGION_HISTORICAL = true,
	AUCTIONDB_REGION_SALE = true,
}

local function note(tag, realmOrRegion, data)
	if type(data) ~= "string" then
		return
	end
	local dt = tonumber(data:match("downloadTime=(%d+)"))
	if not dt then
		return
	end
	local store = SmartTSM_AppDataFreshness
	store.tags[tag] = {
		downloadTime = dt,
		realmOrRegion = realmOrRegion,
	}
	if REALM_TAGS[tag] then
		if dt > (store.realmDownloadTime or 0) then
			store.realmDownloadTime = dt
		end
	end
	if REGION_TAGS[tag] then
		if dt > (store.regionDownloadTime or 0) then
			store.regionDownloadTime = dt
		end
	end
	store.lastCapture = time and time() or dt
end

local function wrapLoader()
	local orig = _G.TSM_APPHELPER_LOAD_DATA
	if type(orig) ~= "function" then
		return false
	end
	if orig.__smartTSMWrapped then
		return true
	end
	local wrapped = function(tag, realmOrRegion, data)
		local ok, err = pcall(note, tag, realmOrRegion, data)
		if not ok and DEFAULT_CHAT_FRAME then
			DEFAULT_CHAT_FRAME:AddMessage("|cff4ecdc4[SmartTSM DataTap]|r " .. tostring(err))
		end
		return orig(tag, realmOrRegion, data)
	end
	wrapped.__smartTSMWrapped = true
	_G.TSM_APPHELPER_LOAD_DATA = wrapped
	return true
end

local f = CreateFrame("Frame", "SmartTSM_DataTapFrame")
local tries = 0
f:RegisterEvent("ADDON_LOADED")
f:SetScript("OnEvent", function(self, event, name)
	if event == "ADDON_LOADED" and (name == "TradeSkillMaster" or name == "!SmartTSM_DataTap") then
		if wrapLoader() then
			-- Keep trying briefly: TSM may assign the loader slightly later
		end
		tries = 0
		self:SetScript("OnUpdate", function(frame, elapsed)
			tries = tries + elapsed
			wrapLoader()
			if tries > 5 then
				frame:SetScript("OnUpdate", nil)
			end
		end)
	end
end)
