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
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: DropdownButton<Store?>(
            key: const Key('storeSwitcherDropdown'),
            value: selected,
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
        );
      },
    );
  }
}
