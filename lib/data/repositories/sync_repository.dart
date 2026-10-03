import 'package:drift/drift.dart';

import '../local/database.dart';
import '../services/sync_gateway.dart';

class SyncRepository {
  SyncRepository(this._gateway, this._db);

  final SyncGateway _gateway;
  final AppDatabase _db;

  static const _pullOrder = [
    'suppliers',
    'ingredients',
    'lots',
    'stock_movements',
  ];

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

  Future<void> pullUpdates({required bool isOwner, String? storeId}) async {
    for (final tableName in _pullOrder) {
      final storeScoped =
          tableName == 'lots' || tableName == 'stock_movements';
      final filterStoreId = (!isOwner && storeScoped) ? storeId : null;

      final cursor = await _db.syncCursorDao.getLastSyncedAt(tableName);
      final rows = await _gateway.fetchSince(
        tableName,
        cursor,
        storeId: filterStoreId,
      );
      if (rows.isEmpty) continue;

      for (final row in rows) {
        await _applyPulledRow(tableName, row);
      }

      final latest = rows
          .map((r) => DateTime.parse(r['synced_at'] as String))
          .reduce((a, b) => a.isAfter(b) ? a : b);
      await _db.syncCursorDao.setLastSyncedAt(tableName, latest);
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

  Future<void> _applyPulledRow(
    String tableName,
    Map<String, dynamic> row,
  ) async {
    final syncId = row['id'] as String;

    switch (tableName) {
      case 'suppliers':
        if (await _findSupplierLocalId(syncId) != null) return;
        await _db.into(_db.suppliers).insert(
              SuppliersCompanion.insert(
                name: row['name'] as String,
                contact: Value(row['contact'] as String?),
                memo: Value(row['memo'] as String?),
                syncId: Value(syncId),
              ),
            );
      case 'ingredients':
        if (await _findIngredientLocalId(syncId) != null) return;
        await _db.into(_db.ingredients).insert(
              IngredientsCompanion.insert(
                name: row['name'] as String,
                category: Value(row['category'] as String?),
                baseUnit: row['base_unit'] as String,
                purchaseUnit: row['purchase_unit'] as String,
                conversionFactor: (row['conversion_factor'] as num).toDouble(),
                isExpiryTracked: row['is_expiry_tracked'] as bool,
                safetyStockQty: Value(
                  (row['safety_stock_qty'] as num?)?.toDouble(),
                ),
                syncId: Value(syncId),
              ),
            );
      case 'lots':
        if (await _findLotLocalId(syncId) != null) return;
        final ingredientLocalId = await _findIngredientLocalId(
          row['ingredient_id'] as String,
        );
        if (ingredientLocalId == null) return;
        int? supplierLocalId;
        if (row['supplier_id'] != null) {
          supplierLocalId =
              await _findSupplierLocalId(row['supplier_id'] as String);
        }
        await _db.into(_db.lots).insert(
              LotsCompanion.insert(
                ingredientId: ingredientLocalId,
                supplierId: Value(supplierLocalId),
                storeId: Value(row['store_id'] as String?),
                receivedDate: DateTime.parse(row['received_date'] as String),
                expiryDate: Value(
                  row['expiry_date'] == null
                      ? null
                      : DateTime.parse(row['expiry_date'] as String),
                ),
                unitCost: (row['unit_cost'] as num).toDouble(),
                remainingQty: 0,
                syncId: Value(syncId),
              ),
            );
      case 'stock_movements':
        if (await _findStockMovementLocalId(syncId) != null) return;
        final lotLocalId = await _findLotLocalId(row['lot_id'] as String);
        if (lotLocalId == null) return;
        await _db.into(_db.stockMovements).insert(
              StockMovementsCompanion.insert(
                lotId: lotLocalId,
                type: row['type'] as String,
                quantity: (row['quantity'] as num).toDouble(),
                occurredAt: DateTime.parse(row['occurred_at'] as String),
                memo: Value(row['memo'] as String?),
                syncId: Value(syncId),
              ),
            );
    }
  }

  Future<int?> _findSupplierLocalId(String syncId) async {
    final row = await (_db.select(_db.suppliers)
          ..where((t) => t.syncId.equals(syncId)))
        .getSingleOrNull();
    return row?.id;
  }

  Future<int?> _findIngredientLocalId(String syncId) async {
    final row = await (_db.select(_db.ingredients)
          ..where((t) => t.syncId.equals(syncId)))
        .getSingleOrNull();
    return row?.id;
  }

  Future<int?> _findLotLocalId(String syncId) async {
    final row = await (_db.select(_db.lots)
          ..where((t) => t.syncId.equals(syncId)))
        .getSingleOrNull();
    return row?.id;
  }

  Future<int?> _findStockMovementLocalId(String syncId) async {
    final row = await (_db.select(_db.stockMovements)
          ..where((t) => t.syncId.equals(syncId)))
        .getSingleOrNull();
    return row?.id;
  }
}
