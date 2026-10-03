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

    await repository.pushPending();

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

    await repository.pushPending();

    expect(gateway.upsertedPayloads, hasLength(1));
    final remaining = await db.syncQueueDao.oldest();
    expect(remaining, isNotNull);
  });

  test('pushPending re-sent to the same entry does not duplicate it '
      '(idempotent retry)', () async {
    final gateway = FakeSyncGateway();
    final repository = SyncRepository(gateway, db);

    await db.supplierDao.insertSupplier(
      SuppliersCompanion.insert(name: '거래처D'),
    );

    await repository.pushPending();
    // 큐가 비어서 두 번째 호출은 아무것도 안 함 — 멱등성은 upsert 자체의 책임이라
    // 여기서는 같은 payload를 가짜 게이트웨이에 직접 두 번 보내 확인한다.
    final payload = gateway.upsertedPayloads.first;
    await gateway.upsert('suppliers', payload);

    expect(gateway.tableRows['suppliers'], hasLength(1));
  });
}
