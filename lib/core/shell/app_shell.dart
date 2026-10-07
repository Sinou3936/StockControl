import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/count/count_screen.dart';
import '../../features/ingredient_management/ingredient_list_screen.dart';
import '../../features/inbound/inbound_form_screen.dart';
import '../../features/shortage/shortage_screen.dart';
import '../../features/stock_overview/stock_overview_screen.dart';
import '../../features/supplier_management/supplier_list_screen.dart';
import '../providers/auth_providers.dart';
import '../providers/shortage_providers.dart';
import '../providers/sync_providers.dart';
import '../theme/app_theme.dart';
import 'auth_add_staff_route.dart';
import 'more_screen.dart';
import 'store_management_route.dart';

const _kDesktopBreakpoint = 600.0;

class AppShell extends ConsumerStatefulWidget {
  const AppShell({super.key});

  @override
  ConsumerState<AppShell> createState() => _AppShellState();
}

class _AppShellState extends ConsumerState<AppShell> {
  int _selectedIndex = 0;

  static const _primaryScreens = [
    StockOverviewScreen(),
    InboundFormScreen(),
    CountScreen(),
    ShortageScreen(),
  ];

  static const _desktopExtraScreens = [
    SupplierListScreen(),
    IngredientListScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    final isDesktop = MediaQuery.sizeOf(context).width >= _kDesktopBreakpoint;
    return isDesktop ? _buildDesktop() : _buildMobile();
  }

  Widget _buildDesktop() {
    final isOwner = ref.watch(authSessionProvider)?.isOwner ?? false;

    return Scaffold(
      body: Row(
        children: [
          NavigationRail(
            selectedIndex: _selectedIndex,
            onDestinationSelected: (index) {
              if (isOwner && index == 6) {
                pushAddStaffScreen(context);
                return;
              }
              if (isOwner && index == 7) {
                pushStoreManagementScreen(context);
                return;
              }
              setState(() => _selectedIndex = index);
            },
            labelType: NavigationRailLabelType.all,
            destinations: [
              const NavigationRailDestination(
                icon: Icon(Icons.inventory_2_outlined),
                label: Text('재고 조회'),
              ),
              const NavigationRailDestination(
                icon: Icon(Icons.input),
                label: Text('입고 등록'),
              ),
              const NavigationRailDestination(
                icon: Icon(Icons.fact_check_outlined),
                label: Text('마감 실사'),
              ),
              NavigationRailDestination(
                icon: _ShortageIcon(count: ref.watch(shortageCountProvider)),
                label: const Text('부족 재고'),
              ),
              const NavigationRailDestination(
                icon: Icon(Icons.store_outlined),
                label: Text('거래처 관리'),
              ),
              const NavigationRailDestination(
                icon: Icon(Icons.category_outlined),
                label: Text('품목 관리'),
              ),
              if (isOwner)
                const NavigationRailDestination(
                  icon: Icon(Icons.person_add_outlined),
                  label: Text('직원 추가'),
                ),
              if (isOwner)
                const NavigationRailDestination(
                  icon: Icon(Icons.store_mall_directory_outlined),
                  label: Text('매장 관리'),
                ),
            ],
            trailing: Expanded(
              child: Align(
                alignment: Alignment.bottomCenter,
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _buildSyncButton(),
                      const SizedBox(height: 8),
                      IconButton(
                        key: const Key('logoutButton'),
                        icon: const Icon(Icons.logout),
                        tooltip: '로그아웃',
                        onPressed: () =>
                            ref.read(authSessionProvider.notifier).clear(),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          const VerticalDivider(width: 1),
          Expanded(
            child: IndexedStack(
              index: _selectedIndex,
              children: const [..._primaryScreens, ..._desktopExtraScreens],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSyncButton() {
    final status = ref.watch(syncControllerProvider);
    final hasError = status.errorMessage != null;

    return Tooltip(
      message: status.description,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            key: const Key('syncButton'),
            icon: status.isSyncing
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Icon(
                    hasError ? Icons.sync_problem : Icons.sync,
                    color: hasError ? Colors.red : null,
                  ),
            onPressed: status.isSyncing
                ? null
                : () => ref.read(syncControllerProvider.notifier).sync(),
          ),
          Text(
            status.isSyncing
                ? '동기화 중'
                : hasError
                ? '실패'
                : status.lastSyncedAt == null
                ? '동기화'
                : _formatTime(status.lastSyncedAt!),
            style: TextStyle(
              fontSize: 11,
              color: hasError ? Colors.red : Colors.black54,
            ),
          ),
        ],
      ),
    );
  }

  String _formatTime(DateTime at) {
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(at.hour)}:${two(at.minute)}:${two(at.second)}';
  }

  Widget _buildMobile() {
    // 넓은 화면에서 고른 거래처/품목 탭은 폰 레이아웃에 없다. 창을 줄였을 때는
    // 재고 탭으로 보여주고, 선택 상태 자체는 그대로 두어 다시 키우면 돌아온다.
    final index = _selectedIndex < _primaryScreens.length ? _selectedIndex : 0;

    return Scaffold(
      body: IndexedStack(index: index, children: _primaryScreens),
      bottomNavigationBar: DecoratedBox(
        decoration: const BoxDecoration(
          border: Border(top: BorderSide(color: AppColors.border)),
        ),
        child: BottomNavigationBar(
          currentIndex: index,
          onTap: (index) {
            if (index == 4) {
              Navigator.of(
                context,
              ).push(MaterialPageRoute(builder: (_) => const MoreScreen()));
              return;
            }
            setState(() => _selectedIndex = index);
          },
          items: [
            const BottomNavigationBarItem(
              icon: Icon(Icons.inventory_2_outlined),
              label: '재고',
            ),
            const BottomNavigationBarItem(
              icon: Icon(Icons.input),
              label: '입고',
            ),
            const BottomNavigationBarItem(
              icon: Icon(Icons.fact_check_outlined),
              label: '실사',
            ),
            BottomNavigationBarItem(
              icon: _ShortageIcon(count: ref.watch(shortageCountProvider)),
              label: '부족',
            ),
            const BottomNavigationBarItem(
              icon: Icon(Icons.more_horiz),
              label: '더보기',
            ),
          ],
        ),
      ),
    );
  }
}

/// 부족 건수를 아이콘 위에 빨간 숫자로 올린다. 0이면 숫자를 숨긴다.
class _ShortageIcon extends StatelessWidget {
  const _ShortageIcon({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    return Badge(
      isLabelVisible: count > 0,
      label: Text('$count'),
      backgroundColor: AppColors.danger,
      child: const Icon(Icons.report_problem_outlined),
    );
  }
}
