local Smart = WoWSmartTSM
local Operations = Smart:Module("Operations")

---Read-only helpers for auctioning operation context.
---Does not mutate global operations because of a single item.
function Operations.GetAuctioningContext(itemString)
	local ctx = {
		itemString = itemString,
		minPrice = nil,
		normalPrice = nil,
		maxPrice = nil,
		postCap = nil,
		operationName = nil,
	}
	if TSM_API and TSM_API.GetAuctioningOperationMinPrice then
		local ok, v = pcall(TSM_API.GetAuctioningOperationMinPrice, itemString)
		if ok then ctx.minPrice = v end
	end
	-- Fallback: custom price evaluation of common fields not available → leave nil
	return ctx
end
