import 'package:stockcontrol/data/local/database.dart';

bool isNearExpiry(
  DateTime? expiryDate, {
  required DateTime now,
  int thresholdDays = 3,
}) {
  if (expiryDate == null) return false;
  return !expiryDate.isAfter(now.add(Duration(days: thresholdDays)));
}

class LotWithIngredient {
  LotWithIngredient({required this.lot, required this.ingredient});

  final Lot lot;
  final Ingredient ingredient;
}

class IngredientStockGroup {
  IngredientStockGroup({
    required this.ingredient,
    required this.lots,
    required this.hasNearExpiryLot,
  });

  final Ingredient ingredient;
  final List<Lot> lots;
  final bool hasNearExpiryLot;

  double get totalRemainingQty =>
      lots.fold(0.0, (sum, lot) => sum + lot.remainingQty);
}

/// [flagNearExpiry]가 false이면 임박 표시도 임박 우선 정렬도 하지 않는다
/// (지난 날짜 조회는 지금 기준의 임박 표시와 정렬을 쓰지 않는다).
List<IngredientStockGroup> groupLotsByIngredient(
  List<LotWithIngredient> rows, {
  required DateTime now,
  bool flagNearExpiry = true,
}) {
  final byIngredient = <int, List<LotWithIngredient>>{};
  for (final row in rows) {
    byIngredient.putIfAbsent(row.ingredient.id, () => []).add(row);
  }

  final groups = byIngredient.values.map((groupRows) {
    final lots = groupRows.map((r) => r.lot).toList();
    return IngredientStockGroup(
      ingredient: groupRows.first.ingredient,
      lots: lots,
      hasNearExpiryLot:
          flagNearExpiry &&
          lots.any((lot) => isNearExpiry(lot.expiryDate, now: now)),
    );
  }).toList();

  groups.sort((a, b) {
    if (a.hasNearExpiryLot != b.hasNearExpiryLot) {
      return a.hasNearExpiryLot ? -1 : 1;
    }
    return a.ingredient.name.compareTo(b.ingredient.name);
  });

  return groups;
}
