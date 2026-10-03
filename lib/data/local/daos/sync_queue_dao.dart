import 'package:drift/drift.dart';

import '../database.dart';
import '../tables/sync_queue_table.dart';

part 'sync_queue_dao.g.dart';

@DriftAccessor(tables: [SyncQueue])
class SyncQueueDao extends DatabaseAccessor<AppDatabase>
    with _$SyncQueueDaoMixin {
  SyncQueueDao(super.db);

  Future<void> enqueue(String tableName, int recordId) => into(syncQueue)
      .insert(SyncQueueCompanion.insert(targetTable: tableName, recordId: recordId));

  Future<SyncQueueData?> oldest() =>
      (select(syncQueue)..orderBy([(t) => OrderingTerm.asc(t.id)])..limit(1))
          .getSingleOrNull();

  Future<void> remove(int id) =>
      (delete(syncQueue)..where((t) => t.id.equals(id))).go();
}
