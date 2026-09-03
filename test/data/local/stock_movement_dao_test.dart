import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stockcontrol/data/local/database.dart';

void main() {
  late AppDatabase db;
  late int ingredientId;
  late int lotId;

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
    lotId = await db.lotDao.insertLot(
      LotsCompanion.insert(
        ingredientId: ingredientId,
        receivedDate: DateTime(2026, 9, 3),
        unitCost: 15.0,
        remainingQty: 20000,
      ),
    );
  });

  tearDown(() => db.close());

  test('inserts a movement linked to a lot', () async {
    await db.stockMovementDao.insertMovement(
      StockMovementsCompanion.insert(
        lotId: lotId,
        type: 'inbound',
        quantity: 20000,
        occurredAt: DateTime(2026, 9, 3),
      ),
    );

    final movements = await db.stockMovementDao.movementsForLot(lotId);

    expect(movements, hasLength(1));
    expect(movements.first.type, 'inbound');
  });
}
