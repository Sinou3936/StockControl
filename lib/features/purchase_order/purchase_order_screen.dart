import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/format/quantity_format.dart';
import '../../core/providers/dao_providers.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/app_widgets.dart';
import '../../data/export/purchase_order_exporter.dart';
import '../../data/local/database.dart';
import '../../domain/purchase_order.dart';
import '../../domain/stock_shortage.dart';

final _suppliersProvider = StreamProvider<List<Supplier>>(
  (ref) => ref.watch(supplierDaoProvider).watchAll(),
);

class PurchaseOrderScreen extends ConsumerStatefulWidget {
  const PurchaseOrderScreen({
    super.key,
    required this.store,
    required this.shortages,
  });

  /// 발주할 매장. 발주서는 매장 하나 단위다.
  final Store store;

  /// 이 매장의 부족 품목. 화면을 열 때 복사해서 넘긴 값이라, 화면을 보는
  /// 중에 동기화로 재고가 바뀌어도 입력 중인 수량은 바뀌지 않는다. 모두
  /// [store]의 것이어야 한다.
  final List<StockShortage> shortages;

  @override
  ConsumerState<PurchaseOrderScreen> createState() =>
      _PurchaseOrderScreenState();
}

class _PurchaseOrderScreenState extends ConsumerState<PurchaseOrderScreen> {
  final _qtyControllers = <int, TextEditingController>{};
  final _unchecked = <int>{};
  late final DateTime _date;
  int? _supplierId;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _date = DateTime.now();
    for (final shortage in widget.shortages) {
      _qtyControllers[shortage.ingredient.id] = TextEditingController(
        text: '${suggestOrderQty(shortage)}',
      );
    }
  }

  @override
  void dispose() {
    for (final controller in _qtyControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  /// 입력칸의 수량. 비었거나 숫자가 아니면 0이라 발주서에서 빠진다.
  int _qtyOf(StockShortage shortage) =>
      int.tryParse(_qtyControllers[shortage.ingredient.id]!.text.trim()) ?? 0;

  /// 지금 입력한 상태로 만들 수 있는 발주서. 거래처를 안 골랐거나 담을 줄이
  /// 하나도 없으면 null이라 저장 버튼이 눌리지 않는다.
  PurchaseOrder? _currentOrder(Supplier? supplier) {
    if (supplier == null) return null;
    final order = buildPurchaseOrder(
      store: widget.store,
      supplier: supplier,
      date: _date,
      lines: [
        for (final shortage in widget.shortages)
          if (!_unchecked.contains(shortage.ingredient.id))
            PurchaseOrderLine(
              ingredient: shortage.ingredient,
              qty: _qtyOf(shortage),
            ),
      ],
    );
    return order.lines.isEmpty ? null : order;
  }

  Future<void> _save(PurchaseOrder order, PurchaseOrderFormat format) async {
    setState(() => _saving = true);
    try {
      final shown = await ref
          .read(purchaseOrderExporterProvider)
          .save(order, format);
      if (!mounted) return;
      // 저장 창을 취소하면 null이다. 사용자가 일부러 닫은 것이라 아무 말도
      // 하지 않는다.
      if (shown != null) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('저장했습니다: $shown')));
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('저장하지 못했습니다: $e')));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final suppliers =
        ref.watch(_suppliersProvider).valueOrNull ?? const <Supplier>[];
    Supplier? supplier;
    for (final s in suppliers) {
      if (s.id == _supplierId) supplier = s;
    }
    final order = _currentOrder(supplier);
    final hasShortages = widget.shortages.isNotEmpty;

    return Scaffold(
      appBar: AppBar(title: const Text('발주서 만들기')),
      body: hasShortages
          ? CenteredContent(
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  _buildInfoCard(suppliers),
                  const SizedBox(height: 12),
                  _buildLinesCard(),
                ],
              ),
            )
          : const EmptyState(
              icon: Icons.check_circle_outline,
              title: '부족한 품목이 없습니다',
              message: '이 매장은 안전재고 기준을 모두 채우고 있어 발주할 품목이 없습니다',
            ),
      bottomNavigationBar: hasShortages ? _buildSaveBar(order) : null,
    );
  }

  Widget _buildInfoCard(List<Supplier> suppliers) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SectionLabel('발주 정보'),
          _InfoRow(label: '매장', value: widget.store.name),
          _InfoRow(label: '발주일', value: formatPurchaseOrderDate(_date)),
          const SizedBox(height: 8),
          if (suppliers.isEmpty)
            const Text(
              '거래처 관리에서 거래처를 먼저 등록하세요',
              style: TextStyle(fontSize: 13, color: AppColors.textMuted),
            )
          else
            // 선택한 객체가 아니라 id를 값으로 쓴다. 객체를 붙잡으면 그 행이
            // 바뀔 때 목록의 항목과 같지 않게 되어 드롭다운이 깨진다.
            DropdownButtonFormField<int>(
              key: const Key('supplierDropdown'),
              initialValue: _supplierId,
              decoration: const InputDecoration(labelText: '거래처'),
              items: [
                for (final s in suppliers)
                  DropdownMenuItem(value: s.id, child: Text(s.name)),
              ],
              onChanged: (value) => setState(() => _supplierId = value),
            ),
        ],
      ),
    );
  }

  Widget _buildLinesCard() {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SectionLabel('발주 품목'),
          for (final shortage in widget.shortages) _buildLine(shortage),
        ],
      ),
    );
  }

  Widget _buildLine(StockShortage shortage) {
    final id = shortage.ingredient.id;
    final checked = !_unchecked.contains(id);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Checkbox(
            key: Key('check_$id'),
            value: checked,
            onChanged: (value) => setState(() {
              if (value ?? false) {
                _unchecked.remove(id);
              } else {
                _unchecked.add(id);
              }
            }),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  shortage.ingredient.name,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textStrong,
                  ),
                ),
                Text(
                  '부족 ${formatQty(shortage.shortfall)}'
                  '${shortage.ingredient.baseUnit}',
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textMuted,
                  ),
                ),
              ],
            ),
          ),
          SizedBox(
            width: 80,
            child: TextField(
              key: Key('qty_$id'),
              controller: _qtyControllers[id],
              enabled: checked,
              keyboardType: TextInputType.number,
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
                LengthLimitingTextInputFormatter(5),
              ],
              textAlign: TextAlign.end,
              decoration: const InputDecoration(isDense: true),
              onChanged: (_) => setState(() {}),
            ),
          ),
          const SizedBox(width: 8),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 72),
            child: Text(
              shortage.ingredient.purchaseUnit,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSaveBar(PurchaseOrder? order) {
    // 저장하는 동안에는 두 버튼 모두 막는다. 파일 만들기와 저장 창이 느릴 때
    // 두 번 누르면 같은 발주서가 두 번 저장된다.
    final current = order;
    VoidCallback? handlerFor(PurchaseOrderFormat format) =>
        (current == null || _saving) ? null : () => _save(current, format);

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Expanded(
              child: FilledButton(
                key: const Key('savePdfButton'),
                onPressed: handlerFor(PurchaseOrderFormat.pdf),
                child: const Text('PDF 저장'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: FilledButton(
                key: const Key('saveXlsxButton'),
                onPressed: handlerFor(PurchaseOrderFormat.xlsx),
                child: const Text('엑셀 저장'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          SizedBox(
            width: 56,
            child: Text(
              label,
              style: const TextStyle(fontSize: 13, color: AppColors.textMuted),
            ),
          ),
          Text(
            value,
            style: const TextStyle(fontSize: 14, color: AppColors.textStrong),
          ),
        ],
      ),
    );
  }
}
