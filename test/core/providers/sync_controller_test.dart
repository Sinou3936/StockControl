import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stockcontrol/core/providers/auth_providers.dart';
import 'package:stockcontrol/core/providers/database_provider.dart';
import 'package:stockcontrol/core/providers/store_providers.dart';
import 'package:stockcontrol/core/providers/sync_providers.dart';
import 'package:stockcontrol/data/local/database.dart';
import 'package:stockcontrol/data/repositories/store_repository.dart';
import 'package:stockcontrol/data/repositories/sync_repository.dart';

import '../../support/fake_store_gateway.dart';
import '../../support/fake_sync_gateway.dart';

void main() {
  late AppDatabase db;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
  });

  tearDown(() => db.close());

  ProviderContainer makeContainer(FakeSyncGateway gateway,
      {bool loggedIn = true}) {
    final container = ProviderContainer(
      overrides: [
        appDatabaseProvider.overrideWithValue(db),
        syncRepositoryProvider
            .overrideWithValue(SyncRepository(gateway, db)),
        storeRepositoryProvider.overrideWithValue(
          StoreRepository(FakeStoreGateway(), db.storeDao),
        ),
      ],
    );
    addTearDown(container.dispose);
    if (loggedIn) {
      container.read(authSessionProvider.notifier).setSession(
            AuthSession(
              id: 'user-1',
              email: 'owner@internal.local',
              pin: '123456',
              displayName: '사장님',
              role: 'owner',
            ),
          );
    }
    return container;
  }

  test('sync pushes the queue and records the last synced time', () async {
    final gateway = FakeSyncGateway();
    final container = makeContainer(gateway);
    await db.supplierDao.insertSupplier(
      SuppliersCompanion.insert(name: '거래처A'),
    );

    await container.read(syncControllerProvider.notifier).sync();

    final status = container.read(syncControllerProvider);
    expect(gateway.upsertedPayloads, hasLength(1));
    expect(status.isSyncing, isFalse);
    expect(status.lastSyncedAt, isNotNull);
    expect(status.errorMessage, isNull);
  });

  test('sync reports an error and keeps the previous time when pushing fails',
      () async {
    final gateway = FakeSyncGateway(failUpsertAfter: 0);
    final container = makeContainer(gateway);
    await db.supplierDao.insertSupplier(
      SuppliersCompanion.insert(name: '거래처A'),
    );

    await container.read(syncControllerProvider.notifier).sync();

    final status = container.read(syncControllerProvider);
    expect(status.errorMessage, isNotNull);
    expect(status.lastSyncedAt, isNull);
    expect(await db.syncQueueDao.oldest(), isNotNull);
  });

  test('sync does nothing when nobody is logged in', () async {
    final gateway = FakeSyncGateway();
    final container = makeContainer(gateway, loggedIn: false);
    await db.supplierDao.insertSupplier(
      SuppliersCompanion.insert(name: '거래처A'),
    );

    await container.read(syncControllerProvider.notifier).sync();

    expect(gateway.upsertedPayloads, isEmpty);
    expect(container.read(syncControllerProvider).lastSyncedAt, isNull);
  });
}
