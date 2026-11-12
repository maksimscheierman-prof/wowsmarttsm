local Smart = WoWSmartTSM
local C = Smart:Module("Constants")
local ItemExplain = Smart:Module("ItemExplain")

local HUMAN = {
	BANK_CHARACTER_NOT_CONFIGURED = "Bankcharakter festlegen, um dieses Item zu verschicken.",
	BANK_IS_SELF = "Du bist auf dem Bankcharakter — AH vorbereiten statt an dich selbst zu senden.",
	BANK_FACTION_MISMATCH = "Bankcharakter hat eine andere Fraktion — Versand nicht möglich.",
	BANK_READY_TO_POST = "Für den Verkauf im Auktionshaus vorbereiten.",
	BANK_HOLD_STORAGE = "Im Banklager aufbewahren (Smart Hold).",
	BANK_VENDOR = "Händlerverkauf empfohlen, da der erwartete AH-Nettoerlös nicht ausreichend höher ist.",
	MAIL_TO_BANK_FOR_AH = "An den Bankcharakter senden, damit dort im AH verkauft werden kann.",
	HOLD_AT_BANK = "Smart Hold — an den Bankcharakter senden und dort lagern.",
	HOLD_KEEP_ON_MAIN = "Smart Hold bleibt auf diesem Charakter (Einstellung).",
	VENDOR_ON_MAIN = "Händlerverkauf empfohlen, da der erwartete AH-Nettoerlös nicht ausreichend höher ist.",
	HARD_PROTECT = "Geschützt (Quest/ausgerüstet/gesperrt/Regel) — behalten.",
	RULE_KEEP = "Durch eine Keep-Regel geschützt.",
	RULE_IGNORE = "Ignoriert durch eine Regel.",
	CRAFTING_RESERVE = "Wird behalten, da es als reserviertes Craftingmaterial geschützt ist.",
	CONSUMABLE_KEEP = "Wird behalten, da es als benötigtes Verbrauchsgut geschützt ist.",
	CONSUMABLE_NEEDS_MIN_CONFIG = "Optionale Reservemenge möglich — ohne Angabe bleibt der Schutz auf MAIN aktiv.",
	CONSUMABLE_SURPLUS = "Überschuss über die Reservemenge — Verkauf/Versand möglich.",
	MANUAL_ROLE_NO_AUTO = "MANUAL-Rolle: nur Vorschlag, keine Automatisierung.",
	BANK_NO_SELF_MAIL = "Bank-Charakter sendet nicht an sich selbst.",
	FALLBACK_REVIEW = "Unklare Daten — manuell prüfen.",
	BANK_REVIEW = "Auf dem Bankcharakter manuell prüfen.",
}

local NEXT = {
	MAIL_TO_BANK = "Zum Briefkasten gehen und Versand vorbereiten.",
	HOLD_AT_BANK = "Zum Briefkasten gehen und Hold-Items versenden.",
	POST_AH = "Zum Auktionshaus gehen und über TSM posten.",
	VENDOR = "Zum Händler gehen und Verkaufsliste prüfen.",
	KEEP = "Keine Aktion notwendig.",
	HOLD = "Im Banklager aufbewahren.",
	IGNORE = "Keine Aktion — ignoriert.",
	MANUAL_REVIEW = "In der Detailansicht prüfen und manuell entscheiden.",
}

function ItemExplain.HumanReason(decision)
	if not decision then
		return "Keine Entscheidung."
	end
	local codes = decision.actionReasons or decision.reasons or {}
	for _, code in ipairs(codes) do
		if HUMAN[code] then
			return HUMAN[code], code
		end
	end
	local action = decision.inventoryAction
	if action == C.ACTIONS.POST_AH then
		return HUMAN.BANK_READY_TO_POST, "BANK_READY_TO_POST"
	end
	if action == C.ACTIONS.MAIL_TO_BANK then
		return HUMAN.MAIL_TO_BANK_FOR_AH, "MAIL_TO_BANK_FOR_AH"
	end
	if action == C.ACTIONS.VENDOR then
		return HUMAN.VENDOR_ON_MAIN, "VENDOR"
	end
	if action == C.ACTIONS.KEEP then
		return "Behalten — keine Verkaufsaktion.", "KEEP"
	end
	if action == C.ACTIONS.HOLD then
		return HUMAN.BANK_HOLD_STORAGE, "HOLD"
	end
	return tostring(codes[1] or action or "Unbekannt"), codes[1]
end

function ItemExplain.NextStep(decision)
	if not decision then
		return "—"
	end
	local action = decision.inventoryAction
	if decision.needsBankConfig then
		return "Im Charakter-Tab einen Bankcharakter festlegen, dann neu bewerten."
	end
	if decision.mailBlockCode == "BANK_IS_SELF" and decision.role ~= C.ROLES.BANK then
		return "Rolle auf BANK prüfen oder neu bewerten — du bist auf dem Bankcharakter."
	end
	return NEXT[action] or "Manuell prüfen."
end

function ItemExplain.ActionStatusLabel(status)
	local map = {
		suggested = "Vorgeschlagen",
		prepared = "Vorbereitet",
		confirmed = "Bestätigt",
		executed = "Ausgeführt",
	}
	return map[status or "suggested"] or tostring(status or "Vorgeschlagen")
end

function ItemExplain.DetailLines(decision)
	local Money = Smart:GetModule("MoneyUtil")
	local Time = Smart:GetModule("TimeUtil")
	local Freshness = Smart:GetModule("Freshness")
	local fmt = function(v)
		if Money and Money.Format then
			return Money.Format(v or 0, true)
		end
		return tostring(v or 0)
	end
	local human, code = ItemExplain.HumanReason(decision)
	local p = decision.pricing or {}
	local qty = decision.actionQty or decision.quantity or 1
	local market = decision.marketValue or p.marketValue or 0
	local vendor = decision.vendorSell or p.vendorSell or 0
	local age = "unbekannt"
	if Freshness and Freshness.GetAgeSeconds then
		local a = Freshness.GetAgeSeconds("realm")
		if a then
			age = string.format("%d min", math.floor(a / 60))
		end
	elseif decision.dataAgeSeconds then
		age = string.format("%d min", math.floor(decision.dataAgeSeconds / 60))
	end

	local lines = {
		{ "Name", decision.name or "?" },
		{ "Qualität", tostring(decision.quality or decision.itemQuality or "?") },
		{ "Item-ID", tostring(decision.itemId or "?") },
		{ "Menge (Aktion)", tostring(qty) },
		{ "Stacks", tostring(decision.stackCount or 1) },
		{ "Markt / Stück", fmt(market) },
		{ "Markt gesamt", fmt(market * qty) },
		{ "Händler / Stück", fmt(vendor) },
		{ "Händler gesamt", fmt(vendor * qty) },
		{ "DBMarket", p.dbMarket and fmt(p.dbMarket) or "unbekannt" },
		{ "DBMinBuyout", p.dbMinBuyout and fmt(p.dbMinBuyout) or "unbekannt" },
		{ "DBRegionMarketAvg", p.dbRegionMarketAvg and fmt(p.dbRegionMarketAvg) or "unbekannt" },
		{ "DBRegionSaleRate", p.dbRegionSaleRate ~= nil and tostring(p.dbRegionSaleRate) or "unbekannt" },
		{ "DBRegionSoldPerDay", p.dbRegionSoldPerDay ~= nil and tostring(p.dbRegionSoldPerDay) or "unbekannt" },
		{ "DBNumAuctions", p.dbNumAuctions ~= nil and tostring(p.dbNumAuctions) or "unbekannt" },
		{ "Datenalter", age },
		{ "AH-Netto (geschätzt)", p.ahNet and fmt(p.ahNet) or (decision.ahNet and fmt(decision.ahNet) or "unbekannt") },
		{ "Deposit", p.deposit and fmt(p.deposit) or "unbekannt" },
		{ "TSM-Gruppe", decision.currentGroup or decision.group or "unbekannt" },
		{ "Vorschlag-Gruppe", decision.targetGroup or "—" },
		{ "Strategie", tostring(decision.strategy or "?") },
		{ "Inventaraktion", tostring(decision.inventoryAction or "?") },
		{ "Schutz", decision.protected and "ja" or "nein" },
		{ "Begründung", human },
		{ "Code", tostring(code or "—") },
		{ "Nächster Schritt", ItemExplain.NextStep(decision) },
		{ "Status", ItemExplain.ActionStatusLabel(decision.actionStatus) },
		{ "Rolle", tostring(decision.role or "?") },
	}
	if decision.stacks then
		local parts = {}
		for _, st in ipairs(decision.stacks) do
			parts[#parts + 1] = string.format("Bag %s Slot %s ×%s", tostring(st.bag), tostring(st.slot), tostring(st.qty))
		end
		lines[#lines + 1] = { "Taschenstapel", table.concat(parts, "; ") }
	end
	return lines
end
