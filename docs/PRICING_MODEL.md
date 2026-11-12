# Pricing Model

## Goal

Choose a buyout candidate that maximizes a **conservative expected value**, not a single rigid TSM string.

## Inputs

DBMarket, DBMinBuyout, DBRegionMarketAvg, DBRegionSaleRate, DBRegionSoldPerDay, VendorSell, Crafting (when present), AH cut, deposit, quantity/stack, operation min (for skip context), data age/quality.

## SaleRate warning

`DBRegionSaleRate` is a **regional market statistic**. It is **not** used as P(sell within auction duration). It is scaled by a discount factor to form a **proxy** only, and results are marked unreliable when demand signals are missing.

## EV

```
net_if_sold = price * (1 - ahCut)
EV ≈ p_proxy * net_if_sold - (1 - p_proxy) * depositFailWeight * deposit
```

Candidates: market, 95%/85% market, undercut min buyout, below-op-min candidate, vendor floor.

## Posting rules

- Require EV ≥ configured minimum
- Reject when net_if_sold ≤ vendor (when vendor > 0)
- Conservative path when thin/stale data
- Never claim false precision when `precise=false`

## Strategy mode (when `shouldPost`)

Priority order:

1. **RARE** — blue/epic equipment or rare-recipe category (Hold category resolver; Sell-first still applies)
2. **QUICK** — only when real demand exists: `saleRate ~= nil and saleRate >= 0.4` **or** `soldPerDay ~= nil and soldPerDay >= 2`
3. **PROFIT** — default AH post when EV is positive but demand is missing/low

**Bug fixed in v0.1.5:** `(saleRate or 1)` treated missing saleRate as 1.0 and forced almost everything to `QUICK_SELL`.

Vendor candidates appear only when AH is not chosen and protections/hold allow — never invented to fill the Vendor tab.

Lower than current TSM operation minimum is allowed **only** as an item-level Smart group recommendation, not a global operation edit.
