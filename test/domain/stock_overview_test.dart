import 'package:flutter_test/flutter_test.dart';
import 'package:stockcontrol/data/local/database.dart';
import 'package:stockcontrol/domain/stock_overview.dart';

Ingredient _makeIngredient(int id, String name) => Ingredient(
      id: id,
      name: name,
      baseUnit: 'g',
      purchaseUnit: '박스',
      conversionFactor: 20000,
      isExpiryTracked: true,
      createdAt: DateTime(2026, 9, 7),
    );

Lot _makeLot(
  int id,
  int ingredientId, {
  DateTime? expiryDate,
  double remainingQty = 1000,
}) =>
    Lot(
      id: id,
      ingredientId: ingredientId,
      receivedDate: DateTime(2026, 9, 7),
      expiryDate: expiryDate,
      unitCost: 10,
      remainingQty: remainingQty,
      createdAt: DateTime(2026, 9, 7),
    );

void _groupLotsByIngredientTests() {
  final now = DateTime(2026, 9, 7);

  group('groupLotsByIngredient', () {
    test('groups rows by ingredient and sums remainingQty', () {
      final onion = _makeIngredient(1, '양파');
      final rows = [
        LotWithIngredient(
          lot: _makeLot(1, 1, remainingQty: 5000),
          ingredient: onion,
        ),
        LotWithIngredient(
          lot: _makeLot(2, 1, remainingQty: 3000),
          ingredient: onion,
        ),
      ];

      final groups = groupLotsByIngredient(rows, now: now);

      expect(groups, hasLength(1));
      expect(groups.first.ingredient.name, '양파');
      expect(groups.first.lots, hasLength(2));
      expect(groups.first.totalRemainingQty, 8000);
    });

    test('sorts groups with a near-expiry lot before ones without', () {
      final onion = _makeIngredient(1, '양파');
      final carrot = _makeIngredient(2, '당근');
      final rows = [
        LotWithIngredient(
          lot: _makeLot(1, 1, expiryDate: now.add(const Duration(days: 30))),
          ingredient: onion,
        ),
        LotWithIngredient(
          lot: _makeLot(2, 2, expiryDate: now.add(const Duration(days: 1))),
          ingredient: carrot,
        ),
      ];

      final groups = groupLotsByIngredient(rows, now: now);

      expect(groups.first.ingredient.name, '당근');
      expect(groups.first.hasNearExpiryLot, isTrue);
      expect(groups.last.ingredient.name, '양파');
      expect(groups.last.hasNearExpiryLot, isFalse);
    });

    test('sorts groups alphabetically when urgency is equal', () {
      final onion = _makeIngredient(1, '양파');
      final carrot = _makeIngredient(2, '당근');
      final rows = [
        LotWithIngredient(lot: _makeLot(1, 1), ingredient: onion),
        LotWithIngredient(lot: _makeLot(2, 2), ingredient: carrot),
      ];

      final groups = groupLotsByIngredient(rows, now: now);

      expect(groups.map((g) => g.ingredient.name), ['당근', '양파']);
    });
  });
}

void main() {
  _groupLotsByIngredientTests();

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
