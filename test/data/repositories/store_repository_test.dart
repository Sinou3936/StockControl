import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stockcontrol/data/local/database.dart';
import 'package:stockcontrol/data/repositories/store_repository.dart';

import '../../support/fake_store_gateway.dart';

void main() {
  late AppDatabase db;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
  });

  tearDown(() => db.close());

  test('addStore writes to the gateway and caches it locally', () async {
    final gateway = FakeStoreGateway();
    final repository = StoreRepository(gateway, db.storeDao);

    await repository.addStore('울산점');

    final cached = await db.storeDao.watchAll().first;
    expect(cached, hasLength(1));
    expect(cached.first.name, '울산점');
    expect(gateway.stores, hasLength(1));
  });

  test('refreshFromServer pulls all gateway stores into the local cache',
      () async {
    final gateway = FakeStoreGateway()
      ..stores.add({'id': 'store-1', 'name': '울산점'})
      ..stores.add({'id': 'store-2', 'name': '부산점'});
    final repository = StoreRepository(gateway, db.storeDao);

    await repository.refreshFromServer();

    final cached = await db.storeDao.watchAll().first;
    expect(cached, hasLength(2));
    expect(cached.map((s) => s.name), containsAll(['울산점', '부산점']));
  });
}
