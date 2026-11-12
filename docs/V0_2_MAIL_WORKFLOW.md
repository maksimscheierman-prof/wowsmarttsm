# Mail Workflow

## MAIN send

1. Bank configured? Else stop with `BANK_CHARACTER_NOT_CONFIGURED`.
2. Same faction check (`BANK_FACTION_MISMATCH`).
3. Collect `MAIL_TO_BANK` + `HOLD_AT_BANK`.
4. Split into messages of ≤ `MAIL_MAX_ATTACHMENTS` (12, PARTIAL).
5. Show plan; Shift+Prepare fills Send Mail UI.
6. Player clicks Send — plan is never marked successful by prepare alone.
7. Tokens prevent double-prepare in-session.

## BANK inbox

Detect received items via bag AutoEval after loot/mail take; classify into posting vs Hold. No forced auto-loot (API-limited).

## Forbidden

Hardware input bots; silent SendMail without player Send click; auto mail when `autoMailWithoutConfirm` (always blocked in code path).
