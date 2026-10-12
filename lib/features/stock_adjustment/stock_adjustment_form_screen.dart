import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/format/quantity_format.dart';
import '../../core/format/thousands_input.dart';
import '../../core/providers/dao_providers.dart';
import '../../core/providers/repository_providers.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/app_widgets.dart';
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
  late bool _expiryTracked = widget.ingredient.isExpiryTracked;

  @override
  void dispose() {
    _quantityController.dispose();
    _memoController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final unit = widget.ingredient.baseUnit;

    return Scaffold(
      appBar: AppBar(title: const Text('폐기/조정 등록')),
      body: Form(
        key: _formKey,
        child: CenteredContent(
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              AppCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.ingredient.name,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textStrong,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '남은 수량 ${formatQty(widget.lot.remainingQty)}$unit',
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textBody,
                        fontFeatures: AppTheme.tabularFigures,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '입고일 '
                      '${widget.lot.receivedDate.toIso8601String().substring(0, 10)}',
                      style: const TextStyle(
                        fontSize: 13,
                        color: AppColors.textMuted,
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
                    const SectionLabel('변경 내용'),
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
                    if (_type == MovementType.adjustment) ...[
                      const SizedBox(height: 12),
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
                        onChanged: (value) =>
                            setState(() => _direction = value!),
                      ),
                    ],
                    const SizedBox(height: 12),
                    TextFormField(
                      key: const Key('quantityField'),
                      controller: _quantityController,
                      decoration: InputDecoration(
                        labelText: '수량',
                        suffixText: unit,
                      ),
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      inputFormatters: const [ThousandsSeparatorFormatter()],
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return '수량을 입력하세요';
                        }
                        if (parseThousands(value) == null) {
                          return '숫자를 입력하세요';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      key: const Key('memoField'),
                      controller: _memoController,
                      decoration: const InputDecoration(labelText: '메모(선택)'),
                    ),
                    const SizedBox(height: 4),
                    const Divider(height: 24),
                    // 폐기/조정(위)과 달리 저장 버튼 없이 바로 이 품목에 적용된다.
                    SwitchListTile(
                      key: const Key('expiryTrackedSwitch'),
                      contentPadding: EdgeInsets.zero,
                      title: const Text('유통기한 관리'),
                      subtitle: const Text(
                        '이 품목 전체에 바로 적용됩니다 (저장 버튼과 별개). '
                        '끄면 기한이 임박 표시에서 빠지고, 이미 적은 기한은 남아 있습니다.',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.textMuted,
                        ),
                      ),
                      value: _expiryTracked,
                      onChanged: _setExpiryTracked,
                    ),
                  ],
                ),
              ),
              if (_errorText != null) ...[
                const SizedBox(height: 12),
                InlineError(_errorText!),
              ],
              const SizedBox(height: 20),
              ElevatedButton(onPressed: _save, child: const Text('저장')),
            ],
          ),
        ),
      ),
    );
  }

  /// 폐기/조정과 별개로, 이 품목의 유통기한 관리를 바로 바꾼다 (저장 버튼을 누를
  /// 필요 없이 품목 전체에 적용되고, 적어 둔 수량·메모는 그대로 남는다).
  Future<void> _setExpiryTracked(bool value) async {
    await ref
        .read(ingredientDaoProvider)
        .updateExpiryTracked(widget.ingredient.id, value);
    if (!mounted) return;
    setState(() => _expiryTracked = value);
    // 연달아 바꿔도 이전 안내 뒤에 줄을 서지 않고 바로 새 안내가 보이게 한다.
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(content: Text(value ? '유통기한 관리를 켰습니다' : '유통기한 관리를 껐습니다')),
      );
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    final enteredQty = parseThousands(_quantityController.text)!;
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
      await ref
          .read(lotRepositoryProvider)
          .recordQuantityChange(
            lotId: widget.lot.id,
            type: _type,
            quantity: signedQty,
            memo: memo,
          );
    } on InsufficientStockException catch (e) {
      setState(() {
        _errorText =
            '남은 수량(${formatQty(e.remainingQty)})보다 많이 뺄 수 없습니다 '
            '(요청: ${formatQty(e.requestedQty)})';
      });
      return;
    }

    if (mounted) Navigator.of(context).pop();
  }
}
