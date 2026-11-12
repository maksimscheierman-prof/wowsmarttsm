# v0.2.3 Role / Bank Fix Report

**Branch:** `dev`  
**In-game acceptance:** OPEN (Owner)

## Root cause

1. **BANK inventory mapping was wrong.** On role `BANK`, rentable strategies (`QUICK_SELL` / `PROFIT_SELL` / `RARE_SELL`) were mapped to `KEEP` with reason `BANK_READY_TO_POST` instead of a real post action. Constants lacked `POST_AH` and bank-local `HOLD`.

2. **Bank-dependent checks were applied without role context.** `BANK_CHARACTER_NOT_CONFIGURED` was used as a generic transport failure. On the bank character itself, AH preparation must **not** require a mail recipient. Additionally, if the logged-in character *is* the primary bank but stored role drifted to `MAIN`, decisions could treat the bank alt like a main (mail-to-bank / blocked review) instead of posting.

3. **Character identity was rebuilt ad hoc.** Realm strings with spaces (`CAMWOW EU4 Realm 6 PvP`) and key format `Name-Realm|Faction` needed a single normalizer. Role/bank changes did not always force a bag reevaluation, so the UI could show a configured bank while **stale** decisions still carried `BANK_CHARACTER_NOT_CONFIGURED`.

## Fix summary

| Piece | Change |
|-------|--------|
| `Core/CharacterResolver.lua` | Canonical keys, `GetEffectiveRole`, `CanMailToBank`, Snapshot, Notify→reeval |
| `CharacterProfiles` | Delegates to resolver; primary-bank login forces BANK; reeval on role/bank change |
| `Constants` | `POST_AH`, `HOLD` |
| `ActionDecide` | MAIN→mail/hold-at-bank; BANK→post/hold/vendor; never mail-to-self on BANK |
| Cleanup UI | Role-aware metrics (AH vorbereiten vs An Bank senden) |

## Expected behavior (Azamat / Banko)

- **Azamat (MAIN)** + bank `Banko`: rentable → `MAIL_TO_BANK`; hold → `HOLD_AT_BANK`; vendor → `VENDOR`.
- **Banko (BANK)** (also when primary bank login): rentable → `POST_AH`; hold → `HOLD`; **never** `MAIL_TO_BANK` / `HOLD_AT_BANK`.
- Missing bank on MAIN blocks only bank-dependent actions with a clear message; BANK posting still works without a mail target.
