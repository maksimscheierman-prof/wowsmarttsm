local Smart = WoWSmartTSM
local C = Smart:Module("Constants")
local Locale = Smart:Module("Locale")
local Layout = Smart:Module("Layout")
local Theme = Smart:Module("Theme")
local Money = Smart:Module("MoneyUtil")
local VendorService = Smart:Module("VendorService")
local History = Smart:Module("History")
local VendorTab = Smart:Module("VendorTab")

local private = {
	selected = {},
}

local function selectedList(candidates)
	local out = {}
	for _, d in ipairs(candidates or {}) do
		if d.itemString and private.selected[d.itemString] then
			out[#out + 1] = d
		end
	end
	return out
end

local function selectedCount()
	local n = 0
	for _ in pairs(private.selected) do
		n = n + 1
	end
	return n
end

function VendorTab.Render(parent)
	local L = Locale.T
	local ScanService = Smart:GetModule("ScanService")
	local results = ScanService.GetLastResults() or {}
	local candidates = VendorService.BuildCandidates(results)
	local sum = ScanService.Summarize(results)
	local eval = ScanService.GetEvalStatus and ScanService.GetEvalStatus() or {}
	local dryRun = WoWSmartTSM_DB and WoWSmartTSM_DB.settings and WoWSmartTSM_DB.settings.dryRunVendor
	if dryRun == nil then
		dryRun = true
	end

	local root = Layout.Begin(parent)
	local _, bw = Layout.HeaderButton(root.header, L("SCAN"), function()
		ScanService.ReevaluateBags({ reason = "ui_button" })
		VendorTab.Render(parent)
	end)
	Layout.HeaderTitle(root.header, L("VENDOR") .. " — Dry-Run", (bw or 160) + 12)

	local stack = Layout.BodyStack(root)
	local mailN = 0
	for _, d in ipairs(ScanService.GetLastResults() or {}) do
		if d and (d.inventoryAction == C.ACTIONS.MAIL_TO_BANK or d.inventoryAction == C.ACTIONS.HOLD_AT_BANK) then
			mailN = mailN + 1
		end
	end
	Layout.AddText(
		stack,
		string.format(
			"Vendor-Kandidaten: %d  |  Dry-Run: %s  |  AH-Posten: %d  |  Mail-Kandidaten: %d  |  Status: %s",
			#candidates,
			tostring(dryRun),
			sum.toPost or 0,
			mailN,
			tostring(eval.status or "?")
		),
		"GameFontHighlightSmall",
		Theme.COLORS.muted
	)
	Layout.AddText(
		stack,
		"Vendor-Kandidaten werden nicht gleichzeitig als Mail/Hold verarbeitet (getrennte inventoryAction).",
		"GameFontHighlightSmall",
		Theme.COLORS.muted
	)

	if eval.status == "FAILED" then
		Layout.AddText(
			stack,
			"Inventarbewertung fehlgeschlagen – Details unter Diagnose.",
			"GameFontNormal",
			Theme.COLORS.bad
		)
		Layout.AddButtonRow(stack, {
			{
				text = "Erneut bewerten",
				onClick = function()
					ScanService.ReevaluateBags({ reason = "ui_retry_after_fail" })
					VendorTab.Render(parent)
				end,
			},
		})
		Layout.FinishStack(stack)
		Layout.FooterText(root.footer, "Keine Vendor-Aktion ohne Bewertung")
		return
	end

	if #candidates == 0 then
		Layout.AddGap(stack, 6)
		Layout.AddText(stack, "Keine Händler-Kandidaten in der letzten Bewertung.", "GameFontNormal", Theme.COLORS.warn)
		Layout.AddText(
			stack,
			"Das ist erwartbar, wenn AH-Verkauf (QUICK/PROFIT/RARE) für die Taschenitems wirtschaftlicher ist, "
				.. "Händlerwert fehlt, Items geschützt sind oder Hold greift. Es werden keine Vendor-Zeilen künstlich erzeugt.",
			"GameFontHighlightSmall",
			Theme.COLORS.muted
		)
		Layout.AddGap(stack, 8)
		Layout.AddButtonRow(stack, {
			{
				text = "Erneut bewerten",
				tooltip = L("SCAN"),
				onClick = function()
					ScanService.ReevaluateBags({ reason = "vendor_tab_reeval" })
					VendorTab.Render(parent)
				end,
			},
		})
		Layout.FinishStack(stack)
		Layout.FooterText(root.footer, "0 Vendor-Kandidaten — keine Gruppen-Buttons hier")
		return
	end

	Layout.AddGap(stack, 4)
	local columns = {
		{ title = "Sel", width = 36 },
		{ title = "Item", width = 220 },
		{ title = "Menge", width = 50 },
		{ title = "Händlerwert", width = 100 },
		{ title = "Grund", width = 200 },
	}
	local rows = {}
	for _, d in ipairs(candidates) do
		local reason = (d.reasons and d.reasons[1]) or "VENDOR_CANDIDATE"
		rows[#rows + 1] = {
			private.selected[d.itemString] and "✓" or "",
			{
				text = d.name or d.itemString or "?",
				fullText = d.name or d.itemString or "?",
				color = Theme.COLORS.vendor,
			},
			tostring(d.quantity or 1),
			Money.Format((d.vendorSell or 0) * (d.quantity or 1), true),
			reason,
			_decision = d,
		}
	end

	Layout.AddTable(stack, columns, rows, {
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
			VendorTab.Render(parent)
		end,
		onEnter = function(row)
			local d = row._decision
			if not d then
				return
			end
			GameTooltip:SetOwner(UIParent, "ANCHOR_CURSOR")
			GameTooltip:AddLine(d.name or "?", 1, 1, 1)
			GameTooltip:AddLine("Händlerwert/Stack: " .. Money.Format(d.vendorSell or 0, true), 0.9, 0.85, 0.5)
			GameTooltip:AddLine(table.concat(d.reasons or {}, ", "), 0.75, 0.75, 0.75, true)
			GameTooltip:Show()
		end,
		onLeave = function()
			GameTooltip:Hide()
		end,
	})

	Layout.AddButtonRow(stack, {
		{
			text = "Alle wählen",
			onClick = function()
				for _, d in ipairs(candidates) do
					if d.itemString then
						private.selected[d.itemString] = true
					end
				end
				VendorTab.Render(parent)
			end,
		},
		{
			text = "Keine",
			onClick = function()
				wipe(private.selected)
				VendorTab.Render(parent)
			end,
		},
		{
			text = L("DRY_RUN"),
			tooltip = "Zählt, was verkauft würde — kein echter Verkauf",
			onClick = function()
				local sel = selectedList(candidates)
				if #sel == 0 then
					print("|cff4ecdc4[SmartTSM]|r Keine Vendor-Auswahl.")
					return
				end
				local res = VendorService.SellSelected(sel, { confirmed = true, dryRun = true })
				History.Add("VENDOR_DRY_RUN", { count = res.sold or 0, blocked = res.blocked or 0 })
				print(string.format(
					"|cff4ecdc4[SmartTSM]|r Vendor-Probelauf: wouldSell=%d blocked=%d (kein echter Verkauf)",
					res.sold or 0,
					res.blocked or 0
				))
			end,
		},
		{
			text = "Echtverkauf (Shift)",
			tooltip = "Nur mit Shift + offenem Händler + dryRunVendor=false. Sonst blockiert.",
			onClick = function()
				local sel = selectedList(candidates)
				if #sel == 0 then
					print("|cff4ecdc4[SmartTSM]|r Keine Vendor-Auswahl.")
					return
				end
				if not IsShiftKeyDown or not IsShiftKeyDown() then
					print("|cffffcc00[SmartTSM]|r Shift halten für echten Verkaufsversuch (Merchant muss offen sein).|r")
					return
				end
				if dryRun then
					print("|cffffcc00[SmartTSM]|r dryRunVendor=true — kein Echtverkauf. In Einstellungen umschalten.|r")
					return
				end
				local res = VendorService.SellSelected(sel, { confirmed = true, dryRun = false })
				History.Add("VENDOR_SELL", { count = res.sold or 0, blocked = res.blocked or 0 })
				print(string.format(
					"|cff4ecdc4[SmartTSM]|r Vendor-Ergebnis: sold=%d blocked=%d dryRun=%s",
					res.sold or 0,
					res.blocked or 0,
					tostring(res.dryRun)
				))
				wipe(private.selected)
				VendorTab.Render(parent)
			end,
		},
	})
	Layout.AddText(
		stack,
		"Keine Gruppenänderungen in diesem Tab. Schutzregeln und Hold bleiben aktiv; Bestätigung erforderlich.",
		"GameFontHighlightSmall",
		Theme.COLORS.muted
	)
	Layout.FinishStack(stack)
	Layout.FooterText(root.footer, string.format("%d ausgewählt / %d Kandidaten", selectedCount(), #candidates))
end
