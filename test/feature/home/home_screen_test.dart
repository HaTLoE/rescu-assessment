import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:pull_to_refresh/pull_to_refresh.dart';
import 'package:rescu/feature/home/home_controller.dart';
import 'package:rescu/feature/home/home_screen.dart';
import 'package:rescu/model/deal_model.dart';
import 'package:rescu/model/paged_response_model.dart';
import 'package:rescu/repository/deal_repo.dart';
import 'package:rescu/service/fake_api_service.dart';

/// Answers with an empty feed, so the screen builds no deal cards and
/// therefore no network images (which need platform plugins).
///
/// The [FakeApiService] is never used: it is only there because [DealRepo]
/// requires one. Its assets are loaded in `init()`, which is never called.
class EmptyDealRepo extends DealRepo {
  EmptyDealRepo() : super(api: FakeApiService());

  @override
  Future<PagedResponseModel<DealModel>> fetchDeals({int page = 1}) async {
    return const PagedResponseModel(items: [], page: 1, totalPages: 1);
  }

  @override
  Future<List<DealModel>> fetchFlashDeals() async => [];
}

void main() {
  tearDown(() async {
    await Get.delete<HomeController>();
    Get.reset();
  });

  testWidgets(
      'scrolling without crossing a threshold rebuilds neither the app bar nor the list',
      (tester) async {
    // A short screen, so even the empty feed (header row + footer) scrolls.
    // It is wide because the test font is much wider than a real one.
    tester.view.physicalSize = const Size(800, 120);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final controller = Get.put(HomeController(dealRepo: EmptyDealRepo()));
    await tester.pumpWidget(const GetMaterialApp(home: HomeScreen()));
    await tester.pump();

    final maxScroll = controller.scrollController.position.maxScrollExtent;
    expect(maxScroll, greaterThan(30), reason: 'the test needs room to scroll');

    // Already past the app bar's shadow threshold (4) and far from the
    // scroll-to-top threshold (800).
    controller.scrollController.jumpTo(10);
    await tester.pump();
    final appBarBefore = tester.widget<AppBar>(find.byType(AppBar));
    final listBefore =
        tester.widget<SmartRefresher>(find.byType(SmartRefresher));

    controller.scrollController.jumpTo(30);
    await tester.pump();

    // A rebuild of the parent creates new AppBar and SmartRefresher objects.
    // The same objects mean these parts of the screen were not rebuilt.
    expect(
      identical(tester.widget<AppBar>(find.byType(AppBar)), appBarBefore),
      isTrue,
      reason: 'the app bar was rebuilt by a scroll that changed nothing in it',
    );
    expect(
      identical(
        tester.widget<SmartRefresher>(find.byType(SmartRefresher)),
        listBefore,
      ),
      isTrue,
      reason: 'the list was rebuilt by a scroll that changed nothing in it',
    );
  });
}
