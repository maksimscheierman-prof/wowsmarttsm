# AGENTS.md — WoW Smart TSM

Instructions for Cursor (and other) coding agents working on this repository.

## Durable branch policy (mandatory)

**Only two durable branches:**

| Branch | Role |
|--------|------|
| `main` | Owner-gated stable / released versions only |
| `dev` | Sole active development branch |

Rules for every agent session (Cursor, Codex, Claude, etc.):

- Develop **directly on `dev`**. Features, bugfixes, tests, and docs land on `dev`.
- **Do not** create new `feature/*`, `bugfix/*`, `hotfix/*`, or `release/*` branches.
- **Do not** create new git worktrees with their own development branches.
- **Do not** run parallel agents that independently mutate the same code.
- **Never** auto-merge to `main`. Owner approval required for any `main` update (PR from `dev`).
- **Never** force-push. **Never** rebase published history.
- Historical branches (e.g. `feature/wow-smart-tsm-v1`) may be kept until the owner explicitly approves deletion.
- Before any git action that could lose unique commits: STOP and ask the owner.

## Always do first

1. Read `diagnostics/health-status.json` if present.
2. Read `diagnostics/repair-queue.json` if present.
3. Run `python tools/doctor.py` (or `python scripts/doctor.py`).
4. Prefer fixing CRITICAL/ERROR items in the repair queue before new features.
5. Never modify original TradeSkillMaster files under the WoW AddOns folder.
6. Never automate protected Blizzard actions (hardware input bots, silent vendor sells).

## Project layout

| Path | Purpose |
|------|---------|
| `addon/WoWSmartTSM/` | In-game companion addon (Lua) |
| `tools/` | Doctor, watchdog, install, package, repair-check |
| `tests/` | Offline unit/integration tests (Python + Lua fixtures) |
| `docs/` | Architecture and policy docs |
| `diagnostics/` | Generated reports (local personal data is gitignored) |

## Hard rules

- Companion addon only: `WoWSmartTSM`. No TSM fork without explicit owner approval.
- Existing TSM groups/operations must remain intact unless the user confirms bulk changes in-game.
- Smart Hold is rare-only (see `docs/SMART_HOLD_POLICY.md`). Sell first, hold rarely.
- Group changes require preview + explicit confirm. Vendor sells require confirm + safety checks.
- Logging/diagnostics are mandatory; do not swallow errors silently.
- Offline mock tests must never be reported as passed in-game smoke tests.
- Visual design changes after owner visual acceptance require owner approval.
- Do not force-push. Do not auto-merge to `main`. Do not publish releases without owner approval.
- Do not write outside the workspace during automated repair. Max 3 repair attempts per fingerprint.
- Cursor headless agent automation is **optional and disabled by default**. Do not invent Cursor APIs.

## Preferred workflow

```text
checkout dev → doctor → diagnose → fix → test → package → install (if WoW not writing locks) → verify-install → commit on dev → push dev (if authorized)
```

`main` stays untouched until the owner merges a reviewed PR from `dev`.

## Useful commands

```powershell
python tools/doctor.py
python tools/test_runner.py
python tools/test_runner.py --all
python tools/diagnose.py
python tools/watch_errors.py --once
python tools/repair_check.py
python tools/package.py
python tools/install.py --dev
python tools/verify_install.py
```

## Owner-gated

- Visual acceptance of UI
- Merge / release to `main`
- Deleting historical feature branches
- Replacing original TSM with a fork
- Changing install paths outside the project / configured WoW Forever AddOns folder
- Enabling optional Cursor repair runner
- Any destructive reset of SavedVariables without backup confirmation
