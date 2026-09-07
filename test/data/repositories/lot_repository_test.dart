import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stockcontrol/data/local/database.dart';
import 'package:stockcontrol/data/repositories/lot_repository.dart';
import 'package:stockcontrol/domain/movement_type.dart';
import 'package:stockcontrol/domain/stock_adjustment.dart';

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

  test('recordQuantityChange reduces remainingQty for a disposal', () async {
    final lotId = await db.lotDao.insertLot(
      LotsCompanion.insert(
        ingredientId: ingredientId,
        receivedDate: DateTime(2026, 9, 7),
        unitCost: 10.0,
        remainingQty: 1000,
      ),
    );

    await repository.recordQuantityChange(
      lotId: lotId,
      type: MovementType.disposal,
      quantity: -300,
      memo: '유통기한 지남',
    );

    final lot = await db.lotDao.getById(lotId);
    final movements = await db.stockMovementDao.movementsForLot(lotId);

    expect(lot.remainingQty, 700);
    expect(movements, hasLength(1));
    expect(movements.first.type, 'disposal');
    expect(movements.first.quantity, -300);
    expect(movements.first.memo, '유통기한 지남');
  });

  test('recordQuantityChange increases remainingQty for an adjustment',
      () async {
    final lotId = await db.lotDao.insertLot(
      LotsCompanion.insert(
        ingredientId: ingredientId,
        receivedDate: DateTime(2026, 9, 7),
        unitCost: 10.0,
        remainingQty: 1000,
      ),
    );

    await repository.recordQuantityChange(
      lotId: lotId,
      type: MovementType.adjustment,
      quantity: 200,
    );

    final lot = await db.lotDao.getById(lotId);
    expect(lot.remainingQty, 1200);
  });

  test(
      'recordQuantityChange throws and writes nothing when the change would '
      'go negative', () async {
    final lotId = await db.lotDao.insertLot(
      LotsCompanion.insert(
        ingredientId: ingredientId,
        receivedDate: DateTime(2026, 9, 7),
        unitCost: 10.0,
        remainingQty: 100,
      ),
    );

    await expectLater(
      () => repository.recordQuantityChange(
        lotId: lotId,
        type: MovementType.disposal,
        quantity: -500,
      ),
      throwsA(isA<InsufficientStockException>()),
    );

    final lot = await db.lotDao.getById(lotId);
    final movements = await db.stockMovementDao.movementsForLot(lotId);

    expect(lot.remainingQty, 100);
    expect(movements, isEmpty);
  });
}
