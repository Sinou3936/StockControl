import 'package:drift/drift.dart';

import '../database.dart';
import '../tables/sync_cursors_table.dart';

part 'sync_cursor_dao.g.dart';

@DriftAccessor(tables: [SyncCursors])
class SyncCursorDao extends DatabaseAccessor<AppDatabase>
    with _$SyncCursorDaoMixin {
  SyncCursorDao(super.db);

  Future<DateTime?> getLastSyncedAt(String tableName) async {
    final row = await (select(syncCursors)
          ..where((t) => t.targetTable.equals(tableName)))
        .getSingleOrNull();
    return row?.lastSyncedAt;
  }

  Future<void> setLastSyncedAt(String tableName, DateTime value) =>
      into(syncCursors).insertOnConflictUpdate(
        SyncCursorsCompanion.insert(
          targetTable: tableName,
          lastSyncedAt: Value(value),
        ),
      );
}
