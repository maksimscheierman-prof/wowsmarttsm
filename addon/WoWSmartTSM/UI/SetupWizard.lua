local Smart = WoWSmartTSM
local Locale = Smart:Module("Locale")
local Layout = Smart:Module("Layout")
local Theme = Smart:Module("Theme")
local Groups = Smart:Module("Groups")
local Operations = Smart:Module("Operations")
local GroupManager = Smart:Module("GroupManager")
local C = Smart:Module("Constants")
local SetupWizard = Smart:Module("SetupWizard")

local private = {
	step = 1,
	appliedPreview = false,
	testItem = nil,
}

local function strategyGroup(strategy)
	return Groups.STRATEGY_TO_GROUP[strategy]
end

local STEPS = {
	"Gruppen erkennen",
	"Smart-Gruppen vorschlagen",
	"Operationen konfigurieren",
	"Mailing prüfen",
	"Vorschau",
	"Anwenden",
	"Testitem",
}

local function store()
	WoWSmartTSM_DB = WoWSmartTSM_DB or {}
	WoWSmartTSM_DB.setupWizard = WoWSmartTSM_DB.setupWizard or {
		completed = false,
		completedAt = nil,
	}
	return WoWSmartTSM_DB.setupWizard
end

function SetupWizard.IsCompleted()
	return store().completed == true
end

function SetupWizard.MarkCompleted()
	local s = store()
	s.completed = true
	s.completedAt = time()
end

function SetupWizard.Render(parent)
	local L = Locale.T
	local CP = Smart:GetModule("CharacterProfiles")
	local role = CP and CP.GetRole and CP.GetRole() or C.ROLES.MAIN
	local bank = CP and CP.GetPrimaryBankDisplay and CP.GetPrimaryBankDisplay() or "—"
	local missing = Groups.MissingSmartGroups()
	local paths = Groups.ListPaths()
	local smartCount = 0
	for _, p in ipairs(paths) do
		if Groups.IsSmartGroup(p) then
			smartCount = smartCount + 1
		end
	end
	local mailOp, mailCode, mailNote = Operations.RecommendMailingOp(role, bank ~= "—" and bank or nil)
	local checklist = Operations.SetupChecklist()
	local cap = Groups.ProbeCapabilities()

	local root = Layout.Begin(parent)
	Layout.HeaderTitle(root.header, L("SETUP_WIZARD"), 12)
	local stack = Layout.BodyStack(root)

	Layout.AddText(
		stack,
		string.format(
			"Schritt %d/%d: %s | Rolle=%s | Bank=%s | Setup=%s",
			private.step,
			#STEPS,
			STEPS[private.step] or "?",
			tostring(role),
			tostring(bank),
			SetupWizard.IsCompleted() and "fertig" or "offen"
		),
		"GameFontHighlightSmall",
		Theme.COLORS.muted
	)
	Layout.AddGap(stack, 6)

	if private.step == 1 then
		Layout.AddText(stack, "Vorhandene TSM-Gruppen (live):", "GameFontNormal")
		Layout.AddText(
			stack,
			string.format("%d Pfade gesamt, davon %d unter Smart TSM", #paths, smartCount),
			"GameFontHighlightSmall",
			Theme.COLORS.text
		)
		local shown = 0
		for _, p in ipairs(paths) do
			if Groups.IsSmartGroup(p) and shown < 12 then
				Layout.AddText(stack, "  • " .. p, "GameFontHighlightSmall", Theme.COLORS.good)
				shown = shown + 1
			end
		end
		if smartCount == 0 then
			Layout.AddText(stack, "Noch keine Smart-Gruppen in TSM.", "GameFontHighlightSmall", Theme.COLORS.warn)
		end
		Layout.AddText(stack, "API: " .. tostring(cap.claim) .. " / " .. tostring(cap.writeMode), "GameFontHighlightSmall", Theme.COLORS.muted)
	elseif private.step == 2 then
		Layout.AddText(stack, "Fehlende Smart-Gruppen:", "GameFontNormal")
		if #missing == 0 then
			Layout.AddText(stack, "Alle Smart-Gruppen vorhanden — keine Duplikate nötig.", "GameFontHighlightSmall", Theme.COLORS.good)
		else
			for _, m in ipairs(missing) do
				Layout.AddText(stack, "  + " .. m, "GameFontHighlightSmall", Theme.COLORS.warn)
			end
			Layout.AddText(
				stack,
				"Werden im Import-String als leere group:-Einträge vorbereitet (kein interner Schreibzugriff).",
				"GameFontHighlightSmall",
				Theme.COLORS.muted
			)
		end
	elseif private.step == 3 then
		Layout.AddText(stack, "Operationen (manuell in TSM):", "GameFontNormal")
		for _, c in ipairs(checklist) do
			if c.id == "ops_auctioning" or c.id == "ops_vendor" or c.id == "ops_inheritance" then
				Layout.AddText(stack, "• " .. c.title, "GameFontHighlight", Theme.COLORS.text)
				Layout.AddText(stack, "  " .. c.detail, "GameFontHighlightSmall", Theme.COLORS.muted)
			end
		end
		Layout.AddText(stack, Operations.OpenTSMHint(), "GameFontHighlightSmall", Theme.COLORS.warn)
	elseif private.step == 4 then
		Layout.AddText(stack, "Mailing MAIN → Banko:", "GameFontNormal")
		if mailOp then
			Layout.AddText(
				stack,
				"Empfohlen: Op „" .. mailOp .. "“ — " .. tostring(mailNote),
				"GameFontHighlightSmall",
				Theme.COLORS.good
			)
		else
			Layout.AddText(
				stack,
				"Keine Mailing-Op: " .. tostring(mailNote) .. " [" .. tostring(mailCode) .. "]",
				"GameFontHighlightSmall",
				Theme.COLORS.warn
			)
		end
		Layout.AddText(
			stack,
			"BANK sendet niemals an sich selbst. Verkaufsgruppen auf BANK: nur Auctioning, kein Mailing.",
			"GameFontHighlightSmall",
			Theme.COLORS.muted
		)
	elseif private.step == 5 then
		local ScanService = Smart:GetModule("ScanService")
		local results = ScanService.GetLastResults() or {}
		local proposals = GroupManager.BuildProposals(results)
		local preview = GroupManager.Preview(proposals)
		Layout.AddText(stack, "Konfigurations-Vorschau:", "GameFontNormal")
		Layout.AddText(
			stack,
			string.format(
				"Sichere Moves=%d | Prüfen=%d | Geschützt=%d | Fehlende Gruppen=%d",
				preview.safeCount,
				preview.reviewCount,
				preview.protectedCount,
				#(preview.missingGroups or {})
			),
			"GameFontHighlightSmall",
			Theme.COLORS.text
		)
		Layout.AddText(
			stack,
			"Nach Bestätigung: Import-String oder Direct-API (falls erkannt). Kein stilles Vendorn/Mailn/Posten.",
			"GameFontHighlightSmall",
			Theme.COLORS.muted
		)
	elseif private.step == 6 then
		Layout.AddText(stack, "Anwenden (nur nach Shift-Bestätigung):", "GameFontNormal")
		Layout.AddButtonRow(stack, {
			{
				text = "Smart-Gruppen Import vorbereiten (Shift)",
				maxWidth = 320,
				onClick = function()
					local moves = {}
					-- empty-group bootstrap
					local ok, applied, meta = Groups.ApplyMoves(moves, { includeEmptyGroups = true })
					private.appliedPreview = true
					if meta and meta.importString then
						WoWSmartTSM_DB.lastGroupImportString = meta.importString
						print("|cff4ecdc4[SmartTSM]|r Setup-Import (Gruppenstruktur):")
						local s = meta.importString
						print((#s > 200) and (s:sub(1, 200) .. "…") or s)
					end
					if not IsShiftKeyDown or not IsShiftKeyDown() then
						print("|cffffcc00Shift halten und erneut klicken, um als bestätigt zu markieren.|r")
						return
					end
					print("|cff4ecdc4[SmartTSM]|r In TSM Groups → Import einfügen, dann Weiter.")
					SetupWizard.Render(parent)
				end,
			},
		})
		if private.appliedPreview then
			Layout.AddText(stack, "Import vorbereitet — manuell in TSM einfügen.", "GameFontHighlightSmall", Theme.COLORS.good)
		end
		Layout.AddText(stack, Groups.OpenTSMGroupsHint(), "GameFontHighlightSmall", Theme.COLORS.muted)
	elseif private.step == 7 then
		Layout.AddText(stack, "Testitem durch den Workflow:", "GameFontNormal")
		local ScanService = Smart:GetModule("ScanService")
		local results = ScanService.GetLastResults() or {}
		local sample = results[1]
		if sample then
			private.testItem = sample
			local live = Groups.GetPathByItem(sample.itemString)
			Layout.AddText(stack, "Item: " .. tostring(sample.name), "GameFontHighlight", Theme.COLORS.text)
			Layout.AddText(stack, "Strategie: " .. tostring(sample.strategy), "GameFontHighlightSmall", Theme.COLORS.muted)
			Layout.AddText(stack, "Aktion: " .. tostring(sample.inventoryAction), "GameFontHighlightSmall", Theme.COLORS.muted)
			Layout.AddText(
				stack,
				"TSM-Gruppe (live): " .. GroupManager.GroupLabel(live),
				"GameFontHighlightSmall",
				Theme.COLORS.text
			)
			Layout.AddText(
				stack,
				"Zielgruppe: " .. GroupManager.GroupLabel(strategyGroup(sample.strategy)),
				"GameFontHighlightSmall",
				Theme.COLORS.text
			)
			Layout.AddText(
				stack,
				"Nächster manueller Schritt: TSM Groups prüfen → ggf. Auctioning/Mailing-Op zuweisen → am BANK posten / am MAIN mailen (nur mit Bestätigung).",
				"GameFontHighlightSmall",
				Theme.COLORS.muted
			)
		else
			Layout.AddText(
				stack,
				"Keine Scan-Ergebnisse — zuerst „Neu bewerten“ im TSM-Gruppen-Tab.",
				"GameFontHighlightSmall",
				Theme.COLORS.warn
			)
		end
		Layout.AddButtonRow(stack, {
			{
				text = "Setup abschließen",
				onClick = function()
					SetupWizard.MarkCompleted()
					print("|cff4ecdc4[SmartTSM]|r Setup-Assistent abgeschlossen.")
					SetupWizard.Render(parent)
				end,
			},
		})
	end

	Layout.AddGap(stack, 10)
	Layout.AddButtonRow(stack, {
		{
			text = "Zurück",
			onClick = function()
				private.step = math.max(1, private.step - 1)
				SetupWizard.Render(parent)
			end,
		},
		{
			text = "Weiter",
			onClick = function()
				private.step = math.min(#STEPS, private.step + 1)
				SetupWizard.Render(parent)
			end,
		},
		{
			text = L("GROUPS_TAB"),
			onClick = function()
				local MainFrame = Smart:GetModule("MainFrame")
				if MainFrame then
					MainFrame.SelectTab("Groups")
				end
			end,
		},
	})

	Layout.AddText(
		stack,
		"Manuell bleibt: TSM Operations anlegen/zuweisen, Import einfügen, AH/Mail/Vendor nur über TSM mit Bestätigung.",
		"GameFontHighlightSmall",
		Theme.COLORS.muted
	)
	Layout.FinishStack(stack)
	Layout.FooterText(root.footer, "Einmaliger Assistent — TSM bleibt Posting-/Mail-/Vendor-Engine")
end
