local Smart = WoWSmartTSM
local C = Smart:Module("Constants")
local BulkReview = Smart:Module("BulkReview")
local Locale = Smart:Module("Locale")
local VendorTab = Smart:Module("VendorTab")

function VendorTab.Render(parent)
	BulkReview.Render(parent, {
		title = Locale.T("VENDOR"),
		strategy = C.STRATEGIES.VENDOR,
	})
end
