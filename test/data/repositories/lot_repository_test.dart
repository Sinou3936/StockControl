import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stockcontrol/data/local/database.dart';
import 'package:stockcontrol/data/repositories/lot_repository.dart';
import 'package:stockcontrol/domain/movement_type.dart';

void main() {
  late AppDatabase db;
  late LotRepository repository;
  late int ingredientId;

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    repository = LotRepository(db);
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

  test('creates a lot and a matching inbound movement atomically', () async {
    final lotId = await repository.receiveLot(
      ingredientId: ingredientId,
      supplierId: null,
      receivedDate: DateTime(2026, 9, 3),
      unitCost: 15.0,
      baseQty: 20000,
    );

    final lot = await db.lotDao.getById(lotId);
    final movements = await db.stockMovementDao.movementsForLot(lotId);

    expect(lot.remainingQty, 20000);
    expect(lot.supplierId, isNull);
    expect(movements, hasLength(1));
    expect(movements.first.type, 'inbound');
    expect(movements.first.quantity, 20000);
  });

  test('registers initial stock as an adjustment movement with no supplier',
      () async {
    final lotId = await repository.receiveLot(
      ingredientId: ingredientId,
      receivedDate: DateTime(2026, 9, 3),
      unitCost: 0,
      baseQty: 5000,
      type: MovementType.adjustment,
      memo: '초기재고',
    );

    final movements = await db.stockMovementDao.movementsForLot(lotId);

    expect(movements.first.type, 'adjustment');
    expect(movements.first.memo, '초기재고');
  });
}
