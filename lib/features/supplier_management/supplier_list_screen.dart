import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers/dao_providers.dart';
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
          final suppliers = snapshot.data ?? [];
          return ListView.builder(
            itemCount: suppliers.length,
            itemBuilder: (context, index) {
              final supplier = suppliers[index];
              return ListTile(
                title: Text(supplier.name),
                subtitle:
                    supplier.contact != null ? Text(supplier.contact!) : null,
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
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
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              decoration: const InputDecoration(labelText: '이름'),
            ),
            TextField(
              controller: contactController,
              decoration: const InputDecoration(labelText: '연락처'),
            ),
          ],
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
