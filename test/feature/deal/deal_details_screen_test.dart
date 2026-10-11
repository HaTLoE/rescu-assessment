import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:rescu/feature/deal/deal_details_controller.dart';
import 'package:rescu/feature/deal/deal_details_screen.dart';
import 'package:rescu/model/deal_model.dart';
import 'package:rescu/model/pickup_window_model.dart';
import 'package:rescu/repository/deal_repo.dart';
import 'package:rescu/service/analytics_service.dart';
import 'package:rescu/service/cart_service.dart';
import 'package:rescu/service/clock_service.dart';
import 'package:rescu/service/fake_api_service.dart';

/// Answers the stock re-check that follows a cart change with the same deal.
/// The [FakeApiService] is only there because [DealRepo] requires one.
class SameDealRepo extends DealRepo {
  SameDealRepo(this.deal) : super(api: FakeApiService());

  final DealModel deal;

  @override
  Future<DealModel> fetchById(int id) async => deal;
}

DealModel lastOneLeft() {
  return DealModel(
    id: 1,
    name: 'Deal 1',
    description: '',
    imageUrl: 'https://example.com/deal1.jpg',
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
  tearDown(Get.reset);

  testWidgets('"Added to bag" is shown only when the deal was really added',
      (tester) async {
    final deal = lastOneLeft();
    // The clock is not started: this deal is not a flash sale.
    final cart = CartService(
      clock: ClockService(readClock: () => DateTime.utc(2026, 1, 15)),
    );
    Get.parameters = {'id': '${deal.id}', 'source': 'home'};
    Get.routing.args = deal;
    Get.put(DealDetailsController(
      dealRepo: SameDealRepo(deal),
      cartService: cart,
      analytics: AnalyticsService(),
    ));
    await tester.pumpWidget(const GetMaterialApp(home: DealDetailsScreen()));

    await tester.tap(find.text('Add to bag'));
    await tester.pump();
    expect(find.text('Added to bag'), findsOneWidget);
    expect(cart.itemCount.value, 1);

    // Let the first notice go away.
    await tester.pump(const Duration(seconds: 5));
    expect(find.text('Added to bag'), findsNothing);

    // Only one was left, so a second add is refused: no "Added" notice.
    await tester.tap(find.text('Add to bag'));
    await tester.pump();
    expect(find.text('Added to bag'), findsNothing);
    expect(cart.itemCount.value, 1);

    await tester.pump(const Duration(seconds: 5));
    await Get.delete<DealDetailsController>();
  });
}
