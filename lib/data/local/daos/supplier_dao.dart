import 'package:drift/drift.dart';

import '../../../domain/sync_id.dart';
import '../database.dart';
import '../tables/suppliers_table.dart';

part 'supplier_dao.g.dart';

@DriftAccessor(tables: [Suppliers])
class SupplierDao extends DatabaseAccessor<AppDatabase>
    with _$SupplierDaoMixin {
  SupplierDao(super.db);

  Stream<List<Supplier>> watchAll() => select(suppliers).watch();

  Future<int> insertSupplier(SuppliersCompanion entry) {
    return attachedDatabase.transaction(() async {
      final id = await into(suppliers)
          .insert(entry.copyWith(syncId: Value(generateSyncId())));
      await attachedDatabase.syncQueueDao.enqueue('suppliers', id);
      return id;
    });
  }
}
