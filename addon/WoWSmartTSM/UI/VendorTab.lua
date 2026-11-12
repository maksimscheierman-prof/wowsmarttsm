local Smart = WoWSmartTSM
local C = Smart:Module("Constants")
local BulkReview = Smart:Module("BulkReview")
local Locale = Smart:Module("Locale")
local Widgets = Smart:Module("Widgets")
local VendorService = Smart:Module("VendorService")
local VendorTab = Smart:Module("VendorTab")

function VendorTab.Render(parent)
	BulkReview.Render(parent, {
		title = Locale.T("VENDOR"),
		strategy = C.STRATEGIES.VENDOR,
	})
	local dry = Widgets.Button(parent, Locale.T("DRY_RUN") .. " Vendor", 160, 22, function()
		local ScanService = Smart:GetModule("ScanService")
		local candidates = VendorService.BuildCandidates(ScanService.GetLastResults())
		local res = VendorService.SellSelected(candidates, { confirmed = true, dryRun = true })
		print(string.format("|cff4ecdc4[SmartTSM]|r Vendor DryRun wouldSell=%d blocked=%d", res.sold, res.blocked))
	end)
	dry:SetPoint("BOTTOM", 0, 14)
end
