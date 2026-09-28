<!-- gitnexus:start -->
# GitNexus — Code Intelligence (optional)

This project is indexed by GitNexus as **stat_trac_technical_mobile** (3351
symbols, 5817 relationships, 62 execution flows at 2026-09-28).

**Optional, not a gate — decided by the user 2026-09-28.** Nothing requires a
GitNexus check before an edit or a commit. The gates are `flutter test`,
`flutter analyze`, and a check on a real phone. It was broken for a whole
session and nothing suffered; its index is a snapshot that goes stale, and it
cannot see Riverpod providers or callbacks, which is how most of this app is
wired — so a "low risk" from it is weakest exactly where the app is most
connected.

**Use it when it helps:** before changing a class or function that many files
use, `impact({target: "Name", direction: "upstream", repo:
"stat_trac_technical_mobile"})` for the blast radius; `context({name})` for a
symbol's callers and callees; `detect_changes()` as an extra look before a big
commit. A text search is an equally valid way to find usages. `UNKNOWN` risk or
an empty caller list means "could not tell", never "safe".

**Re-index after larger changes, and always with both flags**, or it rewrites
this section back to mandatory rules and adds duplicate skill folders:

```
node .gitnexus/run.cjs analyze --skip-agents-md --skip-skills
```

Skill notes: `.claude/skills/gitnexus/` (exploring, impact-analysis,
debugging, refactoring, guide, cli).
<!-- gitnexus:end -->
