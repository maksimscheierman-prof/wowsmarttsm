local Smart = WoWSmartTSM
local Locale = Smart:Module("Locale")
local Layout = Smart:Module("Layout")
local Theme = Smart:Module("Theme")
local C = Smart:Module("Constants")
local CharactersTab = Smart:Module("CharactersTab")

function CharactersTab.Render(parent)
	local CP = Smart:GetModule("CharacterProfiles")
	local cur = CP.EnsureCurrent()
	local list = CP.List()
	local bank = CP.GetPrimaryBankKey()

	local root = Layout.Begin(parent)
	Layout.HeaderTitle(root.header, Locale.T("CHARACTERS"))
	local stack = Layout.BodyStack(root)

	Layout.AddText(stack, "Aktueller Charakter", "GameFontNormal")
	Layout.AddText(stack, "Key: " .. tostring(cur.key), "GameFontHighlightSmall", Theme.COLORS.muted)
	Layout.AddText(stack, "Rolle: " .. tostring(cur.role), "GameFontHighlight")
	Layout.AddText(stack, "Primärer Bankcharakter: " .. tostring(bank or "NICHT GESETZT"), "GameFontHighlight", bank and Theme.COLORS.ok or Theme.COLORS.bad)

	Layout.AddGap(stack, 8)
	Layout.AddText(stack, "Rolle setzen", "GameFontNormal")
	Layout.AddButtonRow(stack, {
		{
			text = "MAIN",
			onClick = function()
				CP.ApplyMainDefaults(cur)
				CP.SetRole(cur.key, C.ROLES.MAIN)
				CharactersTab.Render(parent)
			end,
		},
		{
			text = "BANK",
			onClick = function()
				CP.SetRole(cur.key, C.ROLES.BANK)
				CharactersTab.Render(parent)
			end,
		},
		{
			text = "MANUAL",
			onClick = function()
				CP.SetRole(cur.key, C.ROLES.MANUAL)
				CharactersTab.Render(parent)
			end,
		},
		{
			text = "Als Bank festlegen",
			tooltip = "Diesen Charakter als primären Bank-Empfänger setzen",
			onClick = function()
				CP.SetPrimaryBankKey(cur.key)
				CP.SetRole(cur.key, C.ROLES.BANK)
				print("|cff4ecdc4[SmartTSM]|r Primärer Bankcharakter:", cur.key)
				CharactersTab.Render(parent)
			end,
		},
		{
			text = "Bank löschen",
			onClick = function()
				CP.SetPrimaryBankKey(nil)
				CharactersTab.Render(parent)
			end,
		},
	})

	Layout.AddGap(stack, 10)
	Layout.AddText(stack, "Bekannte Charaktere", "GameFontNormal")
	local columns = {
		{ title = "Key", width = 280 },
		{ title = "Rolle", width = 80 },
		{ title = "Name", width = 120 },
	}
	local rows = {}
	for _, ch in ipairs(list) do
		rows[#rows + 1] = {
			{ text = ch.key, fullText = ch.key },
			ch.role or "?",
			ch.name or "?",
		}
	end
	if #rows == 0 then
		Layout.AddText(stack, "Noch keine gespeicherten Profile (Login erzeugt eines).", "GameFontHighlightSmall", Theme.COLORS.muted)
	else
		Layout.AddTable(stack, columns, rows, { rowHeight = 22 })
		Layout.AddText(stack, "Tipp: Auf dem Bankcharakter einloggen → „Als Bank festlegen“, dann auf MAIN zurück.", "GameFontHighlightSmall", Theme.COLORS.muted)
	end

	Layout.AddGap(stack, 8)
	Layout.AddText(stack, "MAIN-Defaults: AutoEval an, Verbrauch/Crafting schützen, Smart Hold→Bank, kein Auto-Mail/Vendor.", "GameFontHighlightSmall", Theme.COLORS.muted)
	Layout.FinishStack(stack)
	Layout.FooterText(root.footer, "Profil gespeichert in SavedVariables (Flush bei Logout/Reload)")
end
