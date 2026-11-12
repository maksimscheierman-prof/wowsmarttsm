#!/usr/bin/env python3
"""Offline test runner. Never claims in-game success."""
from __future__ import annotations

import argparse
import importlib.util
import json
import sys
import traceback
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "tools"))


def load_tests(paths: list[Path]):
    tests = []
    for path in paths:
        name = path.stem
        spec = importlib.util.spec_from_file_location(name, path)
        mod = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(mod)
        for attr in dir(mod):
            if attr.startswith("test_"):
                tests.append((path.name, attr, getattr(mod, attr)))
    return tests


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--all", action="store_true")
    ap.add_argument("--unit", action="store_true")
    ap.add_argument("--integration", action="store_true")
    args = ap.parse_args()
    if not args.unit and not args.integration:
        args.all = True

    files = []
    if args.all or args.unit:
        files += sorted((ROOT / "tests" / "unit").glob("test_*.py"))
    if args.all or args.integration:
        files += sorted((ROOT / "tests" / "integration").glob("test_*.py"))

    tests = load_tests(files)
    passed = failed = 0
    failures = []
    for file, name, fn in tests:
        try:
            fn()
            passed += 1
            print(f"PASS  {file}::{name}")
        except Exception as e:
            failed += 1
            failures.append({"file": file, "test": name, "error": str(e), "trace": traceback.format_exc()})
            print(f"FAIL  {file}::{name} — {e}")

    summary = {
        "mode": "OFFLINE_MOCK",
        "note": "These results are NOT in-game smoke tests.",
        "passed": passed,
        "failed": failed,
        "total": passed + failed,
        "failures": failures,
    }
    out = ROOT / "diagnostics" / "latest-test-summary.json"
    out.parent.mkdir(parents=True, exist_ok=True)
    out.write_text(json.dumps(summary, indent=2), encoding="utf-8")
    print()
    print(f"Offline tests: {passed} passed, {failed} failed (NOT in-game)")
    return 0 if failed == 0 else 1


if __name__ == "__main__":
    raise SystemExit(main())
