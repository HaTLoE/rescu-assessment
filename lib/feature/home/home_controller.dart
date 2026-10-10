import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:pull_to_refresh/pull_to_refresh.dart';

import '../../model/deal_model.dart';
import '../../repository/deal_repo.dart';
import '../../service/api_exception.dart';
import '../../util/log_service.dart';

class HomeController extends GetxController {
  final DealRepo dealRepo;

  HomeController({required this.dealRepo});

  final deals = <DealModel>[].obs;
  final flashDeals = <DealModel>[].obs;
  final isLoading = true.obs;
  final todayOnly = false.obs;
  final scrollOffset = 0.0.obs;

  final scrollController = ScrollController();
  final refreshController = RefreshController();

  int _page = 1;
  int _totalPages = 1;
  bool _isFetchingMore = false;

  /// Goes up each time a refresh replaces the list. A loadMore response that
  /// was requested for an older list must not be added to the new one.
  int _generation = 0;

  bool get hasMore => _page < _totalPages;

  List<DealModel> get visibleDeals => todayOnly.value
      ? deals.where((d) => d.pickupWindow.isToday).toList()
      : deals.toList();

  @override
  void onInit() {
    super.onInit();
    scrollController.addListener(_onScroll);
    _initialLoad();
  }

  void _onScroll() {
    scrollOffset.value = scrollController.offset;
  }

  Future<void> _initialLoad() async {
    isLoading.value = true;
    try {
      await Future.wait([refreshDeals(), _loadFlashDeals()]);
    } catch (e) {
      LogService.error('initial load failed', e);
    }
    isLoading.value = false;
  }

  Future<void> _loadFlashDeals() async {
    flashDeals.assignAll(await dealRepo.fetchFlashDeals());
  }

  Future<void> refreshDeals() async {
    try {
      final res = await dealRepo.fetchDeals(page: 1);
      // The page number, the page count and the list change together, and
      // only once the response is here, so they can never disagree.
      _generation++;
      _page = 1;
      _totalPages = res.totalPages;
      deals.assignAll(res.items);
      // The list is back to page 1, so a footer stuck on "no more data" must
      // be allowed to load again.
      refreshController.refreshCompleted(resetFooterState: true);
    } on ApiException catch (e) {
      // Nothing was changed above, so the old list and page stay valid.
      LogService.error('refresh failed', e);
      refreshController.refreshFailed();
    }
  }

  Future<void> loadMore() async {
    if (_isFetchingMore) return;
    if (!hasMore) {
      refreshController.loadNoData();
      return;
    }
    final generation = _generation;
    final nextPage = _page + 1;
    _isFetchingMore = true;
    try {
      final res = await dealRepo.fetchDeals(page: nextPage);
      // A refresh may have replaced the list while this page was in flight.
      // Then this page belongs to the old list and is dropped.
      if (generation == _generation) {
        _page = nextPage;
        _totalPages = res.totalPages;
        deals.addAll(res.items);
      }
      refreshController.loadComplete();
    } on ApiException catch (e) {
      LogService.error('loadMore failed', e);
      refreshController.loadFailed();
    } finally {
      _isFetchingMore = false;
    }
  }

  void scrollToTop() {
    scrollController.animateTo(0,
        duration: const Duration(milliseconds: 400), curve: Curves.easeOut);
  }

  @override
  void onClose() {
    scrollController.dispose();
    refreshController.dispose();
    super.onClose();
  }
}
