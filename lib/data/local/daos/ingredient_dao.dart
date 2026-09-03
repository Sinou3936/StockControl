import 'package:drift/drift.dart';

import '../database.dart';
import '../tables/ingredients_table.dart';

part 'ingredient_dao.g.dart';

@DriftAccessor(tables: [Ingredients])
class IngredientDao extends DatabaseAccessor<AppDatabase>
    with _$IngredientDaoMixin {
  IngredientDao(super.db);

  Stream<List<Ingredient>> watchAll() => select(ingredients).watch();

  Future<int> insertIngredient(IngredientsCompanion entry) =>
      into(ingredients).insert(entry);
}
