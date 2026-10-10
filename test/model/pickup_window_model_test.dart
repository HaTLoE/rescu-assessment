import 'package:flutter_test/flutter_test.dart';
import 'package:rescu/model/pickup_window_model.dart';

/// Builds a window the way the API sends it (ISO-8601 UTC strings), starting
/// from wall-clock times in the test machine's own time zone. That way the
/// expected local answer is the same whatever zone the tests run in.
///
/// All dates are in January so no daylight-saving change can shift them.
PickupWindowModel windowFromLocal(DateTime localStart, DateTime localEnd) {
  return PickupWindowModel.fromJson({
    'start': localStart.toUtc().toIso8601String(),
    'end': localEnd.toUtc().toIso8601String(),
  });
}

void main() {
  test('label shows the window in local time, not UTC', () {
    final window = windowFromLocal(
      DateTime(2026, 1, 15, 6, 0),
      DateTime(2026, 1, 15, 9, 30),
    );

    expect(window.start.isUtc, isTrue);
    expect(window.label, '06:00 – 09:30');
  });

  test('isTodayAt is true for an early-morning start on the same local day',
      () {
    final window = windowFromLocal(
      DateTime(2026, 1, 15, 0, 30),
      DateTime(2026, 1, 15, 3, 0),
    );

    expect(window.isTodayAt(DateTime(2026, 1, 15, 12, 0)), isTrue);
  });

  test('isTodayAt is false when the window starts tomorrow in local time', () {
    final window = windowFromLocal(
      DateTime(2026, 1, 16, 6, 0),
      DateTime(2026, 1, 16, 9, 30),
    );

    expect(window.isTodayAt(DateTime(2026, 1, 15, 23, 30)), isFalse);
  });

  test('isTodayAt is false for the same day number in another month', () {
    final window = windowFromLocal(
      DateTime(2026, 1, 15, 12, 0),
      DateTime(2026, 1, 15, 14, 0),
    );

    expect(window.isTodayAt(DateTime(2026, 2, 15, 12, 0)), isFalse);
  });
}
