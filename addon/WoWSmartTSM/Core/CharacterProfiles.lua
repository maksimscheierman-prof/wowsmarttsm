local Smart = WoWSmartTSM
local C = Smart:Module("Constants")
local Logger = Smart:Module("Logger")
local CharacterProfiles = Smart:Module("CharacterProfiles")

local private = {
	currentKey = nil,
}

local function realmName()
	local r = GetRealmName and GetRealmName() or "UnknownRealm"
	return tostring(r)
end

local function playerName()
	local n = UnitName and UnitName("player") or "Unknown"
	return tostring(n)
end

local function playerFaction()
	local f = UnitFactionGroup and UnitFactionGroup("player") or "Unknown"
	return tostring(f)
end

---Stable character key: Name-Realm|Faction
function CharacterProfiles.MakeKey(name, realm, faction)
	name = name or playerName()
	realm = realm or realmName()
	faction = faction or playerFaction()
	return string.format("%s-%s|%s", name, realm, faction)
end

function CharacterProfiles.GetCurrentKey()
	private.currentKey = CharacterProfiles.MakeKey()
	return private.currentKey
end

local function ensureStore()
	WoWSmartTSM_DB = WoWSmartTSM_DB or {}
	WoWSmartTSM_DB.characters = WoWSmartTSM_DB.characters or {}
	WoWSmartTSM_DB.profile = WoWSmartTSM_DB.profile or {
		primaryBankKey = nil,
		bankKeys = {},
	}
	return WoWSmartTSM_DB
end

local function defaultChar(key)
	return {
		key = key,
		name = playerName(),
		realm = realmName(),
		faction = playerFaction(),
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
	if not db.characters[key] then
		db.characters[key] = defaultChar(key)
		Logger.Info("UNKNOWN", "CharacterProfiles", "EnsureCurrent", "Created profile for " .. key)
	else
		-- refresh identity fields
		local ch = db.characters[key]
		ch.name = playerName()
		ch.realm = realmName()
		ch.faction = playerFaction()
		ch.key = key
	end
	return db.characters[key]
end

function CharacterProfiles.Get(key)
	local db = ensureStore()
	key = key or CharacterProfiles.GetCurrentKey()
	return db.characters[key]
end

function CharacterProfiles.GetCurrent()
	return CharacterProfiles.EnsureCurrent()
end

function CharacterProfiles.GetRole(key)
	local ch = CharacterProfiles.Get(key)
	return (ch and ch.role) or C.ROLES.MAIN
end

function CharacterProfiles.SetRole(key, role)
	local db = ensureStore()
	key = key or CharacterProfiles.GetCurrentKey()
	if not db.characters[key] then
		db.characters[key] = defaultChar(key)
	end
	if role ~= C.ROLES.MAIN and role ~= C.ROLES.BANK and role ~= C.ROLES.MANUAL then
		Logger.Error("CHAR_CONFIG_INVALID", "CharacterProfiles", "SetRole", "Invalid role " .. tostring(role))
		return false
	end
	db.characters[key].role = role
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
	local db = ensureStore()
	return db.profile.primaryBankKey
end

function CharacterProfiles.SetPrimaryBankKey(key)
	local db = ensureStore()
	if key == nil or key == "" then
		db.profile.primaryBankKey = nil
		return true
	end
	-- Allow setting a bank key even if that character hasn't logged in yet (typed name-realm|faction)
	db.profile.primaryBankKey = key
	db.profile.bankKeys = db.profile.bankKeys or {}
	db.profile.bankKeys[key] = true
	if db.characters[key] then
		db.characters[key].role = C.ROLES.BANK
	end
	Logger.Info("UNKNOWN", "CharacterProfiles", "SetPrimaryBankKey", "Primary bank=" .. tostring(key))
	return true
end

function CharacterProfiles.IsBankConfigured()
	local key = CharacterProfiles.GetPrimaryBankKey()
	return key ~= nil and key ~= ""
end

function CharacterProfiles.GetPrimaryBankDisplay()
	local key = CharacterProfiles.GetPrimaryBankKey()
	if not key then
		return nil
	end
	local name = key:match("^(.-)%|") or key
	return name
end

---Mail recipient name only (Name part before -Realm)
function CharacterProfiles.GetMailRecipientName()
	local key = CharacterProfiles.GetPrimaryBankKey()
	if not key then
		return nil
	end
	-- key = Name-Realm|Faction
	local nameRealm = key:match("^(.-)%|") or key
	local name = nameRealm:match("^(.-)%-") or nameRealm
	return name
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
	return ch
end
