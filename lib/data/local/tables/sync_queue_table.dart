import 'package:drift/drift.dart';

class SyncQueue extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get targetTable => text()();
  IntColumn get recordId => integer()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
}
