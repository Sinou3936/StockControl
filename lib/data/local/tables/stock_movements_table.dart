import 'package:drift/drift.dart';

import 'lots_table.dart';

class StockMovements extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get lotId => integer().references(Lots, #id)();
  TextColumn get type => text()();
  RealColumn get quantity => real()();
  DateTimeColumn get occurredAt => dateTime()();
  TextColumn get memo => text().nullable()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
}
