local Smart = WoWSmartTSM
local MainFrame = Smart:Module("MainFrame")
local UI = Smart:Module("UI")

local private = {
	lastTab = nil,
	lastStatus = nil,
	emptyRetries = {},
	chatOnce = {},
}

local TAB_MAP = {
	Cleanup = "CleanupTab",
	Dashboard = "Dashboard",
	Groups = "GroupsTab",
	Posting = "PostingTab",
	Mail = "MailTab",
	Skipped = "SkippedTab",
	Vendor = "VendorTab",
	Hold = "HoldTab",
	Characters = "CharactersTab",
	Rules = "RulesTab",
	Setup = "SetupWizard",
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

local function getLayout()
	return Smart:GetModule("Layout")
end

local function logUi(codeKey, funcName, message, state)
	local Logger = Smart:GetModule("Logger")
	if not Logger then
		return
	end
	if codeKey == "UI_RENDER_FAILED" or codeKey == "UI_CONTENT_EMPTY" or codeKey == "UI_ERROR" then
		if Logger.Error then
			Logger.Error(codeKey, "UI", funcName, message, { state = state })
			return
		end
	end
	if Logger.Info then
		Logger.Info(codeKey, "UI", funcName, message, { state = state })
	elseif Logger.Log then
		Logger.Log("INFO", codeKey, "UI", funcName, message, { state = state })
	end
end

local function chatOnce(key, message)
	if private.chatOnce[key] then
		return
	end
	private.chatOnce[key] = true
	print("|cffff6666[SmartTSM]|r " .. tostring(message))
end

local function moduleStatus(modName)
	local mod = modName and Smart:GetModule(modName) or nil
	return {
		name = modName,
		present = mod ~= nil,
		hasRender = mod ~= nil and type(mod.Render) == "function",
	}
end

---Emergency visible text when Layout helpers are unavailable.
local function emergencyText(parent, title, detail)
	if not parent or not parent.CreateFontString then
		return false
	end
	local ok = pcall(function()
		if parent._smartEmergency then
			parent._smartEmergency:Hide()
		end
		local fs = parent:CreateFontString(nil, "OVERLAY", "GameFontNormal")
		fs:SetPoint("TOPLEFT", 16, -16)
		fs:SetPoint("TOPRIGHT", -16, -16)
		fs:SetJustifyH("LEFT")
		fs:SetWordWrap(true)
		fs:SetText(tostring(title or "UI-Fehler") .. "\n\n" .. tostring(detail or ""))
		fs:Show()
		parent._smartEmergency = fs
	end)
	return ok
end

local function showFallback(parent, title, detail)
	local Layout = getLayout()
	if not (Layout and type(Layout.Begin) == "function") then
		return emergencyText(parent, title, detail)
	end
	local ok = pcall(function()
		local root = Layout.Begin(parent)
		Layout.HeaderTitle(root.header, title or "UI-Fehler")
		local stack = Layout.BodyStack(root)
		Layout.AddText(stack, tostring(detail or ""))
		Layout.FinishStack(stack)
		Layout.FooterText(root.footer, "Diagnose-Tab bleibt erreichbar.")
	end)
	if not ok then
		return emergencyText(parent, title, detail)
	end
	return true
end

function UI.GetLastRenderStatus()
	return private.lastStatus
end

function UI.RenderTab(name, parent)
	local started = now()
	local Layout = getLayout()
	local modName = TAB_MAP[name]
	local status = {
		tab = name,
		modName = modName,
		startedAt = started,
		module = moduleStatus(modName),
		layoutBegin = Layout ~= nil and type(Layout.Begin) == "function",
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

	if not status.layoutBegin then
		status.renderStatus = "FAILED"
		status.error = "Layout.Begin is nil — UI/Layout.lua failed to load (check Lua parse errors)"
		logUi("UI_RENDER_FAILED", "RenderTab", status.error, status)
		chatOnce("layout_begin_nil", status.error)
		showFallback(parent, "Layout nicht geladen", status.error)
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
		-- One chat line per distinct error fingerprint (Logger also dedupes).
		chatOnce("render:" .. tostring(name) .. ":" .. tostring(err), "E5005 " .. tostring(err))
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
