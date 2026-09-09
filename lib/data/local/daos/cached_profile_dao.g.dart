// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'cached_profile_dao.dart';

// ignore_for_file: type=lint
mixin _$CachedProfileDaoMixin on DatabaseAccessor<AppDatabase> {
  $CachedProfilesTable get cachedProfiles => attachedDatabase.cachedProfiles;
  CachedProfileDaoManager get managers => CachedProfileDaoManager(this);
}

class CachedProfileDaoManager {
  final _$CachedProfileDaoMixin _db;
  CachedProfileDaoManager(this._db);
  $$CachedProfilesTableTableManager get cachedProfiles =>
      $$CachedProfilesTableTableManager(
        _db.attachedDatabase,
        _db.cachedProfiles,
      );
}
