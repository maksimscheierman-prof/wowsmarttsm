"""Mock TSM group integration — offline only."""
from __future__ import annotations


class MockTSM:
    def __init__(self):
        self.groups = {"": True}
        self.items = {}

    def CreateGroup(self, path):
        self.groups[path] = True

    def GetGroupPath(self, item):
        return self.items.get(item)

    def SetGroup(self, item, path):
        prev = self.items.get(item)
        if path is None:
            self.items.pop(item, None)
        else:
            assert path in self.groups or path == ""
            self.items[item] = path
        return prev


def test_existing_groups_untouched():
    tsm = MockTSM()
    tsm.CreateGroup("MyFarm")
    tsm.SetGroup("i:1", "MyFarm")
    tsm.CreateGroup("Smart TSM")
    tsm.CreateGroup("Smart TSM`Smart Quick Sell")
    tsm.SetGroup("i:2", "Smart TSM`Smart Quick Sell")
    assert tsm.GetGroupPath("i:1") == "MyFarm"
    assert tsm.GetGroupPath("i:2") == "Smart TSM`Smart Quick Sell"


def test_single_item_override():
    tsm = MockTSM()
    tsm.CreateGroup("A")
    tsm.CreateGroup("B")
    tsm.SetGroup("i:1", "A")
    tsm.SetGroup("i:2", "A")
    tsm.SetGroup("i:1", "B")
    assert tsm.GetGroupPath("i:1") == "B"
    assert tsm.GetGroupPath("i:2") == "A"


def test_undo_moves():
    tsm = MockTSM()
    tsm.CreateGroup("A")
    tsm.CreateGroup("B")
    tsm.SetGroup("i:1", "A")
    moves = [{"item": "i:1", "from": "A", "to": "B"}]
    for m in moves:
        tsm.SetGroup(m["item"], m["to"])
    # undo
    for m in reversed(moves):
        tsm.SetGroup(m["item"], m["from"])
    assert tsm.GetGroupPath("i:1") == "A"


def test_double_assign_last_wins():
    tsm = MockTSM()
    tsm.CreateGroup("A")
    tsm.CreateGroup("B")
    tsm.SetGroup("i:1", "A")
    tsm.SetGroup("i:1", "B")
    assert tsm.GetGroupPath("i:1") == "B"
