# Known Limitations

1. **In-game smoke test OPEN** until owner executes checklist.
2. **TSM_API surface variance** — group create/move may need manual Smart group bootstrap on some builds.
3. **Deposit/AH cut PARTIAL** — configurable defaults, not Forever-hard proven constants.
4. **No TSM Auctioning column injection** — separate Smart Manager window by design.
5. **SaleRate is a proxy**, not calibrated probability.
6. **SavedVariables** may lag or vanish on crash.
7. **Vendor assist** uses container APIs only with merchant open + confirm; no click automation.
8. **Cursor headless repair** not available; watchdog + queue + manual agent only.
9. **Equipment variants** use available itemString identity; deep bonus-ID parity depends on TSM ItemString helpers when exposed.
10. **UI visual acceptance pending** — see `OWNER_REVIEW.md`.
