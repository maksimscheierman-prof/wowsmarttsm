local Smart = WoWSmartTSM
local Locale = Smart:Module("Locale")
local Money = Smart:Module("MoneyUtil")
local Widgets = Smart:Module("Widgets")
local Theme = Smart:Module("Theme")
local C = Smart:Module("Constants")
local Groups = Smart:Module("Groups")
local History = Smart:Module("History")
local Undo = Smart:Module("Undo")
local SkipMap = Smart:Module("SkipMap")
local BulkReview = Smart:Module("BulkReview")

local private = {
	selected = {},
	filterStrategy = nil,
	filterSkip = nil,
	search = "",
}

local function clearChildren(parent)
	local children = { parent:GetChildren() }
	for _, child in ipairs(children) do
		child:Hide()
		child:SetParent(nil)
	end
end

local function matches(d, filterStrategy, filterSkip, search)
	if not d then
		return false
	end
	if filterStrategy and d.strategy ~= filterStrategy then
		return false
	end
	if filterSkip then
		if not d.skip or d.skip.code ~= filterSkip then
			return false
		end
	end
	if search and search ~= "" then
		local name = (d.name or ""):lower()
		if not name:find(search:lower(), 1, true) then
			return false
		end
	end
	return true
end

function BulkReview.Render(parent, opts)
	opts = opts or {}
	clearChildren(parent)
	private.filterStrategy = opts.strategy
	private.filterSkip = opts.skipCode
	local L = Locale.T
	local ScanService = Smart:GetModule("ScanService")
	local results = ScanService.GetLastResults() or {}

	local title = Widgets.Label(parent, opts.title or "Review", 14)
	title:SetPoint("TOPLEFT", 16, -12)

	local searchBox = CreateFrame("EditBox", nil, parent, "InputBoxTemplate")
	searchBox:SetSize(180, 20)
	searchBox:SetPoint("TOPRIGHT", -160, -12)
	searchBox:SetAutoFocus(false)
	searchBox:SetText(private.search or "")
	searchBox:SetScript("OnTextChanged", function(self)
		private.search = self:GetText() or ""
	end)

	local refresh = Widgets.Button(parent, L("SEARCH"), 80, 22, function()
		BulkReview.Render(parent, opts)
	end)
	refresh:SetPoint("TOPRIGHT", -70, -12)

	local header = Widgets.Label(parent, "Sel | Item | Strategie | Gruppe | Menge | Netto | Grund", 11)
	header:SetPoint("TOPLEFT", 16, -40)

	local scroll = Widgets.ScrollList(parent, nil)
	scroll:SetPoint("TOPLEFT", 12, -58)
	scroll:SetPoint("BOTTOMRIGHT", -32, 48)
	local child = scroll.child
	child:SetWidth(parent:GetWidth() - 50)

	local y = 0
	local rowH = 22
	local shown = {}
	for _, d in ipairs(results) do
		if matches(d, opts.strategy, opts.skipCode, private.search) then
			local ok = true
			if opts.strategies then
				ok = false
				for _, s in ipairs(opts.strategies) do
					if d.strategy == s then
						ok = true
						break
					end
				end
			end
			if ok then
				shown[#shown + 1] = d
			end
		end
	end

	-- sort by strategy then name
	table.sort(shown, function(a, b)
		if a.strategy == b.strategy then
			return tostring(a.name or "") < tostring(b.name or "")
		end
		return tostring(a.strategy) < tostring(b.strategy)
	end)

	for i, d in ipairs(shown) do
		local row = CreateFrame("Frame", nil, child)
		row:SetSize(800, rowH)
		row:SetPoint("TOPLEFT", 0, -y)

		local cb = CreateFrame("CheckButton", nil, row, "ChatConfigCheckButtonTemplate")
		cb:SetPoint("LEFT", 0, 0)
		cb:SetChecked(private.selected[d.itemString] == true)
		cb:SetScript("OnClick", function(self)
			private.selected[d.itemString] = self:GetChecked() and true or nil
		end)

		local col = Theme.StrategyColor(d.strategy)
		local name = Widgets.Label(row, d.name or d.itemString or "?", 11)
		name:SetPoint("LEFT", 28, 0)
		name:SetWidth(200)
		name:SetJustifyH("LEFT")
		name:SetTextColor(col[1], col[2], col[3], 1)

		local strat = Widgets.Label(row, d.strategy or "-", 11)
		strat:SetPoint("LEFT", 240, 0)
		strat:SetWidth(120)

		local grp = Widgets.Label(row, d.targetGroup or "-", 10)
		grp:SetPoint("LEFT", 370, 0)
		grp:SetWidth(160)

		local qty = Widgets.Label(row, tostring(d.quantity or 1), 11)
		qty:SetPoint("LEFT", 540, 0)

		local net = Widgets.Label(row, Money.Format(d.expectedNet or 0, true), 11)
		net:SetPoint("LEFT", 580, 0)

		local reason = "-"
		if d.skip and d.skip.code then
			reason = SkipMap.Describe(d.skip.code)
		elseif d.reasons and d.reasons[1] then
			reason = d.reasons[1]
		end
		local rs = Widgets.Label(row, reason, 10)
		rs:SetPoint("LEFT", 660, 0)
		rs:SetWidth(200)

		row:SetScript("OnEnter", function()
			GameTooltip:SetOwner(row, "ANCHOR_CURSOR")
			GameTooltip:AddLine(d.name or "?", 1, 1, 1)
			if d.skip and d.skip.formatted then
				GameTooltip:AddLine(d.skip.formatted, 0.9, 0.9, 0.7, true)
			else
				GameTooltip:AddLine(table.concat(d.reasons or {}, ", "), 0.8, 0.8, 0.8, true)
			end
			GameTooltip:Show()
		end)
		row:SetScript("OnLeave", function()
			GameTooltip:Hide()
		end)

		y = y + rowH
	end
	child:SetHeight(math.max(y, 10))

	local apply = Widgets.Button(parent, L("APPLY"), 150, 24, function()
		BulkReview.ConfirmApply(shown)
	end)
	apply:SetPoint("BOTTOMLEFT", 16, 14)

	local undo = Widgets.Button(parent, L("UNDO"), 220, 24, function()
		Undo.UndoLast()
	end)
	undo:SetPoint("LEFT", apply, "RIGHT", 8, 0)

	local count = Widgets.Label(parent, string.format("%d Items", #shown), 11)
	count:SetPoint("BOTTOMRIGHT", -16, 18)
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
	-- Preview summary
	print("|cff4ecdc4[SmartTSM]|r Vorschau Gruppenänderungen: " .. tostring(#moves))
	for i = 1, math.min(8, #moves) do
		local m = moves[i]
		print(string.format("  %s -> %s", tostring(m.itemString), tostring(m.toGroup)))
	end
	if #moves > 8 then
		print("  ...")
	end
	print("|cff4ecdc4[SmartTSM]|r Bestätigen mit /smarttsm (Bulk-Apply im UI erneut mit Shift)")

	-- Require Shift for actual apply to avoid accidents
	if not IsShiftKeyDown or not IsShiftKeyDown() then
		print("|cffffcc00Halte Shift und klicke erneut auf Übernehmen zum Bestätigen.|r")
		return
	end

	local ok, applied = Groups.ApplyMoves(moves)
	History.Add("GROUP_APPLY", { count = #applied, ok = ok })
	print("|cff4ecdc4[SmartTSM]|r Angewendet: " .. tostring(#applied))
	wipe(private.selected)
end

function BulkReview.GetSelected()
	return private.selected
end
