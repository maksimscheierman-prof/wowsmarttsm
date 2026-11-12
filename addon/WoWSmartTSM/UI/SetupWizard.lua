local Smart = WoWSmartTSM
local Locale = Smart:Module("Locale")
local Layout = Smart:Module("Layout")
local Theme = Smart:Module("Theme")
local Groups = Smart:Module("Groups")
local Operations = Smart:Module("Operations")
local C = Smart:Module("Constants")
local SetupWizard = Smart:Module("SetupWizard")

--[[
  v0.2.5 simplified setup — no duplicate group/ops management.
  1 detect groups → 2 missing → 3 ops assign → 4 mailing → 5 auctioning bank → 6 gaps → 7 re-verify
]]

local private = {
	step = 1,
}

local STEPS = {
	"Existierende Gruppen",
	"Fehlende Gruppen",
	"Operationszuordnung",
	"Mailing Azamat → Banko",
	"Auctioning auf Banko",
	"Offene Schritte",
	"Erneut verifizieren",
}

local function store()
	WoWSmartTSM_DB = WoWSmartTSM_DB or {}
	WoWSmartTSM_DB.setupWizard = WoWSmartTSM_DB.setupWizard or { completed = false }
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
	local checklist = Operations.SetupChecklist()
	local paths = Groups.ListPaths()
	local missing = Groups.MissingSmartGroups()
	local smartN = 0
	for _, p in ipairs(paths) do
		if Groups.IsSmartGroup(p) then
			smartN = smartN + 1
		end
	end

	local root = Layout.Begin(parent)
	Layout.HeaderTitle(root.header, L("SETUP_WIZARD"), 12)
	local stack = Layout.BodyStack(root)

	Layout.AddText(
		stack,
		string.format(
			"Schritt %d/%d: %s | Rolle=%s | Bank=%s",
			private.step,
			#STEPS,
			STEPS[private.step] or "?",
			tostring(role),
			tostring(bank)
		),
		"GameFontHighlightSmall",
		Theme.COLORS.muted
	)
	Layout.AddGap(stack, 6)

	if private.step == 1 then
		Layout.AddText(stack, string.format("%d TSM-Gruppen live, davon %d Smart.", #paths, smartN), "GameFontNormal")
		Layout.AddText(stack, "Vollständige Hierarchie: Tab TSM-Gruppen.", "GameFontHighlightSmall", Theme.COLORS.muted)
	elseif private.step == 2 then
		if #missing == 0 then
			Layout.AddText(stack, "Keine fehlenden Smart-Gruppen — keine Duplikate nötig.", "GameFontHighlight", Theme.COLORS.good)
		else
			for _, m in ipairs(missing) do
				Layout.AddText(stack, "+ " .. Groups.FormatPath(m), "GameFontHighlightSmall", Theme.COLORS.warn)
			end
			Layout.AddButtonRow(stack, {
				{
					text = "Import vorbereiten (Shift)",
					onClick = function()
						local _, _, meta = Groups.ApplyMoves({}, { includeEmptyGroups = true })
						if meta and meta.importString then
							WoWSmartTSM_DB.lastGroupImportString = meta.importString
						end
						if not IsShiftKeyDown or not IsShiftKeyDown() then
							print("|cffffcc00Shift + erneut klicken.|r")
							return
						end
						print("|cff4ecdc4[SmartTSM]|r /smarttsm importstring → TSM Groups Import")
					end,
				},
			})
		end
	elseif private.step == 3 then
		Layout.AddText(stack, checklist[3].detail, "GameFontHighlightSmall", Theme.COLORS.text)
		Layout.AddText(stack, Operations.OpenTSMHint(), "GameFontHighlightSmall", Theme.COLORS.warn)
		Layout.AddButtonRow(stack, {
			{
				text = L("OPERATIONS_TAB"),
				onClick = function()
					local MainFrame = Smart:GetModule("MainFrame")
					if MainFrame then
						MainFrame.SelectTab("Operations")
					end
				end,
			},
		})
	elseif private.step == 4 then
		local c = checklist[4]
		Layout.AddText(stack, c.detail, "GameFontHighlightSmall", c.ok and Theme.COLORS.good or Theme.COLORS.warn)
		Layout.AddText(stack, "BANK sendet niemals an sich selbst.", "GameFontHighlightSmall", Theme.COLORS.muted)
	elseif private.step == 5 then
		Layout.AddText(stack, checklist[5].detail, "GameFontHighlightSmall", Theme.COLORS.text)
		Layout.AddText(
			stack,
			"Auf Banko: Smart Quick/Profit/Rare mit Auctioning — ohne Mailing-Op.",
			"GameFontHighlightSmall",
			Theme.COLORS.muted
		)
	elseif private.step == 6 then
		Layout.AddText(stack, "Offene / manuelle Schritte:", "GameFontNormal")
		for _, c in ipairs(checklist) do
			local mark = c.ok and "[OK]" or (c.manual and "[MANUELL]" or "[ ]")
			Layout.AddText(
				stack,
				mark .. " " .. c.title .. " — " .. c.detail,
				"GameFontHighlightSmall",
				c.ok and Theme.COLORS.good or Theme.COLORS.warn
			)
		end
	elseif private.step == 7 then
		local hierarchy = Groups.BuildHierarchy({})
		Layout.AddText(
			stack,
			string.format("Re-Verify: %d Gruppenpfade | fehlende Smart=%d", #hierarchy, #missing),
			"GameFontNormal"
		)
		Layout.AddButtonRow(stack, {
			{
				text = "Gruppen aktualisieren",
				onClick = function()
					SetupWizard.Render(parent)
				end,
			},
			{
				text = "Setup abschließen",
				onClick = function()
					SetupWizard.MarkCompleted()
					print("|cff4ecdc4[SmartTSM]|r Setup abgeschlossen.")
					SetupWizard.Render(parent)
				end,
			},
		})
		if SetupWizard.IsCompleted() then
			Layout.AddText(stack, "Setup markiert als fertig.", "GameFontHighlightSmall", Theme.COLORS.good)
		end
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
		{
			text = L("CLEANUP"),
			onClick = function()
				local MainFrame = Smart:GetModule("MainFrame")
				if MainFrame then
					MainFrame.SelectTab("Cleanup")
				end
			end,
		},
	})
	Layout.AddText(
		stack,
		"Keine doppelte Gruppen-/Ops-Verwaltung — TSM bleibt die Engine.",
		"GameFontHighlightSmall",
		Theme.COLORS.muted
	)
	Layout.FinishStack(stack)
	Layout.FooterText(root.footer, SetupWizard.IsCompleted() and "Setup fertig" or "Setup offen")
end
