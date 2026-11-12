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
		if entry.mode == "IMPORT_STRING" then
			local rev = entry.reverseImportString
			if not rev or rev == "" then
				-- rebuild from moves that had fromGroup
				local reverseMoves = {}
				for _, m in ipairs(entry.moves or {}) do
					if m.fromGroup then
						reverseMoves[#reverseMoves + 1] = {
							itemString = m.itemString,
							toGroup = m.fromGroup,
						}
					end
				end
				rev = Groups.BuildImportString(reverseMoves)
			end
			if WoWSmartTSM_DB then
				WoWSmartTSM_DB.lastGroupImportString = rev
			end
			Logger.Info(
				"UNKNOWN",
				"Undo",
				"UndoLast",
				"Reverse import prepared — paste into TSM Groups → Import"
			)
			print("|cff4ecdc4[SmartTSM]|r Undo (Import): Reverse-String bereit — /smarttsm importstring")
			if rev and #rev > 0 then
				local preview = (#rev > 180) and (rev:sub(1, 180) .. "…") or rev
				print(preview)
			end
			return true
		end
		local reverse = {}
		for _, m in ipairs(entry.moves or {}) do
			if m.fromGroup then
				reverse[#reverse + 1] = {
					itemString = m.itemString,
					fromGroup = m.toGroup,
					toGroup = m.fromGroup,
				}
			end
		end
		local api = TSM_API
		if not api then
			return false
		end
		local n = 0
		for _, m in ipairs(reverse) do
			local ok = false
			if api.SetGroup then
				ok = pcall(api.SetGroup, m.itemString, m.toGroup)
			elseif api.MoveItem then
				ok = pcall(api.MoveItem, m.itemString, m.toGroup)
			elseif api.SetItemGroup then
				ok = pcall(api.SetItemGroup, m.itemString, m.toGroup)
			end
			if ok then
				n = n + 1
			end
		end
		Logger.Info("UNKNOWN", "Undo", "UndoLast", "Reverted " .. tostring(n) .. " group moves")
		return n > 0
	end
	return false
end
