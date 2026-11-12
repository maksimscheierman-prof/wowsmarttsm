local Smart = WoWSmartTSM
local Locale = Smart:Module("Locale")
local Layout = Smart:Module("Layout")
local Theme = Smart:Module("Theme")
local Groups = Smart:Module("Groups")
local Operations = Smart:Module("Operations")
local GroupsTab = Smart:Module("GroupsTab")

--[[
  v0.2.5: Group hierarchy manager — NOT an inventory item list.
  Item assignment lives in Cleanup.
]]

local private = {
	search = "",
	focus = nil,
	filter = "ALL", -- ALL / SMART / OTHER / MISSING
}

function GroupsTab.Render(parent)
	local L = Locale.T
	local cap = Groups.ProbeCapabilities()
	local missing = Groups.MissingSmartGroups()
	local hierarchy = Groups.BuildHierarchy({ search = private.search })
	local filtered = {}
	for _, row in ipairs(hierarchy) do
		if private.filter == "ALL" then
			filtered[#filtered + 1] = row
		elseif private.filter == "SMART" and row.isSmart then
			filtered[#filtered + 1] = row
		elseif private.filter == "OTHER" and not row.isSmart then
			filtered[#filtered + 1] = row
		end
	end

	local root = Layout.Begin(parent)
	local _, bw = Layout.HeaderButton(root.header, "Aktualisieren", function()
		GroupsTab.Render(parent)
	end)
	Layout.HeaderTitle(root.header, L("GROUPS_TAB"), (bw or 140) + 12)

	local stack = Layout.BodyStack(root)
	Layout.AddText(
		stack,
		string.format(
			"Live-TSM-Gruppen | %d Pfade | Write=%s | Fehlende Smart=%d",
			#hierarchy,
			tostring(cap.writeMode),
			#missing
		),
		"GameFontHighlightSmall",
		Theme.COLORS.muted
	)
	Layout.AddText(
		stack,
		"Itemzuordnung: Tab Aufräumen. Operationen: Tab TSM-Operationen.",
		"GameFontHighlightSmall",
		Theme.COLORS.muted
	)

	Layout.AddButtonRow(stack, {
		{
			text = "Alle",
			onClick = function()
				private.filter = "ALL"
				GroupsTab.Render(parent)
			end,
		},
		{
			text = "Smart",
			onClick = function()
				private.filter = "SMART"
				GroupsTab.Render(parent)
			end,
		},
		{
			text = "Andere",
			onClick = function()
				private.filter = "OTHER"
				GroupsTab.Render(parent)
			end,
		},
		{
			text = private.search ~= "" and ("Suche: " .. private.search) or "Suche leeren",
			tooltip = "Suche zurücksetzen. Chat: /smarttsm groupsearch <text>",
			onClick = function()
				private.search = ""
				GroupsTab.Render(parent)
			end,
		},
	})

	if #missing > 0 then
		Layout.AddGap(stack, 4)
		Layout.AddText(stack, "Fehlende Smart-Gruppen (keine Duplikate anlegen):", "GameFontNormal", Theme.COLORS.warn)
		for _, m in ipairs(missing) do
			Layout.AddText(stack, "  + " .. Groups.FormatPath(m), "GameFontHighlightSmall", Theme.COLORS.warn)
		end
		Layout.AddButtonRow(stack, {
			{
				text = "Import für fehlende Gruppen (Shift)",
				maxWidth = 280,
				onClick = function()
					local ok, applied, meta = Groups.ApplyMoves({}, { includeEmptyGroups = true })
					if meta and meta.importString then
						WoWSmartTSM_DB = WoWSmartTSM_DB or {}
						WoWSmartTSM_DB.lastGroupImportString = meta.importString
						print("|cff4ecdc4[SmartTSM]|r Gruppen-Import vorbereitet. /smarttsm importstring")
					end
					if not IsShiftKeyDown or not IsShiftKeyDown() then
						print("|cffffcc00Shift halten und erneut klicken zum Bestätigen.|r")
						return
					end
					print("|cff4ecdc4[SmartTSM]|r → TSM Groups → Import. Danach Aktualisieren.")
				end,
			},
		})
	end

	Layout.AddGap(stack, 4)
	local columns = {
		{ title = "Gruppe", width = 280 },
		{ title = "Tiefe", width = 44 },
		{ title = "Items", width = 56 },
		{ title = "Typ", width = 70 },
		{ title = "Ops", width = 160 },
	}
	local rows = {}
	for _, g in ipairs(filtered) do
		local indent = string.rep("  ", math.max(0, (g.depth or 1) - 1))
		local countLabel = g.itemCountReliable and tostring(g.itemCount or 0) or "?"
		rows[#rows + 1] = {
			{
				text = indent .. (g.name or g.display or "?"),
				fullText = g.display,
				color = g.isSmart and Theme.COLORS.good or Theme.COLORS.text,
			},
			tostring(g.depth or 1),
			countLabel,
			g.isSmart and "Smart" or "Nutzer",
			Operations.UnknownLabel() .. " (TSM)",
			_group = g,
		}
	end

	Layout.AddTable(stack, columns, rows, {
		maxHeight = 300,
		rowHeight = 22,
		onClick = function(row)
			private.focus = row._group
			GroupsTab.Render(parent)
		end,
		onEnter = function(row)
			local g = row._group
			if not g then
				return
			end
			GameTooltip:SetOwner(UIParent, "ANCHOR_CURSOR")
			GameTooltip:AddLine(g.display or g.path, 1, 1, 1)
			GameTooltip:AddLine("Pfad: " .. tostring(g.path), 0.7, 0.7, 0.7, true)
			GameTooltip:AddLine("Items (direkt): " .. tostring(g.itemCount), 0.8, 0.9, 0.8)
			GameTooltip:AddLine("Auctioning/Mailing/Vendoring: " .. Operations.UnknownLabel() .. " — öffne TSM Operations", 0.85, 0.85, 0.7, true)
			GameTooltip:Show()
		end,
		onLeave = function()
			GameTooltip:Hide()
		end,
	})

	if private.focus then
		local g = private.focus
		Layout.AddGap(stack, 6)
		Layout.AddText(stack, "Auswahl: " .. tostring(g.display), "GameFontNormal")
		Layout.AddText(
			stack,
			string.format("Pfad=%s | Items=%s | Smart=%s", tostring(g.path), tostring(g.itemCount), tostring(g.isSmart)),
			"GameFontHighlightSmall",
			Theme.COLORS.muted
		)
	end

	Layout.AddButtonRow(stack, {
		{
			text = "In TSM bearbeiten",
			tooltip = "Kein öffentlicher Groups-UI-Open in TSM_API — Hinweis anzeigen",
			onClick = function()
				Groups.OpenInTSM()
			end,
		},
		{
			text = L("OPERATIONS_TAB"),
			onClick = function()
				local MainFrame = Smart:GetModule("MainFrame")
				if MainFrame then
					MainFrame.SelectTab("Operations")
				end
			end,
		},
		{
			text = L("CLEANUP"),
			onClick = function()
				local MainFrame = Smart:GetModule("MainFrame")
				if MainFrame then
					MainFrame.SelectTab("Cleanup")
				end
			end,
		},
		{
			text = L("SETUP_WIZARD"),
			onClick = function()
				local MainFrame = Smart:GetModule("MainFrame")
				if MainFrame then
					MainFrame.SelectTab("Setup")
				end
			end,
		},
	})

	Layout.AddText(
		stack,
		"Ops-Spalte: Live-Zuordnung nicht in TSM_API 4.15.6 — Werte als unbekannt, Einrichtung in TSM.",
		"GameFontHighlightSmall",
		Theme.COLORS.muted
	)
	Layout.FinishStack(stack)
	Layout.FooterText(root.footer, string.format("%d Gruppen | Filter=%s | Suche=%s", #filtered, private.filter, private.search ~= "" and private.search or "—"))
end

function GroupsTab.SetSearch(text)
	private.search = tostring(text or "")
end
