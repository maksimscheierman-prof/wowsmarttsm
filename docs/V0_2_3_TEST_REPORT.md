# v0.2.3 Test Report

**Mode:** `OFFLINE_MOCK` — **not** in-game proof.

## Result

`python tools/test_runner.py --all` → **138 passed, 0 failed** (at packaging time).

## New coverage (`test_role_action_v023.py`)

- MAIN + bank → `MAIL_TO_BANK`
- MAIN without bank → review + `BANK_CHARACTER_NOT_CONFIGURED`
- BANK as self primary → `POST_AH`, never self-mail
- BANK without bank key → still `POST_AH`
- BANK hold/vendor
- Primary-bank login forces effective BANK even if stored role drifted
- MANUAL `automationAllowed=false`
- Key normalization (collapsed spaces)
- Stack aggregation 20+20+5 → 45 with 3 stacks
- Human reasons
- CleanupTab render MAIN/BANK
- TOC order / version 0.2.3

Existing Lua runtime suite still executes all 12 tab Renders.
