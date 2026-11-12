local Smart = WoWSmartTSM
local MainFrame = Smart:Module("MainFrame")
local Layout = Smart:Module("Layout")
local UI = Smart:Module("UI")

local private = {
	lastTab = nil,
	lastStatus = nil,
	emptyRetries = {},
}

local TAB_MAP = {
	Cleanup = "CleanupTab",
	Dashboard = "Dashboard",
	Posting = "PostingTab",
	Mail = "MailTab",
	Skipped = "SkippedTab",
	Vendor = "VendorTab",
	Hold = "HoldTab",
	Characters = "CharactersTab",
	Rules = "RulesTab",
	History = "HistoryTab",
	Settings = "SettingsTab",
	Diagnostics = "DiagnosticsTab",
}

local function now()
	local Time = Smart:GetModule("TimeUtil")
	if Time and Time.Now then
		return Time.Now()
	end
	if type(time) == "function" then
		return time()
	end
	return 0
end

local function logUi(codeKey, funcName, message, state)
	local Logger = Smart:GetModule("Logger")
	if not Logger then
		return
	end
	local severity = "INFO"
	if codeKey == "UI_RENDER_FAILED" or codeKey == "UI_CONTENT_EMPTY" or codeKey == "UI_ERROR" then
		severity = "ERROR"
		if Logger.Error then
			Logger.Error(codeKey, "UI", funcName, message, { state = state })
			return
		end
	end
	if Logger.Info then
		Logger.Info(codeKey, "UI", funcName, message, { state = state })
	elseif Logger.Log then
		Logger.Log(severity, codeKey, "UI", funcName, message, { state = state })
	end
end

local function moduleStatus(modName)
	local mod = modName and Smart:GetModule(modName) or nil
	return {
		name = modName,
		present = mod ~= nil,
		hasRender = mod ~= nil and type(mod.Render) == "function",
	}
end

local function showFallback(parent, title, detail)
	if not (Layout and Layout.Begin) then
		return false
	end
	local ok = pcall(function()
		local root = Layout.Begin(parent)
		Layout.HeaderTitle(root.header, title or "UI-Fehler")
		local stack = Layout.BodyStack(root)
		Layout.AddText(stack, tostring(detail or ""))
		Layout.FinishStack(stack)
		Layout.FooterText(root.footer, "Diagnose-Tab bleibt erreichbar.")
	end)
	return ok
end

function UI.GetLastRenderStatus()
	return private.lastStatus
end

function UI.RenderTab(name, parent)
	local started = now()
	local modName = TAB_MAP[name]
	local status = {
		tab = name,
		modName = modName,
		startedAt = started,
		module = moduleStatus(modName),
		renderStatus = "STARTED",
		error = nil,
		empty = false,
	}
	private.lastTab = name
	private.lastStatus = status

	logUi("UI_TAB_SELECTED", "RenderTab", "tab=" .. tostring(name), status)
	logUi("UI_RENDER_STARTED", "RenderTab", "render start", status)

	if not parent then
		status.renderStatus = "FAILED"
		status.error = "content host missing"
		logUi("UI_RENDER_FAILED", "RenderTab", status.error, status)
		return status
	end

	local mod = modName and Smart:GetModule(modName)
	if not mod or type(mod.Render) ~= "function" then
		status.renderStatus = "FAILED"
		status.error = "module missing or has no Render: " .. tostring(modName)
		logUi("UI_RENDER_FAILED", "RenderTab", status.error, status)
		showFallback(parent, "Tab nicht geladen", status.error)
		return status
	end

	local ok, err = pcall(mod.Render, parent)
	if not ok then
		status.renderStatus = "FAILED"
		status.error = tostring(err)
		logUi("UI_RENDER_FAILED", "RenderTab", status.error, status)
		showFallback(parent, "UI-Fehler", status.error)
		return status
	end

	local hasContent = Layout.HasVisibleContent and Layout.HasVisibleContent(parent)
	status.empty = not hasContent
	status.finishedAt = now()
	status.module = moduleStatus(modName)

	if not hasContent then
		status.renderStatus = "EMPTY"
		logUi("UI_CONTENT_EMPTY", "RenderTab", "unexpected empty content", status)
		-- Single recovery attempt only (no unbounded retries).
		local retries = private.emptyRetries[name] or 0
		if retries < 1 then
			private.emptyRetries[name] = retries + 1
			local ok2, err2 = pcall(mod.Render, parent)
			if ok2 and Layout.HasVisibleContent(parent) then
				status.renderStatus = "COMPLETED"
				status.empty = false
				status.recovered = true
				private.emptyRetries[name] = 0
				logUi("UI_RENDER_COMPLETED", "RenderTab", "recovered after empty", status)
				return status
			end
			if not ok2 then
				status.error = tostring(err2)
			end
		end
		showFallback(
			parent,
			"Leerer Inhalt",
			"Tab '"
				.. tostring(name)
				.. "' hat keinen sichtbaren Inhalt gerendert. "
				.. tostring(status.error or "Siehe Diagnose-Log (UI_CONTENT_EMPTY).")
		)
		logUi("UI_RENDER_FAILED", "RenderTab", "empty after recovery budget", status)
		return status
	end

	status.renderStatus = "COMPLETED"
	private.emptyRetries[name] = 0
	logUi("UI_RENDER_COMPLETED", "RenderTab", "render ok", status)
	return status
end

function UI.Toggle()
	MainFrame.Toggle()
end

function UI.Init()
	-- Lazy create on first open
end
