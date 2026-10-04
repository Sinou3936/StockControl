import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers/auth_providers.dart';
import '../../core/providers/store_providers.dart';
import '../../core/theme/app_theme.dart';
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
        // 목록이 도착하기 전에는 선택값을 담을 항목이 없어 드롭다운이 오류를 낸다.
        if (!snapshot.hasData) return const SizedBox.shrink();
        final stores = snapshot.data!;

        // 선택값은 목록 안의 같은 id 항목으로 맞춘다(객체가 달라도 안전하게).
        Store? current;
        if (selected != null) {
          for (final store in stores) {
            if (store.id == selected.id) current = store;
          }
        }

        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              border: Border.all(color: AppColors.border),
              borderRadius: BorderRadius.circular(999),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<Store?>(
                key: const Key('storeSwitcherDropdown'),
                value: current,
                isDense: true,
                borderRadius: BorderRadius.circular(12),
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textBody,
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
