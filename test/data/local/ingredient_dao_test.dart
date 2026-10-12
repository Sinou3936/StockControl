import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stockcontrol/data/local/database.dart';

void main() {
  late AppDatabase db;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
  });

  tearDown(() => db.close());

  test('inserts an ingredient and reads it back via watchAll', () async {
    await db.ingredientDao.insertIngredient(
      IngredientsCompanion.insert(
        name: '양파',
        baseUnit: 'g',
        purchaseUnit: '박스',
        conversionFactor: 20000,
        isExpiryTracked: false,
      ),
    );

    final ingredients = await db.ingredientDao.watchAll().first;

    expect(ingredients, hasLength(1));
    expect(ingredients.first.name, '양파');
    expect(ingredients.first.conversionFactor, 20000);
  });

  test('insertIngredient always generates a syncId', () async {
    final id = await db.ingredientDao.insertIngredient(
      IngredientsCompanion.insert(
        name: '양파',
        baseUnit: 'g',
        purchaseUnit: '박스',
        conversionFactor: 20000,
        isExpiryTracked: false,
      ),
    );

    final ingredients = await db.ingredientDao.watchAll().first;
    final saved = ingredients.firstWhere((i) => i.id == id);

    expect(saved.syncId, isNotNull);
  });

  test('insertIngredient also enqueues a sync entry for the new row', () async {
    final id = await db.ingredientDao.insertIngredient(
      IngredientsCompanion.insert(
        name: '당근',
        baseUnit: 'g',
        purchaseUnit: '박스',
        conversionFactor: 10000,
        isExpiryTracked: false,
      ),
    );

    final queued = await db.syncQueueDao.oldest();
    expect(queued!.targetTable, 'ingredients');
    expect(queued.recordId, id);
  });

  test(
    'updateSafetyStock writes the value and queues the row for sync',
    () async {
      final id = await db.ingredientDao.insertIngredient(
        IngredientsCompanion.insert(
          name: '양파',
          baseUnit: 'g',
          purchaseUnit: '박스',
          conversionFactor: 20000,
          isExpiryTracked: false,
        ),
      );
      await db.delete(db.syncQueue).go();

      await db.ingredientDao.updateSafetyStock(id, 5000);

      final saved = (await db.ingredientDao.watchAll().first).firstWhere(
        (i) => i.id == id,
      );
      expect(saved.safetyStockQty, 5000);

      final queued = await db.syncQueueDao.oldest();
      expect(queued!.targetTable, 'ingredients');
      expect(queued.recordId, id);
    },
  );

  test(
    'updateSettings writes both fields and queues one row for sync',
    () async {
      final id = await db.ingredientDao.insertIngredient(
        IngredientsCompanion.insert(
          name: '양파',
          baseUnit: 'g',
          purchaseUnit: '박스',
          conversionFactor: 20000,
          isExpiryTracked: true,
          safetyStockQty: const Value(5000),
        ),
      );
      await db.delete(db.syncQueue).go();

      await db.ingredientDao.updateSettings(
        id,
        safetyStockQty: 3000,
        isExpiryTracked: false,
      );

      final saved = (await db.ingredientDao.watchAll().first).firstWhere(
        (i) => i.id == id,
      );
      expect(saved.safetyStockQty, 3000);
      expect(saved.isExpiryTracked, isFalse);
      // 이름·단위·환산계수는 건드리지 않는다.
      expect(saved.name, '양파');
      expect(saved.conversionFactor, 20000);

      final queued = await db.select(db.syncQueue).get();
      expect(queued, hasLength(1));
      expect(queued.single.targetTable, 'ingredients');
      expect(queued.single.recordId, id);
    },
  );

  test(
    'updateExpiryTracked changes only that field and queues the row',
    () async {
      final id = await db.ingredientDao.insertIngredient(
        IngredientsCompanion.insert(
          name: '양파',
          baseUnit: 'g',
          purchaseUnit: '박스',
          conversionFactor: 20000,
          isExpiryTracked: true,
          safetyStockQty: const Value(5000),
        ),
      );
      await db.delete(db.syncQueue).go();

      await db.ingredientDao.updateExpiryTracked(id, false);

      final saved = (await db.ingredientDao.watchAll().first).firstWhere(
        (i) => i.id == id,
      );
      expect(saved.isExpiryTracked, isFalse);
      // 안전재고는 그대로 둔다 (다른 기기에서 막 고친 값을 덮어쓰지 않게 한 칸만 쓴다).
      expect(saved.safetyStockQty, 5000);

      final queued = await db.select(db.syncQueue).get();
      expect(queued, hasLength(1));
      expect(queued.single.targetTable, 'ingredients');
      expect(queued.single.recordId, id);
    },
  );

  test(
    'updateSettings can clear the safety stock and turn tracking on',
    () async {
      final id = await db.ingredientDao.insertIngredient(
        IngredientsCompanion.insert(
          name: '양파',
          baseUnit: 'g',
          purchaseUnit: '박스',
          conversionFactor: 20000,
          isExpiryTracked: false,
          safetyStockQty: const Value(5000),
        ),
      );

      await db.ingredientDao.updateSettings(
        id,
        safetyStockQty: null,
        isExpiryTracked: true,
      );

      final saved = (await db.ingredientDao.watchAll().first).firstWhere(
        (i) => i.id == id,
      );
      expect(saved.safetyStockQty, isNull);
      expect(saved.isExpiryTracked, isTrue);
    },
  );

  test('updateSafetyStock with null clears tracking', () async {
    final id = await db.ingredientDao.insertIngredient(
      IngredientsCompanion.insert(
        name: '양파',
        baseUnit: 'g',
        purchaseUnit: '박스',
        conversionFactor: 20000,
        isExpiryTracked: false,
        safetyStockQty: const Value(5000),
      ),
    );

    await db.ingredientDao.updateSafetyStock(id, null);

    final saved = (await db.ingredientDao.watchAll().first).firstWhere(
      (i) => i.id == id,
    );
    expect(saved.safetyStockQty, isNull);
  });
}
