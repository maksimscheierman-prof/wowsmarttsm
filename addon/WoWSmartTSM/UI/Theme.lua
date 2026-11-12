local Smart = WoWSmartTSM
local Theme = Smart:Module("Theme")

-- Calm, readable palette (avoid loud red/yellow defaults)
Theme.COLORS = {
	bg = { 0.07, 0.09, 0.11, 0.96 },
	panel = { 0.11, 0.14, 0.17, 0.98 },
	accent = { 0.35, 0.72, 0.70, 1 },
	text = { 0.90, 0.92, 0.93, 1 },
	muted = { 0.62, 0.67, 0.70, 1 },
	post = { 0.42, 0.72, 0.50, 1 },
	vendor = { 0.82, 0.70, 0.40, 1 },
	hold = { 0.55, 0.65, 0.85, 1 },
	skip = { 0.85, 0.55, 0.48, 1 },
	review = { 0.75, 0.75, 0.55, 1 },
	ok = { 0.45, 0.75, 0.55, 1 },
	warn = { 0.85, 0.70, 0.35, 1 },
	bad = { 0.85, 0.45, 0.42, 1 },
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
