local Smart = WoWSmartTSM
local C = Smart:Module("Constants")
local CleanupService = Smart:Module("CleanupService")

function CleanupService.Summarize(results)
	results = results or (Smart:GetModule("ScanService").GetLastResults() or {})
	local sum = {
		mailToBank = 0,
		postAh = 0,
		vendor = 0,
		keep = 0,
		hold = 0,
		holdAtBank = 0,
		review = 0,
		ignore = 0,
		needsBankConfig = false,
		n = #results,
	}
	for _, d in ipairs(results) do
		if d and d.needsBankConfig then
			sum.needsBankConfig = true
		end
		local a = d and d.inventoryAction
		if a == C.ACTIONS.MAIL_TO_BANK then
			sum.mailToBank = sum.mailToBank + 1
		elseif a == C.ACTIONS.POST_AH then
			sum.postAh = sum.postAh + 1
		elseif a == C.ACTIONS.VENDOR then
			sum.vendor = sum.vendor + 1
		elseif a == C.ACTIONS.KEEP then
			sum.keep = sum.keep + 1
		elseif a == C.ACTIONS.HOLD then
			sum.hold = sum.hold + 1
		elseif a == C.ACTIONS.HOLD_AT_BANK then
			sum.holdAtBank = sum.holdAtBank + 1
		elseif a == C.ACTIONS.IGNORE then
			sum.ignore = sum.ignore + 1
		else
			sum.review = sum.review + 1
		end
	end
	return sum
end

function CleanupService.Filter(results, actionFilter)
	results = results or {}
	if not actionFilter or actionFilter == "ALL" then
		return results
	end
	local out = {}
	for _, d in ipairs(results) do
		if d and d.inventoryAction == actionFilter then
			out[#out + 1] = d
		elseif actionFilter == "UNSAFE" and d and (d.inventoryAction == C.ACTIONS.MANUAL_REVIEW or (d.actionConfidence or 1) < 0.5) then
			out[#out + 1] = d
		end
	end
	return out
end

function CleanupService.ActionLabel(action)
	local map = {
		MAIL_TO_BANK = "An Bank senden",
		POST_AH = "AH vorbereiten",
		VENDOR = "Händler",
		KEEP = "Behalten",
		IGNORE = "Ignorieren",
		HOLD = "Smart Hold",
		HOLD_AT_BANK = "Hold → Bank",
		MANUAL_REVIEW = "Prüfung",
	}
	return map[action] or tostring(action or "?")
end

local function bindKey(d)
	return tostring(d.bindType or d.binding or "")
end

local function protectKey(d)
	return tostring(d.protected and "1" or "0")
end

---Aggregate stack rows that share item identity + action + strategy + bind/protect.
---Underlying bag/slot stacks remain in `stacks` for mail/vendor fidelity.
function CleanupService.Aggregate(results)
	results = results or {}
	local buckets = {}
	local order = {}
	for _, d in ipairs(results) do
		if d and d.itemString then
			local key = table.concat({
				tostring(d.itemString),
				tostring(d.inventoryAction or ""),
				tostring(d.strategy or ""),
				bindKey(d),
				protectKey(d),
				tostring(d.targetGroup or ""),
			}, "|")
			local b = buckets[key]
			if not b then
				b = {}
				for k, v in pairs(d) do
					b[k] = v
				end
				b.quantity = 0
				b.actionQty = 0
				b.stacks = {}
				b.stackCount = 0
				buckets[key] = b
				order[#order + 1] = key
			end
			local qty = d.actionQty or d.quantity or 1
			b.quantity = (b.quantity or 0) + (d.quantity or qty)
			b.actionQty = (b.actionQty or 0) + qty
			b.stackCount = (b.stackCount or 0) + 1
			b.stacks[#b.stacks + 1] = {
				bag = d.bag,
				slot = d.slot,
				qty = d.quantity or qty,
				link = d.link,
			}
			-- Keep first decision's pricing; sum not meaningful for rates
			if d.needsBankConfig then
				b.needsBankConfig = true
			end
		end
	end
	local out = {}
	for _, key in ipairs(order) do
		out[#out + 1] = buckets[key]
	end
	return out
end
