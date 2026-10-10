import 'dart:async';

import 'package:get/get.dart';

import '../../model/deal_model.dart';
import '../../repository/deal_repo.dart';
import '../../util/log_service.dart';

class SearchDealsController extends GetxController {
  final DealRepo dealRepo;

  SearchDealsController({required this.dealRepo});

  final results = <DealModel>[].obs;
  final isLoading = false.obs;
  final hasSearched = false.obs;
  final hasError = false.obs;

  /// Number of the newest search. Responses can come back out of order, so
  /// only the request holding this number is allowed to update the state.
  int _latestRequestId = 0;

  /// How long the user must stop typing before a search is sent.
  static const debounceDelay = Duration(milliseconds: 300);

  Timer? _debounce;

  void onQueryChanged(String query) {
    _debounce?.cancel();
    // Taken at the keystroke, not when the request is sent, so anything
    // still in flight is stale as soon as the text changes.
    final requestId = ++_latestRequestId;
    if (query.trim().isEmpty) {
      results.clear();
      hasSearched.value = false;
      hasError.value = false;
      isLoading.value = false;
      return;
    }
    isLoading.value = true;
    hasSearched.value = true;
    hasError.value = false;
    _debounce = Timer(debounceDelay, () => _search(query, requestId));
  }

  Future<void> _search(String query, int requestId) async {
    try {
      final found = await dealRepo.search(query);
      if (requestId != _latestRequestId) return;
      results.assignAll(found);
    } catch (e) {
      LogService.error('search failed', e);
      if (requestId != _latestRequestId) return;
      results.clear();
      hasError.value = true;
    }
    isLoading.value = false;
  }

  @override
  void onClose() {
    _debounce?.cancel();
    // Makes a request that is still in flight stale, so its response is
    // ignored after the screen is gone.
    _latestRequestId++;
    super.onClose();
  }
}
