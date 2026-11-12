local Smart = WoWSmartTSM
local Privacy = Smart:Module("Privacy")

local SENSITIVE_PATTERNS = {
	"[Pp]assword",
	"[Tt]oken",
	"[Aa]pi[_%-]?[Kk]ey",
	"[Ss]ecret",
	"[Aa]uth",
	"AccountName",
	"session[_%-]?key",
}

function Privacy.SanitizeString(str)
	if type(str) ~= "string" then
		return str
	end
	local out = str
	for _, pat in ipairs(SENSITIVE_PATTERNS) do
		out = out:gsub(pat .. "[%s:=]+[%S]+", "%1=[REDACTED]")
	end
	-- Strip likely email-ish tokens
	out = out:gsub("[%w%.%%%+%-]+@[%w%.%-]+%.%w+", "[REDACTED_EMAIL]")
	return out
end

function Privacy.SanitizeTable(tbl, depth)
	depth = depth or 0
	if depth > 4 or type(tbl) ~= "table" then
		return tbl
	end
	local out = {}
	for k, v in pairs(tbl) do
		local key = tostring(k)
		local lower = key:lower()
		if lower:find("pass") or lower:find("token") or lower:find("secret") or lower:find("apikey") then
			out[k] = "[REDACTED]"
		elseif type(v) == "string" then
			out[k] = Privacy.SanitizeString(v)
		elseif type(v) == "table" then
			out[k] = Privacy.SanitizeTable(v, depth + 1)
		else
			out[k] = v
		end
	end
	return out
end
