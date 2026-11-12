local Smart = WoWSmartTSM
local C = Smart:Module("Constants")
local CharacterResolver = Smart:Module("CharacterResolver")

--[[
  Single source of truth for character identity, role, and bank recipient checks.
  ActionDecide / UI / Mail must not rebuild keys differently.
]]

local private = {
	cache = nil,
	cacheAt = 0,
}

local function trim(s)
	return (tostring(s or ""):match("^%s*(.-)%s*$")) or ""
end

local function collapseSpaces(s)
	return trim(tostring(s or ""):gsub("%s+", " "))
end

local function liveRealm()
	return collapseSpaces(GetRealmName and GetRealmName() or "UnknownRealm")
end

local function liveName()
	return trim(UnitName and UnitName("player") or "Unknown")
end

local function liveFaction()
	return trim(UnitFactionGroup and UnitFactionGroup("player") or "Unknown")
end

---Canonical key: Name-Realm|Faction (collapsed whitespace).
function CharacterResolver.MakeKey(name, realm, faction)
	name = trim(name or liveName())
	realm = collapseSpaces(realm or liveRealm())
	faction = trim(faction or liveFaction())
	return string.format("%s-%s|%s", name, realm, faction)
end

function CharacterResolver.NormalizeKey(key)
	if not key or key == "" then
		return nil
	end
	key = tostring(key)
	local nameRealm, faction = key:match("^(.-)|(.+)$")
	if not nameRealm then
		nameRealm, faction = key, "Unknown"
	end
	local name, realm = nameRealm:match("^(.-)%-(.+)$")
	if not name then
		name, realm = nameRealm, "UnknownRealm"
	end
	return CharacterResolver.MakeKey(name, realm, faction)
end

function CharacterResolver.KeysEqual(a, b)
	local na = CharacterResolver.NormalizeKey(a)
	local nb = CharacterResolver.NormalizeKey(b)
	return na ~= nil and nb ~= nil and na == nb
end

function CharacterResolver.ParseKey(key)
	key = CharacterResolver.NormalizeKey(key)
	if not key then
		return nil
	end
	local nameRealm, faction = key:match("^(.-)|(.+)$")
	local name, realm = nameRealm:match("^(.-)%-(.+)$")
	return {
		key = key,
		name = name,
		realm = realm,
		faction = faction,
		nameRealm = nameRealm,
	}
end

function CharacterResolver.Invalidate()
	private.cache = nil
	private.cacheAt = 0
end

local function ensureStore()
	WoWSmartTSM_DB = WoWSmartTSM_DB or {}
	WoWSmartTSM_DB.characters = WoWSmartTSM_DB.characters or {}
	WoWSmartTSM_DB.profile = WoWSmartTSM_DB.profile or { primaryBankKey = nil, bankKeys = {} }
	return WoWSmartTSM_DB
end

---Find stored character matching key with normalization (handles realm spacing drift).
function CharacterResolver.FindCharacter(key)
	local db = ensureStore()
	local norm = CharacterResolver.NormalizeKey(key)
	if not norm then
		return nil, nil
	end
	if db.characters[norm] then
		return db.characters[norm], norm
	end
	if db.characters[key] then
		return db.characters[key], key
	end
	for k, ch in pairs(db.characters) do
		if CharacterResolver.KeysEqual(k, norm) then
			return ch, k
		end
	end
	return nil, nil
end

function CharacterResolver.GetCurrentKey()
	return CharacterResolver.MakeKey()
end

function CharacterResolver.GetPrimaryBankKey()
	local db = ensureStore()
	local raw = db.profile and db.profile.primaryBankKey
	return CharacterResolver.NormalizeKey(raw) or raw
end

---Effective inventory role. Primary-bank login always acts as BANK for decisions.
function CharacterResolver.GetEffectiveRole(key)
	key = key or CharacterResolver.GetCurrentKey()
	local ch = CharacterResolver.FindCharacter(key)
	local stored = (ch and ch.role) or C.ROLES.MAIN
	local bankKey = CharacterResolver.GetPrimaryBankKey()
	local resolved = stored
	local why = "STORED_ROLE"
	if bankKey and CharacterResolver.KeysEqual(bankKey, key) then
		resolved = C.ROLES.BANK
		why = (stored == C.ROLES.BANK) and "BANK_ROLE" or "PRIMARY_BANK_LOGIN"
	end
	-- Do not log per-item; callers log Snapshot / NotifyProfileChanged.
	return resolved, why, stored
end

---Can MAIN mail items to the configured bank character?
function CharacterResolver.CanMailToBank()
	local bankKey = CharacterResolver.GetPrimaryBankKey()
	if not bankKey or bankKey == "" then
		return false, "BANK_CHARACTER_NOT_CONFIGURED"
	end
	local cur = CharacterResolver.GetCurrentKey()
	if CharacterResolver.KeysEqual(bankKey, cur) then
		return false, "BANK_IS_SELF"
	end
	local bank = CharacterResolver.ParseKey(bankKey)
	if bank and bank.faction and bank.faction ~= liveFaction() and bank.faction ~= "Unknown" then
		return false, "BANK_FACTION_MISMATCH"
	end
	return true, nil
end

function CharacterResolver.IsBankConfigured()
	local key = CharacterResolver.GetPrimaryBankKey()
	return key ~= nil and key ~= ""
end

function CharacterResolver.GetMailRecipientName()
	local bank = CharacterResolver.ParseKey(CharacterResolver.GetPrimaryBankKey())
	return bank and bank.name or nil
end

function CharacterResolver.GetPrimaryBankDisplay()
	local bank = CharacterResolver.ParseKey(CharacterResolver.GetPrimaryBankKey())
	if not bank then
		return nil
	end
	return bank.nameRealm or bank.key
end

---After role/bank changes: invalidate, optional reeval, UI refresh hook.
function CharacterResolver.NotifyProfileChanged(reason)
	CharacterResolver.Invalidate()
	local Logger = Smart:GetModule("Logger")
	if Logger and Logger.Info then
		Logger.Info("UNKNOWN", "CharacterResolver", "NotifyProfileChanged", tostring(reason or "profile_changed"))
	end
	local ScanService = Smart:GetModule("ScanService")
	if ScanService and ScanService.ReevaluateBags then
		ScanService.ReevaluateBags({ reason = reason or "profile_changed" })
	end
end

function CharacterResolver.Snapshot()
	local role, why, stored = CharacterResolver.GetEffectiveRole()
	local mailOk, mailCode = CharacterResolver.CanMailToBank()
	return {
		currentKey = CharacterResolver.GetCurrentKey(),
		role = role,
		roleWhy = why,
		storedRole = stored,
		bankKey = CharacterResolver.GetPrimaryBankKey(),
		bankDisplay = CharacterResolver.GetPrimaryBankDisplay(),
		bankConfigured = CharacterResolver.IsBankConfigured(),
		canMailToBank = mailOk,
		mailBlockCode = mailCode,
	}
end
