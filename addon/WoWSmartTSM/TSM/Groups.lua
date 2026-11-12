local Smart = WoWSmartTSM
local C = Smart:Module("Constants")
local Logger = Smart:Module("Logger")
local Undo = nil
local Groups = Smart:Module("Groups")

local SMART_GROUPS = {
	C.GROUPS.QUICK,
	C.GROUPS.PROFIT,
	C.GROUPS.RARE,
	C.GROUPS.VENDOR,
	C.GROUPS.HOLD,
	C.GROUPS.REVIEW,
}

local function tsmGroupApi()
	if TSM_API then
		return TSM_API
	end
	return nil
end

function Groups.GetPathByItem(itemString)
	local api = tsmGroupApi()
	if api and api.GetGroupPath then
		local ok, path = pcall(api.GetGroupPath, itemString)
		if ok then
			return path
		end
	end
	return nil
end

function Groups.EnsureSmartGroups()
	local api = tsmGroupApi()
	if not api then
		Logger.Warning("GROUP_CREATE_FAILED", "Groups", "EnsureSmartGroups", "TSM_API unavailable")
		return false
	end
	-- Prefer high-level APIs when present; otherwise no-op with warning (PARTIAL)
	if api.CreateGroup then
		pcall(api.CreateGroup, C.SMART_ROOT)
		for _, path in ipairs(SMART_GROUPS) do
			pcall(api.CreateGroup, path)
		end
		return true
	end
	Logger.Warning("GROUP_CREATE_FAILED", "Groups", "EnsureSmartGroups", "CreateGroup API not exposed — create Smart TSM groups manually once")
	return false
end

---Apply confirmed moves. Does NOT touch unrelated groups except moving listed items.
---@param moves table[] {itemString, fromGroup, toGroup}
function Groups.ApplyMoves(moves, opts)
	opts = opts or {}
	local api = tsmGroupApi()
	if not api or not api.SetCustomPrice and not api.GetGroupPath then
		-- TSM_API historically exposes group helpers differently across builds
	end
	Undo = Smart:GetModule("Undo")
	local applied = {}
	local apiSet = api and (api.SetItemGroup or api.MoveItem)
	if not api then
		Logger.Error("GROUP_MOVE_FAILED", "Groups", "ApplyMoves", "TSM_API missing")
		return false, applied
	end

	-- Documented TSM_API surface varies; try SetGroup / known names
	local function setGroup(itemString, groupPath)
		if api.SetGroup then
			return pcall(api.SetGroup, itemString, groupPath)
		end
		if api.MoveItem then
			return pcall(api.MoveItem, itemString, groupPath)
		end
		return false, "no set API"
	end

	Groups.EnsureSmartGroups()

	for _, m in ipairs(moves or {}) do
		local from = m.fromGroup or Groups.GetPathByItem(m.itemString)
		local ok, err = setGroup(m.itemString, m.toGroup)
		if ok then
			applied[#applied + 1] = {
				itemString = m.itemString,
				fromGroup = from,
				toGroup = m.toGroup,
			}
		else
			Logger.Error("GROUP_MOVE_FAILED", "Groups", "ApplyMoves", tostring(err), {
				itemId = m.itemString,
				group = m.toGroup,
			})
		end
	end

	if Undo and #applied > 0 then
		Undo.Push({ type = "GROUP_MOVES", moves = applied, at = time() })
	end
	return #applied > 0, applied
end

function Groups.IsSmartGroup(path)
	if not path then
		return false
	end
	return path == C.SMART_ROOT or path:find("^Smart TSM") ~= nil
end

Groups.SMART_GROUPS = SMART_GROUPS
