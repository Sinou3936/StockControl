import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/format/quantity_format.dart';
import '../../core/providers/dao_providers.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/app_widgets.dart';
import '../../data/local/daos/ingredient_dao.dart';
import '../../data/local/database.dart';
import '../../domain/base_unit.dart';
import '../../domain/safety_stock_input.dart';

/// 안전재고 칸을 읽을 수 없을 때 보여 주는 문구. null로 저장하면 알림이
/// 말없이 꺼지므로, 읽을 수 없는 입력은 저장하지 않고 이 문구를 보여 준다.
const _safetyStockErrorMessage = '숫자로 입력해 주세요 (예: 5000). 비우면 알림에서 제외됩니다.';

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
                final safety = ingredient.safetyStockQty;
                return AppListCard(
                  title: ingredient.name,
                  subtitle:
                      '${ingredient.purchaseUnit} = '
                      '${formatQty(ingredient.conversionFactor)}'
                      '${ingredient.baseUnit}',
                  trailing: (safety == null && !ingredient.isExpiryTracked)
                      ? null
                      : Wrap(
                          spacing: 6,
                          runSpacing: 4,
                          alignment: WrapAlignment.end,
                          children: [
                            if (safety != null)
                              InfoChip(
                                '안전재고 ${formatQty(safety)}${ingredient.baseUnit}',
                              ),
                            if (ingredient.isExpiryTracked)
                              const InfoChip('유통기한 관리'),
                          ],
                        ),
                  onTap: () =>
                      _showSafetyStockDialog(context, dao, ingredient),
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

  /// 안전재고 값만 고친다. 이름·단위·환산계수는 과거 로트와 어긋날 수 있어
  /// 이번 범위에서 수정 대상이 아니다.
  Future<void> _showSafetyStockDialog(
    BuildContext context,
    IngredientDao dao,
    Ingredient ingredient,
  ) async {
    final controller = TextEditingController(
      text: ingredient.safetyStockQty == null
          ? ''
          : safetyStockInputText(ingredient.safetyStockQty!),
    );
    String? error;

    await showDialog<void>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: Text('${ingredient.name} 안전재고'),
          content: SizedBox(
            width: 380,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  key: const Key('safetyStockField'),
                  controller: controller,
                  autofocus: true,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: InputDecoration(
                    labelText: '안전재고',
                    suffixText: ingredient.baseUnit,
                    errorText: error,
                  ),
                  onChanged: (_) {
                    if (error != null) setState(() => error = null);
                  },
                ),
                const SizedBox(height: 8),
                const Text(
                  '비워 두면 이 품목은 부족 알림에서 제외됩니다.',
                  style: TextStyle(fontSize: 12, color: AppColors.textMuted),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('취소'),
            ),
            TextButton(
              onPressed: () async {
                final parsed = parseSafetyStockInput(controller.text);
                if (!parsed.isValid) {
                  setState(() => error = _safetyStockErrorMessage);
                  return;
                }
                await dao.updateSafetyStock(ingredient.id, parsed.value);
                if (context.mounted) Navigator.of(context).pop();
              },
              child: const Text('저장'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showAddDialog(BuildContext context, IngredientDao dao) async {
    final nameController = TextEditingController();
    final purchaseUnitController = TextEditingController();
    final conversionFactorController = TextEditingController();
    final safetyStockController = TextEditingController();
    BaseUnit selectedBaseUnit = BaseUnit.g;
    bool isExpiryTracked = true;
    String? safetyStockError;

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
                  const SizedBox(height: 12),
                  TextField(
                    key: const Key('newSafetyStockField'),
                    controller: safetyStockController,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: InputDecoration(
                      labelText: '안전재고 (선택)',
                      suffixText: selectedBaseUnit.name,
                      errorText: safetyStockError,
                    ),
                    onChanged: (_) {
                      if (safetyStockError != null) {
                        setState(() => safetyStockError = null);
                      }
                    },
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
                final parsedSafety = parseSafetyStockInput(
                  safetyStockController.text,
                );
                if (!parsedSafety.isValid) {
                  setState(() => safetyStockError = _safetyStockErrorMessage);
                  return;
                }
                await dao.insertIngredient(
                  IngredientsCompanion.insert(
                    name: nameController.text.trim(),
                    baseUnit: selectedBaseUnit.toDbString(),
                    purchaseUnit: purchaseUnitController.text.trim(),
                    conversionFactor: factor,
                    isExpiryTracked: isExpiryTracked,
                    safetyStockQty: Value(parsedSafety.value),
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
