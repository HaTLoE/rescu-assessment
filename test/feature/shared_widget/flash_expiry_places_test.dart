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
    quantityLeft: 5,
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

/// When a flash sale ends, every place the deal appears must switch to a
/// disabled "Expired" state. Time is the test's fake clock.
void main() {
  tearDown(Get.reset);

  /// Registers the shared clock on the fake clock and returns a deal whose
  /// flash sale ends in exactly ten seconds.
  DealModel startClock(WidgetTester tester) {
    Get.put(ClockService(readClock: () => tester.binding.clock.now()));
    return flashDeal(
      1,
      tester.binding.clock.now().add(const Duration(seconds: 10)),
    );
  }

  /// The clock's timer must be stopped before a test ends. `force` is needed
  /// because GetX does not delete a GetxService otherwise.
  Future<void> stopClock() => Get.delete<ClockService>(force: true);

  /// The details screen's button. `FilledButton.icon` builds a subclass of
  /// FilledButton, so it has to be found with `is`, not by exact type.
  FilledButton addToBagButton(WidgetTester tester) {
    return tester.widget<FilledButton>(
      find.byWidgetPredicate((widget) => widget is FilledButton),
    );
  }

  testWidgets('a feed card becomes a disabled "Expired" card at zero',
      (tester) async {
    final deal = startClock(tester);
    await tester.pumpWidget(GetMaterialApp(
      home: Scaffold(body: ListView(children: [DealCard(deal: deal)])),
    ));
    expect(find.text('FLASH SALE'), findsOneWidget);
    expect(tester.widget<InkWell>(find.byType(InkWell)).onTap, isNotNull);

    await tester.pump(const Duration(seconds: 10));

    expect(find.text('EXPIRED'), findsOneWidget);
    expect(find.text('FLASH SALE'), findsNothing);
    expect(find.text('00:00'), findsNothing);
    expect(tester.widget<InkWell>(find.byType(InkWell)).onTap, isNull);

    await stopClock();
  });

  testWidgets('a flash rail card becomes a disabled "Expired" card at zero',
      (tester) async {
    final deal = startClock(tester);
    await tester.pumpWidget(GetMaterialApp(
      home: Scaffold(
        body: ListView(children: [
          FlashDealsSection(deals: [deal])
        ]),
      ),
    ));
    expect(tester.widget<InkWell>(find.byType(InkWell)).onTap, isNotNull);

    await tester.pump(const Duration(seconds: 10));

    expect(find.text('Expired'), findsOneWidget);
    expect(find.text('00:00'), findsNothing);
    expect(tester.widget<InkWell>(find.byType(InkWell)).onTap, isNull);

    await stopClock();
  });

  testWidgets('a card built after the sale ended is expired from the start',
      (tester) async {
    final deal = startClock(tester);
    await tester.pump(const Duration(seconds: 30));

    await tester.pumpWidget(GetMaterialApp(
      home: Scaffold(body: ListView(children: [DealCard(deal: deal)])),
    ));

    expect(find.text('EXPIRED'), findsOneWidget);
    expect(tester.widget<InkWell>(find.byType(InkWell)).onTap, isNull);

    await stopClock();
  });

  testWidgets('the details button turns into a disabled "Expired" at zero',
      (tester) async {
    final deal = startClock(tester);
    Get.parameters = {'id': '${deal.id}', 'source': 'home'};
    Get.routing.args = deal;
    Get.put(DealDetailsController(
      dealRepo: UnusedDealRepo(),
      cartService: CartService(clock: Get.find()),
      analytics: AnalyticsService(),
    ));
    await tester.pumpWidget(const GetMaterialApp(home: DealDetailsScreen()));
    expect(find.text('Add to bag'), findsOneWidget);
    expect(
      addToBagButton(tester).onPressed,
      isNotNull,
    );

    await tester.pump(const Duration(seconds: 10));

    expect(find.text('Add to bag'), findsNothing);
    expect(find.text('Expired'), findsOneWidget);
    expect(find.text('Flash sale ended'), findsOneWidget);
    expect(find.text('00:00'), findsNothing);
    expect(
      addToBagButton(tester).onPressed,
      isNull,
    );

    await Get.delete<DealDetailsController>();
    await stopClock();
  });
}
