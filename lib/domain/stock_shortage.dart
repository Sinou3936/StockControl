import 'package:stockcontrol/data/local/database.dart';

/// 매장 한 곳에서 품목 하나의 현재 재고 합계.
class StoreStockLevel {
  const StoreStockLevel({
    required this.ingredientId,
    required this.storeId,
    required this.totalQty,
  });

  final int ingredientId;
  final String storeId;
  final double totalQty;
}

/// 한 매장에서 한 품목이 안전재고 기준에 못 미치는 상태.
class StockShortage {
  const StockShortage({
    required this.ingredient,
    required this.store,
    required this.currentQty,
  });

  final Ingredient ingredient;
  final Store store;
  final double currentQty;

  /// 추적 대상만 StockShortage가 되므로 항상 non-null이다.
  double get safetyStockQty => ingredient.safetyStockQty!;

  double get shortfall => safetyStockQty - currentQty;

  /// 기준 대비 채워진 비율. 0이면 완전히 빈 상태.
  double get fillRatio => currentQty / safetyStockQty;
}

/// 안전재고가 설정된 품목에 대해 [stores] 각각의 재고를 비교해 부족분을 모은다.
/// 매장 범위를 좁히려면 호출하는 쪽에서 [stores]를 걸러 넘긴다.
List<StockShortage> calculateShortages({
  required List<Ingredient> ingredients,
  required List<Store> stores,
  required List<StoreStockLevel> levels,
}) {
  final quantities = <String, double>{
    for (final level in levels)
      '${level.ingredientId}@${level.storeId}': level.totalQty,
  };

  final shortages = <StockShortage>[];
  for (final ingredient in ingredients) {
    final threshold = ingredient.safetyStockQty;
    if (threshold == null || threshold <= 0) continue;

    for (final store in stores) {
      final current = quantities['${ingredient.id}@${store.id}'] ?? 0;
      if (current >= threshold) continue;
      shortages.add(
        StockShortage(
          ingredient: ingredient,
          store: store,
          currentQty: current,
        ),
      );
    }
  }

  shortages.sort((a, b) {
    final byRatio = a.fillRatio.compareTo(b.fillRatio);
    if (byRatio != 0) return byRatio;
    final byStore = a.store.name.compareTo(b.store.name);
    if (byStore != 0) return byStore;
    return a.ingredient.name.compareTo(b.ingredient.name);
  });

  return shortages;
}
