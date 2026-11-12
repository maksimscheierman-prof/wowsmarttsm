# v0.2.1 Test Report

**Mode:** `OFFLINE_MOCK`  
**Important:** These results are **NOT** in-game smoke tests.

## Summary

| Suite | Result |
|-------|--------|
| `python tools/test_runner.py --all` | **117 passed, 0 failed** |
| In-game visual acceptance | **PENDING owner** (see `V0_2_1_OWNER_REVIEW.md`) |

## Git / branch tests

- `dev` contains all lineage commits through `cadc85a` (v0.2.0) plus v0.2.1 work.
- `main` remains at initial `3878921` (unchanged relative to consolidation intent).
- No open merge conflicts.
- Bundle backup present: `backups/git/wowsmarttsm-v0.2.0-cadc85a.bundle`.
- No new feature branches created for this workstream.

## UI tests (offline)

Covered in `tests/unit/test_ui_render_v021.py` and prior layout suites:

- All 12 tabs registered in MainFrame + Init map.
- Each tab defines a `Render` callback.
- ClearHost preserves Backdrop/NineSlice siblings (mock).
- Render host separated from backdrop panel.
- Visible FontString content after mock render.
- Tab switch replaces managed root (12 switches).
- Diagnostic events: `UI_TAB_SELECTED`, `UI_RENDER_STARTED`, `UI_RENDER_COMPLETED`, `UI_RENDER_FAILED`, `UI_CONTENT_EMPTY`.
- Missing module → fallback UI (not silent).
- Empty recovery budget capped at 1 retry.

## Function / regression tests

Existing offline suites still green for:

- Inventory classify / pricing / hold / vendor guards
- AutoEval status labels
- TSM data reevaluation (no AH scan)
- Character profiles / ActionDecide / mail prepare≠sent
- Consumables / crafting / ignore / groups / undo
- Logger Forever compatibility / ItemAPI
- DataTap wrap idempotency

## Explicit non-claims

- Offline PASS does **not** mean Forever in-game UI acceptance.
- Owner must still `/reload` and walk the steps in `V0_2_1_OWNER_REVIEW.md`.
