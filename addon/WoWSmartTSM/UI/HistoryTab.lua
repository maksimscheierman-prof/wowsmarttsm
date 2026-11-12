local Smart = WoWSmartTSM
local Locale = Smart:Module("Locale")
local Widgets = Smart:Module("Widgets")
local History = Smart:Module("History")
local Time = Smart:Module("TimeUtil")
local HistoryTab = Smart:Module("HistoryTab")

function HistoryTab.Render(parent)
	for _, child in ipairs({ parent:GetChildren() }) do
		child:Hide()
		child:SetParent(nil)
	end
	local title = Widgets.Label(parent, Locale.T("HISTORY"), 14)
	title:SetPoint("TOPLEFT", 16, -16)
	local y = -44
	local list = History.Get()
	for i = #list, math.max(1, #list - 40), -1 do
		local e = list[i]
		local line = Widgets.Label(parent, string.format("%s  %s  %s", Time.ISO(e.at), e.type, tostring(e.payload and e.payload.count or "")), 11)
		line:SetPoint("TOPLEFT", 16, y)
		y = y - 16
	end
	if #list == 0 then
		local empty = Widgets.Label(parent, "Noch keine Einträge.", 11)
		empty:SetPoint("TOPLEFT", 16, -44)
	end
end
