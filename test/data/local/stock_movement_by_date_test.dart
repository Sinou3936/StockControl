import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stockcontrol/data/local/database.dart';
import 'package:stockcontrol/data/repositories/lot_repository.dart';
import 'package:stockcontrol/domain/movement_type.dart';
import 'package:stockcontrol/domain/stock_by_date.dart';
import 'package:stockcontrol/domain/stock_overview.dart';

void main() {
  late AppDatabase db;
  late LotRepository repo;
  late int onionId;
  late int carrotId;

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    repo = LotRepository(db);
    Future<int> ingredient(String name) => db.ingredientDao.insertIngredient(
      IngredientsCompanion.insert(
        name: name,
        baseUnit: 'g',
        purchaseUnit: '박스',
        conversionFactor: 1000,
        isExpiryTracked: false,
      ),
    );
    onionId = await ingredient('양파');
    carrotId = await ingredient('당근');
  });

  tearDown(() => db.close());

  Future<List<LotWithIngredient>> stockAsOf(DateTime day, {String? storeId}) =>
      db.stockMovementDao.watchStockAsOf(dayEnd(day), storeId: storeId).first;

  Future<List<InboundEntry>> inboundOn(DateTime day, {String? storeId}) => db
      .stockMovementDao
      .watchInboundOn(dayStart(day), dayEnd(day), storeId: storeId)
      .first;

  group('watchStockAsOf', () {
    test('그날 이후의 폐기는 빼지 않는다', () async {
      final lotId = await repo.receiveLot(
        ingredientId: onionId,
        receivedDate: DateTime(2026, 10, 5, 9),
        unitCost: 1,
        baseQty: 1000,
      );
      await repo.recordQuantityChange(
        lotId: lotId,
        type: MovementType.disposal,
        quantity: -300,
        occurredAt: DateTime(2026, 10, 7, 10),
      );

      expect(
        (await stockAsOf(DateTime(2026, 10, 5))).single.lot.remainingQty,
        1000,
      );
      expect(
        (await stockAsOf(DateTime(2026, 10, 6))).single.lot.remainingQty,
        1000,
      );
      expect(
        (await stockAsOf(DateTime(2026, 10, 7))).single.lot.remainingQty,
        700,
      );
    });

    test('Lot.remainingQty 사본이 아니라 기록 합계를 읽는다', () async {
      final lotId = await repo.receiveLot(
        ingredientId: onionId,
        receivedDate: DateTime(2026, 10, 5, 9),
        unitCost: 1,
        baseQty: 1000,
      );
      await db.lotDao.updateRemainingQty(lotId, 42);

      expect(
        (await stockAsOf(DateTime(2026, 10, 5))).single.lot.remainingQty,
        1000,
      );
    });

    test('그날 이후에 들어온 로트는 나오지 않는다', () async {
      await repo.receiveLot(
        ingredientId: onionId,
        receivedDate: DateTime(2026, 10, 6, 9),
        unitCost: 1,
        baseQty: 1000,
      );

      expect(await stockAsOf(DateTime(2026, 10, 5)), isEmpty);
    });

    test('그날 안에 다 쓴 로트(합계 0)는 나오지 않는다', () async {
      final lotId = await repo.receiveLot(
        ingredientId: onionId,
        receivedDate: DateTime(2026, 10, 5, 9),
        unitCost: 1,
        baseQty: 1000,
      );
      await repo.recordQuantityChange(
        lotId: lotId,
        type: MovementType.disposal,
        quantity: -1000,
        occurredAt: DateTime(2026, 10, 5, 18),
      );

      expect(await stockAsOf(DateTime(2026, 10, 5)), isEmpty);
      expect((await stockAsOf(DateTime(2026, 10, 4))), isEmpty);
    });

    test('경계: 23:59:59는 그날, 다음 날 00:00:00은 다음 날', () async {
      await repo.receiveLot(
        ingredientId: onionId,
        receivedDate: DateTime(2026, 10, 5, 23, 59, 59),
        unitCost: 1,
        baseQty: 100,
      );
      await repo.receiveLot(
        ingredientId: carrotId,
        receivedDate: DateTime(2026, 10, 6),
        unitCost: 1,
        baseQty: 200,
      );

      final fifth = await stockAsOf(DateTime(2026, 10, 5));
      final sixth = await stockAsOf(DateTime(2026, 10, 6));

      expect(fifth.map((r) => r.ingredient.name), ['양파']);
      expect(sixth.map((r) => r.ingredient.name).toSet(), {'양파', '당근'});
    });

    test('매장을 고르면 그 매장 로트만, 고르지 않으면 모두', () async {
      await db.storeDao.upsertStore(
        StoresCompanion.insert(id: 'a', name: '울산점'),
      );
      await db.storeDao.upsertStore(
        StoresCompanion.insert(id: 'b', name: '부산점'),
      );
      await repo.receiveLot(
        ingredientId: onionId,
        storeId: 'a',
        receivedDate: DateTime(2026, 10, 5, 9),
        unitCost: 1,
        baseQty: 100,
      );
      await repo.receiveLot(
        ingredientId: carrotId,
        storeId: 'b',
        receivedDate: DateTime(2026, 10, 5, 9),
        unitCost: 1,
        baseQty: 200,
      );

      final onlyA = await stockAsOf(DateTime(2026, 10, 5), storeId: 'a');
      final all = await stockAsOf(DateTime(2026, 10, 5));

      expect(onlyA.map((r) => r.ingredient.name), ['양파']);
      expect(all, hasLength(2));
    });
  });

  group('watchInboundOn', () {
    test('inbound 기록만 나오고 다른 종류의 변동은 빠진다', () async {
      final lotId = await repo.receiveLot(
        ingredientId: onionId,
        receivedDate: DateTime(2026, 10, 5, 9),
        unitCost: 1,
        baseQty: 1000,
      );
      for (final type in [
        MovementType.usage,
        MovementType.disposal,
        MovementType.adjustment,
        MovementType.countCorrection,
      ]) {
        await repo.recordQuantityChange(
          lotId: lotId,
          type: type,
          quantity: -10,
          occurredAt: DateTime(2026, 10, 5, 12),
        );
      }

      final entries = await inboundOn(DateTime(2026, 10, 5));

      expect(entries, hasLength(1));
      expect(entries.single.movement.type, 'inbound');
    });

    test('나중에 폐기돼도 입고 때의 수량이 나온다', () async {
      final lotId = await repo.receiveLot(
        ingredientId: onionId,
        receivedDate: DateTime(2026, 10, 5, 9),
        unitCost: 1,
        baseQty: 1000,
      );
      await repo.recordQuantityChange(
        lotId: lotId,
        type: MovementType.disposal,
        quantity: -400,
        occurredAt: DateTime(2026, 10, 5, 15),
      );

      final entries = await inboundOn(DateTime(2026, 10, 5));

      expect(entries.single.movement.quantity, 1000);
    });

    test('경계: 그날 00:00:00 포함, 다음 날 00:00:00 제외', () async {
      await repo.receiveLot(
        ingredientId: onionId,
        receivedDate: DateTime(2026, 10, 5),
        unitCost: 1,
        baseQty: 1,
      );
      await repo.receiveLot(
        ingredientId: carrotId,
        receivedDate: DateTime(2026, 10, 6),
        unitCost: 1,
        baseQty: 2,
      );

      final entries = await inboundOn(DateTime(2026, 10, 5));

      expect(entries.map((e) => e.ingredient.name), ['양파']);
    });

    test('매장과 거래처 이름을 함께 주고, 없으면 null', () async {
      await db.storeDao.upsertStore(
        StoresCompanion.insert(id: 'a', name: '울산점'),
      );
      await db.storeDao.upsertStore(
        StoresCompanion.insert(id: 'b', name: '부산점'),
      );
      final supplierId = await db.supplierDao.insertSupplier(
        SuppliersCompanion.insert(name: '가나다상사'),
      );
      await repo.receiveLot(
        ingredientId: onionId,
        storeId: 'a',
        supplierId: supplierId,
        receivedDate: DateTime(2026, 10, 5, 9),
        unitCost: 1,
        baseQty: 100,
      );
      await repo.receiveLot(
        ingredientId: carrotId,
        storeId: 'b',
        receivedDate: DateTime(2026, 10, 5, 10),
        unitCost: 1,
        baseQty: 200,
      );

      final all = await inboundOn(DateTime(2026, 10, 5));
      final onlyA = await inboundOn(DateTime(2026, 10, 5), storeId: 'a');

      expect(all.map((e) => e.storeName), ['울산점', '부산점']);
      expect(all.map((e) => e.supplierName), ['가나다상사', null]);
      expect(onlyA.map((e) => e.ingredient.name), ['양파']);
    });

    test('입고한 시각 순서로 나온다', () async {
      await repo.receiveLot(
        ingredientId: carrotId,
        receivedDate: DateTime(2026, 10, 5, 15),
        unitCost: 1,
        baseQty: 2,
      );
      await repo.receiveLot(
        ingredientId: onionId,
        receivedDate: DateTime(2026, 10, 5, 9),
        unitCost: 1,
        baseQty: 1,
      );

      final entries = await inboundOn(DateTime(2026, 10, 5));

      expect(entries.map((e) => e.ingredient.name), ['양파', '당근']);
    });
  });
}
