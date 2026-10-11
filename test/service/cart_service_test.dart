import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:rescu/model/deal_model.dart';
import 'package:rescu/model/pickup_window_model.dart';
import 'package:rescu/service/cart_service.dart';
import 'package:rescu/service/clock_service.dart';

DealModel deal(int id, {int quantityLeft = 5, DateTime? flashSaleEndsAt}) {
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
    flashSaleEndsAt: flashSaleEndsAt,
  );
}

void main() {
  final noon = DateTime.utc(2026, 1, 15, 12);
  late ClockService clock;
  late CartService cart;

  setUp(() {
    // The clock is not started (no timer). Each test sets the time it needs
    // by writing clock.now.value directly.
    clock = ClockService(readClock: () => noon);
    cart = CartService(clock: clock);
  });

  test('adding a normal deal succeeds and returns true', () {
    expect(cart.add(deal(1)), isTrue);
    expect(cart.itemCount.value, 1);
  });

  test('adding a flash deal that is still running succeeds', () {
    final running = deal(
      1,
      flashSaleEndsAt: noon.add(const Duration(seconds: 1)),
    );

    expect(cart.add(running), isTrue);
    expect(cart.itemCount.value, 1);
  });

  test('adding a flash deal whose sale is over is refused', () {
    final expired = deal(
      1,
      flashSaleEndsAt: noon.subtract(const Duration(seconds: 1)),
    );

    expect(cart.add(expired), isFalse);
    expect(cart.items, isEmpty);
    expect(cart.itemCount.value, 0);
  });

  test('a flash deal is refused from the end time itself', () {
    final endingNow = deal(1, flashSaleEndsAt: noon);

    expect(cart.add(endingNow), isFalse);
    expect(cart.items, isEmpty);
  });

  test('a deal that was addable is refused once the clock passes its end', () {
    final flash = deal(
      1,
      flashSaleEndsAt: noon.add(const Duration(minutes: 5)),
    );
    expect(cart.add(flash), isTrue);

    clock.now.value = noon.add(const Duration(minutes: 5));

    expect(cart.add(flash), isFalse);
    expect(cart.itemCount.value, 1);
  });

  test('adding more than are left is refused and returns false', () {
    final lastOne = deal(1, quantityLeft: 1);
    expect(cart.add(lastOne), isTrue);

    expect(cart.add(lastOne), isFalse);
    expect(cart.itemCount.value, 1);
  });

  group('a flash sale that ends while the deal is in the bag', () {
    final endsAt = noon.add(const Duration(minutes: 5));

    setUp(() {
      // Get.put runs the service's onInit, like the app does at start-up.
      // A clock tick is simulated by writing clock.now.value.
      Get.put(cart);
    });

    tearDown(Get.reset);

    test('the expired line is removed from the bag', () {
      cart.add(deal(1, flashSaleEndsAt: endsAt));
      cart.add(deal(1, flashSaleEndsAt: endsAt));
      expect(cart.itemCount.value, 2);

      clock.now.value = endsAt;

      expect(cart.items, isEmpty);
      expect(cart.itemCount.value, 0);
    });

    test('other lines stay in the bag', () {
      cart.add(deal(1, flashSaleEndsAt: endsAt));
      cart.add(deal(2));
      cart.add(deal(3, flashSaleEndsAt: endsAt.add(const Duration(hours: 1))));

      clock.now.value = endsAt;

      expect(cart.items.map((i) => i.deal.id), [2, 3]);
      expect(cart.itemCount.value, 2);
    });

    test('nothing is removed before the end time', () {
      cart.add(deal(1, flashSaleEndsAt: endsAt));

      clock.now.value = endsAt.subtract(const Duration(seconds: 1));

      expect(cart.itemCount.value, 1);
    });
  });

  group('the notice for a removed flash deal', () {
    final endsAt = noon.add(const Duration(minutes: 5));
    late List<int> noticedIds;
    late CartService noticingCart;

    setUp(() {
      noticedIds = [];
      noticingCart = Get.put(CartService(
        clock: clock,
        onFlashSaleExpired: (deal) => noticedIds.add(deal.id),
      ));
    });

    tearDown(Get.reset);

    test('is given once per removed deal, however many of it were in the bag',
        () {
      final flash = deal(1, flashSaleEndsAt: endsAt);
      noticingCart.add(flash);
      noticingCart.add(flash);
      noticingCart.add(flash);

      clock.now.value = endsAt;

      expect(noticedIds, [1]);
    });

    test('is not repeated on later ticks', () {
      noticingCart.add(deal(1, flashSaleEndsAt: endsAt));

      clock.now.value = endsAt;
      clock.now.value = endsAt.add(const Duration(seconds: 1));
      clock.now.value = endsAt.add(const Duration(seconds: 2));

      expect(noticedIds, [1]);
    });

    test('is given for each deal when two sales end on the same tick', () {
      noticingCart.add(deal(1, flashSaleEndsAt: endsAt));
      noticingCart.add(deal(2, flashSaleEndsAt: endsAt));
      noticingCart.add(deal(3));

      clock.now.value = endsAt;

      expect(noticedIds, [1, 2]);
      expect(noticingCart.items.map((i) => i.deal.id), [3]);
    });

    test('is not given when nothing in the bag has expired', () {
      noticingCart.add(deal(1));
      noticingCart.add(deal(2, flashSaleEndsAt: endsAt));

      clock.now.value = endsAt.subtract(const Duration(minutes: 1));

      expect(noticedIds, isEmpty);
    });

    test('stops after the service is closed', () async {
      noticingCart.add(deal(1, flashSaleEndsAt: endsAt));

      // `force` is needed: GetX does not delete a GetxService otherwise.
      await Get.delete<CartService>(force: true);
      clock.now.value = endsAt;

      expect(noticedIds, isEmpty);
      expect(noticingCart.itemCount.value, 1);
    });
  });
}
