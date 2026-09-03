import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers/dao_providers.dart';
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
          final ingredients = snapshot.data ?? [];
          return ListView.builder(
            itemCount: ingredients.length,
            itemBuilder: (context, index) {
              final ingredient = ingredients[index];
              return ListTile(
                title: Text(ingredient.name),
                subtitle: Text(
                  '${ingredient.purchaseUnit} = ${ingredient.conversionFactor}${ingredient.baseUnit}',
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
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
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: const InputDecoration(labelText: '품목명'),
              ),
              DropdownButton<BaseUnit>(
                value: selectedBaseUnit,
                items: BaseUnit.values
                    .map(
                      (unit) => DropdownMenuItem(
                        value: unit,
                        child: Text(unit.name),
                      ),
                    )
                    .toList(),
                onChanged: (value) => setState(() => selectedBaseUnit = value!),
              ),
              TextField(
                controller: purchaseUnitController,
                decoration:
                    const InputDecoration(labelText: '구매 단위 (예: 박스)'),
              ),
              TextField(
                controller: conversionFactorController,
                decoration: const InputDecoration(
                  labelText: '구매단위 1개 = base unit 몇 개',
                ),
                keyboardType: TextInputType.number,
              ),
              CheckboxListTile(
                title: const Text('유통기한 관리'),
                value: isExpiryTracked,
                onChanged: (value) =>
                    setState(() => isExpiryTracked = value!),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('취소'),
            ),
            TextButton(
              onPressed: () async {
                final factor =
                    double.tryParse(conversionFactorController.text);
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
