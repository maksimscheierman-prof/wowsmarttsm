"""Layout.AddButtonRow width / wrap regressions (incl. German labels)."""
from pathlib import Path
import sys

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "tools"))
from paths import ADDON_SRC

PAD = 24
GAP = 8
MIN_W = 72
MAX_W = 220


def measure(text: str, min_w=MIN_W, max_w=MAX_W) -> int:
    w = len(text) * 7 + PAD
    return max(min_w, min(max_w, w))


def layout_rows(labels, width: int):
    """Mirror AddButtonRow wrap logic with the offline char estimator."""
    rows = [[]]
    x = 0
    for text in labels:
        natural = measure(text)
        avail = width - x
        if x > 0 and natural + GAP > avail and avail < MIN_W + GAP:
            rows.append([])
            x = 0
            avail = width
        use_w = natural
        if use_w > avail and avail >= MIN_W:
            use_w = avail
        elif use_w > width:
            use_w = width
        rows[-1].append((text, use_w, x))
        x = x + use_w + GAP
    # Overlap check within each row
    for row in rows:
        for i in range(len(row) - 1):
            left_end = row[i][2] + row[i][1]
            right_start = row[i + 1][2]
            assert left_end <= right_start, (row[i], row[i + 1])
            assert right_start - left_end >= GAP - 0.01
        for _, w, start in row:
            assert start + w <= width + 0.01
    return rows


def test_layout_source_has_measure_and_wrap():
    layout = (ADDON_SRC / "UI" / "Layout.lua").read_text(encoding="utf-8")
    assert "function Layout.MeasureButtonWidth" in layout
    assert "shortenLabel" in layout
    assert "GameTooltip" in layout
    assert "BTN_GAP" in layout or "BTN_HEIGHT" in layout


def test_german_posting_buttons_no_overlap_narrow_frame():
    labels = [
        "Alle wählen",
        "Keine",
        "Auswahl übernehmen (Shift)",
        "Rückgängig",
    ]
    # Typical content width after padding/scroll gutter
    for width in (420, 520, 700, 900):
        rows = layout_rows(labels, width)
        assert sum(len(r) for r in rows) == 4
        # On narrow widths wrapping must occur rather than overlap
        if width <= 420:
            assert len(rows) >= 2


def test_settings_buttons_fit():
    labels = ["Locale de/en", "Dry-Run umschalten", "Debug umschalten"]
    rows = layout_rows(labels, 500)
    assert sum(len(r) for r in rows) == 3


def test_bulk_review_failed_ux_message():
    text = (ADDON_SRC / "UI" / "BulkReview.lua").read_text(encoding="utf-8")
    assert "Inventarbewertung fehlgeschlagen – Details unter Diagnose." in text
    assert "Erneut bewerten" in text
    assert "ui_retry_after_fail" in text
    assert 'eval.status == "FAILED"' in text


def test_version_semver():
    ver = (ADDON_SRC / "Core" / "Version.lua").read_text(encoding="utf-8")
    assert 'STRING = "0.' in ver
