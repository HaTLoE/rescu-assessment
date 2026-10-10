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
| RES-101 Search stale results | fixed + tested + confirmed on emulator; not committed yet | | Emulator confirmed 2026-10-10: typing "sushi" quickly ends on sushi results and they stay; clearing the box shows the hint. See "RES-101 notes" below. Debounce: later, separate commit |
| RES-102 My Orders crash | todo — cause found by reading code | | See Phase 1 table |
| RES-103 Request pile-up | todo — cause found by reading code | | See Phase 1 table |
| RES-104 Duplicate deals | todo — cause found by reading code | | See Phase 1 table |
| RES-105 Feed jank / memory | before-evidence captured | | Emulator Pixel API 37, debug mode, Flutter 3.27.0. ~30s scroll: Scaffold/AppBar rebuilt ~106x, DealCard 501x, CachedNetworkImage 709x; ~45-53 FPS with jank frames. ~3 min scroll pages 1-6: memory flat (~90MB Dart heap, ~400MB RSS) — growth NOT reproduced on emulator. Screenshots in docs/before/ |
| RES-106 Pickup times / filter | done — fixed + tested + confirmed on emulator | 78cea08 | Decided 2026-10-10: show times in the phone's time zone (not a fixed market time zone). Emulator (time zone Asia/Bangkok) confirmed 2026-10-10: Baan Somtam Kitchen shows 05:30 – 08:00, Sunrise Bakehouse 06:00 – 09:30 (before the fix Baan Somtam showed 22:30 – 01:00). Screenshots: docs/before/06_res106_times.png, docs/after/06_res106_times.png. See "RES-106 notes" below |
| RES-107 Deep link crash | todo — cause found by reading code | | See Phase 1 table |
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

## Next step
- Commit RES-101 (emulator check passed).
- Then RES-101 debounce as a separate commit, then the next ticket (suggested order: RES-106, 101, 102, 103, 104, 107, then RES-105 and F-1).
- For each: reproduce in the app first, then failing test → fix → passing test.
