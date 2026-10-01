import 'package:drift/drift.dart' hide isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stockcontrol/data/local/database.dart';

void main() {
  late AppDatabase db;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
  });

  tearDown(() => db.close());

  test('inserts a supplier and reads it back via watchAll', () async {
    await db.supplierDao.insertSupplier(
      SuppliersCompanion.insert(name: '테스트거래처'),
    );

    final suppliers = await db.supplierDao.watchAll().first;

    expect(suppliers, hasLength(1));
    expect(suppliers.first.name, '테스트거래처');
  });

  test('insertSupplier always generates a fresh syncId, overriding any '
      'caller-provided value, and keeps other fields intact', () async {
    final id = await db.supplierDao.insertSupplier(
      SuppliersCompanion.insert(
        name: '거래처A',
        contact: const Value('010-0000-0000'),
        syncId: const Value('caller-provided-should-be-ignored'),
      ),
    );

    final suppliers = await db.supplierDao.watchAll().first;
    final saved = suppliers.firstWhere((s) => s.id == id);

    expect(saved.syncId, isNotNull);
    expect(saved.syncId, isNot('caller-provided-should-be-ignored'));
    expect(saved.name, '거래처A');
    expect(saved.contact, '010-0000-0000');
  });

  test('insertSupplier produces a different syncId for each call', () async {
    await db.supplierDao.insertSupplier(
      SuppliersCompanion.insert(name: '거래처B'),
    );
    await db.supplierDao.insertSupplier(
      SuppliersCompanion.insert(name: '거래처C'),
    );

    final suppliers = await db.supplierDao.watchAll().first;
    final syncIds = suppliers.map((s) => s.syncId).toSet();

    expect(syncIds, hasLength(suppliers.length));
  });
}
