local Smart = WoWSmartTSM
local CraftingReserve = Smart:Module("CraftingReserve")

local function store()
	WoWSmartTSM_DB = WoWSmartTSM_DB or {}
	WoWSmartTSM_DB.craftingReserves = WoWSmartTSM_DB.craftingReserves or {
		-- [charKey][itemString] = { minQty=n, always=bool, note= }
	}
	-- legacy
	WoWSmartTSM_DB.reservedCrafting = WoWSmartTSM_DB.reservedCrafting or {}
	return WoWSmartTSM_DB.craftingReserves
end

local function charKey()
	local CP = Smart:GetModule("CharacterProfiles")
	return CP and CP.GetCurrentKey and CP.GetCurrentKey() or "unknown"
end

function CraftingReserve.Get(itemString, key)
	key = key or charKey()
	local s = store()
	s[key] = s[key] or {}
	local r = s[key][itemString]
	if r then
		return r
	end
	if WoWSmartTSM_DB.reservedCrafting and WoWSmartTSM_DB.reservedCrafting[itemString] then
		return { minQty = nil, always = true, legacy = true }
	end
	return nil
end

function CraftingReserve.Set(itemString, rule, key)
	if not itemString then
		return false
	end
	key = key or charKey()
	local s = store()
	s[key] = s[key] or {}
	s[key][itemString] = rule
	return true
end

function CraftingReserve.Clear(itemString, key)
	key = key or charKey()
	local s = store()
	if s[key] then
		s[key][itemString] = nil
	end
	if WoWSmartTSM_DB.reservedCrafting then
		WoWSmartTSM_DB.reservedCrafting[itemString] = nil
	end
	return true
end

---keepQty, surplusQty
function CraftingReserve.SplitQuantity(profile, quantity)
	quantity = quantity or 1
	local ch = Smart:GetModule("CharacterProfiles")
	local cur = ch and ch.GetCurrent and ch.GetCurrent() or nil
	if cur and cur.protectCraftingReserves == false then
		return 0, quantity
	end
	local r = CraftingReserve.Get(profile.itemString)
	if not r then
		return 0, quantity
	end
	if r.always then
		return quantity, 0
	end
	local minQ = r.minQty or 0
	local keep = math.min(quantity, minQ)
	return keep, math.max(0, quantity - keep)
end
