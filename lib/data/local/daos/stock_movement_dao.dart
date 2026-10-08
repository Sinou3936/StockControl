import 'package:drift/drift.dart';

import '../../../domain/movement_type.dart';
import '../../../domain/stock_by_date.dart';
import '../../../domain/stock_overview.dart';
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

  /// [dayEndExclusive] 직전까지의 기록 합계로 구한, 그 시점의 로트별 재고.
  /// `Lot.remainingQty`는 지금 값의 사본이라 과거를 알 수 없으므로 읽지 않고,
  /// 돌려주는 로트의 `remainingQty`를 그 합계로 바꿔 채운다. 합계가 0 이하인
  /// 로트는 뺀다.
  Stream<List<LotWithIngredient>> watchStockAsOf(
    DateTime dayEndExclusive, {
    String? storeId,
  }) {
    final total = stockMovements.quantity.sum();
    final query =
        select(lots).join([
            innerJoin(ingredients, ingredients.id.equalsExp(lots.ingredientId)),
            innerJoin(
              stockMovements,
              stockMovements.lotId.equalsExp(lots.id) &
                  stockMovements.occurredAt.isSmallerThanValue(dayEndExclusive),
            ),
          ])
          ..addColumns([total])
          ..groupBy([lots.id], having: total.isBiggerThanValue(0));

    if (storeId != null) {
      query.where(lots.storeId.equals(storeId));
    }
    query.orderBy([OrderingTerm.asc(lots.expiryDate)]);

    return query.watch().map(
      (rows) => rows
          .map(
            (row) => LotWithIngredient(
              lot: row
                  .readTable(lots)
                  .copyWith(remainingQty: row.read(total) ?? 0),
              ingredient: row.readTable(ingredients),
            ),
          )
          .toList(),
    );
  }

  /// [dayStart] 이상 [dayEndExclusive] 미만에 기록된 입고(`inbound`). 수량은
  /// 입고 때의 값이다 — 그 뒤에 폐기·조정으로 줄어든 값이 아니다.
  Stream<List<InboundEntry>> watchInboundOn(
    DateTime dayStart,
    DateTime dayEndExclusive, {
    String? storeId,
  }) {
    final query =
        select(stockMovements).join([
          innerJoin(lots, lots.id.equalsExp(stockMovements.lotId)),
          innerJoin(ingredients, ingredients.id.equalsExp(lots.ingredientId)),
          leftOuterJoin(suppliers, suppliers.id.equalsExp(lots.supplierId)),
          leftOuterJoin(stores, stores.id.equalsExp(lots.storeId)),
        ])..where(
          stockMovements.type.equals(MovementType.inbound.toDbString()) &
              stockMovements.occurredAt.isBiggerOrEqualValue(dayStart) &
              stockMovements.occurredAt.isSmallerThanValue(dayEndExclusive),
        );

    if (storeId != null) {
      query.where(lots.storeId.equals(storeId));
    }
    query.orderBy([
      OrderingTerm.asc(stockMovements.occurredAt),
      OrderingTerm.asc(stockMovements.id),
    ]);

    return query.watch().map(
      (rows) => rows
          .map(
            (row) => InboundEntry(
              movement: row.readTable(stockMovements),
              lot: row.readTable(lots),
              ingredient: row.readTable(ingredients),
              supplierName: row.readTableOrNull(suppliers)?.name,
              storeName: row.readTableOrNull(stores)?.name,
            ),
          )
          .toList(),
    );
  }
}
