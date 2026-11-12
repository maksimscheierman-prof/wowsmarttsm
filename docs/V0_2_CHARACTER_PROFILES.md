# Character Profiles

## Identity

`Name-Realm|Faction` (e.g. `Banko Omar-PvP|Horde`).

## Roles

| Role | Default tab | Behaviour |
|------|-------------|-----------|
| MAIN | Aufräumen | Analyze bags; mail AH items to bank; vendor junk; keep protected |
| BANK | Posten | Keep AH items for posting; Hold storage; vendor junk |
| MANUAL | Dashboard | Suggestions only; no automation flags |

## Primary bank

`WoWSmartTSM_DB.profile.primaryBankKey`

Until set: `BANK_CHARACTER_NOT_CONFIGURED` — mail blocked; Characters tab offers picker.

## MAIN defaults

autoEval, protectConsumables, protectCraftingReserves, smartHoldToBank, goalEmptyBags; autoAhScan/autoMail/autoVendor = false.
