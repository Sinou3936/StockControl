import 'package:drift/drift.dart';

import 'ingredients_table.dart';
import 'suppliers_table.dart';

class Lots extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get ingredientId => integer().references(Ingredients, #id)();
  IntColumn get supplierId =>
      integer().nullable().references(Suppliers, #id)();
  DateTimeColumn get receivedDate => dateTime()();
  DateTimeColumn get expiryDate => dateTime().nullable()();
  RealColumn get unitCost => real()();
  RealColumn get remainingQty => real()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
}
