# v0.2.6 — Compact UI / No-Scroll Layout

## TSM-Gruppen

Zweispaltig ohne äußeren Scroll bei typischer Datenmenge (3 Gruppen + 8 fehlende):

- Links: existierende Gruppen (kompakte Zeilen, Auswahl → Detail)
- Rechts: fehlende Smart-Gruppen mit Auswahl + Import (Shift)
- Fußzeile: In TSM / Ops / Aufräumen / Setup + Status (nicht abgeschnitten)

Internes Listen-Scroll nur bei vielen Einträgen (`CompactList`).

## Layout-APIs

`ContentBudget`, `TwoColumns`, `CompactList`, `FooterActions`, `FitsWithoutScroll`

## Navigation

Kompakte Tab-Labels (Tooltip = voller Name), einheitliche Höhe 20px, engere Abstände.

## Owner-Abnahme

Maximiertes Forever-Fenster: Gruppen-Tab ohne sichtbaren Body-Scrollbalken. `main` unverändert.
