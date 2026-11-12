local Smart = WoWSmartTSM
local C = Smart:Module("Constants")
local Recommend = Smart:Module("Recommend")

function Recommend.FromDecision(decision)
	local tips = {}
	local strategy = decision.strategy
	if strategy == C.STRATEGIES.QUICK_SELL then
		tips[#tips + 1] = "ASSIGN_SMART_QUICK_SELL"
	elseif strategy == C.STRATEGIES.PROFIT_SELL then
		tips[#tips + 1] = "ASSIGN_SMART_PROFIT_SELL"
	elseif strategy == C.STRATEGIES.RARE_SELL then
		tips[#tips + 1] = "ASSIGN_SMART_RARE_SELL"
	elseif strategy == C.STRATEGIES.HOLD then
		tips[#tips + 1] = "HOLD_FILTER_ONLY_IF_AH_BAD"
	elseif strategy == C.STRATEGIES.VENDOR then
		tips[#tips + 1] = "CONFIRM_VENDOR_BULK"
	else
		tips[#tips + 1] = "MANUAL_REVIEW_REQUIRED"
	end
	if decision.pricing and decision.pricing.reasons then
		for _, r in ipairs(decision.pricing.reasons) do
			if r == "COMPETITION_BELOW_OPERATION_MIN" then
				tips[#tips + 1] = "EVALUATE_LOWER_PRICE_OR_QUICK_SELL"
			elseif r == "DEPOSIT_RISK_TOO_HIGH" then
				tips[#tips + 1] = "CONSIDER_VENDOR_OR_WAIT"
			end
		end
	end
	return tips
end
