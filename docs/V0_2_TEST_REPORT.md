# v0.2.0 Offline Test Report

Mode: **OFFLINE_MOCK** — not in-game smoke tests.

Coverage added:

- Character roles / bank missing
- ActionDecide MAIN mail vs vendor vs hold
- SV schema migration 1→2
- Mail plan batching
- Cleanup aggregates
- Consumable conservative keep
- Strategy×transport independence

Run: `python tools/test_runner.py --all`

Latest offline result: **100 passed, 0 failed** (2026-11-12).

In-game verification: **OPEN (Owner)** after `/reload`.
