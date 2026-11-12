# v0.2.2 UI Fix Report

**Branch:** `dev` only  
**Base:** `6d27c73` (v0.2.1)  
**In-game visual acceptance:** **OPEN (Owner)** — offline PASS ≠ in-game PASS.

## Actual root cause

Forever reported `attempt to call a nil value` at:

| File | Line | Call site |
|------|------|-----------|
| `UI/CleanupTab.lua` | 33 | `Layout.Begin(parent)` |
| `UI/Dashboard.lua` | 35 | `Layout.Begin(parent)` |
| `UI/BulkReview.lua` | 74 | `Layout.Begin(parent)` |
| `UI/DiagnosticsTab.lua` | 21 | `Layout.Begin(parent)` |
| `UI/MailTab.lua` | 16 | `Layout.Begin(parent)` |
| `UI/VendorTab.lua` | 45 | `Layout.Begin(parent)` |

`Layout.Begin` was **nil at runtime** because **`UI/Layout.lua` failed to parse**, so none of its exports were registered.

### Parse failure (reproduced with real Lua)

In `truncateTextToWidth`:

```lua
-- INVALID in Lua: ':' requires a call; cannot be used as a bare existence check
local sw = fs:GetStringWidth and fs:GetStringWidth() or (#text * 7)
```

Lua error:

```text
function arguments expected near 'and'
```

Reproduced offline with lupa before the fix. After the whole file fails to load, every tab’s `local Layout = Smart:Module("Layout")` sees an empty module table → `Layout.Begin` is nil → E5005 at the call sites above.

### Why prior offline tests missed it

Static/mock tests checked that the *source text* contained `function Layout.Begin` and that Python fakes could “render”. They never **parsed/executed** `Layout.lua` under a real Lua VM, so the Forever-breaking syntax never failed CI.

## Fix

```lua
-- VALID
local sw = (fs.GetStringWidth and fs:GetStringWidth()) or (#text * 7)
```

Same correction for the second occurrence in the binary-search loop.

Also:

- `lua_syntax.py` now flags `:\w+\s+and` patterns.
- `UI/Init.lua` detects missing `Layout.Begin`, shows emergency text, and limits repeated chat lines.
- Version → **0.2.2**.

## Affected functions

| Function | Status |
|----------|--------|
| `Layout.Begin` | Restored (file loads again) |
| `Layout.ClearHost` / `HeaderButton` / `BodyStack` / `Add*` | Restored with the file |
| `truncateTextToWidth` | Syntax fixed (`.` existence check) |
| All 12 tab `Render` entry points | Can call `Layout.Begin` again |

## Regression tests

New Forever-like Lua runtime (`tools/forever_lua_runtime.py` + `tests/unit/test_ui_lua_runtime_v022.py`):

- Loads real `Locale` + `Layout.lua` with lupa
- Asserts all Layout APIs exist and are callable
- Reproduces the invalid `:`+`and` parse error
- Executes each of the 12 tab `Render` functions individually and sequentially
- Fails if `Layout.Begin` is nil (simulates the v0.2.1 in-game failure mode)

**Offline result:** 125 passed, 0 failed (`OFFLINE_MOCK` — not in-game).

## Installation check

- `python tools/install.py --dev`
- `python tools/verify_install.py` → source/install file counts match; hashes compared
- TOC `## Version: 0.2.2` and `Version.STRING = "0.2.2"` present in Forever AddOns copy
- No leftover v0.2.1 Layout syntax in the install path

## Open risks

- Owner must `/reload` and visually confirm all 12 tabs.
- Other undiscovered Forever Lua dialect gaps may still exist; the new runtime reduces but does not eliminate that risk.
- Chat once-guards + Logger dedupe limit spam; first distinct E5005 still prints once.
