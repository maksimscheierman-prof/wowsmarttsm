local Smart = WoWSmartTSM
local Locale = Smart:Module("Locale")
local Layout = Smart:Module("Layout")
local Theme = Smart:Module("Theme")
local Groups = Smart:Module("Groups")
local GroupManager = Smart:Module("GroupManager")
local Operations = Smart:Module("Operations")
local Undo = Smart:Module("Undo")
local GroupsTab = Smart:Module("GroupsTab")

local private = {
	filter = "ALL", -- ALL / SAFE / REVIEW / PROTECTED
	lastImport = nil,
	focus = nil,
}

local function statusColor(status)
	if status == GroupManager.STATUS.SAFE then
		return Theme.COLORS.good
	end
	if status == GroupManager.STATUS.REVIEW then
		return Theme.COLORS.warn
	end
	if status == GroupManager.STATUS.PROTECTED then
		return Theme.COLORS.muted
	end
	return Theme.COLORS.text
end

local function copyImportHint(str)
	private.lastImport = str
	if not str or str == "" then
		print("|cff4ecdc4[SmartTSM]|r Kein Import-String.")
		return
	end
	-- Forever may lack clipboard; print truncated + chat notice
	local preview = str
	if #preview > 180 then
		preview = preview:sub(1, 180) .. "…"
	end
	print("|cff4ecdc4[SmartTSM]|r TSM-Import (Gruppen):")
	print(preview)
	if ChatFrame1 and ChatFrame1.AddMessage then
		ChatFrame1:AddMessage("|cff4ecdc4[SmartTSM]|r Vollständigen String: /smarttsm importstring")
	end
	if WoWSmartTSM_DB then
		WoWSmartTSM_DB.lastGroupImportString = str
	end
end

function GroupsTab.Render(parent)
	local L = Locale.T
	local ScanService = Smart:GetModule("ScanService")
	local results = ScanService.GetLastResults() or {}
	local proposals = GroupManager.BuildProposals(results)
	local preview = GroupManager.Preview(proposals)
	local cap = preview.capabilities or Groups.ProbeCapabilities()

	local filtered = {}
	for _, p in ipairs(proposals) do
		if private.filter == "ALL" or p.status == private.filter then
			filtered[#filtered + 1] = p
		end
	end

	local root = Layout.Begin(parent)
	local _, bw = Layout.HeaderButton(root.header, L("SCAN"), function()
		ScanService.ReevaluateBags({ reason = "groups_tab_scan" })
		GroupsTab.Render(parent)
	end)
	Layout.HeaderTitle(root.header, L("GROUPS_TAB"), (bw or 160) + 12)

	local stack = Layout.BodyStack(root)
	Layout.AddText(
		stack,
		string.format(
			"Live-TSM | Write=%s | Sicher=%d | Prüfen=%d | Geschützt=%d | OK=%d",
			tostring(cap.writeMode),
			preview.safeCount or 0,
			preview.reviewCount or 0,
			preview.protectedCount or 0,
			preview.alreadyOk or 0
		),
		"GameFontHighlightSmall",
		Theme.COLORS.muted
	)

	if #(preview.missingGroups or {}) > 0 then
		Layout.AddText(
			stack,
			"Fehlende Smart-Gruppen: " .. table.concat(preview.missingGroups, ", "),
			"GameFontHighlightSmall",
			Theme.COLORS.warn
		)
		Layout.AddText(stack, Groups.OpenTSMGroupsHint(), "GameFontHighlightSmall", Theme.COLORS.muted)
	end

	Layout.AddButtonRow(stack, {
		{
			text = "Alle",
			onClick = function()
				private.filter = "ALL"
				GroupsTab.Render(parent)
			end,
		},
		{
			text = "Sicher",
			onClick = function()
				private.filter = "SAFE"
				GroupsTab.Render(parent)
			end,
		},
		{
			text = "Prüfen",
			onClick = function()
				private.filter = "REVIEW"
				GroupsTab.Render(parent)
			end,
		},
		{
			text = "Geschützt",
			onClick = function()
				private.filter = "PROTECTED"
				GroupsTab.Render(parent)
			end,
		},
	})
	Layout.AddGap(stack, 4)

	local columns = {
		{ title = "Item", width = 150 },
		{ title = "Anz", width = 36 },
		{ title = "Aktuell", width = 130 },
		{ title = "Vorschlag", width = 130 },
		{ title = "Strategie", width = 90 },
		{ title = "Operation", width = 100 },
		{ title = "Status", width = 70 },
		{ title = "Grund", width = 160 },
	}
	local rows = {}
	for _, p in ipairs(filtered) do
		rows[#rows + 1] = {
			{
				text = p.name or p.itemString or "?",
				fullText = p.name or p.itemString,
				color = Theme.StrategyColor and Theme.StrategyColor(p.strategy) or Theme.COLORS.text,
			},
			tostring(p.quantity or 1),
			GroupManager.GroupLabel(p.currentGroup),
			GroupManager.GroupLabel(p.proposedGroup),
			p.strategy or "-",
			p.operation or "-",
			{
				text = GroupManager.StatusLabel(p.status),
				color = statusColor(p.status),
			},
			p.reason or "",
			_prop = p,
		}
	end

	Layout.AddTable(stack, columns, rows, {
		maxHeight = 280,
		rowHeight = 22,
		onClick = function(row)
			private.focus = row._prop
			GroupsTab.Render(parent)
		end,
		onEnter = function(row)
			local p = row._prop
			if not p then
				return
			end
			GameTooltip:SetOwner(UIParent, "ANCHOR_CURSOR")
			GameTooltip:AddLine(p.name or "?", 1, 1, 1)
			GameTooltip:AddLine("Aktuell: " .. GroupManager.GroupLabel(p.currentGroup), 0.8, 0.8, 0.8)
			GameTooltip:AddLine("Vorschlag: " .. GroupManager.GroupLabel(p.proposedGroup), 0.7, 0.9, 0.7)
			GameTooltip:AddLine(p.reason or "", 0.85, 0.85, 0.7, true)
			GameTooltip:Show()
		end,
		onLeave = function()
			GameTooltip:Hide()
		end,
	})

	if private.focus then
		local f = private.focus
		Layout.AddGap(stack, 6)
		Layout.AddText(
			stack,
			string.format(
				"Fokus: %s → %s [%s]",
				tostring(f.name),
				GroupManager.GroupLabel(f.proposedGroup),
				GroupManager.StatusLabel(f.status)
			),
			"GameFontHighlightSmall",
			Theme.COLORS.text
		)
	end

	Layout.AddGap(stack, 6)
	Layout.AddButtonRow(stack, {
		{
			text = L("APPLY_SAFE_ALL") .. " (Shift)",
			tooltip = "Nur sichere Vorschläge — Vorschau, dann Shift+Klick bestätigen",
			maxWidth = 260,
			onClick = function()
				local stage = GroupManager.StageSafeApply(proposals)
				print(
					"|cff4ecdc4[SmartTSM]|r Vorschau sichere Gruppenänderungen: "
						.. tostring(stage.safeCount)
						.. " | Modus="
						.. tostring((stage.capabilities and stage.capabilities.writeMode) or "?")
				)
				for i = 1, math.min(6, #(stage.moves or {})) do
					local m = stage.moves[i]
					print(
						string.format(
							"  %s: %s → %s",
							tostring(m.name or m.itemString),
							tostring(m.fromGroup or "—"),
							tostring(m.toGroup)
						)
					)
				end
				if not IsShiftKeyDown or not IsShiftKeyDown() then
					print("|cffffcc00Halte Shift und klicke erneut zum Bestätigen.|r")
					return
				end
				local ok, applied, meta = GroupManager.ConfirmSafeApply(true)
				if meta and meta.error == "MANUAL_ROLE" then
					print("|cffffcc00MANUAL-Rolle: keine automatische Übernahme.|r")
					return
				end
				if meta and meta.mode == "IMPORT_STRING" then
					copyImportHint(meta.importString)
					print(
						"|cff4ecdc4[SmartTSM]|r Import-String bereit ("
							.. tostring(#(applied or {}))
							.. "). TSM → Groups → Import. Danach „Verifizieren“."
					)
				else
					print(
						"|cff4ecdc4[SmartTSM]|r Angewendet: "
							.. tostring(#(applied or {}))
							.. " ok="
							.. tostring(ok)
					)
					if meta and meta.verifyFailed and #meta.verifyFailed > 0 then
						print("|cffff6666Fehlgeschlagen: " .. tostring(#meta.verifyFailed) .. "|r")
					end
				end
				GroupsTab.Render(parent)
			end,
		},
		{
			text = "Import kopieren",
			tooltip = "Letzten / aktuellen Import-String in SavedVariables + Chat",
			onClick = function()
				local prev = GroupManager.GetLastPreview() or preview
				copyImportHint(prev.importString or Groups.GetLastImportString())
			end,
		},
		{
			text = "Verifizieren",
			tooltip = "Live aus TSM zurücklesen",
			onClick = function()
				local moves = (GroupManager.GetLastPreview() or {}).moves or {}
				local okList, bad = Groups.VerifyMoves(moves)
				print(
					"|cff4ecdc4[SmartTSM]|r Verify: OK="
						.. tostring(#okList)
						.. " fehlend="
						.. tostring(#bad)
				)
				for i = 1, math.min(5, #bad) do
					local b = bad[i]
					print(
						string.format(
							"  %s erwartet=%s ist=%s",
							tostring(b.itemString),
							tostring(b.expected),
							tostring(b.actual)
						)
					)
				end
				GroupsTab.Render(parent)
			end,
		},
		{
			text = L("UNDO"),
			onClick = function()
				Undo.UndoLast()
				GroupsTab.Render(parent)
			end,
		},
		{
			text = L("SETUP_WIZARD"),
			onClick = function()
				local MainFrame = Smart:GetModule("MainFrame")
				if MainFrame and MainFrame.SelectTab then
					MainFrame.SelectTab("Setup")
				end
			end,
		},
	})

	Layout.AddText(
		stack,
		"Bestehende manuelle TSM-Gruppen werden nicht überschrieben (Status Prüfen). "
			.. Operations.OpenTSMHint(),
		"GameFontHighlightSmall",
		Theme.COLORS.muted
	)
	Layout.FinishStack(stack)
	Layout.FooterText(
		root.footer,
		string.format("%d Zeilen | Filter=%s | %s", #filtered, private.filter, L("SELL_FIRST"))
	)
end
