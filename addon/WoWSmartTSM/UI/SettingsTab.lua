local Smart = WoWSmartTSM
local Locale = Smart:Module("Locale")
local Layout = Smart:Module("Layout")
local Theme = Smart:Module("Theme")
local SettingsTab = Smart:Module("SettingsTab")

function SettingsTab.Render(parent)
	local db = WoWSmartTSM_DB.settings
	local root = Layout.Begin(parent)
	Layout.HeaderTitle(root.header, Locale.T("SETTINGS"))
	local stack = Layout.BodyStack(root)

	Layout.AddText(stack, "Allgemein", "GameFontNormal")
	Layout.AddText(stack, "Locale: " .. tostring(db.locale), "GameFontHighlight")
	Layout.AddText(stack, "AH Cut: " .. tostring(db.ahCut), "GameFontHighlight")
	Layout.AddText(stack, "Deposit Fallback: " .. tostring(db.depositRateFallback), "GameFontHighlight")
	Layout.AddText(stack, "Auction Hours: " .. tostring(db.auctionHours), "GameFontHighlight")
	Layout.AddText(stack, "Data Max Age (s): " .. tostring(db.dataMaxAgeSeconds), "GameFontHighlight")
	Layout.AddText(stack, "Dry-Run Vendor: " .. tostring(db.dryRunVendor), "GameFontHighlight")
	Layout.AddText(stack, "Debug: " .. tostring(db.debug), "GameFontHighlight")
	Layout.AddGap(stack, 10)
	Layout.AddButtonRow(stack, {
		{
			text = "Locale de/en",
			width = 120,
			onClick = function()
				db.locale = (db.locale == "deDE") and "enUS" or "deDE"
				SettingsTab.Render(parent)
			end,
		},
		{
			text = "Dry-Run umschalten",
			width = 140,
			onClick = function()
				db.dryRunVendor = not db.dryRunVendor
				SettingsTab.Render(parent)
			end,
		},
		{
			text = "Debug umschalten",
			width = 130,
			onClick = function()
				db.debug = not db.debug
				SettingsTab.Render(parent)
			end,
		},
	})
	Layout.AddGap(stack, 8)
	Layout.AddText(
		stack,
		"AH-Cut/Deposit sind PARTIAL verifiziert und konfigurierbar. Globale TSM-Operationen werden nicht verändert.",
		"GameFontHighlightSmall",
		Theme.COLORS.muted
	)
	Layout.FinishStack(stack)
	Layout.FooterText(root.footer, "Einstellungen werden in SavedVariables gespeichert (Flush bei Logout/Reload).")
end
