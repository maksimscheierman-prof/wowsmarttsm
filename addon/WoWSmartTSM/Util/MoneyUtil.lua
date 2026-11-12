local Smart = WoWSmartTSM
local C = Smart:Module("Constants")
local M = Smart:Module("MoneyUtil")

function M.ToCopper(gold, silver, copper)
	return (gold or 0) * C.COPPER_PER_GOLD + (silver or 0) * C.COPPER_PER_SILVER + (copper or 0)
end

function M.FromCopper(copper)
	copper = math.floor(copper or 0)
	local g = math.floor(copper / C.COPPER_PER_GOLD)
	copper = copper % C.COPPER_PER_GOLD
	local s = math.floor(copper / C.COPPER_PER_SILVER)
	local c = copper % C.COPPER_PER_SILVER
	return g, s, c
end

function M.Format(copper, short)
	copper = math.floor(copper or 0)
	local neg = copper < 0
	copper = math.abs(copper)
	local g, s, c = M.FromCopper(copper)
	local text
	if short then
		if g > 0 then
			text = string.format("%dg%02ds", g, s)
		elseif s > 0 then
			text = string.format("%ds%02dc", s, c)
		else
			text = string.format("%dc", c)
		end
	else
		text = string.format("%dg %02ds %02dc", g, s, c)
	end
	if neg then
		return "-" .. text
	end
	return text
end

function M.SafeDiv(a, b)
	if not b or b == 0 then
		return nil
	end
	return a / b
end
