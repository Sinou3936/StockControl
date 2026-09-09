import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stockcontrol/data/local/database.dart';
import 'package:stockcontrol/data/repositories/auth_repository.dart';
import 'package:stockcontrol/domain/pin_hash.dart';

import '../../support/fake_auth_gateway.dart';

void main() {
  late AppDatabase db;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
  });

  tearDown(() => db.close());

  test('login succeeds online and caches the profile locally', () async {
    final gateway = FakeAuthGateway()
      ..seedUser(
        id: 'user-1',
        email: 'owner@internal.local',
        password: '123456',
        displayName: '사장님',
        role: 'owner',
      );

    final repository = AuthRepository(gateway, db.cachedProfileDao);

    final result = await repository.login(
      id: 'user-1',
      email: 'owner@internal.local',
      pin: '123456',
    );

    expect(result.outcome, AuthOutcome.success);
    expect(result.displayName, '사장님');
    expect(result.role, 'owner');

    final cached = await db.cachedProfileDao.getById('user-1');
    expect(cached, isNotNull);
    expect(cached!.displayName, '사장님');
  });

  test('falls back to the local cache when the network is unavailable',
      () async {
    await db.cachedProfileDao.upsertProfile(
      CachedProfilesCompanion.insert(
        id: 'user-2',
        displayName: '직원1',
        role: 'staff',
        email: 'staff1@internal.local',
        pinHash: hashPin('567890', 'fixed-salt'),
        pinSalt: 'fixed-salt',
      ),
    );

    final gateway = FakeAuthGateway(throwNetworkError: true);
    final repository = AuthRepository(gateway, db.cachedProfileDao);

    final result = await repository.login(
      id: 'user-2',
      email: 'staff1@internal.local',
      pin: '567890',
    );

    expect(result.outcome, AuthOutcome.success);
    expect(result.displayName, '직원1');
    expect(result.role, 'staff');
  });

  test('rejects an incorrect pin even when using the offline cache',
      () async {
    await db.cachedProfileDao.upsertProfile(
      CachedProfilesCompanion.insert(
        id: 'user-2',
        displayName: '직원1',
        role: 'staff',
        email: 'staff1@internal.local',
        pinHash: hashPin('567890', 'fixed-salt'),
        pinSalt: 'fixed-salt',
      ),
    );

    final gateway = FakeAuthGateway(throwNetworkError: true);
    final repository = AuthRepository(gateway, db.cachedProfileDao);

    final result = await repository.login(
      id: 'user-2',
      email: 'staff1@internal.local',
      pin: '000000',
    );

    expect(result.outcome, AuthOutcome.invalidPin);
  });

  test(
      'reports no offline cache when the device has never logged in '
      'before', () async {
    final gateway = FakeAuthGateway(throwNetworkError: true);
    final repository = AuthRepository(gateway, db.cachedProfileDao);

    final result = await repository.login(
      id: 'user-3',
      email: 'staff2@internal.local',
      pin: '111111',
    );

    expect(result.outcome, AuthOutcome.offlineNoCache);
  });

  test(
      'reports no offline cache when logging in without a known id at all '
      '(first login on a new device)', () async {
    final gateway = FakeAuthGateway(throwNetworkError: true);
    final repository = AuthRepository(gateway, db.cachedProfileDao);

    final result = await repository.login(
      email: 'owner@internal.local',
      pin: '123456',
    );

    expect(result.outcome, AuthOutcome.offlineNoCache);
  });
}
