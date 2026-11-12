local Smart = WoWSmartTSM
local Locale = Smart:Module("Locale")
local Layout = Smart:Module("Layout")
local Theme = Smart:Module("Theme")
local ItemRules = Smart:Module("ItemRules")
local Consumables = Smart:Module("Consumables")
local CraftingReserve = Smart:Module("CraftingReserve")
local RulesTab = Smart:Module("RulesTab")

function RulesTab.Render(parent)
	local root = Layout.Begin(parent)
	Layout.HeaderTitle(root.header, Locale.T("RULES"))
	local stack = Layout.BodyStack(root)

	Layout.AddText(stack, "Regelverwaltung (sichtbar & editierbar)", "GameFontNormal")
	Layout.AddText(
		stack,
		"Priorität: Hart schützen → Ignore/Keep → Crafting → Verbrauch → Smart Hold → Markt.",
		"GameFontHighlightSmall",
		Theme.COLORS.muted
	)
	Layout.AddGap(stack, 6)

	local rules = ItemRules.ListAll()
	local columns = {
		{ title = "Item", width = 160 },
		{ title = "Typ", width = 80 },
		{ title = "Scope", width = 90 },
		{ title = "Min", width = 50 },
	}
	local rows = {}
	for _, e in ipairs(rules) do
		rows[#rows + 1] = {
			{ text = e.itemString, fullText = e.itemString },
			(e.rule and e.rule.type) or "?",
			e.scope or "?",
			tostring((e.rule and e.rule.minQty) or ""),
		}
	end
	if #rows == 0 then
		Layout.AddText(stack, "Keine gespeicherten Itemregeln.", "GameFontHighlight", Theme.COLORS.muted)
	else
		Layout.AddTable(stack, columns, rows, { rowHeight = 22 })
	end

	Layout.AddGap(stack, 8)
	Layout.AddButtonRow(stack, {
		{
			text = "Session-Ignore leeren",
			onClick = function()
				local s = WoWSmartTSM_DB.itemRules
				if s then
					wipe(s.sessionIgnore)
				end
				print("|cff4ecdc4[SmartTSM]|r Session-Ignore geleert")
				RulesTab.Render(parent)
			end,
		},
	})
	Layout.AddText(
		stack,
		"MAIN: Verbrauchsgüter/Materialien standardmäßig schützen. BANK: AH-Verkauf bewerten. "
			.. "Optionale Reservemenge pro Item/Charakter via Consumables.SetMinQty — kein stilles Abschalten des Schutzes.",
		"GameFontHighlightSmall",
		Theme.COLORS.muted
	)
	Layout.FinishStack(stack)
	Layout.FooterText(root.footer, string.format("%d Regeln", #rules))
end
