local Smart = WoWSmartTSM
local C = Smart:Module("Constants")
local Time = Smart:Module("TimeUtil")
local History = Smart:Module("History")

function History.Add(eventType, payload)
	local db = WoWSmartTSM_DB
	if not db then
		return
	end
	db.history = db.history or {}
	db.history[#db.history + 1] = {
		at = Time.Now(),
		type = eventType,
		payload = payload,
	}
	while #db.history > C.HISTORY_RING_SIZE do
		table.remove(db.history, 1)
	end
end

function History.Get()
	return (WoWSmartTSM_DB and WoWSmartTSM_DB.history) or {}
end
