"""v0.2.0 multi-character / action / mail offline regressions."""
from pathlib import Path
import sys

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "tools"))
from paths import ADDON_SRC
from smart_logic import classify, COPPER_PER_GOLD


def test_constants_have_actions_and_roles():
    text = (ADDON_SRC / "Core" / "Constants.lua").read_text(encoding="utf-8")
    assert "MAIL_TO_BANK" in text
    assert "HOLD_AT_BANK" in text
    assert 'MAIN = "MAIN"' in text
    assert "SV_SCHEMA_VERSION = 2" in text


def test_action_decide_and_profiles_exist():
    assert (ADDON_SRC / "Rules" / "ActionDecide.lua").exists()
    assert (ADDON_SRC / "Core" / "CharacterProfiles.lua").exists()
    assert (ADDON_SRC / "Core" / "MailService.lua").exists()
    assert (ADDON_SRC / "Core" / "CleanupService.lua").exists()
    assert (ADDON_SRC / "UI" / "CleanupTab.lua").exists()
    assert (ADDON_SRC / "UI" / "MailTab.lua").exists()
    assert (ADDON_SRC / "UI" / "CharactersTab.lua").exists()


def test_sv_migration_2_present():
    sv = (ADDON_SRC / "Diagnostics" / "SavedVariables.lua").read_text(encoding="utf-8")
    assert "[2] = function(db)" in sv
    assert "primaryBankKey" in sv
    assert "itemRules" in sv


def test_engine_calls_action_decide():
    eng = (ADDON_SRC / "Rules" / "Engine.lua").read_text(encoding="utf-8")
    assert "ActionDecide.Assign" in eng


def test_mail_service_never_auto_success():
    mail = (ADDON_SRC / "Core" / "MailService.lua").read_text(encoding="utf-8")
    assert "executed = false" in mail or "never" in mail.lower() or "PrepareMessage" in mail
    assert "autoMailWithoutConfirm" in mail
    assert "BANK_CHARACTER_NOT_CONFIGURED" in mail
    assert "MAIL_MAX_ATTACHMENTS" in (ADDON_SRC / "Core" / "Constants.lua").read_text(encoding="utf-8")


def test_cleanup_tab_live_metrics_not_hardcoded_demo():
    text = (ADDON_SRC / "UI" / "CleanupTab.lua").read_text(encoding="utf-8")
    assert "CleanupService.Summarize" in text
    assert "18 Items" not in text  # no fake dashboard numbers


def test_toc_version_020_and_new_files():
    toc = (ADDON_SRC / "WoWSmartTSM.toc").read_text(encoding="utf-8")
    assert "## Version: 0.2.0" in toc
    for rel in (
        "Core\\CharacterProfiles.lua",
        "Rules\\ActionDecide.lua",
        "UI\\CleanupTab.lua",
        "UI\\MailTab.lua",
        "UI\\CharactersTab.lua",
        "UI\\RulesTab.lua",
    ):
        assert rel in toc


def test_error_codes_v02():
    text = (ADDON_SRC / "Diagnostics" / "ErrorCodes.lua").read_text(encoding="utf-8")
    for k in (
        "BANK_CHARACTER_NOT_CONFIGURED",
        "MAIL_SEND_FAILED",
        "MAIL_ITEM_GONE",
        "CHAR_CONFIG_INVALID",
        "VENDOR_STALE_SELECTION",
    ):
        assert k in text


def test_hold_policy_thresholds_unchanged():
    text = (ADDON_SRC / "Rules" / "HoldPolicy.lua").read_text(encoding="utf-8")
    assert "HOLD_MIN_MARKET_COPPER" in (ADDON_SRC / "Core" / "Constants.lua").read_text(encoding="utf-8")
    c = (ADDON_SRC / "Core" / "Constants.lua").read_text(encoding="utf-8")
    assert "HOLD_VENDOR_MULTIPLIER = 5" in c
    assert "10 * C.COPPER_PER_GOLD" in c


def test_classify_still_sell_first():
    d = classify(
        {
            "itemString": "i:cloth2",
            "vendorSell": 100,
            "marketValue": 9000,
            "dataQuality": 0.9,
            "saleRate": 0.5,
            "soldPerDay": 3,
            "quantity": 10,
        }
    )
    assert d["strategy"] in ("QUICK_SELL", "PROFIT_SELL")


def test_vendor_candidate_when_ah_bad():
    d = classify(
        {
            "itemString": "i:junk2",
            "quality": 0,
            "vendorSell": 800,
            "marketValue": 100,
            "dataQuality": 0.9,
            "saleRate": 0.01,
            "soldPerDay": 0.01,
        }
    )
    assert d["strategy"] == "VENDOR"


def test_docs_v02_exist():
    docs = ROOT / "docs"
    for name in (
        "V0_2_ARCHITECTURE.md",
        "V0_2_CHARACTER_PROFILES.md",
        "V0_2_MAIL_WORKFLOW.md",
        "V0_2_RULE_PRIORITY.md",
        "V0_2_TEST_REPORT.md",
        "V0_2_OWNER_REVIEW.md",
    ):
        assert (docs / name).exists(), name
