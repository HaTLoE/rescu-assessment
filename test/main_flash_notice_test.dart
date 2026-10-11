import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:rescu/main.dart';
import 'package:rescu/model/deal_model.dart';
import 'package:rescu/model/pickup_window_model.dart';
import 'package:rescu/service/cart_service.dart';
import 'package:rescu/service/clock_service.dart';

DealModel flashDeal(DateTime flashSaleEndsAt) {
  return DealModel(
    id: 1,
    name: 'Mystery Thai Feast',
    description: '',
    imageUrl: '',
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

void main() {
  tearDown(Get.reset);

  testWidgets(
      'a deal whose flash sale ends in the bag is removed with a visible notice, '
      'with no bag screen open', (tester) async {
    // The services are wired the same way main.dart wires them, on the
    // test's fake clock. The screen shown is NOT the bag.
    final clock = Get.put(
      ClockService(readClock: () => tester.binding.clock.now()),
    );
    final cart = Get.put(CartService(
      clock: clock,
      onFlashSaleExpired: showFlashSaleExpiredNotice,
    ));
    await tester.pumpWidget(const GetMaterialApp(
      home: Scaffold(body: Center(child: Text('Some other screen'))),
    ));
    cart.add(flashDeal(
      tester.binding.clock.now().add(const Duration(seconds: 10)),
    ));
    expect(cart.itemCount.value, 1);

    await tester.pump(const Duration(seconds: 9));
    expect(cart.itemCount.value, 1);
    expect(find.text('Flash sale ended'), findsNothing);

    await tester.pump(const Duration(seconds: 1));
    await tester.pump();

    expect(cart.items, isEmpty);
    expect(find.text('Flash sale ended'), findsOneWidget);
    expect(
      find.text('Mystery Thai Feast was removed from your bag'),
      findsOneWidget,
    );

    // Let the notice go away, then stop the timers before the test ends.
    // `force` is needed: GetX does not delete a GetxService otherwise.
    await tester.pump(const Duration(seconds: 6));
    await Get.delete<CartService>(force: true);
    await Get.delete<ClockService>(force: true);
  });
}
