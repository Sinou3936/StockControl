import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stockcontrol/core/providers/auth_providers.dart';
import 'package:stockcontrol/core/providers/store_providers.dart';
import 'package:stockcontrol/data/local/database.dart';

void main() {
  late AppDatabase db;
  late ProviderContainer container;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    container = ProviderContainer();
  });

  tearDown(() {
    container.dispose();
    db.close();
  });

  test('is null when there is no session', () {
    expect(container.read(activeStoreIdProvider), isNull);
  });

  test('is the session store id for a staff session', () {
    container.read(authSessionProvider.notifier).setSession(
          AuthSession(
            id: 'user-1',
            email: 'staff1@internal.local',
            pin: '111111',
            displayName: '직원1',
            role: 'staff',
            storeId: 'store-1',
            storeName: '울산점',
          ),
        );

    expect(container.read(activeStoreIdProvider), 'store-1');
  });

  test('is null for an owner until a store is selected', () async {
    container.read(authSessionProvider.notifier).setSession(
          AuthSession(
            id: 'user-owner',
            email: 'owner@internal.local',
            pin: '123456',
            displayName: '사장님',
            role: 'owner',
          ),
        );

    expect(container.read(activeStoreIdProvider), isNull);

    await db.storeDao.upsertStore(
      StoresCompanion.insert(id: 'store-1', name: '울산점'),
    );
    final store = (await db.storeDao.watchAll().first).first;
    container.read(selectedStoreProvider.notifier).state = store;

    expect(container.read(activeStoreIdProvider), 'store-1');
  });
}
