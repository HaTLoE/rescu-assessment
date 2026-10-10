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

  /// Every search that was actually sent, in order.
  final queries = <String>[];

  @override
  Future<List<DealModel>> search(String query) {
    queries.add(query);
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

  // These tests use testWidgets only for its fake clock: time moves only when
  // the test calls tester.pump(duration). No widget is built.
  //
  // pump(debounce) lets the debounce timer fire, so the request is "sent".
  // pump() with no duration only lets a finished request's code run.
  const debounce = Duration(milliseconds: 300);

  testWidgets(
      'an older response that arrives late does not overwrite newer results',
      (tester) async {
    controller.onQueryChanged('s');
    await tester.pump(debounce);
    controller.onQueryChanged('sushi');
    await tester.pump(debounce);

    repo.succeed('sushi', [deal(1)]);
    await tester.pump();
    expect(resultIds(), [1]);

    repo.succeed('s', [deal(2), deal(3)]);
    await tester.pump();

    expect(resultIds(), [1]);
    expect(controller.isLoading.value, isFalse);
  });

  testWidgets('stays loading until the newest request finishes',
      (tester) async {
    controller.onQueryChanged('s');
    await tester.pump(debounce);
    controller.onQueryChanged('sushi');
    await tester.pump(debounce);

    repo.succeed('s', [deal(2), deal(3)]);
    await tester.pump();

    expect(controller.isLoading.value, isTrue);
    expect(resultIds(), isEmpty);
  });

  testWidgets('clearing the query ignores a request that is still in flight',
      (tester) async {
    controller.onQueryChanged('s');
    await tester.pump(debounce);
    controller.onQueryChanged('');

    expect(controller.isLoading.value, isFalse);

    repo.succeed('s', [deal(2)]);
    await tester.pump();

    expect(resultIds(), isEmpty);
    expect(controller.hasSearched.value, isFalse);
    expect(controller.isLoading.value, isFalse);
  });

  testWidgets(
      'when the newest request fails it shows an error and no old results',
      (tester) async {
    controller.onQueryChanged('s');
    await tester.pump(debounce);
    repo.succeed('s', [deal(2)]);
    await tester.pump();
    expect(resultIds(), [2]);

    controller.onQueryChanged('sushi');
    await tester.pump(debounce);
    repo.fail('sushi');
    await tester.pump();

    expect(controller.hasError.value, isTrue);
    expect(resultIds(), isEmpty);
    expect(controller.isLoading.value, isFalse);
  });

  testWidgets('an older request that fails late does not touch newer results',
      (tester) async {
    controller.onQueryChanged('s');
    await tester.pump(debounce);
    controller.onQueryChanged('sushi');
    await tester.pump(debounce);

    repo.succeed('sushi', [deal(1)]);
    await tester.pump();

    repo.fail('s');
    await tester.pump();

    expect(resultIds(), [1]);
    expect(controller.hasError.value, isFalse);
    expect(controller.isLoading.value, isFalse);
  });

  testWidgets('fast typing sends a single request for the final text',
      (tester) async {
    for (final query in ['s', 'su', 'sus', 'sush', 'sushi']) {
      controller.onQueryChanged(query);
      await tester.pump(const Duration(milliseconds: 100));
    }

    // 100 ms have passed since the last keystroke.
    await tester.pump(const Duration(milliseconds: 199));
    expect(repo.queries, isEmpty);

    await tester.pump(const Duration(milliseconds: 1));
    expect(repo.queries, ['sushi']);
  });

  testWidgets('onClose cancels a search that is still waiting to be sent',
      (tester) async {
    controller.onQueryChanged('s');
    controller.onClose();

    await tester.pump(const Duration(seconds: 1));

    expect(repo.queries, isEmpty);
  });

  testWidgets('clearing the query is immediate and cancels the waiting search',
      (tester) async {
    controller.onQueryChanged('s');
    await tester.pump(const Duration(milliseconds: 100));
    controller.onQueryChanged('');

    expect(controller.isLoading.value, isFalse);
    expect(controller.hasSearched.value, isFalse);

    await tester.pump(const Duration(seconds: 1));

    expect(repo.queries, isEmpty);
  });

  testWidgets(
      'a response that arrives while newer text is waiting to be sent is ignored',
      (tester) async {
    controller.onQueryChanged('su');
    await tester.pump(debounce);
    controller.onQueryChanged('sushi');

    repo.succeed('su', [deal(2)]);
    await tester.pump();

    expect(controller.isLoading.value, isTrue);
    expect(resultIds(), isEmpty);

    await tester.pump(debounce);
  });

  testWidgets('a response that arrives after onClose is ignored',
      (tester) async {
    controller.onQueryChanged('sushi');
    await tester.pump(debounce);
    controller.onClose();

    repo.succeed('sushi', [deal(1)]);
    await tester.pump();

    expect(resultIds(), isEmpty);
  });
}
