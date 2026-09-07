import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'features/count/count_screen.dart';
import 'features/ingredient_management/ingredient_list_screen.dart';
import 'features/inbound/inbound_form_screen.dart';
import 'features/stock_overview/stock_overview_screen.dart';
import 'features/supplier_management/supplier_list_screen.dart';

void main() {
  runApp(const ProviderScope(child: StockControlApp()));
}

class StockControlApp extends StatelessWidget {
  const StockControlApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '재고관리',
      home: const HomeScreen(),
    );
  }
}

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('재고관리')),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ElevatedButton(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const SupplierListScreen()),
              ),
              child: const Text('거래처 관리'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => const IngredientListScreen(),
                ),
              ),
              child: const Text('품목 관리'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const InboundFormScreen()),
              ),
              child: const Text('입고 등록'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => const StockOverviewScreen(),
                ),
              ),
              child: const Text('재고 조회'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const CountScreen()),
              ),
              child: const Text('마감 실사'),
            ),
          ],
        ),
      ),
    );
  }
}
