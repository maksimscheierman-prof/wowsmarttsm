local Smart = WoWSmartTSM
local Locale = Smart:Module("Locale")
local Layout = Smart:Module("Layout")
local Theme = Smart:Module("Theme")
local Money = Smart:Module("MoneyUtil")
local C = Smart:Module("Constants")
local CleanupService = Smart:Module("CleanupService")
local ItemRules = Smart:Module("ItemRules")
local ItemExplain = Smart:Module("ItemExplain")
local ItemContextMenu = Smart:Module("ItemContextMenu")
local CleanupTab = Smart:Module("CleanupTab")

local private = {
	selected = {}, -- [itemString] = true
	focusKey = nil, -- aggregate key / itemString for detail
	focusDecision = nil,
	filter = "ALL",
	lastIndex = nil,
}

local function selectedCount()
	local n = 0
	for _ in pairs(private.selected) do
		n = n + 1
	end
	return n
end

local function rowKey(d)
	return tostring(d.itemString or "") .. "|" .. tostring(d.inventoryAction or "") .. "|" .. tostring(d.strategy or "")
end

local function showItemTooltip(d, owner)
	if not d then
		return
	end
	GameTooltip:SetOwner(owner or UIParent, "ANCHOR_CURSOR")
	local set = false
	if d.link and GameTooltip.SetHyperlink then
		local ok = pcall(GameTooltip.SetHyperlink, GameTooltip, d.link)
		set = ok
	end
	if not set and d.itemId and GameTooltip.SetItemByID then
		local ok = pcall(GameTooltip.SetItemByID, GameTooltip, d.itemId)
		set = ok
	end
	if not set then
		GameTooltip:AddLine(d.name or "?", 1, 1, 1)
	end
	GameTooltip:AddLine(" ", 1, 1, 1)
	local human = ItemExplain.HumanReason(d)
	GameTooltip:AddLine(human, 0.85, 0.9, 0.75, true)
	GameTooltip:AddLine("Nächster Schritt: " .. ItemExplain.NextStep(d), 0.6, 0.8, 0.9, true)
	GameTooltip:AddLine("Codes: " .. table.concat(d.actionReasons or {}, ", "), 0.55, 0.55, 0.55, true)
	GameTooltip:Show()
end

local function renderDetail(stack, d)
	Layout.AddGap(stack, 8)
	Layout.AddText(stack, "Item-Detail", "GameFontNormal")
	if not d then
		Layout.AddText(stack, "Linksklick auf eine Zeile für Details. Rechtsklick für Aktionen.", "GameFontHighlightSmall", Theme.COLORS.muted)
		return
	end
	local ok, err = pcall(function()
		local lines = ItemExplain.DetailLines(d)
		for _, pair in ipairs(lines) do
			Layout.AddText(stack, pair[1] .. ":  " .. tostring(pair[2]), "GameFontHighlightSmall", Theme.COLORS.text)
		end
	end)
	if not ok then
		local Logger = Smart:GetModule("Logger")
		if Logger and Logger.Error then
			Logger.Error("ITEM_DETAIL_RENDER_FAILED", "CleanupTab", "renderDetail", tostring(err))
		end
		Layout.AddText(stack, "Detailansicht fehlgeschlagen: " .. tostring(err), "GameFontHighlight", Theme.COLORS.bad)
	end
end

function CleanupTab.Render(parent)
	local L = Locale.T
	local ScanService = Smart:GetModule("ScanService")
	local CP = Smart:GetModule("CharacterProfiles")
	local Resolver = Smart:GetModule("CharacterResolver")
	local results = ScanService.GetLastResults() or {}
	local role = CP.GetRole and CP.GetRole() or C.ROLES.MAIN
	local snap = Resolver and Resolver.Snapshot and Resolver.Snapshot() or {}
	local aggregated = CleanupService.Aggregate(CleanupService.Filter(results, private.filter))
	local sum = CleanupService.Summarize(results)
	local bankOk = CP.IsBankConfigured and CP.IsBankConfigured()
	local mailOk = snap.canMailToBank
	local mailBlock = snap.mailBlockCode

	ItemContextMenu.Hide()

	local root = Layout.Begin(parent)
	local _, bw = Layout.HeaderButton(root.header, L("SCAN"), function()
		ScanService.ReevaluateBags({ reason = "cleanup_ui" })
		CleanupTab.Render(parent)
	end)
	local title = (role == C.ROLES.BANK) and "Bank-Aufräumen" or L("CLEANUP")
	Layout.HeaderTitle(root.header, title, (bw or 160) + 12)

	local stack = Layout.BodyStack(root)
	Layout.AddText(
		stack,
		string.format("Rolle: %s | Charakter: %s", tostring(role), tostring(snap.currentKey or CP.GetCurrentKey and CP.GetCurrentKey())),
		"GameFontHighlightSmall",
		Theme.COLORS.muted
	)

	-- Role-aware metrics
	if role == C.ROLES.BANK then
		Layout.AddMetricGrid(stack, {
			{ "AH vorbereiten", sum.postAh, Theme.COLORS.post },
			{ "Händler", sum.vendor, Theme.COLORS.vendor },
			{ "Behalten", sum.keep, Theme.COLORS.muted },
			{ "Smart Hold", sum.hold, Theme.COLORS.hold },
			{ "Prüfung", sum.review, Theme.COLORS.warn },
		}, 5)
	else
		Layout.AddMetricGrid(stack, {
			{ "An Bank senden", sum.mailToBank, Theme.COLORS.post },
			{ "Händler", sum.vendor, Theme.COLORS.vendor },
			{ "Behalten", sum.keep, Theme.COLORS.muted },
			{ "Hold → Bank", sum.holdAtBank, Theme.COLORS.hold },
			{ "Prüfung", sum.review, Theme.COLORS.warn },
		}, 5)
	end

	Layout.AddGap(stack, 4)
	if role == C.ROLES.BANK then
		Layout.AddText(
			stack,
			"Bank-Charakter: AH vorbereiten — kein Versand an sich selbst.",
			"GameFontHighlightSmall",
			Theme.COLORS.ok
		)
	elseif not bankOk then
		Layout.AddText(
			stack,
			"Bankcharakter festlegen, um Items zu verschicken.",
			"GameFontNormal",
			Theme.COLORS.bad
		)
		Layout.AddButtonRow(stack, {
			{
				text = "Bankcharakter wählen",
				onClick = function()
					local MainFrame = Smart:GetModule("MainFrame")
					if MainFrame then
						MainFrame.SelectTab("Characters")
					end
				end,
			},
		})
	elseif mailBlock == "BANK_IS_SELF" then
		Layout.AddText(
			stack,
			"Du bist auf dem Bankcharakter (oder Bank=Selbst). Für AH bitte Rolle BANK / Bank-Tab nutzen.",
			"GameFontNormal",
			Theme.COLORS.warn
		)
	else
		Layout.AddText(
			stack,
			"Bank: " .. tostring(CP.GetPrimaryBankDisplay() or CP.GetPrimaryBankKey()) .. (mailOk and " (Versand möglich)" or ""),
			"GameFontHighlightSmall",
			Theme.COLORS.muted
		)
	end

	Layout.AddGap(stack, 4)
	local filters = {
		{ text = "Alle", filter = "ALL" },
		{ text = "Vendor", filter = C.ACTIONS.VENDOR },
		{ text = "Keep", filter = C.ACTIONS.KEEP },
		{ text = "Unsicher", filter = "UNSAFE" },
	}
	if role == C.ROLES.BANK then
		table.insert(filters, 2, { text = "AH", filter = C.ACTIONS.POST_AH })
		table.insert(filters, 4, { text = "Hold", filter = C.ACTIONS.HOLD })
	else
		table.insert(filters, 2, { text = "Mail", filter = C.ACTIONS.MAIL_TO_BANK })
		table.insert(filters, 4, { text = "Hold", filter = C.ACTIONS.HOLD_AT_BANK })
	end
	local filterBtns = {}
	for _, f in ipairs(filters) do
		filterBtns[#filterBtns + 1] = {
			text = f.text,
			onClick = function()
				private.filter = f.filter
				CleanupTab.Render(parent)
			end,
		}
	end
	Layout.AddButtonRow(stack, filterBtns)

	local columns = {
		{ title = "Sel", width = 28 },
		{ title = "Item", width = 150 },
		{ title = "Menge", width = 52 },
		{ title = "Markt", width = 72 },
		{ title = "Händler", width = 72 },
		{ title = "Aktion", width = 100 },
		{ title = "Begründung", width = 200 },
	}
	local rows = {}
	for idx, d in ipairs(aggregated) do
		local name = d.name or d.itemString or "?"
		local qty = d.actionQty or d.quantity or 1
		local human = ItemExplain.HumanReason(d)
		local key = rowKey(d)
		rows[#rows + 1] = {
			private.selected[d.itemString] and "✓" or "",
			{ text = name, fullText = name, color = Theme.StrategyColor(d.strategy), tooltip = name },
			"×" .. tostring(qty),
			Money.Format(d.marketValue or 0, true),
			Money.Format(d.vendorSell or 0, true),
			CleanupService.ActionLabel(d.inventoryAction),
			{ text = human, fullText = human, tooltip = table.concat(d.actionReasons or {}, ", ") },
			_decision = d,
			_index = idx,
			_key = key,
		}
	end

	Layout.AddTable(stack, columns, rows, {
		rowHeight = 22,
		isSelected = function(row)
			local d = row._decision
			return d and (private.focusKey == row._key or private.selected[d.itemString])
		end,
		onClick = function(row, index, line, shift, ctrl)
			local d = row._decision
			if not d or not d.itemString then
				return
			end
			local Logger = Smart:GetModule("Logger")
			if Logger and Logger.Info then
				Logger.Info("ITEM_SELECTED", "CleanupTab", "onClick", d.itemString or "?", {
					state = { name = d.name, action = d.inventoryAction },
				})
			end
			-- Selection: ctrl toggles multi; shift range; plain left focuses detail without forcing action
			if ctrl then
				if private.selected[d.itemString] then
					private.selected[d.itemString] = nil
				else
					private.selected[d.itemString] = true
				end
			elseif shift and private.lastIndex then
				local a, b = private.lastIndex, row._index
				if a > b then
					a, b = b, a
				end
				for i = a, b do
					local r = aggregated[i]
					if r and r.itemString then
						private.selected[r.itemString] = true
					end
				end
			else
				-- Focus detail; toggle single selection mark
				if private.focusKey == row._key and private.selected[d.itemString] then
					private.selected[d.itemString] = nil
				else
					wipe(private.selected)
					private.selected[d.itemString] = true
				end
			end
			private.focusKey = row._key
			private.focusDecision = d
			private.lastIndex = row._index
			CleanupTab.Render(parent)
		end,
		onRightClick = function(row, index, line)
			local d = row._decision
			if not d then
				return
			end
			private.focusKey = row._key
			private.focusDecision = d
			ItemContextMenu.Show(line, d, {
				onSelect = function(dec)
					private.focusDecision = dec
					CleanupTab.Render(parent)
				end,
			})
		end,
		onEnter = function(row, _, line)
			showItemTooltip(row._decision, line)
		end,
		onLeave = function()
			GameTooltip:Hide()
		end,
	})

	renderDetail(stack, private.focusDecision)

	Layout.AddGap(stack, 6)
	Layout.AddButtonRow(stack, {
		{
			text = "Alle wählen",
			onClick = function()
				for _, d in ipairs(aggregated) do
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
				private.focusDecision = nil
				private.focusKey = nil
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
			text = role == C.ROLES.BANK and "Posten-Tab" or "Mail-Plan",
			onClick = function()
				local MainFrame = Smart:GetModule("MainFrame")
				if MainFrame then
					MainFrame.SelectTab(role == C.ROLES.BANK and "Posting" or "Mail")
				end
			end,
		},
	})
	Layout.AddText(
		stack,
		"Linksklick = auswählen/Details · Rechtsklick = Menü · Strg/Shift = Mehrfachauswahl. Kein Verkauf ohne Bestätigung.",
		"GameFontHighlightSmall",
		Theme.COLORS.muted
	)
	Layout.FinishStack(stack)
	Layout.FooterText(
		root.footer,
		string.format("Filter=%s | %d ausgewählt / %d Positionen (aggregiert)", private.filter, selectedCount(), #aggregated)
	)
end
