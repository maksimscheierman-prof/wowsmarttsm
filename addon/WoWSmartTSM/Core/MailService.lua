local Smart = WoWSmartTSM
local C = Smart:Module("Constants")
local Logger = Smart:Module("Logger")
local MailService = Smart:Module("MailService")

local private = {
	lastPlan = nil,
	sentTokens = {}, -- prevent double-mark
}

function MailService.GetCandidates(results)
	results = results or (Smart:GetModule("ScanService").GetLastResults() or {})
	local out = {}
	for _, d in ipairs(results) do
		if d and (d.inventoryAction == C.ACTIONS.MAIL_TO_BANK or d.inventoryAction == C.ACTIONS.HOLD_AT_BANK) then
			out[#out + 1] = d
		end
	end
	return out
end

---Build a send plan. Never marks as sent.
function MailService.BuildPlan(results)
	local CP = Smart:GetModule("CharacterProfiles")
	local Resolver = Smart:GetModule("CharacterResolver")
	local role = CP.GetRole and CP.GetRole() or "MAIN"
	if role == "BANK" then
		Logger.Warning("INVENTORY_ACTION_BLOCKED", "MailService", "BuildPlan", "BANK role does not mail to self")
		return {
			ok = false,
			code = "BANK_IS_SELF",
			messages = {},
			candidates = {},
		}
	end
	local mailOk, mailCode = true, nil
	if CP.CanMailToBank then
		mailOk, mailCode = CP.CanMailToBank()
	elseif Resolver and Resolver.CanMailToBank then
		mailOk, mailCode = Resolver.CanMailToBank()
	elseif not CP.IsBankConfigured() then
		mailOk, mailCode = false, "BANK_CHARACTER_NOT_CONFIGURED"
	end
	if not mailOk then
		Logger.Warning(mailCode or "BANK_CHARACTER_NOT_CONFIGURED", "MailService", "BuildPlan", tostring(mailCode))
		return {
			ok = false,
			code = mailCode or "BANK_CHARACTER_NOT_CONFIGURED",
			messages = {},
			candidates = {},
		}
	end
	if CP.SameFactionAsBank and not CP.SameFactionAsBank() then
		Logger.Warning("BANK_FACTION_MISMATCH", "MailService", "BuildPlan", "Faction mismatch with bank")
		return {
			ok = false,
			code = "BANK_FACTION_MISMATCH",
			messages = {},
			candidates = {},
		}
	end

	local recipient = CP.GetMailRecipientName()
	local candidates = MailService.GetCandidates(results)
	local maxAtt = C.MAIL_MAX_ATTACHMENTS or 12
	local messages = {}
	local batch = {}
	for _, d in ipairs(candidates) do
		-- Exclude non-mailable / missing bag slot
		if not d.bag or not d.slot then
			d.mailExcluded = "NO_BAG_SLOT"
		elseif d.protect and d.protect.protected then
			d.mailExcluded = "PROTECTED"
		else
			batch[#batch + 1] = d
			if #batch >= maxAtt then
				messages[#messages + 1] = { attachments = batch, recipient = recipient }
				batch = {}
			end
		end
	end
	if #batch > 0 then
		messages[#messages + 1] = { attachments = batch, recipient = recipient }
	end

	local plan = {
		ok = true,
		code = "OK",
		recipient = recipient,
		bankKey = CP.GetPrimaryBankKey(),
		messages = messages,
		candidates = candidates,
		totalAttachments = #candidates,
		messageCount = #messages,
		confirmed = false,
		executed = false,
		createdAt = (Smart:GetModule("TimeUtil").Now and Smart:GetModule("TimeUtil").Now()) or 0,
	}
	private.lastPlan = plan
	return plan
end

function MailService.GetLastPlan()
	return private.lastPlan
end

function MailService.IsMailboxOpen()
	return (MailFrame and MailFrame:IsShown()) or (SendMailFrame and SendMailFrame:IsShown()) or false
end

---Prepare one message into the send-mail UI (player must click Send).
---Uses SetSendMailCOD/SetSendMailMoney not required; SetSendMailShowing + ClickSendMailItemButton patterns vary.
---Forever-safe approach: fill recipient + attach via PickupContainerItem/ClickSendMailItemButton when available.
function MailService.PrepareMessage(messageIndex, opts)
	opts = opts or {}
	local plan = private.lastPlan
	if not plan or not plan.ok then
		return false, "NO_PLAN"
	end
	if not opts.confirmed then
		Logger.Warning("MAIL_NOT_POSSIBLE", "MailService", "PrepareMessage", "Confirmation required")
		return false, "CONFIRM_REQUIRED"
	end
	if plan.autoMailWithoutConfirm then
		return false, "AUTO_MAIL_FORBIDDEN"
	end
	local ch = Smart:GetModule("CharacterProfiles").GetCurrent()
	if ch and ch.autoMailWithoutConfirm then
		Logger.Warning("MAIL_NOT_POSSIBLE", "MailService", "PrepareMessage", "autoMailWithoutConfirm blocked")
		return false, "AUTO_MAIL_FORBIDDEN"
	end
	if not MailService.IsMailboxOpen() then
		Logger.Warning("MAIL_NOT_POSSIBLE", "MailService", "PrepareMessage", "Mailbox not open")
		return false, "MAILBOX_CLOSED"
	end
	local msg = plan.messages[messageIndex]
	if not msg then
		return false, "BAD_INDEX"
	end
	if SendMailNameEditBox then
		SendMailNameEditBox:SetText(msg.recipient or "")
	end
	-- Attach items one by one — each Pickup/Click is a legal API path; player still hits Send
	local attached = 0
	for i, d in ipairs(msg.attachments or {}) do
		local token = tostring(d.itemString) .. ":" .. tostring(d.bag) .. ":" .. tostring(d.slot)
		if private.sentTokens[token] then
			-- already prepared/sent in this session plan
		elseif d.bag and d.slot then
			local ok = false
			if PickupContainerItem then
				ok = pcall(PickupContainerItem, d.bag, d.slot)
			elseif C_Container and C_Container.PickupContainerItem then
				ok = pcall(C_Container.PickupContainerItem, d.bag, d.slot)
			end
			if ok and ClickSendMailItemButton then
				pcall(ClickSendMailItemButton, i)
				attached = attached + 1
			end
		end
	end
	msg.prepared = true
	msg.attached = attached
	Logger.Info("UNKNOWN", "MailService", "PrepareMessage", string.format(
		"Prepared mail #%d to %s attachments=%d — player must click Send",
		messageIndex,
		tostring(msg.recipient),
		attached
	))
	return true, msg
end

function MailService.MarkSent(token)
	if token then
		private.sentTokens[token] = true
	end
end

function MailService.ResetSentTokens()
	wipe(private.sentTokens)
end
