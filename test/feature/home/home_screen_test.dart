import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:pull_to_refresh/pull_to_refresh.dart';
import 'package:rescu/feature/home/home_controller.dart';
import 'package:rescu/feature/home/home_screen.dart';
import 'package:rescu/feature/shared_widget/deal_card.dart';
import 'package:rescu/model/deal_model.dart';
import 'package:rescu/model/paged_response_model.dart';
import 'package:rescu/model/pickup_window_model.dart';
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

/// Answers with one fixed page of [deals] and the given [flash] deals.
class ListDealRepo extends DealRepo {
  ListDealRepo({required this.deals, this.flash = const []})
      : super(api: FakeApiService());

  final List<DealModel> deals;
  final List<DealModel> flash;

  @override
  Future<PagedResponseModel<DealModel>> fetchDeals({int page = 1}) async {
    return PagedResponseModel(items: deals, page: 1, totalPages: 1);
  }

  @override
  Future<List<DealModel>> fetchFlashDeals() async => flash;
}

/// Noon today in local time: always "today" for the Pickup today filter.
DateTime get _noonToday {
  final now = DateTime.now();
  return DateTime(now.year, now.month, now.day, 12);
}

DealModel deal(int id, {bool pickupToday = true}) {
  final start =
      pickupToday ? _noonToday : _noonToday.add(const Duration(days: 2));
  return DealModel(
    id: id,
    name: 'Deal $id',
    description: '',
    imageUrl: 'https://example.com/deal$id.jpg',
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
      start: start.toUtc(),
      end: start.add(const Duration(hours: 2)).toUtc(),
    ),
    flashSaleEndsAt: null,
  );
}

void main() {
  tearDown(() async {
    await Get.delete<HomeController>();
    Get.reset();
  });

  Future<void> pumpHome(WidgetTester tester, DealRepo repo) async {
    Get.put(HomeController(dealRepo: repo));
    await tester.pumpWidget(const GetMaterialApp(home: HomeScreen()));
    await tester.pump();
  }

  testWidgets('each card carries its deal id as its key', (tester) async {
    await pumpHome(tester, ListDealRepo(deals: [deal(1), deal(2)]));

    final keyed = find.byKey(const ValueKey<int>(1));
    expect(keyed, findsOneWidget);
    expect(tester.widget(keyed), isA<DealCard>());
  });

  testWidgets('only cards near the screen are built', (tester) async {
    final deals = [for (var id = 1; id <= 40; id++) deal(id)];
    await pumpHome(tester, ListDealRepo(deals: deals));

    final built = find.byType(DealCard).evaluate().length;
    expect(built, greaterThan(0));
    expect(built, lessThan(10));
  });

  testWidgets('"Pickup today" hides deals that do not start today',
      (tester) async {
    await pumpHome(
      tester,
      ListDealRepo(deals: [deal(1), deal(2, pickupToday: false)]),
    );
    expect(find.text('Deal 1'), findsOneWidget);
    expect(find.text('Deal 2'), findsOneWidget);

    await tester.tap(find.text('Pickup today'));
    await tester.pump();

    expect(find.text('Deal 1'), findsOneWidget);
    expect(find.text('Deal 2'), findsNothing);
  });

  testWidgets('the flash rail and the header show above the cards',
      (tester) async {
    await pumpHome(
      tester,
      ListDealRepo(deals: [deal(1)], flash: [deal(9)]),
    );

    expect(find.text('Flash sales'), findsOneWidget);
    expect(find.text('Nearby deals'), findsOneWidget);
    expect(find.text('Deal 1'), findsOneWidget);
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
