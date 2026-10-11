import 'package:get/get.dart';

import '../model/cart_item_model.dart';
import '../model/deal_model.dart';
import '../util/log_service.dart';
import 'clock_service.dart';

/// App-wide cart. Lives for the whole session.
///
/// NOTE: the starter cart is purely local — it does not reserve stock on the
/// backend. See the "Reservations" feature task in PROBLEM.md.
class CartService extends GetxService {
  /// The app's shared clock, used to tell whether a flash sale is over.
  final ClockService clock;

  /// Called once for each deal that is removed from the bag because its
  /// flash sale ended. The app passes a function that shows a notice; the
  /// cart itself knows nothing about the screen, so it stays testable.
  final void Function(DealModel deal)? onFlashSaleExpired;

  CartService({required this.clock, this.onFlashSaleExpired});

  final items = <CartItemModel>[].obs;
  final itemCount = 0.obs;

  /// Listener on the shared clock, ended in [onClose].
  Worker? _clockWorker;

  @override
  void onInit() {
    super.onInit();
    // The cart lives for the whole app, so this runs on every clock tick
    // whichever screen is open — the bag screen does not have to be.
    _clockWorker = ever(clock.now, _removeExpiredFlashDeals);
  }

  @override
  void onClose() {
    _clockWorker?.dispose();
    super.onClose();
  }

  /// Takes every line whose flash sale is over at [now] out of the bag.
  void _removeExpiredFlashDeals(DateTime now) {
    final expired = [
      for (final item in items)
        if (item.deal.isFlashExpiredAt(now)) item.deal,
    ];
    if (expired.isEmpty) return;

    items.removeWhere((i) => i.deal.isFlashExpiredAt(now));
    _recount();
    for (final deal in expired) {
      LogService.log('cart: removed deal ${deal.id}, its flash sale ended');
      onFlashSaleExpired?.call(deal);
    }
  }

  /// Adds one of [deal] to the bag. Returns true if it was added, and false
  /// if it was refused: the flash sale is over, or the bag already holds all
  /// that are left.
  ///
  /// Every "add to bag" in the app goes through here, so this is the one
  /// place that stops an expired flash deal from being bought.
  bool add(DealModel deal) {
    if (deal.isFlashExpiredAt(clock.now.value)) {
      LogService.log('cart: flash sale is over for deal ${deal.id}');
      return false;
    }
    final existing = items.firstWhereOrNull((i) => i.deal.id == deal.id);
    if (existing != null) {
      if (existing.quantity >= deal.quantityLeft) {
        LogService.log('cart: cannot add more of deal ${deal.id}');
        return false;
      }
      existing.quantity++;
      items.refresh();
    } else {
      items.add(CartItemModel(deal: deal));
    }
    _recount();
    return true;
  }

  void decrement(int dealId) {
    final existing = items.firstWhereOrNull((i) => i.deal.id == dealId);
    if (existing == null) return;
    existing.quantity--;
    if (existing.quantity <= 0) {
      items.removeWhere((i) => i.deal.id == dealId);
    } else {
      items.refresh();
    }
    _recount();
  }

  void remove(int dealId) {
    items.removeWhere((i) => i.deal.id == dealId);
    _recount();
  }

  void clear() {
    items.clear();
    _recount();
  }

  num get total => items.fold(0, (sum, i) => sum + i.lineTotal);

  void _recount() {
    itemCount.value = items.fold(0, (sum, i) => sum + i.quantity);
  }
}
