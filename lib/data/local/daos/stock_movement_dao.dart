import 'package:drift/drift.dart';

import '../../../domain/sync_id.dart';
import '../database.dart';
import '../tables/stock_movements_table.dart';

part 'stock_movement_dao.g.dart';

@DriftAccessor(tables: [StockMovements])
class StockMovementDao extends DatabaseAccessor<AppDatabase>
    with _$StockMovementDaoMixin {
  StockMovementDao(super.db);

  Future<int> insertMovement(StockMovementsCompanion entry) {
    return attachedDatabase.transaction(() async {
      final id = await into(stockMovements)
          .insert(entry.copyWith(syncId: Value(generateSyncId())));
      await attachedDatabase.syncQueueDao.enqueue('stock_movements', id);
      return id;
    });
  }

  Future<List<StockMovement>> movementsForLot(int lotId) =>
      (select(stockMovements)..where((m) => m.lotId.equals(lotId))).get();
}
