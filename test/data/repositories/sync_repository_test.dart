import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stockcontrol/data/local/database.dart';
import 'package:stockcontrol/data/repositories/sync_repository.dart';

import '../../support/fake_sync_gateway.dart';

void main() {
  late AppDatabase db;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
  });

  tearDown(() => db.close());

  test('pushPending upserts a queued supplier and clears the queue',
      () async {
    final gateway = FakeSyncGateway();
    final repository = SyncRepository(gateway, db);

    await db.supplierDao.insertSupplier(
      SuppliersCompanion.insert(name: '거래처A'),
    );

    final drained = await repository.pushPending();

    expect(drained, isTrue);
    expect(gateway.upsertedPayloads, hasLength(1));
    expect(gateway.upsertedPayloads.first['name'], '거래처A');
    expect(await db.syncQueueDao.oldest(), isNull);
  });

  test('pushPending translates lot FKs to the referenced rows\' syncId',
      () async {
    final gateway = FakeSyncGateway();
    final repository = SyncRepository(gateway, db);

    final ingredientId = await db.ingredientDao.insertIngredient(
      IngredientsCompanion.insert(
        name: '양파',
        baseUnit: 'g',
        purchaseUnit: '박스',
        conversionFactor: 20000,
        isExpiryTracked: false,
      ),
    );
    await db.lotDao.insertLot(
      LotsCompanion.insert(
        ingredientId: ingredientId,
        storeId: const Value('store-1'),
        receivedDate: DateTime(2026, 9, 3),
        unitCost: 15.0,
        remainingQty: 1000,
      ),
    );

    await repository.pushPending();

    final ingredients = await db.ingredientDao.watchAll().first;
    final lotPayload = gateway.upsertedPayloads
        .firstWhere((p) => p.containsKey('ingredient_id'));

    expect(lotPayload['ingredient_id'], ingredients.first.syncId);
    expect(lotPayload['store_id'], 'store-1');
    expect(lotPayload.containsKey('remaining_qty'), isFalse);
  });

  test('pushPending sends every timestamp as UTC with an explicit Z',
      () async {
    final gateway = FakeSyncGateway();
    final repository = SyncRepository(gateway, db);

    final ingredientId = await db.ingredientDao.insertIngredient(
      IngredientsCompanion.insert(
        name: '양파',
        baseUnit: 'g',
        purchaseUnit: '박스',
        conversionFactor: 20000,
        isExpiryTracked: true,
      ),
    );
    await db.lotDao.insertLot(
      LotsCompanion.insert(
        ingredientId: ingredientId,
        receivedDate: DateTime(2026, 9, 3),
        expiryDate: Value(DateTime(2026, 9, 10)),
        unitCost: 15.0,
        remainingQty: 1000,
      ),
    );

    await repository.pushPending();

    final lotPayload = gateway.upsertedPayloads
        .firstWhere((p) => p.containsKey('ingredient_id'));
    for (final key in ['created_at', 'received_date', 'expiry_date']) {
      expect((lotPayload[key] as String).endsWith('Z'), isTrue, reason: key);
    }
    expect(
      DateTime.parse(lotPayload['received_date'] as String)
          .isAtSameMomentAs(DateTime(2026, 9, 3)),
      isTrue,
    );
  });

  test('pushPending stops at the first failure and leaves later entries '
      'queued', () async {
    final gateway = FakeSyncGateway(failUpsertAfter: 1);
    final repository = SyncRepository(gateway, db);

    await db.supplierDao.insertSupplier(
      SuppliersCompanion.insert(name: '거래처B'),
    );
    await db.supplierDao.insertSupplier(
      SuppliersCompanion.insert(name: '거래처C'),
    );

    final drained = await repository.pushPending();

    expect(drained, isFalse);
    expect(gateway.upsertedPayloads, hasLength(1));
    final remaining = await db.syncQueueDao.oldest();
    expect(remaining, isNotNull);
  });

  test('pushPending sent twice for the same row does not duplicate it '
      '(idempotent retry)', () async {
    final gateway = FakeSyncGateway();
    final repository = SyncRepository(gateway, db);

    final id = await db.supplierDao.insertSupplier(
      SuppliersCompanion.insert(name: '거래처D'),
    );
    // 전송은 됐는데 큐에서 지우기 전에 앱이 꺼진 상황: 같은 행이 큐에 다시 남는다.
    await repository.pushPending();
    await db.syncQueueDao.enqueue('suppliers', id);
    await repository.pushPending();

    expect(gateway.upsertedPayloads, hasLength(2));
    expect(gateway.tableRows['suppliers'], hasLength(1));
  });

  test('pullUpdates inserts suppliers and ingredients regardless of role',
      () async {
    final gateway = FakeSyncGateway();
    gateway.tableRows['suppliers'] = [
      {
        'id': 'supplier-syncid-1',
        'name': '서버거래처',
        'contact': null,
        'memo': null,
        'synced_at': DateTime(2026, 10, 1).toIso8601String(),
      },
    ];
    final repository = SyncRepository(gateway, db);

    await repository.pullUpdates(isOwner: false, storeId: 'store-1');

    final suppliers = await db.supplierDao.watchAll().first;
    expect(suppliers, hasLength(1));
    expect(suppliers.first.name, '서버거래처');
    expect(suppliers.first.syncId, 'supplier-syncid-1');
  });

  test('pullUpdates filters lots by storeId for a non-owner', () async {
    final gateway = FakeSyncGateway();
    gateway.tableRows['ingredients'] = [
      {
        'id': 'ingredient-syncid-1',
        'name': '당근',
        'category': null,
        'base_unit': 'g',
        'purchase_unit': '박스',
        'conversion_factor': 10000,
        'is_expiry_tracked': false,
        'safety_stock_qty': null,
        'synced_at': DateTime(2026, 10, 1).toIso8601String(),
      },
    ];
    gateway.tableRows['lots'] = [
      {
        'id': 'lot-syncid-1',
        'ingredient_id': 'ingredient-syncid-1',
        'supplier_id': null,
        'store_id': 'store-1',
        'received_date': DateTime(2026, 10, 1).toIso8601String(),
        'expiry_date': null,
        'unit_cost': 10,
        'synced_at': DateTime(2026, 10, 1).toIso8601String(),
      },
      {
        'id': 'lot-syncid-2',
        'ingredient_id': 'ingredient-syncid-1',
        'supplier_id': null,
        'store_id': 'store-2',
        'received_date': DateTime(2026, 10, 1).toIso8601String(),
        'expiry_date': null,
        'unit_cost': 10,
        'synced_at': DateTime(2026, 10, 1).toIso8601String(),
      },
    ];
    final repository = SyncRepository(gateway, db);

    await repository.pullUpdates(isOwner: false, storeId: 'store-1');

    // pull으로 받은 로트는 remainingQty가 0으로 만들어진다(알려진 한계).
    // watchAvailableLotsWithIngredient는 잔량 > 0만 보므로 테이블을 직접 조회한다.
    final pulledLots = await db.select(db.lots).get();
    expect(pulledLots, hasLength(1));
    expect(pulledLots.first.syncId, 'lot-syncid-1');
    expect(pulledLots.first.storeId, 'store-1');
    expect(pulledLots.first.remainingQty, 0);
  });

  test('pullUpdates skips a row whose syncId already exists locally',
      () async {
    final gateway = FakeSyncGateway();
    final existingId = await db.supplierDao.insertSupplier(
      SuppliersCompanion.insert(name: '이미있음'),
    );
    final existing = await db.supplierDao.watchAll().first;
    final existingSyncId =
        existing.firstWhere((s) => s.id == existingId).syncId;

    gateway.tableRows['suppliers'] = [
      {
        'id': existingSyncId,
        'name': '서버에서온이름',
        'contact': null,
        'memo': null,
        'synced_at': DateTime(2026, 10, 1).toIso8601String(),
      },
    ];
    final repository = SyncRepository(gateway, db);

    await repository.pullUpdates(isOwner: true);

    final suppliers = await db.supplierDao.watchAll().first;
    expect(suppliers, hasLength(1));
    expect(suppliers.first.name, '이미있음');
  });

  test('pullUpdates accepts whole-number JSON for real columns', () async {
    final gateway = FakeSyncGateway();
    gateway.tableRows['ingredients'] = [
      {
        'id': 'ingredient-int-1',
        'name': '감자',
        'category': null,
        'base_unit': 'g',
        'purchase_unit': '박스',
        'conversion_factor': 20000,
        'is_expiry_tracked': false,
        'safety_stock_qty': 500,
        'synced_at': DateTime(2026, 10, 1).toIso8601String(),
      },
    ];
    final repository = SyncRepository(gateway, db);

    await repository.pullUpdates(isOwner: true);

    final ingredients = await db.ingredientDao.watchAll().first;
    expect(ingredients.single.conversionFactor, 20000.0);
    expect(ingredients.single.safetyStockQty, 500.0);
  });

  test('a second pullUpdates only fetches rows synced after the cursor',
      () async {
    final gateway = FakeSyncGateway();
    gateway.tableRows['suppliers'] = [
      {
        'id': 'supplier-old',
        'name': '옛날',
        'contact': null,
        'memo': null,
        'synced_at': DateTime(2026, 10, 1).toIso8601String(),
      },
    ];
    final repository = SyncRepository(gateway, db);
    await repository.pullUpdates(isOwner: true);

    gateway.tableRows['suppliers']!.add({
      'id': 'supplier-late',
      'name': '늦게도착',
      'contact': null,
      'memo': null,
      'synced_at': DateTime(2026, 10, 2).toIso8601String(),
    });
    await repository.pullUpdates(isOwner: true);

    final suppliers = await db.supplierDao.watchAll().first;
    expect(suppliers.map((s) => s.name), containsAll(['옛날', '늦게도착']));
    expect(suppliers, hasLength(2));
  });

  Map<String, dynamic> pulledIngredient() => {
        'id': 'ingredient-1',
        'name': '당근',
        'category': null,
        'base_unit': 'g',
        'purchase_unit': '박스',
        'conversion_factor': 10000,
        'is_expiry_tracked': false,
        'safety_stock_qty': null,
        'synced_at': DateTime(2026, 10, 1).toIso8601String(),
      };

  Map<String, dynamic> pulledLot() => {
        'id': 'lot-1',
        'ingredient_id': 'ingredient-1',
        'supplier_id': null,
        'store_id': 'store-1',
        'received_date': DateTime(2026, 10, 1).toIso8601String(),
        'expiry_date': null,
        'unit_cost': 10,
        'synced_at': DateTime(2026, 10, 1).toIso8601String(),
      };

  Map<String, dynamic> pulledMovement(String id, num quantity) => {
        'id': id,
        'lot_id': 'lot-1',
        'store_id': 'store-1',
        'type': 'inbound',
        'quantity': quantity,
        'occurred_at': DateTime(2026, 10, 1).toIso8601String(),
        'memo': null,
        'synced_at': DateTime(2026, 10, 1).toIso8601String(),
      };

  test('pullUpdates retries a lot whose ingredient has not arrived yet '
      'instead of skipping it forever', () async {
    final gateway = FakeSyncGateway();
    gateway.tableRows['lots'] = [pulledLot()];
    final repository = SyncRepository(gateway, db);

    await repository.pullUpdates(isOwner: true);

    expect(await db.select(db.lots).get(), isEmpty);

    gateway.tableRows['ingredients'] = [pulledIngredient()];
    await repository.pullUpdates(isOwner: true);

    final lots = await db.select(db.lots).get();
    expect(lots, hasLength(1));
    expect(lots.single.syncId, 'lot-1');
  });

  test('pullUpdates stops at a row it cannot apply yet and keeps the cursor '
      'before it', () async {
    final gateway = FakeSyncGateway();
    gateway.tableRows['ingredients'] = [pulledIngredient()];
    gateway.tableRows['lots'] = [
      {...pulledLot(), 'id': 'lot-ok'},
      {
        ...pulledLot(),
        'id': 'lot-stuck',
        'ingredient_id': 'ingredient-missing',
        'synced_at': DateTime(2026, 10, 2).toIso8601String(),
      },
      {
        ...pulledLot(),
        'id': 'lot-after',
        'synced_at': DateTime(2026, 10, 3).toIso8601String(),
      },
    ];
    final repository = SyncRepository(gateway, db);

    await repository.pullUpdates(isOwner: true);

    final syncIds = (await db.select(db.lots).get()).map((l) => l.syncId);
    expect(syncIds, ['lot-ok']);
    expect(
      await db.syncCursorDao.getLastSyncedAt('lots'),
      DateTime(2026, 10, 1),
    );
  });

  test('pullUpdates sets a pulled lot\'s remainingQty to the sum of its '
      'pulled movements', () async {
    final gateway = FakeSyncGateway();
    gateway.tableRows['ingredients'] = [pulledIngredient()];
    gateway.tableRows['lots'] = [pulledLot()];
    gateway.tableRows['stock_movements'] = [
      pulledMovement('movement-1', 1000),
      pulledMovement('movement-2', -300),
    ];
    final repository = SyncRepository(gateway, db);

    await repository.pullUpdates(isOwner: true);

    final lot = await (db.select(db.lots)
          ..where((t) => t.syncId.equals('lot-1')))
        .getSingle();
    expect(lot.remainingQty, 700);

    final visible = await db.lotDao.watchAvailableLotsWithIngredient().first;
    expect(visible, hasLength(1));
  });

  test('pullUpdates applies a later movement from another device to an '
      'existing lot', () async {
    final gateway = FakeSyncGateway();
    gateway.tableRows['ingredients'] = [pulledIngredient()];
    gateway.tableRows['lots'] = [pulledLot()];
    gateway.tableRows['stock_movements'] = [pulledMovement('movement-1', 1000)];
    final repository = SyncRepository(gateway, db);
    await repository.pullUpdates(isOwner: true);

    gateway.tableRows['stock_movements']!.add({
      ...pulledMovement('movement-2', -400),
      'synced_at': DateTime(2026, 10, 2).toIso8601String(),
    });
    await repository.pullUpdates(isOwner: true);

    final lot = await (db.select(db.lots)
          ..where((t) => t.syncId.equals('lot-1')))
        .getSingle();
    expect(lot.remainingQty, 600);
  });
}
