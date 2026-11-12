# TSM / WoW Forever Compatibility Audit

**Audit date:** 2026-11-12  
**Auditor:** Cursor agent (local install inspection)  
**Target install:** `E:\WoW\World of Warcraft\_forever_`  
**Decision:** Independent companion addon `WoWSmartTSM` (no TSM fork).

## Environment evidence

| Item | Value | Status |
|------|-------|--------|
| Product flavor | `wowf` (`.flavor.info`) | VERIFIED |
| Client binary | `Wow.exe` present; process observed running during audit | VERIFIED |
| TSM version | `v4.15.6` (`TradeSkillMaster.toc`) | VERIFIED |
| AppHelper version | `v4.15` | VERIFIED |
| TSM TOC Interface | `120105, 50504, 20506, 16001, 11509` | VERIFIED |
| Forever addon Interface sample | `16001` (+ multi-flavor list in 4EVR_SpellRank) | VERIFIED |
| AppHelper region | `EU-Forever` in SavedVariables | VERIFIED |
| Realm context | `PvP` factionrealm keys in TSM DB | VERIFIED |
| Characters observed | `Banko Omar - PvP`, `Azamat Bagatow - PvP` | VERIFIED |
| SavedVariables path | `WTF\Account\121278306#2\SavedVariables\` | VERIFIED |

## Architecture decision

Prefer **WoWSmartTSM** as a separate addon that:

1. Reads TSM price sources via `CustomString.GetValue` / `GetSourceValue` when available.
2. Reads/writes item group membership via `Group.GetPathByItem` / `Group.SetItemGroup` / `Group.SetItemsGroup` only after user confirmation.
3. Provides its own Smart Manager UI in the AH context (does not patch TSM UI frames by default).
4. Never replaces or edits files under `Interface\AddOns\TradeSkillMaster*`.

A TSM fork remains **owner-gated last resort**.

## Interface inventory

### Groups — VERIFIED

Source: `LibTSMTypes/Source/Group/Group.lua`

| API | Evidence | Notes |
|-----|----------|-------|
| `Group.GetPathByItem(itemString)` | Present | Returns group path for item |
| `Group.SetItemGroup(itemString, groupPath)` | Present | Single-item move / ungroup (`nil`) |
| `Group.SetItemsGroup(items, groupPath)` | Present | Bulk move |
| `Group.Exists(groupPath)` | Present | Existence check |
| `Group.HandleGroupCreated(groupPath)` | Present | After creating group path in settings |
| `Group.ItemIterator` / `CreateItemsQuery` | Present | Enumeration |
| `Group.IsItemInGroup` | Present | Membership |

**Risk:** Group create/delete also involves TSM settings modules (`App/MainUI/Groups`). Companion must create Smart groups through supported settings APIs or documented paths; raw `HandleGroupCreated` alone may be PARTIAL without settings sync.

### Custom prices / market sources — VERIFIED (API), PARTIAL (runtime data)

Source: `LibTSMTypes/Source/CustomString/CustomString.lua`

| API | Status | Notes |
|-----|--------|-------|
| `CustomString.GetValue(text, itemString, allowZero)` | VERIFIED | Evaluates custom price strings |
| `CustomString.GetSourceValue(key, itemString)` | VERIFIED | Direct source lookup |
| `DBMarket`, `DBMinBuyout`, `DBRegionMarketAvg`, `DBRegionSaleRate`, `DBRegionSoldPerDay` | PARTIAL | API keys exist in TSM; values depend on AppHelper sync / AuctionDB |
| `VendorSell` / `ItemInfo.GetVendorSell` | VERIFIED | `LibTSMService/.../ItemInfo.lua` |
| `Crafting` costs | PARTIAL | Available when crafting DB populated |

AppHelper DB confirms region `EU-Forever` and active analytics for `v4.15.6`.

### Auctioning skip / post reasons — VERIFIED

Source: `LibTSMSystem/Source/Operation/AuctioningOperation.lua` (`RESULT` enum)

Notable `NOT_POSTING` reasons:

- `DISABLED`
- `NOT_ENOUGH`
- `MAX_EXPIRES`
- `BELOW_MIN`
- `ABOVE_MAX_NO_POST`

Also invalid operation/item-group reasons under `RESULT.INVALID.ITEM_GROUP.*` (POST_CAP, STACK_SIZE, MIN_PRICE, …).

Smart TSM maps these to structured reason codes (see Skip Analyzer). Direct hook into TSM PostScan UI columns is **PARTIAL**: PostScan logic exists (`LibTSMApp/.../PostScan.lua`), but injecting columns into TSM scrolling tables is fragile across versions → own Smart Manager window preferred.

### Deposit calculation — PARTIAL

| API | Status | Notes |
|-----|--------|-------|
| `AuctionHouseUIUtils.CalculateDeposit(...)` | VERIFIED in TSM source | Requires bag slot / AH wrapper |
| Forever exact deposit formula | PARTIAL | Must treat as runtime-measured / configurable; do not hardcode retail rates as truth |
| AH cut / house cut | PARTIAL | Configurable in Smart Pricing settings with Forever defaults documented as provisional |

### Protected / restricted actions — UNSUPPORTED (by design)

| Action | Status | Notes |
|--------|--------|-------|
| Silent vendor sell without click | UNSUPPORTED | Blizzard protected functions; require explicit user confirmation and allowed APIs only |
| Hardware input automation / bots | UNSUPPORTED | Not implemented |
| Claiming SavedVariables flush mid-session | UNSUPPORTED | Files update on logout/reload; watchdog must treat live session as possibly stale |
| Reading arbitrary other-addon Lua errors | PARTIAL | Own handler + BugSack coexistence; no guaranteed global error bus |

### Extending TSM Auctioning list UI — PARTIAL → workaround

Injecting buttons/columns into TSM Auctioning list is version-fragile. **Chosen approach:** independent `WoWSmartTSM` frame, openable from slash command and AH context, with optional soft hooks that do not alter TSM files.

## Forever API limitations (summary)

See also `docs/FOREVER_API_LIMITATIONS.md`.

1. Flavor `wowf` / Interface `16001` multi-load TOC pattern.
2. Classic-like AH flows observed via TSM Auctioning (stack/post cap semantics present).
3. No assumption that retail-only AH APIs exist.
4. Crash before logout can lose SavedVariables (document for watchdog).

## Wuild/TSM-App note

Optional future desktop companion. Not required for MVP. Local Forever already uses official TSM AppHelper sync. Deferred; no code dependency in v1.

## Compatibility matrix (implementation targets)

| Capability | Target | Status at audit |
|------------|--------|-----------------|
| Read prices | CustomString sources | VERIFIED API |
| Explain skips | Map AuctioningOperation.RESULT | VERIFIED |
| Move items to Smart groups | Group.SetItemGroup after confirm | VERIFIED API |
| Own UI | AceGUI/custom frames | Planned |
| Auto-post without user | Not in scope | UNSUPPORTED |
| Auto-vendor without confirm | Not in scope | UNSUPPORTED |

## Conclusion

Companion-addon architecture is feasible on TSM **v4.15.6** under Forever (`wowf`). Proceed without modifying original TSM. Mark deposit/cut rates and live market freshness as PARTIAL and keep them configurable + confidence-scored.
