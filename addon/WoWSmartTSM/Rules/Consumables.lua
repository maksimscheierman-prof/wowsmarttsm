local Smart = WoWSmartTSM
local C = Smart:Module("Constants")
local Consumables = Smart:Module("Consumables")

--[[
  v0.2.4 role-aware consumables:
  - MAIN: protect needed consumables/crafting mats; optional per-item reserve.
    Without a configured min: keep all, but do NOT spam "configure minimum" as default UX.
  - BANK: evaluate for AH/vendor by default (no silent global protect).
  - Optional per-character / per-item mins via consumableMins.
  Never silently disable an explicit protectConsumables=false override.
]]

local function store()
	WoWSmartTSM_DB = WoWSmartTSM_DB or {}
	WoWSmartTSM_DB.consumableMins = WoWSmartTSM_DB.consumableMins or {
		-- [itemString] = minQty  (global fallback)
	}
	WoWSmartTSM_DB.consumableMinsByChar = WoWSmartTSM_DB.consumableMinsByChar or {
		-- [charKey][itemString] = minQty
	}
	return WoWSmartTSM_DB.consumableMins
end

local function charStore(charKey)
	store()
	local by = WoWSmartTSM_DB.consumableMinsByChar
	if charKey then
		by[charKey] = by[charKey] or {}
		return by[charKey]
	end
	return nil
end

local CONSUMABLE_CLASS_HINTS = {
	consumable = true,
	verbrauchsgut = true,
	food = true,
	trinken = true,
	potion = true,
	trank = true,
	flask = true,
	elixier = true,
	bandage = true,
	scroll = true,
}

function Consumables.IsLikelyConsumable(profile)
	if profile.isConsumable == true then
		return true
	end
	local class = (profile.className or ""):lower()
	local sub = (profile.subclassName or ""):lower()
	local name = (profile.name or ""):lower()
	for hint in pairs(CONSUMABLE_CLASS_HINTS) do
		if class:find(hint, 1, true) or sub:find(hint, 1, true) or name:find(hint, 1, true) then
			return true
		end
	end
	return false
end

function Consumables.GetMinQty(itemString, charKey)
	if not itemString then
		return nil
	end
	if charKey then
		local cs = charStore(charKey)
		if cs and cs[itemString] ~= nil then
			return cs[itemString]
		end
	end
	return store()[itemString]
end

function Consumables.SetMinQty(itemString, minQty, charKey)
	if not itemString then
		return false
	end
	local target = charKey and charStore(charKey) or store()
	if minQty == nil then
		target[itemString] = nil
	else
		target[itemString] = math.max(0, tonumber(minQty) or 0)
	end
	return true
end

---Returns keepQty, surplusQty, needsConfig, protectAll
---needsConfig is only true when player explicitly opted into "require min config" (legacy flag).
function Consumables.SplitQuantity(profile, quantity)
	quantity = quantity or 1
	local ch = Smart:GetModule("CharacterProfiles")
	local cur = ch and ch.GetCurrent and ch.GetCurrent() or nil
	local role = ch and ch.GetRole and ch.GetRole() or C.ROLES.MAIN
	local charKey = cur and (cur.key or cur.name) or nil

	-- Explicit per-character opt-out
	if cur and cur.protectConsumables == false then
		return 0, quantity, false, false
	end
	if not Consumables.IsLikelyConsumable(profile) then
		return 0, quantity, false, false
	end

	-- BANK: sell/evaluate surplus by default (AH path); no blanket protect
	if role == C.ROLES.BANK then
		local minQ = Consumables.GetMinQty(profile.itemString, charKey)
		if minQ == nil then
			return 0, quantity, false, false
		end
		local keep = math.min(quantity, minQ)
		local surplus = math.max(0, quantity - keep)
		return keep, surplus, false, false
	end

	-- MANUAL: treat like MAIN keep guidance but decisions stay non-auto elsewhere
	local minQ = Consumables.GetMinQty(profile.itemString, charKey)
	if minQ == nil then
		-- MAIN default: protect all without "configure minimum" nag (needsConfig=false)
		return quantity, 0, false, true
	end
	local keep = math.min(quantity, minQ)
	local surplus = math.max(0, quantity - keep)
	return keep, surplus, false, false
end
