# v0.2.3 Owner Review

**Version:** 0.2.3 on `dev` (not a `main` release)

## In-game steps

1. `/reload` after install.
2. Confirm addon version **0.2.3**.
3. **On Banko:** Characters tab → role BANK / primary bank = Banko. `/smarttsm scan` then Cleanup.
   - Metrics show **AH vorbereiten**, not „An Bank senden“.
   - Rentable items: action **AH vorbereiten** (`POST_AH`).
   - No `BANK_CHARACTER_NOT_CONFIGURED` on rentable AH items.
   - Left-click opens detail; right-click opens menu.
4. **On Azamat:** role MAIN, primary bank = Banko. Rescan.
   - Rentable → **An Bank senden**.
   - Human reason about mailing to bank; next step mailbox.
5. Click aggregated dust row → detail shows total qty and bag/slot list.
6. Confirm no automatic vendor sell / mail send without your confirm at NPC/mailbox.

## Acceptance

- [ ] Azamat: rentable → mail to Banko  
- [ ] Banko: rentable → AH prepare, never mail-to-self  
- [ ] Items clickable + detail + context menu  
- [ ] Protect rules still hold  
- [ ] PASS / FAIL
