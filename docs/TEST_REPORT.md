# Test Report

## Offline (automated)

Run: `python tools/test_runner.py --all`

**Latest run (2026-11-12, v0.1.1):** `43 passed, 0 failed` — mode `OFFLINE_MOCK`.

Categories covered:

- Rules / Smart Hold policy cases
- AH pricing / skip mapping
- Protected / always-keep
- Mock TSM group move / undo / isolation
- Addon structure + Lua syntax sanity
- Error fingerprint / repair attempt ceiling
- TSM data freshness / cache invalidation / debounce / no AH-scan reeval

**These are OFFLINE_MOCK results. They are not in-game smoke tests.**

## In-game smoke — OPEN

Owner checklist (after `/reload`):

1. [ ] Addon loads without Lua error
2. [ ] TSM Auctioning still works
3. [ ] `/smarttsm scan` produces decisions
4. [ ] Skip reasons readable
5. [ ] Bulk apply requires Shift confirm; undo works
6. [ ] Vendor dry-run blocks protected/hold candidates
7. [ ] `/smarttsm errors` shows logger output after forced test warning
8. [ ] UI tabs usable at UI scale 1.0 and 1.2

Mark results here when executed. Do not mark PASS without evidence.
