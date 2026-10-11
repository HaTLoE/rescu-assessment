# Master prompt — Yindii / Rescu Flutter assessment

> Paste this into Claude Code in VS Code at the start. CLAUDE.md (already in the repo) holds the permanent rules —
> follow it at all times. This prompt holds the task details and the phase plan.

## ROLE AND OBJECTIVE

Act as a senior Flutter engineer, code reviewer, performance engineer, and technical interviewer.

Help me complete the Yindii Junior Frontend Developer take-home assessment (Rescu app, see `PROBLEM.md`).
I am entry-level. I need a correct, clean solution that I fully understand and can explain line by line in the interview.

Grading (from PROBLEM.md): diagnosis quality over volume, performance awareness (they open the branch in DevTools),
decision-making on underspecified parts, and process (commit history, honesty, AI usage log).
Five tickets root-caused well beat seven patched superficially.

## SCOPE TARGET (adjust after Phase 1)

- Priority 1: RES-101, RES-102, RES-103, RES-106, RES-107
- Priority 2: RES-104, then F-1 (complete and profiled)
- Priority 3, only if time allows: RES-105 (needs my DevTools before/after), F-2, F-3
- After Phase 1, tell me if the real code suggests a different order (e.g. a fix one ticket depends on).

## PART A — BUG TICKETS

For every ticket: follow the bug workflow in CLAUDE.md. Never assume the cause from the ticket text.

### RES-101 — Search shows results for an earlier query
Symptom: typing "sushi" quickly; results for an older, shorter query replace the correct ones.
Investigate: overlapping async requests, completion order, whether stale responses can write state, debounce,
loading/error/empty states, pending work on controller close.
Requirements: results always match the latest query; stale responses never overwrite newer ones; debounce alone is
NOT the correctness fix; empty query handled; no unhandled async errors.
Test: controlled futures (Completer) where an earlier request finishes AFTER a later one.

### RES-102 — Crash after leaving My Orders
Symptom: open My Orders with an upcoming pickup, go back → `setState() called after dispose()`.
Investigate: widget State lifecycle vs GetxController lifecycle, timers, streams, listeners, async callbacks after navigation,
who owns each resource.
Requirements: fix the ownership problem (not just a `mounted` check); cancel at the correct lifecycle boundary;
opening/closing repeatedly must not accumulate resources.
Explain the widget vs GetX lifecycle difference (needed for Design Q1).

### RES-103 — Requests pile up after visiting deal pages
Symptom: after viewing several deals, one "Add to bag" triggers `GET /deals/:id` for every deal viewed earlier.
Investigate: GetX workers (`ever`, `once`, `debounce`, `interval`), listeners on app-wide services, controller
registration/deletion, route bindings.
Requirements: one action → only the intended request(s); closed screens leave no listeners; reopening doesn't duplicate.
Do NOT hide it with global request de-duplication.
Test: count requests across repeated open/close.

### RES-104 — Duplicate deals after refresh during pagination
Symptom: next page loading + pull-to-refresh → duplicate cards or more items than the catalog.
Investigate: page index/cursor, concurrent refresh + pagination, loading flags, stale responses.
Requirements: deterministic interaction; stale page responses can't corrupt refreshed data; no duplicates; no lost items;
loading flags reset on success AND failure; no infinite pagination loops. Use deal IDs (not object identity) if dedup is needed.
Tests: normal pagination; refresh while page pending; pagination failure; repeated triggers; refresh then paginate.

### RES-105 — Feed jank and memory growth
Symptom: janky scroll, whole feed rebuilds during scroll, image cache balloons. Brief says more than one cause.
Investigate: broad `Obx`, eager vs lazy list building, keys, repeated computations in build, image decode size/cache,
state updates during scroll, repeated API calls.
Requirements: explain each cause with evidence; lazy lists; tight `Obx` scope; keep scroll + pagination correct;
no arbitrary global cache limits; don't remove images or features.
IMPORTANT: before ANY change, stop and remind me to capture "before" DevTools evidence on the Android emulator in
DEBUG mode (I have no physical device). Give me exact steps.
Frame times from debug mode are not representative — use rebuild counts and memory/image evidence instead.
Never write numbers I didn't give you.

### RES-106 — Wrong pickup times; "Pickup today" misses deals
Symptom: 06:00–09:30 shows 23:00–02:30; some stores with pickup today missing from the filter. API sends ISO-8601 UTC.
Investigate: parsing, `toLocal()`/`toUtc()`, double conversion, local vs UTC date comparison, windows crossing midnight.
Requirements: correct parsing; display in local time; correct midnight handling; "today" = local calendar day;
no string hacks or hardcoded offsets; make "now" injectable (minimal seam) so it's testable.
Tests: UTC/local boundary cases, midnight-crossing windows. Explain the strategy (needed for Design Q3).
Note: `flutter test` runs in the machine's time zone — explain how the tests stay valid regardless of TZ.

### RES-107 — Deep link crashes (deal not loaded)
Symptom: `rescu://open/deal?id=42&source=push` → `type 'Null' is not a subtype of type 'DealModel'`. Works from home feed.
Requirements: link lands on a FULLY WORKING deal page (deal 42 exists — an error page is NOT acceptable);
fetch the deal via the repository when not passed in; respect route/binding/controller architecture;
loading state before content; safe handling of malformed or missing IDs; no hardcoding 42; no duplicate requests;
keep the existing link format.
Tests: open an existing deal directly when not previously loaded; invalid/missing id.

## PART B — FEATURES

Read `fake_api_service.dart`, `analytics_service.dart`, `cart_service.dart` contracts first. Never invent API parameters.

### F-1 — Live flash-sale countdowns
Replace "Ends soon" with a live countdown (`mm:ss`, or `hh:mm:ss` above one hour) on: flash rail, home feed cards, details screen.
- At zero: disabled "Expired" state; can't add to bag; if already in bag, remove it with a visible notice.
- No negative values; all appearances of the same deal stay consistent.
- PERFORMANCE: 100+ visible countdowns; per-second rebuilds only on the countdown text, not cards, not the list.
  Prefer one shared ticker over one timer per card. Clean up on dispose.
- Tests: <1h, >1h, expiry, expiry while in bag, expiry during navigation, no negatives, timer cleanup.
- I will profile it in DevTools (Flutter Inspector "track widget rebuilds").

### F-2 — Impression tracking
Using `AnalyticsService`: log `deal_impression` when a card is ≥50% visible for 1 continuous second.
Props: `deal_id`, `source` (`home_feed` | `flash_rail` | `search`), `position` (index in its list).
- Once per deal per app session across all screens.
- Batch via `FakeApiService.sendAnalyticsBatch`: flush at 10 events OR 15s since the first unsent event.
- Handle visibility dropping before 1s, cards leaving viewport, failures/retry per the service contract, timer cleanup.
- No scroll regression. `visibility_detector` is allowed.
- Tests: dedup, continuous visibility, properties, batch size, timeout flush, cleanup.

### F-3 — Stock reservations with optimistic UI
Use `reserveDeal` / `releaseReservation` / `reservationId` on checkout. Reservation = 5 min hold, intermittent 409.
- Optimistic add, then reconcile; on failure roll back with a clear, non-technical message.
- Each bag line shows remaining hold time.
- Remove / reduce quantity releases or adjusts the hold (per actual contract).
- Checkout passes reservation ids; handle `410 reservation expired` gracefully.
- No duplicate reservations from repeated taps.
- Underspecified on purpose: what happens when a hold expires while in the app or mid-checkout?
  Propose 2–3 policies with trade-offs, let ME choose, then implement. Cover detection, bag update, user notice,
  checkout racing with expiry, never silently restoring an expired hold.
- Tests: optimistic add, success, 409 rollback, release, expiry, checkout ids, 410.

## PART C — solutions.md (at repo root, written at the end from PROGRESS.md + AI_LOG.md)

A. Summary: done / not done / key decisions / what is actually verified.
B. Per ticket/feature: symptom, root cause (with code refs), files, why this fix, ≥1 rejected alternative and why,
   edge cases handled AND edge cases deliberately NOT handled (with reason), tests added, commands + real results, limitations.
   Unfinished items: what was investigated, what remains, next step.
C. RES-105 evidence: device (Android emulator), Flutter version, build mode (debug — no physical device), scenario, before/after screenshots or numbers, interpretation.
D. F-3 expiry decision: chosen policy, alternatives, why.
E. AI usage log: tools used and for what; accepted/modified/rejected suggestions; how verified;
   ≥2 REAL examples where AI was wrong or misleading (from AI_LOG.md — never invented).
F. Design questions, one paragraph each, referencing the actual code:
   Q1: GetxController lifecycle vs widget State lifecycle; name one Part A bug caused by confusing them.
   Q2: When does one big `Obx` hurt? How to decide reactivity scope?
   Q3: An automated test that would have caught RES-106; what code change makes it possible?
G. Time spent (honest, I will give you the numbers) and what I'd do with one more day.

## PHASES

- Phase 1: Read README, PROBLEM, .fvmrc, pubspec, analysis_options, all of `lib/`, `test/`. Produce:
  architecture map; relevant files per ticket/feature; first hypotheses (marked as unverified);
  dependencies between fixes; prioritized plan; risks/questions for me. NO code changes.
- Phase 2: Baseline — tool versions, `git log` start commit, `pub get` (no upgrade), `flutter analyze`, `flutter test`.
  Record pre-existing failures. Create PROGRESS.md.
- Phase 3: Priority 1 tickets, one at a time, one commit each.
- Phase 4: Priority 2.
- Phase 5: Priority 3 if time allows.
- Phase 6: Full test + analyze + final diff review; confirm forbidden files untouched (`git diff upstream/main --stat -- lib/service/fake_api_service.dart assets/data/` must be empty).
- Phase 7: solutions.md, final checklist (verified / unverified / incomplete).

End every phase with the report described in CLAUDE.md and wait for me.

**Start with Phase 1 only.**
