local Smart = WoWSmartTSM
local C = Smart:Module("Constants")
local Operations = Smart:Module("Operations")

--[[
  TSM 4.15.6: no public ListOperations / GetOperationSettings / AssignOperation.
  Readable: price sources, IsCustomPriceValid, GetCustomPriceValue.
  Optional probe: GetAuctioningOperationMinPrice if present.
  Smart TSM shows suggestions + guided TSM setup — never writes private op tables.
]]

local UNKNOWN = "unbekannt"

local private = {
	probe = nil,
}

local function suggestionStore()
	WoWSmartTSM_DB = WoWSmartTSM_DB or {}
	WoWSmartTSM_DB.operationSuggestions = WoWSmartTSM_DB.operationSuggestions or {}
	return WoWSmartTSM_DB.operationSuggestions
end

function Operations.ProbeCapabilities()
	if private.probe then
		return private.probe
	end
	local api = TSM_API
	local cap = {
		apiPresent = api ~= nil,
		priceSources = api and type(api.GetPriceSourceKeys) == "function" or false,
		customPriceValid = api and type(api.IsCustomPriceValid) == "function" or false,
		customPriceValue = api and type(api.GetCustomPriceValue) == "function" or false,
		auctionMinPrice = api and type(api.GetAuctioningOperationMinPrice) == "function" or false,
		listOperations = api and type(api.GetOperations) == "function" or false,
		getOperationSettings = api and type(api.GetOperationSettings) == "function" or false,
		createOperation = api and type(api.CreateOperation) == "function" or false,
		assignOperation = api and (type(api.AssignOperation) == "function" or type(api.SetOperation) == "function") or false,
		writeMode = "MANUAL_SETUP",
		claim = "VERIFIED_READ_PARTIAL",
	}
	if cap.listOperations and cap.getOperationSettings then
		cap.claim = "OPS_READ_DETECTED"
	end
	if cap.createOperation and cap.assignOperation then
		cap.writeMode = "DIRECT_API"
		cap.claim = "WRITE_API_DETECTED"
	end
	private.probe = cap
	return cap
end

function Operations.GetAuctioningContext(itemString)
	local ctx = {
		itemString = itemString,
		minPrice = nil,
		normalPrice = nil,
		maxPrice = nil,
		postCap = nil,
		stackSize = nil,
		duration = nil,
		undercut = nil,
		operationName = nil,
		source = "unavailable",
	}
	local api = TSM_API
	if api and api.GetAuctioningOperationMinPrice then
		local ok, v = pcall(api.GetAuctioningOperationMinPrice, itemString)
		if ok and v ~= nil then
			ctx.minPrice = v
			ctx.source = "GetAuctioningOperationMinPrice"
		end
	end
	return ctx
end

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

function Operations.ListPriceSources()
	local keys = {}
	if TSM_API and TSM_API.GetPriceSourceKeys then
		local ok = pcall(TSM_API.GetPriceSourceKeys, keys)
		if not ok then
			return {}
		end
	end
	return keys
end

function Operations.ValidatePriceFormula(formula)
	if not formula or formula == "" then
		return false, "EMPTY"
	end
	if TSM_API and TSM_API.IsCustomPriceValid then
		local ok, valid = pcall(TSM_API.IsCustomPriceValid, formula)
		if ok then
			return valid and true or false, valid and "OK" or "INVALID"
		end
	end
	return nil, "API_UNAVAILABLE"
end

local DEFAULT_PROFILES = {
	{
		id = "quick",
		type = "Auctioning",
		name = C.OPS.QUICK,
		group = C.GROUPS.QUICK,
		minPrice = "max(vendorsell, first(dbminbuyout, dbmarket) * 0.85)",
		normalPrice = "max(vendorsell * 1.1, first(dbmarket, dbminbuyout))",
		maxPrice = "first(dbmarket, dbminbuyout) * 1.25",
		postCap = "3",
		stackSize = "1",
		duration = "24",
		undercut = "1c",
		note = "Schnelldreher — nur anwenden wenn Formelquellen vorhanden.",
	},
	{
		id = "profit",
		type = "Auctioning",
		name = C.OPS.PROFIT,
		group = C.GROUPS.PROFIT,
		minPrice = "max(vendorsell * 1.15, first(dbmarket, dbregionmarketavg) * 0.9)",
		normalPrice = "first(dbmarket, dbregionmarketavg)",
		maxPrice = "first(dbmarket, dbregionmarketavg) * 1.35",
		postCap = "2",
		stackSize = "1",
		duration = "24",
		undercut = "1c",
		note = "Standardprofit — Region nur wenn lokal fehlt.",
	},
	{
		id = "rare",
		type = "Auctioning",
		name = C.OPS.RARE,
		group = C.GROUPS.RARE,
		minPrice = "max(vendorsell * 2, first(dbmarket, dbregionmarketavg) * 0.95)",
		normalPrice = "first(dbmarket, dbregionmarketavg) * 1.1",
		maxPrice = "first(dbmarket, dbregionmarketavg) * 1.6",
		postCap = "1",
		stackSize = "1",
		duration = "48",
		undercut = "1c",
		note = "Hochwertig — selten posten, nicht blind undercutten.",
	},
	{
		id = "mail",
		type = "Mailing",
		name = C.OPS.MAIL_TO_BANK,
		group = C.GROUPS.QUICK,
		target = nil, -- filled at runtime
		keepQty = "0",
		note = "Nur MAIN → Banko. Nie auf BANK zuweisen.",
	},
	{
		id = "vendor",
		type = "Vendoring",
		name = C.OPS.VENDOR,
		group = C.GROUPS.VENDOR,
		sellTrash = "true",
		vsDestroyValue = UNKNOWN,
		note = "Nur nach Bestätigung am Händler; keine Auto-Verkäufe durch Smart TSM.",
	},
}

function Operations.GetEditableSuggestion(id)
	local store = suggestionStore()
	local base
	for _, p in ipairs(DEFAULT_PROFILES) do
		if p.id == id then
			base = p
			break
		end
	end
	if not base then
		return nil
	end
	local overlay = store[id] or {}
	local out = {}
	for k, v in pairs(base) do
		out[k] = overlay[k] ~= nil and overlay[k] or v
	end
	return out
end

function Operations.SetSuggestionField(id, field, value)
	if not id or not field then
		return false
	end
	local store = suggestionStore()
	store[id] = store[id] or {}
	store[id][field] = value
	return true
end

function Operations.ResetSuggestion(id)
	suggestionStore()[id] = nil
end

---Catalog for Operations tab: live ops if API exists, else suggestions + unknowns.
function Operations.BuildCatalog()
	local cap = Operations.ProbeCapabilities()
	local CP = Smart:GetModule("CharacterProfiles")
	local role = CP and CP.GetRole and CP.GetRole() or C.ROLES.MAIN
	local bank = CP and CP.GetPrimaryBankDisplay and CP.GetPrimaryBankDisplay() or nil
	local mailOp, mailCode, mailNote = Operations.RecommendMailingOp(role, bank)

	local catalog = {
		capabilities = cap,
		liveAvailable = cap.listOperations and true or false,
		auctioning = {},
		mailing = {},
		vendoring = {},
		suggestions = {},
		warnings = {},
	}

	if not cap.listOperations then
		catalog.warnings[#catalog.warnings + 1] =
			"TSM 4.15.6: keine öffentliche GetOperations-API — Live-Ops nicht auflistbar."
	end

	-- Attempt live list only via verified probe
	if cap.listOperations and TSM_API.GetOperations then
		for _, typeName in ipairs({ "Auctioning", "Mailing", "Vendoring" }) do
			local names = {}
			local ok = pcall(TSM_API.GetOperations, typeName, names)
			if ok then
				local bucket = typeName == "Auctioning" and catalog.auctioning
					or (typeName == "Mailing" and catalog.mailing or catalog.vendoring)
				for _, name in ipairs(names) do
					local settings = { name = name, type = typeName, fields = {} }
					if cap.getOperationSettings and TSM_API.GetOperationSettings then
						local raw = {}
						local ok2 = pcall(TSM_API.GetOperationSettings, typeName, name, raw)
						if ok2 then
							settings.fields = raw
							settings.source = "API"
						else
							settings.fields = { note = UNKNOWN }
							settings.source = "read_failed"
						end
					else
						settings.fields = {
							minPrice = UNKNOWN,
							normalPrice = UNKNOWN,
							maxPrice = UNKNOWN,
							postCap = UNKNOWN,
							stackSize = UNKNOWN,
							duration = UNKNOWN,
							undercut = UNKNOWN,
							target = UNKNOWN,
							groups = UNKNOWN,
						}
						settings.source = "name_only"
					end
					bucket[#bucket + 1] = settings
				end
			end
		end
	end

	for _, def in ipairs(DEFAULT_PROFILES) do
		local sug = Operations.GetEditableSuggestion(def.id)
		if sug.type == "Mailing" then
			sug.target = mailOp and bank or UNKNOWN
			sug.mailCode = mailCode
			sug.mailNote = mailNote
			sug.blocked = mailOp == nil
		end
		-- Validate auctioning formulas against TSM when possible
		if sug.type == "Auctioning" then
			sug.validation = {}
			for _, field in ipairs({ "minPrice", "normalPrice", "maxPrice" }) do
				local ok, why = Operations.ValidatePriceFormula(sug[field])
				sug.validation[field] = { ok = ok, why = why }
			end
		end
		catalog.suggestions[#catalog.suggestions + 1] = sug
	end

	return catalog
end

function Operations.SetupChecklist()
	local CP = Smart:GetModule("CharacterProfiles")
	local role = CP and CP.GetRole and CP.GetRole() or "MAIN"
	local bank = CP and CP.GetPrimaryBankDisplay and CP.GetPrimaryBankDisplay() or nil
	local mailOp, mailCode, mailNote = Operations.RecommendMailingOp(role, bank)
	local Groups = Smart:GetModule("Groups")
	local missing = Groups and Groups.MissingSmartGroups and Groups.MissingSmartGroups() or {}
	return {
		{
			id = "groups_detect",
			title = "Gruppen erkennen",
			detail = "Live-TSM-Gruppen werden im TSM-Gruppen-Tab gelesen.",
			manual = false,
			ok = true,
		},
		{
			id = "groups_missing",
			title = "Fehlende Smart-Gruppen",
			detail = #missing == 0 and "Alle Smart-Gruppen vorhanden."
				or ("Fehlt: " .. table.concat(missing, ", ")),
			manual = #missing > 0,
			ok = #missing == 0,
		},
		{
			id = "ops_assign",
			title = "Operationszuordnung",
			detail = "In TSM Operations den Smart-Gruppen zuweisen (kein öffentlicher Write).",
			manual = true,
			ok = false,
		},
		{
			id = "ops_mailing",
			title = "Mailing Azamat → Banko",
			detail = mailOp and ("Op „" .. mailOp .. "“ → " .. tostring(bank))
				or ("Blockiert: " .. tostring(mailNote) .. " [" .. tostring(mailCode) .. "]"),
			manual = true,
			ok = mailOp ~= nil,
			blocked = mailOp == nil,
		},
		{
			id = "ops_auctioning_bank",
			title = "Auctioning auf Banko",
			detail = "BANK: Auctioning-Ops auf Smart Quick/Profit/Rare — kein Mailing.",
			manual = true,
			ok = false,
		},
	}
end

function Operations.OpenTSMHint()
	return "TSM öffnen → Operations. Smart TSM legt Ops nicht per API an (4.15.6)."
end

function Operations.UnknownLabel()
	return UNKNOWN
end
