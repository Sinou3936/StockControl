import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/format/quantity_format.dart';
import '../../core/providers/dao_providers.dart';
import '../../core/widgets/app_widgets.dart';
import '../../data/local/daos/ingredient_dao.dart';
import '../../data/local/database.dart';
import '../../domain/base_unit.dart';

class IngredientListScreen extends ConsumerWidget {
  const IngredientListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dao = ref.watch(ingredientDaoProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('품목 관리')),
      body: StreamBuilder<List<Ingredient>>(
        stream: dao.watchAll(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const SizedBox.shrink();
          final ingredients = snapshot.data!;
          if (ingredients.isEmpty) {
            return const EmptyState(
              icon: Icons.category_outlined,
              title: '등록된 품목이 없습니다',
              message: '오른쪽 아래 + 버튼으로 품목을 추가하세요',
            );
          }

          return CenteredContent(
            child: ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 88),
              itemCount: ingredients.length,
              separatorBuilder: (_, _) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                final ingredient = ingredients[index];
                return AppListCard(
                  title: ingredient.name,
                  subtitle:
                      '${ingredient.purchaseUnit} = '
                      '${formatQty(ingredient.conversionFactor)}'
                      '${ingredient.baseUnit}',
                  trailing: ingredient.isExpiryTracked
                      ? const InfoChip('유통기한 관리')
                      : null,
                );
              },
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        // 데스크톱에서는 IndexedStack이 거래처·품목 화면을 동시에 살려두므로
        // 기본 Hero 태그를 쓰면 화면 전환 때 태그가 충돌해 예외가 난다.
        heroTag: 'ingredientAddFab',
        onPressed: () => _showAddDialog(context, dao),
        child: const Icon(Icons.add),
      ),
    );
  }

  Future<void> _showAddDialog(BuildContext context, IngredientDao dao) async {
    final nameController = TextEditingController();
    final purchaseUnitController = TextEditingController();
    final conversionFactorController = TextEditingController();
    BaseUnit selectedBaseUnit = BaseUnit.g;
    bool isExpiryTracked = true;

    await showDialog<void>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('품목 등록'),
          content: SizedBox(
            width: 380,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: nameController,
                    decoration: const InputDecoration(labelText: '품목명'),
                  ),
                  const SizedBox(height: 12),
                  InputDecorator(
                    decoration: const InputDecoration(labelText: '기본 단위'),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<BaseUnit>(
                        value: selectedBaseUnit,
                        isExpanded: true,
                        isDense: true,
                        items: BaseUnit.values
                            .map(
                              (unit) => DropdownMenuItem(
                                value: unit,
                                child: Text(unit.name),
                              ),
                            )
                            .toList(),
                        onChanged: (value) =>
                            setState(() => selectedBaseUnit = value!),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: purchaseUnitController,
                    decoration: const InputDecoration(
                      labelText: '구매 단위 (예: 박스)',
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: conversionFactorController,
                    decoration: const InputDecoration(
                      labelText: '구매단위 1개 = base unit 몇 개',
                    ),
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                  ),
                  CheckboxListTile(
                    contentPadding: EdgeInsets.zero,
                    controlAffinity: ListTileControlAffinity.leading,
                    title: const Text('유통기한 관리'),
                    value: isExpiryTracked,
                    onChanged: (value) =>
                        setState(() => isExpiryTracked = value!),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('취소'),
            ),
            TextButton(
              onPressed: () async {
                final factor = double.tryParse(conversionFactorController.text);
                if (nameController.text.trim().isEmpty ||
                    purchaseUnitController.text.trim().isEmpty ||
                    factor == null) {
                  return;
                }
                await dao.insertIngredient(
                  IngredientsCompanion.insert(
                    name: nameController.text.trim(),
                    baseUnit: selectedBaseUnit.toDbString(),
                    purchaseUnit: purchaseUnitController.text.trim(),
                    conversionFactor: factor,
                    isExpiryTracked: isExpiryTracked,
                  ),
                );
                if (context.mounted) Navigator.of(context).pop();
              },
              child: const Text('저장'),
            ),
          ],
        ),
      ),
    );
  }
}
