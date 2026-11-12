local Smart = WoWSmartTSM
local MainFrame = Smart:Module("MainFrame")
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
	local modName = map[name]
	local mod = modName and Smart:GetModule(modName)
	if mod and mod.Render then
		local ok, err = pcall(mod.Render, parent)
		if not ok then
			local Logger = Smart:GetModule("Logger")
			Logger.Error("UI_ERROR", "UI", "RenderTab", tostring(err), { state = { tab = name } })
		end
	end
end

function UI.Toggle()
	MainFrame.Toggle()
end

function UI.Init()
	-- Lazy create on first open
end
