import 'package:supabase_flutter/supabase_flutter.dart';

abstract class SyncGateway {
  Future<void> upsert(String tableName, Map<String, dynamic> payload);
  Future<List<Map<String, dynamic>>> fetchSince(
    String tableName,
    DateTime? since, {
    String? storeId,
  });
}

class SupabaseSyncGateway implements SyncGateway {
  SupabaseSyncGateway(this._client);

  final SupabaseClient _client;

  @override
  Future<void> upsert(String tableName, Map<String, dynamic> payload) async {
    await _client.from(tableName).upsert(payload);
  }

  @override
  Future<List<Map<String, dynamic>>> fetchSince(
    String tableName,
    DateTime? since, {
    String? storeId,
  }) async {
    var query = _client.from(tableName).select();
    if (since != null) {
      query = query.gt('synced_at', since.toIso8601String());
    }
    if (storeId != null) {
      query = query.eq('store_id', storeId);
    }
    return query;
  }
}
