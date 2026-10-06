import 'package:flutter_test/flutter_test.dart';
import 'package:stockcontrol/data/local/database.dart';
import 'package:stockcontrol/domain/stock_shortage.dart';

Ingredient makeIngredient(int id, String name, double? safetyStockQty) =>
    Ingredient(
      id: id,
      name: name,
      baseUnit: 'g',
      purchaseUnit: '박스',
      conversionFactor: 1000,
      isExpiryTracked: false,
      safetyStockQty: safetyStockQty,
      createdAt: DateTime(2026, 10, 1),
    );

void main() {
  const ulsan = Store(id: 'store-1', name: '울산점');
  const busan = Store(id: 'store-2', name: '부산점');

  test('안전재고가 없는 품목은 결과에 나오지 않는다', () {
    final result = calculateShortages(
      ingredients: [makeIngredient(1, '양파', null)],
      stores: [ulsan],
      levels: [],
    );

    expect(result, isEmpty);
  });

  test('안전재고가 0 이하인 품목도 추적하지 않는다', () {
    final result = calculateShortages(
      ingredients: [makeIngredient(1, '양파', 0)],
      stores: [ulsan],
      levels: [],
    );

    expect(result, isEmpty);
  });

  test('로트가 하나도 없는 매장은 현재 수량 0으로 부족에 포함된다', () {
    final result = calculateShortages(
      ingredients: [makeIngredient(1, '양파', 5000)],
      stores: [ulsan],
      levels: [],
    );

    expect(result, hasLength(1));
    expect(result.single.currentQty, 0);
    expect(result.single.shortfall, 5000);
    expect(result.single.fillRatio, 0);
    expect(result.single.store.id, 'store-1');
  });

  test('현재 수량이 기준과 정확히 같으면 부족이 아니다', () {
    final result = calculateShortages(
      ingredients: [makeIngredient(1, '양파', 5000)],
      stores: [ulsan],
      levels: [
        const StoreStockLevel(
          ingredientId: 1,
          storeId: 'store-1',
          totalQty: 5000,
        ),
      ],
    );

    expect(result, isEmpty);
  });

  test('현재 수량이 기준보다 많으면 부족이 아니다', () {
    final result = calculateShortages(
      ingredients: [makeIngredient(1, '양파', 5000)],
      stores: [ulsan],
      levels: [
        const StoreStockLevel(
          ingredientId: 1,
          storeId: 'store-1',
          totalQty: 5001,
        ),
      ],
    );

    expect(result, isEmpty);
  });

  test('한 매장이 부족해도 다른 매장이 충분하면 그 매장만 나온다', () {
    final result = calculateShortages(
      ingredients: [makeIngredient(1, '양파', 5000)],
      stores: [ulsan, busan],
      levels: [
        const StoreStockLevel(
          ingredientId: 1,
          storeId: 'store-2',
          totalQty: 9000,
        ),
      ],
    );

    expect(result, hasLength(1));
    expect(result.single.store.id, 'store-1');
  });

  test('채워진 비율이 낮은 순, 같으면 매장 이름, 그다음 품목 이름 순', () {
    final result = calculateShortages(
      ingredients: [
        makeIngredient(1, '양파', 100),
        makeIngredient(2, '당근', 100),
      ],
      stores: [ulsan, busan],
      levels: [
        // 울산 양파 50%, 부산 양파 0%, 울산 당근 50%, 부산 당근 50%
        const StoreStockLevel(
          ingredientId: 1,
          storeId: 'store-1',
          totalQty: 50,
        ),
        const StoreStockLevel(
          ingredientId: 2,
          storeId: 'store-1',
          totalQty: 50,
        ),
        const StoreStockLevel(
          ingredientId: 2,
          storeId: 'store-2',
          totalQty: 50,
        ),
      ],
    );

    final labels = result
        .map((s) => '${s.store.name}-${s.ingredient.name}')
        .toList();
    expect(labels, ['부산점-양파', '부산점-당근', '울산점-당근', '울산점-양파']);
  });

  test('stores에 한 매장만 넘기면 그 매장 결과만 나온다', () {
    final result = calculateShortages(
      ingredients: [makeIngredient(1, '양파', 5000)],
      stores: [busan],
      levels: [],
    );

    expect(result, hasLength(1));
    expect(result.single.store.id, 'store-2');
  });
}
