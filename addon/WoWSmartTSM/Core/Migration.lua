local Smart = WoWSmartTSM
local C = Smart:Module("Constants")
local Groups = Smart:Module("Groups")
local Logger = Smart:Module("Logger")
local History = Smart:Module("History")
local Migration = Smart:Module("Migration")

--[[
  Owner migration (v0.2.7):
    Replace: 1er Group, 20er AH Sell
    Keep:    Auto Vendeor ALL (never migrate / never delete)
    Create:  Smart Quick/Profit/Rare/Hold/Ignore (+ root) — NOT Smart Vendor
  Apply path: TSM Import string only. No private TSM table writes.
  Deletion of old sell groups requires a second explicit owner confirm.
]]

local REPLACE = {
	["1er Group"] = true,
	["20er AH Sell"] = true,
}
local KEEP = {
	["Auto Vendeor ALL"] = true,
}

local SELL_GROUPS = {
	C.GROUPS.QUICK,
	C.GROUPS.PROFIT,
	C.GROUPS.RARE,
	C.GROUPS.HOLD,
	C.GROUPS.IGNORE,
}

local private = {
	lastBackup = nil,
	lastPlan = nil,
	lastReport = nil,
}

local function store()
	WoWSmartTSM_DB = WoWSmartTSM_DB or {}
	WoWSmartTSM_DB.migration = WoWSmartTSM_DB.migration or {
		backups = {},
		deleteMarkers = {
			["1er Group"] = { marked = false, ownerDeleteConfirm = false },
			["20er AH Sell"] = { marked = false, ownerDeleteConfirm = false },
			["Auto Vendeor ALL"] = { marked = false, ownerDeleteConfirm = false },
		},
		lastImportString = nil,
		verifiedAt = nil,
	}
	return WoWSmartTSM_DB.migration
end

function Migration.ReplaceGroupNames()
	return { "1er Group", "20er AH Sell" }
end

function Migration.KeepGroupNames()
	return { "Auto Vendeor ALL" }
end

function Migration.IsKeepGroup(path)
	return path and KEEP[path] == true
end

function Migration.IsReplaceGroup(path)
	return path and REPLACE[path] == true
end

---Live backup via public TSM_API reads only.
function Migration.BackupLive()
	local backup = {
		at = time(),
		paths = {},
		groups = {},
		claim = "VERIFIED_READ_ONLY",
	}
	for _, path in ipairs(Groups.ListPaths()) do
		backup.paths[#backup.paths + 1] = path
		local items = Groups.GetItemsInGroup(path, false)
		backup.groups[path] = {
			itemCount = #items,
			items = items,
			isReplace = REPLACE[path] == true,
			isKeep = KEEP[path] == true,
		}
	end
	local db = store()
	db.backups[#db.backups + 1] = {
		at = backup.at,
		pathCount = #backup.paths,
		replaceCounts = {
			["1er Group"] = backup.groups["1er Group"] and backup.groups["1er Group"].itemCount or 0,
			["20er AH Sell"] = backup.groups["20er AH Sell"] and backup.groups["20er AH Sell"].itemCount or 0,
			["Auto Vendeor ALL"] = backup.groups["Auto Vendeor ALL"] and backup.groups["Auto Vendeor ALL"].itemCount or 0,
		},
	}
	while #db.backups > 5 do
		table.remove(db.backups, 1)
	end
	private.lastBackup = backup
	Logger.Info("UNKNOWN", "Migration", "BackupLive", "Live group backup stored (" .. tostring(#backup.paths) .. " paths)")
	return backup
end

local function classifyItem(itemString, fromGroup)
	local Prices = Smart:GetModule("Prices")
	local ItemProfile = Smart:GetModule("ItemProfile")
	local Classify = Smart:GetModule("Classify")
	local ItemAPI = Smart:GetModule("ItemAPI")
	local Freshness = Smart:GetModule("Freshness")

	local itemId = tonumber(tostring(itemString):match("i:(%d+)")) or tonumber(tostring(itemString):match("item:(%d+)"))
	local name, quality, className, subclassName
	if ItemAPI and ItemAPI.GetInfo then
		local info = ItemAPI.GetInfo(itemId or itemString)
		if info then
			name = info.name
			quality = info.quality
			className = info.className
			subclassName = info.subclassName
			itemId = itemId or info.itemId
		end
	end

	local sources = (Prices and Prices.Collect and Prices.Collect(itemString)) or {}

	local raw = {
		itemString = itemString,
		itemId = itemId,
		name = name,
		quality = quality or 0,
		className = className,
		subclassName = subclassName,
		quantity = 1,
		stackSize = (fromGroup == "20er AH Sell") and 20 or 1,
		currentGroup = fromGroup,
		dbMarket = sources.dbMarket,
		dbMinBuyout = sources.dbMinBuyout,
		dbRegionMarketAvg = sources.dbRegionMarketAvg,
		dbRegionSaleRate = sources.dbRegionSaleRate,
		dbRegionSoldPerDay = sources.dbRegionSoldPerDay,
		vendorSell = sources.vendorSell or 0,
		numAuctions = sources.numAuctions,
		dataTimestamp = sources.dataTimestamp,
		freshness = sources.freshness or (Freshness and Freshness.GetReport and Freshness.GetReport()) or nil,
		metaIncomplete = (name == nil),
	}

	if ItemProfile and ItemProfile.Build and Classify and Classify.Decide then
		local profile = ItemProfile.Build(raw)
		local decision = Classify.Decide(profile)
		local target = decision.targetGroup
		-- Never route migration into Smart Vendor — keep Auto Vendeor ALL as sole vendor group
		if target == C.GROUPS.VENDOR then
			target = C.GROUPS.PROFIT
			return target, "VENDOR_REMAPPED_TO_PROFIT_KEEP_AUTO_VENDOR", decision.strategy, (fromGroup == "20er AH Sell") and "stack20" or "single"
		end
		if target == C.GROUPS.REVIEW then
			-- Prefer sell groups from source heuristic when data weak
			if fromGroup == "1er Group" then
				target = C.GROUPS.RARE
			else
				target = C.GROUPS.QUICK
			end
			return target, "REVIEW_FALLBACK_SOURCE", decision.strategy, (fromGroup == "20er AH Sell") and "stack20" or "single"
		end
		return target, table.concat(decision.reasons or { "CLASSIFY" }, ","), decision.strategy, (fromGroup == "20er AH Sell") and "stack20" or "single"
	end

	-- Offline / missing modules
	if fromGroup == "1er Group" then
		return C.GROUPS.RARE, "HEURISTIC_1ER", "RARE_SELL", "single"
	end
	return C.GROUPS.QUICK, "HEURISTIC_20ER", "QUICK_SELL", "stack20"
end

---Build migration plan from live TSM group membership.
function Migration.BuildPlan(opts)
	opts = opts or {}
	local backup = private.lastBackup or Migration.BackupLive()
	local moves = {}
	local skipped = {}
	local counts = { byFrom = {}, byTo = {}, keptVendor = 0 }

	for fromGroup, _ in pairs(REPLACE) do
		counts.byFrom[fromGroup] = 0
		local items = {}
		if backup.groups[fromGroup] then
			items = backup.groups[fromGroup].items or {}
		else
			items = Groups.GetItemsInGroup(fromGroup, false)
		end
		for _, itemString in ipairs(items) do
			local to, reason, strategy, stackHint = classifyItem(itemString, fromGroup)
			moves[#moves + 1] = {
				itemString = itemString,
				fromGroup = fromGroup,
				toGroup = to,
				reason = reason,
				strategy = strategy,
				stackHint = stackHint,
			}
			counts.byFrom[fromGroup] = counts.byFrom[fromGroup] + 1
			counts.byTo[to] = (counts.byTo[to] or 0) + 1
		end
	end

	-- Explicitly record kept vendor items (no moves)
	local vendorItems = Groups.GetItemsInGroup("Auto Vendeor ALL", false)
	counts.keptVendor = #vendorItems
	for _, itemString in ipairs(vendorItems) do
		skipped[#skipped + 1] = {
			itemString = itemString,
			group = "Auto Vendeor ALL",
			reason = "KEEP_VENDOR_UNCHANGED",
		}
	end

	local missingSmart = {}
	for _, path in ipairs(SELL_GROUPS) do
		if not Groups.SmartGroupExists(path) then
			missingSmart[#missingSmart + 1] = path
		end
	end
	if not Groups.SmartGroupExists(C.SMART_ROOT) then
		table.insert(missingSmart, 1, C.SMART_ROOT)
	end

	local plan = {
		at = time(),
		moves = moves,
		skipped = skipped,
		counts = counts,
		missingSmart = missingSmart,
		createSmartVendor = false,
		deleteMarkers = {
			["1er Group"] = { markedAfterVerify = false, ownerDeleteConfirm = false },
			["20er AH Sell"] = { markedAfterVerify = false, ownerDeleteConfirm = false },
			["Auto Vendeor ALL"] = { markedAfterVerify = false, ownerDeleteConfirm = false, neverDelete = true },
		},
		openSteps = {
			"Shift-confirm Import vorbereiten",
			"String in TSM Groups → Import einfügen",
			"Verify ausführen",
			"Auctioning-Ops in TSM manuell zuweisen (Single/Stack Formeln)",
			"Owner-Bestätigung vor Löschen von 1er Group / 20er AH Sell",
		},
	}
	plan.importString = Groups.BuildImportString(moves, { emptyGroupPaths = missingSmart })
	private.lastPlan = plan
	store().lastPlanSummary = {
		at = plan.at,
		moveCount = #moves,
		keptVendor = counts.keptVendor,
		byTo = counts.byTo,
	}
	return plan
end

function Migration.GetLastPlan()
	return private.lastPlan
end

function Migration.GetLastBackup()
	return private.lastBackup
end

---Prepare import string (Shift required). Does not delete anything.
function Migration.PrepareImport(shiftHeld)
	local plan = private.lastPlan or Migration.BuildPlan()
	if not shiftHeld then
		return false, plan, { error = "NEED_SHIFT" }
	end
	local db = store()
	db.lastImportString = plan.importString
	WoWSmartTSM_DB.lastGroupImportString = plan.importString
	History.Add("MIGRATION_IMPORT_PREPARED", { count = #(plan.moves or {}) })
	Logger.Info("UNKNOWN", "Migration", "PrepareImport", "Import prepared for " .. tostring(#(plan.moves or {})) .. " items")
	return true, plan, { mode = "IMPORT_STRING", importString = plan.importString }
end

function Migration.Verify()
	local plan = private.lastPlan
	if not plan then
		return {}, { error = "NO_PLAN" }
	end
	local okList, bad = Groups.VerifyMoves(plan.moves)
	store().verifiedAt = time()
	if #bad == 0 and #okList > 0 then
		-- Mark old sell groups for deletion — still requires owner confirm to actually delete
		local markers = store().deleteMarkers
		markers["1er Group"].marked = true
		markers["1er Group"].ownerDeleteConfirm = false
		markers["20er AH Sell"].marked = true
		markers["20er AH Sell"].ownerDeleteConfirm = false
		markers["Auto Vendeor ALL"].marked = false
		if plan.deleteMarkers then
			plan.deleteMarkers["1er Group"].markedAfterVerify = true
			plan.deleteMarkers["20er AH Sell"].markedAfterVerify = true
		end
		History.Add("MIGRATION_VERIFIED", { ok = #okList, failed = 0 })
	else
		History.Add("MIGRATION_VERIFY_PARTIAL", { ok = #okList, failed = #bad })
	end
	return okList, bad
end

---Hard stop: never auto-delete. Returns false until ownerDeleteConfirm set by owner command.
function Migration.ConfirmDeleteOldSellGroups(ownerPhrase)
	local db = store()
	if ownerPhrase ~= "OWNER_CONFIRM_DELETE_OLD_SELL_GROUPS" then
		Logger.Warning(
			"UNKNOWN",
			"Migration",
			"ConfirmDeleteOldSellGroups",
			"Refused — need exact owner phrase; no TSM group delete performed"
		)
		return false, "NEED_OWNER_PHRASE"
	end
	-- Even with phrase: Smart TSM has no safe public DeleteGroup API — instruct manual delete
	db.deleteMarkers["1er Group"].ownerDeleteConfirm = true
	db.deleteMarkers["20er AH Sell"].ownerDeleteConfirm = true
	print("|cff4ecdc4[SmartTSM]|r Owner-Löschfreigabe gesetzt.")
	print("|cffffcc00Lösche in TSM manuell: 1er Group und 20er AH Sell (nach Verify). Auto Vendeor ALL behalten.|r")
	print("|cffffcc00Smart TSM löscht Gruppen nicht per API (4.15.6).|r")
	return true, "MANUAL_DELETE_IN_TSM"
end

function Migration.BuildReportText()
	local plan = private.lastPlan or Migration.BuildPlan()
	local lines = {
		"=== Smart TSM Migration Report ===",
		"Replace: 1er Group, 20er AH Sell",
		"Keep: Auto Vendeor ALL",
		"Create Smart Vendor: NO",
		string.format("Moves: %d | Vendor kept: %d", #(plan.moves or {}), plan.counts and plan.counts.keptVendor or 0),
	}
	if plan.counts and plan.counts.byTo then
		for g, n in pairs(plan.counts.byTo) do
			lines[#lines + 1] = string.format("  → %s: %d", tostring(g), n)
		end
	end
	lines[#lines + 1] = "Delete old sell groups: MARK only after verify; owner confirm required"
	lines[#lines + 1] = "Open: " .. table.concat(plan.openSteps or {}, " | ")
	private.lastReport = table.concat(lines, "\n")
	return private.lastReport, plan
end

-- Documented op formulas from owner SV (read-only extract)
Migration.DOCUMENTED_OPS = {
	single = {
		name = "Smart Single Sell",
		sourceGroup = "1er Group",
		minPrice = "check(first(crafting,dbmarket,dbregionmarketavg),max(0.5*first(dbmarket,dbregionmarketavg,crafting),2.11*vendorsell))",
		normalPrice = "check(first(crafting,dbmarket,dbregionmarketavg),max(first(dbmarket,dbregionmarketavg,crafting),3*vendorsell))",
		maxPrice = "check(first(crafting,dbmarket,dbregionmarketavg),max(2*first(dbmarket,dbregionmarketavg,crafting),5*vendorsell))",
		postCap = "1",
		duration = "3",
		undercut = "0c",
		stackHint = "single",
	},
	stack = {
		name = "Smart Stack Sell",
		sourceGroup = "20er AH Sell",
		minPrice = "check(first(crafting,dbmarket,dbregionmarketavg),max(0.5*first(dbmarket,dbregionmarketavg,crafting),2.11*vendorsell))",
		normalPrice = "check(first(crafting,dbmarket,dbregionmarketavg),max(first(dbmarket,dbregionmarketavg,crafting),3*vendorsell))",
		maxPrice = "check(first(crafting,dbmarket,dbregionmarketavg),max(2*first(dbmarket,dbregionmarketavg,crafting),5*vendorsell))",
		postCap = "5",
		duration = "2",
		undercut = "0c",
		stackHint = "stack_mats",
	},
	vendorKeep = {
		name = "AHeqVendorPriceAutoSell",
		sourceGroup = "Auto Vendeor ALL",
		vsMarketValue = "150% vendorsell",
		enableSell = true,
		unchanged = true,
	},
}
