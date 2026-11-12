local Smart = WoWSmartTSM
local Protect = Smart:Module("Protect")
local Logger = Smart:Module("Logger")
local C = Smart:Module("Constants")
local VendorService = Smart:Module("VendorService")

---Safety check immediately before any vendor action.
function VendorService.PreSellCheck(profile)
	local can, st = Protect.CanAutoVendor(profile)
	if not can then
		Logger.Warning("VENDOR_BLOCKED", "VendorService", "PreSellCheck", table.concat(st.reasons or {}, ","), {
			itemId = profile.itemId,
		})
		return false, st
	end
	if (profile.vendorSell or 0) <= 0 then
		return false, { protected = true, reasons = { "VENDOR_SELL_ZERO" } }
	end
	-- Block hold-eligible rares from accidental vendor when flagged
	local HoldPolicy = Smart:GetModule("HoldPolicy")
	if HoldPolicy then
		local okHold, det = HoldPolicy.Evaluate(profile)
		if okHold then
			return false, { protected = true, reasons = { "HOLD_CANDIDATE" }, hold = det }
		end
	end
	return true, st
end

function VendorService.BuildCandidates(decisions)
	local list = {}
	for _, d in ipairs(decisions or {}) do
		if d and d.strategy == C.STRATEGIES.VENDOR then
			list[#list + 1] = d
		end
	end
	return list
end

---Dry-run or confirmed sell attempt. Never uses input automation.
---Actual UseContainerItem/SellCursorItem only when merchant open + confirmed + not dryRun.
function VendorService.SellSelected(candidates, opts)
	opts = opts or {}
	local dryRun = opts.dryRun
	if dryRun == nil then
		dryRun = WoWSmartTSM_DB and WoWSmartTSM_DB.settings and WoWSmartTSM_DB.settings.dryRunVendor
	end
	if not opts.confirmed then
		Logger.Warning("VENDOR_CONFIRM_REQUIRED", "VendorService", "SellSelected", "Confirmation required")
		return { sold = 0, blocked = #candidates, dryRun = dryRun }
	end
	if not MerchantFrame or not MerchantFrame:IsShown() then
		Logger.Warning("VENDOR_BLOCKED", "VendorService", "SellSelected", "Merchant frame not open")
		return { sold = 0, blocked = #candidates, reason = "NO_MERCHANT" }
	end

	local sold, blocked = 0, 0
	for _, d in ipairs(candidates or {}) do
		local profile = d -- decision carries needed fields
		local ok = VendorService.PreSellCheck(profile)
		if not ok then
			blocked = blocked + 1
		elseif dryRun then
			sold = sold + 1 -- counted as would-sell
		else
			-- Manual-assist path: we do not simulate clicks. Prefer container sell API if available and safe.
			if d.bag and d.slot and UseContainerItem then
				local pok = pcall(UseContainerItem, d.bag, d.slot)
				if pok then
					sold = sold + 1
				else
					blocked = blocked + 1
				end
			elseif d.bag and d.slot and C_Container and C_Container.UseContainerItem then
				local pok = pcall(C_Container.UseContainerItem, d.bag, d.slot)
				if pok then
					sold = sold + 1
				else
					blocked = blocked + 1
				end
			else
				blocked = blocked + 1
				Logger.Warning("VENDOR_BLOCKED", "VendorService", "SellSelected", "No bag slot for assisted sell", { itemId = d.itemId })
			end
		end
	end
	return { sold = sold, blocked = blocked, dryRun = dryRun and true or false }
end
