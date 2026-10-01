import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stockcontrol/data/local/database.dart';

void main() {
  late AppDatabase db;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
  });

  tearDown(() => db.close());

  test('upserts a store and reads it back', () async {
    await db.storeDao.upsertStore(
      StoresCompanion.insert(id: 'store-1', name: '울산점'),
    );

    final all = await db.storeDao.watchAll().first;

    expect(all, hasLength(1));
    expect(all.first.name, '울산점');
  });

  test('upsert replaces an existing store with the same id', () async {
    await db.storeDao.upsertStore(
      StoresCompanion.insert(id: 'store-1', name: '울산점'),
    );
    await db.storeDao.upsertStore(
      StoresCompanion.insert(id: 'store-1', name: '울산점(개명)'),
    );

    final all = await db.storeDao.watchAll().first;

    expect(all, hasLength(1));
    expect(all.first.name, '울산점(개명)');
  });
}
