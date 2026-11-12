local Smart = WoWSmartTSM
local Locale = Smart:Module("Locale")
local Layout = Smart:Module("Layout")
local Theme = Smart:Module("Theme")
local Operations = Smart:Module("Operations")
local OperationsTab = Smart:Module("OperationsTab")

local private = {
	section = "Auctioning", -- Auctioning / Mailing / Vendoring / Suggestions
	focusId = nil,
}

local function groupsFormat(path)
	local Groups = Smart:GetModule("Groups")
	if Groups and Groups.FormatPath then
		return Groups.FormatPath(path)
	end
	return tostring(path or "—")
end

local function fieldLine(label, value, validation)
	local v = value
	if v == nil or v == "" then
		v = Operations.UnknownLabel()
	end
	local suffix = ""
	if validation then
		if validation.ok == true then
			suffix = " ✓"
		elseif validation.ok == false then
			suffix = " ✗ (" .. tostring(validation.why) .. ")"
		elseif validation.ok == nil then
			suffix = " (? " .. tostring(validation.why) .. ")"
		end
	end
	return label .. ": " .. tostring(v) .. suffix
end

function OperationsTab.Render(parent)
	local L = Locale.T
	local catalog = Operations.BuildCatalog()
	local cap = catalog.capabilities or Operations.ProbeCapabilities()

	local root = Layout.Begin(parent)
	Layout.HeaderTitle(root.header, L("OPERATIONS_TAB"), 12)
	local stack = Layout.BodyStack(root)

	Layout.AddText(
		stack,
		string.format(
			"TSM-Ops | Live=%s | Write=%s | Claim=%s",
			tostring(catalog.liveAvailable),
			tostring(cap.writeMode),
			tostring(cap.claim)
		),
		"GameFontHighlightSmall",
		Theme.COLORS.muted
	)
	for _, w in ipairs(catalog.warnings or {}) do
		Layout.AddText(stack, w, "GameFontHighlightSmall", Theme.COLORS.warn)
	end

	Layout.AddButtonRow(stack, {
		{
			text = "Auctioning",
			onClick = function()
				private.section = "Auctioning"
				OperationsTab.Render(parent)
			end,
		},
		{
			text = "Mailing",
			onClick = function()
				private.section = "Mailing"
				OperationsTab.Render(parent)
			end,
		},
		{
			text = "Vendoring",
			onClick = function()
				private.section = "Vendoring"
				OperationsTab.Render(parent)
			end,
		},
		{
			text = "Vorschläge",
			onClick = function()
				private.section = "Suggestions"
				OperationsTab.Render(parent)
			end,
		},
	})
	Layout.AddGap(stack, 6)

	if private.section == "Suggestions" then
		Layout.AddText(stack, "Bearbeitbare Smart-Operationsprofile (nicht blind auf alle Items):", "GameFontNormal")
		for _, sug in ipairs(catalog.suggestions or {}) do
			Layout.AddGap(stack, 4)
			Layout.AddText(
				stack,
				string.format("[%s] %s → %s", tostring(sug.type), tostring(sug.name), groupsFormat(sug.group)),
				"GameFontHighlight",
				Theme.COLORS.text
			)
			if sug.type == "Auctioning" then
				local val = sug.validation or {}
				Layout.AddText(stack, fieldLine("Min Price", sug.minPrice, val.minPrice), "GameFontHighlightSmall", Theme.COLORS.muted)
				Layout.AddText(stack, fieldLine("Normal Price", sug.normalPrice, val.normalPrice), "GameFontHighlightSmall", Theme.COLORS.muted)
				Layout.AddText(stack, fieldLine("Max Price", sug.maxPrice, val.maxPrice), "GameFontHighlightSmall", Theme.COLORS.muted)
				Layout.AddText(stack, fieldLine("Post Cap", sug.postCap), "GameFontHighlightSmall", Theme.COLORS.muted)
				Layout.AddText(stack, fieldLine("Stack Size", sug.stackSize), "GameFontHighlightSmall", Theme.COLORS.muted)
				Layout.AddText(stack, fieldLine("Duration", sug.duration), "GameFontHighlightSmall", Theme.COLORS.muted)
				Layout.AddText(stack, fieldLine("Undercut", sug.undercut), "GameFontHighlightSmall", Theme.COLORS.muted)
			elseif sug.type == "Mailing" then
				Layout.AddText(stack, fieldLine("Empfänger", sug.target), "GameFontHighlightSmall", Theme.COLORS.muted)
				Layout.AddText(stack, fieldLine("Reserve", sug.keepQty), "GameFontHighlightSmall", Theme.COLORS.muted)
				if sug.blocked then
					Layout.AddText(stack, tostring(sug.mailNote), "GameFontHighlightSmall", Theme.COLORS.warn)
				end
			elseif sug.type == "Vendoring" then
				Layout.AddText(stack, fieldLine("Sell trash", sug.sellTrash), "GameFontHighlightSmall", Theme.COLORS.muted)
				Layout.AddText(stack, fieldLine("vsDestroyValue", sug.vsDestroyValue), "GameFontHighlightSmall", Theme.COLORS.muted)
			end
			if sug.note then
				Layout.AddText(stack, sug.note, "GameFontHighlightSmall", Theme.COLORS.muted)
			end
			Layout.AddButtonRow(stack, {
				{
					text = "Formel zurücksetzen",
					onClick = function()
						Operations.ResetSuggestion(sug.id)
						OperationsTab.Render(parent)
					end,
				},
			})
		end
		Layout.AddText(
			stack,
			"Formeln in SavedVariables überschreibbar via Operations.SetSuggestionField(id, field, value). Einrichtung in TSM bleibt manuell.",
			"GameFontHighlightSmall",
			Theme.COLORS.muted
		)
	else
		local bucket = private.section == "Auctioning" and catalog.auctioning
			or (private.section == "Mailing" and catalog.mailing or catalog.vendoring)
		Layout.AddText(
			stack,
			string.format("Vorhandene %s-Operationen (live): %d", private.section, #bucket),
			"GameFontNormal"
		)
		if #bucket == 0 then
			Layout.AddText(
				stack,
				"Keine Live-Liste — " .. Operations.UnknownLabel() .. ". Nutze Vorschläge + TSM Operations UI.",
				"GameFontHighlightSmall",
				Theme.COLORS.warn
			)
			-- Show expected fields as unknown template
			if private.section == "Auctioning" then
				for _, f in ipairs({ "Min Price", "Normal Price", "Max Price", "Post Cap", "Stack Size", "Duration", "Undercut" }) do
					Layout.AddText(stack, f .. ": " .. Operations.UnknownLabel(), "GameFontHighlightSmall", Theme.COLORS.muted)
				end
			elseif private.section == "Mailing" then
				for _, f in ipairs({ "Empfänger", "Zugeordnete Gruppen", "Versandregeln", "Reservierte Mengen", "Charakter-Einschränkungen" }) do
					Layout.AddText(stack, f .. ": " .. Operations.UnknownLabel(), "GameFontHighlightSmall", Theme.COLORS.muted)
				end
			else
				for _, f in ipairs({ "Verkaufsregeln", "Sicherheitsoptionen", "Zugeordnete Gruppen" }) do
					Layout.AddText(stack, f .. ": " .. Operations.UnknownLabel(), "GameFontHighlightSmall", Theme.COLORS.muted)
				end
			end
		else
			for _, op in ipairs(bucket) do
				Layout.AddText(stack, "• " .. tostring(op.name) .. " [" .. tostring(op.source) .. "]", "GameFontHighlight", Theme.COLORS.text)
				for k, v in pairs(op.fields or {}) do
					Layout.AddText(stack, "  " .. tostring(k) .. ": " .. tostring(v), "GameFontHighlightSmall", Theme.COLORS.muted)
				end
			end
		end
	end

	Layout.AddGap(stack, 8)
	Layout.AddButtonRow(stack, {
		{
			text = "In TSM einrichten",
			onClick = function()
				print("|cff4ecdc4[SmartTSM]|r " .. Operations.OpenTSMHint())
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
	Layout.AddText(stack, Operations.OpenTSMHint(), "GameFontHighlightSmall", Theme.COLORS.muted)
	Layout.FinishStack(stack)
	Layout.FooterText(root.footer, "Keine automatischen Vendor-/Mail-/AH-Aktionen")
end
