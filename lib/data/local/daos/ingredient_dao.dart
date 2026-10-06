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
      final id = await into(ingredients)
          .insert(entry.copyWith(syncId: Value(generateSyncId())));
      await attachedDatabase.syncQueueDao.enqueue('ingredients', id);
      return id;
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
