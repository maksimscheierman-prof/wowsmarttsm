--[[
  Early tap: wraps TSM_APPHELPER_LOAD_DATA after TSM loads and before/while
  AppHelper feeds AuctionDB payloads, so Smart TSM can show downloadTime freshness.
  Does not alter TSM behavior beyond observing timestamps.

  P0 fix: never index Lua functions as tables.
  Idempotency uses local function references only.
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

local private = {
	originalLoader = nil, -- function we last wrapped (TSM's loader)
	wrappedLoader = nil, -- our wrapper function reference
	wrapping = false, -- re-entrancy guard while assigning
	onUpdateActive = false,
	elapsed = 0,
	eventFrame = nil,
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

---Safe wrap of TSM_APPHELPER_LOAD_DATA. Returns true if a usable loader is in place.
function SmartTSM_DataTap_WrapLoader()
	local current = _G.TSM_APPHELPER_LOAD_DATA
	if type(current) ~= "function" then
		return false
	end

	-- Already installed: global still points at our wrapper
	if private.wrappedLoader ~= nil and current == private.wrappedLoader then
		return true
	end

	-- Avoid recursive wrap while we assign
	if private.wrapping then
		return false
	end

	local orig = current
	private.wrapping = true

	local function wrapped(...)
		-- Timestamp capture must never break TSM: pcall only around note
		local tag, realmOrRegion, data = ...
		local ok, err = pcall(note, tag, realmOrRegion, data)
		if not ok then
			if DEFAULT_CHAT_FRAME then
				DEFAULT_CHAT_FRAME:AddMessage("|cff4ecdc4[SmartTSM DataTap]|r note failed: " .. tostring(err))
			end
		end
		-- Forward all arguments and all return values to the original loader
		return orig(...)
	end

	private.originalLoader = orig
	private.wrappedLoader = wrapped
	_G.TSM_APPHELPER_LOAD_DATA = wrapped
	private.wrapping = false
	return true
end

local function wrapLoader()
	return SmartTSM_DataTap_WrapLoader()
end

local function ensureOnUpdate(frame)
	if private.onUpdateActive then
		return
	end
	private.onUpdateActive = true
	private.elapsed = 0
	frame:SetScript("OnUpdate", function(self, elapsed)
		private.elapsed = private.elapsed + (elapsed or 0)
		wrapLoader()
		if private.elapsed > 5 then
			self:SetScript("OnUpdate", nil)
			private.onUpdateActive = false
		end
	end)
end

local f = CreateFrame("Frame", "SmartTSM_DataTapFrame")
private.eventFrame = f
f:RegisterEvent("ADDON_LOADED")
f:SetScript("OnEvent", function(self, event, name)
	if event ~= "ADDON_LOADED" then
		return
	end
	if name ~= "TradeSkillMaster" and name ~= "!SmartTSM_DataTap" then
		return
	end
	wrapLoader()
	-- Single OnUpdate poller only (idempotent; no stacked handlers)
	ensureOnUpdate(self)
end)

-- Expose internals for offline/ingame diagnostics (read-only intent)
SmartTSM_DataTap_Private = private
