import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/format/quantity_format.dart';
import '../../core/providers/dao_providers.dart';
import '../../core/providers/store_providers.dart';
import '../../core/theme/app_theme.dart';
import '../../data/local/database.dart';
import '../../domain/stock_overview.dart';
import '../stock/store_switcher.dart';
import '../stock_adjustment/stock_adjustment_form_screen.dart';

const _kContentMaxWidth = 760.0;

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
              if (!snapshot.hasData) return const SizedBox.shrink();

              final now = DateTime.now();
              final groups = groupLotsByIngredient(snapshot.data!, now: now);
              if (groups.isEmpty) return const _EmptyState();

              final nearExpiryLots = groups.fold<int>(
                0,
                (sum, g) =>
                    sum +
                    g.lots
                        .where((l) => isNearExpiry(l.expiryDate, now: now))
                        .length,
              );

              return Align(
                alignment: Alignment.topCenter,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(
                    maxWidth: _kContentMaxWidth,
                  ),
                  child: ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      _SummaryStrip(
                        itemCount: groups.length,
                        nearExpiryCount: nearExpiryLots,
                      ),
                      const SizedBox(height: 16),
                      for (final group in groups) ...[
                        _IngredientCard(
                          group: group,
                          storeNames: storeNames,
                          now: now,
                        ),
                        const SizedBox(height: 12),
                      ],
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.inventory_2_outlined,
              size: 48,
              color: AppColors.textMuted,
            ),
            SizedBox(height: 12),
            Text(
              '표시할 재고가 없습니다',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: AppColors.textStrong,
              ),
            ),
            SizedBox(height: 4),
            Text(
              '입고를 등록하면 여기에 나타납니다',
              style: TextStyle(fontSize: 13, color: AppColors.textMuted),
            ),
          ],
        ),
      ),
    );
  }
}

class _SummaryStrip extends StatelessWidget {
  const _SummaryStrip({required this.itemCount, required this.nearExpiryCount});

  final int itemCount;
  final int nearExpiryCount;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _StatTile(
            label: '재고 품목',
            value: '$itemCount',
            unit: '종',
            valueKey: const Key('summaryItemCount'),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _StatTile(
            label: '유통기한 임박',
            value: '$nearExpiryCount',
            unit: '건',
            valueKey: const Key('summaryNearExpiryCount'),
            alert: nearExpiryCount > 0,
          ),
        ),
      ],
    );
  }
}

class _StatTile extends StatelessWidget {
  const _StatTile({
    required this.label,
    required this.value,
    required this.unit,
    required this.valueKey,
    this.alert = false,
  });

  final String label;
  final String value;
  final String unit;
  final Key valueKey;
  final bool alert;

  @override
  Widget build(BuildContext context) {
    final color = alert ? AppColors.danger : AppColors.textStrong;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: alert ? AppColors.dangerBackground : AppColors.surface,
        border: Border.all(
          color: alert ? AppColors.dangerBorder : AppColors.border,
        ),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: alert ? AppColors.danger : AppColors.textMuted,
            ),
          ),
          const SizedBox(height: 4),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                value,
                key: valueKey,
                style: TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.w700,
                  color: color,
                  fontFeatures: AppTheme.tabularFigures,
                ),
              ),
              const SizedBox(width: 4),
              Text(unit, style: TextStyle(fontSize: 13, color: color)),
            ],
          ),
        ],
      ),
    );
  }
}

class _IngredientCard extends StatelessWidget {
  const _IngredientCard({
    required this.group,
    required this.storeNames,
    required this.now,
  });

  final IngredientStockGroup group;
  final Map<String, String> storeNames;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final alert = group.hasNearExpiryLot;

    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border.all(
          color: alert ? AppColors.dangerBorder : AppColors.border,
        ),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    group.ingredient.name,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textStrong,
                    ),
                  ),
                ),
                Text(
                  '${formatQty(group.totalRemainingQty)}'
                  '${group.ingredient.baseUnit}',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textStrong,
                    fontFeatures: AppTheme.tabularFigures,
                  ),
                ),
              ],
            ),
          ),
          for (final lot in group.lots) ...[
            const Divider(height: 1, thickness: 1, color: AppColors.border),
            _LotRow(
              lot: lot,
              ingredient: group.ingredient,
              now: now,
              storeName: storeNames[lot.storeId],
            ),
          ],
        ],
      ),
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
        : '기한 ${lot.expiryDate!.toIso8601String().substring(0, 10)}';

    return Material(
      color: near ? AppColors.dangerBackground : AppColors.surface,
      child: InkWell(
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) =>
                StockAdjustmentFormScreen(lot: lot, ingredient: ingredient),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              if (storeName != null) ...[
                _StoreChip(name: storeName!),
                const SizedBox(width: 10),
              ],
              Expanded(
                child: Text(
                  expiryText,
                  style: TextStyle(
                    fontSize: 14,
                    color: lot.expiryDate == null
                        ? AppColors.textMuted
                        : AppColors.textBody,
                  ),
                ),
              ),
              if (near) ...[
                const _NearExpiryBadge(),
                const SizedBox(width: 12),
              ],
              Text(
                formatQty(lot.remainingQty),
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textStrong,
                  fontFeatures: AppTheme.tabularFigures,
                ),
              ),
              const SizedBox(width: 4),
              const Icon(
                Icons.chevron_right,
                size: 18,
                color: AppColors.textMuted,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StoreChip extends StatelessWidget {
  const _StoreChip({required this.name});

  final String name;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: AppColors.chipBackground,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        name,
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: AppColors.textBody,
        ),
      ),
    );
  }
}

class _NearExpiryBadge extends StatelessWidget {
  const _NearExpiryBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border.all(color: AppColors.dangerBorder),
        borderRadius: BorderRadius.circular(999),
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.schedule, size: 12, color: AppColors.danger),
          SizedBox(width: 4),
          Text(
            '임박',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: AppColors.danger,
            ),
          ),
        ],
      ),
    );
  }
}
