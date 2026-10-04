import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/ingredient_management/ingredient_list_screen.dart';
import '../../features/supplier_management/supplier_list_screen.dart';
import '../providers/auth_providers.dart';
import '../providers/sync_providers.dart';
import '../theme/app_theme.dart';
import '../widgets/app_widgets.dart';
import 'auth_add_staff_route.dart';
import 'store_management_route.dart';

class MoreScreen extends ConsumerWidget {
  const MoreScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(authSessionProvider);
    final isOwner = session?.isOwner ?? false;

    return Scaffold(
      appBar: AppBar(title: const Text('더보기')),
      body: CenteredContent(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _MenuGroup(
              children: [
                _MenuTile(
                  icon: Icons.local_shipping_outlined,
                  title: '거래처 관리',
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => const SupplierListScreen(),
                    ),
                  ),
                ),
                _MenuTile(
                  icon: Icons.category_outlined,
                  title: '품목 관리',
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => const IngredientListScreen(),
                    ),
                  ),
                ),
                if (isOwner)
                  _MenuTile(
                    icon: Icons.store_mall_directory_outlined,
                    title: '매장 관리',
                    onTap: () => pushStoreManagementScreen(context),
                  ),
                if (isOwner)
                  _MenuTile(
                    icon: Icons.person_add_outlined,
                    title: '직원 추가',
                    onTap: () => pushAddStaffScreen(context),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            _MenuGroup(
              children: [
                _SyncTile(
                  status: ref.watch(syncControllerProvider),
                  onTap: () => ref.read(syncControllerProvider.notifier).sync(),
                ),
                _MenuTile(
                  icon: Icons.logout,
                  title: '로그아웃',
                  onTap: () => ref.read(authSessionProvider.notifier).clear(),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// 메뉴 항목을 한 카드로 묶고 항목 사이에 가는 선을 넣는다. 물결 효과가 카드
/// 안에서 보이도록 Material 위에 올린다.
class _MenuGroup extends StatelessWidget {
  const _MenuGroup({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Material(
        color: AppColors.surface,
        child: Column(
          children: [
            for (var i = 0; i < children.length; i++) ...[
              if (i > 0) const Divider(height: 1, color: AppColors.border),
              children[i],
            ],
          ],
        ),
      ),
    );
  }
}

class _MenuTile extends StatelessWidget {
  const _MenuTile({
    required this.icon,
    required this.title,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon, color: AppColors.textMuted),
      title: Text(title),
      trailing: const Icon(Icons.chevron_right, color: AppColors.textMuted),
      onTap: onTap,
    );
  }
}

class _SyncTile extends StatelessWidget {
  const _SyncTile({required this.status, required this.onTap});

  final SyncStatus status;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final hasError = status.errorMessage != null;

    return ListTile(
      leading: Icon(
        hasError ? Icons.sync_problem : Icons.sync,
        color: hasError ? AppColors.danger : AppColors.textMuted,
      ),
      title: const Text('지금 동기화'),
      subtitle: Text(
        status.description,
        style: TextStyle(
          color: hasError ? AppColors.danger : AppColors.textMuted,
        ),
      ),
      trailing: status.isSyncing
          ? const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : null,
      onTap: status.isSyncing ? null : onTap,
    );
  }
}
