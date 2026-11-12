local Smart = WoWSmartTSM
local Locale = Smart:Module("Locale")
local Widgets = Smart:Module("Widgets")
local SettingsTab = Smart:Module("SettingsTab")

function SettingsTab.Render(parent)
	for _, child in ipairs({ parent:GetChildren() }) do
		child:Hide()
		child:SetParent(nil)
	end
	local db = WoWSmartTSM_DB.settings
	local title = Widgets.Label(parent, Locale.T("SETTINGS"), 14)
	title:SetPoint("TOPLEFT", 16, -16)

	local function row(y, label, value)
		local l = Widgets.Label(parent, label .. ": " .. tostring(value), 12)
		l:SetPoint("TOPLEFT", 16, y)
		return y - 22
	end

	local y = -48
	y = row(y, "Locale", db.locale)
	y = row(y, "AH Cut", db.ahCut)
	y = row(y, "Deposit Fallback Rate", db.depositRateFallback)
	y = row(y, "Auction Hours", db.auctionHours)
	y = row(y, "Data Max Age (s)", db.dataMaxAgeSeconds)
	y = row(y, "Dry-Run Vendor", db.dryRunVendor)
	y = row(y, "Debug", db.debug)

	local locBtn = Widgets.Button(parent, "Locale deDE/enUS", 140, 24, function()
		db.locale = (db.locale == "deDE") and "enUS" or "deDE"
		SettingsTab.Render(parent)
	end)
	locBtn:SetPoint("TOPLEFT", 16, y - 10)

	local dryBtn = Widgets.Button(parent, "Toggle Dry-Run Vendor", 180, 24, function()
		db.dryRunVendor = not db.dryRunVendor
		SettingsTab.Render(parent)
	end)
	dryBtn:SetPoint("LEFT", locBtn, "RIGHT", 8, 0)

	local note = Widgets.Label(parent, "AH-Cut/Deposit sind PARTIAL verifiziert — Werte anpassbar. Keine globalen TSM-Ops ändern.", 11)
	note:SetPoint("BOTTOMLEFT", 16, 16)
end
