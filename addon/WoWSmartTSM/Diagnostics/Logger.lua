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
	sessionSeq = 0,
	buffer = nil,
	dedupe = {},
	installed = false,
	prevErrorHandler = nil,
	ownHandlerActive = false,
	initFailed = false,
	initError = nil,
	earlyErrors = {},
	coverage = {
		ownErrors = 0,
		capturedLuaErrors = 0,
		suppressedDuplicates = 0,
		earlyErrors = 0,
		note = "Own module + optional seterrorhandler chain only; other addons not fully covered.",
	},
}

---WoW Forever–safe session id: no math.randomseed / no reliance on math.random.
local function newSessionId()
	private.sessionSeq = (private.sessionSeq or 0) + 1
	local now = 0
	local okNow, n = pcall(Time.Now)
	if okNow and type(n) == "number" then
		now = math.floor(n)
	elseif type(time) == "function" then
		local okT, t = pcall(time)
		if okT and type(t) == "number" then
			now = math.floor(t)
		end
	end
	local frac = 0
	if type(GetTime) == "function" then
		local okG, gt = pcall(GetTime)
		if okG and type(gt) == "number" then
			frac = math.floor((gt - math.floor(gt)) * 1000000)
		end
	end
	return string.format("%s-%d-%d-%d", Version.STRING or "0", now, frac, private.sessionSeq)
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
		return true
	end
	local ok, err = pcall(function()
		private.sessionId = newSessionId()
		private.buffer = RB.New(C.LOG_RING_SIZE or 500)
	end)
	if not ok then
		private.initFailed = true
		private.initError = tostring(err)
		-- Minimal fallback buffer so logging still works
		private.buffer = private.buffer or RB.New(100)
		private.sessionId = private.sessionId or ("fallback-" .. tostring(private.sessionSeq or 0))
		return false
	end
	private.initFailed = false
	private.initError = nil
	return true
end

function Logger.GetSessionId()
	return private.sessionId
end

function Logger.GetCoverage()
	return private.coverage
end

function Logger.GetInitStatus()
	return {
		ok = private.buffer ~= nil and not private.initFailed,
		failed = private.initFailed,
		error = private.initError,
		sessionId = private.sessionId,
		earlyErrors = private.coverage.earlyErrors or 0,
	}
end

local function persist(entry)
	if not WoWSmartTSM_Diagnostics then
		return
	end
	WoWSmartTSM_Diagnostics.sessionId = private.sessionId
	WoWSmartTSM_Diagnostics.lastWrite = Time.Now()
	WoWSmartTSM_Diagnostics.entries = WoWSmartTSM_Diagnostics.entries or {}
	local list = WoWSmartTSM_Diagnostics.entries
	list[#list + 1] = entry
	while #list > (C.LOG_RING_SIZE or 500) do
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
	WoWSmartTSM_Diagnostics.initStatus = Logger.GetInitStatus()
end

function Logger.Log(severity, codeKey, moduleName, funcName, message, ctx)
	local initOk = true
	if not private.buffer then
		initOk = Logger.Init()
	end
	local code = ErrorCodes.Get and ErrorCodes.Get(codeKey) or tostring(codeKey)
	if type(codeKey) == "string" and codeKey:match("^E%d+") then
		code = codeKey
	end
	local client = nil
	if Version.GetClientInfo then
		local okC, c = pcall(Version.GetClientInfo)
		if okC then
			client = c
		end
	end
	local entry = {
		timestamp = Time.Now and Time.Now() or 0,
		iso = Time.ISO and Time.ISO() or nil,
		sessionId = private.sessionId,
		addonVersion = Version.GetAddonVersion and Version.GetAddonVersion() or Version.STRING,
		clientVersion = client and client.version or nil,
		clientBuild = client and client.build or nil,
		tocversion = client and client.tocversion or nil,
		tsmVersion = Version.GetTSMVersion and Version.GetTSMVersion() or nil,
		severity = severity or (C.SEVERITY and C.SEVERITY.INFO) or "INFO",
		code = code,
		codeKey = codeKey,
		module = moduleName,
		func = funcName,
		message = Privacy.SanitizeString and Privacy.SanitizeString(tostring(message or "")) or tostring(message or ""),
		stack = nil,
		itemId = ctx and ctx.itemId or nil,
		group = ctx and ctx.group or nil,
		priceSources = ctx and ctx.priceSources or nil,
		state = ctx and (Privacy.SanitizeTable and Privacy.SanitizeTable(ctx.state or ctx) or ctx) or nil,
		count = 1,
		loggerInitOk = initOk and not private.initFailed,
	}

	if severity == (C.SEVERITY and C.SEVERITY.ERROR) or severity == (C.SEVERITY and C.SEVERITY.CRITICAL) or severity == "ERROR" or severity == "CRITICAL" then
		if debugstack then
			local okS, st = pcall(debugstack, 3)
			if okS then
				entry.stack = Privacy.SanitizeString and Privacy.SanitizeString(st) or st
			end
		end
	end

	entry.fingerprint = fingerprint(entry)

	local prev = private.dedupe[entry.fingerprint]
	if prev then
		prev.count = prev.count + 1
		prev.lastSeen = entry.timestamp
		entry.count = prev.count
		private.coverage.suppressedDuplicates = private.coverage.suppressedDuplicates + 1
		persist(entry)
		return entry
	end
	private.dedupe[entry.fingerprint] = entry
	if private.buffer then
		RB.Push(private.buffer, entry)
	else
		private.earlyErrors[#private.earlyErrors + 1] = entry
		private.coverage.earlyErrors = (private.coverage.earlyErrors or 0) + 1
	end
	persist(entry)
	private.coverage.ownErrors = private.coverage.ownErrors + 1

	if severity == "ERROR" or severity == "CRITICAL" or severity == (C.SEVERITY and C.SEVERITY.ERROR) or severity == (C.SEVERITY and C.SEVERITY.CRITICAL) then
		print("|cffff6666[SmartTSM]|r " .. tostring(entry.code) .. " " .. tostring(entry.message))
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
	local arr = RB.ToArray(private.buffer)
	for _, e in ipairs(private.earlyErrors) do
		arr[#arr + 1] = e
	end
	return arr
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
				state = { raw = Privacy.SanitizeString and Privacy.SanitizeString(tostring(msg)) or tostring(msg) },
			})
		end)
		private.ownHandlerActive = false
		if not ok and DEFAULT_CHAT_FRAME then
			DEFAULT_CHAT_FRAME:AddMessage("|cffff6666[SmartTSM] logger failed:|r " .. tostring(err))
		end
		if private.prevErrorHandler then
			return private.prevErrorHandler(msg)
		end
	end)
end
