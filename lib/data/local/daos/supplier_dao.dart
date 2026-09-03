import 'package:drift/drift.dart';

import '../database.dart';
import '../tables/suppliers_table.dart';

part 'supplier_dao.g.dart';

@DriftAccessor(tables: [Suppliers])
class SupplierDao extends DatabaseAccessor<AppDatabase>
    with _$SupplierDaoMixin {
  SupplierDao(super.db);

  Stream<List<Supplier>> watchAll() => select(suppliers).watch();

  Future<int> insertSupplier(SuppliersCompanion entry) =>
      into(suppliers).insert(entry);
}
