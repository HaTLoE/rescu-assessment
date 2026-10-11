# Rescu assessment — solutions

All seven bug tickets and F-1 are done. F-2 and F-3 were not attempted.

Everything was run on Flutter 3.27.0 with an Android emulator in debug mode; I have no physical device. The final
state is 102 passing tests (1 existed at the start), `flutter analyze` with no issues, and no change to
`lib/service/fake_api_service.dart`, `assets/data/`, `pubspec.yaml` or `pubspec.lock`.

Screenshots and captures are in [docs/before](docs/before) and [docs/after](docs/after).

## 1. Summary

| Item | Status | Commits |
|---|---|---|
| RES-101 Search shows results for the wrong query | Fixed, tested, checked on the emulator | `a2c248e` (fix), `64b794c` (debounce, extra) |
| RES-102 Crash after leaving My orders | Fixed, tested, checked on the emulator | `2b0dde3` |
| RES-103 Requests pile up | Fixed, tested, checked on the emulator | `98a1539` |
| RES-104 Duplicate deals in the home feed | Fixed and tested. The race was never reproduced by hand; tests prove it | `ee103c7` (race), `64c64b7` (refresh failure + footer) |
| RES-105 Feed jank and memory | Three causes fixed, each measured. Memory growth was not reproduced | `e165484`, `3c409f8`, `5df71e4` |
| RES-106 Wrong pickup times / "Pickup today" | Fixed, tested, checked on the emulator | `78cea08` |
| RES-107 Deep link opens to a crash | Fixed, tested, checked on the emulator, including a cold start | `059be5c` |
| F-1 Live flash-sale countdowns | Complete and profiled | `002d49b`, `851d7c0`, `6557fa9`, `7c5d4c5` |
| F-2 Impression tracking | **Not attempted** | — |
| F-3 Stock reservations | **Not attempted** | — |

Why F-2 and F-3 are missing: the brief says diagnosis quality beats volume, and that a complete, profiled F-1 beats
three half-done features. I spent the time on root causes, tests that fail before each fix, and measurements, and
did not start a feature I could not finish properly. My plan for both is in section 6.

How I worked on every item: read the code and explain the root cause first, write a test that fails on the old
code, fix, then check on the emulator where the behaviour could be reproduced there.

## 2. Tickets and features

### RES-101 — Search shows results for the wrong query

**Symptom.** Typing "sushi" quickly ends with results for a shorter query such as "s".

**Root cause.** In [search_deals_controller.dart](lib/feature/search/search_deals_controller.dart), every keystroke
started its own request, and each response was written to `results` when it arrived. Nothing checked that a
response belonged to the newest query. The API is slower for short queries (about 1.1–1.4 s for one letter, about
0.2–0.5 s for five), so "s" lands after "sushi" and overwrites it. The same missing check stopped the spinner on
the first response, and clearing the box did not stop a request already in flight.

**Fix and why.** Each search takes a number (`_latestRequestId`). After the `await`, only the request holding the
newest number may change the results, the spinner or the error flag. Clearing the box also takes a number, so
in-flight requests become stale. This is what makes the result correct: a late answer can never be shown.
When the newest request fails, the results are cleared and "Search failed. Please try again." is shown, so old
results never sit under a different query.

A 300 ms debounce was added afterwards as a separate commit. It reduces requests (one per typed word instead of
one per letter) but is not the correctness fix. The timer lives in the controller and is cancelled in `onClose`.

**Rejected alternatives.**
- Debounce only: two requests can still overlap and cross (type "su", pause, type "shi").
- Cancelling the old request: a Dart `Future` cannot be cancelled and the API has no cancel option.

**Edge cases handled.** Empty query; stale success; stale failure (logged, ignored); a response arriving after the
screen is closed; an older response arriving during the debounce wait (the number is taken at the keystroke, not
when the request is sent).

**Not handled, on purpose.** A slow typist who pauses more than 300 ms per letter still sends one request per
letter; the guard keeps the result correct. There is no "search now" on the keyboard's Enter key.

**Tests.** [search_deals_controller_test.dart](test/feature/search/search_deals_controller_test.dart), 10 tests.
A fake repository hands out a `Completer` per query, so a test makes "s" finish after "sushi". On the old code the
first test failed with expected `[1]`, actual `[2, 3]`.

**Evidence.** [results stay on sushi](docs/after/07_res101_search.png),
[cleared box](docs/after/07_res101_cleared.png),
[one request for a typed word](docs/after/08_res101_debounce_console.png).

### RES-102 — Crash after leaving My orders

**Symptom.** Open My orders, go back, and within seconds: `setState() called after dispose()`.

**Root cause.** In [pickup_countdown.dart](lib/feature/order/widget/pickup_countdown.dart), `initState` started a
`Timer.periodic` and threw the timer away. The class had no `dispose()`. A Dart timer runs until it is cancelled;
it knows nothing about widgets. After the screen closed, the timer kept calling `setState` on a disposed `State`.
In release builds this does not crash (the check is a debug assertion) but it leaks one timer and one `State` per
active order per visit.

**Fix and why.** The timer is kept in a field and cancelled in `dispose()`. The `State` that started the timer is
the one that stops it, so its life matches the widget's exactly.

**Rejected alternatives.**
- `if (mounted) setState(...)`: hides the error while the timer and the dead `State` stay alive forever.
- Moving the timer into `OrdersController`: a bigger rewrite, and a once-a-second repaint is display state.

**Not handled, on purpose.** The timer keeps ticking after the pickup window opens, when the text no longer
changes. With more than an hour left the text changes once a minute but the widget repaints every second.
The exact countdown text is not tested, because the widget reads the real clock.

**Tests.** [pickup_countdown_test.dart](test/feature/order/widget/pickup_countdown_test.dart), 2 widget tests.
On the old code the first failed with the same error as the emulator, at `pickup_countdown.dart:22:7`.

**Evidence.** [before](docs/before/09_res102_error.png), [after](docs/after/09_res102_no_error.png).

### RES-103 — Requests pile up the longer you browse

**Symptom.** After opening several deal pages, one "Add to bag" fires a `GET /deals/:id` for every deal viewed
earlier. I reproduced it: after viewing deals 1, 4, 6 and 7, one tap sent four requests (deals 6, 4, 7, 1).

**Root cause.** In [deal_details_controller.dart](lib/feature/deal/deal_details_controller.dart), `onInit` called
`ever(cartService.itemCount, ...)` and threw the returned `Worker` away. The class had no `onClose`. The
subscription is stored in the cart's `itemCount`, and `CartService` is a permanent service, so it never ends.
GetX did delete each controller when its page closed, but `ever` does not register the worker with the controller,
so GetX had nothing to cancel. Every closed page kept listening and re-fetching.

**Fix and why.** The worker is kept in a field and disposed in `onClose`. An `isClosed` check after the `await`
ignores the answer to a request that was already in flight when the page closed. The open page still re-checks its
own deal, as designed.

**Rejected alternative.** Global request de-duplication. Each dead controller asks for a different deal id, so
nothing would merge, and the dead controllers would still be listening and held in memory.

**Not handled, on purpose.** If the re-check request throws, nothing catches it (the API only throws for an
unknown deal). Two quick cart changes send two re-checks with no ordering guard; both return the same value.

**Tests.** [deal_details_controller_test.dart](test/feature/deal/deal_details_controller_test.dart). The tests
open and close the controller with `Get.put` and `Get.delete`, so GetX really runs `onInit` and `onClose`.
On the old code: expected one request for deal `[3]`, actual `[1, 2, 3]`.

**Evidence.** [before](docs/before/10_res103_requests.png), [after](docs/after/10_res103_one_request.png).
One thing I learned while checking: a hot reload still showed the old leaked listeners, because hot reload keeps
app state and the permanent cart service still held the old subscriptions. A full restart was needed.

### RES-104 — Duplicate deals in the home feed

**Symptom.** Refreshing while the next page is loading sometimes leaves duplicated cards, or more items than the
catalog has.

**Root cause.** In [home_controller.dart](lib/feature/home/home_controller.dart), `refreshDeals` and `loadMore`
shared `_page` and `deals` with no coordination. Refresh set `_page = 1` before its response arrived; `loadMore`
did `_page++` before its response arrived and appended the result without checking the list was still the one it
was requested for.

The ticket's timeline: `loadMore` requests page 2, then refresh requests page 1. If page 1 lands first, the list
becomes page 1 and `_page` is 1. Then page 2 lands and is appended, so the list holds pages 1 and 2 while `_page`
still says 1. The next `loadMore` fetches page 2 again. If page 2 lands first, the refresh wipes it and nothing
goes wrong, which is why the bug is intermittent.

Two related faults were in the same code: `_page--` on failure could reach 0 if a refresh had reset `_page`
meanwhile, and a `loadMore` started during a refresh could make a page be skipped.

**Fix and why (commit `ee103c7`).** `_page`, `_totalPages` and `deals` now change together, and only after a
response arrives. A `_generation` counter goes up each time a refresh replaces the list. `loadMore` remembers the
generation before waiting and only applies its page if the generation is unchanged. `loadMore` computes the next
page in a local variable, so a failure leaves `_page` untouched and `_page--` is gone. The "loading more" flag is
reset in `finally`.

**Second commit (`64c64b7`).** Two more faults found in the same function. A failed refresh was unhandled; it is
now logged and reported with `refreshFailed()`, and changes no data. And once the footer said "no more data" it
never recovered, so after scrolling to the end and refreshing, page 2 could never load again; the refresh now
resets the footer.

**Rejected alternative.** Removing duplicates by id. It hides the duplicates but leaves `_page` wrong, so a page
can still be skipped or fetched twice.

**Not handled, on purpose.** Two overlapping refreshes (the pull-to-refresh widget does not start a second one).
An error screen when the very first load fails.

**Tests.** [home_controller_test.dart](test/feature/home/home_controller_test.dart). A fake repository answers
each page request only when the test says so, so the test picks which response lands first. On the old code the
ticket's scenario failed with expected `[1, 2]`, actual `[1, 2, 3, 4]`.

**Evidence and an honest limit.** I could not reproduce the race by hand: the requests take 250–950 ms, so the
window is under a second. The tests are the proof. The footer fault I did reproduce:
[before](docs/before/12_res104_footer_stuck.png), [after](docs/after/12_res104_footer_reset.png).

### RES-105 — Home feed is janky and memory keeps climbing

Three causes, fixed in three commits. Numbers and method are in section 3.

**Cause 1: one `Obx` rebuilt the whole screen on every scroll tick (`e165484`).**
In [home_screen.dart](lib/feature/home/home_screen.dart) a single `Obx` wrapped the whole `Scaffold` and read the
scroll offset, which changes on every scroll tick. The screen only needed two yes/no answers: is the offset past
4 (app bar shadow) and past 800 (scroll-to-top button). The offset is replaced by two `RxBool`s, which notify only
when they flip, and the one `Obx` is replaced by three small ones around the app bar, the body and the button.
Rejected: three `Obx`s still reading the offset, which would still rebuild every tick.

**Cause 2: the feed list was built eagerly, with no keys (`3c409f8`).**
The feed was `ListView(children: [...])` with a card object created for every loaded deal on each rebuild. It is
now a `CustomScrollView` with `SliverList.builder`, and each card has `ValueKey(deal.id)`.
Not handled, on purpose: `findChildIndexCallback`, and duplicate ids from a backend that paginates by offset.

**Cause 3: images were decoded at full size (`5df71e4`).**
Every image URL asks for 1600×1200, and [the_network_image.dart](lib/feature/shared_widget/the_network_image.dart)
gave no decode size, even for a 64×64 thumbnail. A `LayoutBuilder` now reads the real box size, multiplies by the
device pixel ratio, and passes one of `memCacheWidth` or `memCacheHeight`: the width when the box is at least as
wide as the image shape (4:3), otherwise the height. One dimension keeps the shape; the 4:3 comparison guarantees
the decoded image covers the box, so nothing is upscaled.
Rejected: lowering the global image cache limit, which only evicts sooner and decodes more often.
Not handled, on purpose: the cropped-away part of a `BoxFit.cover` image is still decoded. An API image that is
not 4:3 could look slightly soft.

**Tests.** [home_screen_test.dart](test/feature/home/home_screen_test.dart) (scrolling without crossing a
threshold rebuilds neither the app bar nor the list; each card carries its deal id as its key),
[the_network_image_test.dart](test/feature/shared_widget/the_network_image_test.dart) (the size rule, including a
check that every usage in the app is covered).

**What I am not claiming.** Memory growing "until the OS kills the app" was never reproduced. I make no frame-time
claim. See section 3.

### RES-106 — Wrong pickup times; "Pickup today" filter misses deals

**Symptom.** A bakery open 06:00–09:30 shows 23:00–02:30, and some stores with pickup today are missing from the
filter.

**Root cause.** The backend is right: it sends UTC. In
[pickup_window_model.dart](lib/model/pickup_window_model.dart), `DateTime.parse` on a string ending in `Z` gives a
UTC `DateTime`, and `label` formatted it without converting, so it printed the UTC hour. 06:00 in Bangkok is
23:00 UTC the day before. `isToday` was `start.day == DateTime.now().day`: it compared a UTC day with a local day,
and compared only the day number. Stores that open before 07:00 Bangkok time have a UTC start on the previous
day, so they were hidden when they should show and shown when they should not.

**Fix and why.** `label` and `isToday` convert to local time at the point of display and comparison. The stored
values stay UTC. `isToday` compares year, month and day. A small seam, `isTodayAt(DateTime now)`, lets a test pass
a fixed "now".

**Decision.** Times are shown in the phone's time zone, not a fixed market time zone. A phone outside Bangkok
therefore shows shifted times.

**Rejected alternative.** Calling `toLocal()` inside `fromJson`. The model would hold local times, the existing
test that expects UTC would break, and every reader would have to guess which zone a field is in.

**Not handled, on purpose.** "Pickup today" means "pickup starts today". At 00:30 a store open 22:00–01:00 has a
window that started yesterday, so the filter hides it although it is open. `isOpenNow` covers "open right now".

**Tests.** [pickup_window_model_test.dart](test/model/pickup_window_model_test.dart), 4 tests. On the old code,
on my UTC+8 machine: expected `06:00 – 09:30`, actual `22:00 – 01:30`. See Q3 for the time-zone limit.

**Evidence.** [before](docs/before/06_res106_times.png), [after](docs/after/06_res106_times.png), with the
emulator set to Asia/Bangkok.

### RES-107 — Deep link opens to a crash

**Symptom.** `rescu://open/deal?id=42&source=push` crashes with
`type 'Null' is not a subtype of type 'DealModel'`. The same deal opens fine from the feed.

**Root cause.** In [deal_details_controller.dart](lib/feature/deal/deal_details_controller.dart), `onInit` did
`deal = Get.arguments as DealModel`. `Get.arguments` is the in-memory object passed in the navigation call; deal
cards pass it. A deep link is only text, so it can carry `id=42` but never a `DealModel`, and arguments is null.
The id was in `Get.parameters` all along. `deal` was `late final` and the screen read it immediately, so there was
no way to show "loading".

**Fix and why.** The id from the route is the source of truth. `deal` is now an observable that can be empty.
A deal passed from a card is used only as a shortcut when its id matches the route, so the feed still opens
instantly with no request. Otherwise the controller fetches the deal by id and the screen shows a spinner, then
the same page as from the feed. A missing or malformed id shows "This link is not valid." and sends nothing.
The link format is unchanged.

**Rejected alternatives.**
- Catch the cast and show an error page: the ticket forbids it, and deal 42 exists.
- Look the deal up in the home feed's list: the feed is paginated, and on a cold start there is no feed.

**Not handled, on purpose.** "Try again" also shows for a deal that does not exist, where retrying will not help.
Only `ApiException` is caught, so a programming error stays visible.

**Tests.** [deal_details_controller_test.dart](test/feature/deal/deal_details_controller_test.dart), 10 tests for
this ticket. On the old code the first failed with the same cast error as the emulator.

**Evidence.** [in-app crash before](docs/before/11_res107_screen.png),
[cold start via adb before](docs/before/11_res107_coldstart.png),
[deal 42 after](docs/after/11_res107_deal42.png), [invalid id after](docs/after/11_res107_invalid.png).
After the fix a cold start via adb opens deal 42, and back returns to Home.

### F-1 — Live flash-sale countdowns

**What it does.** The flash rail, the feed and search card, and the details screen show a live countdown
(`mm:ss`, or `hh:mm:ss` from one hour up). At zero the card becomes a disabled "Expired" card, the deal can no
longer be added to the bag, and if it is already in the bag it is removed with a notice.

**Design.**
- **One shared clock.** [clock_service.dart](lib/service/clock_service.dart) is an app-wide service with one
  one-second timer. Every countdown reads its `now`. There is no timer per card.
- **No drift.** Time left is always "end time minus now", never a counter that is decremented.
- **Per-second rebuilds are scoped to the text.**
  [flash_countdown.dart](lib/feature/shared_widget/flash_countdown.dart) is an `Obx` around one `Text`, and it is
  the only thing that reads the clock.
- **The card changes once.**
  [flash_expiry_builder.dart](lib/feature/shared_widget/flash_expiry_builder.dart) listens to the clock and calls
  `setState` only on the tick where "expired" becomes true, then stops listening.
- **One place blocks buying.** `CartService.add` refuses an expired flash deal. Everything that adds to the bag
  goes through it.
- **Removal works on any screen.** `CartService` is app-wide and listens to the clock itself, so it removes an
  expired line with no bag screen open. It calls a function it was given to show the notice, which keeps UI code
  out of the service and lets tests check the call.

**Decisions.** An expired card cannot be tapped. Seconds are rounded up, so `00:00` is never shown while the deal
can still be bought. The notice is a snackbar.

**Rejected alternatives.**
- A timer per card: 100 cards would mean 100 timers to start and cancel.
- An `Obx` around the card reading the clock: the whole card would rebuild every second.

**A separate small fix.** `CartService.add` now returns true or false. Before, the details screen showed
"Added to bag" even when the cart silently refused the add at the stock limit. It now shows it only when
something was added.

**Not handled, on purpose.**
- If a sale ends while the app is in the background, the line is removed on the first tick after returning and the
  snackbar shows then. If I am not looking at the phone in those 4 seconds I miss it; nothing in the bag records
  it.
- Expiry is judged by the phone's clock.
- A checkout request already sent when the sale ends still goes through.
- A refused add shows no message.

**Tests.** [countdown_format_test.dart](test/util/countdown_format_test.dart),
[deal_model_test.dart](test/model/deal_model_test.dart),
[clock_service_test.dart](test/service/clock_service_test.dart),
[cart_service_test.dart](test/service/cart_service_test.dart),
[flash_countdown_test.dart](test/feature/shared_widget/flash_countdown_test.dart) (includes 150 countdowns ticking
without rebuilding the list around them),
[flash_expiry_builder_test.dart](test/feature/shared_widget/flash_expiry_builder_test.dart),
[flash_countdown_places_test.dart](test/feature/shared_widget/flash_countdown_places_test.dart),
[flash_expiry_places_test.dart](test/feature/shared_widget/flash_expiry_places_test.dart),
[main_flash_notice_test.dart](test/main_flash_notice_test.dart).
Time is the test binding's fake clock, which moves only when the test says so.

**Profiling.** DevTools Rebuild Stats, top of Home, about 30 seconds without touching the screen: only `Obx` and
`Text` at `flash_countdown.dart` rebuilt, 110 builds each, 5 per frame for the 5 visible countdowns. There were no
rows for `DealCard`, `FlashDealsSection`, `Scaffold` or `AppBar`.
[Screenshot](docs/after/14_f1_rebuilds_idle.png).
The seed data has 14 flash deals, so I could not put 100 on screen in the app; the 150-countdown test covers that.

**Evidence.** [before: "Ends soon"](docs/before/14_f1_ends_soon.png),
[live countdown](docs/after/14_f1_countdown.png),
[details running](docs/after/14_f1_details_running.png),
[details expired](docs/after/14_f1_details_expired.png),
[expired card](docs/after/14_f1_expired.png),
[before: expired deal still in the bag](docs/before/15_f1_bag_expired_still_there.png),
[snackbar on another screen](docs/after/15_f1_snackbar.png),
[bag emptied](docs/after/15_f1_bag_expired_removed.png).

## 3. RES-105 evidence

**Environment.** Android emulator (Pixel, API 37), **debug mode**, Flutter 3.27.0. I have no physical Android
device, so I could not measure on a mid-range phone as the ticket describes.

**Method.** DevTools → Performance → Rebuild Stats with "Count widget builds" on; Flutter Inspector → "Highlight
oversized images" and the console lines it prints; `adb shell dumpsys meminfo dev.rescu.rescu` after scrolling
pages 1–6. The baseline was taken before any RES-105 change. Where I could, I compared the old and new code back
to back by stashing the change.

**Commit 1 — scoping the `Obx`.** About 30 seconds of scrolling:

| Widget | Before | After |
|---|---|---|
| `AppBar` and its `IconButton`s | 154 | 2 |
| `DealCard` | 855 | 98 |
| `CachedNetworkImage` | 927 | 98 |
| Body `Obx` / `SmartRefresher` | 154 | 4–5 |

[before](docs/before/13_res105_rebuilds_top.png), [before, cards](docs/before/13_res105_rebuilds_cards.png),
[after](docs/after/13_res105_c1_rebuilds_top.png), [after, cards](docs/after/13_res105_c1_rebuilds_card.png).

**Commit 2 — lazy list with keys.** Same steps on both versions: top of the feed, about three on/off toggles of
"Pickup today", no scrolling.

| Widget | Commit 1 code | Commit 2 code |
|---|---|---|
| `DealCard` | 102 | 15 |
| `CachedNetworkImage` | 130 | 35 |

[commit 1](docs/after/13_res105_c1_toggle.png), [commit 2](docs/after/13_res105_c2_toggle.png).
The tap count was not exact: the second run may have been five taps, not six. The gap is far larger than one tap.

**Commit 3 — image decode size.** Lines printed by "Highlight oversized images":

| Image | Shown at (px) | Decoded before | Extra before | Decoded after | Extra after |
|---|---|---|---|---|---|
| Flash rail | 504×236 | 1600×1200 | +9379 KB | 504×378 | +372 KB |
| Feed card | 996×420 | 1600×1200 | +7821 KB | 996×747 | +1696 KB |

[before](docs/before/13_res105_decode_lines.png), [after](docs/after/13_res105_decode_lines.png),
[every image flagged before](docs/before/13_res105_oversized.png).
Feed images are still flagged after the fix. The tool compares the decoded size with the visible box, and a 4:3
photo shown in a wide card with `BoxFit.cover` is cropped; the cropped rows are still decoded.

After commit 3 I checked image sharpness on the emulator: the feed, flash rail, search, deal details header,
My orders and bag all looked sharp, with no stretching.

**Memory after pages 1–6** (`dumpsys meminfo`, KB):

| Line | Before | After |
|---|---|---|
| TOTAL PSS | 303,779 | 261,425 |
| Native Heap | 83,391 | 65,383 |
| Unknown | 127,453 | 111,005 |

[before](docs/before/13_res105_meminfo.txt), [after](docs/after/13_res105_c3_meminfo.txt).

**Honest limits.**
- **Debug mode on an emulator.** Frame times are not representative, so I make no frame-time claim. Rebuild counts
  and decode sizes are valid in debug.
- **The frame chart showed slow frames on the raster side**, not the UI thread, and they were still there after
  commit 1. So commit 1 is evidence of removed rebuilds, not of smoother frames.
  [Frame chart](docs/before/01_frames.png).
- **Memory growth was not reproduced.** Over about three minutes and pages 1–6 the memory chart stayed flat
  ([chart](docs/before/05_memory_long.png)). Decoded images are not in the Dart heap, and Flutter's image cache
  stops at 100 MB by default, so a plateau is what I would expect on this emulator.
- **The meminfo numbers are one run each**, and the "before" run predates all three commits. The difference cannot
  be credited to commit 3 alone, and I do not know the run-to-run variation. The decode lines are the direct
  evidence for commit 3.
- **The 30-second scroll run after commit 2 is not comparable** with commit 1's: I scrolled further and loaded
  more pages. I claim no scroll improvement for commit 2.

## 4. AI usage log

**Tools.**
- Claude Code (VS Code extension): reading the code, root-cause analysis, writing tests and fixes, drafting this
  write-up.
- Claude (claude.ai chat): reviewing my prompt against PROBLEM.md, step-by-step setup help, checking Claude Code's
  plans against the actual code before I approved them, and suggesting evidence to capture.

**How I used it.** For each ticket I had it explain the root cause with file references before any edit, write a
test that fails on the old code, and then fix. I did the emulator checks and took all the measurements myself.
Claude Code made one early bookkeeping commit (`7e766f2`); after that I made git add, commit and push mine alone
(`a3c5b4c`) and ran every git command myself. For several tickets I also explained the fix back in my own words
and was corrected where I was imprecise. My working notes are in [PROGRESS.md](PROGRESS.md) and
[AI_LOG.md](AI_LOG.md).

**Times the AI was wrong or misleading.**

1. **RES-105 evidence.** Claude (chat) said the Memory tab's "Default" dropdown switches to an Android memory
   view. I opened it and it only had time ranges. I found the Android chart through the settings option instead,
   and recorded that the image cache is not visible in the Dart heap chart.
2. **RES-101 debounce test.** Claude (chat) told me to ask for a test using `fakeAsync`. Claude Code checked and
   found `flutter_test` does not export it; using it needs the `fake_async` package in `pubspec.yaml`, which the
   brief forbids changing. I used `testWidgets` with `tester.pump(duration)` instead, which gives a fake clock
   with no dependency change.
3. **RES-105 commit 3.** Claude Code predicted "no highlighted images" after decoding at display size. Before I
   measured, it checked the Flutter 3.27 source and corrected itself: an image is flagged when its decoded size
   exceeds the visible box by more than 128 KB, and a cover-cropped photo still does. I used the decode size in the
   console line as the evidence, not whether the image is flipped. The emulator confirmed it: still flagged, but
   1600×1200 became 996×747.
4. **F-1 commit 3.** Claude Code ran `dart format` on the whole `lib/` and `test/` folders instead of only the
   changed files. That reformatted five unrelated files, including the forbidden
   `lib/service/fake_api_service.dart`. It noticed this in the formatter output and reported it. I verified with
   `git status` and `git diff e5ee445 --stat -- lib/service/fake_api_service.dart assets/data` (empty). The files
   were restored from git, and the rule became "format only the files you changed".
5. **RES-107 cold start.** Claude Code read one GetX function (`initialRoutesGenerate`) and predicted that a deep
   link opened on a cold start would have only the deal page in the stack, with no Home underneath, and proposed a
   possible extra commit for a Home button. I tested a cold start with adb after the fix: deal 42 opened and back
   returned to Home. So no extra commit was needed. The prediction came from reading code without running it; why
   it was wrong was not investigated.
6. **RES-105 commit 2.** Claude Code said the lazy list with keys would have little measurable effect, and Claude
   (chat) predicted about 3–6 `DealCard` builds per single filter toggle. I measured 24 and 27 for single toggles
   on the commit 2 code. Those readings were uncontrolled, so I ran a controlled A/B test with the change stashed for the "before" run:
   about three on/off toggles gave 102 `DealCard` builds on the commit 1 code and 15 on the commit 2 code. That
   A/B result is the evidence for commit 2 in section 3.
7. **F-1 clock tests.** Claude Code wrote the `ClockService` tests using `Get.delete<ClockService>()` to close the
   service. They failed after implementing (expected 00:00:01, actual 00:00:06: the clock kept ticking). It then
   checked the GetX 4.7.3 source: `Get.delete` silently refuses to delete a `GetxService` unless `force: true` is
   passed. The tests were fixed; the app code did not change. It also showed me that GetX never closes a service
   by itself, so the clock's timer runs for the whole app, which is the intended design.

**Smaller suggestions I changed or that turned out wrong.**
- RES-101: the first sketch put the stale check before the error log, so a stale failure would leave no trace.
  The log was moved above the check.
- RES-101 debounce: it predicted a test would fail on the old code; it passed. It showed the test was still
  meaningful by temporarily breaking the code, then restored it.
- RES-102: it predicted a test would pass on the old code; it failed, because `testWidgets` reports any timer
  still pending at the end. I kept the test as a "still ticks on screen" guard.
- RES-104: its first version of one test failed on correct code. The fault was in the test: the pull-to-refresh
  package updates its footer after the next frame, and `tester.pump()` alone drew no frame.
- RES-105: its first image rule (width if the box is wider than tall) would have upscaled the details header on
  narrow phones. I asked for an audit of every image usage; it found the gap and changed the rule to compare with
  the image's 4:3 shape.

What I take from this: its predictions about tools and about what a test would do were wrong often enough that I
only trusted what a failing test or the emulator showed.

## 5. Design questions

**Q1. `GetxController` lifecycle versus widget `State` lifecycle.**
A `GetxController` in this codebase is created by a route's binding and lives as long as the route: GetX calls
`onInit` when it is first used and `onClose` when the route is popped and the controller is deleted. App-wide
services registered as permanent in `main.dart` are never closed. A widget `State` lives as long as its widget is
in the tree: `initState` when it appears, `dispose` when it is removed. Neither cleans up for the other, and
neither cleans up something you started unless you write it. RES-102 exists because of this confusion: the pickup
countdown's timer was started in a widget `State` inside a GetX screen, with no `dispose`. GetX correctly deleted
`OrdersController` when the screen closed, but the timer was never the controller's, so nothing stopped it and it
kept calling `setState`. RES-103 is the mirror image: a `GetxController` started a worker on a permanent service
and had no `onClose`, so the deleted controller kept receiving events.

**Q2. When does one big `Obx` hurt, and how do I decide the scope?**
It hurts when the `Obx` reads something that changes often, because everything inside rebuilds each time, even
parts that do not depend on that value. In RES-105 one `Obx` wrapped the home `Scaffold` and read the scroll
offset, so about 30 seconds of scrolling rebuilt the app bar 154 times and built deal cards 855 times, although
nothing in them changed. I decide the scope in two steps. First, make the value as coarse as the UI needs: the
screen needed two yes/no answers, not the offset, and an `RxBool` only notifies when it flips. Second, put the
`Obx` around the smallest widget that uses the value. After that change the same scroll rebuilt the app bar twice
and built 98 cards. F-1 uses the same rule: the `Obx` wraps only the countdown `Text`, so each second rebuilds
that text and not the card.

**Q3. An automated test that would have caught RES-106.**
The test builds a pickup window the way the API sends it, as an ISO-8601 UTC string, and checks the label shows
the local wall-clock time. To stay valid in any time zone it starts from a local time
(`DateTime(2026, 1, 15, 6, 0).toUtc().toIso8601String()`) and expects `06:00`; January avoids daylight-saving
changes. For "today" the code needed one change to be testable: `isToday` read the real clock, so I added
`isTodayAt(DateTime now)` and the tests pass a fixed "now". The honest limit is that the label test only catches
the bug on a machine that is not on UTC, where local time and UTC are the same; CI should run tests with
`TZ=Asia/Bangkok`. The test "same day number, different month" fails on the old code in every time zone. To pin
the zone inside the test itself, the model would have to take the zone or a "to local" function as a parameter;
I did not do that.

## 6. Time spent and what I would do next

**Time.**
- Day 1 (10 October): about 6.5 hours. About 1.3 h toolchain and emulator setup, 0.3 h RES-105 baseline, 1.2 h
  reading the code and the baseline run, then RES-106 (0.4 h), RES-101 with debounce (0.7 h), RES-102 (0.7 h),
  RES-103 (0.4 h), RES-107 (0.5 h), RES-104 (0.5 h) and RES-105 commit 1 (0.5 h).
- Day 2 (11 October): about 4.5 hours (10:07 to about 14:30). RES-105 commits 2 and 3, F-1, and this write-up.
- Total: about 11 hours.

**With one more day.**

*F-2, impression tracking.* The feed cards already have per-deal keys from RES-105, which a visibility tracker
needs. I would wrap each card in a `VisibilityDetector`, start a one-second wait when a card is at least 50%
visible, and cancel it if the card drops below. A session-wide set of deal ids in the analytics service would give
"once per deal per session". Events would go into a buffer that is sent through `sendAnalyticsBatch` at 10 events,
or 15 seconds after the first unsent one, using the shared clock from F-1 so the tests can control time. I would
re-measure scrolling afterwards.

*F-3, stock reservations.* Adding to the bag would show the line at once and reserve in the background; a 409
would roll the line back with a plain message. Each line would show its hold time with the same clock and
countdown approach as F-1. Removing a line would release the hold. Checkout already passes reservation ids, and a
410 would be handled by telling the user which line lost its hold. For the open question, a hold expiring while
the user is still in the app, my decision is: keep the line, mark it "hold expired", block checkout until the user
re-reserves it, and never renew a hold silently, because silent renewal keeps stock away from other buyers
forever.

*Smaller things.* A "no more left" message when an add is refused. A lasting note in the bag when a flash deal was
removed. An error screen when the first feed load fails. Running the tests in CI with `TZ=Asia/Bangkok`.
Measuring RES-105 in profile mode on a real mid-range phone.
