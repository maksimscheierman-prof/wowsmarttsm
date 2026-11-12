# WoW Smart TSM v0.1.3 — Fix Report

**Branch:** `feature/wow-smart-tsm-v1`  
**Date:** 2026-11-12  
**Scope:** P0 Logger Forever-compat + P1 UI Layout rewrite + AutoEval/Diagnose clarity  
**In-game visual acceptance:** **OPEN (Owner)** — this report does **not** claim a passed ingame test.

---

## Owner rejection of v0.1.2 (context)

v0.1.2 failed owner acceptance due to:

1. Massive text overlap in Dashboard and Diagnostics (FontString orphans / fixed spacing).
2. Lua load error: `Logger.lua:50 attempt to call a nil value` (`math.randomseed`).
3. AutoEval status looked like `reason=nil ahScan=false count=0` with no clear meaning.
4. Diagnostics showed `Errors own=0 lua=0 dupes=0` even when a load failure existed.

---

## P0 — Logger initialization

### Cause

WoW Forever’s Lua runtime does not provide `math.randomseed`. Calling it during `Logger.Init` aborted logging before the error handler was installed, cascading into empty diagnostics and missed AutoEval visibility.

### Fix

- Removed all `math.randomseed` / random-seed usage.
- Session IDs now use `Time.Now` / `time` + `GetTime` fractional part + monotonic `sessionSeq`.
- `Logger.Init` is wrapped in `pcall` with a fallback ring buffer.
- `Logger.GetInitStatus()` exposes soft-fail state; early errors are counted.
- Bootstrap (`Addon.lua`) initializes SavedVariables → Logger → error handler → slash → AutoEval, and records `loadError` into `WoWSmartTSM_Diagnostics` without wiping SavedVariables.
- `SlashDiag.Status` no longer treats zero error counters alone as a clean load when `loggerInit` failed or `loadError` is set.
- `Prices.Collect` no longer uses `unpack(SOURCES)` (explicit copy).

### Acceptance criteria (offline verified)

| Criterion | Offline |
|-----------|---------|
| No `math.randomseed` in tree | Pass |
| Logger soft-fail path + GetInitStatus | Pass (source/tests) |
| SavedVariables keys unchanged (`WoWSmartTSM_DB`, `WoWSmartTSM_Diagnostics`) | Pass |
| Load failures surfaced in diagnose/status | Pass (source) |

Ingame verification of ADDON_LOADED remains with the owner after `/reload`.

---

## P1 — UI layout system

### Cause

Tab re-renders created new FontStrings without destroying previous ones; fixed ~18px assumptions and shared host frames caused stacking overlaps, empty lower regions, and broken German wrapping.

### Fix

New `UI/Layout.lua`:

- `ClearHost` removes prior `_smartRoot` and hides leftover children/regions.
- Each tab `Begin`s a fresh header / body / footer.
- `BodyStack` + `AddText` measure `GetStringHeight()` with word wrap (no fixed line pitch for arbitrary text).
- `AddTable` uses defined column widths and uniform row heights; scroll only for overflow.
- `MainFrame` re-renders active tab on `OnSizeChanged` (resize / scale).
- All eight tabs: Dashboard, Posting, Skipped, Vendor, Hold, History, Settings, Diagnostics (thin tabs via `BulkReview`).
- Theme uses a calm teal/panel palette (no loud red/yellow primary buttons).

### Offline layout model

Geometric stacking tests assert measured text blocks and table rows do not overlap. Full pixel-perfect ingame proof requires owner screenshots after install.

---

## P1 — AutoEval clarity

### Changes

- Distinct eval statuses: `NEVER_RUN`, `NO_ITEMS`, `FAILED`, `TSM_DATA_MISSING`, `OK` (+ “keine Verkaufskandidaten”).
- AutoEval schedules on `PLAYER_LOGIN`, `PLAYER_ENTERING_WORLD`, bag/bank updates, plus catch-up if Init runs after login.
- Addon `PLAYER_LOGIN` requests `player_login_catchup` when still idle.
- `/smarttsm status` prints explicit NEVER_RUN vs successful meta, plus bootstrap warnings.

---

## P1 — Diagnose quality

- `Core/Health.lua` health report: addon loaded, logger, slash, TSM API, AppHelper, DataTap, eval label, last error, data age, AutoEval state.
- Diagnostics tab shows health rows, logging coverage note/limitation, recent log lines, session id.
- Coverage report includes `earlyErrors` and clarifies that `own/lua/dupes=0` does **not** prove a clean load.

---

## Tests

Offline suite: **68 passed, 0 failed** (`tools/test_runner.py --all`).

New regressions:

- `tests/unit/test_logger_forever_compat.py`
- `tests/unit/test_ui_layout_v013.py`
- `tests/unit/test_autoeval_status_v013.py`

These are **NOT** in-game smoke tests.

---

## Install

Dev install copies `WoWSmartTSM` + `!SmartTSM_DataTap` into Forever `Interface/AddOns`.  
If Wow.exe is running, activation requires **`/reload`**.  
Original TradeSkillMaster files are not modified.

---

## Owner checklist (ingame)

1. `/reload` after install.
2. Confirm chat has no Logger/nil load error.
3. `/smarttsm diagnose` — loggerInitOk, health lines, no false “clean” if errors exist.
4. `/smarttsm status` — eval status not a naked `reason=nil` without explanation; AutoEval should leave NEVER_RUN after login debounce (~3s) or after `/smarttsm scan`.
5. Open UI — switch all eight tabs twice; shrink window; check DE locale for overlaps.
6. Screenshot Dashboard + Diagnostics for visual acceptance.

**Do not merge or release until owner visual acceptance.**
