# WoW Smart TSM

Intelligent Auction House companion for **TradeSkillMaster** on **WoW Forever**.

**Sell first, hold rarely.** Smart TSM classifies bag items, explains posting skips, proposes item-specific Smart groups, and gathers safe vendor candidates — without modifying original TSM files.

## Requirements

- WoW Forever (`wowf`) with Interface load including `16001`
- TradeSkillMaster **≥ 4.15** (verified against **v4.15.6**)
- TradeSkillMaster_AppHelper
- TSM Desktop sync (region observed: `EU-Forever`)

## Quick start

```powershell
python tools/doctor.py
python tools/test_runner.py --all
python tools/install.py --dev
python tools/verify_install.py
```

In-game: `/smarttsm` · `/smarttsm scan` · `/smarttsm diagnose`

Default UI language: **German** (`enUS` optional in Settings).

## What it does

| Area | Behavior |
|------|----------|
| Classification | Quick / Profit / Rare Sell, Vendor, Hold, Manual Review |
| Smart Hold | Rare exceptions only (≥10g market **and** ≥5× vendor **and** allowed category) |
| Pricing | EV model using market, competition, deposit risk, demand proxies |
| Skips | Structured reason codes + recommendations (not “Not posted”) |
| Bulk review | Preview → Shift-confirm group moves → undo stack |
| Vendor | Dry-run default, protection checks, no input bots |
| Diagnostics | Persistent logs, coverage note, local watchdog |

## Safety

- Does **not** edit `TradeSkillMaster*` addon files
- Does **not** change unrelated existing groups unless you confirm moves
- Does **not** auto-post or silently vendor
- Owner visual acceptance required before final UI design lock (`docs/OWNER_REVIEW.md`)

## Project layout

See `AGENTS.md` and `docs/ARCHITECTURE.md`.

## Status

Development on `feature/wow-smart-tsm-v1`. In-game smoke test: **OPEN** until owner runs the checklist in `docs/TEST_REPORT.md`.

## License

MIT — see `LICENSE`. TSM remains third-party under its own license.
