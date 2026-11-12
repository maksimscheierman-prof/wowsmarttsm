local Smart = WoWSmartTSM
local C = Smart:Module("Constants")
local BulkReview = Smart:Module("BulkReview")
local Locale = Smart:Module("Locale")
local PostingTab = Smart:Module("PostingTab")

function PostingTab.Render(parent)
	BulkReview.Render(parent, {
		title = Locale.T("POSTING"),
		strategies = { C.STRATEGIES.QUICK_SELL, C.STRATEGIES.PROFIT_SELL, C.STRATEGIES.RARE_SELL },
	})
end
