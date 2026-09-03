import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/repositories/lot_repository.dart';
import 'database_provider.dart';

final lotRepositoryProvider = Provider<LotRepository>((ref) {
  return LotRepository(ref.watch(appDatabaseProvider));
});
