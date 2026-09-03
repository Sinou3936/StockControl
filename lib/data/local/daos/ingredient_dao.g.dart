// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'ingredient_dao.dart';

// ignore_for_file: type=lint
mixin _$IngredientDaoMixin on DatabaseAccessor<AppDatabase> {
  $IngredientsTable get ingredients => attachedDatabase.ingredients;
  IngredientDaoManager get managers => IngredientDaoManager(this);
}

class IngredientDaoManager {
  final _$IngredientDaoMixin _db;
  IngredientDaoManager(this._db);
  $$IngredientsTableTableManager get ingredients =>
      $$IngredientsTableTableManager(_db.attachedDatabase, _db.ingredients);
}
