local Smart = WoWSmartTSM
local Time = Smart:Module("TimeUtil")

function Time.Now()
	if GetServerTime then
		return GetServerTime()
	end
	return time()
end

function Time.ISO(ts)
	ts = ts or Time.Now()
	-- WoW has limited date formatting; keep simple epoch + readable
	local d = date and date("!%Y-%m-%dT%H:%M:%SZ", ts) or tostring(ts)
	return d
end

function Time.AgeSeconds(ts)
	if not ts then
		return nil
	end
	return math.max(0, Time.Now() - ts)
end
