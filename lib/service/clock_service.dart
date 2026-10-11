import 'dart:async';

import 'package:get/get.dart';

/// The app's one shared clock. It updates [now] once per second.
///
/// Anything that changes with time (flash-sale countdowns, expiry) reads
/// [now] instead of starting its own timer, so the whole app runs on a single
/// timer however many countdowns are on screen.
///
/// Time left is always worked out as "end time minus [now]". Nothing counts
/// down by subtracting one, so a late tick cannot make a countdown drift.
class ClockService extends GetxService {
  /// [readClock] is how the service reads the time. Tests pass a fake clock;
  /// the app uses the real one.
  ClockService({DateTime Function()? readClock})
      : _readClock = readClock ?? DateTime.now;

  final DateTime Function() _readClock;

  /// The current time, refreshed once per second.
  late final Rx<DateTime> now = _readClock().obs;

  Timer? _timer;

  @override
  void onInit() {
    super.onInit();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      now.value = _readClock();
    });
  }

  @override
  void onClose() {
    _timer?.cancel();
    super.onClose();
  }
}
