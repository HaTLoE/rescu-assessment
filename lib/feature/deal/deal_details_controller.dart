import 'package:get/get.dart';

import '../../model/deal_model.dart';
import '../../repository/deal_repo.dart';
import '../../service/analytics_service.dart';
import '../../service/api_exception.dart';
import '../../service/cart_service.dart';
import '../../util/log_service.dart';

class DealDetailsController extends GetxController {
  final DealRepo dealRepo;
  final CartService cartService;
  final AnalyticsService analytics;

  DealDetailsController({
    required this.dealRepo,
    required this.cartService,
    required this.analytics,
  });

  /// The deal on screen. Null while it is loading, or if it could not load.
  final deal = Rxn<DealModel>();
  final isLoading = false.obs;

  /// Message for the user when the deal cannot be shown.
  final errorMessage = RxnString();

  /// Deal id from the route (`/deal?id=42`). Null when the link has no
  /// usable id. A deep link carries only this id, never a [DealModel].
  int? _dealId;

  /// Whether trying again makes sense (there is an id to fetch).
  bool get canRetry => _dealId != null;

  final _quantityLeft = RxnInt();
  int? get quantityLeft => _quantityLeft.value;

  /// Subscription to the cart. The cart service lives for the whole session,
  /// so this controller must end the subscription itself in [onClose].
  late final Worker _cartWorker;

  @override
  void onInit() {
    super.onInit();
    _dealId = int.tryParse(Get.parameters['id'] ?? '');
    // A deal passed from a card is only a shortcut that saves a request. It
    // is used when it matches the id in the route (or the route has no id).
    final preloaded = Get.arguments;
    if (preloaded is DealModel &&
        (_dealId == null || preloaded.id == _dealId)) {
      _dealId = preloaded.id;
      _showDeal(preloaded);
    } else if (_dealId != null) {
      loadDeal();
    } else {
      errorMessage.value = 'This link is not valid.';
    }
    if (_dealId != null) {
      analytics.logEvent('deal_details_view', {
        'deal_id': _dealId,
        'source': Get.parameters['source'] ?? 'unknown',
      });
    }
    // Whenever the cart changes, re-check this deal's remaining stock so the
    // details screen never shows stale availability.
    _cartWorker = ever(cartService.itemCount, (_) => _recheckAvailability());
  }

  void _showDeal(DealModel loaded) {
    deal.value = loaded;
    _quantityLeft.value = loaded.quantityLeft;
  }

  /// Fetches the deal by the id from the route. Also used by "Try again".
  Future<void> loadDeal() async {
    final id = _dealId;
    if (id == null || isLoading.value) return;
    isLoading.value = true;
    errorMessage.value = null;
    try {
      final fetched = await dealRepo.fetchById(id);
      // The page may have been closed while the request was in flight.
      if (isClosed) return;
      _showDeal(fetched);
    } on ApiException catch (e) {
      LogService.error('load deal $id failed', e);
      if (isClosed) return;
      errorMessage.value = e.statusCode == 404
          ? 'This deal is no longer available.'
          : 'Could not load this deal.';
    }
    isLoading.value = false;
  }

  Future<void> _recheckAvailability() async {
    final current = deal.value;
    // Nothing to re-check until the deal itself has loaded.
    if (current == null) return;
    LogService.log('re-checking availability for deal ${current.id}');
    final fresh = await dealRepo.fetchById(current.id);
    // The page may have been closed while the request was in flight.
    if (isClosed) return;
    _quantityLeft.value = fresh.quantityLeft;
  }

  @override
  void onClose() {
    _cartWorker.dispose();
    super.onClose();
  }

  void addToCart() {
    final current = deal.value;
    if (current == null) return;
    cartService.add(current);
    Get.snackbar(
      'Added to bag',
      '${current.name} — pick up ${current.pickupWindow.label}',
      snackPosition: SnackPosition.BOTTOM,
      duration: const Duration(seconds: 2),
    );
  }
}
