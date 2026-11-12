local Smart = WoWSmartTSM
local Logger = Smart:Module("Logger")
local Time = Smart:Module("TimeUtil")
local AutoEval = Smart:Module("AutoEval")

local private = {
	frame = nil,
	pending = false,
	pendingReason = nil,
	debounceAt = 0,
	debounceSeconds = 1.5,
	bucketSeconds = 0.05,
	queue = {},
	running = false,
	lastFullAt = 0,
	enabled = true,
}

local function schedule(reason, itemKeys)
	if not private.enabled then
		return
	end
	private.pending = true
	private.pendingReason = reason or private.pendingReason or "unknown"
	private.debounceAt = GetTime() + private.debounceSeconds
	if itemKeys then
		for _, k in ipairs(itemKeys) do
			private.queue[k] = true
		end
	else
		private.queue["*"] = true -- full bag reevaluation
	end
end

local function process()
	if private.running then
		return
	end
	private.running = true
	private.pending = false
	local reason = private.pendingReason or "debounce"
	private.pendingReason = nil

	local full = private.queue["*"] == true
	wipe(private.queue)

	local ScanService = Smart:GetModule("ScanService")
	local ok, err = pcall(function()
		if full then
			ScanService.ReevaluateBags({ reason = reason, incremental = false })
		else
			-- incremental path currently falls back to full bag pass but skips AH scan always
			ScanService.ReevaluateBags({ reason = reason, incremental = true })
		end
	end)
	if not ok then
		Logger.Error("CLASSIFY_FAILED", "AutoEval", "process", tostring(err))
	end
	private.lastFullAt = Time.Now()
	private.running = false
end

function AutoEval.Init()
	if private.frame then
		return
	end
	local f = CreateFrame("Frame", "WoWSmartTSMAutoEvalFrame")
	private.frame = f
	f:RegisterEvent("PLAYER_LOGIN")
	f:RegisterEvent("PLAYER_ENTERING_WORLD")
	-- bag events (classic + modern)
	f:RegisterEvent("BAG_UPDATE")
	if C_Container and ContainerFrameUtil_GetShownFrameForFrame then
		-- keep BAG_UPDATE
	end
	f:RegisterEvent("PLAYERBANKSLOTS_CHANGED")
	f:RegisterEvent("ITEM_LOCK_CHANGED")

	f:SetScript("OnEvent", function(_, event, arg1)
		if event == "PLAYER_LOGIN" or event == "PLAYER_ENTERING_WORLD" then
			-- Delay so TSM AppHelper AuctionDB finishes loading
			schedule(event == "PLAYER_LOGIN" and "login" or "reload_or_world", nil)
			private.debounceAt = GetTime() + 3.0
		elseif event == "BAG_UPDATE" then
			local bag = arg1
			schedule("bag_update", { "bag:" .. tostring(bag) })
		elseif event == "PLAYERBANKSLOTS_CHANGED" or event == "ITEM_LOCK_CHANGED" then
			schedule(event:lower(), nil)
		end
	end)

	f:SetScript("OnUpdate", function()
		if not private.pending then
			return
		end
		if GetTime() >= private.debounceAt then
			process()
		end
	end)

	Logger.Info("UNKNOWN", "AutoEval", "Init", "Auto reevaluation armed (debounce " .. private.debounceSeconds .. "s)")
end

function AutoEval.Request(reason, itemKeys)
	schedule(reason or "manual", itemKeys)
end

function AutoEval.SetEnabled(enabled)
	private.enabled = enabled and true or false
end

function AutoEval.GetState()
	return {
		pending = private.pending,
		running = private.running,
		reason = private.pendingReason,
		lastFullAt = private.lastFullAt,
		enabled = private.enabled,
	}
end
