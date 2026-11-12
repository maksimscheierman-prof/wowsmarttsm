# v0.2.4 — Smart Group Manager

## Scope

Companion-only Smart Group Manager on branch `dev`. TSM remains the engine for mailing, auctioning, and vendoring.

## TSM 4.15.6 audit (verified)

Public `TSM_API` group surface is **read-oriented**:

| API | Role |
|-----|------|
| `GetGroupPaths` | List groups |
| `GetGroupPathByItem` | Live item → group |
| `GetGroupItems` | Items in a group |
| `RegisterGroupItemCallback` | Refresh after TSM changes |
| `GetAuctioningOperationMinPrice` | Read auctioning context |

**Not** in public API (Forever 4.15.6): `CreateGroup`, `SetGroup`, `MoveItem`, `CreateOperation`, `AssignOperation`.

Smart TSM therefore:

1. Probes for write APIs at runtime (`Groups.ProbeCapabilities` / `Operations.ProbeCapabilities`).
2. Uses **TSM Groups Import** string format (`group:Path,i:id,…`) as the safe apply path.
3. Never writes into private TSM DB tables.

## UI

- Tab **TSM-Gruppen**: live group, proposed group, strategy, operation, status (Sicher / Prüfen / Geschützt), reason.
- **Alle sicheren Vorschläge übernehmen (Shift)**: preview → confirm → import/direct → verify → undo.
- Tab **Setup**: one-time wizard (detect → propose Smart groups → ops checklist → mailing → preview → apply → test item).

## Safety

- Non-Smart user groups → status Prüfen (no silent overwrite).
- MANUAL role → no auto apply.
- High-value / missing market data → Prüfen; never auto-vendor those.
- Smart Hold remains rare (policy unchanged: ≥10g and ≥5× vendor).
- BANK: no self-mail operation.
- MAIN: consumables protected by default without “configure minimum” nag; optional per-item/char reserves.
- BANK: consumables evaluated for AH by default.

## Commands

```text
/smarttsm groups
/smarttsm setup
/smarttsm importstring
```

## Owner acceptance

Stop after install on Forever. No merge to `main` until owner visual/functional acceptance.
