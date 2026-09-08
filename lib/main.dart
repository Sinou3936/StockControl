import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/shell/app_shell.dart';

void main() {
  runApp(const ProviderScope(child: StockControlApp()));
}

class StockControlApp extends StatelessWidget {
  const StockControlApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '재고관리',
      home: const AppShell(),
    );
  }
}
