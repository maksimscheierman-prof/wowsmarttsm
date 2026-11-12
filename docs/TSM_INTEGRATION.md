# TSM Integration

Verified against installed **TSM v4.15.6** (see `docs/audit/TSM_FOREVER_COMPATIBILITY.md`).

## Read paths

- Prices: `TSM_API.GetCustomPriceValue` when present; sources DBMarket, DBMinBuyout, DBRegion*, VendorSell, Crafting
- Groups: `GetGroupPath` / create+set helpers when exposed
- Skip semantics: mapped from `AuctioningOperation.RESULT` (`BELOW_MIN`, `DISABLED`, …)

## Write paths (user-confirmed only)

- Move items into Smart subgroup paths under `Smart TSM\`…`
- Never rewrite global Auctioning operations for a single item
- Undo stack reverses last bulk move set

## UI integration

Default: separate Smart Manager window. Soft AH show hint only. No file-level TSM UI patches.

## Missing API surface

If `TSM_API.CreateGroup` / `SetGroup` are unavailable in a build, group apply logs `GROUP_CREATE_FAILED` / `GROUP_MOVE_FAILED` and instructs manual Smart group creation once. Classification and skip analysis still work.
