import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';

import 'tables/ingredients_table.dart';
import 'tables/lots_table.dart';
import 'tables/stock_movements_table.dart';
import 'tables/suppliers_table.dart';

part 'database.g.dart';

@DriftDatabase(
  tables: [Suppliers, Ingredients, Lots, StockMovements],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase([QueryExecutor? executor])
      : super(executor ?? driftDatabase(name: 'stockcontrol'));

  @override
  int get schemaVersion => 1;
}
