local Smart = WoWSmartTSM
local C = Smart:Module("Constants")
local ActionDecide = Smart:Module("ActionDecide")

--[[
  Separates sell strategy from inventory/transport action.

  MAIN:  rentable → MAIL_TO_BANK; hold → HOLD_AT_BANK; vendor → VENDOR; protect → KEEP
  BANK:  rentable → POST_AH;      hold → HOLD;         vendor → VENDOR; protect → KEEP
         never MAIL_TO_BANK / HOLD_AT_BANK (not even to self)
  MANUAL: same suggestions, automationAllowed=false
]]

local function reason(list, code)
	list[#list + 1] = code
end

local function logDecided(decision)
	local Logger = Smart:GetModule("Logger")
	-- Per-item decisions stay at DEBUG to avoid chat/log spam; blocked uses Warning.
	if Logger and Logger.Debug then
		Logger.Debug("INVENTORY_ACTION_DECIDED", "ActionDecide", "Assign", tostring(decision.inventoryAction), {
			state = {
				role = decision.role,
				strategy = decision.strategy,
				action = decision.inventoryAction,
				reasons = decision.actionReasons,
				itemId = decision.itemId,
			},
		})
	end
end

local function logBlocked(decision, code)
	local Logger = Smart:GetModule("Logger")
	if Logger and Logger.Warning then
		Logger.Warning("INVENTORY_ACTION_BLOCKED", "ActionDecide", "Assign", tostring(code), {
			state = {
				role = decision.role,
				strategy = decision.strategy,
				code = code,
				itemId = decision.itemId,
			},
		})
	end
end

function ActionDecide.Assign(decision, profile)
	decision = decision or {}
	profile = profile or {}
	local reasons = {}
	local CP = Smart:GetModule("CharacterProfiles")
	local Resolver = Smart:GetModule("CharacterResolver")
	local ItemRules = Smart:GetModule("ItemRules")
	local Consumables = Smart:GetModule("Consumables")
	local CraftingReserve = Smart:GetModule("CraftingReserve")

	local role = C.ROLES.MAIN
	local roleWhy = "DEFAULT"
	if Resolver and Resolver.GetEffectiveRole then
		role, roleWhy = Resolver.GetEffectiveRole()
	elseif CP and CP.GetRole then
		role = CP.GetRole()
	end

	local mailOk, mailBlock = false, "BANK_CHARACTER_NOT_CONFIGURED"
	if Resolver and Resolver.CanMailToBank then
		mailOk, mailBlock = Resolver.CanMailToBank()
	elseif CP and CP.CanMailToBank then
		mailOk, mailBlock = CP.CanMailToBank()
	elseif CP and CP.IsBankConfigured then
		mailOk = CP.IsBankConfigured()
		mailBlock = mailOk and nil or "BANK_CHARACTER_NOT_CONFIGURED"
	end

	local qty = profile.quantity or decision.quantity or 1
	decision.role = role
	decision.roleWhy = roleWhy
	decision.sellStrategy = decision.strategy
	decision.targetGroup = decision.targetGroup
	decision.protected = decision.protect and decision.protect.protected
	decision.actionQty = qty
	decision.keepQty = 0
	decision.surplusQty = qty
	decision.bankConfigured = (Resolver and Resolver.IsBankConfigured and Resolver.IsBankConfigured())
		or (CP and CP.IsBankConfigured and CP.IsBankConfigured())
		or false
	decision.canMailToBank = mailOk and true or false
	decision.mailBlockCode = mailBlock
	decision.bankKey = (Resolver and Resolver.GetPrimaryBankKey and Resolver.GetPrimaryBankKey())
		or (CP and CP.GetPrimaryBankKey and CP.GetPrimaryBankKey())
		or nil
	decision.needsBankConfig = false
	decision.actionStatus = "suggested" -- suggested | prepared | confirmed | executed

	local function finish(action, conf)
		decision.inventoryAction = action
		decision.actionReasons = reasons
		decision.actionConfidence = conf or decision.confidence or 0
		if role == C.ROLES.MANUAL and action ~= C.ACTIONS.MANUAL_REVIEW and action ~= C.ACTIONS.IGNORE and action ~= C.ACTIONS.KEEP then
			reason(reasons, "MANUAL_ROLE_NO_AUTO")
			decision.automationAllowed = false
		else
			decision.automationAllowed = (role ~= C.ROLES.MANUAL)
		end
		-- Hard guarantee: BANK never mails to bank
		if role == C.ROLES.BANK then
			if action == C.ACTIONS.MAIL_TO_BANK or action == C.ACTIONS.HOLD_AT_BANK then
				reason(reasons, "BANK_NO_SELF_MAIL")
				action = (decision.strategy == C.STRATEGIES.HOLD) and C.ACTIONS.HOLD or C.ACTIONS.POST_AH
				decision.inventoryAction = action
			end
		end
		logDecided(decision)
		return decision
	end

	-- 1) Hard protect / unknown
	if profile.unknownIdentity or (decision.protect and decision.protect.protected) then
		reason(reasons, "HARD_PROTECT")
		return finish(C.ACTIONS.KEEP, 1)
	end
	if decision.strategy == C.STRATEGIES.MANUAL_REVIEW and profile.unknownIdentity then
		return finish(C.ACTIONS.MANUAL_REVIEW, 0.2)
	end

	-- 2) Item rules
	if ItemRules and ItemRules.AppliesIgnore and ItemRules.AppliesIgnore(profile.itemString) then
		reason(reasons, "RULE_IGNORE")
		return finish(C.ACTIONS.IGNORE, 1)
	end
	if ItemRules and ItemRules.AppliesKeep then
		local keep, keepAmt = ItemRules.AppliesKeep(profile.itemString, qty)
		if keep and keepAmt >= qty then
			reason(reasons, "RULE_KEEP")
			decision.keepQty = qty
			decision.surplusQty = 0
			return finish(C.ACTIONS.KEEP, 1)
		elseif keepAmt and keepAmt > 0 and keepAmt < qty then
			decision.keepQty = keepAmt
			decision.surplusQty = qty - keepAmt
			reason(reasons, "RULE_MIN_KEEP_SURPLUS")
			qty = decision.surplusQty
		end
	end

	-- 3) Crafting reserves
	if CraftingReserve and CraftingReserve.SplitQuantity then
		local k, s = CraftingReserve.SplitQuantity(profile, qty)
		if k > 0 and s == 0 then
			reason(reasons, "CRAFTING_RESERVE")
			decision.keepQty = (decision.keepQty or 0) + k
			decision.surplusQty = 0
			return finish(C.ACTIONS.KEEP, 0.95)
		elseif k > 0 then
			decision.keepQty = (decision.keepQty or 0) + k
			decision.surplusQty = s
			qty = s
			reason(reasons, "CRAFTING_RESERVE_PARTIAL")
		end
	end

	-- 4) Consumables
	if Consumables and Consumables.SplitQuantity then
		local k, s, needsConfig, protectAll = Consumables.SplitQuantity(profile, qty)
		if protectAll or (k > 0 and s == 0) then
			reason(reasons, needsConfig and "CONSUMABLE_NEEDS_MIN_CONFIG" or "CONSUMABLE_KEEP")
			decision.keepQty = (decision.keepQty or 0) + k
			decision.surplusQty = 0
			decision.needsConsumableConfig = needsConfig
			return finish(C.ACTIONS.KEEP, needsConfig and 0.6 or 0.95)
		elseif k > 0 then
			decision.keepQty = (decision.keepQty or 0) + k
			decision.surplusQty = s
			qty = s
			reason(reasons, "CONSUMABLE_SURPLUS")
		end
	end

	decision.actionQty = qty
	local strat = decision.strategy

	-- ========== BANK ==========
	if role == C.ROLES.BANK then
		if strat == C.STRATEGIES.HOLD then
			reason(reasons, "BANK_HOLD_STORAGE")
			return finish(C.ACTIONS.HOLD, 0.9)
		end
		if strat == C.STRATEGIES.VENDOR then
			reason(reasons, "BANK_VENDOR")
			return finish(C.ACTIONS.VENDOR, decision.confidence or 0.7)
		end
		if strat == C.STRATEGIES.QUICK_SELL or strat == C.STRATEGIES.PROFIT_SELL or strat == C.STRATEGIES.RARE_SELL then
			reason(reasons, "BANK_READY_TO_POST")
			return finish(C.ACTIONS.POST_AH, decision.confidence or 0.8)
		end
		reason(reasons, "BANK_REVIEW")
		return finish(C.ACTIONS.MANUAL_REVIEW, 0.4)
	end

	-- ========== MAIN / MANUAL (suggestion path) ==========
	if strat == C.STRATEGIES.HOLD then
		local ch = CP and CP.GetCurrent and CP.GetCurrent()
		if ch and ch.smartHoldToBank == false then
			reason(reasons, "HOLD_KEEP_ON_MAIN")
			return finish(C.ACTIONS.KEEP, 0.85)
		end
		if not mailOk then
			reason(reasons, mailBlock or "BANK_CHARACTER_NOT_CONFIGURED")
			decision.needsBankConfig = (mailBlock == "BANK_CHARACTER_NOT_CONFIGURED")
			logBlocked(decision, mailBlock or "BANK_CHARACTER_NOT_CONFIGURED")
			return finish(C.ACTIONS.MANUAL_REVIEW, 0.5)
		end
		reason(reasons, "HOLD_AT_BANK")
		return finish(C.ACTIONS.HOLD_AT_BANK, 0.9)
	end

	if strat == C.STRATEGIES.VENDOR then
		reason(reasons, "VENDOR_ON_MAIN")
		return finish(C.ACTIONS.VENDOR, decision.confidence or 0.7)
	end

	if strat == C.STRATEGIES.QUICK_SELL or strat == C.STRATEGIES.PROFIT_SELL or strat == C.STRATEGIES.RARE_SELL then
		if not mailOk then
			reason(reasons, mailBlock or "BANK_CHARACTER_NOT_CONFIGURED")
			decision.needsBankConfig = (mailBlock == "BANK_CHARACTER_NOT_CONFIGURED")
			logBlocked(decision, mailBlock or "BANK_CHARACTER_NOT_CONFIGURED")
			-- Sell strategy still visible; only bank transport blocked
			return finish(C.ACTIONS.MANUAL_REVIEW, 0.55)
		end
		reason(reasons, "MAIL_TO_BANK_FOR_AH")
		return finish(C.ACTIONS.MAIL_TO_BANK, decision.confidence or 0.8)
	end

	reason(reasons, "FALLBACK_REVIEW")
	return finish(C.ACTIONS.MANUAL_REVIEW, 0.3)
end
