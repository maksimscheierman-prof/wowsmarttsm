local Smart = WoWSmartTSM
local C = Smart:Module("Constants")
local Logger = Smart:Module("Logger")
local CharacterProfiles = Smart:Module("CharacterProfiles")

local function realmName()
	local Resolver = Smart:GetModule("CharacterResolver")
	if Resolver and Resolver.MakeKey then
		local snap = Resolver.ParseKey and Resolver.ParseKey(Resolver.MakeKey())
		return snap and snap.realm or (GetRealmName and GetRealmName() or "UnknownRealm")
	end
	return tostring(GetRealmName and GetRealmName() or "UnknownRealm")
end

local function playerName()
	return tostring(UnitName and UnitName("player") or "Unknown")
end

local function playerFaction()
	return tostring(UnitFactionGroup and UnitFactionGroup("player") or "Unknown")
end

function CharacterProfiles.MakeKey(name, realm, faction)
	local Resolver = Smart:GetModule("CharacterResolver")
	if Resolver and Resolver.MakeKey then
		return Resolver.MakeKey(name, realm, faction)
	end
	return string.format("%s-%s|%s", name or playerName(), realm or realmName(), faction or playerFaction())
end

function CharacterProfiles.GetCurrentKey()
	local Resolver = Smart:GetModule("CharacterResolver")
	if Resolver and Resolver.GetCurrentKey then
		return Resolver.GetCurrentKey()
	end
	return CharacterProfiles.MakeKey()
end

local function ensureStore()
	WoWSmartTSM_DB = WoWSmartTSM_DB or {}
	WoWSmartTSM_DB.characters = WoWSmartTSM_DB.characters or {}
	WoWSmartTSM_DB.profile = WoWSmartTSM_DB.profile or {
		primaryBankKey = nil,
		bankKeys = {},
	}
	-- Normalize stored primary bank key once
	local Resolver = Smart:GetModule("CharacterResolver")
	if Resolver and Resolver.NormalizeKey and WoWSmartTSM_DB.profile.primaryBankKey then
		local n = Resolver.NormalizeKey(WoWSmartTSM_DB.profile.primaryBankKey)
		if n and n ~= WoWSmartTSM_DB.profile.primaryBankKey then
			WoWSmartTSM_DB.profile.primaryBankKey = n
		end
	end
	return WoWSmartTSM_DB
end

local function defaultChar(key)
	local Resolver = Smart:GetModule("CharacterResolver")
	local parsed = Resolver and Resolver.ParseKey and Resolver.ParseKey(key)
	return {
		key = key,
		name = (parsed and parsed.name) or playerName(),
		realm = (parsed and parsed.realm) or realmName(),
		faction = (parsed and parsed.faction) or playerFaction(),
		role = C.ROLES.MAIN,
		autoEval = true,
		protectConsumables = true,
		protectCraftingReserves = true,
		smartHoldToBank = true,
		goalEmptyBags = true,
		autoAhScan = false,
		autoMailWithoutConfirm = false,
		autoVendorWithoutConfirm = false,
		updatedAt = 0,
	}
end

function CharacterProfiles.EnsureCurrent()
	local db = ensureStore()
	local key = CharacterProfiles.GetCurrentKey()
	local Resolver = Smart:GetModule("CharacterResolver")
	local existing = Resolver and Resolver.FindCharacter and select(1, Resolver.FindCharacter(key))
	if existing then
		-- Migrate to canonical key if needed
		local _, storedKey = Resolver.FindCharacter(key)
		if storedKey and storedKey ~= key then
			db.characters[key] = existing
			existing.key = key
			-- keep old key as alias table entry pointing same data is messy; copy
		end
	end
	if not db.characters[key] then
		db.characters[key] = defaultChar(key)
		Logger.Info("UNKNOWN", "CharacterProfiles", "EnsureCurrent", "Created profile for " .. key)
	else
		local ch = db.characters[key]
		ch.name = playerName()
		ch.realm = realmName()
		ch.faction = playerFaction()
		ch.key = key
	end
	-- If this login is the primary bank, ensure role is BANK
	local bankKey = CharacterProfiles.GetPrimaryBankKey()
	if bankKey and Resolver and Resolver.KeysEqual and Resolver.KeysEqual(bankKey, key) then
		if db.characters[key].role ~= C.ROLES.BANK then
			db.characters[key].role = C.ROLES.BANK
			Logger.Info("CHARACTER_ROLE_RESOLVED", "CharacterProfiles", "EnsureCurrent", "Forced BANK role for primary bank login")
		end
	end
	return db.characters[key]
end

function CharacterProfiles.Get(key)
	local db = ensureStore()
	key = key or CharacterProfiles.GetCurrentKey()
	local Resolver = Smart:GetModule("CharacterResolver")
	if Resolver and Resolver.FindCharacter then
		local ch = Resolver.FindCharacter(key)
		if ch then
			return ch
		end
	end
	return db.characters[key]
end

function CharacterProfiles.GetCurrent()
	return CharacterProfiles.EnsureCurrent()
end

function CharacterProfiles.GetRole(key)
	local Resolver = Smart:GetModule("CharacterResolver")
	if Resolver and Resolver.GetEffectiveRole then
		return Resolver.GetEffectiveRole(key or CharacterProfiles.GetCurrentKey())
	end
	local ch = CharacterProfiles.Get(key)
	return (ch and ch.role) or C.ROLES.MAIN
end

function CharacterProfiles.SetRole(key, role)
	local db = ensureStore()
	key = key or CharacterProfiles.GetCurrentKey()
	local Resolver = Smart:GetModule("CharacterResolver")
	if Resolver and Resolver.NormalizeKey then
		key = Resolver.NormalizeKey(key) or key
	end
	if not db.characters[key] then
		db.characters[key] = defaultChar(key)
	end
	if role ~= C.ROLES.MAIN and role ~= C.ROLES.BANK and role ~= C.ROLES.MANUAL then
		Logger.Error("CHAR_CONFIG_INVALID", "CharacterProfiles", "SetRole", "Invalid role " .. tostring(role))
		return false
	end
	db.characters[key].role = role
	if Resolver and Resolver.Invalidate then
		Resolver.Invalidate()
	end
	if Resolver and Resolver.NotifyProfileChanged then
		Resolver.NotifyProfileChanged("role_changed")
	end
	return true
end

function CharacterProfiles.List()
	local db = ensureStore()
	local list = {}
	for key, ch in pairs(db.characters) do
		list[#list + 1] = ch
	end
	table.sort(list, function(a, b)
		return tostring(a.key) < tostring(b.key)
	end)
	return list
end

function CharacterProfiles.GetPrimaryBankKey()
	local Resolver = Smart:GetModule("CharacterResolver")
	if Resolver and Resolver.GetPrimaryBankKey then
		return Resolver.GetPrimaryBankKey()
	end
	local db = ensureStore()
	return db.profile.primaryBankKey
end

function CharacterProfiles.SetPrimaryBankKey(key)
	local db = ensureStore()
	local Resolver = Smart:GetModule("CharacterResolver")
	if key == nil or key == "" then
		db.profile.primaryBankKey = nil
		if Resolver and Resolver.NotifyProfileChanged then
			Resolver.NotifyProfileChanged("bank_cleared")
		end
		return true
	end
	if Resolver and Resolver.NormalizeKey then
		key = Resolver.NormalizeKey(key) or key
	end
	db.profile.primaryBankKey = key
	db.profile.bankKeys = db.profile.bankKeys or {}
	db.profile.bankKeys[key] = true
	if not db.characters[key] then
		-- Create placeholder so role can stick
		db.characters[key] = defaultChar(key)
	end
	db.characters[key].role = C.ROLES.BANK
	Logger.Info("BANK_CHARACTER_RESOLVED", "CharacterProfiles", "SetPrimaryBankKey", "Primary bank=" .. tostring(key))
	if Resolver and Resolver.NotifyProfileChanged then
		Resolver.NotifyProfileChanged("bank_changed")
	end
	return true
end

function CharacterProfiles.IsBankConfigured()
	local Resolver = Smart:GetModule("CharacterResolver")
	if Resolver and Resolver.IsBankConfigured then
		return Resolver.IsBankConfigured()
	end
	local key = CharacterProfiles.GetPrimaryBankKey()
	return key ~= nil and key ~= ""
end

function CharacterProfiles.CanMailToBank()
	local Resolver = Smart:GetModule("CharacterResolver")
	if Resolver and Resolver.CanMailToBank then
		return Resolver.CanMailToBank()
	end
	return CharacterProfiles.IsBankConfigured(), nil
end

function CharacterProfiles.GetPrimaryBankDisplay()
	local Resolver = Smart:GetModule("CharacterResolver")
	if Resolver and Resolver.GetPrimaryBankDisplay then
		return Resolver.GetPrimaryBankDisplay()
	end
	local key = CharacterProfiles.GetPrimaryBankKey()
	if not key then
		return nil
	end
	return key:match("^(.-)%|") or key
end

function CharacterProfiles.GetMailRecipientName()
	local Resolver = Smart:GetModule("CharacterResolver")
	if Resolver and Resolver.GetMailRecipientName then
		return Resolver.GetMailRecipientName()
	end
	local key = CharacterProfiles.GetPrimaryBankKey()
	if not key then
		return nil
	end
	local nameRealm = key:match("^(.-)%|") or key
	return nameRealm:match("^(.-)%-") or nameRealm
end

function CharacterProfiles.SameFactionAsBank()
	local bankKey = CharacterProfiles.GetPrimaryBankKey()
	if not bankKey then
		return false
	end
	local bankFaction = bankKey:match("%|(.+)$")
	return bankFaction == playerFaction()
end

function CharacterProfiles.ApplyMainDefaults(ch)
	ch = ch or CharacterProfiles.GetCurrent()
	ch.role = C.ROLES.MAIN
	ch.autoEval = true
	ch.protectConsumables = true
	ch.protectCraftingReserves = true
	ch.smartHoldToBank = true
	ch.goalEmptyBags = true
	ch.autoAhScan = false
	ch.autoMailWithoutConfirm = false
	ch.autoVendorWithoutConfirm = false
	local Resolver = Smart:GetModule("CharacterResolver")
	if Resolver and Resolver.Invalidate then
		Resolver.Invalidate()
	end
	return ch
end
