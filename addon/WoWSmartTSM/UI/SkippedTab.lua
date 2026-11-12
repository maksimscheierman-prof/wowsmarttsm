local Smart = WoWSmartTSM
local BulkReview = Smart:Module("BulkReview")
local Locale = Smart:Module("Locale")
local Widgets = Smart:Module("Widgets")
local SkipMap = Smart:Module("SkipMap")
local SkippedTab = Smart:Module("SkippedTab")

function SkippedTab.Render(parent)
	-- Show all with skip info — filter by having skip in BulkReview via custom
	local ScanService = Smart:GetModule("ScanService")
	local results = ScanService.GetLastResults() or {}
	-- Annotate: use BulkReview with no strategy but we need skip-only
	-- Temporary: render via BulkReview then note; filter by wrapping results
	local filtered = {}
	for _, d in ipairs(results) do
		if d and d.skip then
			filtered[#filtered + 1] = d
		end
	end
	-- Swap last results temporarily for render
	local prev = results
	-- Monkey-patch GetLastResults briefly
	local original = ScanService.GetLastResults
	ScanService.GetLastResults = function()
		return filtered
	end
	BulkReview.Render(parent, { title = Locale.T("SKIPPED") })
	ScanService.GetLastResults = original
end
