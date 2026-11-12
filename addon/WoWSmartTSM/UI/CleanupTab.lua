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
local Groups = Smart:Module("Groups")
local GroupManager = Smart:Module("GroupManager")
local Undo = Smart:Module("Undo")
local CleanupTab = Smart:Module("CleanupTab")

local private = {
	selected = {}, -- [itemString] = true
	focusKey = nil, -- aggregate key / itemString for detail
	focusDecision = nil,
	filter = "ALL",
	lastIndex = nil,
	pickerOpen = false,
	pickerSearch = "",
	assignPermanent = true, -- dauerhaft vs einmalig
	proposalByItem = {},
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

	local root = Layout.Begin(parent, { compact = true, headerHeight = 28, footerHeight = 28 })
	local _, bw = Layout.HeaderButton(root.header, L("SCAN"), function()
		ScanService.ReevaluateBags({ reason = "cleanup_ui" })
		CleanupTab.Render(parent)
	end)
	local title = (role == C.ROLES.BANK) and "Bank-Aufräumen" or L("CLEANUP")
	Layout.HeaderTitle(
		root.header,
		string.format(
			"%s · %s · %s",
			title,
			tostring(role),
			tostring(snap.currentKey or (CP.GetCurrentKey and CP.GetCurrentKey()) or "")
		),
		(bw or 140) + 8
	)

	local stack = Layout.BodyStack(root) -- scroll OK for large item lists

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

	local proposals = GroupManager.BuildProposals(results)
	wipe(private.proposalByItem)
	for _, p in ipairs(proposals) do
		if p.itemString then
			private.proposalByItem[p.itemString] = p
		end
	end
	local preview = GroupManager.Preview(proposals)

	local columns = {
		{ title = "Sel", width = 28 },
		{ title = "Item", width = 130 },
		{ title = "Menge", width = 44 },
		{ title = "TSM-Gruppe", width = 120 },
		{ title = "Vorschlag", width = 120 },
		{ title = "Status", width = 64 },
		{ title = "Aktion", width = 90 },
		{ title = "Begründung", width = 140 },
	}
	local rows = {}
	for idx, d in ipairs(aggregated) do
		local name = d.name or d.itemString or "?"
		local qty = d.actionQty or d.quantity or 1
		local human = ItemExplain.HumanReason(d)
		local key = rowKey(d)
		local prop = private.proposalByItem[d.itemString]
		local currentG = prop and prop.currentGroup or Groups.GetPathByItem(d.itemString)
		local proposedG = prop and prop.proposedGroup
		local status = prop and GroupManager.StatusLabel(prop.status) or "—"
		rows[#rows + 1] = {
			private.selected[d.itemString] and "✓" or "",
			{ text = name, fullText = name, color = Theme.StrategyColor(d.strategy), tooltip = name },
			"×" .. tostring(qty),
			GroupManager.GroupLabel(currentG),
			GroupManager.GroupLabel(proposedG),
			status,
			CleanupService.ActionLabel(d.inventoryAction),
			{ text = human, fullText = human, tooltip = table.concat(d.actionReasons or {}, ", ") },
			_decision = d,
			_prop = prop,
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

	-- Group assignment panel
	Layout.AddGap(stack, 6)
	Layout.AddText(stack, "TSM-Gruppenzuordnung", "GameFontNormal")
	Layout.AddText(
		stack,
		string.format(
			"Sichere Vorschläge=%d | Prüfen=%d | Geschützt=%d | Zuordnung=%s",
			preview.safeCount or 0,
			preview.reviewCount or 0,
			preview.protectedCount or 0,
			private.assignPermanent and "dauerhaft" or "einmalig"
		),
		"GameFontHighlightSmall",
		Theme.COLORS.muted
	)
	if private.focusDecision then
		local fp = private.proposalByItem[private.focusDecision.itemString]
		Layout.AddText(
			stack,
			string.format(
				"Fokus: aktuell=%s → vorschlag=%s",
				GroupManager.GroupLabel(fp and fp.currentGroup),
				GroupManager.GroupLabel(fp and fp.proposedGroup)
			),
			"GameFontHighlightSmall",
			Theme.COLORS.text
		)
	end

	Layout.AddButtonRow(stack, {
		{
			text = private.assignPermanent and "Modus: Dauerhaft" or "Modus: Einmalig",
			tooltip = "Dauerhaft speichert die Wahl; Einmalig nur für diesen Import",
			onClick = function()
				private.assignPermanent = not private.assignPermanent
				CleanupTab.Render(parent)
			end,
		},
		{
			text = private.pickerOpen and "Gruppenliste schließen" or "Gruppe wählen…",
			tooltip = "Dropdown aller existierenden TSM-Gruppen inkl. Keine Gruppe",
			onClick = function()
				private.pickerOpen = not private.pickerOpen
				CleanupTab.Render(parent)
			end,
		},
	})

	if private.pickerOpen then
		local choices = Groups.ListChoices({ search = private.pickerSearch, includeMissingSmart = true })
		Layout.AddText(stack, "Zielgruppe für Auswahl:", "GameFontHighlightSmall", Theme.COLORS.muted)
		local pickBtns = {}
		local shown = 0
		for _, c in ipairs(choices) do
			if shown < 12 then
				local label = c.label
				if c.itemCount then
					label = label .. " (" .. tostring(c.itemCount) .. ")"
				end
				pickBtns[#pickBtns + 1] = {
					text = label,
					maxWidth = 220,
					onClick = function()
						local n = 0
						for itemString in pairs(private.selected) do
							GroupManager.SetPreferredGroup(itemString, c.path, private.assignPermanent)
							n = n + 1
						end
						if n == 0 and private.focusDecision and private.focusDecision.itemString then
							GroupManager.SetPreferredGroup(
								private.focusDecision.itemString,
								c.path,
								private.assignPermanent
							)
							n = 1
						end
						print("|cff4ecdc4[SmartTSM]|r Gruppe gesetzt:", GroupManager.GroupLabel(c.path), "×" .. tostring(n))
						private.pickerOpen = false
						ScanService.ReevaluateBags({ reason = "group_choice" })
						CleanupTab.Render(parent)
					end,
				}
				shown = shown + 1
			end
		end
		Layout.AddButtonRow(stack, pickBtns)
		if #choices > 12 then
			Layout.AddText(
				stack,
				string.format("… %d weitere Gruppen — /smarttsm groupsearch eingrenzen", #choices - 12),
				"GameFontHighlightSmall",
				Theme.COLORS.muted
			)
		end
	end

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
			text = "Sichere wählen",
			tooltip = "Nur Status Sicher (ohne bereits OK)",
			onClick = function()
				wipe(private.selected)
				for _, p in ipairs(GroupManager.FilterSafe(proposals)) do
					private.selected[p.itemString] = true
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
			text = L("APPLY_SAFE_ALL") .. " (Shift)",
			tooltip = "Sichere Gruppierung → Vorschau → Import/Direct → Verifizieren",
			maxWidth = 280,
			onClick = function()
				local stage = GroupManager.StageSafeApply(proposals)
				print("|cff4ecdc4[SmartTSM]|r Vorschau sichere Gruppen: " .. tostring(stage.safeCount))
				for i = 1, math.min(5, #(stage.moves or {})) do
					local m = stage.moves[i]
					print(string.format("  %s → %s", tostring(m.name or m.itemString), tostring(m.toGroup)))
				end
				if not IsShiftKeyDown or not IsShiftKeyDown() then
					print("|cffffcc00Shift halten und erneut bestätigen.|r")
					return
				end
				local ok, applied, meta = GroupManager.ConfirmSafeApply(true)
				if meta and meta.error == "MANUAL_ROLE" then
					print("|cffffcc00MANUAL-Rolle: keine Auto-Übernahme.|r")
					return
				end
				if meta and meta.mode == "IMPORT_STRING" then
					WoWSmartTSM_DB = WoWSmartTSM_DB or {}
					WoWSmartTSM_DB.lastGroupImportString = meta.importString
					print("|cff4ecdc4[SmartTSM]|r Import bereit. /smarttsm importstring → TSM Groups → Import → Verifizieren")
				else
					print("|cff4ecdc4[SmartTSM]|r Angewendet: " .. tostring(#(applied or {})) .. " ok=" .. tostring(ok))
				end
				local verified, failed = Groups.VerifyMoves(stage.moves or {})
				print("|cff4ecdc4[SmartTSM]|r Verify OK=" .. tostring(#verified) .. " fehlend=" .. tostring(#failed))
				ScanService.ReevaluateBags({ reason = "group_apply" })
				CleanupTab.Render(parent)
			end,
		},
		{
			text = "Auswahl zuweisen (Shift)",
			tooltip = "Ausgewählte Items → gewählte/vorgeschlagene Gruppe",
			maxWidth = 200,
			onClick = function()
				local moves = {}
				for itemString in pairs(private.selected) do
					local p = private.proposalByItem[itemString]
					local to = p and p.proposedGroup
					if to and to ~= "" then
						moves[#moves + 1] = {
							itemString = itemString,
							fromGroup = p.currentGroup,
							toGroup = to,
							name = p.name,
						}
					end
				end
				print("|cff4ecdc4[SmartTSM]|r Auswahl-Moves: " .. tostring(#moves))
				if not IsShiftKeyDown or not IsShiftKeyDown() then
					print("|cffffcc00Shift halten und erneut bestätigen.|r")
					return
				end
				local ok, applied, meta = GroupManager.ApplySelectedMoves(moves, {
					shiftHeld = true,
					permanent = private.assignPermanent,
					once = not private.assignPermanent,
				})
				if meta and meta.mode == "IMPORT_STRING" then
					WoWSmartTSM_DB = WoWSmartTSM_DB or {}
					WoWSmartTSM_DB.lastGroupImportString = meta.importString
					print("|cff4ecdc4[SmartTSM]|r Import bereit. /smarttsm importstring")
				end
				local verified, failed = Groups.VerifyMoves(moves)
				print(
					"|cff4ecdc4[SmartTSM]|r Apply ok="
						.. tostring(ok)
						.. " verifyOK="
						.. tostring(#verified)
						.. " fehlend="
						.. tostring(#failed)
				)
				ScanService.ReevaluateBags({ reason = "group_apply_selected" })
				CleanupTab.Render(parent)
			end,
		},
		{
			text = "Verifizieren",
			onClick = function()
				local moves = (GroupManager.GetLastPreview() or {}).moves or {}
				local okList, bad = Groups.VerifyMoves(moves)
				print("|cff4ecdc4[SmartTSM]|r Verify OK=" .. tostring(#okList) .. " fehlend=" .. tostring(#bad))
				CleanupTab.Render(parent)
			end,
		},
		{
			text = L("UNDO"),
			onClick = function()
				Undo.UndoLast()
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
		"Linksklick/Strg/Shift = Auswahl · Gruppe wählen · Sichere Vorschläge (Shift). Hochpreisige bleiben Prüfen. Kein Verkauf ohne Bestätigung.",
		"GameFontHighlightSmall",
		Theme.COLORS.muted
	)
	Layout.FinishStack(stack)
	Layout.FooterText(
		root.footer,
		string.format(
			"Filter=%s | %d ausgewählt / %d | Sicher=%d",
			private.filter,
			selectedCount(),
			#aggregated,
			preview.safeCount or 0
		)
	)
end
