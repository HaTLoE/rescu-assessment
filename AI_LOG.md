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

### Example 3
- Date / ticket: 2026-10-11, RES-105 commit 3
- What the AI suggested: Claude Code predicted "no highlighted images" in the feed after decoding images at display size.
- How I caught it: Claude Code checked its own claim against the Flutter 3.27 source (painting/decoration_image.dart) before I measured: an image is flagged when its decoded size exceeds the visible box by more than 128 KB, and a cover-cropped 4:3 photo in a wide card still does.
- What I did instead: use the decode size in the console line ("display size A×B but a decode size of C×D") as the before/after evidence, not whether the image is flipped. To be confirmed on the emulator.

## Suggestions I modified or rejected (smaller ones)
- I modified: RES-101: Claude’s first sketch put the stale check before the error log, so stale failures would leave no trace. It moved the log above the check during implementation.
- I modified: RES-101 debounce: Claude predicted test 5 would fail on the old code; it passed. It proved the test was still meaningful by temporarily breaking the code (test failed), then restored it.
- I modified: RES-102: Claude predicted test 2 would pass on the old code; it failed because testWidgets reports any timer still pending after teardown, so every test of the old widget fails. Kept the test as a "still ticks on screen" guard.
- I modified: RES-104: Claude's first version of test 8 failed on the correct old code. The fault was in the test: pull_to_refresh updates the footer after the next frame, and tester.pump() alone drew no frame. It added a settle() helper and re-ran before trusting the result.
- RES-105: Claude's first image-decode rule (width if box wider than tall) would have upscaled the details header on phones under ~350 pt wide. I asked for an audit of every image usage; it found the gap and changed the rule to compare against the image's 4:3 shape.