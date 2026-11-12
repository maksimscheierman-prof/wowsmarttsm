# WoW Smart TSM v0.1.4 — Fix Report

**Branch:** `feature/wow-smart-tsm-v1`  
**Date:** 2026-11-12  
**Scope:** P0 Forever Item/Bag API adapter + P1 button-row layout + failed-eval UX  
**In-game acceptance:** **OPEN (Owner)** — no claim of passed ingame smoke/visual test.

---

## Owner rejection of v0.1.3

1. `Core/ScanService.lua:60 attempt to call a nil value` — bare `GetItemInfo(link)` on Forever 1.60.1 / build 70888.
2. Posting-tab buttons overlapped (DE labels wider than fixed widths).
3. Failed inventory eval showed as empty “0 Einträge” without clear failure UX.

---

## P0 — Item API

### Root cause

Forever (aligned with TSM `LibTSMWoW` API.Item) exposes **`C_Item.GetItemInfo`**, not the classic global `GetItemInfo`. Calling the nil global aborted bag reevaluation → `FAILED` / never useful results.

### Fix

- New `Util/ItemAPI.lua` with capability probe (`VERIFIED` / `PARTIAL` / `UNSUPPORTED`).
- Preferred path: `C_Item.GetItemInfo` + `C_Item.GetItemInfoInstant`.
- Bag path: `C_Container.*` with legacy fallbacks.
- Pending loads via `RequestLoadItemDataByID` (when present) + `GET_ITEM_INFO_RECEIVED` → AutoEval catch-up.
- `ScanService` builds each slot in `pcall`; one bad slot cannot abort the walk.
- Incomplete metadata → `metaIncomplete` → `unknownIdentity` → Manual Review / **no blind vendor**.

Documented in `docs/FOREVER_API_LIMITATIONS.md`.

---

## P1 — Button layout

`Layout.AddButtonRow` now:

- Measures label width (+ padding), clamps min/max.
- Wraps to a new row when remaining width is insufficient.
- Truncates with ellipsis + tooltip when still too wide.
- Used by Posting (BulkReview) and Settings; other tabs inherit via shared helpers.

DE labels (e.g. „Auswahl übernehmen (Shift)“) no longer share a single fixed 120–160px row blindly.

---

## UX — Failed evaluation

When `GetEvalStatus().status == "FAILED"`, BulkReview tabs show:

> Inventarbewertung fehlgeschlagen – Details unter Diagnose.

plus **Erneut bewerten** and a Diagnostics shortcut — not a silent “0 Einträge”.

---

## Tests / install

- New: `tests/unit/test_item_api_forever.py`, `tests/unit/test_button_layout_v014.py`
- Offline suite must pass before install (`tools/test_runner.py --all`)
- Dev install to Forever AddOns; if Wow.exe running → **`/reload`**
- Original TSM untouched
- No merge / no release

---

## Owner checklist

1. `/reload`
2. Confirm no `GetItemInfo` nil error in Bugsack / chat.
3. Wait ~3s or `/smarttsm scan` — status should leave `FAILED` from the old bug; expect `OK` / `NO_ITEMS` / `TSM_DATA_MISSING` as appropriate.
4. Posten-Tab: buttons readable, no overlap; shrink window and re-check wrap.
5. Diagnose: Item-API / Bag-API lines present.
6. Visual + functional acceptance remains with owner.
