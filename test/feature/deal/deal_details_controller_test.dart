import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:rescu/feature/deal/deal_details_controller.dart';
import 'package:rescu/model/deal_model.dart';
import 'package:rescu/model/pickup_window_model.dart';
import 'package:rescu/repository/deal_repo.dart';
import 'package:rescu/service/analytics_service.dart';
import 'package:rescu/service/api_exception.dart';
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

  void fail(int id, ApiException error) => _pending[id]!.completeError(error);
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

  /// Opens a deal page the way GetX does for a route like
  /// `/deal?id=42&source=push`: the query ends up in Get.parameters, the
  /// optional [preloaded] deal in Get.arguments, and Get.put runs onInit.
  DealDetailsController openLink(
    Map<String, String?> params, {
    DealModel? preloaded,
  }) {
    Get.parameters = params;
    Get.routing.args = preloaded;
    return Get.put(DealDetailsController(
      dealRepo: repo,
      cartService: cart,
      analytics: analytics,
    ));
  }

  /// Opens a deal page the way a tap on a deal card does: id in the route and
  /// the whole deal passed along as the argument.
  DealDetailsController open(DealModel deal) {
    return openLink({'id': '${deal.id}', 'source': 'home'}, preloaded: deal);
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

  test('a deep link with only an id opens the deal by fetching it', () async {
    final controller = openLink({'id': '42', 'source': 'push'});

    expect(repo.fetchedIds, [42]);
    expect(controller.isLoading.value, isTrue);
    expect(controller.deal.value, isNull);

    repo.answer(deal(42, quantityLeft: 3));
    await pumpEventQueue();

    expect(controller.deal.value?.id, 42);
    expect(controller.quantityLeft, 3);
    expect(controller.isLoading.value, isFalse);
    expect(controller.errorMessage.value, isNull);
  });

  test('a deal passed from a card is shown at once without a request', () {
    final controller = open(deal(7, quantityLeft: 4));

    expect(controller.deal.value?.id, 7);
    expect(controller.quantityLeft, 4);
    expect(controller.isLoading.value, isFalse);
    expect(repo.fetchedIds, isEmpty);
  });

  test('a link with no id shows "not valid" and sends no request', () {
    final controller = openLink({'source': 'push'});

    expect(controller.errorMessage.value, 'This link is not valid.');
    expect(controller.canRetry, isFalse);
    expect(controller.isLoading.value, isFalse);
    expect(repo.fetchedIds, isEmpty);
  });

  test('a link with a malformed id shows "not valid" and sends no request', () {
    final controller = openLink({'id': 'abc', 'source': 'push'});

    expect(controller.errorMessage.value, 'This link is not valid.');
    expect(controller.canRetry, isFalse);
    expect(repo.fetchedIds, isEmpty);
  });

  test('a deal that does not exist shows "no longer available"', () async {
    final controller = openLink({'id': '999'});

    repo.fail(999, const ApiException('Deal not found', statusCode: 404));
    await pumpEventQueue();

    expect(controller.errorMessage.value, 'This deal is no longer available.');
    expect(controller.deal.value, isNull);
    expect(controller.isLoading.value, isFalse);
  });

  test('trying again after a failed load fetches once more and recovers',
      () async {
    final controller = openLink({'id': '42'});
    repo.fail(42, const ApiException('Server error'));
    await pumpEventQueue();
    expect(controller.errorMessage.value, 'Could not load this deal.');
    expect(controller.canRetry, isTrue);

    controller.loadDeal();

    expect(repo.fetchedIds, [42, 42]);
    expect(controller.isLoading.value, isTrue);
    expect(controller.errorMessage.value, isNull);

    repo.answer(deal(42));
    await pumpEventQueue();

    expect(controller.deal.value?.id, 42);
    expect(controller.isLoading.value, isFalse);
  });

  test('loading again while a load is in flight sends no second request', () {
    final controller = openLink({'id': '42'});

    controller.loadDeal();
    controller.loadDeal();

    expect(repo.fetchedIds, [42]);
  });

  test('a cart change while the deal is still loading sends no re-check',
      () async {
    openLink({'id': '42'});

    cart.add(deal(1));
    await pumpEventQueue();

    expect(repo.fetchedIds, [42]);
  });

  test('a deal that arrives after the page is closed is ignored', () async {
    final controller = openLink({'id': '42'});
    await close();

    repo.answer(deal(42));
    await pumpEventQueue();

    expect(controller.deal.value, isNull);
  });

  test('a passed deal with a different id than the route is not trusted',
      () async {
    final controller = openLink({'id': '42'}, preloaded: deal(7));

    expect(repo.fetchedIds, [42]);
    expect(controller.deal.value, isNull);

    repo.answer(deal(42));
    await pumpEventQueue();

    expect(controller.deal.value?.id, 42);
  });

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
