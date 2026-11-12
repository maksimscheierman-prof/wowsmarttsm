local Smart = WoWSmartTSM
local BulkReview = Smart:Module("BulkReview")
local Locale = Smart:Module("Locale")
local SkippedTab = Smart:Module("SkippedTab")

function SkippedTab.Render(parent)
	BulkReview.Render(parent, {
		title = Locale.T("SKIPPED"),
		skipOnly = true,
	})
end
