import 'package:drift/drift.dart' hide isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stockcontrol/data/local/database.dart';

void main() {
  late AppDatabase db;
  late int ingredientId;

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    ingredientId = await db.ingredientDao.insertIngredient(
      IngredientsCompanion.insert(
        name: '양파',
        baseUnit: 'g',
        purchaseUnit: '박스',
        conversionFactor: 20000,
        isExpiryTracked: false,
      ),
    );
  });

  tearDown(() => db.close());

  test('inserts a lot and updates its remainingQty', () async {
    final lotId = await db.lotDao.insertLot(
      LotsCompanion.insert(
        ingredientId: ingredientId,
        receivedDate: DateTime(2026, 9, 3),
        unitCost: 15.0,
        remainingQty: 20000,
      ),
    );

    await db.lotDao.updateRemainingQty(lotId, 15000);

    final lot = await db.lotDao.getById(lotId);
    expect(lot.remainingQty, 15000);
  });

  test(
      'watchAvailableLotsWithIngredient excludes zero-quantity lots and '
      'sorts by expiry', () async {
    await db.lotDao.insertLot(
      LotsCompanion.insert(
        ingredientId: ingredientId,
        receivedDate: DateTime(2026, 9, 1),
        unitCost: 15.0,
        remainingQty: 0,
      ),
    );
    final soonLotId = await db.lotDao.insertLot(
      LotsCompanion.insert(
        ingredientId: ingredientId,
        receivedDate: DateTime(2026, 9, 3),
        expiryDate: Value(DateTime(2026, 9, 8)),
        unitCost: 15.0,
        remainingQty: 5000,
      ),
    );
    final laterLotId = await db.lotDao.insertLot(
      LotsCompanion.insert(
        ingredientId: ingredientId,
        receivedDate: DateTime(2026, 9, 5),
        expiryDate: Value(DateTime(2026, 10, 1)),
        unitCost: 15.0,
        remainingQty: 3000,
      ),
    );

    final rows = await db.lotDao.watchAvailableLotsWithIngredient().first;

    expect(rows, hasLength(2));
    expect(rows[0].lot.id, soonLotId);
    expect(rows[1].lot.id, laterLotId);
    expect(rows[0].ingredient.name, '양파');
  });

  test('watchAvailableLotsWithIngredient filters by storeId when given',
      () async {
    final storeOneLotId = await db.lotDao.insertLot(
      LotsCompanion.insert(
        ingredientId: ingredientId,
        storeId: const Value('store-1'),
        receivedDate: DateTime(2026, 9, 1),
        unitCost: 15.0,
        remainingQty: 1000,
      ),
    );
    await db.lotDao.insertLot(
      LotsCompanion.insert(
        ingredientId: ingredientId,
        storeId: const Value('store-2'),
        receivedDate: DateTime(2026, 9, 1),
        unitCost: 15.0,
        remainingQty: 2000,
      ),
    );

    final rows = await db.lotDao
        .watchAvailableLotsWithIngredient(storeId: 'store-1')
        .first;

    expect(rows, hasLength(1));
    expect(rows.first.lot.id, storeOneLotId);
  });

  test('insertLot always generates a syncId', () async {
    final lotId = await db.lotDao.insertLot(
      LotsCompanion.insert(
        ingredientId: ingredientId,
        receivedDate: DateTime(2026, 9, 3),
        unitCost: 15.0,
        remainingQty: 20000,
      ),
    );

    final lot = await db.lotDao.getById(lotId);
    expect(lot.syncId, isNotNull);
  });

  test('insertLot also enqueues a sync entry for the new row', () async {
    await db.delete(db.syncQueue).go();

    final lotId = await db.lotDao.insertLot(
      LotsCompanion.insert(
        ingredientId: ingredientId,
        receivedDate: DateTime(2026, 9, 3),
        unitCost: 15.0,
        remainingQty: 1000,
      ),
    );

    final queued = await db.syncQueueDao.oldest();
    expect(queued!.targetTable, 'lots');
    expect(queued.recordId, lotId);
  });

  test('watchStockLevelsByStore sums lots per ingredient and store', () async {
    await db.storeDao.upsertStore(
      StoresCompanion.insert(id: 'store-1', name: '울산점'),
    );
    await db.storeDao.upsertStore(
      StoresCompanion.insert(id: 'store-2', name: '부산점'),
    );

    for (final (store, qty) in [('store-1', 300.0), ('store-1', 200.0),
        ('store-2', 50.0)]) {
      await db.lotDao.insertLot(
        LotsCompanion.insert(
          ingredientId: ingredientId,
          storeId: Value(store),
          receivedDate: DateTime(2026, 10, 1),
          unitCost: 10,
          remainingQty: qty,
        ),
      );
    }

    final levels = await db.lotDao.watchStockLevelsByStore().first;

    final ulsan = levels.firstWhere((l) => l.storeId == 'store-1');
    final busan = levels.firstWhere((l) => l.storeId == 'store-2');
    expect(ulsan.totalQty, 500);
    expect(ulsan.ingredientId, ingredientId);
    expect(busan.totalQty, 50);
  });

  test('watchStockLevelsByStore ignores lots that have no store', () async {
    await db.lotDao.insertLot(
      LotsCompanion.insert(
        ingredientId: ingredientId,
        receivedDate: DateTime(2026, 10, 1),
        unitCost: 10,
        remainingQty: 999,
      ),
    );

    final levels = await db.lotDao.watchStockLevelsByStore().first;

    expect(levels, isEmpty);
  });
}
