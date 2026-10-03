import '../local/database.dart';
import '../services/sync_gateway.dart';

class SyncRepository {
  SyncRepository(this._gateway, this._db);

  final SyncGateway _gateway;
  final AppDatabase _db;

  Future<void> pushPending() async {
    while (true) {
      final entry = await _db.syncQueueDao.oldest();
      if (entry == null) return;

      final payload = await _buildPayload(entry.targetTable, entry.recordId);
      if (payload == null) {
        await _db.syncQueueDao.remove(entry.id);
        continue;
      }

      try {
        await _gateway.upsert(entry.targetTable, payload);
      } catch (_) {
        return;
      }
      await _db.syncQueueDao.remove(entry.id);
    }
  }

  Future<Map<String, dynamic>?> _buildPayload(
    String tableName,
    int recordId,
  ) async {
    switch (tableName) {
      case 'suppliers':
        final row = await (_db.select(_db.suppliers)
              ..where((t) => t.id.equals(recordId)))
            .getSingleOrNull();
        if (row == null) return null;
        return {
          'id': row.syncId,
          'name': row.name,
          'contact': row.contact,
          'memo': row.memo,
          'created_at': row.createdAt.toIso8601String(),
        };
      case 'ingredients':
        final row = await (_db.select(_db.ingredients)
              ..where((t) => t.id.equals(recordId)))
            .getSingleOrNull();
        if (row == null) return null;
        return {
          'id': row.syncId,
          'name': row.name,
          'category': row.category,
          'base_unit': row.baseUnit,
          'purchase_unit': row.purchaseUnit,
          'conversion_factor': row.conversionFactor,
          'is_expiry_tracked': row.isExpiryTracked,
          'safety_stock_qty': row.safetyStockQty,
          'created_at': row.createdAt.toIso8601String(),
        };
      case 'lots':
        final row = await (_db.select(_db.lots)
              ..where((t) => t.id.equals(recordId)))
            .getSingleOrNull();
        if (row == null) return null;
        final ingredient = await (_db.select(_db.ingredients)
              ..where((t) => t.id.equals(row.ingredientId)))
            .getSingle();
        String? supplierSyncId;
        if (row.supplierId != null) {
          final supplier = await (_db.select(_db.suppliers)
                ..where((t) => t.id.equals(row.supplierId!)))
              .getSingleOrNull();
          supplierSyncId = supplier?.syncId;
        }
        return {
          'id': row.syncId,
          'ingredient_id': ingredient.syncId,
          'supplier_id': supplierSyncId,
          'store_id': row.storeId,
          'received_date': row.receivedDate.toIso8601String(),
          'expiry_date': row.expiryDate?.toIso8601String(),
          'unit_cost': row.unitCost,
          'created_at': row.createdAt.toIso8601String(),
        };
      case 'stock_movements':
        final row = await (_db.select(_db.stockMovements)
              ..where((t) => t.id.equals(recordId)))
            .getSingleOrNull();
        if (row == null) return null;
        final lot = await (_db.select(_db.lots)
              ..where((t) => t.id.equals(row.lotId)))
            .getSingle();
        return {
          'id': row.syncId,
          'lot_id': lot.syncId,
          'store_id': lot.storeId,
          'type': row.type,
          'quantity': row.quantity,
          'occurred_at': row.occurredAt.toIso8601String(),
          'memo': row.memo,
          'created_at': row.createdAt.toIso8601String(),
        };
      default:
        return null;
    }
  }
}
