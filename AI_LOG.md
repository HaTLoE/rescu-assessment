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

### Example 2
- Date / ticket:2026-10-10, RES-101 debounce
- What the AI suggested:Claude (chat) told me to ask for a debounce test using fakeAsync.
- How I caught it:Claude Code checked and found fakeAsync is not exported by flutter_test; using it needs the fake_async package in pubspec.yaml, which the brief forbids changing.
- What I did instead:used testWidgets with tester.pump(duration), which gives a fake clock built into flutter_test with no dependency change.

## Suggestions I modified or rejected (smaller ones)
- I modified: RES-101: Claude’s first sketch put the stale check before the error log, so stale failures would leave no trace. It moved the log above the check during implementation.
- I modified: RES-101 debounce: Claude predicted test 5 would fail on the old code; it passed. It proved the test was still meaningful by temporarily breaking the code (test failed), then restored it.