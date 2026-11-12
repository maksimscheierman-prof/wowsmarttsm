# v0.2.5 — Gruppenmanager und TSM-Operationen

## Trennung

| Tab | Verantwortung |
|-----|----------------|
| **TSM-Gruppen** | Hierarchie, Itemzahlen, fehlende Smart-Gruppen, Import-Hinweis |
| **Aufräumen** | Itemzuordnung (aktuell/vorschlag/Dropdown), Bulk sichere Vorschläge |
| **TSM-Operationen** | Auctioning/Mailing/Vendoring Anzeige + bearbeitbare Vorschläge |
| **Setup** | Geführte Lückenprüfung ohne Doppelverwaltung |

## TSM 4.15.6

- Gruppen lesen: `GetGroupPaths`, `GetGroupItems`, `FormatGroupPath`, `SplitGroupPath`
- Ops listen/schreiben: **nicht** in `TSM_API` → Werte = `unbekannt`, geführte TSM-UI
- Preisformeln validieren: `IsCustomPriceValid` / `GetPriceSourceKeys`
- Apply: Import-String + Verify; keine privaten Tabellenwrites

## Sicherheit

- Manuelle Nutzergruppen ohne explizite Wahl → Prüfen
- Hochpreisig / unsichere Preise → Prüfen
- BANK: kein Self-Mail
- Keine stillen Vendor-/Mail-/AH-Aktionen

Owner-Abnahme auf `dev`. Kein Merge nach `main`.
