import 'package:drift/drift.dart';

import '../database.dart';
import '../tables/lots_table.dart';

part 'lot_dao.g.dart';

@DriftAccessor(tables: [Lots])
class LotDao extends DatabaseAccessor<AppDatabase> with _$LotDaoMixin {
  LotDao(super.db);

  Future<int> insertLot(LotsCompanion entry) => into(lots).insert(entry);

  Future<Lot> getById(int id) =>
      (select(lots)..where((l) => l.id.equals(id))).getSingle();

  Future<void> updateRemainingQty(int id, double remainingQty) =>
      (update(lots)..where((l) => l.id.equals(id))).write(
        LotsCompanion(remainingQty: Value(remainingQty)),
      );

  Stream<List<Lot>> watchLotsForIngredient(int ingredientId) =>
      (select(lots)..where((l) => l.ingredientId.equals(ingredientId)))
          .watch();
}
