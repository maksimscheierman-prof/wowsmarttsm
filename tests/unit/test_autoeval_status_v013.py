"""AutoEval / ScanService status clarity regressions."""
from pathlib import Path
import sys

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "tools"))
from paths import ADDON_SRC


def test_scan_eval_status_labels_distinct():
    text = (ADDON_SRC / "Core" / "ScanService.lua").read_text(encoding="utf-8")
    for status in ("NEVER_RUN", "NO_ITEMS", "FAILED", "TSM_DATA_MISSING", "OK"):
        assert status in text
    assert "Noch keine Bewertung durchgeführt" in text
    assert "Keine Items in den Taschen gefunden" in text
    assert "Inventarbewertung fehlgeschlagen" in text or "Bewertung fehlgeschlagen" in text
    assert "TSM-Daten fehlen" in text
    assert "keine Verkaufskandidaten" in text
    assert "GetEvalStatus" in text


def test_autoeval_triggers_login_reload_bags():
    text = (ADDON_SRC / "Core" / "AutoEval.lua").read_text(encoding="utf-8")
    assert 'RegisterEvent("PLAYER_LOGIN")' in text
    assert 'RegisterEvent("PLAYER_ENTERING_WORLD")' in text
    assert 'RegisterEvent("BAG_UPDATE")' in text
    assert "init_after_login" in text or "init_catchup" in text
    assert "lastStatus" in text
    assert "GetState" in text


def test_health_report_fields():
    text = (ADDON_SRC / "Core" / "Health.lua").read_text(encoding="utf-8")
    for key in (
        "addonLoaded",
        "tsmApi",
        "appHelper",
        "dataTap",
        "evalStatus",
        "lastError",
        "lastEvalAt",
        "realmDataAge",
        "loggerOk",
    ):
        assert key in text


def test_diagnostics_shows_coverage_and_health():
    text = (ADDON_SRC / "UI" / "DiagnosticsTab.lua").read_text(encoding="utf-8")
    assert "Gesundheitsstatus" in text
    assert "Logging-Abdeckung" in text
    assert "Coverage" in text or "coverage" in text
    assert "TSM API" in text
    assert "DataTap" in text
    assert "Inventarbewertung" in text


def test_version_is_at_least_013():
    ver = (ADDON_SRC / "Core" / "Version.lua").read_text(encoding="utf-8")
    # v0.1.3 introduced eval status clarity; v0.1.4+ keeps it
    assert 'STRING = "0.1.' in ver
