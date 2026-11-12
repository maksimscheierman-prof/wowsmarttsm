"""Lightweight Lua syntax sanity checks (not a full parser)."""
from __future__ import annotations

from pathlib import Path


def check_file(path: Path) -> list[str]:
    errors: list[str] = []
    text = path.read_text(encoding="utf-8", errors="replace")
    # strip strings roughly for balance checks
    cleaned = []
    i = 0
    while i < len(text):
        ch = text[i]
        if ch == "-" and i + 1 < len(text) and text[i + 1] == "-":
            # long comment --[[ ... ]] or --[=[ ... ]=]
            if i + 3 < len(text) and text[i + 2] == "[":
                j = i + 3
                eq = 0
                while j < len(text) and text[j] == "=":
                    eq += 1
                    j += 1
                if j < len(text) and text[j] == "[":
                    close = "]" + ("=" * eq) + "]"
                    k = text.find(close, j + 1)
                    i = len(text) if k < 0 else k + len(close)
                    continue
            # line comment
            while i < len(text) and text[i] != "\n":
                i += 1
            continue
        if ch in ("'", '"'):
            quote = ch
            i += 1
            while i < len(text):
                if text[i] == "\\":
                    i += 2
                    continue
                if text[i] == quote:
                    i += 1
                    break
                i += 1
            continue
        cleaned.append(ch)
        i += 1
    body = "".join(cleaned)
    if body.count("(") != body.count(")"):
        errors.append("unbalanced ()")
    if body.count("{") != body.count("}"):
        errors.append("unbalanced {}")
    # keyword balance for function/end and if/end (approximate)
    # Count 'function' and 'end' tokens
    import re

    # Avoid matching the trailing "if" inside "elseif"
    tokens = re.findall(r"\b(function|elseif|else|if|for|while|repeat|until|end)\b", body)
    depth = 0
    for t in tokens:
        if t in ("function", "if", "for", "while", "repeat"):
            depth += 1
        elif t in ("elseif", "else"):
            # same block level as enclosing if
            pass
        elif t == "until":
            depth -= 1
        elif t == "end":
            depth -= 1
        if depth < 0:
            errors.append("unexpected end")
            break
    if depth != 0:
        errors.append(f"block depth residual={depth}")
    return errors


def check_tree(root: Path) -> dict:
    files = list(root.rglob("*.lua"))
    bad = []
    for f in files:
        errs = check_file(f)
        if errs:
            bad.append({"file": str(f), "errors": errs})
    return {"checked": len(files), "failed": bad}
