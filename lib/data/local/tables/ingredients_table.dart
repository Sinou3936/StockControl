import 'package:drift/drift.dart';

class Ingredients extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text()();
  TextColumn get category => text().nullable()();
  TextColumn get baseUnit => text()();
  TextColumn get purchaseUnit => text()();
  RealColumn get conversionFactor => real()();
  BoolColumn get isExpiryTracked => boolean()();
  RealColumn get safetyStockQty => real().nullable()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
}
