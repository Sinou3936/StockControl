import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers/dao_providers.dart';
import '../../data/local/database.dart';
import '../../domain/stock_overview.dart';

class StockOverviewScreen extends ConsumerWidget {
  const StockOverviewScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dao = ref.watch(lotDaoProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('재고 조회')),
      body: StreamBuilder<List<LotWithIngredient>>(
        stream: dao.watchAvailableLotsWithIngredient(),
        builder: (context, snapshot) {
          final groups = groupLotsByIngredient(
            snapshot.data ?? [],
            now: DateTime.now(),
          );

          return ListView.builder(
            itemCount: groups.length,
            itemBuilder: (context, index) =>
                _IngredientGroupSection(group: groups[index]),
          );
        },
      ),
    );
  }
}

class _IngredientGroupSection extends StatelessWidget {
  const _IngredientGroupSection({required this.group});

  final IngredientStockGroup group;

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
          _LotRow(lot: lot, now: DateTime.now()),
      ],
    );
  }
}

class _LotRow extends StatelessWidget {
  const _LotRow({required this.lot, required this.now});

  final Lot lot;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final near = isNearExpiry(lot.expiryDate, now: now);
    final expiryText = lot.expiryDate == null
        ? '유통기한 관리 안 함'
        : '유통기한 ${lot.expiryDate!.toIso8601String().substring(0, 10)}';

    return Container(
      color: near ? Colors.red.shade50 : null,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Row(
        children: [
          Expanded(child: Text(expiryText)),
          if (near)
            const Padding(
              padding: EdgeInsets.only(right: 8),
              child: Text(
                '임박',
                style:
                    TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
              ),
            ),
          Text('${lot.remainingQty}'),
        ],
      ),
    );
  }
}
