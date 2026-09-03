import 'package:drift/drift.dart';

import '../database.dart';
import '../tables/stock_movements_table.dart';

part 'stock_movement_dao.g.dart';

@DriftAccessor(tables: [StockMovements])
class StockMovementDao extends DatabaseAccessor<AppDatabase>
    with _$StockMovementDaoMixin {
  StockMovementDao(super.db);

  Future<int> insertMovement(StockMovementsCompanion entry) =>
      into(stockMovements).insert(entry);

  Future<List<StockMovement>> movementsForLot(int lotId) =>
      (select(stockMovements)..where((m) => m.lotId.equals(lotId))).get();
}
