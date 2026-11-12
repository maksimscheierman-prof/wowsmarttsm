# Smart Hold Policy

**Hold is a filter, not a keep-forever order. Sell first, hold rarely.**

## Allowed categories only

- Expensive green gear (uncommon equipment)
- Blue gear
- Epic gear
- Rare recipes/patterns (recipe class metadata — not name-only)

## Mandatory thresholds (both)

1. Market value ≥ **10 gold**
2. Market value ≥ **5 × VendorSell**

## VendorSell = 0

Do **not** divide by zero. Special path: ratio skipped; Hold may still pass if market ≥ 10g and category allowed. Blind vendor is still forbidden.

## Precedence

1. If AH posting EV is sensible → **AH strategy** (never Hold)
2. Else if Hold filter passes → **Hold**
3. Else if safe to vendor → **Vendor**
4. Else → **Manual Review**

## Examples

| Case | Result |
|------|--------|
| Common mat 20g market | Not Hold (category) |
| Green 15g / vendor 2g, AH bad | Hold possible |
| Blue 8g | Fail 10g threshold |
| Recipe 50g / vendor 5g, AH bad | Hold possible |
| Missing market | Review — no blind vendor |
