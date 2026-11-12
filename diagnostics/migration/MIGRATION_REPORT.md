# TSM Gruppenmigration — Bericht (20261112T181534Z)

Quelle: `E:\WoW\World of Warcraft\_forever_\WTF\Account\121278306#2\SavedVariables\TradeSkillMaster.lua`

## Owner-Entscheidung

- `1er Group` → Smart-Verkaufsgruppen ersetzen
- `20er AH Sell` → Smart-Verkaufsgruppen ersetzen
- `Auto Vendeor ALL` → **unverändert behalten**
- Keine zweite Vendor-Gruppe (kein Smart Vendor in diesem Lauf)
- Löschen von `1er Group` / `20er AH Sell` erst nach erneuter Owner-Bestätigung

## Sicherung

- Backup JSON: `diagnostics\migration\tsm-groups-backup-20261112T181534Z.json`
- Itemzuordnungen gesichert: 101 Einträge

## Alte Gruppen

### 1er Group
- Items: **44**
- Ops: `{"Auctioning": ["Smart Single Sell", "override"], "Mailing": [], "Vendoring": [], "Shopping": ["#Default"], "Sniper": ["#Default"], "Crafting": ["#Default"], "Warehousing": []}`

### 20er AH Sell
- Items: **50**
- Ops: `{"Auctioning": ["Smart Stack Sell", "override"], "Mailing": [], "Vendoring": [], "Shopping": ["#Default"], "Sniper": ["#Default"], "Crafting": ["#Default"], "Warehousing": []}`

### Auto Vendeor ALL
- Items: **7**
- Ops: `{"Auctioning": [], "Mailing": [], "Vendoring": ["AHeqVendorPriceAutoSell", "override"], "Shopping": ["#Default"], "Sniper": ["#Default"], "Crafting": ["#Default"], "Warehousing": []}`

## Dokumentierte Auctioning-/Vendoring-Einstellungen

### Smart Single Sell
- `minPrice`: `check(first(crafting,dbmarket,dbregionmarketavg),max(0.5*first(dbmarket,dbregionmarketavg,crafting),2.11*vendorsell))`
- `normalPrice`: `check(first(crafting,dbmarket,dbregionmarketavg),max(first(dbmarket,dbregionmarketavg,crafting),3*vendorsell))`
- `maxPrice`: `check(first(crafting,dbmarket,dbregionmarketavg),max(2*first(dbmarket,dbregionmarketavg,crafting),5*vendorsell))`
- `postCap`: `1`
- `duration`: `3`
- `undercut`: `0c`
- `keepQuantity`: `0`
- `maxExpires`: `2`

### Smart Stack Sell
- `minPrice`: `check(first(crafting,dbmarket,dbregionmarketavg),max(0.5*first(dbmarket,dbregionmarketavg,crafting),2.11*vendorsell))`
- `normalPrice`: `check(first(crafting,dbmarket,dbregionmarketavg),max(first(dbmarket,dbregionmarketavg,crafting),3*vendorsell))`
- `maxPrice`: `check(first(crafting,dbmarket,dbregionmarketavg),max(2*first(dbmarket,dbregionmarketavg,crafting),5*vendorsell))`
- `postCap`: `5`
- `duration`: `2`
- `undercut`: `0c`
- `keepQuantity`: `0`
- `maxExpires`: `2`

### AHeqVendorPriceAutoSell
- `vsMarketValue`: `150% vendorsell`
- `enableSell`: `true`

## Stackgrößen-Hinweise

- `1er Group` / op **Smart Single Sell**: postCap=1, duration=3, undercut=0c → Einzelitems
- `20er AH Sell` / op **Smart Stack Sell**: postCap=5, duration=2, undercut=0c → Material-Stacks
- Gleiche Preisformeln für min/normal/max bei beiden Sell-Ops

## Provisional Offline-Zuordnung (vor Live-Reclassify)

- Moves: **94**
- `Smart TSM`Smart Quick Sell`: 50
- `Smart TSM`Smart Rare Sell`: 44

## Import

- Datei: `diagnostics/migration/import-string.txt`
- Weg: TSM → Groups → Import (kein privater Tabellenwrite)

## Noch offen

1. `/reload` → `/smarttsm migrate preview` (Live-Backup + Reclassify)
2. `/smarttsm migrate import` mit Shift → `/smarttsm importstring` → TSM Groups Import
3. `/smarttsm migrate verify`
4. Auctioning-Ops in TSM manuell zuweisen (Formeln aus Smart Single/Stack Sell)
5. **Owner-Bestätigung** vor Löschen von `1er Group` / `20er AH Sell`
6. `Auto Vendeor ALL` nicht löschen
7. Keine Smart-Vendor-Gruppe anlegen

## Löschmarkierung

| Gruppe | Markiert nach Verify | Owner-Löschfreigabe |
|--------|----------------------|---------------------|
| 1er Group | nach erfolgreichem Verify | **NEIN — STOP** |
| 20er AH Sell | nach erfolgreichem Verify | **NEIN — STOP** |
| Auto Vendeor ALL | nein | — |

Freigabe-Phrase (danach nur manueller TSM-Delete):  
`/smarttsm migrate delete-confirm OWNER_CONFIRM_DELETE_OLD_SELL_GROUPS`

**STOP zur Owner-Abnahme. Kein automatisches Löschen. Kein Merge nach `main`.**
