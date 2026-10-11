# AI usage log (working notes — copy into solutions.md section E at the end)

## Tools used
- Claude Code (VS Code extension) — code reading, root-cause analysis, tests, fixes, write-up drafts
- Claude (claude.ai chat) — reviewing my prompt against PROBLEM.md, planning, CLAUDE.md

## Times the AI was wrong or misleading (need ≥ 2 REAL ones)

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
- What I did instead: use the decode size in the console line ("display size A×B but a decode size of C×D") as the before/after evidence, not whether the image is flipped. Confirmed on the emulator: feed images are still flagged after the fix (cover crop), while the feed card's decode size went from 1600×1200 (+7821 KB) to 996×747 (+1696 KB).
### Example 4
- Date / ticket: 2026-10-11, F-1 commit 3
- What the AI suggested/did: Claude Code ran dart format on the whole lib/ and test/ folders instead of only the changed files, which reformatted 5 unrelated files including the forbidden lib/service/fake_api_service.dart.
- How I caught it: Claude Code noticed it in the formatter output and reported it; I then verified myself with git status and `git diff e5ee445 --stat -- lib/service/fake_api_service.dart assets/data` (empty).
- What I did instead: restored the files from git, and the rule is now "format only the files you changed".

### Example 5
- Date / ticket: 2026-10-10, RES-107
- What the AI suggested: Claude Code read GetX's `initialRoutesGenerate` and predicted that on a cold start the deep link would open with ONLY the deal page in the stack (no Home underneath, back would exit the app), and proposed a possible extra commit adding a Home button.
- How I caught it: I tested a cold start with adb after the fix: deal 42 opened and back returned to Home.
- What I did instead: no Home-button commit. The prediction came from reading one function without running it; why it was wrong was not investigated.

### Example 6
- Date / ticket: 2026-10-11, RES-105 commit 2
- What the AI suggested: Claude Code said the lazy list + keys change would have little measurable effect ("rebuild counts ≈ commit 1", "DevTools shows little of it"). Claude (chat) predicted about 3-6 DealCard builds per single "Pickup today" toggle.
- How I caught it: I measured 24 and 27 DealCard builds for single toggles on the commit 2 code (DealCard at home_screen.dart:119 in the screenshot), far above the 3-6 predicted. Those readings were uncontrolled, so I ran a controlled A/B test (same steps on both versions, commit 2 stashed for the "before" run).
- What I did instead: used the A/B result as the evidence for commit 2: about 3 on/off toggles gave DealCard 102 on the commit 1 code and 15 on the commit 2 code. So commit 2 has its own measured effect, not just a "structural" one.

### Example 7
- Date / ticket: 2026-10-11, F-1 commit 1
- What the AI suggested/did: Claude Code wrote the ClockService tests using `Get.delete<ClockService>()` to close the service.
- How I caught it: the three clock tests failed after implementing (expected 00:00:01, actual 00:00:06 — the clock kept ticking after "closing"). Claude Code then checked the GetX 4.7.3 source: `Get.delete` silently refuses to delete a GetxService unless `force: true` (get_instance.dart:377).
- What I did instead: the tests use `force: true`; the app code did not change. It also taught me that GetX never closes a service by itself, so the clock's timer runs for the whole app (which is the intended design).

## Suggestions I modified or rejected (smaller ones)
- I modified: RES-101: Claude’s first sketch put the stale check before the error log, so stale failures would leave no trace. It moved the log above the check during implementation.
- I modified: RES-101 debounce: Claude predicted test 5 would fail on the old code; it passed. It proved the test was still meaningful by temporarily breaking the code (test failed), then restored it.
- I modified: RES-102: Claude predicted test 2 would pass on the old code; it failed because testWidgets reports any timer still pending after teardown, so every test of the old widget fails. Kept the test as a "still ticks on screen" guard.
- I modified: RES-104: Claude's first version of test 8 failed on the correct old code. The fault was in the test: pull_to_refresh updates the footer after the next frame, and tester.pump() alone drew no frame. It added a settle() helper and re-ran before trusting the result.
- RES-105: Claude's first image-decode rule (width if box wider than tall) would have upscaled the details header on phones under ~350 pt wide. I asked for an audit of every image usage; it found the gap and changed the rule to compare against the image's 4:3 shape.