import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../model/deal_model.dart';
import '../../service/clock_service.dart';

/// Rebuilds its child exactly once: at the moment [deal]'s flash sale ends.
///
/// A card must change when its sale ends (greyed out, tap disabled), but it
/// must NOT rebuild every second like the countdown text does. So this widget
/// listens to the shared clock itself and calls `setState` only when the
/// "expired" answer flips from false to true.
///
/// For a deal that is not a flash sale it does nothing: no listener, and
/// `isExpired` is always false.
class FlashExpiryBuilder extends StatefulWidget {
  final DealModel deal;
  final Widget Function(BuildContext context, bool isExpired) builder;

  const FlashExpiryBuilder({
    super.key,
    required this.deal,
    required this.builder,
  });

  @override
  State<FlashExpiryBuilder> createState() => _FlashExpiryBuilderState();
}

class _FlashExpiryBuilderState extends State<FlashExpiryBuilder> {
  bool _isExpired = false;

  /// Listener on the shared clock. The clock lives for the whole app, so this
  /// State must end the listener itself in [dispose].
  Worker? _clockWorker;

  @override
  void initState() {
    super.initState();
    _watch();
  }

  @override
  void didUpdateWidget(FlashExpiryBuilder oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.deal.flashSaleEndsAt != widget.deal.flashSaleEndsAt) {
      _stopWatching();
      _watch();
    }
  }

  void _watch() {
    final deal = widget.deal;
    if (!deal.isFlashSale) {
      _isExpired = false;
      return;
    }
    final clock = Get.find<ClockService>();
    _isExpired = deal.isFlashExpiredAt(clock.now.value);
    if (_isExpired) return;
    _clockWorker = ever(clock.now, (now) {
      if (!deal.isFlashExpiredAt(now)) return;
      // Nothing more can change after expiry, so stop listening.
      _stopWatching();
      setState(() => _isExpired = true);
    });
  }

  void _stopWatching() {
    _clockWorker?.dispose();
    _clockWorker = null;
  }

  @override
  void dispose() {
    _stopWatching();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.builder(context, _isExpired);
}
