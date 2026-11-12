# Forever API Limitations

| Topic | Status | Notes |
|-------|--------|-------|
| Flavor | VERIFIED | `wowf` |
| TOC Interface | VERIFIED | Prefer `16001` (+ multi-flavor list like TSM) |
| Deposit formula | PARTIAL | Use live AH deposit when available; fallback rate configurable |
| AH cut | PARTIAL | Default 5% configurable in settings |
| Protected functions | UNSUPPORTED to bypass | No hardware bots; vendor requires merchant + confirm |
| SavedVariables mid-session | UNSUPPORTED as durable disk truth | Flush on logout/reload; crash may lose logs |
| Cross-addon error bus | PARTIAL | Own logger + chained `seterrorhandler`; BugSack coexistence |

Classic-like auctioning fields (post cap, stack size) are present in TSM Forever build — treat as Classic-family semantics unless Forever docs say otherwise.
