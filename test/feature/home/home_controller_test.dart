import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:pull_to_refresh/pull_to_refresh.dart';
import 'package:rescu/feature/home/home_controller.dart';
import 'package:rescu/model/deal_model.dart';
import 'package:rescu/model/paged_response_model.dart';
import 'package:rescu/model/pickup_window_model.dart';
import 'package:rescu/repository/deal_repo.dart';
import 'package:rescu/service/api_exception.dart';
import 'package:rescu/service/fake_api_service.dart';

/// Test pages hold 2 deals each: page 1 is deals 1-2, page 2 is deals 3-4...
const pageSize = 2;

class _PageRequest {
  _PageRequest(this.page);

  final int page;
  final completer = Completer<PagedResponseModel<DealModel>>();
}

/// Records every `GET /deals?page=N` in order and answers each one only when
/// the test says so, so a test can choose which response lands first.
///
/// The [FakeApiService] is never used: it is only there because [DealRepo]
/// requires one. Its assets are loaded in `init()`, which is never called.
class FakeDealRepo extends DealRepo {
  FakeDealRepo() : super(api: FakeApiService());

  final _requests = <_PageRequest>[];

  List<int> get requestedPages => _requests.map((r) => r.page).toList();

  @override
  Future<PagedResponseModel<DealModel>> fetchDeals({int page = 1}) {
    final request = _PageRequest(page);
    _requests.add(request);
    return request.completer.future;
  }

  @override
  Future<List<DealModel>> fetchFlashDeals() async => [];

  _PageRequest _oldestOpen(int page) =>
      _requests.firstWhere((r) => r.page == page && !r.completer.isCompleted);

  void _complete(_PageRequest request, int totalPages) {
    request.completer.complete(PagedResponseModel(
      items: dealsOnPage(request.page),
      page: request.page,
      totalPages: totalPages,
    ));
  }

  /// Answers the oldest unanswered request for [page].
  void answer(int page, {int totalPages = 7}) =>
      _complete(_oldestOpen(page), totalPages);

  /// Answers the most recent request, whatever page it asked for.
  void answerLatest({int totalPages = 7}) =>
      _complete(_requests.last, totalPages);

  /// Fails the oldest unanswered request for [page].
  void fail(int page) => _oldestOpen(page)
      .completer
      .completeError(const ApiException('Server error'));
}

List<DealModel> dealsOnPage(int page) {
  final firstId = (page - 1) * pageSize + 1;
  return [for (var i = 0; i < pageSize; i++) deal(firstId + i)];
}

DealModel deal(int id) {
  return DealModel(
    id: id,
    name: 'Deal $id',
    description: '',
    imageUrl: '',
    originalPrice: 100,
    price: 50,
    currencyCode: 'THB',
    quantityLeft: 1,
    storeId: 1,
    storeName: 'Store',
    storeAddress: '',
    lat: 0,
    lng: 0,
    rating: null,
    tags: const [],
    pickupWindow: PickupWindowModel(
      start: DateTime.utc(2026, 1, 15, 10),
      end: DateTime.utc(2026, 1, 15, 12),
    ),
    flashSaleEndsAt: null,
  );
}

void main() {
  late FakeDealRepo repo;

  List<int> ids(HomeController controller) =>
      controller.deals.map((d) => d.id).toList();

  /// Lets finished requests run their code, then draws one frame.
  ///
  /// The frame matters: the pull_to_refresh controller changes its footer
  /// status in an "after this frame" callback, and pump() alone draws no
  /// frame when none is scheduled.
  Future<void> settle(WidgetTester tester) async {
    await tester.pump();
    tester.binding.scheduleFrame();
    await tester.pump();
  }

  /// Creates the controller the way GetX does (Get.put runs onInit, which
  /// requests page 1) and answers that first page. No widget is built;
  /// testWidgets is used only for its tester.
  Future<HomeController> startWithFirstPage(
    WidgetTester tester, {
    int totalPages = 7,
  }) async {
    final controller = Get.put(HomeController(dealRepo: repo));
    repo.answer(1, totalPages: totalPages);
    await settle(tester);
    return controller;
  }

  setUp(() {
    repo = FakeDealRepo();
  });

  tearDown(() async {
    await Get.delete<HomeController>();
    Get.reset();
  });

  testWidgets(
      'a page-2 response that lands after a refresh is dropped, so no duplicates',
      (tester) async {
    final controller = await startWithFirstPage(tester);

    controller.loadMore(); // page 2 in flight
    controller.refreshDeals(); // page 1 in flight
    repo.answer(1);
    await settle(tester);
    repo.answer(2);
    await settle(tester);

    expect(ids(controller), [1, 2]);

    controller.loadMore();
    repo.answer(2);
    await settle(tester);

    expect(repo.requestedPages, [1, 2, 1, 2]);
    expect(ids(controller), [1, 2, 3, 4]);
  });

  testWidgets('a page-2 response that lands before the refresh is replaced',
      (tester) async {
    final controller = await startWithFirstPage(tester);

    controller.loadMore(); // page 2 in flight
    controller.refreshDeals(); // page 1 in flight
    repo.answer(2);
    await settle(tester);
    repo.answer(1);
    await settle(tester);

    expect(ids(controller), [1, 2]);

    controller.loadMore();
    repo.answer(2);
    await settle(tester);

    expect(repo.requestedPages, [1, 2, 1, 2]);
    expect(ids(controller), [1, 2, 3, 4]);
  });

  testWidgets('a failed loadMore keeps the list and retries the same page',
      (tester) async {
    final controller = await startWithFirstPage(tester);

    controller.loadMore();
    repo.fail(2);
    await settle(tester);

    expect(ids(controller), [1, 2]);

    controller.loadMore();
    expect(repo.requestedPages, [1, 2, 2]);
    repo.answer(2);
    await settle(tester);
    expect(ids(controller), [1, 2, 3, 4]);

    // Checked last so the page checks above are reported first.
    controller.loadMore();
    repo.fail(3);
    await settle(tester);
    expect(controller.refreshController.footerStatus, LoadStatus.failed);
  });

  testWidgets(
      'a loadMore that fails after a refresh landed does not move the page back',
      (tester) async {
    final controller = await startWithFirstPage(tester);

    controller.loadMore(); // page 2 in flight
    controller.refreshDeals();
    repo.answer(1);
    await settle(tester);
    repo.fail(2);
    await settle(tester);

    controller.loadMore();

    expect(repo.requestedPages, [1, 2, 1, 2]);
    expect(ids(controller), [1, 2]);
  });

  testWidgets('a loadMore started during a refresh does not make a page skip',
      (tester) async {
    final controller = await startWithFirstPage(tester);
    controller.loadMore();
    repo.answer(2);
    await settle(tester);
    controller.loadMore();
    repo.answer(3);
    await settle(tester);
    expect(ids(controller), [1, 2, 3, 4, 5, 6]);

    controller.refreshDeals(); // page 1 in flight
    controller.loadMore(); // lands first, while the old list is still shown
    repo.answerLatest();
    await settle(tester);
    repo.answer(1);
    await settle(tester);

    expect(ids(controller), [1, 2]);

    controller.loadMore();

    expect(repo.requestedPages.last, 2);
  });

  testWidgets('loadMore on the last page sends no request', (tester) async {
    final controller = await startWithFirstPage(tester, totalPages: 1);

    controller.loadMore();
    await settle(tester);

    expect(repo.requestedPages, [1]);
    expect(controller.refreshController.footerStatus, LoadStatus.noMore);
  });

  testWidgets('a failed refresh keeps the list and page and reports failure',
      (tester) async {
    final controller = await startWithFirstPage(tester);
    controller.loadMore();
    repo.answer(2);
    await settle(tester);
    expect(ids(controller), [1, 2, 3, 4]);

    Object? uncaught;
    controller.refreshDeals().catchError((Object e) {
      uncaught = e;
    });
    repo.fail(1);
    await settle(tester);

    expect(uncaught, isNull);
    expect(controller.refreshController.headerStatus, RefreshStatus.failed);
    expect(ids(controller), [1, 2, 3, 4]);

    controller.loadMore();

    expect(repo.requestedPages.last, 3);
  });

  testWidgets('a refresh makes "no more data" loadable again', (tester) async {
    final controller = await startWithFirstPage(tester, totalPages: 2);
    controller.loadMore();
    repo.answer(2, totalPages: 2);
    await settle(tester);
    controller.loadMore(); // already on the last page
    await settle(tester);
    expect(controller.refreshController.footerStatus, LoadStatus.noMore);

    controller.refreshDeals();
    repo.answer(1, totalPages: 2);
    await settle(tester);

    expect(ids(controller), [1, 2]);
    expect(controller.refreshController.footerStatus, LoadStatus.idle);
  });

  testWidgets('the scroll flags flip exactly at their thresholds',
      (tester) async {
    final controller = await startWithFirstPage(tester);
    // Any tall scrollable will do: the flags depend only on the offset.
    await tester.pumpWidget(MaterialApp(
      home: ListView(
        controller: controller.scrollController,
        children: const [SizedBox(height: 5000)],
      ),
    ));
    expect(controller.isScrolled.value, isFalse);
    expect(controller.showScrollToTop.value, isFalse);

    controller.scrollController.jumpTo(4);
    expect(controller.isScrolled.value, isFalse);

    controller.scrollController.jumpTo(5);
    expect(controller.isScrolled.value, isTrue);
    expect(controller.showScrollToTop.value, isFalse);

    controller.scrollController.jumpTo(800);
    expect(controller.showScrollToTop.value, isFalse);

    controller.scrollController.jumpTo(801);
    expect(controller.showScrollToTop.value, isTrue);

    controller.scrollController.jumpTo(0);
    expect(controller.isScrolled.value, isFalse);
    expect(controller.showScrollToTop.value, isFalse);
  });
}
