import 'package:drift/drift.dart';

import '../../../domain/sync_id.dart';
import '../database.dart';
import '../tables/ingredients_table.dart';

part 'ingredient_dao.g.dart';

@DriftAccessor(tables: [Ingredients])
class IngredientDao extends DatabaseAccessor<AppDatabase>
    with _$IngredientDaoMixin {
  IngredientDao(super.db);

  Stream<List<Ingredient>> watchAll() => select(ingredients).watch();

  Future<int> insertIngredient(IngredientsCompanion entry) {
    return attachedDatabase.transaction(() async {
      final id = await into(
        ingredients,
      ).insert(entry.copyWith(syncId: Value(generateSyncId())));
      await attachedDatabase.syncQueueDao.enqueue('ingredients', id);
      return id;
    });
  }

  /// 품목 수정 창에서 고치는 두 값(안전재고, 유통기한 관리)을 함께 쓴다. 이름·
  /// 단위·환산계수는 과거 로트와 어긋날 수 있어 고치지 않는다. 한 번에 한 줄만
  /// 전송 큐에 남긴다.
  Future<void> updateSettings(
    int id, {
    required double? safetyStockQty,
    required bool isExpiryTracked,
  }) {
    return attachedDatabase.transaction(() async {
      await (update(ingredients)..where((i) => i.id.equals(id))).write(
        IngredientsCompanion(
          safetyStockQty: Value(safetyStockQty),
          isExpiryTracked: Value(isExpiryTracked),
        ),
      );
      await attachedDatabase.syncQueueDao.enqueue('ingredients', id);
    });
  }

  /// 유통기한 관리 여부만 고친다. 다른 칸(안전재고 등)은 건드리지 않아, 다른
  /// 기기에서 막 고친 값을 오래된 값으로 덮어쓰지 않는다.
  Future<void> updateExpiryTracked(int id, bool isExpiryTracked) {
    return attachedDatabase.transaction(() async {
      await (update(ingredients)..where((i) => i.id.equals(id))).write(
        IngredientsCompanion(isExpiryTracked: Value(isExpiryTracked)),
      );
      await attachedDatabase.syncQueueDao.enqueue('ingredients', id);
    });
  }

  /// 안전재고 값만 고친다. 값이 바뀌는 유일한 필드라, 고칠 때도 새로 만들 때와
  /// 똑같이 전송 큐에 남겨 다른 기기로 전달한다.
  Future<void> updateSafetyStock(int id, double? value) {
    return attachedDatabase.transaction(() async {
      await (update(ingredients)..where((i) => i.id.equals(id))).write(
        IngredientsCompanion(safetyStockQty: Value(value)),
      );
      await attachedDatabase.syncQueueDao.enqueue('ingredients', id);
    });
  }
}
