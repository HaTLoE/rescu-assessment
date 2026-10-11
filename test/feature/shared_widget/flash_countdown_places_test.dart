import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:rescu/feature/deal/deal_details_controller.dart';
import 'package:rescu/feature/deal/deal_details_screen.dart';
import 'package:rescu/feature/home/widget/flash_deals_section.dart';
import 'package:rescu/feature/shared_widget/deal_card.dart';
import 'package:rescu/model/deal_model.dart';
import 'package:rescu/model/pickup_window_model.dart';
import 'package:rescu/repository/deal_repo.dart';
import 'package:rescu/service/analytics_service.dart';
import 'package:rescu/service/cart_service.dart';
import 'package:rescu/service/clock_service.dart';
import 'package:rescu/service/fake_api_service.dart';

/// Never asked for anything in these tests: the deal is passed in directly.
/// The [FakeApiService] is only there because [DealRepo] requires one.
class UnusedDealRepo extends DealRepo {
  UnusedDealRepo() : super(api: FakeApiService());
}

DealModel flashDeal(int id, DateTime flashSaleEndsAt) {
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
      start: DateTime.utc(2026, 1, 15, 10),
      end: DateTime.utc(2026, 1, 15, 12),
    ),
    flashSaleEndsAt: flashSaleEndsAt,
  );
}

/// The three places a flash deal appears must all show the same live
/// countdown. Time is the test's fake clock: it moves only on pump(duration).
void main() {
  tearDown(Get.reset);

  /// Registers the shared clock on the fake clock and returns a deal whose
  /// flash sale ends in exactly ten minutes.
  DealModel startClock(WidgetTester tester) {
    Get.put(ClockService(readClock: () => tester.binding.clock.now()));
    return flashDeal(
      1,
      tester.binding.clock.now().add(const Duration(minutes: 10)),
    );
  }

  /// The clock's timer must be stopped before a test ends. `force` is needed
  /// because GetX does not delete a GetxService otherwise.
  Future<void> stopClock() => Get.delete<ClockService>(force: true);

  testWidgets('a feed card shows a live countdown for a flash deal',
      (tester) async {
    final deal = startClock(tester);
    await tester.pumpWidget(GetMaterialApp(
      home: Scaffold(body: ListView(children: [DealCard(deal: deal)])),
    ));

    expect(find.text('10:00'), findsOneWidget);

    await tester.pump(const Duration(seconds: 1));
    expect(find.text('09:59'), findsOneWidget);

    await stopClock();
  });

  testWidgets('the flash rail shows a live countdown instead of "Ends soon"',
      (tester) async {
    final deal = startClock(tester);
    await tester.pumpWidget(GetMaterialApp(
      home: Scaffold(
        body: ListView(children: [
          FlashDealsSection(deals: [deal])
        ]),
      ),
    ));

    expect(find.text('Ends soon'), findsNothing);
    expect(find.text('10:00'), findsOneWidget);

    await tester.pump(const Duration(seconds: 1));
    expect(find.text('09:59'), findsOneWidget);

    await stopClock();
  });

  testWidgets('the details screen shows a live countdown for a flash deal',
      (tester) async {
    final deal = startClock(tester);
    Get.parameters = {'id': '${deal.id}', 'source': 'home'};
    Get.routing.args = deal;
    Get.put(DealDetailsController(
      dealRepo: UnusedDealRepo(),
      cartService: CartService(),
      analytics: AnalyticsService(),
    ));
    await tester.pumpWidget(const GetMaterialApp(home: DealDetailsScreen()));

    expect(find.text('10:00'), findsOneWidget);

    await tester.pump(const Duration(seconds: 1));
    expect(find.text('09:59'), findsOneWidget);

    await Get.delete<DealDetailsController>();
    await stopClock();
  });
}
