local Smart = WoWSmartTSM
local C = Smart:Module("Constants")
local Version = Smart:Module("Version")
local RB = Smart:Module("RingBuffer")
local Privacy = Smart:Module("Privacy")
local ErrorCodes = Smart:Module("ErrorCodes")
local Time = Smart:Module("TimeUtil")
local Logger = Smart:Module("Logger")

local private = {
	sessionId = nil,
	buffer = nil,
	dedupe = {},
	installed = false,
	prevErrorHandler = nil,
	ownHandlerActive = false,
	coverage = {
		ownErrors = 0,
		capturedLuaErrors = 0,
		suppressedDuplicates = 0,
		note = "Own module + optional seterrorhandler chain only; other addons not fully covered.",
	},
}

local function newSessionId()
	return string.format("%s-%d-%d", Version.STRING or "0", Time.Now(), math.random(1000, 9999))
end

local function fingerprint(entry)
	local msg = (entry.message or ""):gsub("%d+", "N"):gsub("%s+", " ")
	local stackSig = ""
	if entry.stack then
		stackSig = entry.stack:gsub("%d+", "N"):gsub(":%d+", ":N"):sub(1, 200)
	end
	return table.concat({
		entry.code or "",
		entry.module or "",
		entry.func or "",
		msg:sub(1, 160),
		stackSig,
	}, "|")
end

function Logger.Init()
	if private.buffer then
		return
	end
	private.sessionId = newSessionId()
	private.buffer = RB.New(C.LOG_RING_SIZE)
	math.randomseed(Time.Now() % 1e8)
end

function Logger.GetSessionId()
	return private.sessionId
end

function Logger.GetCoverage()
	return private.coverage
end

local function persist(entry)
	if not WoWSmartTSM_Diagnostics then
		return
	end
	WoWSmartTSM_Diagnostics.sessionId = private.sessionId
	WoWSmartTSM_Diagnostics.lastWrite = Time.Now()
	WoWSmartTSM_Diagnostics.entries = WoWSmartTSM_Diagnostics.entries or {}
	-- Keep persistent capped list
	local list = WoWSmartTSM_Diagnostics.entries
	list[#list + 1] = entry
	while #list > C.LOG_RING_SIZE do
		table.remove(list, 1)
	end
	WoWSmartTSM_Diagnostics.dedupe = WoWSmartTSM_Diagnostics.dedupe or {}
	local fp = entry.fingerprint
	local d = WoWSmartTSM_Diagnostics.dedupe[fp]
	if d then
		d.count = (d.count or 1) + 1
		d.lastSeen = entry.timestamp
	else
		WoWSmartTSM_Diagnostics.dedupe[fp] = {
			count = 1,
			firstSeen = entry.timestamp,
			lastSeen = entry.timestamp,
			code = entry.code,
			severity = entry.severity,
			message = entry.message,
		}
	end
end

function Logger.Log(severity, codeKey, moduleName, funcName, message, ctx)
	Logger.Init()
	local code = ErrorCodes.Get(codeKey)
	if type(codeKey) == "string" and codeKey:match("^E%d+") then
		code = codeKey
	end
	local client = Version.GetClientInfo()
	local entry = {
		timestamp = Time.Now(),
		iso = Time.ISO(),
		sessionId = private.sessionId,
		addonVersion = Version.GetAddonVersion(),
		clientVersion = client and client.version or nil,
		clientBuild = client and client.build or nil,
		tocversion = client and client.tocversion or nil,
		tsmVersion = Version.GetTSMVersion(),
		severity = severity or C.SEVERITY.INFO,
		code = code,
		codeKey = codeKey,
		module = moduleName,
		func = funcName,
		message = Privacy.SanitizeString(tostring(message or "")),
		stack = nil,
		itemId = ctx and ctx.itemId or nil,
		group = ctx and ctx.group or nil,
		priceSources = ctx and ctx.priceSources or nil,
		state = ctx and Privacy.SanitizeTable(ctx.state or ctx) or nil,
		count = 1,
	}

	if severity == C.SEVERITY.ERROR or severity == C.SEVERITY.CRITICAL then
		entry.stack = Privacy.SanitizeString(debugstack and debugstack(3) or nil)
	end

	entry.fingerprint = fingerprint(entry)

	local prev = private.dedupe[entry.fingerprint]
	if prev then
		prev.count = prev.count + 1
		prev.lastSeen = entry.timestamp
		entry.count = prev.count
		private.coverage.suppressedDuplicates = private.coverage.suppressedDuplicates + 1
		-- Still update last occurrence lightly
		persist(entry)
		return entry
	end
	private.dedupe[entry.fingerprint] = entry
	RB.Push(private.buffer, entry)
	persist(entry)
	private.coverage.ownErrors = private.coverage.ownErrors + 1

	if severity == C.SEVERITY.ERROR or severity == C.SEVERITY.CRITICAL then
		print("|cffff6666[SmartTSM]|r " .. entry.code .. " " .. entry.message)
	end
	return entry
end

function Logger.Debug(codeKey, moduleName, funcName, message, ctx)
	return Logger.Log(C.SEVERITY.DEBUG, codeKey, moduleName, funcName, message, ctx)
end
function Logger.Info(codeKey, moduleName, funcName, message, ctx)
	return Logger.Log(C.SEVERITY.INFO, codeKey, moduleName, funcName, message, ctx)
end
function Logger.Warning(codeKey, moduleName, funcName, message, ctx)
	return Logger.Log(C.SEVERITY.WARNING, codeKey, moduleName, funcName, message, ctx)
end
function Logger.Error(codeKey, moduleName, funcName, message, ctx)
	return Logger.Log(C.SEVERITY.ERROR, codeKey, moduleName, funcName, message, ctx)
end
function Logger.Critical(codeKey, moduleName, funcName, message, ctx)
	return Logger.Log(C.SEVERITY.CRITICAL, codeKey, moduleName, funcName, message, ctx)
end

function Logger.GetEntries()
	Logger.Init()
	if WoWSmartTSM_Diagnostics and WoWSmartTSM_Diagnostics.entries then
		return WoWSmartTSM_Diagnostics.entries
	end
	return RB.ToArray(private.buffer)
end

function Logger.InstallErrorHandler()
	if private.installed then
		return
	end
	private.installed = true
	private.prevErrorHandler = geterrorhandler and geterrorhandler() or nil
	if not seterrorhandler then
		return
	end
	seterrorhandler(function(msg)
		if private.ownHandlerActive then
			if private.prevErrorHandler then
				return private.prevErrorHandler(msg)
			end
			return
		end
		private.ownHandlerActive = true
		private.coverage.capturedLuaErrors = private.coverage.capturedLuaErrors + 1
		local ok, err = pcall(function()
			Logger.Error("UNKNOWN", "Lua", "errorhandler", tostring(msg), {
				state = { raw = Privacy.SanitizeString(tostring(msg)) },
			})
		end)
		private.ownHandlerActive = false
		if not ok and DEFAULT_CHAT_FRAME then
			DEFAULT_CHAT_FRAME:AddMessage("|cffff6666[SmartTSM] logger failed:|r " .. tostring(err))
		end
		-- Always chain to previous (BugSack / Blizzard)
		if private.prevErrorHandler then
			return private.prevErrorHandler(msg)
		end
	end)
end
