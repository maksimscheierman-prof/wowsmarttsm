local Smart = WoWSmartTSM
local C = Smart:Module("Constants")
local Groups = Smart:Module("Groups")
local Operations = Smart:Module("Operations")
local Logger = Smart:Module("Logger")
local History = Smart:Module("History")
local GroupManager = Smart:Module("GroupManager")

--[[
  Smart Group Manager (v0.2.4)
  - Live TSM group reads (never stale Smart cache for group path)
  - Propose Safe / Review / Protected
  - One-click safe apply → preview → confirm → import/direct → verify → undo
  - Never overwrite non-Smart user groups without explicit force
]]

local STATUS = {
	SAFE = "SAFE",
	REVIEW = "REVIEW",
	PROTECTED = "PROTECTED",
}

local private = {
	lastProposals = nil,
	lastPreview = nil,
	lastApplyMeta = nil,
	pendingConfirm = nil,
}

local function strategyToGroup(strategy)
	return Groups.STRATEGY_TO_GROUP[strategy]
end

local function isProtectedDecision(d)
	if not d then
		return true
	end
	if d.inventoryAction == C.ACTIONS.KEEP and d.needsConsumableConfig then
		-- optional reserve not configured is protect-all on MAIN — not auto-group
		return true
	end
	if d.inventoryAction == C.ACTIONS.KEEP then
		local reasons = d.actionReasons or d.reasons or {}
		for _, r in ipairs(reasons) do
			if
				r == "PROTECTED"
				or r == "KEEP_RULE"
				or r == "CRAFTING_RESERVE"
				or r == "CONSUMABLE_KEEP"
				or r == "EQUIPPED"
				or r == "SOULBOUND"
			then
				return true
			end
		end
	end
	if d.inventoryAction == C.ACTIONS.IGNORE or d.strategy == nil then
		return true
	end
	return false
end

local function isHighValueUnsafe(d)
	if d.skip and (d.skip.code == "NO_MARKET_DATA" or d.skip.code == "STALE_DATA") then
		return true
	end
	if d.strategy == C.STRATEGIES.HOLD then
		-- Hold is rare; auto-group only into HOLD if already classified HOLD and not protected
		return false
	end
	-- Never auto-vendor high value without market
	if d.strategy == C.STRATEGIES.VENDOR then
		local mv = d.marketValue or d.dbMarket or 0
		local vv = d.vendorValue or 0
		if (not mv or mv <= 0) and vv > 0 then
			return true
		end
		if mv and mv >= C.HOLD_MIN_MARKET_COPPER then
			return true
		end
	end
	return false
end

---Build proposal rows from scan decisions. Always re-reads live TSM group path.
function GroupManager.BuildProposals(results, opts)
	opts = opts or {}
	local CP = Smart:GetModule("CharacterProfiles")
	local role = (CP and CP.GetRole and CP.GetRole()) or C.ROLES.MAIN
	local rows = {}
	for _, d in ipairs(results or {}) do
		if d and d.itemString then
			local liveGroup = Groups.GetPathByItem(d.itemString)
			local proposed = strategyToGroup(d.strategy) or d.targetGroup
			if d.inventoryAction == C.ACTIONS.IGNORE then
				proposed = C.GROUPS.IGNORE
			end
			local status = STATUS.SAFE
			local reasonBits = {}

			if isProtectedDecision(d) then
				status = STATUS.PROTECTED
				reasonBits[#reasonBits + 1] = "Geschützt / behalten"
			elseif isHighValueUnsafe(d) then
				status = STATUS.REVIEW
				reasonBits[#reasonBits + 1] = "Hochwertig oder unsichere Preisdaten"
			elseif role == C.ROLES.MANUAL then
				status = STATUS.REVIEW
				reasonBits[#reasonBits + 1] = "MANUAL: keine Auto-Übernahme"
			elseif liveGroup and liveGroup ~= "" and not Groups.IsSmartGroup(liveGroup) then
				-- Existing manual user group — do not overwrite without force
				status = STATUS.REVIEW
				reasonBits[#reasonBits + 1] = "Bestehende Nutzergruppe: " .. tostring(liveGroup)
			elseif liveGroup and proposed and liveGroup == proposed then
				status = STATUS.SAFE
				reasonBits[#reasonBits + 1] = "Bereits korrekt gruppiert"
			elseif not proposed then
				status = STATUS.REVIEW
				reasonBits[#reasonBits + 1] = "Keine Zielgruppe für Strategie"
			elseif d.strategy == C.STRATEGIES.MANUAL_REVIEW then
				status = STATUS.REVIEW
				reasonBits[#reasonBits + 1] = "Manuelle Prüfung empfohlen"
			else
				status = STATUS.SAFE
				reasonBits[#reasonBits + 1] = table.concat(d.actionReasons or d.reasons or { "OK" }, ", ")
			end

			-- Already correct → not an apply candidate
			local alreadyOk = liveGroup and proposed and liveGroup == proposed
			local opName = Operations.RecommendAuctioningOp(d.strategy)
			rows[#rows + 1] = {
				itemString = d.itemString,
				name = d.name,
				quantity = d.quantity or 1,
				link = d.link,
				itemId = d.itemId,
				currentGroup = liveGroup,
				proposedGroup = proposed,
				strategy = d.strategy,
				inventoryAction = d.inventoryAction,
				operation = opName,
				status = status,
				reason = table.concat(reasonBits, "; "),
				alreadyOk = alreadyOk and true or false,
				decision = d,
				role = role,
			}
		end
	end
	private.lastProposals = rows
	return rows
end

function GroupManager.GetLastProposals()
	return private.lastProposals or {}
end

function GroupManager.FilterSafe(proposals, opts)
	opts = opts or {}
	local cleaned = {}
	for _, p in ipairs(proposals or {}) do
		if p.status == STATUS.SAFE and not p.alreadyOk and p.proposedGroup then
			if p.strategy == C.STRATEGIES.HOLD and opts.excludeHold then
				-- optional: exclude rare hold from bulk (default includes SAFE hold)
			else
				cleaned[#cleaned + 1] = p
			end
		end
	end
	return cleaned
end

function GroupManager.Preview(proposals)
	local safe = GroupManager.FilterSafe(proposals)
	local preview = {
		safeCount = #safe,
		reviewCount = 0,
		protectedCount = 0,
		alreadyOk = 0,
		moves = {},
		missingGroups = Groups.MissingSmartGroups(),
		capabilities = Groups.ProbeCapabilities(),
		opsCap = Operations.ProbeCapabilities(),
	}
	for _, p in ipairs(proposals or {}) do
		if p.alreadyOk then
			preview.alreadyOk = preview.alreadyOk + 1
		elseif p.status == STATUS.REVIEW then
			preview.reviewCount = preview.reviewCount + 1
		elseif p.status == STATUS.PROTECTED then
			preview.protectedCount = preview.protectedCount + 1
		end
	end
	for _, p in ipairs(safe) do
		preview.moves[#preview.moves + 1] = {
			itemString = p.itemString,
			name = p.name,
			fromGroup = p.currentGroup,
			toGroup = p.proposedGroup,
			strategy = p.strategy,
		}
	end
	preview.importString = Groups.BuildImportString(preview.moves, {
		includeEmptyGroups = #preview.missingGroups > 0,
	})
	private.lastPreview = preview
	return preview
end

function GroupManager.GetLastPreview()
	return private.lastPreview
end

---Stage confirm: requires IsShiftKeyDown on apply.
function GroupManager.StageSafeApply(proposals)
	local preview = GroupManager.Preview(proposals)
	private.pendingConfirm = preview
	return preview
end

function GroupManager.ConfirmSafeApply(shiftHeld)
	local preview = private.pendingConfirm or private.lastPreview
	if not preview or not preview.moves or #preview.moves == 0 then
		return false, {}, { error = "NO_MOVES" }
	end
	if not shiftHeld then
		return false, {}, { error = "NEED_SHIFT", preview = preview }
	end
	local CP = Smart:GetModule("CharacterProfiles")
	local role = CP and CP.GetRole and CP.GetRole() or C.ROLES.MAIN
	if role == C.ROLES.MANUAL then
		Logger.Warning("GROUP_MOVE_FAILED", "GroupManager", "ConfirmSafeApply", "MANUAL role blocks auto apply")
		return false, {}, { error = "MANUAL_ROLE" }
	end

	local ok, applied, meta = Groups.ApplyMoves(preview.moves, {
		includeEmptyGroups = #(preview.missingGroups or {}) > 0,
	})
	private.lastApplyMeta = meta
	private.pendingConfirm = nil

	-- Live verify when direct write; for import mode report pending
	local verified, failed = {}, {}
	if meta and meta.mode == "IMPORT_STRING" then
		History.Add("GROUP_IMPORT_PREPARED", {
			count = #(applied or {}),
			mode = meta.mode,
		})
		return ok, applied, meta
	end
	verified, failed = Groups.VerifyMoves(preview.moves)
	meta.verified = verified
	meta.verifyFailed = failed
	if #failed > 0 then
		Logger.Warning(
			"GROUP_MOVE_FAILED",
			"GroupManager",
			"ConfirmSafeApply",
			tostring(#failed) .. " moves not reflected in TSM after apply"
		)
	end
	History.Add("GROUP_APPLY", { count = #(applied or {}), ok = ok, failed = #failed })
	return ok, applied, meta
end

function GroupManager.GetLastApplyMeta()
	return private.lastApplyMeta
end

function GroupManager.StatusLabel(status)
	if status == STATUS.SAFE then
		return "Sicher"
	end
	if status == STATUS.REVIEW then
		return "Prüfen"
	end
	if status == STATUS.PROTECTED then
		return "Geschützt"
	end
	return tostring(status or "?")
end

function GroupManager.GroupLabel(path)
	if not path or path == "" then
		return "Keine Gruppe"
	end
	return path
end

GroupManager.STATUS = STATUS
