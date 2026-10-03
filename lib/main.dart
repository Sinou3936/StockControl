import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'core/config/supabase_config.dart';
import 'core/providers/auth_providers.dart';
import 'core/providers/store_providers.dart';
import 'core/providers/sync_providers.dart';
import 'core/shell/app_shell.dart';
import 'features/auth/login_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Supabase.initialize(url: supabaseUrl, publishableKey: supabaseAnonKey);
  runApp(const ProviderScope(child: StockControlApp()));
}

class StockControlApp extends ConsumerStatefulWidget {
  const StockControlApp({super.key});

  @override
  ConsumerState<StockControlApp> createState() => _StockControlAppState();
}

class _StockControlAppState extends ConsumerState<StockControlApp> {
  Timer? _syncTimer;

  @override
  void dispose() {
    _syncTimer?.cancel();
    super.dispose();
  }

  Future<void> _runSync() async {
    final session = ref.read(authSessionProvider);
    if (session == null) return;
    try {
      await ref.read(storeRepositoryProvider).refreshFromServer();
    } catch (_) {
      // 매장 목록을 못 받아도 로컬 데이터 동기화는 계속 진행
    }
    try {
      final repository = ref.read(syncRepositoryProvider);
      await repository.pushPending();
      await repository.pullUpdates(
        isOwner: session.isOwner,
        storeId: session.storeId,
      );
    } catch (_) {
      // 오프라인이거나 서버 오류 — 다음 주기에 재시도
    }
  }

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(authSessionProvider);

    ref.listen(authSessionProvider, (previous, next) {
      if (previous == null && next != null) {
        _runSync();
        _syncTimer?.cancel();
        _syncTimer = Timer.periodic(
          const Duration(seconds: 60),
          (_) => _runSync(),
        );
      }
      if (next == null) {
        _syncTimer?.cancel();
      }
    });

    return MaterialApp(
      title: '재고관리',
      home: session == null ? const LoginScreen() : const AppShell(),
    );
  }
}
