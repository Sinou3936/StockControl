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
}
