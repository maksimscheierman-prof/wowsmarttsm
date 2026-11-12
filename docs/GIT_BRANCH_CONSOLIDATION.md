# Git branch consolidation — v0.2.1

**Date:** 2026-11-12  
**Policy:** Durable branches are only `main` and `dev`.

## Audit summary

| Item | Result |
|------|--------|
| Prior HEAD | `cadc85a` on `feature/wow-smart-tsm-v1` (= v0.2.0) |
| Remote heads (pre) | Only `origin/feature/wow-smart-tsm-v1` |
| Local `main` / `dev` (pre) | Absent |
| Worktrees | Single worktree at repo root |
| Dirty tree (pre-fix) | Clean at `cadc85a` (diagnostics later touched by doctor) |
| Open PRs | `gh` CLI unavailable; no remote `main`/`dev` to PR against |
| Tags | None observed on remote |

### Commit lineage retained on `dev`

```
3878921 Initial WoW Smart TSM …
247d2b2 Use TSM AuctionDB via TSM_API …
977d64a Fix DataTap P0 …
c08e6e4 Fix v0.1.3 Logger + Layout …
047436b Fix v0.1.4 C_Item + button rows …
0250329 Polish v0.1.5 …
cadc85a Implement v0.2.0 multi-character …
(+ subsequent v0.2.1 commits on dev)
```

`main` points at `3878921` (initial). It is an ancestor of `dev`. **No merge to `main` was performed for v0.2.x.**

## Backup

| Artifact | Path | Status |
|----------|------|--------|
| Git bundle @ v0.2.0 | `artifacts/git/wowsmarttsm-v0.2.0-cadc85a.bundle` (tracked) + local `backups/git/…` | Verified (`git bundle verify` OK) |
| Feature branch tip | `feature/wow-smart-tsm-v1` @ `cadc85a` | Retained until owner deletion approval |
| Remote feature | `origin/feature/wow-smart-tsm-v1` | Retained (no deletion) |

Restore example:

```powershell
git fetch backups/git/wowsmarttsm-v0.2.0-cadc85a.bundle feature/wow-smart-tsm-v1:refs/heads/restore-v020
```

## Consolidation actions

1. Created local `main` at `3878921`.
2. Created local `dev` at `cadc85a` (fast-forward equivalent: feature tip).
3. Checked out `dev` for all further work.
4. Did **not** delete `feature/wow-smart-tsm-v1` (owner-gated).
5. Did **not** merge into `main`.
6. Updated `AGENTS.md`, `CONTRIBUTING.md`, `.cursor/rules/smart-tsm.mdc` for the two-branch policy.

## Target durable structure

```
main  — owner-approved stable versions only
dev   — sole active development
```

Historical feature refs may remain as read-only backups until the owner approves deletion.

## Branch protection (GitHub)

Configure when permissions allow (see `CONTRIBUTING.md`):

- `main`: PR-only from `dev`, CI required, no force-push, no auto-merge without owner.
- `dev`: direct development commits allowed, no force-push, prevent accidental delete.

`gh` was not available in the agent environment; protection must be confirmed in the GitHub UI by the owner if API setup is incomplete.
