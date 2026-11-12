# Rule Priority

Highest first:

1. Hard protect (quest, equipped, locked, unknown metadata, explicit protect)
2. Session / character / account Ignore & Keep / Min-Keep (`ItemRules`)
3. Crafting reserves (`CraftingReserve`)
4. Consumables (`Consumables`, conservative protect-all if no min qty)
5. Smart Hold → `HOLD_AT_BANK` on MAIN (policy unchanged)
6. Market strategy → transport mapping by role

Account rules lose to character rules; once-ignore is session-only.

Smart Hold never merges into normal AH mail batches visually — same mail plan but distinct `HOLD_AT_BANK` action and Hold UI on BANK.
