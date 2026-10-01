import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../data/repositories/store_repository.dart';
import '../../data/services/store_gateway.dart';
import 'database_provider.dart';

final storeDaoProvider =
    Provider((ref) => ref.watch(appDatabaseProvider).storeDao);

final storeRepositoryProvider = Provider<StoreRepository>((ref) {
  return StoreRepository(
    SupabaseStoreGateway(Supabase.instance.client),
    ref.watch(storeDaoProvider),
  );
});
