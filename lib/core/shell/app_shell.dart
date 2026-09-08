import 'package:flutter/material.dart';

import '../../features/count/count_screen.dart';
import '../../features/ingredient_management/ingredient_list_screen.dart';
import '../../features/inbound/inbound_form_screen.dart';
import '../../features/stock_overview/stock_overview_screen.dart';
import '../../features/supplier_management/supplier_list_screen.dart';
import 'more_screen.dart';

const _kDesktopBreakpoint = 600.0;

class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
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
    return Scaffold(
      body: Row(
        children: [
          NavigationRail(
            selectedIndex: _selectedIndex,
            onDestinationSelected: (index) =>
                setState(() => _selectedIndex = index),
            labelType: NavigationRailLabelType.all,
            destinations: const [
              NavigationRailDestination(
                icon: Icon(Icons.inventory_2_outlined),
                label: Text('재고 조회'),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.input),
                label: Text('입고 등록'),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.fact_check_outlined),
                label: Text('마감 실사'),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.store_outlined),
                label: Text('거래처 관리'),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.category_outlined),
                label: Text('품목 관리'),
              ),
            ],
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
