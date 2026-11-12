# Error Logging

## In-addon

Module `Diagnostics/Logger.lua`:

- Severities: DEBUG, INFO, WARNING, ERROR, CRITICAL
- Fields: timestamp, sessionId, addonVersion, client build, TSM version, code, module, func, message, stack, itemId, group, priceSources, state, count
- Ring buffer size 500 + persistent `WoWSmartTSM_Diagnostics`
- Dedup by fingerprint
- Privacy sanitization (passwords/tokens/emails)
- `seterrorhandler` chained to previous (BugSack-safe)
- Coverage report explains partial third-party capture

## Slash

`/smarttsm status|errors|diagnose|debug|reset`

Reset requires `reset confirm` with backup hint.

## Disk reality

SavedVariables are **not** continuously flushed. Watchdog treats in-session files as possibly stale. Crash before logout can drop errors — documented in health reports.
