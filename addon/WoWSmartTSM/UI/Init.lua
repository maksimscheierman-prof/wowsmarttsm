local Smart = WoWSmartTSM
local MainFrame = Smart:Module("MainFrame")
local Layout = Smart:Module("Layout")
local UI = Smart:Module("UI")

function UI.RenderTab(name, parent)
	local map = {
		Dashboard = "Dashboard",
		Posting = "PostingTab",
		Skipped = "SkippedTab",
		Vendor = "VendorTab",
		Hold = "HoldTab",
		History = "HistoryTab",
		Settings = "SettingsTab",
		Diagnostics = "DiagnosticsTab",
	}
	-- Always clear host before render to prevent FontString overlap
	if Layout and Layout.ClearHost then
		-- Begin() inside each tab also clears; ensure host is clean if render fails early
	end
	local modName = map[name]
	local mod = modName and Smart:GetModule(modName)
	if mod and mod.Render then
		local ok, err = pcall(mod.Render, parent)
		if not ok then
			local Logger = Smart:GetModule("Logger")
			if Logger and Logger.Error then
				Logger.Error("UI_ERROR", "UI", "RenderTab", tostring(err), { state = { tab = name } })
			end
			if Layout and Layout.Begin then
				local root = Layout.Begin(parent)
				Layout.HeaderTitle(root.header, "UI-Fehler")
				local stack = Layout.BodyStack(root)
				Layout.AddText(stack, tostring(err))
				Layout.FinishStack(stack)
			end
		end
	end
end

function UI.Toggle()
	MainFrame.Toggle()
end

function UI.Init()
	-- Lazy create on first open
end
