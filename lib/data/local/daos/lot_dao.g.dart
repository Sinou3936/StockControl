// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'lot_dao.dart';

// ignore_for_file: type=lint
mixin _$LotDaoMixin on DatabaseAccessor<AppDatabase> {
  $IngredientsTable get ingredients => attachedDatabase.ingredients;
  $SuppliersTable get suppliers => attachedDatabase.suppliers;
  $LotsTable get lots => attachedDatabase.lots;
  LotDaoManager get managers => LotDaoManager(this);
}

class LotDaoManager {
  final _$LotDaoMixin _db;
  LotDaoManager(this._db);
  $$IngredientsTableTableManager get ingredients =>
      $$IngredientsTableTableManager(_db.attachedDatabase, _db.ingredients);
  $$SuppliersTableTableManager get suppliers =>
      $$SuppliersTableTableManager(_db.attachedDatabase, _db.suppliers);
  $$LotsTableTableManager get lots =>
      $$LotsTableTableManager(_db.attachedDatabase, _db.lots);
}
