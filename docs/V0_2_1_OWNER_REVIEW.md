# v0.2.1 Owner review checklist

**Version installed for review:** `0.2.1`  
**Branch:** `dev` (do not treat as `main` release)  
**Prior FAIL:** v0.2.0 empty gray content on all 12 tabs.

## Exact in-game steps

1. Ensure Forever is running with TSM + AppHelper as usual.
2. Confirm AddOns list shows **WoW Smart TSM 0.2.1** (after install + `/reload`).
3. `/reload`.
4. `/smarttsm show` (or `/smarttsm`).
5. Confirm the **default tab** for your role opens with **visible content** (not empty gray):
   - MAIN → Aufräumen (Cleanup)
   - BANK → Posten (Posting)
   - MANUAL → Dashboard
6. Click every tab and verify content (title + body text or tables/buttons):

   | Tab | Expect |
   |-----|--------|
   | Aufräumen | Header + scan + metrics/table or bank/empty hint |
   | Dashboard | Scan + summary metrics |
   | Posten | Bulk review posting list / empty state |
   | Post | Mail plan UI / bank config hint |
   | Händler | Vendor dry-run UI |
   | Halten | Hold review |
   | Übersprungen | Skipped review |
   | Charaktere | Role list MAIN/BANK/MANUAL |
   | Regeln | Ignore / consumable / crafting rules |
   | Verlauf | History rows or empty |
   | Einstellungen | Locale / dry-run / debug toggles |
   | Diagnose | Logs / health even if other systems soft-fail |

7. Close UI (X or ESC), reopen `/smarttsm show` — content still renders.
8. Resize window — content reflows without going blank.
9. Optional: `/smarttsm scan` (reeval only; does not start AH scan).
10. Optional: Diagnostics tab — look for `UI_RENDER_COMPLETED` entries; no flood of chat INFO spam (ERROR only if empty/fail).

## Acceptance criteria

- [ ] No empty gray-only content panel on any of the 12 tabs
- [ ] Tab switching works
- [ ] v0.2 multi-char / mail / vendor dry-run surfaces still reachable
- [ ] SavedVariables preserved (no unexpected reset)
- [ ] Owner visual acceptance: PASS / FAIL

## Notes for FAIL reports

Please include: character role (MAIN/BANK/MANUAL), which tab(s) failed, screenshot if possible, and any `[SmartTSM]` ERROR chat lines (`E5005` / `E5006`).
