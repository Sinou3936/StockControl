import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../data/local/database.dart';
import '../../data/repositories/store_repository.dart';
import '../../data/services/store_gateway.dart';
import 'auth_providers.dart';
import 'database_provider.dart';

final storeDaoProvider =
    Provider((ref) => ref.watch(appDatabaseProvider).storeDao);

final storeRepositoryProvider = Provider<StoreRepository>((ref) {
  return StoreRepository(
    SupabaseStoreGateway(Supabase.instance.client),
    ref.watch(storeDaoProvider),
  );
});

/// 사장이 상단 드롭다운에서 고른 매장. `null`이면 "전체 합산"을 뜻한다.
/// 직원 세션에서는 이 provider를 쓰지 않는다 — `activeStoreIdProvider`를 보라.
final selectedStoreProvider = StateProvider<Store?>((ref) => null);

/// 지금 화면이 어느 매장 기준으로 동작해야 하는지. 직원은 자기 매장으로
/// 고정, 사장은 `selectedStoreProvider`를 따른다(선택 안 하면 null = 전체
/// 합산). 세 화면(재고 조회/입고 등록/마감 실사)과 `StoreSwitcher`는 이
/// provider 하나만 보면 된다.
final activeStoreIdProvider = Provider<String?>((ref) {
  final session = ref.watch(authSessionProvider);
  if (session == null) return null;
  if (!session.isOwner) return session.storeId;
  return ref.watch(selectedStoreProvider)?.id;
});
