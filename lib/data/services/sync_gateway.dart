import 'package:supabase_flutter/supabase_flutter.dart';

abstract class SyncGateway {
  Future<void> upsert(String tableName, Map<String, dynamic> payload);
  Future<List<Map<String, dynamic>>> fetchSince(
    String tableName,
    DateTime? since, {
    String? storeId,
  });
}

/// 서버는 시간대 표시가 없는 시각을 UTC로 해석한다. 로컬 시각을 그대로
/// 보내면 한국에서는 9시간 어긋나므로 항상 UTC(Z)로 바꿔서 보낸다.
String cursorToIso(DateTime since) => since.toUtc().toIso8601String();

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
      query = query.gt('synced_at', cursorToIso(since));
    }
    if (storeId != null) {
      query = query.eq('store_id', storeId);
    }
    // 서버는 한 번에 최대 1000행만 주므로, 오래된 것부터 받아야 커서가 안전하게 전진한다.
    return query.order('synced_at', ascending: true);
  }
}
