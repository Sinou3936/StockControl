import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers/store_providers.dart';
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
          final stores = snapshot.data ?? [];
          return ListView.builder(
            itemCount: stores.length,
            itemBuilder: (context, index) {
              final store = stores[index];
              return ListTile(title: Text(store.name));
            },
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
        content: TextField(
          key: const Key('newStoreNameField'),
          controller: nameController,
          decoration: const InputDecoration(labelText: '매장 이름'),
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
