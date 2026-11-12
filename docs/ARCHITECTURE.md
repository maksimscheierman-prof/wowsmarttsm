# Architecture

## Decision

Independent companion addon **WoWSmartTSM** + local Python tooling. Original TSM is never forked or patched on disk.

```
┌─────────────────────┐     read prices/groups      ┌──────────────────┐
│   WoWSmartTSM UI    │◄───────────────────────────►│ TradeSkillMaster │
│  Rules / Pricing    │     confirmed SetGroup      │  + AppHelper     │
│  Diagnostics SV     │                             └──────────────────┘
└──────────┬──────────┘
           │ logout/reload flush
           ▼
┌─────────────────────┐     watchdog poll            ┌──────────────────┐
│  SavedVariables     │─────────────────────────────►│ tools/diagnose   │
└─────────────────────┘                              │ repair-queue     │
                                                     └──────────────────┘
```

## Addon modules

1. **Diagnostics** — first-class logger, ring buffer, SV schema migrations, error handler chaining
2. **TSM bridge** — Detect, Prices, Groups, Operations, SkipMap (defensive `pcall`)
3. **Rules** — ItemProfile, Protect, HoldPolicy, Classify, SkipAnalyzer, Engine
4. **Pricing** — configurable cut/deposit, EV candidates, conservative thin-data fallback
5. **Services** — Scan (bags), Vendor (confirm + dry-run), Undo, History
6. **UI** — own Smart Manager frame (AH context via slash / events; no TSM list injection)

## Data stores

| SV | Purpose |
|----|---------|
| `WoWSmartTSM_DB` | settings, always-keep, history, undo |
| `WoWSmartTSM_Diagnostics` | persistent errors, dedupe, coverage |

## Offline parity

`tools/smart_logic.py` mirrors Hold/Classify/Pricing for offline tests. Lua remains runtime source of truth for in-game behavior.
