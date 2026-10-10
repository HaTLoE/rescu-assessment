import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:rescu/feature/deal/deal_details_controller.dart';
import 'package:rescu/model/deal_model.dart';
import 'package:rescu/model/pickup_window_model.dart';
import 'package:rescu/repository/deal_repo.dart';
import 'package:rescu/service/analytics_service.dart';
import 'package:rescu/service/cart_service.dart';
import 'package:rescu/service/fake_api_service.dart';

/// Records every `GET /deals/:id` and answers only when the test says so.
///
/// The [FakeApiService] is never used: it is only there because [DealRepo]
/// requires one. Its assets are loaded in `init()`, which is never called.
class FakeDealRepo extends DealRepo {
  FakeDealRepo() : super(api: FakeApiService());

  final fetchedIds = <int>[];
  final _pending = <int, Completer<DealModel>>{};

  @override
  Future<DealModel> fetchById(int id) {
    fetchedIds.add(id);
    final completer = Completer<DealModel>();
    _pending[id] = completer;
    return completer.future;
  }

  void answer(DealModel deal) => _pending[deal.id]!.complete(deal);
}

DealModel deal(int id, {int quantityLeft = 5}) {
  return DealModel(
    id: id,
    name: 'Deal $id',
    description: '',
    imageUrl: '',
    originalPrice: 100,
    price: 50,
    currencyCode: 'THB',
    quantityLeft: quantityLeft,
    storeId: 1,
    storeName: 'Store',
    storeAddress: '',
    lat: 0,
    lng: 0,
    rating: null,
    tags: const [],
    pickupWindow: PickupWindowModel(
      start: DateTime.utc(2026, 1, 15, 10),
      end: DateTime.utc(2026, 1, 15, 12),
    ),
    flashSaleEndsAt: null,
  );
}

void main() {
  late FakeDealRepo repo;
  late CartService cart;
  late AnalyticsService analytics;

  /// Opens a deal page the way GetX does: the deal arrives as the route
  /// argument and Get.put runs the controller's onInit.
  DealDetailsController open(DealModel deal) {
    Get.routing.args = deal;
    return Get.put(DealDetailsController(
      dealRepo: repo,
      cartService: cart,
      analytics: analytics,
    ));
  }

  /// Closes the page the way GetX does when the route is popped: Get.delete
  /// runs the controller's onClose.
  Future<void> close() => Get.delete<DealDetailsController>();

  setUp(() {
    repo = FakeDealRepo();
    cart = CartService();
    analytics = AnalyticsService();
  });

  tearDown(Get.reset);

  test('closed deal pages stop re-checking when the cart changes', () async {
    open(deal(1));
    await close();
    open(deal(2));
    await close();
    open(deal(3));

    cart.add(deal(3));
    await pumpEventQueue();

    expect(repo.fetchedIds, [3]);
  });

  test('the open deal page still re-checks and shows the fresh quantity',
      () async {
    final controller = open(deal(1, quantityLeft: 5));

    cart.add(deal(1));
    await pumpEventQueue();
    expect(repo.fetchedIds, [1]);

    repo.answer(deal(1, quantityLeft: 1));
    await pumpEventQueue();

    expect(controller.quantityLeft, 1);
  });

  test('an answer that arrives after the page is closed is ignored', () async {
    final controller = open(deal(1, quantityLeft: 5));

    cart.add(deal(1));
    await pumpEventQueue();
    await close();

    repo.answer(deal(1, quantityLeft: 0));
    await pumpEventQueue();

    expect(controller.quantityLeft, 5);
  });
}
