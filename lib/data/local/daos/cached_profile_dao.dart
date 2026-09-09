import 'package:drift/drift.dart';

import '../database.dart';
import '../tables/cached_profiles_table.dart';

part 'cached_profile_dao.g.dart';

@DriftAccessor(tables: [CachedProfiles])
class CachedProfileDao extends DatabaseAccessor<AppDatabase>
    with _$CachedProfileDaoMixin {
  CachedProfileDao(super.db);

  Future<void> upsertProfile(CachedProfilesCompanion entry) =>
      into(cachedProfiles).insertOnConflictUpdate(entry);

  Future<CachedProfile?> getById(String id) =>
      (select(cachedProfiles)..where((p) => p.id.equals(id)))
          .getSingleOrNull();

  Stream<List<CachedProfile>> watchAll() => select(cachedProfiles).watch();
}
