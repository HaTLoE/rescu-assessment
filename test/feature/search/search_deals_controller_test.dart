import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:rescu/feature/search/search_deals_controller.dart';
import 'package:rescu/model/deal_model.dart';
import 'package:rescu/model/pickup_window_model.dart';
import 'package:rescu/repository/deal_repo.dart';
import 'package:rescu/service/fake_api_service.dart';

/// A repo whose searches finish only when the test says so. This lets a test
/// make an OLDER request finish AFTER a newer one, with no real delays.
///
/// The [FakeApiService] is never used: it is only there because [DealRepo]
/// requires one. Its assets are loaded in `init()`, which is never called.
class FakeDealRepo extends DealRepo {
  FakeDealRepo() : super(api: FakeApiService());

  final _pending = <String, Completer<List<DealModel>>>{};

  @override
  Future<List<DealModel>> search(String query) {
    final completer = Completer<List<DealModel>>();
    _pending[query] = completer;
    return completer.future;
  }

  void succeed(String query, List<DealModel> deals) =>
      _pending[query]!.complete(deals);

  void fail(String query) =>
      _pending[query]!.completeError(Exception('search exploded'));
}

DealModel deal(int id) {
  return DealModel(
    id: id,
    name: 'Deal $id',
    description: '',
    imageUrl: '',
    originalPrice: 100,
    price: 50,
    currencyCode: 'THB',
    quantityLeft: 1,
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
  late SearchDealsController controller;

  List<int> resultIds() => controller.results.map((d) => d.id).toList();

  setUp(() {
    repo = FakeDealRepo();
    controller = SearchDealsController(dealRepo: repo);
  });

  test('an older response that arrives late does not overwrite newer results',
      () async {
    controller.onQueryChanged('s');
    controller.onQueryChanged('sushi');

    repo.succeed('sushi', [deal(1)]);
    await pumpEventQueue();
    expect(resultIds(), [1]);

    repo.succeed('s', [deal(2), deal(3)]);
    await pumpEventQueue();

    expect(resultIds(), [1]);
    expect(controller.isLoading.value, isFalse);
  });

  test('stays loading until the newest request finishes', () async {
    controller.onQueryChanged('s');
    controller.onQueryChanged('sushi');

    repo.succeed('s', [deal(2), deal(3)]);
    await pumpEventQueue();

    expect(controller.isLoading.value, isTrue);
    expect(resultIds(), isEmpty);
  });

  test('clearing the query ignores a request that is still in flight',
      () async {
    controller.onQueryChanged('s');
    controller.onQueryChanged('');

    expect(controller.isLoading.value, isFalse);

    repo.succeed('s', [deal(2)]);
    await pumpEventQueue();

    expect(resultIds(), isEmpty);
    expect(controller.hasSearched.value, isFalse);
    expect(controller.isLoading.value, isFalse);
  });

  test('when the newest request fails it shows an error and no old results',
      () async {
    controller.onQueryChanged('s');
    repo.succeed('s', [deal(2)]);
    await pumpEventQueue();
    expect(resultIds(), [2]);

    controller.onQueryChanged('sushi');
    repo.fail('sushi');
    await pumpEventQueue();

    expect(controller.hasError.value, isTrue);
    expect(resultIds(), isEmpty);
    expect(controller.isLoading.value, isFalse);
  });

  test('an older request that fails late does not touch newer results',
      () async {
    controller.onQueryChanged('s');
    controller.onQueryChanged('sushi');

    repo.succeed('sushi', [deal(1)]);
    await pumpEventQueue();

    repo.fail('s');
    await pumpEventQueue();

    expect(resultIds(), [1]);
    expect(controller.hasError.value, isFalse);
    expect(controller.isLoading.value, isFalse);
  });
}
