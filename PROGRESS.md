# Progress tracker

Started: 2026-10-10 · Deadline: reply to email within one week (≈ 2026-10-17)
Starter commit (upstream/main): e5ee445

## Time log (honest, rough)
| Date | Hours | What |
|---|---|---|
| | | |

## Status
| Item | Status | Commit | Notes / open questions |
|---|---|---|---|
| Baseline (analyze/test) | done 2026-10-10 | | analyze: no issues. test: 1/1 passed. See "Phase 2 baseline" below |
| RES-101 Search stale results | done — fixed + tested + confirmed on emulator | a2c248e (guard), 64b794c (debounce) | Emulator confirmed 2026-10-10: typing "sushi" quickly ends on sushi results and they stay; clearing the box shows the hint. See "RES-101 notes" below. Debounce done as a separate commit; emulator confirmed 2026-10-10: typing "sushi" quickly shows one `GET /deals/search?q=sushi` |
| RES-102 My Orders crash | done — fixed + tested (bug reproduced on emulator before the fix; emulator re-check after the fix not recorded) | 2b0dde3 | See "RES-102 notes" below. Reproduced on emulator 2026-10-10: open My orders, press back → "setState() called after dispose(): _PickupCountdownState" at pickup_countdown.dart:22:7 |
| RES-103 Request pile-up | done — fixed + tested + confirmed on emulator | 98a1539 | Reproduced on emulator 2026-10-10 before the fix: viewed deals 1, 4, 6, 7, then one Add to bag on deal 7 → 4 requests (deals 6, 4, 7, 1). After the fix (full restart): one Add to bag on deal 7 → one re-check and one `GET /deals/7`. See "RES-103 notes" below |
| RES-104 Duplicate deals | done — both commits; footer fix confirmed on emulator (page 2 loads again after refresh); the race itself was never reproduced by hand, proven by tests | ee103c7 (A: race), 64c64b7 (B: refresh failure + footer) | See "RES-104 notes" below. Manual attempt 2026-10-10: console showed `GET /deals?page=2` then `GET /deals?page=1` twelve seconds later, so the two requests did not overlap. `getDeals` latency is 250–950 ms, so the race window is under 1 s. Cause is from code reading; to be proven by a Completer-based test |
| RES-105 Feed jank / memory | before-evidence captured | | Emulator Pixel API 37, debug mode, Flutter 3.27.0. ~30s scroll: Scaffold/AppBar rebuilt ~106x, DealCard 501x, CachedNetworkImage 709x; ~45-53 FPS with jank frames. ~3 min scroll pages 1-6: memory flat (~90MB Dart heap, ~400MB RSS) — growth NOT reproduced on emulator. Screenshots in docs/before/ |
| RES-106 Pickup times / filter | done — fixed + tested + confirmed on emulator | 78cea08 | Decided 2026-10-10: show times in the phone's time zone (not a fixed market time zone). Emulator (time zone Asia/Bangkok) confirmed 2026-10-10: Baan Somtam Kitchen shows 05:30 – 08:00, Sunrise Bakehouse 06:00 – 09:30 (before the fix Baan Somtam showed 22:30 – 01:00). Screenshots: docs/before/06_res106_times.png, docs/after/06_res106_times.png. See "RES-106 notes" below |
| RES-107 Deep link crash | done — fixed + tested + confirmed on emulator | 059be5c | Emulator confirmed 2026-10-10 after the fix: deep link id=42 loads the full page and Add to bag works; id=abc shows "This link is not valid."; feed cards open with no extra request; cold start via adb opens deal 42 and back returns to Home. See "RES-107 notes" below. Reproduced on emulator 2026-10-10 via Home ⋮ → Simulate deep link (`rescu://open/deal?id=42&source=push`): red screen "type 'Null' is not a subtype of type 'DealModel' in type cast". Screenshot: docs/before/11_res107_screen.png. Cold start via adb NOT yet tried |
| F-1 Countdowns | todo | | |
| F-2 Impressions | todo | | |
| F-3 Reservations | todo | | Expiry policy decision: |
| solutions.md | todo | | |

## Phase 1 summary (redone 2026-10-10 in C:\dev\rescu — the earlier run was in an old copy without git)

Architecture, in short:
- `main.dart` registers app-wide services (`FakeApiService`, `AnalyticsService`, `CartService`, all permanent)
  and the three repos (lazy, `fenix: true`).
- `routes/routes.dart` maps each route to a screen + a binding. The binding creates that screen's controller,
  and GetX deletes the controller when the route is popped.
- Data flow: Screen (`GetView`) → Controller (`.obs` state) → Repo (JSON → model) → `FakeApiService`.

Root causes — found by READING the code only. None reproduced in the running app yet
(RES-105 is the exception: it has measured before-evidence).

| Ticket | Root cause | Where |
|---|---|---|
| RES-101 | Every keystroke starts a search and whichever response arrives LAST wins. Nothing checks that the response belongs to the latest query. The API is slower for short queries (1 letter ≈ 1.1–1.4s, 5 letters ≈ 0.2–0.5s), so "s" lands after "sushi" and overwrites it. Same race on `isLoading`, and clearing the box does not cancel in-flight requests. | `search_deals_controller.dart:16-35`, latency in `fake_api_service.dart:95-99` |
| RES-102 | `Timer.periodic` is started in `initState`, never stored, never cancelled. No `dispose()`. After the screen is popped the timer still ticks and calls `setState` on a disposed `State`. | `pickup_countdown.dart:19-24` |
| RES-103 | `ever(cartService.itemCount, ...)` subscribes to a PERMANENT service. The returned `Worker` is never disposed (confirmed in GetX 4.7.3 source: `ever` only returns the worker, it does not attach it to the controller). So each closed deal controller keeps listening and fires `GET /deals/:id` on every cart change. | `deal_details_controller.dart:36`, `cart_service.dart:13` |
| RES-104 | `refreshDeals` and `loadMore` share `_page` and `deals` with no coordination. Refresh resets `_page = 1` while a page-2 request is in flight. If page 1 lands first, page 2 is appended but `_page` still says 1, so the next `loadMore` fetches page 2 again → duplicates. If page 2 lands first, `assignAll` hides it → explains "intermittent". | `home_controller.dart:58-84` |
| RES-105 | (1) One `Obx` wraps the whole `Scaffold` and reads `scrollOffset`, which changes on every scroll tick → whole screen rebuilds per frame. (2) Feed is `ListView(children: [...map])`: a new list of every loaded card is allocated on each of those rebuilds, and `visibleDeals` re-filters each time. (3) Images are 1600x1200 and decoded at full size (no `memCacheWidth/Height`) for a 160px-tall card. | `home_screen.dart:17-18, 76-98`, `home_controller.dart:29-31, 41`, `the_network_image.dart:26-30`, URLs in `fake_api_service.dart:278` |
| RES-106 | API sends UTC instants. `DateTime.parse` keeps them UTC and `label` formats them without converting to local time → 06:00 Bangkok shows as 23:00. `isToday` compares only day-of-month, and compares a UTC day with a local day → wrong for early-morning stores (and across months). | `pickup_window_model.dart:12-13, 18-22` |
| RES-107 | Controller does `Get.arguments as DealModel`. A deep link carries only `?id=42&source=push`, so arguments is null → cast throws. `deal` is `late final` and the screen reads it synchronously, so there is no loading state to fetch into. | `deal_details_controller.dart:20, 28`, `deal_details_screen.dart:13` |

Things to remember when fixing:
- RES-106: the existing test asserts `pickupWindow.start.isUtc` is true (`test/model_test.dart:33`). So keep the stored
  value in UTC and convert only where it is displayed/compared. Do not change that test.
- RES-105: memory growth was NOT reproduced on the emulator (see row above). Cause (3) is from code reading only.
- The old Phase 1 table (wrong folder) is not available in this repo, so it could not be compared line by line.

## Phase 2 baseline (2026-10-10, commands actually run)
| Command | Result |
|---|---|
| `fvm flutter --version` | Flutter 3.27.0, Dart 3.6.0, DevTools 2.40.2 |
| `java -version` | OpenJDK 17.0.20.1 (Temurin) |
| `fvm flutter pub get` | OK. "51 packages have newer versions" — expected, not upgraded. `pubspec.lock` unchanged |
| `fvm flutter analyze` | No issues found |
| `fvm flutter test` | 1 passed, 0 failed (`test/model_test.dart`) |

No pre-existing failures. Not run: the app itself, any device/emulator build.

## RES-106 notes (2026-10-10)
- Fix: `label` and `isToday` in `lib/model/pickup_window_model.dart` now convert to local time (`toLocal()`)
  at the point of display/comparison. Stored `start`/`end` stay UTC. `isToday` compares year + month + day.
- Test seam: `isTodayAt(DateTime now)` so tests can pass a fixed "now". The app still calls `isToday`.
- Tests: `test/model/pickup_window_model_test.dart` (4 tests). On the old logic all 4 FAILED on this machine
  (UTC+8), e.g. label expected `06:00 – 09:30`, actual `22:00 – 01:30`. After the fix: 4/4 pass.
  Full suite 5/5 pass, analyze no issues.
- Deliberately NOT handled — overnight windows: "Pickup today" means "pickup STARTS today". At 00:30 a store
  open 22:00–01:00 has a window that started yesterday, so the filter hides it even though it is open right now.
  Kept on purpose: it matches the documented meaning of `isToday`; `isOpenNow` already covers "open right now".
- Consequence of the phone-time-zone decision: a phone outside Bangkok shows shifted times
  (this dev machine is UTC+8, so the 06:00 bakery shows 07:00). To see 06:00–09:30, set the emulator to Asia/Bangkok.
- For solutions.md Q3: the label test only catches the bug on a NON-UTC machine (on UTC, local time == UTC, so
  the old code passes too). CI should therefore run tests with `TZ=Asia/Bangkok` (Linux/macOS).
  The "same day number, different month" test fails on the old code in every time zone.
- Emulator check done for the card times (see status row). The "Pickup today" filter was checked by tests only,
  not separately confirmed on the emulator.

## RES-101 notes (2026-10-10)
- Fix: latest-request-wins guard in `lib/feature/search/search_deals_controller.dart`. Each search takes a number
  (`_latestRequestId`); after the `await`, only the newest number may change `results`, `isLoading`, `hasError`.
  The number also goes up when the box is cleared, so in-flight requests become stale.
- New `hasError` flag + "Search failed. Please try again." branch in `search_screen.dart`. When the NEWEST request
  fails, results are cleared so old results never sit under a different query. Stale failures are logged but ignored.
- Tests: `test/feature/search/search_deals_controller_test.dart` (5 tests, Completer-based, no real delays).
  Tests 1-3 FAILED on the old code (e.g. expected `[1]`, actual `[2, 3]`). After the fix: 5/5 pass.
  Full suite 10/10 pass, analyze no issues.
- Test fake: `FakeDealRepo extends DealRepo` with `super(api: FakeApiService())`. The API object is never used and
  `init()` is never called, so no assets are loaded. No production seam was needed.
- Rejected as the correctness fix: debounce only (requests can still overlap), cancelling (Dart futures cannot be
  cancelled), comparing the response's query with the text box (counter is simpler).
- Decided: debounce comes LATER as a separate commit, cancelled in `onClose`, with its own test.
- Not handled on purpose: every keystroke still sends a request (until debounce); a response that arrives after
  the screen is closed still writes to the old controller's state, which nothing shows any more.
- Emulator check done (see status row). The "Search failed" message was checked by tests only: the fake API's
  search never fails, so it cannot be triggered in the running app.

## RES-101 debounce notes (2026-10-10, separate commit from the guard)
- `onQueryChanged` now waits 300 ms (`debounceDelay`) after the last keystroke before sending. The timer lives in
  the controller (`_debounce`) and is cancelled in `onClose`, and on every new keystroke.
- The request number is now taken AT THE KEYSTROKE, not when the request is sent. So an older response that
  arrives during the 300 ms wait is already stale. The spinner shows during the wait.
- Clearing the box is not debounced: it cancels the timer and resets the screen at once.
- `onClose` also increments `_latestRequestId`, so a response that arrives after the screen is closed is ignored.
  (This removes the "not handled" edge case listed in the RES-101 notes above.)
- 300 ms is a convention / judgement call, not a measured value.
- Tests: `fakeAsync` is NOT exported by `flutter_test`; using it needs `fake_async` in pubspec.yaml (forbidden).
  Used `testWidgets` + `tester.pump(duration)` instead — same idea, fake clock, no pubspec change.
- 5 new tests. On the old code 4 FAILED (e.g. expected no requests, actual `['s', 'su', 'sus', 'sush', 'sushi']`).
  The 5th ("response arrives while newer text is waiting") PASSED on the old code — the plan wrongly said it would
  fail. It guards the new keystroke numbering: checked by temporarily taking the number at send time → it failed
  (expected loading true, actual false) → code restored.
- The 5 RES-101 tests gained `tester.pump` calls so the request is actually sent; their assertions are unchanged.
- After: search tests 10/10, full suite 15/15, analyze no issues.
- Emulator check done: one `GET /deals/search?q=sushi` for a quickly typed word. Committed as 64b794c.

## RES-102 notes (2026-10-10)
- Cause: `Timer.periodic` started in `initState` of `_PickupCountdownState`, never stored, never cancelled, and
  the class had no `dispose()`. The timer outlived the widget and called `setState` on a disposed State.
- Fix (`lib/feature/order/widget/pickup_countdown.dart`): keep the timer in `late final Timer _timer` and cancel
  it in `dispose()`. No `if (mounted)` check — after `cancel()` the callback never runs, so there is nothing to hide.
- Owner decision: the widget State owns the timer (it only repaints this widget; start in `initState`, stop in
  `dispose`). Not moved to `OrdersController`: bigger rewrite, and a per-second repaint is display state.
- In release builds the old code did not crash (the check is a debug assertion) but leaked one timer + State per
  active order per visit.
- Tests: `test/feature/order/widget/pickup_countdown_test.dart` (2 widget tests, fake clock).
  On the old code BOTH failed: test 1 with "setState() called after dispose(): _PickupCountdownState" at
  pickup_countdown.dart:22:7 (same as the emulator repro); test 2 with "A Timer is still pending even after the
  widget tree was disposed". The plan wrongly said test 2 would pass on the old code — `testWidgets` tears the
  tree down at the end of every test, so any test that builds the old widget hits the leaked timer.
- Not handled on purpose: the timer keeps ticking after the window opens (text is fixed by then); when more than
  an hour is left the text changes once a minute but the widget repaints every second.
- Not tested: the exact countdown text (e.g. "04:59"). The widget reads `DateTime.now()`, which the fake clock
  does not control; that needs an injected clock (relevant again for F-1).
- Still to do: check on the emulator that opening My orders and pressing back no longer throws.

## RES-103 notes (2026-10-10)
- Cause: `ever(cartService.itemCount, ...)` in `DealDetailsController.onInit`. The returned `Worker` was thrown away
  and the class had no `onClose`. The subscription is held by `cartService.itemCount`, and `CartService` is
  permanent, so every closed deal controller kept listening and re-fetching its deal on each cart change.
- Why GetX did not clean up: in GetX 4.7.3 `ever` only does `listener.listen(...)` and returns the worker; it is
  not registered with the controller. GetX did delete the controller and call `onClose` — there was just nothing in it.
- Fix (`lib/feature/deal/deal_details_controller.dart`): keep the worker in `late final Worker _cartWorker`, dispose
  it in `onClose`. Plus `if (isClosed) return;` after the `await` in `_recheckAvailability`, for a request already
  in flight when the page closes (a Future cannot be cancelled).
- The open page still re-checks its own deal on cart changes — intended, unchanged.
- Rejected: global request dedup. Each dead controller asks for a DIFFERENT deal id, so dedup would not even reduce
  the burst, and the dead controllers would still be listening and held in memory.
- Tests: `test/feature/deal/deal_details_controller_test.dart` (3 tests, real GetX lifecycle via `Get.put` /
  `Get.delete`, Completer-based fake repo). On the old code: test 1 FAILED (expected `[3]`, actual `[1, 2, 3]`),
  test 3 FAILED (expected 5, actual 0), test 2 passed (regression guard) — all as predicted.
- Test setup note: the deal is passed with `Get.routing.args = deal` because `onInit` reads `Get.arguments`.
  This will change with RES-107.
- Not handled on purpose: if `fetchById` throws, the error is unhandled (the worker does not await the future);
  the API only throws for an unknown id. Two quick cart changes send two re-checks with no ordering guard; both
  return the same server value.
- Emulator check done (see status row). Verification gotcha: the FIRST check, after a hot reload, still showed the
  old leaked listeners. Hot reload swaps the code but keeps app state, so the permanent `CartService` still held
  the subscriptions that the old controllers had created before the fix. A full restart was needed to start
  with a clean cart service. Lesson: verify lifecycle/leak fixes after a full restart, not a hot reload.

## RES-107 notes (2026-10-10)
- Cause: `DealDetailsController.onInit` did `deal = Get.arguments as DealModel`. `Get.arguments` is the in-memory
  object passed in `Get.toNamed(..., arguments: deal)` (deal cards do this). A deep link is only text
  (`/deal?id=42&source=push`), so arguments is null and the cast throws. The id was in `Get.parameters` all along.
  `deal` was `late final` and the screen read it synchronously, so there was no way to show "loading".
- Fix (`deal_details_controller.dart`, `deal_details_screen.dart`): the id from `Get.parameters` is the source of
  truth. `deal` is now `Rxn<DealModel>`. A passed-in deal is used only as a preload when its id matches the route
  (or the route has no id) → zero requests from the feed. Otherwise `loadDeal()` fetches via
  `DealRepo.fetchById` with `isLoading` / `errorMessage`. Missing or malformed id → "This link is not valid.",
  no request. 404 → "This deal is no longer available." Other `ApiException` → "Could not load this deal."
  + "Try again". Only `ApiException` is caught, so programming errors still surface.
- No duplicates: `loadDeal` returns early while loading; the RES-103 cart re-check is skipped until a deal is loaded.
  `_cartWorker` is still disposed in `onClose`; `isClosed` guard after the load `await` too.
- Screen: one `Obx` picks spinner / message / the existing page (moved unchanged into `_buildDeal`).
- Rejected: catch the cast and show an error page (ticket forbids it); look the deal up in the home feed list
  (paginated, and missing on a cold start); fetch in middleware/binding (no feedback, not built for async).
- Tests (`test/feature/deal/deal_details_controller_test.dart`): test 1 FAILED on the old code with
  "type 'Null' is not a subtype of type 'DealModel' in type cast" at deal_details_controller.dart:32 (same as the
  emulator). After the fix: 10 RES-107 tests + the 3 RES-103 tests = 13/13 pass.
- Not tested by automated tests: the loaded page itself and "Add to bag" after a deep link (the page builds
  `CachedNetworkImage`, which needs platform plugins) → check on the emulator.
- Known small thing: "Try again" also shows for a 404, where retrying will not help.
- Cold start (link via adb) — CLOSED, AI prediction was WRONG: from reading GetX's `initialRoutesGenerate`, Claude
  predicted the stack would hold ONLY the deal page (no Home underneath, back would exit the app). The adb test
  showed deal 42 opens and back returns to Home. So no Home-button commit is needed. Why the prediction was wrong
  has not been investigated. Caught by testing on the emulator instead of trusting the code reading.
  (Candidate for AI_LOG.md.)
- Emulator checks all done (see status row).

## RES-104 notes (2026-10-10) — split into two commits
- Cause: `refreshDeals` and `loadMore` in `home_controller.dart` shared `_page` and `deals` with no coordination.
  Refresh set `_page = 1` BEFORE its response; `loadMore` did `_page++` before its response; a `loadMore` response
  was appended without checking the list was still the one it was requested for. Ticket timeline: loadMore
  (page 2 in flight) → refresh (page 1 in flight) → page 1 lands (`_page` 1, list = page 1) → page 2 lands and is
  appended (`_page` still 1, list = pages 1+2) → next loadMore fetches page 2 AGAIN → duplicates. If page 2 lands
  first it is wiped by the refresh → intermittent.
- Related faults in the same code: `_page--` on failure goes to 0 if a refresh reset `_page` meanwhile (next
  loadMore re-fetches page 1); a loadMore started DURING a refresh could make a page be skipped.
- COMMIT A (race fix): `_generation` goes up when a refresh REPLACES the list (on success, not at start).
  `loadMore` remembers the generation and the next page number before the `await`, and only applies the response
  (`_page`, `_totalPages`, `deals` together) if the generation is unchanged. `_page--` removed — `_page` is only
  assigned after an accepted response. `_isFetchingMore` reset in `finally`. Failure calls `loadFailed()`.
  No dedup by id.
- Behaviour change to know: `loadMore` used to `catch (e)` everything; it now catches `ApiException` only, so a
  programming error is no longer silently logged.
- Tests A: `test/feature/home/home_controller_test.dart`, tests 1, 2, 3, 4, 6, 8 (Completer-based, one request
  answered at a time). On the old code: 1, 3, 4, 6 FAILED; 2 and 8 passed — matches the predictions.
  E.g. test 1 expected `[1, 2]`, actual `[1, 2, 3, 4]`; test 4 expected pages `[1, 2, 1, 2]`, actual `[1, 2, 1, 1]`.
- Test bug caught on the first run: test 8 failed on the old code with footer "idle" instead of "noMore". The old
  code was right; the TEST was wrong — pull_to_refresh changes the footer status in an after-frame callback and
  `tester.pump()` alone draws no frame when none is scheduled. Fixed with a `settle()` helper that schedules a
  frame. (Candidate for AI_LOG.md: first test draft produced a false failure.)
- After commit A's fix: home tests 6/6, full suite 36/36, analyze no issues.
- Race NOT reproduced by hand (window under 1 s); proven by the Completer tests only.
- COMMIT B (to do): refresh failure path (`refreshFailed()`, no uncaught error, list/page untouched) and
  `refreshCompleted(resetFooterState: true)`, with tests 5 and 7. Footer bug CONFIRMED on the emulator 2026-10-10
  (before the fix): loaded pages 1–7, pulled to refresh, then scrolling never loaded page 2 again.
  Screenshot: docs/before/12_res104_footer_stuck.png (console: pages 1–7, then page 1, then nothing).
- COMMIT B done (not committed yet): `refreshDeals` wraps its work in `try` / `on ApiException`. On failure it logs
  and calls `refreshFailed()`; `_page`, `_totalPages`, `deals` and `_generation` are untouched because they are only
  changed after a response arrives. On success it calls `refreshCompleted(resetFooterState: true)`, which clears
  a footer stuck on "no more data" (pull_to_refresh 2.0.0 does not reset it by default and blocks loading in that
  state).
- Tests B (5 and 7) on the code after commit A: both FAILED as predicted — test 5 `Expected: null`, `Actual:
  ApiException(500)` (the error escaped `refreshDeals`); test 7 footer `Expected: idle`, `Actual: noMore`.
  After the fix: home tests 8/8, full suite 38/38, analyze no issues.
- Side effect to know: a failed FIRST load is now logged inside `refreshDeals` ("refresh failed") instead of by
  `_initialLoad` ("initial load failed"). Visible result unchanged (empty feed).
- Cannot be checked in the running app: the refresh FAILURE path (the fake API's `getDeals` never throws) —
  covered by test 5 only.
- Emulator check done 2026-10-10: after commit B, page 2 loads again after a refresh. Committed as 64c64b7.
- Not handled on purpose: two overlapping refreshes (the widget does not start a second one); an error screen
  when the very first load fails.

## RES-105 notes (2026-10-10) — three commits: 1 scope the Obx, 2 lazy list + keys, 3 image decode size
- All measurements: Android emulator, DEBUG mode. Rebuild counts and oversized-image flags are valid in debug;
  frame times are NOT representative and are not used as evidence.
- FRESH BASELINE on today's code (after RES-101…107 fixes, before any RES-105 change), ~30 s scroll,
  measured by me:
  - Rebuild Stats: Obx / Scaffold / AppBar / IconButtons 154 builds each; DealCard 855; CachedNetworkImage 927;
    FlashDealsSection 18. (docs/before/13_res105_rebuilds_top.png, 13_res105_rebuilds_cards.png)
  - Inspector "Highlight oversized images": every feed image and every flash-rail image is flipped/inverted,
    i.e. decoded larger than it is shown. (docs/before/13_res105_oversized.png)
  - `adb shell dumpsys meminfo dev.rescu.rescu` after scrolling pages 1–6 (docs/before/13_res105_meminfo.txt, KB):
    TOTAL PSS 303,779 · TOTAL RSS 393,304 · Native Heap PSS 83,391 · Private Other 179,224 · Unknown PSS 127,453 ·
    Graphics 0. Note: Graphics is 0 on this emulator, so image memory is not reported on that line here.
- Earlier baseline (first row of the status table, morning of 2026-10-10): Scaffold/AppBar ~106, DealCard 501,
  CachedNetworkImage 709; memory chart flat over pages 1–6.
- Causes (file refs in the Phase 1 table):
  1. One `Obx` wraps the whole `Scaffold` and reads `scrollOffset`, written on every scroll tick → app bar, list and
     button rebuild per tick. Evidence: SUPPORTS (Scaffold/AppBar/IconButtons rebuilt 154x though nothing in them changes).
  2. Feed is `ListView(children: [...map])` with no keys; `visibleDeals` builds a new list per read. Evidence:
     PARTLY — DealCard 855 / 154 passes ≈ 5–6 per pass, so only cards near the screen were rebuilt (not all loaded
     ones), but each of them on every pass. The cost of allocating every card object per pass is not visible in
     DevTools. Phase 1 wording ("every loaded card") was too strong.
  3. 1600x1200 images decoded at full size for a 160-pt-tall card. Evidence: the oversized-image highlight SUPPORTS it.
     Memory growth "until the OS kills the app" was NOT reproduced (flat chart); Flutter's image cache caps at
     100 MB by default, so a plateau is expected on this emulator.
- Frame chart (docs/before/01_frames.png): slow frames were on the RASTER side, UI-thread bars tiny. So rebuild
  fixes are not claimed to fix frame times; no frame-time claims will be made from the emulator.
- Commit 3 image rule (decided, with a refinement): pass ONE decode dimension so the image keeps its shape —
  width when the box is at least as wide as the image shape (4:3), otherwise height. Usage audit in the chat/
  solutions notes; to be re-checked when commit 3 is done.

- COMMIT 1 done (not committed yet, not yet re-measured): `scrollOffset` (RxDouble, written every scroll tick) is
  replaced by two RxBools in `home_controller.dart`: `isScrolled` (offset > 4) and `showScrollToTop` (offset > 800).
  An RxBool notifies only when it flips. In `home_screen.dart` the one `Obx` around the whole `Scaffold` is replaced
  by three small ones: around the `AppBar` (in a `PreferredSize`), the body, and the scroll-to-top button.
  - Tests: new `test/feature/home/home_screen_test.dart` — scroll from offset 10 to 30 (no threshold crossed) and
    check the `AppBar` and `SmartRefresher` are the SAME objects afterwards (a parent rebuild would create new
    ones). FAILED on the old code ("the app bar was rebuilt by a scroll that changed nothing in it"), passes now.
    Plus a threshold test in `home_controller_test.dart` (flags flip at 4/5 and 800/801).
    Home tests 10/10, full suite 40/40, analyze no issues.
  - Test-writing slip: the first run also showed two layout-overflow errors — my test screen (400 wide) was too
    narrow for the test font. Widened to 800; not an app bug.
  - Diff note: `home_screen.dart` shows ~96 changed lines, but ~17 without whitespace — the rest is re-indentation
    from removing the outer `Obx`. Two existing one-line `if`s got braces because the formatter wrapped them.
  - Visible change: the scroll-to-top button now appears/disappears without the Scaffold's built-in scale
    animation (the Scaffold no longer sees the button being added/removed).
  - RE-MEASURED after commit 1 (emulator, debug, ~30 s scroll after Clear), measured by me:

    | Widget | Before (fresh baseline) | After commit 1 |
    |---|---|---|
    | AppBar / IconButtons | 154 | 2 |
    | DealCard | 855 | 98 |
    | CachedNetworkImage | 927 | 98 |
    | Obx / SmartRefresher (body, home_screen.dart:70/78) | 154 (old outer Obx) | 4–5 |

    Screenshots: docs/after/13_res105_c1_rebuilds_cards.png, docs/after/13_res105_c1_rebuilds_top.png.
    The AppBar screenshot was taken a bit later in the same run, so the card counts visible IN THAT screenshot are
    higher than 98; the 98 comes from the cards screenshot.
  - Frames are STILL janky on the raster side after commit 1 (as expected from the baseline frame chart). So commit 1
    is evidence of removed rebuilds only — no frame-time improvement is claimed.

## Next step
- Commit RES-105 commit 1. Then commit 2 (lazy list + keys), then capture nothing new before commit 3
  (image "before" evidence is already in docs/before/13_*).
- Then the next ticket (suggested order: RES-106, 101, 102, 103, 104, 107, then RES-105 and F-1).
- For each: reproduce in the app first, then failing test → fix → passing test.
