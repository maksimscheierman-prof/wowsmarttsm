local Smart = WoWSmartTSM
local C = Smart:Module("Constants")
local Logger = Smart:Module("Logger")
local Groups = Smart:Module("Groups")
local Undo = Smart:Module("Undo")

local function stack()
	local db = WoWSmartTSM_DB
	db.undoStack = db.undoStack or {}
	return db.undoStack
end

function Undo.Push(entry)
	local s = stack()
	s[#s + 1] = entry
	while #s > C.UNDO_STACK_SIZE do
		table.remove(s, 1)
	end
end

function Undo.CanUndo()
	local s = stack()
	return #s > 0
end

function Undo.UndoLast()
	local s = stack()
	local entry = table.remove(s)
	if not entry then
		Logger.Warning("UNDO_EMPTY", "Undo", "UndoLast", "Nothing to undo")
		return false
	end
	if entry.type == "GROUP_MOVES" then
		local reverse = {}
		for _, m in ipairs(entry.moves or {}) do
			reverse[#reverse + 1] = {
				itemString = m.itemString,
				fromGroup = m.toGroup,
				toGroup = m.fromGroup,
			}
		end
		-- Apply without pushing another undo (manual)
		local api = TSM_API
		if not api then
			return false
		end
		for _, m in ipairs(reverse) do
			if api.SetGroup then
				pcall(api.SetGroup, m.itemString, m.toGroup)
			elseif api.MoveItem then
				pcall(api.MoveItem, m.itemString, m.toGroup)
			end
		end
		Logger.Info("UNKNOWN", "Undo", "UndoLast", "Reverted " .. tostring(#reverse) .. " group moves")
		return true
	end
	return false
end
