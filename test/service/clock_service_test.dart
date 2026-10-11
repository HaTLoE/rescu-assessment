import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:rescu/service/clock_service.dart';

void main() {
  tearDown(Get.reset);

  // testWidgets gives a fake clock: tester.binding.clock only moves when the
  // test calls tester.pump(duration). Passing it in as the service's clock
  // makes time fully controlled, with no real waiting.
  //
  // Each test closes the service itself, because testWidgets fails a test
  // that ends with a timer still running. `force: true` is needed: GetX
  // refuses to delete a GetxService otherwise (services live for the app).

  testWidgets('now starts at the injected clock and moves once per second',
      (tester) async {
    final clock = Get.put(
      ClockService(readClock: () => tester.binding.clock.now()),
    );
    final start = tester.binding.clock.now();
    expect(clock.now.value, start);

    await tester.pump(const Duration(seconds: 1));
    expect(clock.now.value, start.add(const Duration(seconds: 1)));

    await tester.pump(const Duration(seconds: 3));
    expect(clock.now.value, start.add(const Duration(seconds: 4)));

    await Get.delete<ClockService>(force: true);
  });

  testWidgets('listeners are told on every tick', (tester) async {
    final clock = Get.put(
      ClockService(readClock: () => tester.binding.clock.now()),
    );
    var ticks = 0;
    final subscription = clock.now.listen((_) => ticks++);

    await tester.pump(const Duration(seconds: 3));

    expect(ticks, 3);

    await subscription.cancel();
    await Get.delete<ClockService>(force: true);
  });

  testWidgets('closing the service stops the ticking', (tester) async {
    final clock = Get.put(
      ClockService(readClock: () => tester.binding.clock.now()),
    );
    await tester.pump(const Duration(seconds: 1));
    final atClose = clock.now.value;

    await Get.delete<ClockService>(force: true);
    await tester.pump(const Duration(seconds: 5));

    expect(clock.now.value, atClose);
  });
}
