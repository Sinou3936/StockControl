import 'dart:async';

import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stockcontrol/core/providers/auth_providers.dart';
import 'package:stockcontrol/core/providers/database_provider.dart';
import 'package:stockcontrol/core/providers/shortage_providers.dart';
import 'package:stockcontrol/core/providers/store_providers.dart';
import 'package:stockcontrol/data/local/database.dart';
import 'package:stockcontrol/domain/stock_shortage.dart';

void main() {
  late AppDatabase db;
  late int ingredientId;

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    await db.storeDao.upsertStore(
      StoresCompanion.insert(id: 'store-1', name: '울산점'),
    );
    await db.storeDao.upsertStore(
      StoresCompanion.insert(id: 'store-2', name: '부산점'),
    );
    ingredientId = await db.ingredientDao.insertIngredient(
      IngredientsCompanion.insert(
        name: '양파',
        baseUnit: 'g',
        purchaseUnit: '박스',
        conversionFactor: 20000,
        isExpiryTracked: false,
        safetyStockQty: const Value(5000),
      ),
    );
  });

  tearDown(() => db.close());

  ProviderContainer makeContainer(AuthSession? session) {
    final container = ProviderContainer(
      overrides: [appDatabaseProvider.overrideWithValue(db)],
    );
    addTearDown(container.dispose);
    if (session != null) {
      container.read(authSessionProvider.notifier).setSession(session);
    }
    return container;
  }

  AuthSession owner() => AuthSession(
        id: 'owner-1',
        email: 'owner@internal.local',
        pin: '123456',
        displayName: '사장님',
        role: 'owner',
      );

  AuthSession staff({String? storeId}) => AuthSession(
        id: 'staff-1',
        email: 'staff@internal.local',
        pin: '111111',
        displayName: '직원1',
        role: 'staff',
        storeId: storeId,
        storeName: storeId == null ? null : '울산점',
      );

  /// 세 스트림이 첫 값을 내보낼 때까지 흘려보낸다.
  Future<void> settle(ProviderContainer container) async {
    container.listen(storesStreamProvider, (_, _) {});
    container.listen(ingredientsStreamProvider, (_, _) {});
    container.listen(stockLevelsStreamProvider, (_, _) {});
    await Future<void>.delayed(const Duration(milliseconds: 50));
  }

  test('사장이 전체를 보면 모든 매장의 부족이 나온다', () async {
    final container = makeContainer(owner());
    await settle(container);

    final shortages = container.read(shortagesProvider);

    expect(shortages, hasLength(2));
    expect(
      shortages.map((s) => s.store.id).toSet(),
      {'store-1', 'store-2'},
    );
    expect(container.read(shortageCountProvider), 2);
  });

  test('사장이 매장을 고르면 그 매장만 나온다', () async {
    final container = makeContainer(owner());
    await settle(container);

    container.read(selectedStoreProvider.notifier).state =
        const Store(id: 'store-1', name: '울산점');

    final shortages = container.read(shortagesProvider);

    expect(shortages, hasLength(1));
    expect(shortages.single.store.id, 'store-1');
  });

  test('직원은 자기 매장 것만 본다', () async {
    final container = makeContainer(staff(storeId: 'store-2'));
    await settle(container);

    final shortages = container.read(shortagesProvider);

    expect(shortages, hasLength(1));
    expect(shortages.single.store.id, 'store-2');
  });

  test('매장이 지정되지 않은 직원에게는 아무것도 보이지 않는다', () async {
    final container = makeContainer(staff());
    await settle(container);

    expect(container.read(shortagesProvider), isEmpty);
  });

  test('로그인하지 않으면 빈 목록이다', () async {
    final container = makeContainer(null);
    await settle(container);

    expect(container.read(shortagesProvider), isEmpty);
  });

  test('재고가 기준 이상이면 그 매장은 빠진다', () async {
    await db.lotDao.insertLot(
      LotsCompanion.insert(
        ingredientId: ingredientId,
        storeId: const Value('store-1'),
        receivedDate: DateTime(2026, 10, 1),
        unitCost: 10,
        remainingQty: 9000,
      ),
    );

    final container = makeContainer(owner());
    await settle(container);

    final shortages = container.read(shortagesProvider);

    expect(shortages, hasLength(1));
    expect(shortages.single.store.id, 'store-2');
  });

  // 세 스트림을 각각 따로 막는다. 하나만 확인하면 나머지 두 가드 절을 지워도
  // 테스트가 통과해서, 일부 데이터로 계산하는 회귀를 잡지 못한다.
  Stream<T> neverEmits<T>() => Stream.fromFuture(Completer<T>().future);

  test('재고 합계 스트림이 로딩 중이면 빈 목록을 반환한다', () async {
    final container = ProviderContainer(
      overrides: [
        appDatabaseProvider.overrideWithValue(db),
        stockLevelsStreamProvider.overrideWith(
          (_) => neverEmits<List<StoreStockLevel>>(),
        ),
      ],
    );
    addTearDown(container.dispose);
    container.read(authSessionProvider.notifier).setSession(owner());
    await settle(container);

    expect(container.read(shortagesProvider), isEmpty);
  });

  test('품목 스트림이 로딩 중이면 빈 목록을 반환한다', () async {
    final container = ProviderContainer(
      overrides: [
        appDatabaseProvider.overrideWithValue(db),
        ingredientsStreamProvider.overrideWith(
          (_) => neverEmits<List<Ingredient>>(),
        ),
      ],
    );
    addTearDown(container.dispose);
    container.read(authSessionProvider.notifier).setSession(owner());
    await settle(container);

    expect(container.read(shortagesProvider), isEmpty);
  });

  test('매장 스트림이 로딩 중이면 빈 목록을 반환한다', () async {
    final container = ProviderContainer(
      overrides: [
        appDatabaseProvider.overrideWithValue(db),
        storesStreamProvider.overrideWith((_) => neverEmits<List<Store>>()),
      ],
    );
    addTearDown(container.dispose);
    container.read(authSessionProvider.notifier).setSession(owner());
    await settle(container);

    expect(container.read(shortagesProvider), isEmpty);
  });
}
