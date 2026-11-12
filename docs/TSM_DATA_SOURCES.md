# TSM Data Sources — Actual Usage (v0.1.1)

Audit against installed **TradeSkillMaster v4.15.6** + **TradeSkillMaster_AppHelper**.

## What v0.1.0 already used

| Source | Path | Status in 0.1.0 |
|--------|------|-----------------|
| DBMarket | `TSM_API.GetCustomPriceValue` if present | Used in `Prices.Collect` |
| DBMinBuyout | same | Used |
| DBRegionMarketAvg | same | Used |
| DBRegionSaleRate | same | Used |
| DBRegionSoldPerDay | same | Used |
| VendorSell | same (+ `GetItemInfo` fallback) | Used |
| Crafting | same | Attempted |
| Freshness / downloadTime | — | **Not implemented** |
| DBNumAuctions | — | **Not used** |
| Auto reevaluation | — | **Manual `/smarttsm scan` only** |
| AH scan | Bag iteration labeled “scan” | **Did not call AH APIs**, but naming was ambiguous |

## What v0.1.1 uses (VERIFIED)

Official API surface: `TradeSkillMaster/App/API.lua`

| Capability | API | Status |
|------------|-----|--------|
| Price / custom source | `TSM_API.GetCustomPriceValue(key, itemString)` | **VERIFIED** |
| Item string normalize | `TSM_API.ToItemString(item)` | **VERIFIED** |
| List registered sources | `TSM_API.GetPriceSourceKeys(result)` | **VERIFIED** |
| Group path | `TSM_API.GetGroupPathByItem(itemString)` | **VERIFIED** |
| Auction UI visibility | `TSM_API.RegisterUICallback("AUCTION", …)` | **VERIFIED** |

AuctionDB keys registered in `LibTSMApp/Source/Config/AuctionDBConfig.lua` (fed by AppHelper):

- `DBMarket`, `DBMinBuyout`, `DBNumAuctions`, `DBRecent`, `DBHistorical`
- `DBRegionMarketAvg`, `DBRegionSaleRate`, `DBRegionSoldPerDay`, …

Smart TSM reads these **only** through `TSM_API` — no TSM file patches, no second AH scan.

## Freshness

Exact `downloadTime` lives inside TSM AuctionDB private state after AppHelper load.

**DataTap** addon `!SmartTSM_DataTap` (`LoadWith: TradeSkillMaster`) wraps `TSM_APPHELPER_LOAD_DATA` and records:

- `SmartTSM_AppDataFreshness.realmDownloadTime`
- `SmartTSM_AppDataFreshness.regionDownloadTime`

Per-source UI status: `FRESH` / `STALE` / `MISSING` / `PRESENT_AGE_UNKNOWN`.

## No duplicate AH scans

| Action | Behavior |
|--------|----------|
| Login / reload / bag changes | Debounced **reevaluation** of bags using TSM_API values |
| `/smarttsm scan` | Same reevaluation — **`startedAhScan=false` always** |
| Competition | Prefer `DBMinBuyout` + `DBNumAuctions` from AuctionDB |
| Live AH needed | Flag `needsLiveCompetition` only when those are missing — **does not auto-scan** |
| Prior posting session | `PostingCache` reuses last Smart/TSM-UI observations |

## Hold / Vendor

Unchanged: Smart Hold policy + Protect checks remain authoritative.
