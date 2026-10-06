import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/local/database.dart';
import '../../domain/stock_shortage.dart';
import 'auth_providers.dart';
import 'dao_providers.dart';
import 'store_providers.dart';

final storesStreamProvider = StreamProvider<List<Store>>(
  (ref) => ref.watch(storeDaoProvider).watchAll(),
);

final ingredientsStreamProvider = StreamProvider<List<Ingredient>>(
  (ref) => ref.watch(ingredientDaoProvider).watchAll(),
);

final stockLevelsStreamProvider = StreamProvider<List<StoreStockLevel>>(
  (ref) => ref.watch(lotDaoProvider).watchStockLevelsByStore(),
);

/// 지금 보고 있는 범위의 부족 목록.
///
/// 판정 대상 매장은 세션 역할에서 직접 끌어낸다. `activeStoreIdProvider`를
/// 쓰지 않는 이유는 그 provider의 null이 "사장의 전체 합산"과 "매장이 없는
/// 직원" 두 가지를 뜻해서, 후자에게 전 매장이 보일 수 있기 때문이다.
final shortagesProvider = Provider<List<StockShortage>>((ref) {
  final session = ref.watch(authSessionProvider);
  if (session == null) return const [];

  final storesAsync = ref.watch(storesStreamProvider);
  final ingredientsAsync = ref.watch(ingredientsStreamProvider);
  final levelsAsync = ref.watch(stockLevelsStreamProvider);

  if (!storesAsync.hasValue ||
      !ingredientsAsync.hasValue ||
      !levelsAsync.hasValue) {
    return const [];
  }

  final allStores = storesAsync.requireValue;
  final ingredients = ingredientsAsync.requireValue;
  final levels = levelsAsync.requireValue;

  final List<Store> stores;
  if (session.isOwner) {
    final selected = ref.watch(selectedStoreProvider);
    stores = selected == null
        ? allStores
        : allStores.where((s) => s.id == selected.id).toList();
  } else {
    final storeId = session.storeId;
    if (storeId == null) return const [];
    stores = allStores.where((s) => s.id == storeId).toList();
  }

  return calculateShortages(
    ingredients: ingredients,
    stores: stores,
    levels: levels,
  );
});

/// 탭 배지용 부족 건수.
final shortageCountProvider = Provider<int>(
  (ref) => ref.watch(shortagesProvider).length,
);
