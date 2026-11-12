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
	loginDelaySeconds = 3.0,
	queue = {},
	running = false,
	lastFullAt = 0,
	lastStatus = "IDLE",
	lastError = nil,
	enabled = true,
	bootstrapped = false,
}

local function schedule(reason, itemKeys, delay)
	if not private.enabled then
		return
	end
	private.pending = true
	private.pendingReason = reason or private.pendingReason or "unknown"
	private.debounceAt = GetTime() + (delay or private.debounceSeconds)
	private.lastStatus = "SCHEDULED"
	if itemKeys then
		for _, k in ipairs(itemKeys) do
			private.queue[k] = true
		end
	else
		private.queue["*"] = true
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
	private.lastStatus = "RUNNING"

	local full = private.queue["*"] == true
	wipe(private.queue)

	local ScanService = Smart:GetModule("ScanService")
	local ok, err = pcall(function()
		ScanService.ReevaluateBags({ reason = reason, incremental = not full })
	end)
	if not ok then
		private.lastStatus = "FAILED"
		private.lastError = tostring(err)
		Logger.Error("CLASSIFY_FAILED", "AutoEval", "process", tostring(err))
	else
		private.lastStatus = "OK"
		private.lastError = nil
	end
	private.lastFullAt = Time.Now()
	private.running = false
end

function AutoEval.Init()
	if private.frame then
		-- Still ensure a login reevaluation if we missed PLAYER_LOGIN
		if not private.bootstrapped then
			schedule("init_catchup", nil, private.loginDelaySeconds)
			private.bootstrapped = true
		end
		return
	end
	local f = CreateFrame("Frame", "WoWSmartTSMAutoEvalFrame")
	private.frame = f
	f:RegisterEvent("PLAYER_LOGIN")
	f:RegisterEvent("PLAYER_ENTERING_WORLD")
	f:RegisterEvent("BAG_UPDATE")
	f:RegisterEvent("PLAYERBANKSLOTS_CHANGED")

	f:SetScript("OnEvent", function(_, event, arg1)
		if event == "PLAYER_LOGIN" then
			schedule("login", nil, private.loginDelaySeconds)
			private.bootstrapped = true
		elseif event == "PLAYER_ENTERING_WORLD" then
			schedule("reload_or_world", nil, private.loginDelaySeconds)
			private.bootstrapped = true
		elseif event == "BAG_UPDATE" then
			schedule("bag_update", { "bag:" .. tostring(arg1) }, private.debounceSeconds)
		elseif event == "PLAYERBANKSLOTS_CHANGED" then
			schedule("bank_update", nil, private.debounceSeconds)
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

	-- If Init runs after login events already fired, schedule catch-up
	if UnitName and UnitName("player") then
		schedule("init_after_login", nil, private.loginDelaySeconds)
		private.bootstrapped = true
	end

	Logger.Info("UNKNOWN", "AutoEval", "Init", "Auto reevaluation armed (debounce " .. private.debounceSeconds .. "s)")
end

function AutoEval.Request(reason, itemKeys)
	schedule(reason or "manual", itemKeys, private.debounceSeconds)
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
		lastStatus = private.lastStatus,
		lastError = private.lastError,
		enabled = private.enabled,
		bootstrapped = private.bootstrapped,
	}
end
