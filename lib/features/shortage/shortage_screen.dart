import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/format/quantity_format.dart';
import '../../core/providers/auth_providers.dart';
import '../../core/providers/shortage_providers.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/app_widgets.dart';
import '../../domain/stock_shortage.dart';
import '../stock/store_switcher.dart';

const _kContentMaxWidth = 1100.0;
const _kPagePadding = 16.0;
const _kGap = 12.0;
const _kMinCardWidth = 240.0;
const _kMaxColumns = 4;

class ShortageScreen extends ConsumerWidget {
  const ShortageScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final shortages = ref.watch(shortagesProvider);
    final ingredients =
        ref.watch(ingredientsStreamProvider).valueOrNull ?? const [];
    final hasTrackedIngredient = ingredients.any(
      (i) => (i.safetyStockQty ?? 0) > 0,
    );
    final isOwner = ref.watch(authSessionProvider)?.isOwner ?? false;

    return Scaffold(
      appBar: AppBar(
        title: const Text('부족 재고'),
        actions: const [StoreSwitcher()],
      ),
      body: shortages.isEmpty
          ? _buildEmpty(hasTrackedIngredient)
          : _buildGrid(shortages, showStoreName: isOwner),
    );
  }

  Widget _buildEmpty(bool hasTrackedIngredient) {
    if (!hasTrackedIngredient) {
      return const EmptyState(
        icon: Icons.tune,
        title: '안전재고가 설정된 품목이 없습니다',
        message: '품목 관리에서 안전재고를 정하면 부족한 품목이 여기에 표시됩니다',
      );
    }
    return const EmptyState(
      icon: Icons.check_circle_outline,
      title: '모든 품목이 기준 이상입니다',
      message: '안전재고 밑으로 떨어지면 여기에 표시됩니다',
    );
  }

  Widget _buildGrid(
    List<StockShortage> shortages, {
    required bool showStoreName,
  }) {
    return CenteredContent(
      maxWidth: _kContentMaxWidth,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final columns = _columnsFor(constraints.maxWidth);
          final rowCount = (shortages.length / columns).ceil();

          return ListView.builder(
            padding: const EdgeInsets.all(_kPagePadding),
            itemCount: rowCount,
            itemBuilder: (context, rowIndex) {
              final start = rowIndex * columns;
              return Padding(
                padding: const EdgeInsets.only(bottom: _kGap),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (var i = 0; i < columns; i++) ...[
                      if (i > 0) const SizedBox(width: _kGap),
                      Expanded(
                        child: start + i < shortages.length
                            ? _ShortageCard(
                                shortage: shortages[start + i],
                                showStoreName: showStoreName,
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
  }

  int _columnsFor(double maxWidth) {
    final available = maxWidth - _kPagePadding * 2;
    final fit = ((available + _kGap) / (_kMinCardWidth + _kGap)).floor();
    return fit.clamp(1, _kMaxColumns);
  }
}

class _ShortageCard extends StatelessWidget {
  const _ShortageCard({required this.shortage, required this.showStoreName});

  final StockShortage shortage;
  final bool showStoreName;

  @override
  Widget build(BuildContext context) {
    final empty = shortage.currentQty <= 0;
    final unit = shortage.ingredient.baseUnit;

    return Container(
      key: Key(
        'shortageCard_${shortage.ingredient.id}_${shortage.store.id}',
      ),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: empty ? AppColors.dangerBackground : AppColors.surface,
        border: Border.all(
          color: empty ? AppColors.dangerBorder : AppColors.border,
        ),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  shortage.ingredient.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textStrong,
                  ),
                ),
              ),
              if (showStoreName) ...[
                const SizedBox(width: 8),
                InfoChip(shortage.store.name),
              ],
            ],
          ),
          const SizedBox(height: 8),
          Text(
            '${formatQty(shortage.currentQty)}$unit'
            ' / 기준 ${formatQty(shortage.safetyStockQty)}$unit',
            style: TextStyle(
              fontSize: 13,
              color: empty ? AppColors.danger : AppColors.textBody,
              fontFeatures: AppTheme.tabularFigures,
            ),
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              value: shortage.fillRatio.clamp(0.0, 1.0),
              minHeight: 6,
              backgroundColor: AppColors.chipBackground,
              valueColor: AlwaysStoppedAnimation(
                empty ? AppColors.danger : AppColors.primary,
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '${formatQty(shortage.shortfall)}$unit 부족',
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: AppColors.danger,
              fontFeatures: AppTheme.tabularFigures,
            ),
          ),
        ],
      ),
    );
  }
}
