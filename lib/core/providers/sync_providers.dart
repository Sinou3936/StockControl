import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../data/repositories/sync_repository.dart';
import '../../data/services/sync_gateway.dart';
import 'auth_providers.dart';
import 'database_provider.dart';
import 'store_providers.dart';

final syncRepositoryProvider = Provider<SyncRepository>((ref) {
  return SyncRepository(
    SupabaseSyncGateway(Supabase.instance.client),
    ref.watch(appDatabaseProvider),
  );
});

/// 아직 서버로 못 보낸 변경 건수. 늘어나면(= 방금 저장이 일어나면) 바로
/// 동기화를 돌리는 신호로 쓴다.
final pendingSyncCountProvider = StreamProvider<int>((ref) {
  return ref.watch(appDatabaseProvider).syncQueueDao.watchPendingCount();
});

class SyncStatus {
  const SyncStatus({
    this.isSyncing = false,
    this.lastSyncedAt,
    this.errorMessage,
  });

  final bool isSyncing;
  final DateTime? lastSyncedAt;
  final String? errorMessage;

  String get description {
    if (isSyncing) return '동기화 중...';
    if (errorMessage != null) return errorMessage!;
    final at = lastSyncedAt;
    if (at == null) return '아직 동기화하지 않았습니다';
    String two(int n) => n.toString().padLeft(2, '0');
    return '마지막 동기화 ${two(at.hour)}:${two(at.minute)}:${two(at.second)}';
  }
}

class SyncController extends StateNotifier<SyncStatus> {
  SyncController(this._ref) : super(const SyncStatus());

  final Ref _ref;
  bool _rerunRequested = false;

  /// 매장 목록 갱신 → 올리기 → 내려받기 순으로 한 번 돌린다. 이미 돌고 있으면
  /// 끝난 직후 한 번 더 돌도록 예약만 한다(저장이 동기화 도중에 일어난 경우).
  Future<void> sync() async {
    final session = _ref.read(authSessionProvider);
    if (session == null) return;
    if (state.isSyncing) {
      _rerunRequested = true;
      return;
    }

    state = SyncStatus(
      isSyncing: true,
      lastSyncedAt: state.lastSyncedAt,
    );

    String? error;
    try {
      await _ref.read(storeRepositoryProvider).refreshFromServer();
    } catch (_) {
      // 매장 목록을 못 받아도 재고 동기화는 계속 진행
    }
    try {
      final repository = _ref.read(syncRepositoryProvider);
      final drained = await repository.pushPending();
      await repository.pullUpdates(
        isOwner: session.isOwner,
        storeId: session.storeId,
      );
      if (!drained) error = '일부 변경을 서버로 보내지 못했습니다';
    } catch (_) {
      error = '서버에 연결할 수 없습니다';
    }

    if (!mounted) return;
    state = SyncStatus(
      lastSyncedAt: error == null ? DateTime.now() : state.lastSyncedAt,
      errorMessage: error,
    );

    if (_rerunRequested) {
      _rerunRequested = false;
      await sync();
    }
  }
}

final syncControllerProvider =
    StateNotifierProvider<SyncController, SyncStatus>(
  (ref) => SyncController(ref),
);
