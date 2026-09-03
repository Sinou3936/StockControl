import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers/dao_providers.dart';
import '../../core/providers/repository_providers.dart';
import '../../data/local/database.dart';
import '../../domain/unit_conversion.dart';
import '../ingredient_management/ingredient_list_screen.dart';
import '../supplier_management/supplier_list_screen.dart';

class InboundFormScreen extends ConsumerStatefulWidget {
  const InboundFormScreen({super.key});

  @override
  ConsumerState<InboundFormScreen> createState() => _InboundFormScreenState();
}

class _InboundFormScreenState extends ConsumerState<InboundFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _purchaseQtyController = TextEditingController();
  final _unitCostController = TextEditingController();

  Supplier? _selectedSupplier;
  Ingredient? _selectedIngredient;
  DateTime? _expiryDate;

  @override
  void dispose() {
    _purchaseQtyController.dispose();
    _unitCostController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final supplierDao = ref.watch(supplierDaoProvider);
    final ingredientDao = ref.watch(ingredientDaoProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('입고 등록')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            StreamBuilder<List<Supplier>>(
              stream: supplierDao.watchAll(),
              builder: (context, snapshot) {
                final suppliers = snapshot.data ?? [];
                return DropdownButtonFormField<Supplier>(
                  key: const Key('supplierDropdown'),
                  initialValue: _selectedSupplier,
                  decoration: const InputDecoration(labelText: '거래처'),
                  items: suppliers
                      .map(
                        (s) => DropdownMenuItem(value: s, child: Text(s.name)),
                      )
                      .toList(),
                  onChanged: (value) =>
                      setState(() => _selectedSupplier = value),
                );
              },
            ),
            TextButton(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const SupplierListScreen()),
              ),
              child: const Text('+ 신규 거래처 등록'),
            ),
            StreamBuilder<List<Ingredient>>(
              stream: ingredientDao.watchAll(),
              builder: (context, snapshot) {
                final ingredients = snapshot.data ?? [];
                return DropdownButtonFormField<Ingredient>(
                  key: const Key('ingredientDropdown'),
                  initialValue: _selectedIngredient,
                  decoration: const InputDecoration(labelText: '품목'),
                  items: ingredients
                      .map(
                        (i) => DropdownMenuItem(value: i, child: Text(i.name)),
                      )
                      .toList(),
                  onChanged: (value) =>
                      setState(() => _selectedIngredient = value),
                );
              },
            ),
            TextButton(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => const IngredientListScreen(),
                ),
              ),
              child: const Text('+ 신규 품목 등록'),
            ),
            TextFormField(
              key: const Key('purchaseQtyField'),
              controller: _purchaseQtyController,
              decoration: InputDecoration(
                labelText: _selectedIngredient == null
                    ? '수량'
                    : '수량 (${_selectedIngredient!.purchaseUnit})',
              ),
              keyboardType: TextInputType.number,
              validator: (value) {
                if (value == null || value.trim().isEmpty) return '수량을 입력하세요';
                if (double.tryParse(value) == null) return '숫자를 입력하세요';
                return null;
              },
              onChanged: (_) => setState(() {}),
            ),
            if (_selectedIngredient != null &&
                double.tryParse(_purchaseQtyController.text) != null)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  '= ${purchaseQtyToBaseQty(double.parse(_purchaseQtyController.text), _selectedIngredient!.conversionFactor)}'
                  ' ${_selectedIngredient!.baseUnit}',
                ),
              ),
            TextFormField(
              key: const Key('unitCostField'),
              controller: _unitCostController,
              decoration: const InputDecoration(labelText: '단가'),
              keyboardType: TextInputType.number,
              validator: (value) {
                if (value == null || value.trim().isEmpty) return '단가를 입력하세요';
                if (double.tryParse(value) == null) return '숫자를 입력하세요';
                return null;
              },
            ),
            if (_selectedIngredient?.isExpiryTracked ?? false)
              Row(
                children: [
                  Text(
                    _expiryDate == null
                        ? '유통기한 미선택'
                        : '유통기한: ${_expiryDate!.toIso8601String().substring(0, 10)}',
                  ),
                  TextButton(
                    onPressed: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: DateTime.now(),
                        firstDate: DateTime.now(),
                        lastDate: DateTime.now().add(const Duration(days: 3650)),
                      );
                      if (picked != null) setState(() => _expiryDate = picked);
                    },
                    child: const Text('날짜 선택'),
                  ),
                ],
              ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _save,
              child: const Text('저장'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedIngredient == null) return;

    final ingredient = _selectedIngredient!;
    final purchaseQty = double.parse(_purchaseQtyController.text);
    final unitCost = double.parse(_unitCostController.text);
    final baseQty = purchaseQtyToBaseQty(purchaseQty, ingredient.conversionFactor);

    final repository = ref.read(lotRepositoryProvider);
    await repository.receiveLot(
      ingredientId: ingredient.id,
      supplierId: _selectedSupplier?.id,
      receivedDate: DateTime.now(),
      expiryDate: _expiryDate,
      unitCost: unitCost,
      baseQty: baseQty,
    );

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('입고 등록 완료')),
      );
      _formKey.currentState!.reset();
      _purchaseQtyController.clear();
      _unitCostController.clear();
      setState(() {
        _selectedSupplier = null;
        _selectedIngredient = null;
        _expiryDate = null;
      });
    }
  }
}
