local Smart = WoWSmartTSM
local ItemProfile = Smart:Module("ItemProfile")
local Classify = Smart:Module("Classify")
local SkipAnalyzer = Smart:Module("SkipAnalyzer")
local Logger = Smart:Module("Logger")
local Engine = Smart:Module("Engine")

function Engine.EvaluateRaw(raw, tsmSkipToken)
	local ok, profileOrErr = pcall(ItemProfile.Build, raw)
	if not ok then
		Logger.Error("CLASSIFY_FAILED", "Engine", "EvaluateRaw", tostring(profileOrErr))
		return nil
	end
	local ok2, decisionOrErr = pcall(Classify.Decide, profileOrErr)
	if not ok2 then
		Logger.Error("CLASSIFY_FAILED", "Engine", "Decide", tostring(decisionOrErr), { itemId = profileOrErr.itemId })
		return nil
	end
	local decision = decisionOrErr
	-- Attach bag/slot for mail/vendor assist
	decision.bag = profileOrErr.bag or raw.bag
	decision.slot = profileOrErr.slot or raw.slot
	decision.link = profileOrErr.link or raw.link
	local ActionDecide = Smart:GetModule("ActionDecide")
	if ActionDecide and ActionDecide.Assign then
		local ok3, err3 = pcall(ActionDecide.Assign, decision, profileOrErr)
		if not ok3 then
			Logger.Error("CLASSIFY_FAILED", "Engine", "ActionDecide", tostring(err3), { itemId = profileOrErr.itemId })
			decision.inventoryAction = "MANUAL_REVIEW"
			decision.actionReasons = { "ACTION_DECIDE_FAILED" }
		end
	end
	if tsmSkipToken or (decision.pricing and not decision.pricing.shouldPost and decision.strategy ~= "VENDOR" and decision.strategy ~= "HOLD") then
		decision.skip = SkipAnalyzer.Analyze(profileOrErr, decision, tsmSkipToken)
	end
	return decision
end

function Engine.EvaluateMany(rawList)
	local out = {}
	for i, raw in ipairs(rawList or {}) do
		out[i] = Engine.EvaluateRaw(raw, raw.tsmSkipToken)
	end
	return out
end
