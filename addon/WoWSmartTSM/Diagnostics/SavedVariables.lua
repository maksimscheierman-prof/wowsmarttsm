local Smart = WoWSmartTSM
local C = Smart:Module("Constants")
local Logger = Smart:Module("Logger")
local Version = Smart:Module("Version")
local Time = Smart:Module("TimeUtil")
local SV = Smart:Module("SavedVariables")

local function defaultsDB()
	return {
		schemaVersion = C.SV_SCHEMA_VERSION,
		settings = {
			locale = "deDE",
			ahCut = C.DEFAULT_AH_CUT,
			depositRateFallback = C.DEFAULT_DEPOSIT_RATE,
			auctionHours = C.DEFAULT_AUCTION_HOURS,
			dataMaxAgeSeconds = C.DATA_MAX_AGE_SECONDS,
			minExpectedNetCopper = 0,
			dryRunVendor = true,
			openUIAfterScan = false,
			debug = false,
			frame = { point = "CENTER", x = 0, y = 0, width = 960, height = 640, scale = 1 },
			columns = {},
		},
		alwaysKeep = {},
		reservedCrafting = {},
		characters = {},
		profile = {
			primaryBankKey = nil,
			bankKeys = {},
		},
		itemRules = {
			account = {},
			characters = {},
			sessionIgnore = {},
		},
		consumableMins = {},
		craftingReserves = {},
		history = {},
		undoStack = {},
		lastScan = nil,
		mailPlans = {},
	}
end

local function defaultsDiag()
	return {
		schemaVersion = C.DIAG_SCHEMA_VERSION,
		addonVersion = Version.STRING,
		created = Time.Now(),
		lastWrite = Time.Now(),
		sessionId = nil,
		entries = {},
		dedupe = {},
		coverage = {},
		health = { status = "unknown", issues = {} },
	}
end

local migrationsDB = {
	[1] = function(db)
		db.schemaVersion = 1
		return db
	end,
	[2] = function(db)
		-- v0.2.0 multi-character fields
		db.characters = db.characters or {}
		db.profile = db.profile or { primaryBankKey = nil, bankKeys = {} }
		db.itemRules = db.itemRules or { account = {}, characters = {}, sessionIgnore = {} }
		db.consumableMins = db.consumableMins or {}
		db.craftingReserves = db.craftingReserves or {}
		db.mailPlans = db.mailPlans or {}
		db.settings = db.settings or {}
		db.schemaVersion = 2
		return db
	end,
}

local migrationsDiag = {
	[1] = function(diag)
		diag.schemaVersion = 1
		return diag
	end,
}

local function migrate(store, migrations, target, label)
	if type(store) ~= "table" then
		return nil, "corrupt"
	end
	local ver = tonumber(store.schemaVersion) or 0
	while ver < target do
		local nextVer = ver + 1
		local fn = migrations[nextVer]
		if not fn then
			return nil, "missing migration " .. tostring(nextVer)
		end
		local ok, result = pcall(fn, store)
		if not ok then
			return nil, result
		end
		store = result or store
		store.schemaVersion = nextVer
		ver = nextVer
	end
	return store
end

local function deepMergeMissing(dst, src)
	for k, v in pairs(src) do
		if dst[k] == nil then
			dst[k] = v
		elseif type(v) == "table" and type(dst[k]) == "table" then
			deepMergeMissing(dst[k], v)
		end
	end
end

function SV.Init()
	if type(WoWSmartTSM_DB) ~= "table" then
		WoWSmartTSM_DB = defaultsDB()
	else
		local migrated, err = migrate(WoWSmartTSM_DB, migrationsDB, C.SV_SCHEMA_VERSION, "DB")
		if not migrated then
			Logger.Error("SV_MIGRATE_FAILED", "SavedVariables", "Init", tostring(err))
			WoWSmartTSM_DB = defaultsDB()
			WoWSmartTSM_DB._corruptBackupMeta = { at = Time.Now(), err = tostring(err) }
			WoWSmartTSM_DB._hadCorrupt = true
		else
			WoWSmartTSM_DB = migrated
		end
	end

	deepMergeMissing(WoWSmartTSM_DB, defaultsDB())
	WoWSmartTSM_DB.settings = WoWSmartTSM_DB.settings or {}
	deepMergeMissing(WoWSmartTSM_DB.settings, defaultsDB().settings)

	if type(WoWSmartTSM_Diagnostics) ~= "table" then
		WoWSmartTSM_Diagnostics = defaultsDiag()
	else
		local migrated, err = migrate(WoWSmartTSM_Diagnostics, migrationsDiag, C.DIAG_SCHEMA_VERSION, "Diagnostics")
		if not migrated then
			WoWSmartTSM_Diagnostics = defaultsDiag()
			WoWSmartTSM_Diagnostics._hadCorrupt = true
			WoWSmartTSM_Diagnostics._corruptErr = tostring(err)
		else
			WoWSmartTSM_Diagnostics = migrated
		end
	end
end

function SV.GetDB()
	return WoWSmartTSM_DB
end

function SV.GetDiagnostics()
	return WoWSmartTSM_Diagnostics
end

function SV.ResetWithBackupHint()
	return "Backup SavedVariables before reset. Files flush on logout/reload only."
end

function SV.DoReset()
	WoWSmartTSM_DB = defaultsDB()
	WoWSmartTSM_Diagnostics = defaultsDiag()
	Logger.Init()
	Logger.Warning("UNKNOWN", "SavedVariables", "DoReset", "User reset SavedVariables")
end
