# Automatic Repair Workflow

## What exists

1. `tools/watch_errors.py` — interval poll (default 60s), change-detect only
2. `tools/diagnose.py` — import SV, fingerprints, update `diagnostics/*`
3. `tools/repair_check.py` — queue inspection; stops after 3 attempts/fingerprint
4. Manual Cursor loop: read queue → fix → `test_runner` → mark fixed

## Cursor agent automation

Installed Cursor **3.29.9** provides `cursor` CLI; **no supported headless agent API was found** (`agent` command absent). Therefore:

- Optional repair runner config `tools/repair_runner.local.json` defaults to **disabled**
- We do **not** invent a Cursor API
- Documented manual start: open this repo in Cursor and ask the agent to process `diagnostics/repair-queue.json`

## Constraints

- Workspace writes only
- No admin rights required
- Max concurrent agent jobs: 1 (manual)
- Max 3 auto attempts per fingerprint
- No WoW install mutation while game running without owner approval
- No secrets in prompts/logs
- No auto git merge/release
