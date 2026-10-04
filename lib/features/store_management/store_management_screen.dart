import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers/store_providers.dart';
import '../../core/widgets/app_widgets.dart';
import '../../data/local/database.dart';
import '../../data/repositories/store_repository.dart';

class StoreManagementScreen extends ConsumerWidget {
  const StoreManagementScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dao = ref.watch(storeDaoProvider);
    final repository = ref.watch(storeRepositoryProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('매장 관리')),
      body: StreamBuilder<List<Store>>(
        stream: dao.watchAll(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const SizedBox.shrink();
          final stores = snapshot.data!;
          if (stores.isEmpty) {
            return const EmptyState(
              icon: Icons.store_mall_directory_outlined,
              title: '등록된 매장이 없습니다',
              message: '오른쪽 아래 + 버튼으로 매장을 추가하세요',
            );
          }

          return CenteredContent(
            child: ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 88),
              itemCount: stores.length,
              separatorBuilder: (_, _) => const SizedBox(height: 12),
              itemBuilder: (context, index) =>
                  AppListCard(title: stores[index].name),
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddDialog(context, repository),
        child: const Icon(Icons.add),
      ),
    );
  }

  Future<void> _showAddDialog(
    BuildContext context,
    StoreRepository repository,
  ) async {
    final nameController = TextEditingController();

    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('매장 등록'),
        content: SizedBox(
          width: 380,
          child: TextField(
            key: const Key('newStoreNameField'),
            controller: nameController,
            decoration: const InputDecoration(labelText: '매장 이름'),
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
              await repository.addStore(nameController.text.trim());
              if (context.mounted) Navigator.of(context).pop();
            },
            child: const Text('저장'),
          ),
        ],
      ),
    );
  }
}
