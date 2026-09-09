import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/count/count_screen.dart';
import '../../features/ingredient_management/ingredient_list_screen.dart';
import '../../features/inbound/inbound_form_screen.dart';
import '../../features/stock_overview/stock_overview_screen.dart';
import '../../features/supplier_management/supplier_list_screen.dart';
import '../providers/auth_providers.dart';
import 'auth_add_staff_route.dart';
import 'more_screen.dart';

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
              if (isOwner && index == 5) {
                pushAddStaffScreen(context);
                return;
              }
              setState(() => _selectedIndex = index);
            },
            labelType: NavigationRailLabelType.all,
            backgroundColor: Colors.white,
            selectedIconTheme: const IconThemeData(color: Colors.indigo),
            unselectedIconTheme: const IconThemeData(color: Colors.black54),
            selectedLabelTextStyle: const TextStyle(color: Colors.indigo),
            unselectedLabelTextStyle: const TextStyle(color: Colors.black54),
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
            ],
            trailing: Expanded(
              child: Align(
                alignment: Alignment.bottomCenter,
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: IconButton(
                    key: const Key('logoutButton'),
                    icon: const Icon(Icons.logout),
                    tooltip: '로그아웃',
                    onPressed: () =>
                        ref.read(authSessionProvider.notifier).clear(),
                  ),
                ),
              ),
            ),
          ),
          const VerticalDivider(width: 1),
          Expanded(
            child: IndexedStack(
              index: _selectedIndex,
              children: const [
                ..._primaryScreens,
                ..._desktopExtraScreens,
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMobile() {
    return Scaffold(
      body: IndexedStack(index: _selectedIndex, children: _primaryScreens),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        type: BottomNavigationBarType.fixed,
        backgroundColor: Colors.white,
        selectedItemColor: Colors.indigo,
        unselectedItemColor: Colors.black54,
        onTap: (index) {
          if (index == 3) {
            Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const MoreScreen()),
            );
            return;
          }
          setState(() => _selectedIndex = index);
        },
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.inventory_2_outlined),
            label: '재고',
          ),
          BottomNavigationBarItem(icon: Icon(Icons.input), label: '입고'),
          BottomNavigationBarItem(
            icon: Icon(Icons.fact_check_outlined),
            label: '실사',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.more_horiz),
            label: '더보기',
          ),
        ],
      ),
    );
  }
}
