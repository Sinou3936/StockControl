import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/format/quantity_format.dart';
import '../../core/providers/store_providers.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/app_widgets.dart';
import '../../data/import/excel_import_service.dart';
import '../../data/import/import_file_gateway.dart';
import '../../data/import/import_template.dart';
import '../../data/import/import_workbook_reader.dart';
import '../stock/store_switcher.dart';

/// 미리보기에서 보여 주는 입고 줄·중복 줄 수. 넘으면 "외 N건".
const _kPreviewLines = 10;

String _dateText(DateTime d) {
  String two(int n) => n.toString().padLeft(2, '0');
  return '${d.year}-${two(d.month)}-${two(d.day)}';
}

/// 사장 전용: 양식을 받아 채운 엑셀 파일로 거래처·품목·입고를 한 번에 등록한다.
/// 파일 하나는 매장 하나이고, 매장은 입고 등록과 같이 오른쪽 위에서 고른다.
class ExcelImportScreen extends ConsumerStatefulWidget {
  const ExcelImportScreen({super.key});

  @override
  ConsumerState<ExcelImportScreen> createState() => _ExcelImportScreenState();
}

class _ExcelImportScreenState extends ConsumerState<ExcelImportScreen> {
  ImportPreview? _preview;
  String? _templateMessage;
  String? _resultMessage;
  String? _problem;
  bool _confirmedDuplicates = false;
  bool _busy = false;

  void _resetPreview() {
    _preview = null;
    _confirmedDuplicates = false;
  }

  Future<void> _saveTemplate() async {
    final shown = await ref
        .read(importFileGatewayProvider)
        .saveTemplate(buildImportTemplateXlsx());
    if (!mounted) return;
    setState(() => _templateMessage = shown == null ? null : '저장했습니다: $shown');
  }

  Future<void> _pickFile(String storeId) async {
    if (_busy) return;
    final bytes = await ref.read(importFileGatewayProvider).pickWorkbook();
    if (bytes == null || !mounted) return;

    setState(() {
      _busy = true;
      _problem = null;
      _resultMessage = null;
    });
    try {
      final preview = await ref
          .read(excelImportServiceProvider)
          .prepare(bytes: bytes, storeId: storeId);
      if (!mounted) return;
      setState(() {
        _preview = preview;
        _confirmedDuplicates = false;
      });
    } on ImportFileException catch (e) {
      if (mounted) setState(() => _problem = e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _commit(String storeId) async {
    final plan = _preview?.validation.plan;
    if (plan == null || _busy) return;

    setState(() {
      _busy = true;
      _problem = null;
    });
    try {
      final result = await ref
          .read(excelImportServiceProvider)
          .commit(plan: plan, storeId: storeId);
      if (!mounted) return;
      final first = result.firstDate;
      final last = result.lastDate;
      final storeName = ref.read(selectedStoreProvider)?.name;
      setState(() {
        _resetPreview();
        _resultMessage =
            '${storeName == null ? '' : '$storeName에 '}'
            '거래처 ${result.newSuppliers}, 품목 ${result.newIngredients}, '
            '입고 ${result.inboundCount}건을 등록했습니다'
            '${first == null || last == null ? '' : ' (${_dateText(first)} ~ ${_dateText(last)})'}';
      });
      // 탭 화면처럼 pop 하지 않는다: 화면을 비우고 결과를 보여 준다.
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('엑셀 업로드를 마쳤습니다')));
    } catch (e) {
      if (mounted) {
        setState(() => _problem = '저장하지 못했습니다. 아무것도 저장되지 않았습니다. ($e)');
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final storeId = ref.watch(activeStoreIdProvider);
    // 매장을 바꾸면 이전 매장 기준으로 만든 미리보기(중복 조회)는 쓸 수 없다.
    ref.listen(activeStoreIdProvider, (previous, next) {
      if (previous != next) setState(_resetPreview);
    });

    return Scaffold(
      appBar: AppBar(
        title: const Text('엑셀 업로드'),
        actions: const [StoreSwitcher()],
      ),
      body: storeId == null
          ? const EmptyState(
              icon: Icons.upload_file_outlined,
              title: '매장을 선택해주세요',
              message: '오른쪽 위에서 업로드할 매장을 고르세요',
            )
          : CenteredContent(
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  if (_problem != null) ...[
                    InlineError(_problem!),
                    const SizedBox(height: 12),
                  ],
                  if (_preview == null)
                    _buildStart(storeId)
                  else
                    _buildPreview(storeId, _preview!),
                ],
              ),
            ),
    );
  }

  Widget _buildStart(String storeId) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SectionLabel('엑셀로 한 번에 등록'),
              const Text(
                '양식을 받아 거래처, 품목, 입고를 채운 뒤 올려 주세요. '
                '파일 하나는 매장 하나입니다.',
                style: TextStyle(fontSize: 13, color: AppColors.textBody),
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                key: const Key('templateButton'),
                onPressed: _saveTemplate,
                icon: const Icon(Icons.download_outlined),
                label: const Text('양식 받기'),
              ),
              if (_templateMessage != null) ...[
                const SizedBox(height: 8),
                Text(
                  _templateMessage!,
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textMuted,
                  ),
                ),
              ],
              const SizedBox(height: 12),
              FilledButton.icon(
                key: const Key('pickFileButton'),
                onPressed: _busy ? null : () => _pickFile(storeId),
                icon: const Icon(Icons.upload_file_outlined),
                label: const Text('파일 선택'),
              ),
            ],
          ),
        ),
        if (_resultMessage != null) ...[
          const SizedBox(height: 12),
          AppCard(
            key: const Key('resultCard'),
            child: Text(
              _resultMessage!,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: AppColors.textStrong,
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildPreview(String storeId, ImportPreview preview) {
    final validation = preview.validation;
    final anotherFile = OutlinedButton(
      key: const Key('anotherFileButton'),
      onPressed: () => setState(_resetPreview),
      child: const Text('다른 파일 선택'),
    );

    if (!validation.isValid) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AppCard(
            key: const Key('errorList'),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SectionLabel(
                  '오류 ${validation.errors.length}줄 — 고친 뒤 다시 올려 주세요',
                ),
                for (final e in validation.shownErrors)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Text(
                      e.text,
                      style: const TextStyle(
                        fontSize: 13,
                        color: AppColors.danger,
                      ),
                    ),
                  ),
                if (validation.hiddenErrorCount > 0)
                  Text(
                    '외 ${validation.hiddenErrorCount}개',
                    style: const TextStyle(
                      fontSize: 13,
                      color: AppColors.textMuted,
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          anotherFile,
        ],
      );
    }

    final plan = validation.plan!;
    final first = plan.firstDate;
    final last = plan.lastDate;
    final hasDuplicates = preview.duplicates.isNotEmpty;
    final canCommit = !_busy && (!hasDuplicates || _confirmedDuplicates);

    final storeName = ref.watch(selectedStoreProvider)?.name;

    Text line(String text) => Text(
      text,
      style: const TextStyle(fontSize: 14, color: AppColors.textStrong),
    );

    // 새로 만들어질 이름. 눈에 같아 보이는 이름이 새 품목으로 잘못 잡히는 것을
    // 올리기 전에 알아챌 수 있게 한다.
    Widget nameLine(String label, List<String> names) {
      final shown = names.take(_kPreviewLines).join(', ');
      final more = names.length - _kPreviewLines;
      return Padding(
        padding: const EdgeInsets.only(bottom: 4),
        child: Text(
          '$label: $shown${more > 0 ? ' 외 $more개' : ''}',
          style: const TextStyle(fontSize: 13, color: AppColors.textBody),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AppCard(
          key: const Key('previewSummary'),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SectionLabel('올리기 전에 확인하세요'),
              // 되돌리기 기능이 없으므로 어느 매장에 올라가는지 눈에 띄게 보인다.
              if (storeName != null) line('매장 $storeName'),
              line('새 거래처 ${plan.newSuppliers.length}'),
              if (plan.newSuppliers.isNotEmpty)
                nameLine('새 거래처', [for (final s in plan.newSuppliers) s.name]),
              line('새 품목 ${plan.newIngredients.length}'),
              if (plan.newIngredients.isNotEmpty)
                nameLine('새 품목', [for (final i in plan.newIngredients) i.name]),
              line('입고 ${plan.inboundLines.length}건'),
              line('단가 없음 ${plan.noPriceCount}건'),
              if (plan.ignoredExpiryCount > 0)
                line('유통기한 무시 ${plan.ignoredExpiryCount}건'),
              if (first != null && last != null)
                line('입고 날짜 ${_dateText(first)} ~ ${_dateText(last)}'),
            ],
          ),
        ),
        if (plan.inboundLines.isNotEmpty) ...[
          const SizedBox(height: 12),
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SectionLabel('수량 환산 (구매 단위 × 환산계수 = 기본 단위)'),
                for (final l in plan.inboundLines.take(_kPreviewLines))
                  Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Text(
                      '${l.ingredientName} · ${formatQty(l.purchaseQty)}${l.purchaseUnit}'
                      ' × ${formatQty(l.conversionFactor)}'
                      ' = ${formatQty(l.baseQty)}${l.baseUnit}',
                      style: const TextStyle(
                        fontSize: 13,
                        color: AppColors.textBody,
                      ),
                    ),
                  ),
                if (plan.inboundLines.length > _kPreviewLines)
                  Text(
                    '외 ${plan.inboundLines.length - _kPreviewLines}건',
                    style: const TextStyle(
                      fontSize: 13,
                      color: AppColors.textMuted,
                    ),
                  ),
              ],
            ),
          ),
        ],
        if (hasDuplicates) ...[
          const SizedBox(height: 12),
          AppCard(
            key: const Key('duplicateList'),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SectionLabel('이미 같은 입고가 있습니다 (${preview.duplicates.length}건)'),
                for (final d in preview.duplicates.take(_kPreviewLines))
                  Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Text(
                      '입고 시트 ${d.rowNumber}번째 줄 · ${d.ingredientName}'
                      ' · ${_dateText(d.receivedAt)} · ${formatQty(d.baseQty)}',
                      style: const TextStyle(
                        fontSize: 13,
                        color: AppColors.danger,
                      ),
                    ),
                  ),
                if (preview.duplicates.length > _kPreviewLines)
                  Text(
                    '외 ${preview.duplicates.length - _kPreviewLines}건',
                    style: const TextStyle(
                      fontSize: 13,
                      color: AppColors.textMuted,
                    ),
                  ),
                CheckboxListTile(
                  key: const Key('duplicateConfirm'),
                  contentPadding: EdgeInsets.zero,
                  controlAffinity: ListTileControlAffinity.leading,
                  title: const Text('알고 있습니다. 그래도 올리기'),
                  value: _confirmedDuplicates,
                  onChanged: (value) =>
                      setState(() => _confirmedDuplicates = value ?? false),
                ),
              ],
            ),
          ),
        ],
        const SizedBox(height: 12),
        FilledButton(
          key: const Key('commitButton'),
          onPressed: canCommit ? () => _commit(storeId) : null,
          child: const Text('올리기'),
        ),
        const SizedBox(height: 8),
        anotherFile,
      ],
    );
  }
}
