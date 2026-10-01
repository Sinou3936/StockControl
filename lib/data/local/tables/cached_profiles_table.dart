import 'package:drift/drift.dart';

class CachedProfiles extends Table {
  TextColumn get id => text()();
  TextColumn get displayName => text()();
  TextColumn get role => text()();
  TextColumn get email => text()();
  TextColumn get pinHash => text()();
  TextColumn get pinSalt => text()();
  TextColumn get storeId => text().nullable()();
  TextColumn get storeName => text().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}
