import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/format/quantity_format.dart';
import '../../core/providers/dao_providers.dart';
import '../../core/providers/store_providers.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/app_widgets.dart';
import '../../data/local/database.dart';
import '../../domain/stock_overview.dart';
import '../stock/store_switcher.dart';
import '../stock_adjustment/stock_adjustment_form_screen.dart';

const _kContentMaxWidth = 1100.0;
const _kPagePadding = 16.0;
const _kGap = 12.0;
const _kMinCardWidth = 220.0;
const _kMaxColumns = 4;

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
              if (groups.isEmpty) {
                return const EmptyState(
                  icon: Icons.inventory_2_outlined,
                  title: '표시할 재고가 없습니다',
                  message: '입고를 등록하면 여기에 나타납니다',
                );
              }

              final nearExpiryLots = groups.fold<int>(
                0,
                (sum, g) =>
                    sum +
                    g.lots
                        .where((l) => isNearExpiry(l.expiryDate, now: now))
                        .length,
              );

              return CenteredContent(
                maxWidth: _kContentMaxWidth,
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final columns = _columnsFor(constraints.maxWidth);
                    final rowCount = (groups.length / columns).ceil();

                    // 카드 줄 단위로 만들어 화면에 보이는 줄만 그린다.
                    return ListView.builder(
                      padding: const EdgeInsets.all(_kPagePadding),
                      itemCount: rowCount + 1,
                      itemBuilder: (context, index) {
                        if (index == 0) {
                          return Padding(
                            padding: const EdgeInsets.only(bottom: _kGap),
                            child: _SummaryStrip(
                              itemCount: groups.length,
                              nearExpiryCount: nearExpiryLots,
                            ),
                          );
                        }

                        final start = (index - 1) * columns;
                        return Padding(
                          padding: const EdgeInsets.only(bottom: _kGap),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              for (var i = 0; i < columns; i++) ...[
                                if (i > 0) const SizedBox(width: _kGap),
                                Expanded(
                                  child: start + i < groups.length
                                      ? _IngredientCard(
                                          group: groups[start + i],
                                          storeNames: storeNames,
                                          now: now,
                                        )
                                      : const SizedBox.shrink(),
                                ),
                              ],
                            ],
                          ),
                        );
                      },
                    );
                  },
                ),
              );
            },
          );
        },
      ),
    );
  }

  /// 카드가 [_kMinCardWidth]보다 좁아지지 않는 선에서 한 줄에 최대한 많이.
  int _columnsFor(double maxWidth) {
    final available = maxWidth - _kPagePadding * 2;
    final fit = ((available + _kGap) / (_kMinCardWidth + _kGap)).floor();
    return fit.clamp(1, _kMaxColumns);
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
        const SizedBox(width: _kGap),
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
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: alert ? AppColors.dangerBackground : AppColors.surface,
        border: Border.all(
          color: alert ? AppColors.dangerBorder : AppColors.border,
        ),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: alert ? AppColors.danger : AppColors.textMuted,
              ),
            ),
          ),
          Text(
            value,
            key: valueKey,
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w700,
              color: color,
              fontFeatures: AppTheme.tabularFigures,
            ),
          ),
          const SizedBox(width: 4),
          Text(unit, style: TextStyle(fontSize: 13, color: color)),
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

    // 테두리를 Container의 decoration에 맡기면 마지막 로트 줄의 불투명한 배경이
    // 아래쪽 두 모서리의 호 구간 테두리를 덮는다. Material의 shape는 테두리를
    // 자식 위에 그린다.
    return Material(
      key: Key('ingredientCard_${group.ingredient.id}'),
      color: AppColors.surface,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        side: BorderSide(
          color: alert ? AppColors.dangerBorder : AppColors.border,
        ),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 8),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    group.ingredient.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textStrong,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  '${formatQty(group.totalRemainingQty)}'
                  '${group.ingredient.baseUnit}',
                  style: const TextStyle(
                    fontSize: 15,
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
          padding: const EdgeInsets.fromLTRB(12, 8, 8, 8),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      expiryText,
                      style: TextStyle(
                        fontSize: 13,
                        color: lot.expiryDate == null
                            ? AppColors.textMuted
                            : AppColors.textBody,
                      ),
                    ),
                    if (storeName != null || near) ...[
                      const SizedBox(height: 4),
                      Wrap(
                        spacing: 6,
                        runSpacing: 4,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          if (storeName != null) _StoreChip(name: storeName!),
                          if (near) const _NearExpiryBadge(),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Text(
                formatQty(lot.remainingQty),
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textStrong,
                  fontFeatures: AppTheme.tabularFigures,
                ),
              ),
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
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: AppColors.chipBackground,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        name,
        style: const TextStyle(
          fontSize: 11,
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
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border.all(color: AppColors.dangerBorder),
        borderRadius: BorderRadius.circular(999),
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.schedule, size: 11, color: AppColors.danger),
          SizedBox(width: 3),
          Text(
            '임박',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: AppColors.danger,
            ),
          ),
        ],
      ),
    );
  }
}
