local Smart = WoWSmartTSM
local C = Smart:Module("Constants")
local Logger = Smart:Module("Logger")
local Groups = Smart:Module("Groups")

--[[
  TSM v4.15.6 App/API.lua (VERIFIED read surface):
    GetGroupPaths, FormatGroupPath, SplitGroupPath,
    GetGroupPathByItem, GetGroupItems, RegisterGroupItemCallback
  Write APIs (CreateGroup / SetGroup / MoveItem): NOT in public TSM_API.
  Safe apply path = TSM Groups Import string (group:path,item list format).
]]

local SMART_GROUPS = {
	C.GROUPS.QUICK,
	C.GROUPS.PROFIT,
	C.GROUPS.RARE,
	C.GROUPS.VENDOR,
	C.GROUPS.HOLD,
	C.GROUPS.REVIEW,
	C.GROUPS.IGNORE,
}

local private = {
	writeProbe = nil,
	lastImportString = nil,
	groupCallbackRegistered = false,
}

local function tsmGroupApi()
	return TSM_API
end

function Groups.ProbeCapabilities()
	if private.writeProbe then
		return private.writeProbe
	end
	local api = tsmGroupApi()
	local cap = {
		apiPresent = api ~= nil,
		getPaths = api and type(api.GetGroupPaths) == "function" or false,
		getPathByItem = api and type(api.GetGroupPathByItem) == "function" or false,
		getItems = api and type(api.GetGroupItems) == "function" or false,
		registerCallback = api and type(api.RegisterGroupItemCallback) == "function" or false,
		createGroup = api and type(api.CreateGroup) == "function" or false,
		setGroup = api and (type(api.SetGroup) == "function" or type(api.MoveItem) == "function" or type(api.SetItemGroup) == "function") or false,
		writeMode = "IMPORT_STRING", -- default safe path for 4.15.6
		claim = "VERIFIED_READ_PARTIAL_WRITE",
	}
	if cap.createGroup and cap.setGroup then
		cap.writeMode = "DIRECT_API"
		cap.claim = "WRITE_API_DETECTED"
	elseif cap.setGroup then
		cap.writeMode = "DIRECT_MOVE_ONLY"
		cap.claim = "PARTIAL_WRITE_API"
	else
		cap.writeMode = "IMPORT_STRING"
		cap.claim = "VERIFIED_READ_IMPORT_WRITE"
	end
	private.writeProbe = cap
	return cap
end

function Groups.GetPathByItem(itemString)
	local api = tsmGroupApi()
	if not api then
		return nil
	end
	if api.GetGroupPathByItem then
		local ok, path = pcall(api.GetGroupPathByItem, itemString)
		if ok and path and path ~= "" then
			return path
		end
	end
	return nil
end

function Groups.ListPaths()
	local api = tsmGroupApi()
	local result = {}
	if not api or not api.GetGroupPaths then
		return result
	end
	local ok = pcall(api.GetGroupPaths, result)
	if not ok then
		return {}
	end
	return result
end

function Groups.GetItemsInGroup(path, includeSubGroups)
	local api = tsmGroupApi()
	local result = {}
	if not api or not api.GetGroupItems or not path then
		return result
	end
	local ok = pcall(api.GetGroupItems, path, includeSubGroups and true or false, result)
	if not ok then
		return {}
	end
	return result
end

function Groups.CountItems(path, includeSubGroups)
	local items = Groups.GetItemsInGroup(path, includeSubGroups)
	return #items, items
end

function Groups.FormatPath(path)
	local api = tsmGroupApi()
	if api and api.FormatGroupPath and path and path ~= "" then
		local ok, formatted = pcall(api.FormatGroupPath, path)
		if ok and formatted then
			return formatted
		end
	end
	if not path or path == "" then
		return "Keine Gruppe"
	end
	return (tostring(path):gsub("`", " > "))
end

function Groups.SplitPath(path)
	local api = tsmGroupApi()
	if api and api.SplitGroupPath and path and path ~= "" then
		local ok, parent, name = pcall(api.SplitGroupPath, path)
		if ok then
			return parent, name
		end
	end
	if not path or path == "" then
		return nil, ""
	end
	local parent, name = path:match("^(.*)`([^`]+)$")
	if name then
		return parent, name
	end
	return nil, path
end

local function pathDepth(path)
	if not path or path == "" then
		return 0
	end
	local n = 1
	for _ in tostring(path):gmatch("`") do
		n = n + 1
	end
	return n
end

---Sorted hierarchy rows for UI: depth, path, display, itemCount, isSmart.
function Groups.BuildHierarchy(opts)
	opts = opts or {}
	local search = (opts.search or ""):lower()
	local paths = Groups.ListPaths()
	table.sort(paths, function(a, b)
		return tostring(a) < tostring(b)
	end)
	local rows = {}
	for _, path in ipairs(paths) do
		local display = Groups.FormatPath(path)
		if search == "" or display:lower():find(search, 1, true) or tostring(path):lower():find(search, 1, true) then
			local count = Groups.CountItems(path, false)
			local parent, leaf = Groups.SplitPath(path)
			rows[#rows + 1] = {
				path = path,
				parent = parent,
				name = leaf or path,
				display = display,
				depth = pathDepth(path),
				itemCount = count,
				itemCountReliable = Groups.ProbeCapabilities().getItems,
				isSmart = Groups.IsSmartGroup(path),
			}
		end
	end
	return rows
end

---Dropdown choices including "Keine Gruppe" sentinel (empty string).
function Groups.ListChoices(opts)
	opts = opts or {}
	local choices = {
		{ path = "", label = "Keine Gruppe" },
	}
	for _, row in ipairs(Groups.BuildHierarchy({ search = opts.search })) do
		choices[#choices + 1] = {
			path = row.path,
			label = row.display,
			itemCount = row.itemCount,
			isSmart = row.isSmart,
		}
	end
	-- Offer missing Smart groups as create-via-import targets
	if opts.includeMissingSmart then
		for _, missing in ipairs(Groups.MissingSmartGroups()) do
			local exists = false
			for _, c in ipairs(choices) do
				if c.path == missing then
					exists = true
					break
				end
			end
			if not exists then
				choices[#choices + 1] = {
					path = missing,
					label = Groups.FormatPath(missing) .. " (fehlt — Import)",
					missing = true,
					isSmart = true,
				}
			end
		end
	end
	return choices
end

function Groups.OpenInTSM()
	-- TSM_API has no Groups UI open; only AUCTION/CRAFTING/MAILING/VENDORING visibility.
	local hint = Groups.OpenTSMGroupsHint()
	print("|cff4ecdc4[SmartTSM]|r " .. hint)
	return false, hint
end

function Groups.SmartGroupExists(path)
	for _, p in ipairs(Groups.ListPaths()) do
		if p == path then
			return true
		end
	end
	return false
end

function Groups.MissingSmartGroups()
	local missing = {}
	for _, path in ipairs(SMART_GROUPS) do
		if not Groups.SmartGroupExists(path) then
			missing[#missing + 1] = path
		end
	end
	if not Groups.SmartGroupExists(C.SMART_ROOT) then
		table.insert(missing, 1, C.SMART_ROOT)
	end
	return missing
end

function Groups.EnsureSmartGroups()
	local cap = Groups.ProbeCapabilities()
	if not cap.apiPresent then
		Logger.Warning("GROUP_CREATE_FAILED", "Groups", "EnsureSmartGroups", "TSM_API unavailable")
		return false, "NO_API"
	end
	if cap.createGroup then
		local api = tsmGroupApi()
		pcall(api.CreateGroup, C.SMART_ROOT)
		for _, path in ipairs(SMART_GROUPS) do
			pcall(api.CreateGroup, path)
		end
		return true, "DIRECT_API"
	end
	-- Cannot create via API — caller must use import string / setup wizard
	local missing = Groups.MissingSmartGroups()
	if #missing == 0 then
		return true, "ALREADY_PRESENT"
	end
	Logger.Warning(
		"GROUP_CREATE_FAILED",
		"Groups",
		"EnsureSmartGroups",
		"CreateGroup not in TSM_API 4.15.6 — import Smart groups via TSM Groups UI (" .. tostring(#missing) .. " missing)"
	)
	return false, "NEED_IMPORT", missing
end

---Escape commas in group path for import (TSM uses ``).
local function escapePath(path)
	return (tostring(path or ""):gsub(",", "``"))
end

---Build a TSM-compatible group/item import string (old list format).
---Format: group:Path,i:123,i:456,group:Other,i:789
function Groups.BuildImportString(moves, opts)
	opts = opts or {}
	local includeEmptyGroups = opts.includeEmptyGroups
	local byGroup = {}
	local order = {}
	for _, m in ipairs(moves or {}) do
		local g = m.toGroup
		local item = m.itemString
		if g and item then
			if not byGroup[g] then
				byGroup[g] = {}
				order[#order + 1] = g
			end
			byGroup[g][#byGroup[g] + 1] = item
		end
	end
	local emptyPaths = opts.emptyGroupPaths
	if includeEmptyGroups and not emptyPaths then
		emptyPaths = {}
		for _, path in ipairs(SMART_GROUPS) do
			emptyPaths[#emptyPaths + 1] = path
		end
		emptyPaths[#emptyPaths + 1] = C.SMART_ROOT
	end
	if emptyPaths then
		for _, path in ipairs(emptyPaths) do
			if path and not byGroup[path] then
				byGroup[path] = {}
				order[#order + 1] = path
			end
		end
		if not byGroup[C.SMART_ROOT] and includeEmptyGroups then
			-- ensure root when bootstrapping full smart set
			local hasRoot = false
			for _, p in ipairs(emptyPaths) do
				if p == C.SMART_ROOT then
					hasRoot = true
					break
				end
			end
			if not hasRoot then
				table.insert(order, 1, C.SMART_ROOT)
				byGroup[C.SMART_ROOT] = {}
			end
		end
	end
	local parts = {}
	-- Ensure root first if present
	table.sort(order, function(a, b)
		if a == C.SMART_ROOT then
			return true
		end
		if b == C.SMART_ROOT then
			return false
		end
		return tostring(a) < tostring(b)
	end)
	for _, g in ipairs(order) do
		parts[#parts + 1] = "group:" .. escapePath(g)
		for _, item in ipairs(byGroup[g] or {}) do
			parts[#parts + 1] = item
		end
	end
	local str = table.concat(parts, ",")
	private.lastImportString = str
	return str
end

function Groups.GetLastImportString()
	return private.lastImportString
end

local function tryDirectSet(itemString, groupPath)
	local api = tsmGroupApi()
	if not api then
		return false, "NO_API"
	end
	if api.SetGroup then
		return pcall(api.SetGroup, itemString, groupPath)
	end
	if api.MoveItem then
		return pcall(api.MoveItem, itemString, groupPath)
	end
	if api.SetItemGroup then
		return pcall(api.SetItemGroup, itemString, groupPath)
	end
	return false, "NO_WRITE_API"
end

---Apply moves. On TSM 4.15.6 returns import-string mode unless write API appears.
---@return boolean ok
---@return table applied
---@return table meta { mode, importString, failed }
function Groups.ApplyMoves(moves, opts)
	opts = opts or {}
	local Undo = Smart:GetModule("Undo")
	local cap = Groups.ProbeCapabilities()
	local applied = {}
	local failed = {}
	local meta = { mode = cap.writeMode, importString = nil, failed = failed, claim = cap.claim }

	if not cap.apiPresent then
		Logger.Error("GROUP_MOVE_FAILED", "Groups", "ApplyMoves", "TSM_API missing")
		return false, applied, meta
	end

	-- Refresh fromGroup from live TSM before apply
	for _, m in ipairs(moves or {}) do
		m.fromGroup = Groups.GetPathByItem(m.itemString) or m.fromGroup
	end

	if cap.writeMode == "DIRECT_API" or cap.writeMode == "DIRECT_MOVE_ONLY" then
		Groups.EnsureSmartGroups()
		for _, m in ipairs(moves or {}) do
			local ok, err = tryDirectSet(m.itemString, m.toGroup)
			if ok then
				applied[#applied + 1] = {
					itemString = m.itemString,
					fromGroup = m.fromGroup,
					toGroup = m.toGroup,
				}
			else
				failed[#failed + 1] = { itemString = m.itemString, error = tostring(err) }
				Logger.Error("GROUP_MOVE_FAILED", "Groups", "ApplyMoves", tostring(err), {
					itemId = m.itemString,
					group = m.toGroup,
				})
			end
		end
		if Undo and #applied > 0 then
			Undo.Push({ type = "GROUP_MOVES", moves = applied, mode = "DIRECT", at = time() })
		end
		meta.failed = failed
		return #applied > 0, applied, meta
	end

	-- IMPORT_STRING mode (default for Forever TSM 4.15.6)
	local importStr = Groups.BuildImportString(moves, { includeEmptyGroups = opts.includeEmptyGroups })
	meta.importString = importStr
	meta.mode = "IMPORT_STRING"
	-- Record intended moves for undo-as-reverse-import
	for _, m in ipairs(moves or {}) do
		applied[#applied + 1] = {
			itemString = m.itemString,
			fromGroup = m.fromGroup,
			toGroup = m.toGroup,
			pendingImport = true,
		}
	end
	if Undo and #applied > 0 then
		Undo.Push({
			type = "GROUP_MOVES",
			moves = applied,
			mode = "IMPORT_STRING",
			importString = importStr,
			reverseImportString = Groups.BuildImportString((function()
				local rev = {}
				for _, m in ipairs(applied) do
					if m.fromGroup then
						rev[#rev + 1] = { itemString = m.itemString, toGroup = m.fromGroup }
					end
				end
				return rev
			end)()),
			at = time(),
		})
	end
	Logger.Info("UNKNOWN", "Groups", "ApplyMoves", "Import string prepared (" .. tostring(#applied) .. " items) — paste into TSM Groups → Import")
	return true, applied, meta
end

function Groups.VerifyMoves(moves)
	local okList, badList = {}, {}
	for _, m in ipairs(moves or {}) do
		local live = Groups.GetPathByItem(m.itemString)
		if live == m.toGroup then
			okList[#okList + 1] = m
		else
			badList[#badList + 1] = { itemString = m.itemString, expected = m.toGroup, actual = live }
		end
	end
	return okList, badList
end

function Groups.IsSmartGroup(path)
	if not path then
		return false
	end
	return path == C.SMART_ROOT or path:find("^Smart TSM", 1, true) ~= nil
end

function Groups.RegisterRefreshCallback(cb)
	local api = tsmGroupApi()
	if not api or not api.RegisterGroupItemCallback or private.groupCallbackRegistered then
		return false
	end
	local ok = pcall(api.RegisterGroupItemCallback, "WoWSmartTSM:Groups", function()
		if cb then
			pcall(cb)
		end
	end)
	private.groupCallbackRegistered = ok and true or false
	return private.groupCallbackRegistered
end

function Groups.OpenTSMGroupsHint()
	return "TSM öffnen → Groups → Import String einfügen (oder Gruppe manuell anlegen). Smart TSM schreibt nicht in interne TSM-Strukturen."
end

Groups.SMART_GROUPS = SMART_GROUPS
Groups.STRATEGY_TO_GROUP = {
	QUICK_SELL = C.GROUPS.QUICK,
	PROFIT_SELL = C.GROUPS.PROFIT,
	RARE_SELL = C.GROUPS.RARE,
	VENDOR = C.GROUPS.VENDOR,
	HOLD = C.GROUPS.HOLD,
	MANUAL_REVIEW = C.GROUPS.REVIEW,
}

---Compatibility helper: suggest target group + preview moves (read-only).
function Groups.Suggest(decisions)
	local moves = {}
	for _, d in ipairs(decisions or {}) do
		local to = d and (d.targetGroup or Groups.STRATEGY_TO_GROUP[d.strategy])
		if d and d.itemString and to then
			moves[#moves + 1] = {
				itemString = d.itemString,
				fromGroup = Groups.GetPathByItem(d.itemString) or d.currentGroup,
				toGroup = to,
				preview = true,
			}
		end
	end
	return moves
end
