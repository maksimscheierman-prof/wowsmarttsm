local Smart = WoWSmartTSM
local Locale = Smart:Module("Locale")
local Layout = Smart:Module("Layout")
local Theme = Smart:Module("Theme")
local MailService = Smart:Module("MailService")
local CleanupService = Smart:Module("CleanupService")
local MailTab = Smart:Module("MailTab")

function MailTab.Render(parent)
	local L = Locale.T
	local ScanService = Smart:GetModule("ScanService")
	local CP = Smart:GetModule("CharacterProfiles")
	local results = ScanService.GetLastResults() or {}
	local plan = MailService.BuildPlan(results)

	local root = Layout.Begin(parent)
	local _, bw = Layout.HeaderButton(root.header, L("SCAN"), function()
		ScanService.ReevaluateBags({ reason = "mail_ui" })
		MailTab.Render(parent)
	end)
	Layout.HeaderTitle(root.header, L("MAIL"), (bw or 160) + 12)

	local stack = Layout.BodyStack(root)
	Layout.AddText(stack, "Mail Manager (MAIN → Bank)", "GameFontNormal")

	if not plan.ok then
		Layout.AddText(stack, "Status: " .. tostring(plan.code), "GameFontNormal", Theme.COLORS.bad)
		if plan.code == "BANK_CHARACTER_NOT_CONFIGURED" then
			Layout.AddButtonRow(stack, {
				{
					text = "Bankcharakter wählen",
					onClick = function()
						Smart:GetModule("MainFrame").SelectTab("Characters")
					end,
				},
			})
		end
		Layout.FinishStack(stack)
		Layout.FooterText(root.footer, "Kein Versandplan")
		return
	end

	Layout.AddText(
		stack,
		string.format(
			"Empfänger: %s | Anhänge: %d | Nachrichten: %d | Briefkasten offen: %s",
			tostring(plan.recipient),
			plan.totalAttachments or 0,
			plan.messageCount or 0,
			tostring(MailService.IsMailboxOpen())
		),
		"GameFontHighlightSmall",
		Theme.COLORS.muted
	)
	Layout.AddText(
		stack,
		"Geplanteter Versand gilt niemals als erfolgreich. Spieler muss Senden klicken. Keine Input-Bots.",
		"GameFontHighlightSmall",
		Theme.COLORS.warn
	)
	Layout.AddGap(stack, 6)

	local columns = {
		{ title = "Msg", width = 40 },
		{ title = "Item", width = 200 },
		{ title = "Aktion", width = 110 },
		{ title = "Menge", width = 50 },
		{ title = "Slot", width = 70 },
	}
	local rows = {}
	for mi, msg in ipairs(plan.messages or {}) do
		for _, d in ipairs(msg.attachments or {}) do
			rows[#rows + 1] = {
				tostring(mi),
				{ text = d.name or d.itemString or "?", fullText = d.name or d.itemString or "?" },
				CleanupService.ActionLabel(d.inventoryAction),
				tostring(d.actionQty or d.quantity or 1),
				string.format("%s:%s", tostring(d.bag), tostring(d.slot)),
			}
		end
	end
	if #rows == 0 then
		Layout.AddText(stack, "Keine MAIL_TO_BANK / HOLD_AT_BANK Kandidaten.", "GameFontHighlight", Theme.COLORS.muted)
	else
		Layout.AddTable(stack, columns, rows, { rowHeight = 22 })
	end

	Layout.AddGap(stack, 6)
	local buttons = {}
	for mi = 1, math.min(5, #(plan.messages or {})) do
		buttons[#buttons + 1] = {
			text = "Nachricht " .. mi .. " vorbereiten",
			tooltip = "Empfänger + Anhänge in Send Mail — danach Senden klicken (Shift erforderlich)",
			onClick = function()
				if not IsShiftKeyDown or not IsShiftKeyDown() then
					print("|cffffcc00[SmartTSM]|r Shift halten zum Vorbereiten der Mail.|r")
					return
				end
				local ok, err = MailService.PrepareMessage(mi, { confirmed = true })
				if ok then
					print("|cff4ecdc4[SmartTSM]|r Mail vorbereitet — jetzt Senden im Briefkasten klicken.")
				else
					print("|cffff6666[SmartTSM]|r Mail-Vorbereitung fehlgeschlagen: " .. tostring(err))
				end
			end,
		}
	end
	if #buttons > 0 then
		Layout.AddButtonRow(stack, buttons)
	end

	Layout.FinishStack(stack)
	Layout.FooterText(root.footer, "Bank=" .. tostring(CP.GetPrimaryBankKey() or "—"))
end
