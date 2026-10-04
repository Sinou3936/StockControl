import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/format/quantity_format.dart';
import '../../core/providers/dao_providers.dart';
import '../../core/providers/repository_providers.dart';
import '../../core/providers/store_providers.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/app_widgets.dart';
import '../../domain/stock_count.dart';
import '../../domain/stock_overview.dart';
import '../stock/store_switcher.dart';

class CountScreen extends ConsumerStatefulWidget {
  const CountScreen({super.key});

  @override
  ConsumerState<CountScreen> createState() => _CountScreenState();
}

class _CountScreenState extends ConsumerState<CountScreen> {
  final Map<int, double> _enteredCounts = {};

  // 제출 후 입력칸을 비우기 위해 목록의 State를 새로 만든다.
  int _formVersion = 0;

  @override
  Widget build(BuildContext context) {
    final storeId = ref.watch(activeStoreIdProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('마감 실사'),
        actions: const [StoreSwitcher()],
      ),
      body: storeId == null
          ? const EmptyState(
              icon: Icons.storefront_outlined,
              title: '매장을 선택해주세요',
              message: '오른쪽 위에서 매장을 고르면 실사를 진행할 수 있습니다',
            )
          : _buildCountList(storeId),
    );
  }

  Widget _buildCountList(String storeId) {
    final dao = ref.watch(lotDaoProvider);

    return StreamBuilder<List<LotWithIngredient>>(
      stream: dao.watchAvailableLotsWithIngredient(storeId: storeId),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const SizedBox.shrink();

        final groups = groupLotsByIngredient(
          snapshot.data!,
          now: DateTime.now(),
        );

        if (groups.isEmpty) {
          return const EmptyState(
            icon: Icons.fact_check_outlined,
            title: '실사할 재고가 없습니다',
            message: '입고를 등록하면 실사 목록에 나타납니다',
          );
        }

        return CenteredContent(
          child: Column(
            children: [
              Expanded(
                child: ListView.separated(
                  key: ValueKey(_formVersion),
                  padding: const EdgeInsets.all(16),
                  itemCount: groups.length + 1,
                  separatorBuilder: (_, _) => const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    if (index == 0) return const _CountHint();
                    return _CountRow(
                      group: groups[index - 1],
                      onChanged: _onCountChanged,
                    );
                  },
                ),
              ),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: const BoxDecoration(
                  color: AppColors.surface,
                  border: Border(top: BorderSide(color: AppColors.border)),
                ),
                child: SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () => _submit(groups),
                    child: const Text('실사 제출'),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _onCountChanged(int ingredientId, String value) {
    final parsed = double.tryParse(value);
    if (parsed == null) {
      _enteredCounts.remove(ingredientId);
    } else {
      _enteredCounts[ingredientId] = parsed;
    }
  }

  Future<void> _submit(List<IngredientStockGroup> groups) async {
    final differences = <CountDifference>[];
    for (final group in groups) {
      final actual = _enteredCounts[group.ingredient.id];
      if (actual == null) continue;
      final diff = CountDifference(
        ingredient: group.ingredient,
        theoreticalQty: group.totalRemainingQty,
        actualQty: actual,
      );
      if (diff.difference != 0) differences.add(diff);
    }

    if (differences.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('차이가 있는 품목이 없습니다')));
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('실사 차이 확인'),
        content: SizedBox(
          width: 420,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [for (final diff in differences) _DiffLine(diff: diff)],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('취소'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('확정'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    final adjustments = <LotQuantityAdjustment>[];
    for (final diff in differences) {
      final group = groups.firstWhere(
        (g) => g.ingredient.id == diff.ingredient.id,
      );
      adjustments.addAll(
        distributeCountDifference(group.lots, diff.difference),
      );
    }

    await ref.read(lotRepositoryProvider).submitCountCorrections(adjustments);

    if (!mounted) return;
    setState(() {
      _enteredCounts.clear();
      _formVersion++;
    });
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('실사가 반영되었습니다')));
  }
}

class _CountHint extends StatelessWidget {
  const _CountHint();

  @override
  Widget build(BuildContext context) {
    return const Row(
      children: [
        Icon(Icons.info_outline, size: 16, color: AppColors.textMuted),
        SizedBox(width: 6),
        Expanded(
          child: Text(
            '실제로 센 수량을 입력하면 이론재고와 비교합니다. 비워 둔 품목은 건너뜁니다.',
            style: TextStyle(fontSize: 13, color: AppColors.textMuted),
          ),
        ),
      ],
    );
  }
}

class _CountRow extends StatelessWidget {
  const _CountRow({required this.group, required this.onChanged});

  final IngredientStockGroup group;
  final void Function(int ingredientId, String value) onChanged;

  @override
  Widget build(BuildContext context) {
    final ingredient = group.ingredient;

    return AppCard(
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  ingredient.name,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textStrong,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '이론재고 ${formatQty(group.totalRemainingQty)}'
                  '${ingredient.baseUnit}',
                  style: const TextStyle(
                    fontSize: 13,
                    color: AppColors.textMuted,
                    fontFeatures: AppTheme.tabularFigures,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          SizedBox(
            width: 140,
            child: TextFormField(
              key: Key('countField_${ingredient.id}'),
              textAlign: TextAlign.right,
              decoration: InputDecoration(
                labelText: '실사 수량',
                suffixText: ingredient.baseUnit,
              ),
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              onChanged: (value) => onChanged(ingredient.id, value),
            ),
          ),
        ],
      ),
    );
  }
}

class _DiffLine extends StatelessWidget {
  const _DiffLine({required this.diff});

  final CountDifference diff;

  @override
  Widget build(BuildContext context) {
    final unit = diff.ingredient.baseUnit;
    final change = diff.difference;
    final sign = change > 0 ? '+' : '';

    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            diff.ingredient.name,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: AppColors.textStrong,
            ),
          ),
          const SizedBox(height: 2),
          Text.rich(
            TextSpan(
              style: const TextStyle(
                fontSize: 14,
                color: AppColors.textBody,
                fontFeatures: AppTheme.tabularFigures,
              ),
              children: [
                TextSpan(
                  text:
                      '이론 ${formatQty(diff.theoreticalQty)}$unit · '
                      '실사 ${formatQty(diff.actualQty)}$unit · ',
                ),
                TextSpan(
                  text: '차이 $sign${formatQty(change)}$unit',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: change < 0 ? AppColors.danger : AppColors.textStrong,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
