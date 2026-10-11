import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:rescu/feature/shared_widget/flash_countdown.dart';
import 'package:rescu/service/clock_service.dart';

void main() {
  tearDown(Get.reset);

  // Time is the test's fake clock: it moves only on tester.pump(duration).
  DateTime startClock(WidgetTester tester) {
    Get.put(ClockService(readClock: () => tester.binding.clock.now()));
    return tester.binding.clock.now();
  }

  // The clock's timer must be stopped before a test ends. `force` is needed
  // because GetX does not delete a GetxService otherwise.
  Future<void> stopClock() => Get.delete<ClockService>(force: true);

  Future<void> pumpCountdown(WidgetTester tester, DateTime endsAt) {
    return tester.pumpWidget(MaterialApp(
      home: Center(child: FlashCountdown(endsAt: endsAt)),
    ));
  }

  testWidgets('counts down once per second in mm:ss', (tester) async {
    final now = startClock(tester);
    await pumpCountdown(tester, now.add(const Duration(minutes: 10)));
    expect(find.text('10:00'), findsOneWidget);

    await tester.pump(const Duration(seconds: 1));
    expect(find.text('09:59'), findsOneWidget);

    await tester.pump(const Duration(seconds: 59));
    expect(find.text('09:00'), findsOneWidget);

    await stopClock();
  });

  testWidgets('shows hh:mm:ss above an hour and switches to mm:ss below it',
      (tester) async {
    final now = startClock(tester);
    await pumpCountdown(
      tester,
      now.add(const Duration(hours: 1, seconds: 1)),
    );
    expect(find.text('01:00:01'), findsOneWidget);

    await tester.pump(const Duration(seconds: 1));
    expect(find.text('01:00:00'), findsOneWidget);

    await tester.pump(const Duration(seconds: 1));
    expect(find.text('59:59'), findsOneWidget);

    await stopClock();
  });

  testWidgets('stops at 00:00 and never shows a negative time', (tester) async {
    final now = startClock(tester);
    await pumpCountdown(tester, now.add(const Duration(seconds: 2)));

    await tester.pump(const Duration(seconds: 2));
    expect(find.text('00:00'), findsOneWidget);

    await tester.pump(const Duration(seconds: 5));
    expect(find.text('00:00'), findsOneWidget);

    await stopClock();
  });

  testWidgets('a tick rebuilds the countdown text but not its parent',
      (tester) async {
    final now = startClock(tester);
    var parentBuilds = 0;
    await tester.pumpWidget(MaterialApp(
      home: Builder(builder: (context) {
        parentBuilds++;
        return Center(
          child: FlashCountdown(
            endsAt: now.add(const Duration(minutes: 10)),
          ),
        );
      }),
    ));
    expect(parentBuilds, 1);

    await tester.pump(const Duration(seconds: 3));

    expect(find.text('09:57'), findsOneWidget);
    expect(parentBuilds, 1);

    await stopClock();
  });

  testWidgets('150 countdowns tick without rebuilding the list around them',
      (tester) async {
    final now = startClock(tester);
    final endsAt = now.add(const Duration(minutes: 10));
    var listBuilds = 0;
    await tester.pumpWidget(MaterialApp(
      home: Builder(builder: (context) {
        listBuilds++;
        return SingleChildScrollView(
          child: Wrap(
            children: [
              for (var i = 0; i < 150; i++) FlashCountdown(endsAt: endsAt),
            ],
          ),
        );
      }),
    ));
    expect(find.text('10:00'), findsNWidgets(150));

    await tester.pump(const Duration(seconds: 3));

    expect(find.text('09:57'), findsNWidgets(150));
    expect(listBuilds, 1);

    await stopClock();
  });
}
