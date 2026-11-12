#!/usr/bin/env python3
"""Read-only TSM SavedVariables backup + migration plan for Smart TSM sell groups.

Does NOT write into TSM private tables. Produces:
  diagnostics/migration/tsm-groups-backup-*.json
  diagnostics/migration/MIGRATION_REPORT.md
  diagnostics/migration/import-string.txt
"""
from __future__ import annotations

import json
import re
from collections import defaultdict
from datetime import datetime, timezone
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "diagnostics" / "migration"

REPLACE_GROUPS = ("1er Group", "20er AH Sell")
KEEP_GROUPS = ("Auto Vendeor ALL",)
SMART_SELL = {
    "QUICK": "Smart TSM`Smart Quick Sell",
    "PROFIT": "Smart TSM`Smart Profit Sell",
    "RARE": "Smart TSM`Smart Rare Sell",
    "HOLD": "Smart TSM`Smart Hold",
    "IGNORE": "Smart TSM`Smart Ignore",
}
SMART_ROOT = "Smart TSM"
# Do NOT create Smart Vendor in this migration — keep Auto Vendeor ALL.


def find_tsm_sv() -> Path:
    wow = Path(r"E:\WoW\World of Warcraft\_forever_\WTF")
    cands = list(wow.glob("Account/*/SavedVariables/TradeSkillMaster.lua"))
    if not cands:
        raise SystemExit("TradeSkillMaster.lua SavedVariables not found")
    # Prefer the one that contains the owner groups
    for p in cands:
        t = p.read_text(encoding="utf-8", errors="replace")
        if '["1er Group"]' in t and '["20er AH Sell"]' in t:
            return p
    return cands[0]


def extract_brace_block(text: str, start: int) -> str:
    i = text.find("{", start)
    if i < 0:
        return ""
    depth = 0
    for j in range(i, len(text)):
        ch = text[j]
        if ch == "{":
            depth += 1
        elif ch == "}":
            depth -= 1
            if depth == 0:
                return text[start : j + 1]
    return text[start : start + 500]


def extract_named_table(text: str, name: str) -> str:
    pat = re.escape(f'["{name}"]') + r"\s*=\s*\{"
    m = re.search(pat, text)
    if not m:
        return ""
    return extract_brace_block(text, m.start())


def parse_item_assignments(text: str) -> dict[str, str]:
    """Parse itemString -> groupPath assignments from TSM SV."""
    items: dict[str, str] = {}
    # Typical: ["i:123"] = "1er Group",
    for m in re.finditer(
        r'\["(i:[^"]+|item:[^"]+)"\]\s*=\s*"(1er Group|20er AH Sell|Auto Vendeor ALL|[^"]+)"',
        text,
    ):
        items[m.group(1)] = m.group(2)
    return items


def parse_op_settings(text: str, op_name: str) -> dict:
    block = extract_named_table(text, op_name)
    settings: dict[str, str] = {}
    if not block:
        return settings
    for m in re.finditer(r'\["([^"]+)"\]\s*=\s*"([^"]*)"', block):
        settings[m.group(1)] = m.group(2)
    for m in re.finditer(r'\["([^"]+)"\]\s*=\s*(true|false|\d+)', block):
        settings[m.group(1)] = m.group(2)
    # quoted op name references inside Auctioning
    return settings


def parse_group_ops(text: str, group: str) -> dict:
    block = extract_named_table(text, group)
    ops: dict[str, list[str]] = {}
    if not block:
        return ops
    for typ in ("Auctioning", "Mailing", "Vendoring", "Shopping", "Sniper", "Crafting", "Warehousing"):
        m = re.search(rf'\["{typ}"\]\s*=\s*\{{(.*?)\}}', block, re.S)
        if not m:
            continue
        body = m.group(1)
        names = re.findall(r'"([^"#][^"]*)"', body)
        # also #Default
        defaults = re.findall(r'"(#[^"]+)"', body)
        ops[typ] = names + defaults
    return ops


def provisional_target(item: str, from_group: str) -> tuple[str, str]:
    """Offline heuristic until in-game Classify re-runs with TSM prices."""
    if from_group == "1er Group":
        # Single-item auction path → Rare Sell default (gear/specialty); Profit as fallback tag
        return SMART_SELL["RARE"], "from_1er_single_default_rare"
    if from_group == "20er AH Sell":
        return SMART_SELL["QUICK"], "from_20er_stack_default_quick"
    return SMART_SELL["IGNORE"], "unexpected_source"


def build_import_string(moves: list[dict], empty_groups: list[str]) -> str:
    by: dict[str, list[str]] = defaultdict(list)
    order: list[str] = []
    for path in empty_groups:
        if path not in by:
            by[path] = []
            order.append(path)
    for m in moves:
        g = m["toGroup"]
        if g not in by:
            by[g] = []
            order.append(g)
        by[g].append(m["itemString"])

    def sort_key(p: str) -> tuple:
        if p == SMART_ROOT:
            return (0, p)
        return (1, p)

    order = sorted(set(order), key=sort_key)
    parts: list[str] = []
    for g in order:
        parts.append("group:" + g.replace(",", "``"))
        parts.extend(by.get(g, []))
    return ",".join(parts)


def main() -> None:
    OUT.mkdir(parents=True, exist_ok=True)
    sv = find_tsm_sv()
    text = sv.read_text(encoding="utf-8", errors="replace")
    ts = datetime.now(timezone.utc).strftime("%Y%m%dT%H%M%SZ")

    items = parse_item_assignments(text)
    by_group: dict[str, list[str]] = defaultdict(list)
    for item, group in items.items():
        by_group[group].append(item)

    group_meta = {}
    for g in list(REPLACE_GROUPS) + list(KEEP_GROUPS):
        ops = parse_group_ops(text, g)
        group_meta[g] = {
            "operations": ops,
            "itemCount": len(by_group.get(g, [])),
            "items": sorted(by_group.get(g, [])),
        }

    op_docs = {
        "Smart Single Sell": parse_op_settings(text, "Smart Single Sell"),
        "Smart Stack Sell": parse_op_settings(text, "Smart Stack Sell"),
        "AHeqVendorPriceAutoSell": parse_op_settings(text, "AHeqVendorPriceAutoSell"),
    }

    moves = []
    for g in REPLACE_GROUPS:
        for item in sorted(by_group.get(g, [])):
            to, why = provisional_target(item, g)
            moves.append(
                {
                    "itemString": item,
                    "fromGroup": g,
                    "toGroup": to,
                    "reason": why,
                    "stackHint": "single" if g == "1er Group" else "stack20_mats",
                    "status": "PROVISIONAL_OFFLINE",
                }
            )

    empty = [SMART_ROOT] + list(SMART_SELL.values())
    import_str = build_import_string(moves, empty)

    backup = {
        "createdAt": ts,
        "sourceFile": str(sv),
        "ownerDecision": {
            "replace": list(REPLACE_GROUPS),
            "keep": list(KEEP_GROUPS),
            "createSmart": list(SMART_SELL.values()),
            "createSmartVendor": False,
            "deleteAfterConfirmOnly": list(REPLACE_GROUPS),
        },
        "groups": group_meta,
        "operationsDocumented": op_docs,
        "movesProvisional": moves,
        "counts": {
            "replaceItems": len(moves),
            "keepVendorItems": len(by_group.get("Auto Vendeor ALL", [])),
            "byTarget": {},
        },
        "openSteps": [
            "In-game /smarttsm migrate preview — reclassify with live TSM prices",
            "Paste import string into TSM Groups → Import (Shift-confirm)",
            "Verify item group paths via GetGroupPathByItem",
            "Manually assign Auctioning ops Smart Single/Stack or new Smart ops in TSM UI",
            "Owner confirmation required BEFORE deleting 1er Group and 20er AH Sell",
            "Do not delete Auto Vendeor ALL",
            "Do not create Smart Vendor duplicate",
        ],
        "deleteMarkers": {
            "1er Group": {"markedForDeletion": True, "confirmedByOwner": False},
            "20er AH Sell": {"markedForDeletion": True, "confirmedByOwner": False},
            "Auto Vendeor ALL": {"markedForDeletion": False},
        },
    }
    tgt_counts: dict[str, int] = defaultdict(int)
    for m in moves:
        tgt_counts[m["toGroup"]] += 1
    backup["counts"]["byTarget"] = dict(tgt_counts)

    bak_path = OUT / f"tsm-groups-backup-{ts}.json"
    bak_path.write_text(json.dumps(backup, indent=2, ensure_ascii=False), encoding="utf-8")
    (OUT / "tsm-groups-backup-latest.json").write_text(
        json.dumps(backup, indent=2, ensure_ascii=False), encoding="utf-8"
    )
    (OUT / "import-string.txt").write_text(import_str, encoding="utf-8")

    # Markdown report
    lines = [
        f"# TSM Gruppenmigration — Bericht ({ts})",
        "",
        f"Quelle: `{sv}`",
        "",
        "## Owner-Entscheidung",
        "",
        "- `1er Group` → Smart-Verkaufsgruppen ersetzen",
        "- `20er AH Sell` → Smart-Verkaufsgruppen ersetzen",
        "- `Auto Vendeor ALL` → **unverändert behalten**",
        "- Keine zweite Vendor-Gruppe (kein Smart Vendor in diesem Lauf)",
        "- Löschen von `1er Group` / `20er AH Sell` erst nach erneuter Owner-Bestätigung",
        "",
        "## Sicherung",
        "",
        f"- Backup JSON: `{bak_path.relative_to(ROOT)}`",
        f"- Itemzuordnungen gesichert: {sum(len(v) for v in by_group.values())} Einträge",
        "",
        "## Alte Gruppen",
        "",
    ]
    for g in list(REPLACE_GROUPS) + list(KEEP_GROUPS):
        meta = group_meta[g]
        lines.append(f"### {g}")
        lines.append(f"- Items: **{meta['itemCount']}**")
        lines.append(f"- Ops: `{json.dumps(meta['operations'], ensure_ascii=False)}`")
        lines.append("")

    lines += [
        "## Dokumentierte Auctioning-/Vendoring-Einstellungen",
        "",
    ]
    for op, settings in op_docs.items():
        lines.append(f"### {op}")
        if not settings:
            lines.append("- *(nicht gefunden / unbekannt)*")
        else:
            for k in (
                "minPrice",
                "normalPrice",
                "maxPrice",
                "postCap",
                "duration",
                "undercut",
                "keepQuantity",
                "maxExpires",
                "vsMarketValue",
                "enableSell",
            ):
                if k in settings:
                    lines.append(f"- `{k}`: `{settings[k]}`")
        lines.append("")

    lines += [
        "## Stackgrößen-Hinweise",
        "",
        "- `1er Group` / op **Smart Single Sell**: postCap=1, duration=3, undercut=0c → Einzelitems",
        "- `20er AH Sell` / op **Smart Stack Sell**: postCap=5, duration=2, undercut=0c → Material-Stacks",
        "- Gleiche Preisformeln für min/normal/max bei beiden Sell-Ops",
        "",
        "## Provisional Offline-Zuordnung (vor Live-Reclassify)",
        "",
        f"- Moves: **{len(moves)}**",
    ]
    for g, n in sorted(tgt_counts.items()):
        lines.append(f"- `{g}`: {n}")
    lines += [
        "",
        "## Import",
        "",
        "- Datei: `diagnostics/migration/import-string.txt`",
        "- Weg: TSM → Groups → Import (kein privater Tabellenwrite)",
        "",
        "## Noch offen",
        "",
    ]
    for s in backup["openSteps"]:
        lines.append(f"1. {s}")
    lines += [
        "",
        "## Löschmarkierung",
        "",
        "| Gruppe | Markiert | Owner-Löschfreigabe |",
        "|--------|----------|---------------------|",
        "| 1er Group | ja | **NEIN — STOP** |",
        "| 20er AH Sell | ja | **NEIN — STOP** |",
        "| Auto Vendeor ALL | nein | — |",
        "",
        "**STOP zur Owner-Abnahme. Kein automatisches Löschen.**",
        "",
    ]
    report = OUT / "MIGRATION_REPORT.md"
    report.write_text("\n".join(lines), encoding="utf-8")
    print(json.dumps({"backup": str(bak_path), "report": str(report), "moves": len(moves)}, indent=2))


if __name__ == "__main__":
    main()
