# AI usage log (working notes — copy into solutions.md section E at the end)

## Tools used
- Claude Code (VS Code extension) — code reading, root-cause analysis, tests, fixes, write-up drafts
- Claude (claude.ai chat) — reviewing my prompt against PROBLEM.md, planning, CLAUDE.md
- (add any others: Copilot, ChatGPT, …)

## Times the AI was wrong or misleading (need ≥ 2 REAL ones)
<!-- Fill in WHEN it happens. Never invent. -->

### Example 1
- Date / ticket:2026-10-10, RES-105 evidence
- What the AI suggested:Claude (chat) said the Memory tab’s “Default” dropdown switches to an Android memory view.
- How I caught it (test failed? read the code? DevTools? contradicted PROBLEM.md?):I opened it and it only had time ranges (1 min / 5 min / All).
- What I did instead:found the Android chart via the gear/settings option, and recorded that the image cache isn’t visible in the Dart heap chart.
- Suggestions I modified: RES-101: Claude’s first sketch put the stale check before the error log, so stale failures would leave no trace. It moved the log above the check during implementation.

### Example 2
- Date / ticket:
- What the AI suggested:
- How I caught it:
- What I did instead:

## Suggestions I modified or rejected (smaller ones)
-
