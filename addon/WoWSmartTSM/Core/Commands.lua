local Smart = WoWSmartTSM
local SlashDiag = Smart:Module("SlashDiag")
local Commands = Smart:Module("Commands")

local function openUI()
	local UI = Smart:GetModule("UI")
	if UI and UI.Toggle then
		UI.Toggle()
	else
		print("|cff4ecdc4[SmartTSM]|r UI not ready")
	end
end

function Commands.Handle(msg)
	msg = (msg or ""):match("^%s*(.-)%s*$") or ""
	local cmd, rest = msg:match("^(%S+)%s*(.*)$")
	cmd = cmd and cmd:lower() or ""
	if cmd == "" or cmd == "show" or cmd == "toggle" then
		openUI()
	elseif cmd == "status" then
		SlashDiag.Status()
	elseif cmd == "errors" then
		SlashDiag.Errors(tonumber(rest) or 15)
	elseif cmd == "diagnose" then
		SlashDiag.Diagnose()
	elseif cmd == "debug" then
		SlashDiag.DebugToggle()
	elseif cmd == "reset" then
		SlashDiag.Reset(rest)
	elseif cmd == "scan" then
		local ScanService = Smart:GetModule("ScanService")
		local results = ScanService.RunBagScan()
		local sum = ScanService.Summarize(results)
		print(string.format("|cff4ecdc4[SmartTSM]|r Scan: post=%d vendor=%d hold=%d review=%d", sum.toPost, sum.vendor, sum.hold, sum.review))
		openUI()
	elseif cmd == "help" then
		print("|cff4ecdc4[SmartTSM]|r /smarttsm [show|scan|status|errors|diagnose|debug|reset|help]")
	else
		print("|cff4ecdc4[SmartTSM]|r Unknown command. /smarttsm help")
	end
end

function Commands.Register()
	SLASH_SMARTTSM1 = "/smarttsm"
	SLASH_SMARTTSM2 = "/wsmarttsm"
	SlashCmdList["SMARTTSM"] = function(msg)
		Commands.Handle(msg)
	end
end
