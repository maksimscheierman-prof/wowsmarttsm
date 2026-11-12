local Smart = WoWSmartTSM
local RB = Smart:Module("RingBuffer")

function RB.New(capacity)
	return {
		capacity = capacity or 500,
		items = {},
		nextIndex = 1,
		count = 0,
	}
end

function RB.Push(buf, item)
	buf.items[buf.nextIndex] = item
	buf.nextIndex = buf.nextIndex % buf.capacity + 1
	if buf.count < buf.capacity then
		buf.count = buf.count + 1
	end
end

function RB.ToArray(buf)
	local out = {}
	if buf.count == 0 then
		return out
	end
	local start
	if buf.count < buf.capacity then
		start = 1
	else
		start = buf.nextIndex
	end
	for i = 0, buf.count - 1 do
		local idx = (start + i - 1) % buf.capacity + 1
		out[#out + 1] = buf.items[idx]
	end
	return out
end
