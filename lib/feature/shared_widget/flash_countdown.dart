import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../service/clock_service.dart';
import '../../util/countdown_format.dart';

/// Live time left until a flash sale ends, e.g. "09:59" or "01:15:00".
///
/// Only this widget's [Text] rebuilds each second: it is the only thing that
/// reads the shared clock. The card or screen around it is not rebuilt.
class FlashCountdown extends StatelessWidget {
  final DateTime endsAt;
  final TextStyle? style;

  const FlashCountdown({super.key, required this.endsAt, this.style});

  @override
  Widget build(BuildContext context) {
    final clock = Get.find<ClockService>();
    // Every digit gets the same width, so the text does not jiggle as the
    // numbers change.
    final textStyle = (style ?? const TextStyle()).copyWith(
      fontFeatures: const [FontFeature.tabularFigures()],
    );
    return Obx(() => Text(
          formatCountdown(endsAt.difference(clock.now.value)),
          style: textStyle,
        ));
  }
}
