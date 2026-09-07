import 'package:drift/drift.dart';

import '../../domain/movement_type.dart';
import '../../domain/stock_adjustment.dart';
import '../local/database.dart';

class LotRepository {
  LotRepository(this._db);

  final AppDatabase _db;

  Future<int> receiveLot({
    required int ingredientId,
    int? supplierId,
    required DateTime receivedDate,
    DateTime? expiryDate,
    required double unitCost,
    required double baseQty,
    MovementType type = MovementType.inbound,
    String? memo,
  }) {
    return _db.transaction(() async {
      final lotId = await _db.lotDao.insertLot(
        LotsCompanion.insert(
          ingredientId: ingredientId,
          supplierId: Value(supplierId),
          receivedDate: receivedDate,
          expiryDate: Value(expiryDate),
          unitCost: unitCost,
          remainingQty: baseQty,
        ),
      );

      await _db.stockMovementDao.insertMovement(
        StockMovementsCompanion.insert(
          lotId: lotId,
          type: type.toDbString(),
          quantity: baseQty,
          occurredAt: receivedDate,
          memo: Value(memo),
        ),
      );

      return lotId;
    });
  }

  Future<void> recordQuantityChange({
    required int lotId,
    required MovementType type,
    required double quantity,
    DateTime? occurredAt,
    String? memo,
  }) async {
    await _db.transaction(() async {
      final lot = await _db.lotDao.getById(lotId);
      final newQty = applyQuantityChange(lot.remainingQty, quantity);

      await _db.lotDao.updateRemainingQty(lotId, newQty);
      await _db.stockMovementDao.insertMovement(
        StockMovementsCompanion.insert(
          lotId: lotId,
          type: type.toDbString(),
          quantity: quantity,
          occurredAt: occurredAt ?? DateTime.now(),
          memo: Value(memo),
        ),
      );
    });
  }
}
