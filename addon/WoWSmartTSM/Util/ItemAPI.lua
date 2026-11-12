local Smart = WoWSmartTSM
local Logger = Smart:Module("Logger")
local ItemAPI = Smart:Module("ItemAPI")

--[[
  Forever-compatible item/bag adapters.

  Evidence (TSM Forever v4.15.6 LibTSMWoW API.Item / API.Container):
    C_Item.GetItemInfo / C_Item.GetItemInfoInstant — VERIFIED (TSM uses these on Forever)
    C_Container.GetContainerItemInfo — VERIFIED
    Global GetItemInfo — UNSUPPORTED / nil on Forever 1.60.1 build 70888 (ingame crash)
]]

local private = {
	probed = false,
	caps = nil,
	pendingIds = {},
	listener = nil,
	onPendingResolved = nil,
}

local function safeCall(fn, ...)
	if type(fn) ~= "function" then
		return false
	end
	return pcall(fn, ...)
end

function ItemAPI.ProbeCapabilities()
	if private.probed and private.caps then
		return private.caps
	end
	local caps = {
		cItemGetItemInfo = (C_Item and type(C_Item.GetItemInfo) == "function") and "VERIFIED" or "UNSUPPORTED",
		cItemGetItemInfoInstant = (C_Item and type(C_Item.GetItemInfoInstant) == "function") and "VERIFIED" or "UNSUPPORTED",
		cItemRequestLoad = (C_Item and type(C_Item.RequestLoadItemDataByID) == "function") and "VERIFIED"
			or ((C_Item and type(C_Item.RequestLoadItemData) == "function") and "PARTIAL" or "UNSUPPORTED"),
		getItemInfo = (type(GetItemInfo) == "function") and "PARTIAL" or "UNSUPPORTED",
		getItemInfoInstant = (type(GetItemInfoInstant) == "function") and "PARTIAL" or "UNSUPPORTED",
		cContainerNumSlots = (C_Container and type(C_Container.GetContainerNumSlots) == "function") and "VERIFIED" or "UNSUPPORTED",
		cContainerItemInfo = (C_Container and type(C_Container.GetContainerItemInfo) == "function") and "VERIFIED" or "UNSUPPORTED",
		cContainerItemLink = (C_Container and type(C_Container.GetContainerItemLink) == "function") and "VERIFIED" or "UNSUPPORTED",
		getContainerNumSlots = (type(GetContainerNumSlots) == "function") and "PARTIAL" or "UNSUPPORTED",
		getContainerItemInfo = (type(GetContainerItemInfo) == "function") and "PARTIAL" or "UNSUPPORTED",
		getContainerItemLink = (type(GetContainerItemLink) == "function") and "PARTIAL" or "UNSUPPORTED",
		getItemInfoReceived = "PARTIAL", -- event may exist; handler installed defensively
		preferredInfoAPI = nil,
		preferredBagAPI = nil,
	}
	if caps.cItemGetItemInfo == "VERIFIED" then
		caps.preferredInfoAPI = "C_Item.GetItemInfo"
	elseif caps.getItemInfo == "PARTIAL" then
		caps.preferredInfoAPI = "GetItemInfo"
	else
		caps.preferredInfoAPI = "NONE"
	end
	if caps.cContainerItemInfo == "VERIFIED" then
		caps.preferredBagAPI = "C_Container"
	elseif caps.getContainerItemInfo == "PARTIAL" or caps.getContainerItemLink == "PARTIAL" then
		caps.preferredBagAPI = "legacy"
	else
		caps.preferredBagAPI = "NONE"
	end
	private.caps = caps
	private.probed = true
	return caps
end

local function parseLinkName(link)
	if type(link) ~= "string" then
		return nil
	end
	-- |Hitem:...|h[Name]|h
	local name = link:match("%[(.-)%]")
	return name
end

local function packFromClassicReturns(name, link, quality, itemLevel, minLevel, className, subclassName, maxStack, equipSlot, texture, vendorSell)
	if not name and not link and quality == nil then
		return nil
	end
	return {
		name = name or parseLinkName(link),
		link = link,
		quality = quality,
		itemLevel = itemLevel,
		minLevel = minLevel,
		className = className,
		subclassName = subclassName,
		maxStack = maxStack,
		equipSlot = equipSlot,
		texture = texture,
		vendorSell = vendorSell or 0,
		complete = name ~= nil and quality ~= nil,
		source = "classic_tuple",
	}
end

---Request async item data load when APIs exist.
function ItemAPI.RequestLoad(itemOrId)
	local id = tonumber(itemOrId)
	if not id and type(itemOrId) == "string" then
		id = tonumber(itemOrId:match("item:(%d+)")) or tonumber(itemOrId:match("^i:(%d+)"))
	end
	if not id then
		return false
	end
	private.pendingIds[id] = true
	if C_Item and C_Item.RequestLoadItemDataByID then
		local ok = safeCall(C_Item.RequestLoadItemDataByID, id)
		return ok and true or false
	end
	if C_Item and C_Item.RequestLoadItemData then
		-- Some builds take an ItemLocation; skip if we only have an id
		return false
	end
	-- Touching GetItemInfo / C_Item.GetItemInfo often queues a load
	if C_Item and C_Item.GetItemInfo then
		safeCall(C_Item.GetItemInfo, id)
		return true
	end
	if type(GetItemInfo) == "function" then
		safeCall(GetItemInfo, id)
		return true
	end
	return false
end

---Instant fields (ids / class strings) when available.
function ItemAPI.GetInfoInstant(item)
	local id = tonumber(item)
	if not id and type(item) == "string" then
		id = tonumber(item:match("item:(%d+)")) or tonumber(item:match("^i:(%d+)")) or tonumber(item:match("^(%d+)$"))
	end
	if not id then
		return nil
	end
	if C_Item and type(C_Item.GetItemInfoInstant) == "function" then
		local ok, a, b, c, d, e, f, g = pcall(C_Item.GetItemInfoInstant, id)
		if ok and (a or e or f) then
			-- Retail/Forever: itemID?, itemType, itemSubType, itemEquipLoc, icon, classID, subClassID
			-- TSM ignores first and uses classStr, subClassStr, equipSlot, texture, classId, subClassId
			return {
				itemId = id,
				className = b,
				subclassName = c,
				equipSlot = d,
				texture = e,
				classId = f,
				subClassId = g,
				source = "C_Item.GetItemInfoInstant",
			}
		end
	end
	if type(GetItemInfoInstant) == "function" then
		local ok, a, b, c, d, e, f, g = pcall(GetItemInfoInstant, id)
		if ok and (a or e or f) then
			return {
				itemId = id,
				className = b,
				subclassName = c,
				equipSlot = d,
				texture = e,
				classId = f,
				subClassId = g,
				source = "GetItemInfoInstant",
			}
		end
	end
	return nil
end

---Full item info. Never throws. May return incomplete stub + pending=true.
function ItemAPI.GetInfo(item)
	if item == nil then
		return nil, "NO_ITEM"
	end
	ItemAPI.ProbeCapabilities()

	local info = nil
	if C_Item and type(C_Item.GetItemInfo) == "function" then
		local ok, name, link, quality, itemLevel, minLevel, className, subclassName, maxStack, equipSlot, texture, vendorSell =
			pcall(C_Item.GetItemInfo, item)
		if ok then
			info = packFromClassicReturns(name, link, quality, itemLevel, minLevel, className, subclassName, maxStack, equipSlot, texture, vendorSell)
			if info then
				info.source = "C_Item.GetItemInfo"
			end
		end
	end
	if not info and type(GetItemInfo) == "function" then
		local ok, name, link, quality, itemLevel, minLevel, className, subclassName, maxStack, equipSlot, texture, vendorSell =
			pcall(GetItemInfo, item)
		if ok then
			info = packFromClassicReturns(name, link, quality, itemLevel, minLevel, className, subclassName, maxStack, equipSlot, texture, vendorSell)
			if info then
				info.source = "GetItemInfo"
			end
		end
	end

	local instant = ItemAPI.GetInfoInstant(item)
	if not info then
		-- Incomplete: synthesize from link + instant
		local link = type(item) == "string" and item:find("|H") and item or nil
		info = {
			name = parseLinkName(link),
			link = link,
			quality = nil,
			itemLevel = nil,
			minLevel = nil,
			className = instant and instant.className or nil,
			subclassName = instant and instant.subclassName or nil,
			maxStack = nil,
			equipSlot = instant and instant.equipSlot or nil,
			texture = instant and instant.texture or nil,
			vendorSell = 0,
			complete = false,
			pending = true,
			source = instant and instant.source or "none",
		}
		ItemAPI.RequestLoad(item)
		return info, "PENDING"
	end

	-- Merge instant class fields if full info omitted them
	if instant then
		info.className = info.className or instant.className
		info.subclassName = info.subclassName or instant.subclassName
		info.equipSlot = info.equipSlot or instant.equipSlot
		info.texture = info.texture or instant.texture
		info.classId = instant.classId
		info.subClassId = instant.subClassId
	end

	if not info.complete then
		info.pending = true
		ItemAPI.RequestLoad(item)
		return info, "INCOMPLETE"
	end
	info.pending = false
	return info, nil
end

function ItemAPI.GetBagNumSlots(bag)
	if C_Container and type(C_Container.GetContainerNumSlots) == "function" then
		local ok, n = pcall(C_Container.GetContainerNumSlots, bag)
		if ok and type(n) == "number" then
			return n
		end
	end
	if type(GetContainerNumSlots) == "function" then
		local ok, n = pcall(GetContainerNumSlots, bag)
		if ok and type(n) == "number" then
			return n
		end
	end
	return 0
end

---Returns link, count, quality, itemId, isBound (best-effort). Never throws.
function ItemAPI.GetBagSlot(bag, slot)
	if C_Container and type(C_Container.GetContainerItemInfo) == "function" then
		local ok, info = pcall(C_Container.GetContainerItemInfo, bag, slot)
		if ok and type(info) == "table" then
			return {
				link = info.hyperlink or info.itemLink,
				count = info.stackCount or 1,
				quality = info.quality,
				itemId = info.itemID,
				isBound = info.isBound and true or false,
				icon = info.iconFileID,
				source = "C_Container.GetContainerItemInfo",
			}
		end
	end

	local link = nil
	if C_Container and type(C_Container.GetContainerItemLink) == "function" then
		local ok, l = pcall(C_Container.GetContainerItemLink, bag, slot)
		if ok then
			link = l
		end
	elseif type(GetContainerItemLink) == "function" then
		local ok, l = pcall(GetContainerItemLink, bag, slot)
		if ok then
			link = l
		end
	end

	local count, quality, locked = 1, nil, nil
	if type(GetContainerItemInfo) == "function" then
		local ok, texture, itemCount, isLocked, qualityOrNil = pcall(GetContainerItemInfo, bag, slot)
		if ok then
			count = itemCount or 1
			locked = isLocked
			quality = qualityOrNil
			if not link and type(texture) == "string" and texture:find("|H") then
				link = texture
			end
		end
	end

	if not link then
		return nil
	end
	local itemId = tonumber(link:match("item:(%d+)"))
	return {
		link = link,
		count = count or 1,
		quality = quality,
		itemId = itemId,
		isBound = false,
		isLocked = locked and true or false,
		source = "legacy_container",
	}
end

function ItemAPI.SetPendingResolvedHandler(fn)
	private.onPendingResolved = fn
end

function ItemAPI.Init()
	ItemAPI.ProbeCapabilities()
	if private.listener then
		return private.caps
	end
	local f = CreateFrame("Frame", "WoWSmartTSMItemAPIFrame")
	private.listener = f
	f:RegisterEvent("GET_ITEM_INFO_RECEIVED")
	f:SetScript("OnEvent", function(_, event, itemId, success)
		if event ~= "GET_ITEM_INFO_RECEIVED" then
			return
		end
		itemId = tonumber(itemId)
		if not itemId then
			return
		end
		if private.pendingIds[itemId] then
			private.pendingIds[itemId] = nil
		end
		if success and private.onPendingResolved then
			pcall(private.onPendingResolved, itemId)
		end
	end)
	Logger.Info("UNKNOWN", "ItemAPI", "Init", string.format(
		"Item API probe: info=%s bag=%s GetItemInfo=%s",
		tostring(private.caps.preferredInfoAPI),
		tostring(private.caps.preferredBagAPI),
		tostring(private.caps.getItemInfo)
	))
	return private.caps
end

function ItemAPI.GetCapabilities()
	return ItemAPI.ProbeCapabilities()
end

function ItemAPI.HasPending()
	return next(private.pendingIds) ~= nil
end
