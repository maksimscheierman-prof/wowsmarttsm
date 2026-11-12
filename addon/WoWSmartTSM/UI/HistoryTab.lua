local Smart = WoWSmartTSM
local Locale = Smart:Module("Locale")
local Layout = Smart:Module("Layout")
local Theme = Smart:Module("Theme")
local History = Smart:Module("History")
local Time = Smart:Module("TimeUtil")
local HistoryTab = Smart:Module("HistoryTab")

function HistoryTab.Render(parent)
	local root = Layout.Begin(parent)
	Layout.HeaderTitle(root.header, Locale.T("HISTORY"))
	local stack = Layout.BodyStack(root)
	local list = History.Get()
	if #list == 0 then
		Layout.AddText(stack, "Noch keine Einträge.", "GameFontHighlight", Theme.COLORS.muted)
	else
		local rows = {}
		local from = math.max(1, #list - 40)
		for i = #list, from, -1 do
			local e = list[i]
			rows[#rows + 1] = {
				Time.ISO(e.at),
				e.type or "?",
				tostring(e.payload and e.payload.count or ""),
			}
		end
		Layout.AddTable(stack, {
			{ title = "Zeit", width = 180 },
			{ title = "Ereignis", width = 220 },
			{ title = "Detail", width = 120 },
		}, rows, { maxHeight = 360 })
	end
	Layout.FinishStack(stack)
	Layout.FooterText(root.footer, string.format("%d Einträge", #list))
end
