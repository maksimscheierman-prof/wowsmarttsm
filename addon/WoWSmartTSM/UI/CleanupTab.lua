local Smart = WoWSmartTSM
local Locale = Smart:Module("Locale")
local Layout = Smart:Module("Layout")
local Theme = Smart:Module("Theme")
local Money = Smart:Module("MoneyUtil")
local C = Smart:Module("Constants")
local CleanupService = Smart:Module("CleanupService")
local ItemRules = Smart:Module("ItemRules")
local CleanupTab = Smart:Module("CleanupTab")

local private = {
	selected = {},
	filter = "ALL",
}

local function selectedCount()
	local n = 0
	for _ in pairs(private.selected) do
		n = n + 1
	end
	return n
end

function CleanupTab.Render(parent)
	local L = Locale.T
	local ScanService = Smart:GetModule("ScanService")
	local CP = Smart:GetModule("CharacterProfiles")
	local results = ScanService.GetLastResults() or {}
	local sum = CleanupService.Summarize(results)
	local shown = CleanupService.Filter(results, private.filter)
	local bankOk = CP.IsBankConfigured()

	local root = Layout.Begin(parent)
	local _, bw = Layout.HeaderButton(root.header, L("SCAN"), function()
		ScanService.ReevaluateBags({ reason = "cleanup_ui" })
		CleanupTab.Render(parent)
	end)
	Layout.HeaderTitle(root.header, L("CLEANUP"), (bw or 160) + 12)

	local stack = Layout.BodyStack(root)
	Layout.AddText(stack, "Inventar aufräumen", "GameFontNormal")
	Layout.AddMetricGrid(stack, {
		{ "An Bank senden", sum.mailToBank, Theme.COLORS.post },
		{ "Händler", sum.vendor, Theme.COLORS.vendor },
		{ "Behalten", sum.keep, Theme.COLORS.muted },
		{ "Hold → Bank", sum.holdAtBank, Theme.COLORS.hold },
		{ "Prüfung", sum.review, Theme.COLORS.warn },
	}, 5)

	if not bankOk then
		Layout.AddGap(stack, 6)
		Layout.AddText(
			stack,
			"BANK_CHARACTER_NOT_CONFIGURED — Kein Bankcharakter festgelegt. Mail-Aktionen sind blockiert.",
			"GameFontNormal",
			Theme.COLORS.bad
		)
		Layout.AddButtonRow(stack, {
			{
				text = "Bankcharakter wählen",
				tooltip = "Charakter-Tab öffnen",
				onClick = function()
					local MainFrame = Smart:GetModule("MainFrame")
					if MainFrame and MainFrame.SelectTab then
						MainFrame.SelectTab("Characters")
					end
				end,
			},
		})
	else
		Layout.AddText(
			stack,
			"Bank: " .. tostring(CP.GetPrimaryBankDisplay() or CP.GetPrimaryBankKey()),
			"GameFontHighlightSmall",
			Theme.COLORS.muted
		)
	end

	Layout.AddGap(stack, 4)
	Layout.AddButtonRow(stack, {
		{ text = "Alle", onClick = function()
			private.filter = "ALL"
			CleanupTab.Render(parent)
		end },
		{ text = "Mail", onClick = function()
			private.filter = C.ACTIONS.MAIL_TO_BANK
			CleanupTab.Render(parent)
		end },
		{ text = "Vendor", onClick = function()
			private.filter = C.ACTIONS.VENDOR
			CleanupTab.Render(parent)
		end },
		{ text = "Keep", onClick = function()
			private.filter = C.ACTIONS.KEEP
			CleanupTab.Render(parent)
		end },
		{ text = "Hold", onClick = function()
			private.filter = C.ACTIONS.HOLD_AT_BANK
			CleanupTab.Render(parent)
		end },
		{ text = "Unsicher", onClick = function()
			private.filter = "UNSAFE"
			CleanupTab.Render(parent)
		end },
	})

	local columns = {
		{ title = "Sel", width = 32 },
		{ title = "Item", width = 160 },
		{ title = "Menge", width = 48 },
		{ title = "Markt", width = 80 },
		{ title = "Händler", width = 80 },
		{ title = "Aktion", width = 100 },
		{ title = "Gruppe", width = 140 },
		{ title = "Grund", width = 140 },
	}
	local rows = {}
	for _, d in ipairs(shown) do
		local name = d.name or d.itemString or "?"
		rows[#rows + 1] = {
			private.selected[d.itemString] and "✓" or "",
			{ text = name, fullText = name, color = Theme.StrategyColor(d.strategy) },
			tostring(d.actionQty or d.quantity or 1),
			Money.Format(d.marketValue or 0, true),
			Money.Format(d.vendorSell or 0, true),
			CleanupService.ActionLabel(d.inventoryAction),
			d.targetGroup or "-",
			(d.actionReasons and d.actionReasons[1]) or (d.reasons and d.reasons[1]) or "-",
			_decision = d,
		}
	end

	Layout.AddTable(stack, columns, rows, {
		rowHeight = 22,
		onClick = function(row)
			local d = row._decision
			if not d or not d.itemString then
				return
			end
			if private.selected[d.itemString] then
				private.selected[d.itemString] = nil
			else
				private.selected[d.itemString] = true
			end
			CleanupTab.Render(parent)
		end,
		onEnter = function(row)
			local d = row._decision
			if not d then
				return
			end
			GameTooltip:SetOwner(UIParent, "ANCHOR_CURSOR")
			GameTooltip:AddLine(d.name or "?", 1, 1, 1)
			GameTooltip:AddLine("Strategie: " .. tostring(d.strategy), 0.7, 0.85, 0.7)
			GameTooltip:AddLine("Aktion: " .. tostring(d.inventoryAction), 0.7, 0.85, 0.9)
			GameTooltip:AddLine("Rechtsklick-Menü: Regeln setzen", 0.6, 0.6, 0.6)
			GameTooltip:AddLine(table.concat(d.actionReasons or d.reasons or {}, ", "), 0.8, 0.8, 0.75, true)
			GameTooltip:Show()
		end,
		onLeave = function()
			GameTooltip:Hide()
		end,
	})

	Layout.AddButtonRow(stack, {
		{
			text = "Alle wählen",
			onClick = function()
				for _, d in ipairs(shown) do
					if d.itemString then
						private.selected[d.itemString] = true
					end
				end
				CleanupTab.Render(parent)
			end,
		},
		{
			text = "Keine",
			onClick = function()
				wipe(private.selected)
				CleanupTab.Render(parent)
			end,
		},
		{
			text = "Behalten (dauerhaft)",
			tooltip = "Auswahl als Charakter-Regel KEEP speichern",
			onClick = function()
				for itemString in pairs(private.selected) do
					ItemRules.Set(itemString, { type = "KEEP" }, "character")
				end
				print("|cff4ecdc4[SmartTSM]|r Keep-Regeln gespeichert:", selectedCount())
				ScanService.ReevaluateBags({ reason = "rules_changed" })
				CleanupTab.Render(parent)
			end,
		},
		{
			text = "Ignorieren (einmal)",
			onClick = function()
				for itemString in pairs(private.selected) do
					ItemRules.Set(itemString, { type = "IGNORE" }, "once")
				end
				ScanService.ReevaluateBags({ reason = "rules_changed" })
				CleanupTab.Render(parent)
			end,
		},
		{
			text = "Mail-Plan",
			tooltip = "Mail-Tab: Versandplan für MAIL_TO_BANK / HOLD_AT_BANK",
			onClick = function()
				local MainFrame = Smart:GetModule("MainFrame")
				if MainFrame then
					MainFrame.SelectTab("Mail")
				end
			end,
		},
	})
	Layout.AddText(
		stack,
		"Strategie ≠ Transport. RARE_SELL kann trotzdem MAIL_TO_BANK heißen. Kein Versand/Vendor ohne Bestätigung.",
		"GameFontHighlightSmall",
		Theme.COLORS.muted
	)
	Layout.FinishStack(stack)
	Layout.FooterText(root.footer, string.format("Filter=%s | %d ausgewählt / %d sichtbar", private.filter, selectedCount(), #shown))
end
