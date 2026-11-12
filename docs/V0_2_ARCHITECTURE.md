# WoW Smart TSM v0.2.0 — Architecture

## Goal

Main keeps bags as empty as practical; Bank character auctions profitable items. Strategy, transport, TSM group, and protect status are independent fields on each decision.

## Decision pipeline

```
Bag slot → ItemAPI → Prices (TSM_API) → ItemProfile
  → Classify (sell strategy + targetGroup)
  → ActionDecide (inventoryAction by role + rules)
  → UI (Cleanup / Mail / Vendor / Posting)
```

## Key modules

| Module | Responsibility |
|--------|----------------|
| `CharacterProfiles` | MAIN/BANK/MANUAL, primary bank key |
| `Classify` | QUICK/PROFIT/RARE/VENDOR/HOLD/REVIEW |
| `ActionDecide` | MAIL_TO_BANK, VENDOR, KEEP, IGNORE, HOLD_AT_BANK, MANUAL_REVIEW |
| `ItemRules` / `Consumables` / `CraftingReserve` | Priority rule layers |
| `CleanupService` | Aufräumen aggregates |
| `MailService` | Multi-message mail plans (never auto-success) |
| `VendorService` | Dry-run / confirmed vendor |

## Safety

- No auto mail/vendor without confirm.
- No bank addressing until `primaryBankKey` set.
- No blind vendor on missing metadata.
- Original TSM files untouched.
- Smart Hold policy unchanged (10g + 5× vendor, rare categories).
