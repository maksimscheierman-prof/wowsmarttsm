local Smart = WoWSmartTSM
local Locale = Smart:Module("Locale")
local Money = Smart:Module("MoneyUtil")
local Layout = Smart:Module("Layout")
local Theme = Smart:Module("Theme")
local Groups = Smart:Module("Groups")
local History = Smart:Module("History")
local Undo = Smart:Module("Undo")
local SkipMap = Smart:Module("SkipMap")
local BulkReview = Smart:Module("BulkReview")

local private = {
	selected = {},
	search = "",
}

local function matches(d, opts, search)
	if not d then
		return false
	end
	if opts.strategy and d.strategy ~= opts.strategy then
		return false
	end
	if opts.strategies then
		local ok = false
		for _, s in ipairs(opts.strategies) do
			if d.strategy == s then
				ok = true
				break
			end
		end
		if not ok then
			return false
		end
	end
	if opts.skipOnly and not d.skip then
		return false
	end
	if search and search ~= "" then
		local name = (d.name or ""):lower()
		if not name:find(search:lower(), 1, true) then
			return false
		end
	end
	return true
end

local function selectedCount()
	local n = 0
	for _ in pairs(private.selected) do
		n = n + 1
	end
	return n
end

function BulkReview.Render(parent, opts)
	opts = opts or {}
	local L = Locale.T
	local ScanService = Smart:GetModule("ScanService")
	local results = ScanService.GetLastResults() or {}
	local shown = {}
	for _, d in ipairs(results) do
		if matches(d, opts, private.search) then
			shown[#shown + 1] = d
		end
	end
	table.sort(shown, function(a, b)
		if a.strategy == b.strategy then
			return tostring(a.name or "") < tostring(b.name or "")
		end
		return tostring(a.strategy) < tostring(b.strategy)
	end)

	local root = Layout.Begin(parent)
	Layout.HeaderTitle(root.header, opts.title or "Review")
	Layout.HeaderButton(root.header, L("SCAN"), function()
		ScanService.ReevaluateBags({ reason = "ui_button" })
		BulkReview.Render(parent, opts)
	end)

	local stack = Layout.BodyStack(root)
	Layout.AddText(
		stack,
		string.format("%d Einträge — Klick auf Zeile wählt aus; Shift+Übernehmen bestätigt", #shown),
		"GameFontHighlightSmall",
		Theme.COLORS.muted
	)
	Layout.AddGap(stack, 4)

	local columns = {
		{ title = "Sel", width = 36 },
		{ title = "Item", width = 180 },
		{ title = "Strategie", width = 110 },
		{ title = "Gruppe", width = 160 },
		{ title = "Menge", width = 50 },
		{ title = "Netto", width = 90 },
		{ title = "Grund", width = 180 },
	}
	local rows = {}
	for _, d in ipairs(shown) do
		local reason = "-"
		if d.skip and d.skip.code then
			reason = SkipMap.Describe(d.skip.code)
		elseif d.reasons and d.reasons[1] then
			reason = d.reasons[1]
		end
		local selected = private.selected[d.itemString] and "✓" or ""
		rows[#rows + 1] = {
			selected,
			{ text = d.name or d.itemString or "?", color = Theme.StrategyColor(d.strategy) },
			d.strategy or "-",
			d.targetGroup or "-",
			tostring(d.quantity or 1),
			Money.Format(d.expectedNet or 0, true),
			reason,
			_decision = d,
		}
	end

	Layout.AddTable(stack, columns, rows, {
		maxHeight = 300,
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
			BulkReview.Render(parent, opts)
		end,
		onEnter = function(row)
			local d = row._decision
			if not d then
				return
			end
			GameTooltip:SetOwner(UIParent, "ANCHOR_CURSOR")
			GameTooltip:AddLine(d.name or "?", 1, 1, 1)
			if d.skip and d.skip.formatted then
				GameTooltip:AddLine(d.skip.formatted, 0.9, 0.9, 0.7, true)
			else
				GameTooltip:AddLine(table.concat(d.reasons or {}, ", "), 0.8, 0.8, 0.8, true)
			end
			GameTooltip:AddLine("Linksklick: Auswahl umschalten", 0.6, 0.7, 0.7, true)
			GameTooltip:Show()
		end,
		onLeave = function()
			GameTooltip:Hide()
		end,
	})

	Layout.AddButtonRow(stack, {
		{
			text = "Alle wählen",
			width = 110,
			onClick = function()
				for _, d in ipairs(shown) do
					if d.itemString then
						private.selected[d.itemString] = true
					end
				end
				BulkReview.Render(parent, opts)
			end,
		},
		{
			text = "Keine",
			width = 80,
			onClick = function()
				wipe(private.selected)
				BulkReview.Render(parent, opts)
			end,
		},
		{
			text = L("APPLY") .. " (Shift)",
			width = 140,
			onClick = function()
				BulkReview.ConfirmApply(shown)
			end,
		},
		{
			text = L("UNDO"),
			width = 160,
			onClick = function()
				Undo.UndoLast()
			end,
		},
	})
	Layout.AddText(
		stack,
		"Bestätigung nur mit Shift+Übernehmen. Keine automatische Gruppenänderung ohne Bestätigung.",
		"GameFontHighlightSmall",
		Theme.COLORS.muted
	)
	Layout.FinishStack(stack)
	Layout.FooterText(root.footer, string.format("%d ausgewählt / %d sichtbar", selectedCount(), #shown))
end

function BulkReview.ConfirmApply(shown)
	local moves = {}
	for _, d in ipairs(shown or {}) do
		if private.selected[d.itemString] and d.targetGroup then
			moves[#moves + 1] = {
				itemString = d.itemString,
				fromGroup = d.currentGroup,
				toGroup = d.targetGroup,
			}
		end
	end
	if #moves == 0 then
		print("|cff4ecdc4[SmartTSM]|r Keine Auswahl.")
		return
	end
	print("|cff4ecdc4[SmartTSM]|r Vorschau Gruppenänderungen: " .. tostring(#moves))
	for i = 1, math.min(8, #moves) do
		local m = moves[i]
		print(string.format("  %s -> %s", tostring(m.itemString), tostring(m.toGroup)))
	end
	if not IsShiftKeyDown or not IsShiftKeyDown() then
		print("|cffffcc00Halte Shift und klicke erneut auf Übernehmen zum Bestätigen.|r")
		return
	end
	local ok, applied = Groups.ApplyMoves(moves)
	History.Add("GROUP_APPLY", { count = #(applied or {}), ok = ok })
	print("|cff4ecdc4[SmartTSM]|r Angewendet: " .. tostring(#(applied or {})))
	wipe(private.selected)
end

function BulkReview.GetSelected()
	return private.selected
end
