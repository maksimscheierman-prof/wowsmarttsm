# Contributing

## Development setup

1. Clone this repository.
2. Ensure Python 3.10+ is available.
3. Install WoW Forever with TradeSkillMaster ≥ 4.15 and TradeSkillMaster_AppHelper.
4. Check out **`dev`** (`git checkout dev`).
5. Run `python tools/doctor.py` and fix reported blockers.
6. Use `python tools/install.py --dev` to symlink/copy the addon into Forever AddOns.

## Branching (two-branch policy)

Durable branches only:

- **`main`** — stable, owner-approved versions. No direct development commits.
- **`dev`** — sole active development branch. All features, fixes, tests, and docs go here.

Rules:

- Do **not** open new `feature/*`, `bugfix/*`, `hotfix/*`, or `release/*` branches.
- Do **not** force-push.
- Do **not** rebase published history.
- Do **not** merge to `main` without explicit owner review (PR `dev` → `main`, CI green).
- Historical branches are retained until the owner approves deletion.
- Before pushing `dev`, run `git status` and confirm you are not diverging unexpectedly from `origin/dev`.

### Suggested GitHub branch protection (when permissions allow)

**main**

- Require pull request from `dev`
- Require CI to pass
- Block force-pushes
- No automatic merge without owner approval

**dev**

- Allow direct pushes for development
- Block force-pushes
- Prevent accidental branch deletion

## Testing

```powershell
python tools/test_runner.py --all
```

Offline tests use mocks. Mark real in-game verification separately (e.g. `docs/V0_2_1_OWNER_REVIEW.md`). Never report offline PASS as in-game PASS.

## Coding standards

- Lua: avoid global leaks; use the `WoWSmartTSM` namespace / modules.
- Prefer defensive `pcall` around TSM/WoW interop with Diagnostics logging.
- Keep German locale as default; English optional.
- Document VERIFIED / PARTIAL / UNSUPPORTED API claims in `docs/audit/`.
- UI tab renders must leave visible content; empty hosts are errors (`UI_CONTENT_EMPTY`).

## Pull requests

Include:

- What changed and why
- Test results (`test_runner` output summary; offline ≠ in-game)
- Owner-gated items left open
- Impact on existing TSM groups (must be none unless intentional and tested)
- Target branch: `dev` for work; `main` only for owner-approved releases
