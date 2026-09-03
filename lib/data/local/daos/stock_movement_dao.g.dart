// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'stock_movement_dao.dart';

// ignore_for_file: type=lint
mixin _$StockMovementDaoMixin on DatabaseAccessor<AppDatabase> {
  $IngredientsTable get ingredients => attachedDatabase.ingredients;
  $SuppliersTable get suppliers => attachedDatabase.suppliers;
  $LotsTable get lots => attachedDatabase.lots;
  $StockMovementsTable get stockMovements => attachedDatabase.stockMovements;
  StockMovementDaoManager get managers => StockMovementDaoManager(this);
}

class StockMovementDaoManager {
  final _$StockMovementDaoMixin _db;
  StockMovementDaoManager(this._db);
  $$IngredientsTableTableManager get ingredients =>
      $$IngredientsTableTableManager(_db.attachedDatabase, _db.ingredients);
  $$SuppliersTableTableManager get suppliers =>
      $$SuppliersTableTableManager(_db.attachedDatabase, _db.suppliers);
  $$LotsTableTableManager get lots =>
      $$LotsTableTableManager(_db.attachedDatabase, _db.lots);
  $$StockMovementsTableTableManager get stockMovements =>
      $$StockMovementsTableTableManager(
        _db.attachedDatabase,
        _db.stockMovements,
      );
}
