local Smart = WoWSmartTSM
local T = Smart:Module("TableUtil")

function T.ShallowCopy(src)
	local dst = {}
	if not src then
		return dst
	end
	for k, v in pairs(src) do
		dst[k] = v
	end
	return dst
end

function T.DeepCopy(src, seen)
	if type(src) ~= "table" then
		return src
	end
	seen = seen or {}
	if seen[src] then
		return seen[src]
	end
	local dst = {}
	seen[src] = dst
	for k, v in pairs(src) do
		dst[T.DeepCopy(k, seen)] = T.DeepCopy(v, seen)
	end
	return dst
end

function T.Count(tbl)
	local n = 0
	for _ in pairs(tbl or {}) do
		n = n + 1
	end
	return n
end

function T.Keys(tbl)
	local keys = {}
	for k in pairs(tbl or {}) do
		keys[#keys + 1] = k
	end
	return keys
end
