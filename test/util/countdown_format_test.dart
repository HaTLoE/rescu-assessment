import 'package:flutter_test/flutter_test.dart';
import 'package:rescu/util/countdown_format.dart';

void main() {
  test('under an hour shows mm:ss', () {
    expect(
      formatCountdown(const Duration(minutes: 9, seconds: 59)),
      '09:59',
    );
    expect(formatCountdown(const Duration(seconds: 5)), '00:05');
  });

  test('exactly one hour switches to hh:mm:ss', () {
    expect(formatCountdown(const Duration(hours: 1)), '01:00:00');
  });

  test('above an hour shows hh:mm:ss', () {
    expect(
      formatCountdown(const Duration(hours: 1, minutes: 15)),
      '01:15:00',
    );
    expect(
      formatCountdown(const Duration(hours: 12, minutes: 3, seconds: 4)),
      '12:03:04',
    );
  });

  test('one second under an hour is still mm:ss', () {
    expect(
      formatCountdown(const Duration(minutes: 59, seconds: 59)),
      '59:59',
    );
  });

  test('zero shows 00:00', () {
    expect(formatCountdown(Duration.zero), '00:00');
  });

  test('a negative duration shows 00:00, never a negative time', () {
    expect(formatCountdown(const Duration(seconds: -1)), '00:00');
    expect(formatCountdown(const Duration(hours: -2)), '00:00');
  });

  test('a part of a second is rounded up', () {
    // With 0.4 s left the sale is still on, so it must not read 00:00 yet.
    expect(formatCountdown(const Duration(milliseconds: 400)), '00:01');
    expect(
      formatCountdown(const Duration(seconds: 59, milliseconds: 400)),
      '01:00',
    );
    expect(
      formatCountdown(
          const Duration(minutes: 59, seconds: 59, milliseconds: 1)),
      '01:00:00',
    );
  });
}
