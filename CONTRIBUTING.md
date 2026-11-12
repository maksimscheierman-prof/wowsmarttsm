# Contributing

## Development setup

1. Clone this repository.
2. Ensure Python 3.10+ is available.
3. Install WoW Forever with TradeSkillMaster ≥ 4.15 and TradeSkillMaster_AppHelper.
4. Run `python tools/doctor.py` and fix reported blockers.
5. Use `python tools/install.py --dev` to symlink/copy the addon into Forever AddOns.

## Branching

- Develop on `feature/*` branches.
- Do not force-push.
- Do not merge to `main` without review.

## Testing

```powershell
python tools/test_runner.py --all
```

Offline tests use mocks. Mark real in-game verification separately in `docs/TEST_REPORT.md`.

## Coding standards

- Lua: avoid global leaks; use the `WoWSmartTSM` namespace / AceAddon modules.
- Prefer defensive `pcall` around TSM/WoW interop with Diagnostics logging.
- Keep German locale as default; English optional.
- Document VERIFIED / PARTIAL / UNSUPPORTED API claims in `docs/audit/`.

## Pull requests

Include:

- What changed and why
- Test results (`test_runner` output summary)
- Owner-gated items left open
- Impact on existing TSM groups (must be none unless intentional and tested)
