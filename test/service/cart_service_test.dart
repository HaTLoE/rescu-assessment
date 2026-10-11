import 'package:flutter_test/flutter_test.dart';
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
}
