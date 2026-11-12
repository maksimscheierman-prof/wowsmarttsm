local Smart = WoWSmartTSM
local C = Smart:Module("Constants")
local Operations = Smart:Module("Operations")

--[[
  TSM 4.15.6: public auctioning price helpers exist; create/assign operations
  are NOT in TSM_API. Smart TSM recommends ops and guides setup — never invents
  writes into private TSM operation tables.
]]

local private = {
	probe = nil,
}

function Operations.ProbeCapabilities()
	if private.probe then
		return private.probe
	end
	local api = TSM_API
	local cap = {
		apiPresent = api ~= nil,
		auctionMinPrice = api and type(api.GetAuctioningOperationMinPrice) == "function" or false,
		createOperation = api and type(api.CreateOperation) == "function" or false,
		assignOperation = api and (type(api.AssignOperation) == "function" or type(api.SetOperation) == "function") or false,
		listOperations = api and type(api.GetOperations) == "function" or false,
		writeMode = "MANUAL_SETUP",
		claim = "VERIFIED_READ_PARTIAL",
	}
	if cap.createOperation and cap.assignOperation then
		cap.writeMode = "DIRECT_API"
		cap.claim = "WRITE_API_DETECTED"
	end
	private.probe = cap
	return cap
end

---Read-only helpers for auctioning operation context.
function Operations.GetAuctioningContext(itemString)
	local ctx = {
		itemString = itemString,
		minPrice = nil,
		normalPrice = nil,
		maxPrice = nil,
		postCap = nil,
		operationName = nil,
	}
	if TSM_API and TSM_API.GetAuctioningOperationMinPrice then
		local ok, v = pcall(TSM_API.GetAuctioningOperationMinPrice, itemString)
		if ok then
			ctx.minPrice = v
		end
	end
	return ctx
end

---Map Smart strategy → recommended auctioning operation name.
function Operations.RecommendAuctioningOp(strategy)
	local map = {
		[C.STRATEGIES.QUICK_SELL] = C.OPS.QUICK,
		[C.STRATEGIES.PROFIT_SELL] = C.OPS.PROFIT,
		[C.STRATEGIES.RARE_SELL] = C.OPS.RARE,
		[C.STRATEGIES.VENDOR] = C.OPS.VENDOR,
		[C.STRATEGIES.HOLD] = C.OPS.HOLD,
	}
	return map[strategy]
end

---Mailing: MAIN may use Smart Mail to Bank → bank character.
---BANK must NEVER mail to self. MANUAL: suggestions only.
function Operations.RecommendMailingOp(role, bankName)
	role = role or "MAIN"
	if role == "BANK" then
		return nil, "BANK_NO_SELF_MAIL", "BANK never mails to self — auction/vendor only."
	end
	if role == "MANUAL" then
		return nil, "MANUAL_NO_AUTO", "MANUAL role: no automatic mailing operation."
	end
	if not bankName or bankName == "" then
		return nil, "BANK_NOT_CONFIGURED", "Configure primary bank character before mailing op."
	end
	local CP = Smart:GetModule("CharacterProfiles")
	if CP and CP.CanMailToBank then
		local can, why = CP.CanMailToBank()
		if not can then
			return nil, why or "MAIL_BLOCKED", "Mailing to bank blocked."
		end
	end
	return C.OPS.MAIL_TO_BANK, nil, "Mail surplus sellables MAIN → " .. tostring(bankName)
end

---Human checklist for setup wizard (manual TSM steps).
function Operations.SetupChecklist()
	local CP = Smart:GetModule("CharacterProfiles")
	local role = CP and CP.GetRole and CP.GetRole() or "MAIN"
	local bank = CP and CP.GetPrimaryBankDisplay and CP.GetPrimaryBankDisplay() or nil
	local mailOp, mailCode, mailNote = Operations.RecommendMailingOp(role, bank)
	return {
		{
			id = "ops_auctioning",
			title = "Auctioning-Operationen",
			detail = "In TSM → Operations → Auctioning: "
				.. C.OPS.QUICK
				.. ", "
				.. C.OPS.PROFIT
				.. ", "
				.. C.OPS.RARE
				.. " anlegen und Smart-Gruppen zuweisen.",
			manual = true,
		},
		{
			id = "ops_vendor",
			title = "Vendoring",
			detail = "Optional Vendoring-Op für " .. C.GROUPS.VENDOR .. " (nur nach Bestätigung am Händler).",
			manual = true,
		},
		{
			id = "ops_mailing",
			title = "Mailing",
			detail = mailOp
					and ("Op „" .. mailOp .. "“: Ziel = " .. tostring(bank) .. ". Nicht auf BANK anwenden.")
				or ("Mailing übersprungen: " .. tostring(mailNote) .. " (" .. tostring(mailCode) .. ")"),
			manual = true,
			blocked = mailOp == nil,
		},
		{
			id = "ops_inheritance",
			title = "Vererbung",
			detail = "Untergruppen erben Ops vom Parent — Smart-Untergruppen explizit zuweisen oder Root-Vererbung prüfen.",
			manual = true,
		},
	}
end

function Operations.OpenTSMHint()
	return "TSM öffnen → Operations. Smart TSM legt Auctioning/Mailing-Ops nicht per API an (4.15.6)."
end
