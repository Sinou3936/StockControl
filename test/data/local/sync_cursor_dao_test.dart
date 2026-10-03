import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stockcontrol/data/local/database.dart';

void main() {
  late AppDatabase db;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
  });

  tearDown(() => db.close());

  test('returns null when a table has never been synced', () async {
    expect(await db.syncCursorDao.getLastSyncedAt('lots'), isNull);
  });

  test('setLastSyncedAt then getLastSyncedAt round-trips the value',
      () async {
    final when = DateTime(2026, 10, 1, 12);
    await db.syncCursorDao.setLastSyncedAt('lots', when);

    expect(await db.syncCursorDao.getLastSyncedAt('lots'), when);
  });

  test('setLastSyncedAt overwrites a previous value for the same table',
      () async {
    await db.syncCursorDao.setLastSyncedAt('lots', DateTime(2026, 10, 1));
    await db.syncCursorDao.setLastSyncedAt('lots', DateTime(2026, 10, 2));

    expect(
      await db.syncCursorDao.getLastSyncedAt('lots'),
      DateTime(2026, 10, 2),
    );
  });
}
