local Smart = WoWSmartTSM
local Consumables = Smart:Module("Consumables")

--[[
  protectConsumables=true: keep configured minimum on MAIN; surplus may MAIL_TO_BANK.
  Conservative: unknown consumables with no min qty → protect all (KEEP) + flag needsConfig.
]]

local function store()
	WoWSmartTSM_DB = WoWSmartTSM_DB or {}
	WoWSmartTSM_DB.consumableMins = WoWSmartTSM_DB.consumableMins or {
		-- [itemString] = minQty
	}
	return WoWSmartTSM_DB.consumableMins
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

function Consumables.GetMinQty(itemString)
	if not itemString then
		return nil
	end
	return store()[itemString]
end

function Consumables.SetMinQty(itemString, minQty)
	if not itemString then
		return false
	end
	if minQty == nil then
		store()[itemString] = nil
	else
		store()[itemString] = math.max(0, tonumber(minQty) or 0)
	end
	return true
end

---Returns keepQty, surplusQty, needsConfig, protectAll
function Consumables.SplitQuantity(profile, quantity)
	quantity = quantity or 1
	local ch = Smart:GetModule("CharacterProfiles")
	local cur = ch and ch.GetCurrent and ch.GetCurrent() or nil
	if cur and cur.protectConsumables == false then
		return 0, quantity, false, false
	end
	if not Consumables.IsLikelyConsumable(profile) then
		return 0, quantity, false, false
	end
	local minQ = Consumables.GetMinQty(profile.itemString)
	if minQ == nil then
		-- Conservative: protect all until player sets a minimum
		return quantity, 0, true, true
	end
	local keep = math.min(quantity, minQ)
	local surplus = math.max(0, quantity - keep)
	return keep, surplus, false, false
end
