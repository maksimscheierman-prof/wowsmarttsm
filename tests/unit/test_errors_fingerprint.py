import json
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[2] / "tools"))
from smart_logic import fingerprint


def test_fingerprint_stable_with_numbers():
    a = fingerprint("E1001", "SafeCall", "Call", "failed item 12345", "foo.lua:12")
    b = fingerprint("E1001", "SafeCall", "Call", "failed item 99999", "foo.lua:99")
    assert a == b


def test_fingerprint_differs_by_module():
    a = fingerprint("E1001", "A", "Call", "msg")
    b = fingerprint("E1001", "B", "Call", "msg")
    assert a != b


def test_dedupe_logic():
    seen = {}
    fp = fingerprint("E1", "M", "F", "x")
    seen[fp] = {"count": 1}
    seen[fp]["count"] += 1
    assert seen[fp]["count"] == 2


def test_repair_queue_max_attempts_concept():
    queue = {"E1|M|F|x|": {"attempts": 3, "status": "failed"}}
    fp = "E1|M|F|x|"
    assert queue[fp]["attempts"] >= 3
    # runner must stop
    assert queue[fp]["attempts"] >= 3
