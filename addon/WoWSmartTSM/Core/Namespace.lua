-- WoW Smart TSM — global namespace bootstrap
local ADDON_NAME = ...
---@class WoWSmartTSM
local Smart = {}
_G.WoWSmartTSM = Smart
Smart.ADDON_NAME = ADDON_NAME
Smart._modules = {}

---Register or fetch a submodule table.
---@param name string
---@return table
function Smart:Module(name)
	if not self._modules[name] then
		self._modules[name] = {}
	end
	return self._modules[name]
end

function Smart:GetModule(name)
	return self._modules[name]
end
