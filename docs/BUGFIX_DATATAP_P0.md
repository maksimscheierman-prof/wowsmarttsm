# P0 Bugfix — DataTap function indexing

**Date:** 2026-11-12  
**Version:** 0.1.2  
**Branch:** `feature/wow-smart-tsm-v1`

## Reproduced error

```
Interface/AddOns/!SmartTSM_DataTap/DataTap.lua:60:
attempt to index local 'orig' (a function value)
```

## Root cause

Idempotency used invalid Lua patterns:

- `orig.__smartTSMWrapped`
- `wrapped.__smartTSMWrapped = true`

Lua functions are not tables; indexing them raises the observed runtime error.

## Fix

- Local references: `private.originalLoader`, `private.wrappedLoader`
- Identity compare: `current == private.wrappedLoader`
- Re-entrancy guard: `private.wrapping`
- Wrapper forwards `orig(...)` with all args/returns
- `note()` failures are `pcall`'d and never block TSM
- `OnUpdate` registered once via `private.onUpdateActive`

## Slash command check (separate)

DataTap is a separate addon; its crash does **not** automatically prove `/smarttsm` is broken.

Hardened in 0.1.2:

- Idempotent `Commands.Register()`
- `Commands.IsRegistered()`
- PLAYER_LOGIN fallback registration
- Load-failure path still attempts slash registration

## Verification

- Offline suite including `test_datatap_wrapper.py` (reproduces error class + safe wrapper)
- Installed to Forever AddOns
- **In-game:** Owner must `/reload`, then test `/smarttsm`, `/smarttsm status`, `/smarttsm errors`

In-game success is **OPEN** until owner confirms.
