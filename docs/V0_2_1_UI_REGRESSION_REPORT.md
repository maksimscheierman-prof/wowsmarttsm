# v0.2.1 UI regression report — empty gray tabs

**Severity:** P0  
**Owner visual acceptance (v0.2.0):** FAIL — all 12 tabs showed only an empty gray content panel after `/reload`.

## Root cause

Primary defect in `UI/Layout.lua` `ClearHost`:

1. After clearing `_smartRoot`, the function iterated **`host:GetChildren()`** and called **`SetParent(nil)`** on every child.
2. The tab content frame used **`BackdropTemplate`**. On modern clients that creates a **NineSlice** (and related) child used by the backdrop.
3. Orphaning those children broke/confused the host while the gray panel textures remained visible — producing an empty gray content area across **all** tabs (including previously working v0.1.5 tabs).
4. Contributing factors:
   - First `SelectTab` during `MainFrame.Create` ran while the frame was still **hidden**, so host width/height could be **0**.
   - Render failures or missing modules could fail **silently** (no `Render` → no fallback UI).
   - Content was parented onto the same frame that owned the backdrop children.

This was not a cosmetic “missing text color” issue; it was a host lifecycle / parenting bug.

## Fix (v0.2.1)

| Change | Purpose |
|--------|---------|
| `ClearHost` only retires `_smartRoot` into a hidden discard bin | Never mass-unparent backdrop/NineSlice children |
| `MainFrame` splits **panel** (backdrop) vs **`WoWSmartTSMContentHost`** (render target) | Backdrop children never share ClearHost scope |
| First paint deferred to **`OnShow`** | Valid layout sizes before render |
| `Layout.ResolveHostSize` ancestor fallbacks | Avoid 0×0 stacks when sizes are not ready |
| Root `SetFrameLevel(host+20)` + explicit Show | Content above panel chrome |
| `UI.RenderTab` diagnostics + empty detection | `UI_TAB_SELECTED`, `UI_RENDER_*`, `UI_CONTENT_EMPTY` |
| Missing module / empty host → visible fallback | One empty recovery attempt max; no unbounded retries; no chat spam for INFO |

## Verification scope

- Offline unit tests execute render-callback models and NineSlice preservation checks (`tests/unit/test_ui_render_v021.py`).
- **In-game acceptance is still required** (see `docs/V0_2_1_OWNER_REVIEW.md`). Offline PASS ≠ in-game PASS.

## Files touched

- `addon/WoWSmartTSM/UI/Layout.lua`
- `addon/WoWSmartTSM/UI/MainFrame.lua`
- `addon/WoWSmartTSM/UI/Init.lua`
- `addon/WoWSmartTSM/Diagnostics/ErrorCodes.lua`
- `addon/WoWSmartTSM/Core/Version.lua` → `0.2.1`
- `addon/WoWSmartTSM/WoWSmartTSM.toc` → `0.2.1`
