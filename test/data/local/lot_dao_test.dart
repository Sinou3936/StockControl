import 'package:drift/drift.dart';
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
}
