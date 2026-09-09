import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stockcontrol/data/local/database.dart';

void main() {
  late AppDatabase db;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
  });

  tearDown(() => db.close());

  test('upserts a profile and reads it back by id', () async {
    await db.cachedProfileDao.upsertProfile(
      CachedProfilesCompanion.insert(
        id: 'user-1',
        displayName: '테스터',
        role: 'owner',
        email: 'user-1@internal.local',
        pinHash: 'hash-a',
        pinSalt: 'salt-a',
      ),
    );

    final profile = await db.cachedProfileDao.getById('user-1');

    expect(profile, isNotNull);
    expect(profile!.displayName, '테스터');
    expect(profile.role, 'owner');
  });

  test('upsert replaces an existing profile with the same id', () async {
    await db.cachedProfileDao.upsertProfile(
      CachedProfilesCompanion.insert(
        id: 'user-1',
        displayName: '테스터',
        role: 'owner',
        email: 'user-1@internal.local',
        pinHash: 'hash-a',
        pinSalt: 'salt-a',
      ),
    );
    await db.cachedProfileDao.upsertProfile(
      CachedProfilesCompanion.insert(
        id: 'user-1',
        displayName: '테스터',
        role: 'owner',
        email: 'user-1@internal.local',
        pinHash: 'hash-b',
        pinSalt: 'salt-b',
      ),
    );

    final profile = await db.cachedProfileDao.getById('user-1');
    expect(profile!.pinHash, 'hash-b');

    final all = await db.cachedProfileDao.watchAll().first;
    expect(all, hasLength(1));
  });
}
