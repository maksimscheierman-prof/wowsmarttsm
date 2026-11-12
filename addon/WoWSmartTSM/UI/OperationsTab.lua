local Smart = WoWSmartTSM
local Locale = Smart:Module("Locale")
local Layout = Smart:Module("Layout")
local Theme = Smart:Module("Theme")
local Operations = Smart:Module("Operations")
local OperationsTab = Smart:Module("OperationsTab")

--[[
  v0.2.6: Compact ops view — status line + section buttons + detail pane.
]]

local private = {
	section = "Suggestions",
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
			suffix = " ✗"
		end
	end
	return label .. "=" .. tostring(v) .. suffix
end

function OperationsTab.Render(parent)
	local L = Locale.T
	local catalog = Operations.BuildCatalog()
	local cap = catalog.capabilities or Operations.ProbeCapabilities()

	local root = Layout.Begin(parent, { compact = true, footerHeight = 48, headerHeight = 28 })
	Layout.HeaderTitle(
		root.header,
		string.format(
			"%s · Live=%s · %s",
			L("OPERATIONS_TAB"),
			tostring(catalog.liveAvailable),
			tostring(cap.writeMode)
		),
		8
	)

	local stack = Layout.BodyStack(root, { scroll = false })
	Layout.AddButtonRow(stack, {
		{ text = "AH", maxWidth = 56, onClick = function()
			private.section = "Auctioning"
			OperationsTab.Render(parent)
		end },
		{ text = "Mail", maxWidth = 56, onClick = function()
			private.section = "Mailing"
			OperationsTab.Render(parent)
		end },
		{ text = "Vendor", maxWidth = 64, onClick = function()
			private.section = "Vendoring"
			OperationsTab.Render(parent)
		end },
		{ text = "Vorschläge", maxWidth = 90, onClick = function()
			private.section = "Suggestions"
			OperationsTab.Render(parent)
		end },
		{ text = "In TSM", maxWidth = 70, onClick = function()
			print("|cff4ecdc4[SmartTSM]|r " .. Operations.OpenTSMHint())
		end },
	})

	if private.section == "Suggestions" then
		for _, sug in ipairs(catalog.suggestions or {}) do
			Layout.AddText(
				stack,
				string.format("%s · %s → %s", sug.type, sug.name, groupsFormat(sug.group)),
				"GameFontHighlightSmall",
				Theme.COLORS.text
			)
			if sug.type == "Auctioning" then
				local val = sug.validation or {}
				Layout.AddText(
					stack,
					table.concat({
						fieldLine("min", sug.minPrice, val.minPrice),
						fieldLine("norm", sug.normalPrice, val.normalPrice),
						fieldLine("max", sug.maxPrice, val.maxPrice),
						fieldLine("cap", sug.postCap),
						fieldLine("stack", sug.stackSize),
						fieldLine("dur", sug.duration),
						fieldLine("uc", sug.undercut),
					}, " · "),
					"GameFontHighlightSmall",
					Theme.COLORS.muted
				)
			elseif sug.type == "Mailing" then
				Layout.AddText(
					stack,
					fieldLine("Ziel", sug.target) .. (sug.blocked and (" · " .. tostring(sug.mailNote)) or ""),
					"GameFontHighlightSmall",
					sug.blocked and Theme.COLORS.warn or Theme.COLORS.muted
				)
			else
				Layout.AddText(
					stack,
					fieldLine("trash", sug.sellTrash) .. " · " .. fieldLine("destroy", sug.vsDestroyValue),
					"GameFontHighlightSmall",
					Theme.COLORS.muted
				)
			end
		end
	else
		local bucket = private.section == "Auctioning" and catalog.auctioning
			or (private.section == "Mailing" and catalog.mailing or catalog.vendoring)
		Layout.AddText(
			stack,
			string.format("%s live: %d — fehlende Felder = %s", private.section, #bucket, Operations.UnknownLabel()),
			"GameFontHighlightSmall",
			Theme.COLORS.warn
		)
		if #bucket == 0 then
			local fields = private.section == "Auctioning"
					and { "Min", "Normal", "Max", "PostCap", "Stack", "Duration", "Undercut" }
				or (private.section == "Mailing" and { "Empfänger", "Gruppen", "Regeln", "Reserve" } or { "Regeln", "Sicherheit", "Gruppen" })
			Layout.AddText(stack, table.concat(fields, " / ") .. " = " .. Operations.UnknownLabel(), "GameFontHighlightSmall", Theme.COLORS.muted)
		else
			for i = 1, math.min(8, #bucket) do
				local op = bucket[i]
				Layout.AddText(stack, "• " .. tostring(op.name), "GameFontHighlightSmall", Theme.COLORS.text)
			end
		end
	end

	Layout.FinishStack(stack)
	Layout.FooterActions(root.footer, {
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
			text = "Setup",
			maxWidth = 70,
			onClick = function()
				local MainFrame = Smart:GetModule("MainFrame")
				if MainFrame then
					MainFrame.SelectTab("Setup")
				end
			end,
		},
	}, "Keine Auto-Vendor/Mail/AH · Formeln in Vorschläge editierbar (SV)")
end
