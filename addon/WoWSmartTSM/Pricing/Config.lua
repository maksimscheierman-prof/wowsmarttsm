local Smart = WoWSmartTSM
local C = Smart:Module("Constants")
local PricingConfig = Smart:Module("PricingConfig")

function PricingConfig.Get()
	local s = (WoWSmartTSM_DB and WoWSmartTSM_DB.settings) or {}
	return {
		ahCut = s.ahCut or C.DEFAULT_AH_CUT,
		depositRateFallback = s.depositRateFallback or C.DEFAULT_DEPOSIT_RATE,
		auctionHours = s.auctionHours or C.DEFAULT_AUCTION_HOURS,
		minExpectedNetCopper = s.minExpectedNetCopper or 0,
		-- SaleRate is a regional statistic, NOT P(sell in auctionHours)
		saleRateDiscount = 0.65, -- conservative mapping factor to listing success proxy
		undercutCopper = 1,
		depositFailWeight = 1.0,
	}
end
