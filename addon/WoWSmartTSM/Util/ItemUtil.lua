local Smart = WoWSmartTSM
local ItemAPI = Smart:Module("ItemAPI")
local I = Smart:Module("ItemUtil")

---Normalize to a stable item identity string.
function I.GetItemString(itemLinkOrString)
	if not itemLinkOrString then
		return nil
	end
	if type(itemLinkOrString) == "string" and itemLinkOrString:match("^i:") then
		return itemLinkOrString
	end
	local id = tostring(itemLinkOrString):match("item:(%d+)")
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

---Forever-safe basic info (delegates to ItemAPI). Never calls bare GetItemInfo.
function I.GetBasicInfo(itemLink)
	local info = ItemAPI.GetInfo(itemLink)
	if not info then
		return {
			name = nil,
			link = itemLink,
			quality = nil,
			itemLevel = nil,
			reqLevel = nil,
			className = nil,
			subclassName = nil,
			maxStack = nil,
			equipSlot = nil,
			texture = nil,
			vendorSell = 0,
			complete = false,
			pending = true,
		}
	end
	return {
		name = info.name,
		link = info.link or itemLink,
		quality = info.quality,
		itemLevel = info.itemLevel,
		reqLevel = info.minLevel,
		className = info.className,
		subclassName = info.subclassName,
		maxStack = info.maxStack,
		equipSlot = info.equipSlot,
		texture = info.texture,
		vendorSell = info.vendorSell or 0,
		complete = info.complete and true or false,
		pending = info.pending and true or false,
		source = info.source,
	}
end

function I.IsEquipmentSlot(equipSlot)
	if not equipSlot or equipSlot == "" then
		return false
	end
	return equipSlot ~= "" and equipSlot ~= "INVTYPE_NON_EQUIP_IGNORE"
end

function I.IsRecipeClass(className, subclassName, name)
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
