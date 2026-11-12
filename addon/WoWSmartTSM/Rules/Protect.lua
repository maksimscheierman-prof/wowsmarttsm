local Smart = WoWSmartTSM
local Protect = Smart:Module("Protect")

local BIND = {
	[1] = "BIND_ON_PICKUP", -- rough classic enums vary; we also check tooltip/API flags when present
}

---Returns protection status preventing automatic vendor.
function Protect.Evaluate(profile, db)
	local reasons = {}
	db = db or WoWSmartTSM_DB

	if profile.isBound then
		reasons[#reasons + 1] = "BOUND"
	end
	if profile.isEquipped then
		reasons[#reasons + 1] = "EQUIPPED"
	end
	if profile.isQuestItem then
		reasons[#reasons + 1] = "QUEST"
	end
	if profile.isLocked then
		reasons[#reasons + 1] = "LOCKED"
	end
	if profile.isProtectedFlag then
		reasons[#reasons + 1] = "EXPLICIT_PROTECTED"
	end
	if db and db.alwaysKeep and profile.itemString and db.alwaysKeep[profile.itemString] then
		reasons[#reasons + 1] = "ALWAYS_KEEP"
	end
	if db and db.reservedCrafting and profile.itemString and db.reservedCrafting[profile.itemString] then
		reasons[#reasons + 1] = "RESERVED_CRAFTING"
	end
	if profile.unknownIdentity then
		reasons[#reasons + 1] = "UNKNOWN_IDENTITY"
	end

	return {
		protected = #reasons > 0,
		reasons = reasons,
	}
end

function Protect.CanAutoVendor(profile, db)
	local st = Protect.Evaluate(profile, db)
	return not st.protected, st
end
