import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers/dao_providers.dart';
import '../../core/widgets/app_widgets.dart';
import '../../data/local/daos/supplier_dao.dart';
import '../../data/local/database.dart';

class SupplierListScreen extends ConsumerWidget {
  const SupplierListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dao = ref.watch(supplierDaoProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('거래처 관리')),
      body: StreamBuilder<List<Supplier>>(
        stream: dao.watchAll(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const SizedBox.shrink();
          final suppliers = snapshot.data!;
          if (suppliers.isEmpty) {
            return const EmptyState(
              icon: Icons.local_shipping_outlined,
              title: '등록된 거래처가 없습니다',
              message: '오른쪽 아래 + 버튼으로 거래처를 추가하세요',
            );
          }

          return CenteredContent(
            child: ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 88),
              itemCount: suppliers.length,
              separatorBuilder: (_, _) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                final supplier = suppliers[index];
                return AppListCard(
                  title: supplier.name,
                  subtitle: supplier.contact,
                );
              },
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        // 데스크톱에서는 IndexedStack이 거래처·품목 화면을 동시에 살려두므로
        // 기본 Hero 태그를 쓰면 화면 전환 때 태그가 충돌해 예외가 난다.
        heroTag: 'supplierAddFab',
        onPressed: () => _showAddDialog(context, dao),
        child: const Icon(Icons.add),
      ),
    );
  }

  Future<void> _showAddDialog(BuildContext context, SupplierDao dao) async {
    final nameController = TextEditingController();
    final contactController = TextEditingController();

    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('거래처 등록'),
        content: SizedBox(
          width: 380,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: const InputDecoration(labelText: '이름'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: contactController,
                decoration: const InputDecoration(labelText: '연락처'),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('취소'),
          ),
          TextButton(
            onPressed: () async {
              if (nameController.text.trim().isEmpty) return;
              await dao.insertSupplier(
                SuppliersCompanion.insert(
                  name: nameController.text.trim(),
                  contact: Value(
                    contactController.text.trim().isEmpty
                        ? null
                        : contactController.text.trim(),
                  ),
                ),
              );
              if (context.mounted) Navigator.of(context).pop();
            },
            child: const Text('저장'),
          ),
        ],
      ),
    );
  }
}
