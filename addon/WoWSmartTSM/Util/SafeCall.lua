local Smart = WoWSmartTSM
local Safe = Smart:Module("SafeCall")

---Protected call that logs failures via Diagnostics when available.
function Safe.Call(moduleName, funcName, fn, ...)
	local ok, a, b, c, d, e = pcall(fn, ...)
	if ok then
		return true, a, b, c, d, e
	end
	local Logger = Smart:GetModule("Logger")
	if Logger and Logger.Error then
		Logger.Error("SAFE_CALL_FAILED", moduleName, funcName, tostring(a), {
			err = tostring(a),
		})
	end
	return false, a
end

function Safe.CallQuiet(fn, ...)
	local ok, a, b, c, d, e = pcall(fn, ...)
	if ok then
		return true, a, b, c, d, e
	end
	return false, a
end
