import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rescu/feature/order/widget/pickup_countdown.dart';

void main() {
  // A pickup time in the past keeps the text fixed ("Pickup window is open"),
  // so these tests do not depend on the real clock.
  final pastPickup = DateTime.now().subtract(const Duration(hours: 1));

  testWidgets('stops ticking after it is removed from the tree',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(home: PickupCountdown(pickupStart: pastPickup)),
    );
    expect(find.text('Pickup window is open'), findsOneWidget);

    // Replacing the tree disposes the countdown's State, like pressing back.
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 2));

    expect(tester.takeException(), isNull);
  });

  testWidgets('keeps ticking without errors while it is on screen',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(home: PickupCountdown(pickupStart: pastPickup)),
    );

    await tester.pump(const Duration(seconds: 2));

    expect(tester.takeException(), isNull);
    expect(find.text('Pickup window is open'), findsOneWidget);
  });
}
