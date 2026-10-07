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

/// 부족 판정을 할 매장. 세션 역할이 범위를 정한다.
///
/// 매장 범위를 `activeStoreIdProvider`에서 끌어오지 않는 이유는 그 provider의
/// null이 "사장의 전체 합산"과 "매장이 없는 직원" 두 가지를 뜻해서, 후자에게
/// 전 매장이 보일 수 있기 때문이다.
///
/// 이 목록이 비면 판정이 한 건도 일어나지 않았다는 뜻이다. 부족이 없는 것과
/// 다르므로 화면이 둘을 구별해 안내할 수 있도록 따로 떼어 둔다.
final shortageStoresProvider = Provider<List<Store>>((ref) {
  final session = ref.watch(authSessionProvider);
  if (session == null) return const [];

  final storesAsync = ref.watch(storesStreamProvider);
  if (!storesAsync.hasValue) return const [];
  final allStores = storesAsync.requireValue;

  if (session.isOwner) {
    final selected = ref.watch(selectedStoreProvider);
    return selected == null
        ? allStores
        : allStores.where((s) => s.id == selected.id).toList();
  }

  final storeId = session.storeId;
  if (storeId == null) return const [];
  return allStores.where((s) => s.id == storeId).toList();
});

/// 지금 보고 있는 범위의 부족 목록.
final shortagesProvider = Provider<List<StockShortage>>((ref) {
  final storesAsync = ref.watch(storesStreamProvider);
  final ingredientsAsync = ref.watch(ingredientsStreamProvider);
  final levelsAsync = ref.watch(stockLevelsStreamProvider);

  // 세 스트림 중 하나라도 아직 로딩 중이면 빈 목록으로 본다. 일부만 들어온
  // 상태로 계산하면 추적 중인 품목이 전부 빈 것처럼 보여 배지에 거짓 숫자가
  // 깜빡인다.
  if (!storesAsync.hasValue ||
      !ingredientsAsync.hasValue ||
      !levelsAsync.hasValue) {
    return const [];
  }

  final stores = ref.watch(shortageStoresProvider);
  if (stores.isEmpty) return const [];

  return calculateShortages(
    ingredients: ingredientsAsync.requireValue,
    stores: stores,
    levels: levelsAsync.requireValue,
  );
});

/// 탭 배지용 부족 건수.
final shortageCountProvider = Provider<int>(
  (ref) => ref.watch(shortagesProvider).length,
);
