import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/format/quantity_format.dart';
import '../../core/providers/dao_providers.dart';
import '../../core/providers/repository_providers.dart';
import '../../core/providers/store_providers.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/app_widgets.dart';
import '../../data/local/database.dart';
import '../../domain/unit_conversion.dart';
import '../ingredient_management/ingredient_list_screen.dart';
import '../stock/store_switcher.dart';
import '../supplier_management/supplier_list_screen.dart';

class InboundFormScreen extends ConsumerStatefulWidget {
  const InboundFormScreen({super.key, this.initialIngredient});

  /// 부족 재고 화면에서 넘어올 때 미리 선택해 둘 품목.
  final Ingredient? initialIngredient;

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
  void initState() {
    super.initState();
    _selectedIngredient = widget.initialIngredient;
  }

  @override
  void dispose() {
    _purchaseQtyController.dispose();
    _unitCostController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final storeId = ref.watch(activeStoreIdProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('입고 등록'),
        actions: const [StoreSwitcher()],
      ),
      body: storeId == null
          ? const EmptyState(
              icon: Icons.storefront_outlined,
              title: '매장을 선택해주세요',
              message: '오른쪽 위에서 매장을 고르면 입고를 등록할 수 있습니다',
            )
          : _buildForm(storeId),
    );
  }

  Widget _buildForm(String storeId) {
    final supplierDao = ref.watch(supplierDaoProvider);
    final ingredientDao = ref.watch(ingredientDaoProvider);
    final ingredient = _selectedIngredient;
    final purchaseQty = double.tryParse(_purchaseQtyController.text);

    return Form(
      key: _formKey,
      child: CenteredContent(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SectionLabel('입고 정보'),
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
                              (s) => DropdownMenuItem(
                                value: s,
                                child: Text(s.name),
                              ),
                            )
                            .toList(),
                        onChanged: (value) =>
                            setState(() => _selectedSupplier = value),
                      );
                    },
                  ),
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed: () => Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => const SupplierListScreen(),
                        ),
                      ),
                      child: const Text('+ 신규 거래처 등록'),
                    ),
                  ),
                  StreamBuilder<List<Ingredient>>(
                    stream: ingredientDao.watchAll(),
                    builder: (context, snapshot) {
                      final ingredients = snapshot.data ?? [];

                      // 붙잡아 둔 품목 객체는 그 품목의 안전재고가 바뀌면
                      // 목록의 어떤 항목과도 같지 않게 된다 — drift가 생성한
                      // ==가 그 필드를 포함하기 때문이다. 그대로 넘기면
                      // 드롭다운이 "값에 해당하는 항목이 정확히 하나여야
                      // 한다"는 단정에 걸려 화면이 깨진다. 같은 id 항목으로
                      // 맞춰 넘긴다. StoreSwitcher도 같은 방어를 쓴다.
                      Ingredient? current;
                      final held = _selectedIngredient;
                      if (held != null) {
                        for (final i in ingredients) {
                          if (i.id == held.id) current = i;
                        }
                      }

                      return DropdownButtonFormField<Ingredient>(
                        key: const Key('ingredientDropdown'),
                        initialValue: current,
                        decoration: const InputDecoration(labelText: '품목'),
                        items: ingredients
                            .map(
                              (i) => DropdownMenuItem(
                                value: i,
                                child: Text(i.name),
                              ),
                            )
                            .toList(),
                        onChanged: (value) =>
                            setState(() => _selectedIngredient = value),
                      );
                    },
                  ),
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed: () => Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => const IngredientListScreen(),
                        ),
                      ),
                      child: const Text('+ 신규 품목 등록'),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SectionLabel('수량과 단가'),
                  TextFormField(
                    key: const Key('purchaseQtyField'),
                    controller: _purchaseQtyController,
                    decoration: InputDecoration(
                      labelText: ingredient == null
                          ? '수량'
                          : '수량 (${ingredient.purchaseUnit})',
                    ),
                    keyboardType: TextInputType.number,
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return '수량을 입력하세요';
                      }
                      if (double.tryParse(value) == null) return '숫자를 입력하세요';
                      return null;
                    },
                    onChanged: (_) => setState(() {}),
                  ),
                  if (ingredient != null && purchaseQty != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: _ConversionPreview(
                        text:
                            '${formatQty(purchaseQtyToBaseQty(purchaseQty, ingredient.conversionFactor))}'
                            ' ${ingredient.baseUnit}',
                      ),
                    ),
                  const SizedBox(height: 12),
                  TextFormField(
                    key: const Key('unitCostField'),
                    controller: _unitCostController,
                    decoration: const InputDecoration(labelText: '단가'),
                    keyboardType: TextInputType.number,
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return '단가를 입력하세요';
                      }
                      if (double.tryParse(value) == null) return '숫자를 입력하세요';
                      return null;
                    },
                  ),
                ],
              ),
            ),
            if (ingredient?.isExpiryTracked ?? false) ...[
              const SizedBox(height: 12),
              AppCard(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.event_outlined,
                      size: 20,
                      color: AppColors.textMuted,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        _expiryDate == null
                            ? '유통기한 미선택'
                            : '유통기한: ${_expiryDate!.toIso8601String().substring(0, 10)}',
                        style: TextStyle(
                          fontSize: 14,
                          color: _expiryDate == null
                              ? AppColors.textMuted
                              : AppColors.textStrong,
                          fontWeight: _expiryDate == null
                              ? FontWeight.w400
                              : FontWeight.w600,
                        ),
                      ),
                    ),
                    TextButton(
                      onPressed: () async {
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: DateTime.now(),
                          firstDate: DateTime.now(),
                          lastDate: DateTime.now().add(
                            const Duration(days: 3650),
                          ),
                        );
                        if (picked != null) {
                          setState(() => _expiryDate = picked);
                        }
                      },
                      child: const Text('날짜 선택'),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () => _save(storeId),
              child: const Text('저장'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _save(String storeId) async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedIngredient == null) return;

    final ingredient = _selectedIngredient!;
    final purchaseQty = double.parse(_purchaseQtyController.text);
    final unitCost = double.parse(_unitCostController.text);
    final baseQty = purchaseQtyToBaseQty(
      purchaseQty,
      ingredient.conversionFactor,
    );

    final repository = ref.read(lotRepositoryProvider);
    await repository.receiveLot(
      ingredientId: ingredient.id,
      supplierId: _selectedSupplier?.id,
      storeId: storeId,
      receivedDate: DateTime.now(),
      expiryDate: _expiryDate,
      unitCost: unitCost,
      baseQty: baseQty,
    );

    if (mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('입고 등록 완료')));
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

class _ConversionPreview extends StatelessWidget {
  const _ConversionPreview({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.chipBackground,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          const Icon(Icons.swap_horiz, size: 16, color: AppColors.textMuted),
          const SizedBox(width: 8),
          const Text(
            '기본 단위로',
            style: TextStyle(fontSize: 13, color: AppColors.textMuted),
          ),
          const Spacer(),
          Text(
            text,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: AppColors.textStrong,
              fontFeatures: AppTheme.tabularFigures,
            ),
          ),
        ],
      ),
    );
  }
}
