local Smart = WoWSmartTSM
local Locale = Smart:Module("Locale")
local Layout = Smart:Module("Layout")
local Theme = Smart:Module("Theme")
local Groups = Smart:Module("Groups")
local Operations = Smart:Module("Operations")
local C = Smart:Module("Constants")
local SetupWizard = Smart:Module("SetupWizard")

--[[
  v0.2.6 compact setup — no outer scroll for the 7 short steps.
]]

local private = { step = 1 }

local STEPS = {
	"Gruppen",
	"Fehlend",
	"Ops",
	"Mailing",
	"AH Bank",
	"Lücken",
	"Verify",
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

	local root = Layout.Begin(parent, { compact = true, footerHeight = 52, headerHeight = 28 })
	Layout.HeaderTitle(
		root.header,
		string.format(
			"%s %d/%d · %s · %s · Bank=%s",
			L("SETUP_WIZARD"),
			private.step,
			#STEPS,
			STEPS[private.step] or "?",
			tostring(role),
			tostring(bank)
		),
		8
	)

	local stack = Layout.BodyStack(root, { scroll = false })

	if private.step == 1 then
		Layout.AddText(stack, string.format("%d Gruppen live · %d Smart", #paths, smartN), "GameFontHighlight", Theme.COLORS.text)
		Layout.AddText(stack, "Hierarchie: Tab Gruppen", "GameFontHighlightSmall", Theme.COLORS.muted)
	elseif private.step == 2 then
		if #missing == 0 then
			Layout.AddText(stack, "Keine fehlenden Smart-Gruppen.", "GameFontHighlight", Theme.COLORS.good)
		else
			Layout.AddText(stack, #missing .. " fehlend — Import im Gruppen-Tab", "GameFontHighlight", Theme.COLORS.warn)
			for i = 1, math.min(8, #missing) do
				Layout.AddText(stack, "· " .. Groups.FormatPath(missing[i]), "GameFontHighlightSmall", Theme.COLORS.muted)
			end
		end
	elseif private.step == 3 then
		Layout.AddText(stack, checklist[3].detail, "GameFontHighlightSmall", Theme.COLORS.text)
	elseif private.step == 4 then
		local c = checklist[4]
		Layout.AddText(stack, c.detail, "GameFontHighlightSmall", c.ok and Theme.COLORS.good or Theme.COLORS.warn)
		Layout.AddText(stack, "BANK: kein Self-Mail", "GameFontHighlightSmall", Theme.COLORS.muted)
	elseif private.step == 5 then
		Layout.AddText(stack, checklist[5].detail, "GameFontHighlightSmall", Theme.COLORS.text)
	elseif private.step == 6 then
		for _, c in ipairs(checklist) do
			Layout.AddText(
				stack,
				(c.ok and "[OK] " or "[ ] ") .. c.title,
				"GameFontHighlightSmall",
				c.ok and Theme.COLORS.good or Theme.COLORS.warn
			)
		end
	else
		Layout.AddText(
			stack,
			string.format("Verify: %d Pfade · fehlend=%d · Setup=%s", #paths, #missing, SetupWizard.IsCompleted() and "fertig" or "offen"),
			"GameFontHighlight",
			Theme.COLORS.text
		)
	end

	Layout.FinishStack(stack)
	Layout.FooterActions(root.footer, {
		{
			text = "Zurück",
			maxWidth = 70,
			onClick = function()
				private.step = math.max(1, private.step - 1)
				SetupWizard.Render(parent)
			end,
		},
		{
			text = "Weiter",
			maxWidth = 70,
			onClick = function()
				private.step = math.min(#STEPS, private.step + 1)
				SetupWizard.Render(parent)
			end,
		},
		{
			text = "Gruppen",
			maxWidth = 80,
			onClick = function()
				local MainFrame = Smart:GetModule("MainFrame")
				if MainFrame then
					MainFrame.SelectTab("Groups")
				end
			end,
		},
		{
			text = "Fertig",
			maxWidth = 70,
			onClick = function()
				SetupWizard.MarkCompleted()
				print("|cff4ecdc4[SmartTSM]|r Setup abgeschlossen.")
				SetupWizard.Render(parent)
			end,
		},
	}, "Keine Doppelverwaltung — TSM bleibt Engine")
end
