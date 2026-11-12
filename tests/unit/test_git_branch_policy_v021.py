"""Offline checks for the durable main/dev branch policy (v0.2.1).

NOT an in-game test. Uses local git state only.
"""
from __future__ import annotations

import subprocess
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
V020 = "cadc85a5bc35c515f2bb4178060789918253ca88"
INITIAL = "387892185f62db6b3fdc6e925e922acac7d46ab7"


def _git(*args: str) -> str:
    r = subprocess.run(
        ["git", *args],
        cwd=ROOT,
        capture_output=True,
        text=True,
        check=True,
    )
    return r.stdout.strip()


def _ancestor(commit: str, branch: str) -> bool:
    r = subprocess.run(
        ["git", "merge-base", "--is-ancestor", commit, branch],
        cwd=ROOT,
    )
    return r.returncode == 0


def test_dev_contains_v020_commit():
    assert _ancestor(V020, "dev")
    # All feature commits reachable from tip
    for c in (
        INITIAL,
        "247d2b2",
        "977d64a",
        "c08e6e4",
        "047436b",
        "0250329",
        V020,
    ):
        assert _ancestor(c, "dev"), c


def test_main_is_initial_and_ancestor_of_dev():
    main = _git("rev-parse", "main")
    assert main.startswith("3878921")
    assert main == INITIAL
    assert _ancestor(main, "dev")


def test_no_open_merge_conflicts_in_workdir():
    status = _git("status", "--porcelain")
    assert "UU " not in status
    assert "AA " not in status


def test_agents_and_contributing_declare_two_branch_policy():
    agents = (ROOT / "AGENTS.md").read_text(encoding="utf-8")
    contrib = (ROOT / "CONTRIBUTING.md").read_text(encoding="utf-8")
    assert "dev" in agents and "main" in agents
    assert "two-branch" in agents.lower() or "Durable branch" in agents or "Zwei-Branch" in agents
    assert "Do **not** open new" in contrib or "Do not" in contrib
    assert "feature/*" in contrib


def test_bundle_backup_present():
    tracked = ROOT / "artifacts" / "git" / "wowsmarttsm-v0.2.0-cadc85a.bundle"
    local = ROOT / "backups" / "git" / "wowsmarttsm-v0.2.0-cadc85a.bundle"
    assert tracked.exists() or local.exists(), "historical v0.2.0 bundle must exist"


def test_current_branch_is_dev_for_active_work():
    branch = _git("rev-parse", "--abbrev-ref", "HEAD")
    assert branch == "dev"
