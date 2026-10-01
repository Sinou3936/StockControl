import 'package:drift/drift.dart';

import '../database.dart';
import '../tables/stores_table.dart';

part 'store_dao.g.dart';

@DriftAccessor(tables: [Stores])
class StoreDao extends DatabaseAccessor<AppDatabase> with _$StoreDaoMixin {
  StoreDao(super.db);

  Future<void> upsertStore(StoresCompanion entry) =>
      into(stores).insertOnConflictUpdate(entry);

  Stream<List<Store>> watchAll() => select(stores).watch();
}
