import 'package:flutter_test/flutter_test.dart';
import 'package:rescu/model/deal_model.dart';
import 'package:rescu/model/pickup_window_model.dart';

DealModel dealEndingAt(DateTime? flashSaleEndsAt) {
  return DealModel(
    id: 1,
    name: 'Deal 1',
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
    flashSaleEndsAt: flashSaleEndsAt,
  );
}

void main() {
  final endsAt = DateTime.utc(2026, 1, 15, 12);

  test('a flash deal is not expired before its end time', () {
    final deal = dealEndingAt(endsAt);

    expect(
      deal.isFlashExpiredAt(endsAt.subtract(const Duration(seconds: 1))),
      isFalse,
    );
  });

  test('a flash deal is expired exactly at its end time', () {
    final deal = dealEndingAt(endsAt);

    expect(deal.isFlashExpiredAt(endsAt), isTrue);
  });

  test('a flash deal is expired after its end time', () {
    final deal = dealEndingAt(endsAt);

    expect(
      deal.isFlashExpiredAt(endsAt.add(const Duration(seconds: 1))),
      isTrue,
    );
  });

  test('the same moment in local time gives the same answer', () {
    final deal = dealEndingAt(endsAt);

    expect(deal.isFlashExpiredAt(endsAt.toLocal()), isTrue);
  });

  test('a deal that is not a flash sale never expires', () {
    final deal = dealEndingAt(null);

    expect(deal.isFlashExpiredAt(DateTime.utc(2100)), isFalse);
  });
}
