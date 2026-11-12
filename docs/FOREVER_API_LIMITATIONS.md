# Forever API Limitations

| Topic | Status | Notes |
|-------|--------|-------|
| Flavor | VERIFIED | `wowf` |
| TOC Interface | VERIFIED | Prefer `16001` (+ multi-flavor list like TSM) |
| Client | VERIFIED | Forever 1.60.1 / build 70888 (owner report) |
| Deposit formula | PARTIAL | Use live AH deposit when available; fallback rate configurable |
| AH cut | PARTIAL | Default 5% configurable in settings |
| Protected functions | UNSUPPORTED to bypass | No hardware bots; vendor requires merchant + confirm |
| SavedVariables mid-session | UNSUPPORTED as durable disk truth | Flush on logout/reload; crash may lose logs |
| Cross-addon error bus | PARTIAL | Own logger + chained `seterrorhandler`; BugSack coexistence |

## Item / bag APIs (v0.1.4)

Evidence: TSM Forever `LibTSMWoW/Source/API/Item.lua` + `Container.lua`; owner crash on global `GetItemInfo`.

| API | Status | Notes |
|-----|--------|-------|
| `C_Item.GetItemInfo` | VERIFIED | Preferred; same return shape TSM uses on Forever |
| `C_Item.GetItemInfoInstant` | VERIFIED | Class / subclass / equip / icon |
| `C_Item.RequestLoadItemDataByID` | PARTIAL | Used when present; else touch GetInfo |
| Global `GetItemInfo` | UNSUPPORTED | Nil on Forever 1.60.1 → crash if called bare |
| Global `GetItemInfoInstant` | PARTIAL | Fallback only when present |
| `GET_ITEM_INFO_RECEIVED` | PARTIAL | Listener installed; triggers AutoEval catch-up |
| `C_Container.GetContainerNumSlots` | VERIFIED | Preferred bag size |
| `C_Container.GetContainerItemInfo` | VERIFIED | Table: hyperlink, stackCount, quality, itemID, isBound |
| `C_Container.GetContainerItemLink` | VERIFIED | Fallback link path |
| Legacy `GetContainerItemInfo` / `GetContainerItemLink` | PARTIAL | Classic-shaped fallback |

Smart TSM adapter: `Util/ItemAPI.lua`. Incomplete metadata → `metaIncomplete` → no blind vendor.

Classic-like auctioning fields (post cap, stack size) are present in TSM Forever build — treat as Classic-family semantics unless Forever docs say otherwise.
