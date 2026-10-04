import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers/auth_providers.dart';
import '../../core/providers/store_providers.dart';
import '../../data/local/database.dart';

class StoreSwitcher extends ConsumerWidget {
  const StoreSwitcher({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isOwner = ref.watch(authSessionProvider)?.isOwner ?? false;
    if (!isOwner) return const SizedBox.shrink();

    final dao = ref.watch(storeDaoProvider);
    final selected = ref.watch(selectedStoreProvider);

    return StreamBuilder<List<Store>>(
      stream: dao.watchAll(),
      builder: (context, snapshot) {
        final stores = snapshot.data ?? [];
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              border: Border.all(color: const Color(0xFFE2E8F0)),
              borderRadius: BorderRadius.circular(999),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<Store?>(
                key: const Key('storeSwitcherDropdown'),
                value: selected,
                isDense: true,
                borderRadius: BorderRadius.circular(12),
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF334155),
                ),
                items: [
                  const DropdownMenuItem<Store?>(
                    value: null,
                    child: Text('전체 합산'),
                  ),
                  for (final store in stores)
                    DropdownMenuItem<Store?>(
                      value: store,
                      child: Text(store.name),
                    ),
                ],
                onChanged: (value) =>
                    ref.read(selectedStoreProvider.notifier).state = value,
              ),
            ),
          ),
        );
      },
    );
  }
}
