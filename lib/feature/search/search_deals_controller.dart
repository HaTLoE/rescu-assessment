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

  void onQueryChanged(String query) {
    _search(query);
  }

  Future<void> _search(String query) async {
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
}
