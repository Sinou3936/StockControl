import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/ingredient_management/ingredient_list_screen.dart';
import '../../features/supplier_management/supplier_list_screen.dart';
import '../providers/auth_providers.dart';
import 'auth_add_staff_route.dart';

class MoreScreen extends ConsumerWidget {
  const MoreScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(authSessionProvider);

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
          if (session?.isOwner ?? false)
            ListTile(
              title: const Text('직원 추가'),
              onTap: () => pushAddStaffScreen(context),
            ),
          ListTile(
            title: const Text('로그아웃'),
            onTap: () => ref.read(authSessionProvider.notifier).clear(),
          ),
        ],
      ),
    );
  }
}
