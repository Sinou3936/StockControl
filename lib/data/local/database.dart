import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';

import 'daos/cached_profile_dao.dart';
import 'daos/ingredient_dao.dart';
import 'daos/lot_dao.dart';
import 'daos/stock_movement_dao.dart';
import 'daos/supplier_dao.dart';
import 'tables/cached_profiles_table.dart';
import 'tables/ingredients_table.dart';
import 'tables/lots_table.dart';
import 'tables/stock_movements_table.dart';
import 'tables/suppliers_table.dart';

part 'database.g.dart';

@DriftDatabase(
  tables: [Suppliers, Ingredients, Lots, StockMovements, CachedProfiles],
  daos: [
    SupplierDao,
    IngredientDao,
    LotDao,
    StockMovementDao,
    CachedProfileDao,
  ],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase([QueryExecutor? executor])
      : super(executor ?? driftDatabase(name: 'stockcontrol'));

  @override
  int get schemaVersion => 2;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (Migrator m) => m.createAll(),
        onUpgrade: (Migrator m, int from, int to) async {
          if (from < 2) {
            await m.createTable(cachedProfiles);
          }
        },
      );
}
