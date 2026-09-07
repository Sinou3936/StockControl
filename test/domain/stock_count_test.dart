import 'package:flutter_test/flutter_test.dart';
import 'package:stockcontrol/data/local/database.dart';
import 'package:stockcontrol/domain/stock_count.dart';

Ingredient _makeIngredient(int id, String name) => Ingredient(
      id: id,
      name: name,
      baseUnit: 'g',
      purchaseUnit: '박스',
      conversionFactor: 20000,
      isExpiryTracked: false,
      createdAt: DateTime(2026, 9, 7),
    );

Lot _makeLot(
  int id, {
  required DateTime receivedDate,
  double remainingQty = 1000,
}) =>
    Lot(
      id: id,
      ingredientId: 1,
      receivedDate: receivedDate,
      unitCost: 10,
      remainingQty: remainingQty,
      createdAt: receivedDate,
    );

void main() {
  group('distributeCountDifference', () {
    test('returns an empty list when there is no difference', () {
      final lots = [_makeLot(1, receivedDate: DateTime(2026, 9, 1))];
      expect(distributeCountDifference(lots, 0), isEmpty);
    });

    test('takes a shortfall entirely from a single lot when it covers it',
        () {
      final lots = [
        _makeLot(1, receivedDate: DateTime(2026, 9, 1), remainingQty: 1000),
      ];

      final adjustments = distributeCountDifference(lots, -300);

      expect(adjustments, hasLength(1));
      expect(adjustments.first.lotId, 1);
      expect(adjustments.first.change, -300);
    });

    test('spreads a shortfall across lots oldest-received first', () {
      final lots = [
        _makeLot(2, receivedDate: DateTime(2026, 9, 5), remainingQty: 1000),
        _makeLot(1, receivedDate: DateTime(2026, 9, 1), remainingQty: 500),
      ];

      final adjustments = distributeCountDifference(lots, -700);

      expect(adjustments, hasLength(2));
      expect(adjustments[0].lotId, 1);
      expect(adjustments[0].change, -500);
      expect(adjustments[1].lotId, 2);
      expect(adjustments[1].change, -200);
    });

    test('adds a surplus entirely to the most recently received lot', () {
      final lots = [
        _makeLot(1, receivedDate: DateTime(2026, 9, 1), remainingQty: 500),
        _makeLot(2, receivedDate: DateTime(2026, 9, 5), remainingQty: 500),
      ];

      final adjustments = distributeCountDifference(lots, 200);

      expect(adjustments, hasLength(1));
      expect(adjustments.first.lotId, 2);
      expect(adjustments.first.change, 200);
    });
  });

  group('CountDifference', () {
    test('computes difference as actual minus theoretical', () {
      final diff = CountDifference(
        ingredient: _makeIngredient(1, '양파'),
        theoreticalQty: 1000,
        actualQty: 700,
      );

      expect(diff.difference, -300);
    });
  });
}
