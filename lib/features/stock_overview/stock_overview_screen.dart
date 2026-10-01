import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers/dao_providers.dart';
import '../../core/providers/store_providers.dart';
import '../../data/local/database.dart';
import '../../domain/stock_overview.dart';
import '../stock/store_switcher.dart';
import '../stock_adjustment/stock_adjustment_form_screen.dart';

class StockOverviewScreen extends ConsumerWidget {
  const StockOverviewScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dao = ref.watch(lotDaoProvider);
    final storeId = ref.watch(activeStoreIdProvider);
    final storeDao = ref.watch(storeDaoProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('재고 조회'),
        actions: const [StoreSwitcher()],
      ),
      body: StreamBuilder<List<Store>>(
        stream: storeDao.watchAll(),
        builder: (context, storeSnapshot) {
          final storeNames = {
            for (final s in storeSnapshot.data ?? <Store>[]) s.id: s.name,
          };

          return StreamBuilder<List<LotWithIngredient>>(
            stream: dao.watchAvailableLotsWithIngredient(storeId: storeId),
            builder: (context, snapshot) {
              final groups = groupLotsByIngredient(
                snapshot.data ?? [],
                now: DateTime.now(),
              );

              return ListView.builder(
                itemCount: groups.length,
                itemBuilder: (context, index) => _IngredientGroupSection(
                  group: groups[index],
                  storeNames: storeNames,
                ),
              );
            },
          );
        },
      ),
    );
  }
}

class _IngredientGroupSection extends StatelessWidget {
  const _IngredientGroupSection({
    required this.group,
    required this.storeNames,
  });

  final IngredientStockGroup group;
  final Map<String, String> storeNames;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
          child: Text(
            '${group.ingredient.name} · 총 ${group.totalRemainingQty}'
            '${group.ingredient.baseUnit}',
            style: Theme.of(context).textTheme.titleMedium,
          ),
        ),
        for (final lot in group.lots)
          _LotRow(
            lot: lot,
            ingredient: group.ingredient,
            now: DateTime.now(),
            storeName: storeNames[lot.storeId],
          ),
      ],
    );
  }
}

class _LotRow extends StatelessWidget {
  const _LotRow({
    required this.lot,
    required this.ingredient,
    required this.now,
    this.storeName,
  });

  final Lot lot;
  final Ingredient ingredient;
  final DateTime now;
  final String? storeName;

  @override
  Widget build(BuildContext context) {
    final near = isNearExpiry(lot.expiryDate, now: now);
    final expiryText = lot.expiryDate == null
        ? '유통기한 관리 안 함'
        : '유통기한 ${lot.expiryDate!.toIso8601String().substring(0, 10)}';

    return InkWell(
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => StockAdjustmentFormScreen(
            lot: lot,
            ingredient: ingredient,
          ),
        ),
      ),
      child: Container(
        color: near ? Colors.red.shade50 : null,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        child: Row(
          children: [
            if (storeName != null)
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: Text(
                  storeName!,
                  style: const TextStyle(color: Colors.black54),
                ),
              ),
            Expanded(child: Text(expiryText)),
            if (near)
              const Padding(
                padding: EdgeInsets.only(right: 8),
                child: Text(
                  '임박',
                  style: TextStyle(
                    color: Colors.red,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            Text('${lot.remainingQty}'),
          ],
        ),
      ),
    );
  }
}
