local Smart = WoWSmartTSM
local I = Smart:Module("ItemUtil")

---Normalize to a stable item identity string.
function I.GetItemString(itemLinkOrString)
	if not itemLinkOrString then
		return nil
	end
	if type(itemLinkOrString) == "string" and itemLinkOrString:match("^i:") then
		return itemLinkOrString
	end
	local id = itemLinkOrString:match("item:(%d+)")
	if id then
		return "i:" .. id
	end
	if tonumber(itemLinkOrString) then
		return "i:" .. tostring(itemLinkOrString)
	end
	return nil
end

function I.GetItemID(itemString)
	if not itemString then
		return nil
	end
	local id = tostring(itemString):match("i:(%d+)") or tostring(itemString):match("^(%d+)$")
	return id and tonumber(id) or nil
end

function I.GetBasicInfo(itemLink)
	local name, link, quality, itemLevel, reqLevel, className, subclassName, maxStack, equipSlot, texture, vendorPrice =
		GetItemInfo(itemLink)
	return {
		name = name,
		link = link,
		quality = quality,
		itemLevel = itemLevel,
		reqLevel = reqLevel,
		className = className,
		subclassName = subclassName,
		maxStack = maxStack,
		equipSlot = equipSlot,
		texture = texture,
		vendorSell = vendorPrice or 0,
	}
end

function I.IsEquipmentSlot(equipSlot)
	if not equipSlot or equipSlot == "" then
		return false
	end
	-- INVTYPE_* empty for non-equip
	return equipSlot ~= "" and equipSlot ~= "INVTYPE_NON_EQUIP_IGNORE"
end

function I.IsRecipeClass(className, subclassName, name)
	-- Prefer class metadata over name; name is fallback only
	if className then
		local lower = className:lower()
		if lower:find("recipe") or lower:find("rezept") then
			return true
		end
	end
	if subclassName then
		local lower = subclassName:lower()
		if lower:find("recipe") or lower:find("pattern") or lower:find("schematic")
			or lower:find("formula") or lower:find("plans") or lower:find("rezept") then
			return true
		end
	end
	return false
end
