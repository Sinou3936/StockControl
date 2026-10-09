import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'core/config/supabase_config.dart';
import 'core/l10n/app_locale.dart';
import 'core/providers/auth_providers.dart';
import 'core/providers/sync_providers.dart';
import 'core/shell/app_shell.dart';
import 'core/theme/app_theme.dart';
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

  void _runSync() => ref.read(syncControllerProvider.notifier).sync();

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

    // 저장이 일어나 큐가 늘어나면 60초를 기다리지 않고 바로 동기화한다.
    ref.listen(pendingSyncCountProvider, (previous, next) {
      final before = previous?.valueOrNull ?? 0;
      final after = next.valueOrNull ?? 0;
      if (after > before) _runSync();
    });

    return MaterialApp(
      title: '재고관리',
      theme: AppTheme.light(),
      locale: appLocale,
      supportedLocales: appSupportedLocales,
      localizationsDelegates: appLocalizationsDelegates,
      home: session == null ? const LoginScreen() : const AppShell(),
    );
  }
}
