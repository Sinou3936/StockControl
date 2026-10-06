import 'package:drift/drift.dart';

import '../../../domain/stock_overview.dart';
import '../../../domain/stock_shortage.dart';
import '../../../domain/sync_id.dart';
import '../database.dart';
import '../tables/lots_table.dart';

part 'lot_dao.g.dart';

@DriftAccessor(tables: [Lots])
class LotDao extends DatabaseAccessor<AppDatabase> with _$LotDaoMixin {
  LotDao(super.db);

  Future<int> insertLot(LotsCompanion entry) {
    return attachedDatabase.transaction(() async {
      final id = await into(lots)
          .insert(entry.copyWith(syncId: Value(generateSyncId())));
      await attachedDatabase.syncQueueDao.enqueue('lots', id);
      return id;
    });
  }

  Future<Lot> getById(int id) =>
      (select(lots)..where((l) => l.id.equals(id))).getSingle();

  Future<void> updateRemainingQty(int id, double remainingQty) =>
      (update(lots)..where((l) => l.id.equals(id))).write(
        LotsCompanion(remainingQty: Value(remainingQty)),
      );

  Stream<List<Lot>> watchLotsForIngredient(int ingredientId) =>
      (select(lots)..where((l) => l.ingredientId.equals(ingredientId)))
          .watch();

  Stream<List<LotWithIngredient>> watchAvailableLotsWithIngredient({
    String? storeId,
  }) {
    final query = select(lots).join([
      innerJoin(ingredients, ingredients.id.equalsExp(lots.ingredientId)),
    ])
      ..where(lots.remainingQty.isBiggerThanValue(0));

    if (storeId != null) {
      query.where(lots.storeId.equals(storeId));
    }

    query.orderBy([OrderingTerm.asc(lots.expiryDate)]);

    return query.watch().map(
          (rows) => rows
              .map(
                (row) => LotWithIngredient(
                  lot: row.readTable(lots),
                  ingredient: row.readTable(ingredients),
                ),
              )
              .toList(),
        );
  }

  /// 매장별·품목별 남은 수량 합계. 매장이 지정되지 않은 로트는 제외한다.
  Stream<List<StoreStockLevel>> watchStockLevelsByStore() {
    final total = lots.remainingQty.sum();
    final query = selectOnly(lots)
      ..addColumns([lots.ingredientId, lots.storeId, total])
      ..where(lots.storeId.isNotNull())
      ..groupBy([lots.ingredientId, lots.storeId]);

    return query.watch().map(
          (rows) => rows
              .map(
                (row) => StoreStockLevel(
                  ingredientId: row.read(lots.ingredientId)!,
                  storeId: row.read(lots.storeId)!,
                  totalQty: row.read(total) ?? 0,
                ),
              )
              .toList(),
        );
  }
}
