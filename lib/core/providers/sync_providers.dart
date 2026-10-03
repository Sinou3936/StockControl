import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../data/repositories/sync_repository.dart';
import '../../data/services/sync_gateway.dart';
import 'database_provider.dart';

final syncRepositoryProvider = Provider<SyncRepository>((ref) {
  return SyncRepository(
    SupabaseSyncGateway(Supabase.instance.client),
    ref.watch(appDatabaseProvider),
  );
});
