import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:rescu/feature/shared_widget/flash_expiry_builder.dart';
import 'package:rescu/model/deal_model.dart';
import 'package:rescu/model/pickup_window_model.dart';
import 'package:rescu/service/clock_service.dart';

DealModel deal({DateTime? flashSaleEndsAt}) {
  return DealModel(
    id: 1,
    name: 'Deal 1',
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

  // Time is the test's fake clock: it moves only on tester.pump(duration).
  DateTime startClock(WidgetTester tester) {
    Get.put(ClockService(readClock: () => tester.binding.clock.now()));
    return tester.binding.clock.now();
  }

  // `force` is needed because GetX does not delete a GetxService otherwise.
  Future<void> stopClock() => Get.delete<ClockService>(force: true);

  testWidgets('builds once before expiry, once more at expiry, then never',
      (tester) async {
    final now = startClock(tester);
    var builds = 0;
    await tester.pumpWidget(MaterialApp(
      home: FlashExpiryBuilder(
        deal: deal(flashSaleEndsAt: now.add(const Duration(seconds: 10))),
        builder: (context, isExpired) {
          builds++;
          return Text(isExpired ? 'expired' : 'running');
        },
      ),
    ));
    expect(find.text('running'), findsOneWidget);
    expect(builds, 1);

    // Nine ticks of the clock: still running, and NOT rebuilt per second.
    await tester.pump(const Duration(seconds: 9));
    expect(find.text('running'), findsOneWidget);
    expect(builds, 1);

    await tester.pump(const Duration(seconds: 1));
    expect(find.text('expired'), findsOneWidget);
    expect(builds, 2);

    await tester.pump(const Duration(seconds: 30));
    expect(builds, 2);

    await stopClock();
  });

  testWidgets('a deal that already expired is expired on the first build',
      (tester) async {
    final now = startClock(tester);
    var builds = 0;
    await tester.pumpWidget(MaterialApp(
      home: FlashExpiryBuilder(
        deal: deal(flashSaleEndsAt: now.subtract(const Duration(seconds: 1))),
        builder: (context, isExpired) {
          builds++;
          return Text(isExpired ? 'expired' : 'running');
        },
      ),
    ));

    expect(find.text('expired'), findsOneWidget);

    await tester.pump(const Duration(seconds: 5));
    expect(builds, 1);

    await stopClock();
  });

  testWidgets('a deal that is not a flash sale never expires, needs no clock',
      (tester) async {
    // No ClockService is registered in this test on purpose.
    await tester.pumpWidget(MaterialApp(
      home: FlashExpiryBuilder(
        deal: deal(),
        builder: (context, isExpired) =>
            Text(isExpired ? 'expired' : 'running'),
      ),
    ));

    expect(find.text('running'), findsOneWidget);
  });

  testWidgets('removing the widget stops it listening to the clock',
      (tester) async {
    final now = startClock(tester);
    await tester.pumpWidget(MaterialApp(
      home: FlashExpiryBuilder(
        deal: deal(flashSaleEndsAt: now.add(const Duration(seconds: 10))),
        builder: (context, isExpired) => const Text('card'),
      ),
    ));

    await tester.pumpWidget(const SizedBox());
    // The sale ends while the widget is gone. A listener left behind would
    // call setState on a disposed State and throw.
    await tester.pump(const Duration(seconds: 15));

    expect(tester.takeException(), isNull);

    await stopClock();
  });
}
