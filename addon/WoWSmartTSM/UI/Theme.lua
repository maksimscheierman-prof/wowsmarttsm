local Smart = WoWSmartTSM
local Theme = Smart:Module("Theme")

Theme.COLORS = {
	bg = { 0.08, 0.10, 0.12, 0.95 },
	panel = { 0.12, 0.15, 0.18, 0.98 },
	accent = { 0.30, 0.80, 0.77, 1 },
	text = { 0.92, 0.93, 0.94, 1 },
	muted = { 0.65, 0.70, 0.72, 1 },
	post = { 0.35, 0.78, 0.45, 1 },
	vendor = { 0.95, 0.75, 0.30, 1 },
	hold = { 0.55, 0.65, 0.95, 1 },
	skip = { 0.95, 0.45, 0.40, 1 },
	review = { 0.80, 0.80, 0.55, 1 },
}

function Theme.StrategyColor(strategy)
	local C = Smart:Module("Constants")
	if strategy == C.STRATEGIES.VENDOR then
		return Theme.COLORS.vendor
	end
	if strategy == C.STRATEGIES.HOLD then
		return Theme.COLORS.hold
	end
	if strategy == C.STRATEGIES.MANUAL_REVIEW then
		return Theme.COLORS.review
	end
	if strategy == C.STRATEGIES.QUICK_SELL or strategy == C.STRATEGIES.PROFIT_SELL or strategy == C.STRATEGIES.RARE_SELL then
		return Theme.COLORS.post
	end
	return Theme.COLORS.text
end
