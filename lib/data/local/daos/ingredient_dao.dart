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
}
