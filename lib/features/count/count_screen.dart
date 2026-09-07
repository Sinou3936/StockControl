import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers/dao_providers.dart';
import '../../core/providers/repository_providers.dart';
import '../../domain/stock_count.dart';
import '../../domain/stock_overview.dart';

class CountScreen extends ConsumerStatefulWidget {
  const CountScreen({super.key});

  @override
  ConsumerState<CountScreen> createState() => _CountScreenState();
}

class _CountScreenState extends ConsumerState<CountScreen> {
  final Map<int, double> _enteredCounts = {};

  @override
  Widget build(BuildContext context) {
    final dao = ref.watch(lotDaoProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('마감 실사')),
      body: StreamBuilder<List<LotWithIngredient>>(
        stream: dao.watchAvailableLotsWithIngredient(),
        builder: (context, snapshot) {
          final groups = groupLotsByIngredient(
            snapshot.data ?? [],
            now: DateTime.now(),
          );

          return Column(
            children: [
              Expanded(
                child: ListView.builder(
                  itemCount: groups.length,
                  itemBuilder: (context, index) {
                    final group = groups[index];
                    return ListTile(
                      title: Text(group.ingredient.name),
                      subtitle: Text(
                        '이론재고 ${group.totalRemainingQty}'
                        '${group.ingredient.baseUnit}',
                      ),
                      trailing: SizedBox(
                        width: 100,
                        child: TextFormField(
                          key: Key('countField_${group.ingredient.id}'),
                          decoration:
                              const InputDecoration(labelText: '실사 수량'),
                          keyboardType: TextInputType.number,
                          onChanged: (value) {
                            final parsed = double.tryParse(value);
                            if (parsed == null) {
                              _enteredCounts.remove(group.ingredient.id);
                            } else {
                              _enteredCounts[group.ingredient.id] = parsed;
                            }
                          },
                        ),
                      ),
                    );
                  },
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(16),
                child: ElevatedButton(
                  onPressed: () => _submit(groups),
                  child: const Text('실사 제출'),
                ),
              ),
            ],
          );
        },
      ),
    );
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
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('차이가 있는 품목이 없습니다')),
      );
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('실사 차이 확인'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (final diff in differences)
                Text(
                  '${diff.ingredient.name}: 이론 ${diff.theoreticalQty}'
                  '${diff.ingredient.baseUnit} / 실사 ${diff.actualQty}'
                  '${diff.ingredient.baseUnit} / 차이 ${diff.difference}'
                  '${diff.ingredient.baseUnit}',
                ),
            ],
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

    if (mounted) Navigator.of(context).pop();
  }
}
