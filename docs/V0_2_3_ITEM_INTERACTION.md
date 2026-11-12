# v0.2.3 Item Interaction

## Cleanup tab (Aufräumen / Bank-Aufräumen)

| Input | Behavior |
|-------|----------|
| Left click | Focus detail + selection (no vendor/mail execution) |
| Ctrl+click | Toggle multi-select |
| Shift+click | Range select from last index |
| Right click | Context menu (role-aware) |
| Hover | WoW item tooltip when link/id available + human reason |

## Detail panel

Shows name, quality, item id, quantities, market/vendor totals, TSM price fields (unknown if missing), groups, strategy, inventory action, protect flag, human reason, technical code, next step, action status, and underlying bag/slot stacks after aggregation.

## Aggregation

Stacks sharing `itemString` + `inventoryAction` + `strategy` + bind/protect/group merge into one row (`Strange Dust ×45`) while preserving `stacks[]` for mail/vendor fidelity.

## Context menu (P1)

MAIN: once/always mail-to-bank rules (still require mailbox confirm).  
BANK: prepare AH (status→prepared).  
Shared: keep / min-keep / ignore (char/account) / smart-hold inspect / group hint / reset.  
Hard protects are not bypassed; permanent rules are explicit menu choices.

## Human reasons & next steps

`UI/ItemExplain.lua` maps codes such as `BANK_CHARACTER_NOT_CONFIGURED` → German guidance; next steps point to mailbox, AH, vendor, or idle.
