local Smart = WoWSmartTSM
local C = Smart:Module("Constants")
local ItemRules = Smart:Module("ItemRules")

--[[
  Persistent keep/ignore/min-qty rules.
  Scopes: once (session), character, account
]]

local function store()
	WoWSmartTSM_DB = WoWSmartTSM_DB or {}
	WoWSmartTSM_DB.itemRules = WoWSmartTSM_DB.itemRules or {
		account = {}, -- [itemString] = rule
		characters = {}, -- [charKey][itemString] = rule
		sessionIgnore = {}, -- [itemString] = true (once)
	}
	return WoWSmartTSM_DB.itemRules
end

local function charKey()
	local CP = Smart:GetModule("CharacterProfiles")
	return CP and CP.GetCurrentKey and CP.GetCurrentKey() or "unknown"
end

---rule = { type=KEEP|IGNORE|MIN_KEEP, minQty=n, note=..., permanent=true }
function ItemRules.GetEffective(itemString)
	if not itemString then
		return nil
	end
	local s = store()
	if s.sessionIgnore[itemString] then
		return { type = "IGNORE", scope = "once", permanent = false }
	end
	local ck = charKey()
	s.characters[ck] = s.characters[ck] or {}
	local ch = s.characters[ck][itemString]
	if ch then
		ch.scope = "character"
		return ch
	end
	local acc = s.account[itemString]
	if acc then
		acc.scope = "account"
		return acc
	end
	-- legacy alwaysKeep
	if WoWSmartTSM_DB.alwaysKeep and WoWSmartTSM_DB.alwaysKeep[itemString] then
		return { type = "KEEP", scope = "character", permanent = true, legacy = true }
	end
	return nil
end

function ItemRules.Set(itemString, rule, scope)
	if not itemString or not rule then
		return false
	end
	scope = scope or "character"
	local s = store()
	rule.permanent = scope ~= "once"
	if scope == "once" then
		s.sessionIgnore[itemString] = true
		return true
	end
	if scope == "account" then
		s.account[itemString] = rule
		return true
	end
	local ck = charKey()
	s.characters[ck] = s.characters[ck] or {}
	s.characters[ck][itemString] = rule
	return true
end

function ItemRules.Clear(itemString, scope)
	if not itemString then
		return false
	end
	local s = store()
	if scope == "once" or not scope then
		s.sessionIgnore[itemString] = nil
	end
	if scope == "account" or not scope then
		s.account[itemString] = nil
	end
	if scope == "character" or not scope then
		local ck = charKey()
		if s.characters[ck] then
			s.characters[ck][itemString] = nil
		end
		if WoWSmartTSM_DB.alwaysKeep then
			WoWSmartTSM_DB.alwaysKeep[itemString] = nil
		end
	end
	return true
end

function ItemRules.ListAll()
	local s = store()
	local out = {}
	for itemString, rule in pairs(s.account) do
		out[#out + 1] = { itemString = itemString, rule = rule, scope = "account" }
	end
	local ck = charKey()
	for itemString, rule in pairs(s.characters[ck] or {}) do
		out[#out + 1] = { itemString = itemString, rule = rule, scope = "character" }
	end
	for itemString in pairs(s.sessionIgnore) do
		out[#out + 1] = { itemString = itemString, rule = { type = "IGNORE" }, scope = "once" }
	end
	return out
end

function ItemRules.AppliesKeep(itemString, quantity)
	local r = ItemRules.GetEffective(itemString)
	if not r then
		return false, 0
	end
	if r.type == "KEEP" then
		return true, quantity or 0
	end
	if r.type == "MIN_KEEP" then
		local minQ = r.minQty or 0
		local q = quantity or 0
		if q <= minQ then
			return true, q
		end
		return false, minQ -- keep minQ, surplus may sell
	end
	return false, 0
end

function ItemRules.AppliesIgnore(itemString)
	local r = ItemRules.GetEffective(itemString)
	return r and r.type == "IGNORE"
end
