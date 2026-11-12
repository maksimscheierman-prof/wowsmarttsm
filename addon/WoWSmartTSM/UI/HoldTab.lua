local Smart = WoWSmartTSM
local C = Smart:Module("Constants")
local BulkReview = Smart:Module("BulkReview")
local Locale = Smart:Module("Locale")
local HoldTab = Smart:Module("HoldTab")

function HoldTab.Render(parent)
	BulkReview.Render(parent, {
		title = Locale.T("HOLD") .. " (Filter, kein Dauerbefehl)",
		strategy = C.STRATEGIES.HOLD,
	})
end
