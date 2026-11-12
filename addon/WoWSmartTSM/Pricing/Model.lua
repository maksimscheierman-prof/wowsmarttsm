local Smart = WoWSmartTSM
local C = Smart:Module("Constants")
local PricingConfig = Smart:Module("PricingConfig")
local PricingModel = Smart:Module("PricingModel")

--[[
Expected value model (documented in docs/PRICING_MODEL.md):

  net_if_sold(price) = price * (1 - ahCut) - 0  (deposit returned on sale in classic-like rules; if not, adjust)
  loss_if_expire     = deposit

  EV(price) ≈ p_sell * net_if_sold(price) - (1 - p_sell) * deposit_fail_weight * deposit

p_sell is a *proxy*, never claimed as calibrated probability:
  base from min(0.95, max(0.05, saleRate * saleRateDiscount)) when saleRate present
  adjusted by competition vs price and soldPerDay

Conservative fallback when data thin: require price >= max(vendor/(1-cut), small margin) and confidence flag.
]]

local function estimateDeposit(profile, cfg, price)
	if profile.deposit and profile.deposit > 0 then
		return profile.deposit
	end
	local base = profile.vendorSell or 0
	if base <= 0 then
		base = math.floor((price or 0) * 0.05)
	end
	return math.max(1, math.floor(base * cfg.depositRateFallback * (profile.stackSize or 1)))
end

local function sellProxy(profile, cfg, price)
	local p = 0.35 -- conservative default when no demand signal
	local unreliable = true
	if profile.saleRate ~= nil then
		-- DBRegionSaleRate is NOT duration probability
		p = math.min(0.9, math.max(0.05, profile.saleRate * cfg.saleRateDiscount))
		unreliable = false
	end
	if profile.soldPerDay ~= nil then
		if profile.soldPerDay >= 5 then
			p = math.min(0.92, p + 0.15)
		elseif profile.soldPerDay <= 0.2 then
			p = math.max(0.05, p - 0.15)
		end
		unreliable = false
	end
	if profile.minBuyout and price then
		if price > profile.minBuyout * 1.15 then
			p = math.max(0.05, p - 0.2) -- overpriced vs competition
		elseif price <= profile.minBuyout then
			p = math.min(0.95, p + 0.1)
		end
	end
	if profile.numAuctions and profile.numAuctions > 20 then
		p = math.max(0.05, p - 0.1)
	end
	return p, unreliable
end

local function netIfSold(price, cfg)
	return math.floor(price * (1 - cfg.ahCut))
end

function PricingModel.ScorePrice(profile, price, cfg)
	cfg = cfg or PricingConfig.Get()
	price = math.floor(price or 0)
	if price <= 0 then
		return {
			price = price,
			ev = nil,
			pSellProxy = nil,
			deposit = 0,
			netIfSold = 0,
			valid = false,
			reason = "INVALID_PRICE",
		}
	end
	local deposit = estimateDeposit(profile, cfg, price)
	local p, unreliable = sellProxy(profile, cfg, price)
	local nis = netIfSold(price, cfg)
	local ev = p * nis - (1 - p) * cfg.depositFailWeight * deposit
	return {
		price = price,
		ev = ev,
		pSellProxy = p,
		pSellUnreliable = unreliable,
		deposit = deposit,
		netIfSold = nis,
		valid = true,
	}
end

function PricingModel.Evaluate(profile)
	local cfg = PricingConfig.Get()
	local candidates = {}
	local reasons = {}

	local market = profile.marketValue
	local region = profile.regionMarket
	local minBuyout = profile.minBuyout
	local opMin = profile.operationMinPrice
	local vendor = profile.vendorSell or 0

	if not market and region then
		market = region
		reasons[#reasons + 1] = "USING_REGION_AS_MARKET"
	end
	if not market and minBuyout then
		market = minBuyout
		reasons[#reasons + 1] = "USING_MINBUYOUT_AS_MARKET"
	end

	local thinData = (profile.dataQuality or 0) < 0.4 or profile.stale
	if thinData then
		reasons[#reasons + 1] = "THIN_OR_STALE_DATA_CONSERVATIVE"
	end

	-- Candidate prices
	local function add(price, tag)
		if price and price > 0 then
			local scored = PricingModel.ScorePrice(profile, price, cfg)
			scored.tag = tag
			candidates[#candidates + 1] = scored
		end
	end

	if market then
		add(market, "DBMARKET")
		add(math.floor(market * 0.95), "DBMARKET_95")
		add(math.floor(market * 0.85), "DBMARKET_85")
	end
	if minBuyout then
		add(math.max(1, minBuyout - cfg.undercutCopper), "UNDERCUT_MINBUYOUT")
	end
	if opMin and minBuyout and minBuyout < opMin then
		-- Competing under current TSM min — evaluate lower price economically
		add(math.max(1, minBuyout - cfg.undercutCopper), "BELOW_OP_MIN_CANDIDATE")
		reasons[#reasons + 1] = "COMPETITION_BELOW_OPERATION_MIN"
	end
	if vendor > 0 then
		local floorPrice = math.floor(vendor / math.max(0.01, (1 - cfg.ahCut)) + 1)
		add(floorPrice, "VENDOR_FLOOR")
	end

	local best = nil
	for _, c in ipairs(candidates) do
		if c.valid and c.ev ~= nil then
			if not best or c.ev > best.ev then
				best = c
			end
		end
	end

	local shouldPost = false
	local mode = "PROFIT"
	local suggested = best and best.price or nil
	local expectedNet = best and best.ev or nil

	if best and best.ev and best.ev >= cfg.minExpectedNetCopper then
		-- Must beat vendor alternative on expected value when vendor exists
		local vendorAlt = vendor * (profile.quantity or 1)
		if vendor > 0 and best.ev < vendor * 0.5 and thinData then
			reasons[#reasons + 1] = "EV_NOT_BETTER_THAN_VENDOR_CONSERVATIVE"
			shouldPost = false
		elseif best.netIfSold <= vendor and vendor > 0 then
			reasons[#reasons + 1] = "NET_IF_SOLD_LEQ_VENDOR"
			shouldPost = false
		elseif best.deposit > (best.netIfSold * 0.8) and (best.pSellProxy or 0) < 0.25 then
			reasons[#reasons + 1] = "DEPOSIT_RISK_TOO_HIGH"
			shouldPost = false
		else
			shouldPost = true
			-- Mode priority: RARE (blue+/epic/recipe) → QUICK (real demand) → PROFIT (default).
			-- Never treat missing saleRate as 1.0 (that forced everything to QUICK_SELL).
			local holdCat = nil
			local HoldPolicy = Smart:GetModule("HoldPolicy")
			if HoldPolicy and HoldPolicy.ResolveCategory then
				holdCat = HoldPolicy.ResolveCategory(profile)
			end
			local isRarePost = (holdCat == "RARE_RECIPE")
				or (holdCat == "BLUE_GEAR")
				or (holdCat == "EPIC_GEAR")
				or ((profile.quality or 0) >= C.QUALITY.RARE and profile.isEquipment == true)
			local hasQuickDemand = (profile.saleRate ~= nil and profile.saleRate >= 0.4)
				or (profile.soldPerDay ~= nil and profile.soldPerDay >= 2)
			if isRarePost then
				mode = "RARE"
				reasons[#reasons + 1] = "MODE_RARE_ITEM"
			elseif hasQuickDemand then
				mode = "QUICK"
				reasons[#reasons + 1] = "MODE_QUICK_DEMAND"
			else
				mode = "PROFIT"
				reasons[#reasons + 1] = "MODE_PROFIT_DEFAULT"
			end
			reasons[#reasons + 1] = "EV_POSITIVE"
		end
	else
		reasons[#reasons + 1] = "NO_POSITIVE_EV_CANDIDATE"
	end

	-- Loss-making explicit
	if best and best.netIfSold and vendor > 0 and best.netIfSold < vendor then
		reasons[#reasons + 1] = "POTENTIAL_LOSS_VS_VENDOR"
	end

	return {
		shouldPost = shouldPost,
		mode = mode,
		suggestedBuyout = suggested,
		expectedNet = expectedNet,
		estimatedDeposit = best and best.deposit or estimateDeposit(profile, cfg, suggested or vendor),
		candidates = candidates,
		best = best,
		reasons = reasons,
		ahCut = cfg.ahCut,
		thinData = thinData,
		precise = not thinData and best and not best.pSellUnreliable,
	}
end
