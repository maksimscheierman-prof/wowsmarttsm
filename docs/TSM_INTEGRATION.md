# TSM Integration

Verified against installed **TSM v4.15.6** (see `docs/audit/TSM_FOREVER_COMPATIBILITY.md` and `docs/TSM_DATA_SOURCES.md`).

## Read paths

- Prices: **`TSM_API.GetCustomPriceValue`** + **`TSM_API.ToItemString`** (VERIFIED in `App/API.lua`)
- Sources: DBMarket, DBMinBuyout, **DBNumAuctions**, DBRegionMarketAvg, DBRegionSaleRate, DBRegionSoldPerDay, VendorSell, Crafting
- Freshness: `!SmartTSM_DataTap` captures AppHelper `downloadTime` into `SmartTSM_AppDataFreshness`
- Groups: `TSM_API.GetGroupPathByItem` (VERIFIED)
- Skip semantics: mapped from `AuctioningOperation.RESULT` (`BELOW_MIN`, `DISABLED`, …)
- Posting reuse: `TSM_API.RegisterUICallback("AUCTION", …)` + in-memory `PostingCache`

## Reevaluation (not AH scanning)

- Login / reload / bag updates → debounced `ScanService.ReevaluateBags`
- `/smarttsm scan` → same reevaluation; **never** starts an AH scan (`startedAhScan=false`)
- Live competition only flagged via `needsLiveCompetition` when AuctionDB min buyout / num auctions missing

## Write paths (user-confirmed only)

- Move items into Smart subgroup paths under `Smart TSM\`…`
- Never rewrite global Auctioning operations for a single item
- Undo stack reverses last bulk move set

## UI integration

Default: separate Smart Manager window. Soft AH show hint only. No file-level TSM UI patches.

## Missing API surface

If `TSM_API.CreateGroup` / `SetGroup` are unavailable in a build, group apply logs `GROUP_CREATE_FAILED` / `GROUP_MOVE_FAILED` and instructs manual Smart group creation once. Classification and skip analysis still work.
