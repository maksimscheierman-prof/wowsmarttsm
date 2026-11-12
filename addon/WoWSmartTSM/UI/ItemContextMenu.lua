local Smart = WoWSmartTSM
local C = Smart:Module("Constants")
local ItemContextMenu = Smart:Module("ItemContextMenu")

local private = {
	frame = nil,
	buttons = {},
}

local function hide()
	if private.frame then
		private.frame:Hide()
	end
end

local function ensureFrame()
	if private.frame then
		return private.frame
	end
	local f = CreateFrame("Frame", "WoWSmartTSMItemMenu", UIParent, BackdropTemplateMixin and "BackdropTemplate" or nil)
	f:SetFrameStrata("TOOLTIP")
	f:SetSize(240, 10)
	f:SetBackdrop({
		bgFile = "Interface\\Buttons\\WHITE8X8",
		edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
		edgeSize = 12,
		insets = { left = 3, right = 3, top = 3, bottom = 3 },
	})
	f:SetBackdropColor(0.08, 0.1, 0.12, 0.96)
	f:SetBackdropBorderColor(0.3, 0.4, 0.42, 1)
	f:EnableMouse(true)
	f:Hide()
	f:SetScript("OnLeave", function(self)
		if not MouseIsOver(self) then
			hide()
		end
	end)
	private.frame = f
	return f
end

local function clearButtons()
	for _, btn in ipairs(private.buttons) do
		btn:Hide()
		btn:SetParent(nil)
	end
	wipe(private.buttons)
end

local function addButton(label, onClick, disabled)
	local f = ensureFrame()
	local btn = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
	local y = 8 + (#private.buttons * 26)
	btn:SetPoint("TOPLEFT", 8, -y)
	btn:SetPoint("TOPRIGHT", -8, -y)
	btn:SetHeight(22)
	btn:SetText(label)
	if disabled then
		btn:Disable()
	else
		btn:Enable()
		btn:SetScript("OnClick", function()
			hide()
			if onClick then
				onClick()
			end
		end)
	end
	private.buttons[#private.buttons + 1] = btn
	f:SetHeight(y + 34)
end

local function afterRuleChange()
	local Logger = Smart:GetModule("Logger")
	if Logger and Logger.Info then
		Logger.Info("ITEM_RULE_CHANGED", "ItemContextMenu", "afterRuleChange", "rules updated")
	end
	local ScanService = Smart:GetModule("ScanService")
	if ScanService and ScanService.ReevaluateBags then
		ScanService.ReevaluateBags({ reason = "item_rule_changed" })
	end
	local MainFrame = Smart:GetModule("MainFrame")
	if MainFrame and MainFrame.SelectTab and MainFrame.GetActiveTab then
		MainFrame.SelectTab(MainFrame.GetActiveTab() or "Cleanup")
	end
end

function ItemContextMenu.Show(anchor, decision, opts)
	opts = opts or {}
	if not decision or not decision.itemString then
		return
	end
	hide()
	clearButtons()
	local role = decision.role or C.ROLES.MAIN
	local ItemRules = Smart:GetModule("ItemRules")
	local protected = decision.protected

	addButton("Details aktualisieren", function()
		if opts.onSelect then
			opts.onSelect(decision)
		end
	end)

	if role == C.ROLES.MAIN and not protected then
		addButton("Einmalig an Bank senden (Regel)", function()
			ItemRules.Set(decision.itemString, { type = "MAIL_ONCE", note = "once mail to bank" }, "character")
			print("|cff4ecdc4[SmartTSM]|r Vorgemerkt: einmalig an Bank — bitte Mail-Tab nutzen (Bestätigung am Briefkasten).")
			afterRuleChange()
		end)
		addButton("Immer an Bank senden (Bestätigung)", function()
			ItemRules.Set(decision.itemString, { type = "MAIL_ALWAYS", note = "always mail to bank", permanent = true }, "character")
			print("|cff4ecdc4[SmartTSM]|r Regel gespeichert: immer an Bank (Manuell bestätigen beim Versand).")
			afterRuleChange()
		end)
	end

	if role == C.ROLES.BANK and not protected then
		addButton("Für AH vorbereiten", function()
			print("|cff4ecdc4[SmartTSM]|r Nächster Schritt: Zum AH gehen und über TSM posten —", decision.name or "?")
			decision.actionStatus = "prepared"
			if opts.onSelect then
				opts.onSelect(decision)
			end
		end)
	end

	addButton("Einmalig behalten", function()
		ItemRules.Set(decision.itemString, { type = "KEEP" }, "once")
		-- once keep via session: use character keep for session by min
		ItemRules.Set(decision.itemString, { type = "KEEP", note = "once" }, "character")
		afterRuleChange()
	end)
	addButton("Immer behalten (Bestätigung)", function()
		ItemRules.Set(decision.itemString, { type = "KEEP", permanent = true }, "character")
		afterRuleChange()
	end)
	addButton("Mindestmenge behalten…", function()
		local minQty = math.max(1, math.floor((decision.quantity or 1) / 2))
		ItemRules.Set(decision.itemString, { type = "MIN_KEEP", minQty = minQty, permanent = true }, "character")
		print("|cff4ecdc4[SmartTSM]|r MIN_KEEP=", minQty, decision.name or "")
		afterRuleChange()
	end)

	if not protected then
		addButton("Vendor vorschlagen (Regel nicht hart)", function()
			print("|cff4ecdc4[SmartTSM]|r Vendor bleibt Vorschlag — Verkauf nur mit Bestätigung am Händler.")
			if opts.onSelect then
				opts.onSelect(decision)
			end
		end)
	end

	addButton("Ignorieren (dieser Charakter)", function()
		ItemRules.Set(decision.itemString, { type = "IGNORE" }, "character")
		afterRuleChange()
	end)
	addButton("Accountweit ignorieren (Bestätigung)", function()
		ItemRules.Set(decision.itemString, { type = "IGNORE", permanent = true }, "account")
		afterRuleChange()
	end)
	addButton("Smart Hold prüfen", function()
		print("|cff4ecdc4[SmartTSM]|r Strategie=", decision.strategy, "Hold-Gründe=", table.concat(decision.actionReasons or {}, ", "))
		if opts.onSelect then
			opts.onSelect(decision)
		end
	end)
	addButton("TSM-Gruppe ändern…", function()
		local MainFrame = Smart:GetModule("MainFrame")
		if MainFrame then
			MainFrame.SelectTab("Posting")
		end
		print("|cff4ecdc4[SmartTSM]|r Gruppenänderung nur über Vorschau + Bestätigung.")
	end)
	addButton("Regel zurücksetzen", function()
		ItemRules.Clear(decision.itemString, nil)
		afterRuleChange()
	end)

	local f = ensureFrame()
	f:ClearAllPoints()
	if anchor then
		f:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", 0, 0)
	else
		f:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
	end
	f:Show()
end

function ItemContextMenu.Hide()
	hide()
end
