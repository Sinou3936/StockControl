import 'package:stockcontrol/data/services/sync_gateway.dart';

class FakeSyncGateway implements SyncGateway {
  FakeSyncGateway({this.failUpsertAfter});

  /// 이 횟수만큼 upsert가 성공한 다음부터는 매번 실패하도록 — push 중단 동작
  /// 테스트용. null이면 항상 성공.
  final int? failUpsertAfter;
  int _upsertCount = 0;

  final List<Map<String, dynamic>> upsertedPayloads = [];
  final Map<String, List<Map<String, dynamic>>> tableRows = {};

  @override
  Future<void> upsert(String tableName, Map<String, dynamic> payload) async {
    if (failUpsertAfter != null && _upsertCount >= failUpsertAfter!) {
      throw Exception('시뮬레이션된 네트워크 오류');
    }
    _upsertCount++;
    upsertedPayloads.add(payload);

    final rows = tableRows.putIfAbsent(tableName, () => []);
    final existingIndex =
        rows.indexWhere((r) => r['id'] == payload['id']);
    if (existingIndex >= 0) {
      rows[existingIndex] = payload;
    } else {
      rows.add(payload);
    }
  }

  @override
  Future<List<Map<String, dynamic>>> fetchSince(
    String tableName,
    DateTime? since, {
    String? storeId,
  }) async {
    final rows = tableRows[tableName] ?? [];
    return rows.where((row) {
      if (since != null) {
        final createdAt = DateTime.parse(row['created_at'] as String);
        if (!createdAt.isAfter(since)) return false;
      }
      if (storeId != null && row['store_id'] != storeId) return false;
      return true;
    }).toList();
  }
}
