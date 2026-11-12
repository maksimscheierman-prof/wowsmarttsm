local Smart = WoWSmartTSM
local C = Smart:Module("Constants")

C.ADDON_DISPLAY_NAME = "WoW Smart TSM"
C.SV_SCHEMA_VERSION = 1
C.DIAG_SCHEMA_VERSION = 1
C.LOG_RING_SIZE = 500
C.HISTORY_RING_SIZE = 200
C.UNDO_STACK_SIZE = 20

-- Groups created/managed under this root (does not touch unrelated user groups)
C.SMART_ROOT = "Smart TSM"
C.GROUPS = {
	QUICK = "Smart TSM`Smart Quick Sell",
	PROFIT = "Smart TSM`Smart Profit Sell",
	RARE = "Smart TSM`Smart Rare Sell",
	VENDOR = "Smart TSM`Smart Vendor",
	HOLD = "Smart TSM`Smart Hold",
	REVIEW = "Smart TSM`Manual Review",
}

C.STRATEGIES = {
	QUICK_SELL = "QUICK_SELL",
	PROFIT_SELL = "PROFIT_SELL",
	RARE_SELL = "RARE_SELL",
	VENDOR = "VENDOR",
	HOLD = "HOLD",
	MANUAL_REVIEW = "MANUAL_REVIEW",
}

C.SEVERITY = {
	DEBUG = "DEBUG",
	INFO = "INFO",
	WARNING = "WARNING",
	ERROR = "ERROR",
	CRITICAL = "CRITICAL",
}

-- Copper units
C.COPPER_PER_SILVER = 100
C.COPPER_PER_GOLD = 10000
C.HOLD_MIN_MARKET_COPPER = 10 * C.COPPER_PER_GOLD -- 10g
C.HOLD_VENDOR_MULTIPLIER = 5

-- Quality
C.QUALITY = {
	POOR = 0,
	COMMON = 1,
	UNCOMMON = 2, -- green
	RARE = 3,     -- blue
	EPIC = 4,
	LEGENDARY = 5,
}

-- Provisional Forever AH economics (configurable; PARTIAL verification)
C.DEFAULT_AH_CUT = 0.05
C.DEFAULT_DEPOSIT_RATE = 0.15 -- fraction of vendor or estimated; overridden when live deposit known
C.DEFAULT_AUCTION_HOURS = 24

C.DATA_MAX_AGE_SECONDS = 48 * 3600
