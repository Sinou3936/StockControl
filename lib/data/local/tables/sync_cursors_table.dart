import 'package:drift/drift.dart';

class SyncCursors extends Table {
  TextColumn get targetTable => text()();
  DateTimeColumn get lastSyncedAt => dateTime().nullable()();

  @override
  Set<Column> get primaryKey => {targetTable};
}
