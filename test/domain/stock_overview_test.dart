import 'package:flutter_test/flutter_test.dart';
import 'package:stockcontrol/domain/stock_overview.dart';

void main() {
  group('isNearExpiry', () {
    final now = DateTime(2026, 9, 7);

    test('returns false when expiryDate is null', () {
      expect(isNearExpiry(null, now: now), isFalse);
    });

    test('returns true when expiry date is already past', () {
      expect(isNearExpiry(DateTime(2026, 9, 5), now: now), isTrue);
    });

    test('returns true when expiry date is today', () {
      expect(isNearExpiry(DateTime(2026, 9, 7), now: now), isTrue);
    });

    test('returns true when exactly at the threshold (3 days from now)', () {
      expect(isNearExpiry(DateTime(2026, 9, 10), now: now), isTrue);
    });

    test('returns false when beyond the threshold', () {
      expect(isNearExpiry(DateTime(2026, 9, 11), now: now), isFalse);
    });

    test('supports a custom threshold', () {
      expect(
        isNearExpiry(DateTime(2026, 9, 14), now: now, thresholdDays: 7),
        isTrue,
      );
    });
  });
}
