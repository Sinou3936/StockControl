import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers/auth_providers.dart';
import '../../core/providers/store_providers.dart';
import '../../data/local/database.dart';

class AddStaffScreen extends ConsumerStatefulWidget {
  const AddStaffScreen({super.key});

  @override
  ConsumerState<AddStaffScreen> createState() => _AddStaffScreenState();
}

class _AddStaffScreenState extends ConsumerState<AddStaffScreen> {
  final _nameController = TextEditingController();
  final _pinController = TextEditingController();
  Store? _selectedStore;
  String? _errorText;

  @override
  void dispose() {
    _nameController.dispose();
    _pinController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final dao = ref.watch(storeDaoProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('직원 추가')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              key: const Key('newStaffNameField'),
              controller: _nameController,
              decoration: const InputDecoration(labelText: '이름'),
            ),
            TextField(
              key: const Key('newStaffPinField'),
              controller: _pinController,
              obscureText: true,
              keyboardType: TextInputType.number,
              maxLength: 6,
              decoration: const InputDecoration(labelText: 'PIN (6자리)'),
            ),
            StreamBuilder<List<Store>>(
              stream: dao.watchAll(),
              builder: (context, snapshot) {
                final stores = snapshot.data ?? [];
                return DropdownButton<Store>(
                  key: const Key('newStaffStoreDropdown'),
                  hint: const Text('소속 매장 선택'),
                  value: _selectedStore,
                  items: [
                    for (final store in stores)
                      DropdownMenuItem(
                        value: store,
                        child: Text(store.name),
                      ),
                  ],
                  onChanged: (store) =>
                      setState(() => _selectedStore = store),
                );
              },
            ),
            if (_errorText != null)
              Text(_errorText!, style: const TextStyle(color: Colors.red)),
            const SizedBox(height: 16),
            ElevatedButton(onPressed: _submit, child: const Text('추가')),
          ],
        ),
      ),
    );
  }

  Future<void> _submit() async {
    final name = _nameController.text.trim();
    final pin = _pinController.text.trim();
    final store = _selectedStore;

    if (name.isEmpty || pin.length != 6 || store == null) {
      setState(() => _errorText = '이름, 6자리 PIN, 매장을 모두 입력하세요');
      return;
    }

    final owner = ref.read(authSessionProvider);
    if (owner == null) return;

    setState(() => _errorText = null);

    try {
      await ref.read(authRepositoryProvider).addStaff(
            displayName: name,
            pin: pin,
            ownerEmail: owner.email,
            ownerPin: owner.pin,
            storeId: store.id,
            storeName: store.name,
          );
    } catch (e) {
      setState(() => _errorText = '직원 추가에 실패했습니다: $e');
      return;
    }

    if (mounted) Navigator.of(context).pop();
  }
}
