import 'package:flutter/material.dart';

import '../../features/ingredient_management/ingredient_list_screen.dart';
import '../../features/supplier_management/supplier_list_screen.dart';

class MoreScreen extends StatelessWidget {
  const MoreScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('더보기')),
      body: ListView(
        children: [
          ListTile(
            title: const Text('거래처 관리'),
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const SupplierListScreen()),
            ),
          ),
          ListTile(
            title: const Text('품목 관리'),
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => const IngredientListScreen(),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
