local Smart = WoWSmartTSM
local SkipAnalyzer = Smart:Module("SkipAnalyzer")
local SkipMap = Smart:Module("SkipMap")

-- Human-facing DE descriptions keyed by reason code
SkipMap.DE = {
	COMPETITION_BELOW_MIN = "Konkurrenz unter bisherigem Mindestpreis",
	MARKET_MISSING = "Marktwert fehlt",
	MARKET_STALE = "Marktwert veraltet",
	PRICE_SOURCE_INVALID = "Preisquelle ungültig",
	LOW_EXPECTED_MARGIN = "Zu geringe erwartete Gewinnspanne",
	DEPOSIT_RISK_HIGH = "Deposit-Risiko zu hoch",
	LOW_DEMAND = "Geringe Nachfrage",
	ENOUGH_AUCTIONS = "Bereits ausreichende Auktionen aktiv",
	POST_CAP = "Posting-Cap erreicht",
	NOT_GROUPED = "Item nicht korrekt gruppiert",
	INVALID_OPERATION = "Ungültige Operation",
	PROTECTED = "Item geschützt",
	AH_UNAVAILABLE = "AH nicht verfügbar",
	API_LIMIT = "API-Limitierung",
	DISABLED = "Posting deaktiviert",
	NOT_ENOUGH = "Nicht genug Items",
	MAX_EXPIRES = "Maximale Ablaufzahl erreicht",
	ABOVE_MAX_NO_POST = "Über Maxpreis — kein Posting",
	UNKNOWN = "Unbekannter Fehler",
	INSUFFICIENT_DATA = "Daten unzureichend",
}

SkipMap.EN = {
	COMPETITION_BELOW_MIN = "Competition below current minimum price",
	MARKET_MISSING = "Market value missing",
	MARKET_STALE = "Market value stale",
	PRICE_SOURCE_INVALID = "Invalid price source",
	LOW_EXPECTED_MARGIN = "Expected margin too low",
	DEPOSIT_RISK_HIGH = "Deposit risk too high",
	LOW_DEMAND = "Low demand",
	ENOUGH_AUCTIONS = "Enough auctions already active",
	POST_CAP = "Posting cap reached",
	NOT_GROUPED = "Item not correctly grouped",
	INVALID_OPERATION = "Invalid operation",
	PROTECTED = "Item protected",
	AH_UNAVAILABLE = "Auction house unavailable",
	API_LIMIT = "API limitation",
	DISABLED = "Posting disabled",
	NOT_ENOUGH = "Not enough items",
	MAX_EXPIRES = "Max expires reached",
	ABOVE_MAX_NO_POST = "Above max — no post",
	UNKNOWN = "Unknown error",
	INSUFFICIENT_DATA = "Insufficient data",
}

function SkipMap.Describe(code, locale)
	locale = locale or (WoWSmartTSM_DB and WoWSmartTSM_DB.settings and WoWSmartTSM_DB.settings.locale) or "deDE"
	local table_ = (locale == "enUS") and SkipMap.EN or SkipMap.DE
	return table_[code] or table_.UNKNOWN
end

function SkipMap.FromTSM(token)
	return SkipAnalyzer.MapTSMResult(token)
end
