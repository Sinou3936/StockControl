import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers/repository_providers.dart';
import '../../data/local/database.dart';
import '../../domain/movement_type.dart';
import '../../domain/stock_adjustment.dart';

enum _AdjustmentDirection { increase, decrease }

class StockAdjustmentFormScreen extends ConsumerStatefulWidget {
  const StockAdjustmentFormScreen({
    super.key,
    required this.lot,
    required this.ingredient,
  });

  final Lot lot;
  final Ingredient ingredient;

  @override
  ConsumerState<StockAdjustmentFormScreen> createState() =>
      _StockAdjustmentFormScreenState();
}

class _StockAdjustmentFormScreenState
    extends ConsumerState<StockAdjustmentFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _quantityController = TextEditingController();
  final _memoController = TextEditingController();

  MovementType _type = MovementType.disposal;
  _AdjustmentDirection _direction = _AdjustmentDirection.decrease;
  String? _errorText;

  @override
  void dispose() {
    _quantityController.dispose();
    _memoController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('폐기/조정 등록')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text(
              '${widget.ingredient.name} · 남은 수량 '
              '${widget.lot.remainingQty}${widget.ingredient.baseUnit}',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            Text(
              '입고일 '
              '${widget.lot.receivedDate.toIso8601String().substring(0, 10)}',
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<MovementType>(
              key: const Key('typeDropdown'),
              initialValue: _type,
              decoration: const InputDecoration(labelText: '유형'),
              items: const [
                DropdownMenuItem(
                  value: MovementType.disposal,
                  child: Text('폐기'),
                ),
                DropdownMenuItem(
                  value: MovementType.adjustment,
                  child: Text('조정'),
                ),
              ],
              onChanged: (value) => setState(() => _type = value!),
            ),
            if (_type == MovementType.adjustment)
              DropdownButtonFormField<_AdjustmentDirection>(
                key: const Key('directionDropdown'),
                initialValue: _direction,
                decoration: const InputDecoration(labelText: '증감'),
                items: const [
                  DropdownMenuItem(
                    value: _AdjustmentDirection.increase,
                    child: Text('증가'),
                  ),
                  DropdownMenuItem(
                    value: _AdjustmentDirection.decrease,
                    child: Text('감소'),
                  ),
                ],
                onChanged: (value) => setState(() => _direction = value!),
              ),
            TextFormField(
              key: const Key('quantityField'),
              controller: _quantityController,
              decoration: const InputDecoration(labelText: '수량'),
              keyboardType: TextInputType.number,
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return '수량을 입력하세요';
                }
                if (double.tryParse(value) == null) return '숫자를 입력하세요';
                return null;
              },
            ),
            TextFormField(
              key: const Key('memoField'),
              controller: _memoController,
              decoration: const InputDecoration(labelText: '메모(선택)'),
            ),
            if (_errorText != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  _errorText!,
                  style: const TextStyle(color: Colors.red),
                ),
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

    final enteredQty = double.parse(_quantityController.text);
    final signedQty = _type == MovementType.disposal
        ? -enteredQty
        : (_direction == _AdjustmentDirection.increase
            ? enteredQty
            : -enteredQty);

    final memo = _memoController.text.trim().isEmpty
        ? null
        : _memoController.text.trim();

    setState(() => _errorText = null);

    try {
      await ref.read(lotRepositoryProvider).recordQuantityChange(
            lotId: widget.lot.id,
            type: _type,
            quantity: signedQty,
            memo: memo,
          );
    } on InsufficientStockException catch (e) {
      setState(() {
        _errorText =
            '남은 수량(${e.remainingQty})보다 많이 뺄 수 없습니다 (요청: ${e.requestedQty})';
      });
      return;
    }

    if (mounted) Navigator.of(context).pop();
  }
}
