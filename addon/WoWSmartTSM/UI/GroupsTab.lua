local Smart = WoWSmartTSM
local Locale = Smart:Module("Locale")
local Layout = Smart:Module("Layout")
local Theme = Smart:Module("Theme")
local Groups = Smart:Module("Groups")
local Operations = Smart:Module("Operations")
local GroupsTab = Smart:Module("GroupsTab")

--[[
  v0.2.6: Compact two-column Groups tab — no outer scroll for typical sizes.
  Left = existing groups | Right = missing Smart groups with checkboxes.
  Footer = actions (never clipped) + status.
]]

local private = {
	search = "",
	focus = nil,
	missingSelected = nil, -- [path]=bool; nil → default all selected
}

local function smartRoot()
	local C = Smart:GetModule("Constants")
	return (C and C.SMART_ROOT) or "Smart TSM"
end

local function ensureMissingSelection(missing)
	if private.missingSelected == nil then
		private.missingSelected = {}
		for _, path in ipairs(missing) do
			private.missingSelected[path] = true
		end
	else
		-- drop stale, add new defaults selected
		local keep = {}
		for _, path in ipairs(missing) do
			if private.missingSelected[path] == nil then
				keep[path] = true
			else
				keep[path] = private.missingSelected[path] and true or false
			end
		end
		private.missingSelected = keep
	end
end

local function selectedMissing(missing)
	local out = {}
	for _, path in ipairs(missing) do
		if private.missingSelected and private.missingSelected[path] then
			out[#out + 1] = path
		end
	end
	return out
end

local function shortName(path)
	local _, leaf = Groups.SplitPath(path)
	return leaf or Groups.FormatPath(path)
end

function GroupsTab.Render(parent)
	local L = Locale.T
	local cap = Groups.ProbeCapabilities()
	local missing = Groups.MissingSmartGroups()
	ensureMissingSelection(missing)
	local hierarchy = Groups.BuildHierarchy({ search = private.search })

	local root = Layout.Begin(parent, { compact = true, footerHeight = 52, headerHeight = 28 })
	local _, bw = Layout.HeaderButton(root.header, "Aktualisieren", function()
		GroupsTab.Render(parent)
	end)
	Layout.HeaderTitle(
		root.header,
		string.format("%s  ·  %d / fehlend %d  ·  %s", L("GROUPS_TAB"), #hierarchy, #missing, tostring(cap.writeMode)),
		(bw or 120) + 8
	)

	local cols = Layout.TwoColumns(root, { leftRatio = 0.58, gap = 10 })
	local budget = cols.budget
	local listMaxH = math.max(120, budget.bodyH - 36)

	-- LEFT: existing groups
	Layout.AddText(cols.leftStack, "Existierende Gruppen", "GameFontNormal", Theme.COLORS.text)
	local leftRows = {}
	for _, g in ipairs(hierarchy) do
		local indent = string.rep("· ", math.max(0, (g.depth or 1) - 1))
		local count = g.itemCountReliable and tostring(g.itemCount or 0) or "?"
		local ops = Operations.UnknownLabel()
		leftRows[#leftRows + 1] = {
			text = string.format("%s%s  [%s]  ops:%s", indent, g.name or "?", count, ops),
			color = g.isSmart and Theme.COLORS.good or Theme.COLORS.text,
			_group = g,
			tooltip = (g.display or g.path) .. "\nItems: " .. count .. "\nOps: " .. ops .. " (TSM)",
		}
	end
	if #leftRows == 0 then
		Layout.AddText(cols.leftStack, "Keine Gruppen in TSM.", "GameFontHighlightSmall", Theme.COLORS.muted)
	else
		local list = Layout.CompactList(cols.left, leftRows, {
			rowHeight = 18,
			maxHeight = listMaxH,
			width = cols.leftW - 4,
			point = { "TOPLEFT", cols.left, "TOPLEFT", 0, -(cols.leftStack.y) },
			isSelected = function(row)
				return private.focus and row._group and private.focus.path == row._group.path
			end,
			onClick = function(row)
				private.focus = row._group
				GroupsTab.Render(parent)
			end,
			onEnter = function(row, _, line)
				GameTooltip:SetOwner(line or UIParent, "ANCHOR_CURSOR")
				GameTooltip:AddLine(row.tooltip or row.text, 1, 1, 1, true)
				GameTooltip:Show()
			end,
		})
		cols.leftStack.y = cols.leftStack.y + (list._viewH or listMaxH) + 4
	end

	if private.focus then
		local g = private.focus
		Layout.AddText(
			cols.leftStack,
			string.format("Detail: %s · Items=%s · %s", tostring(g.name), tostring(g.itemCount), g.isSmart and "Smart" or "Nutzer"),
			"GameFontHighlightSmall",
			Theme.COLORS.muted
		)
	end

	-- RIGHT: missing smart groups
	Layout.AddText(cols.rightStack, "Fehlende Smart-Gruppen", "GameFontNormal", Theme.COLORS.warn)
	if #missing == 0 then
		Layout.AddText(cols.rightStack, "Alle vorhanden — keine Duplikate.", "GameFontHighlightSmall", Theme.COLORS.good)
	else
		Layout.AddText(
			cols.rightStack,
			"Auswahl für Import (keine Doppelten):",
			"GameFontHighlightSmall",
			Theme.COLORS.muted
		)
		local missRows = {}
		for _, path in ipairs(missing) do
			local on = private.missingSelected[path]
			missRows[#missRows + 1] = {
				text = string.format("[%s] %s", on and "x" or " ", shortName(path)),
				color = on and Theme.COLORS.warn or Theme.COLORS.muted,
				_path = path,
				tooltip = Groups.FormatPath(path),
			}
		end
		local mlist = Layout.CompactList(cols.right, missRows, {
			rowHeight = 18,
			maxHeight = math.max(100, listMaxH - 48),
			width = cols.rightW - 4,
			point = { "TOPLEFT", cols.right, "TOPLEFT", 0, -(cols.rightStack.y) },
			onClick = function(row)
				local p = row._path
				private.missingSelected[p] = not private.missingSelected[p]
				GroupsTab.Render(parent)
			end,
			onEnter = function(row, _, line)
				GameTooltip:SetOwner(line or UIParent, "ANCHOR_CURSOR")
				GameTooltip:AddLine(row.tooltip or row.text, 1, 1, 1, true)
				GameTooltip:Show()
			end,
		})
		cols.rightStack.y = cols.rightStack.y + (mlist._viewH or 100) + 4

		Layout.AddButtonRow(cols.rightStack, {
			{
				text = "Alle",
				minWidth = 48,
				maxWidth = 64,
				onClick = function()
					for _, path in ipairs(missing) do
						private.missingSelected[path] = true
					end
					GroupsTab.Render(parent)
				end,
			},
			{
				text = "Keine",
				minWidth = 48,
				maxWidth = 64,
				onClick = function()
					for _, path in ipairs(missing) do
						private.missingSelected[path] = false
					end
					GroupsTab.Render(parent)
				end,
			},
			{
				text = "Import (Shift)",
				tooltip = "Nur ausgewählte fehlende Gruppen als TSM-Import vorbereiten",
				maxWidth = 120,
				onClick = function()
					local sel = selectedMissing(missing)
					if #sel == 0 then
						print("|cffffcc00[SmartTSM]|r Keine fehlende Gruppe ausgewählt.")
						return
					end
					-- Ensure root included when creating subgroups
					local paths = { smartRoot() }
					for _, p in ipairs(sel) do
						paths[#paths + 1] = p
					end
					local importStr = Groups.BuildImportString({}, { emptyGroupPaths = paths })
					WoWSmartTSM_DB = WoWSmartTSM_DB or {}
					WoWSmartTSM_DB.lastGroupImportString = importStr
					print("|cff4ecdc4[SmartTSM]|r Import für " .. tostring(#sel) .. " Gruppe(n). /smarttsm importstring")
					if not IsShiftKeyDown or not IsShiftKeyDown() then
						print("|cffffcc00Shift halten und erneut klicken zum Bestätigen.|r")
						return
					end
					print("|cff4ecdc4[SmartTSM]|r → TSM Groups → Import")
				end,
			},
		})
	end

	Layout.FooterActions(root.footer, {
		{
			text = "In TSM",
			tooltip = "TSM Groups öffnen (Hinweis — keine API)",
			maxWidth = 90,
			onClick = function()
				Groups.OpenInTSM()
			end,
		},
		{
			text = "Ops",
			tooltip = L("OPERATIONS_TAB"),
			maxWidth = 70,
			onClick = function()
				local MainFrame = Smart:GetModule("MainFrame")
				if MainFrame then
					MainFrame.SelectTab("Operations")
				end
			end,
		},
		{
			text = L("CLEANUP"),
			maxWidth = 100,
			onClick = function()
				local MainFrame = Smart:GetModule("MainFrame")
				if MainFrame then
					MainFrame.SelectTab("Cleanup")
				end
			end,
		},
		{
			text = "Setup",
			maxWidth = 70,
			onClick = function()
				local MainFrame = Smart:GetModule("MainFrame")
				if MainFrame then
					MainFrame.SelectTab("Setup")
				end
			end,
		},
	}, string.format(
		"%d Gruppen · %d fehlend · Scroll=%s · Itemzuordnung im Aufräumen",
		#hierarchy,
		#missing,
		(budget.bodyH < 180 or #hierarchy > 40) and "liste" or "nein"
	))
end

function GroupsTab.SetSearch(text)
	private.search = tostring(text or "")
end
