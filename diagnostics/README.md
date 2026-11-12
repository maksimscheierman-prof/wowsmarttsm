# Diagnostics

Generated reports:

- `latest-report.md` — doctor summary
- `health-status.json`
- `errors.json` / `error-history.json` / `repair-queue.json`

Personal SavedVariables copies go to `local/` (gitignored).

Crash-before-flush limitation: errors may be missing if WoW did not logout/reload cleanly.
