import 'package:flutter/material.dart';

import '../../core/format/quantity_format.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/app_widgets.dart';
import '../../domain/stock_by_date.dart';

/// 카드에 미리 보여 주는 입고 줄 수. 이보다 많으면 "전체 N건 보기" 줄이 붙는다.
const _kInboundPreviewCount = 3;

/// 재고 조회 화면의 "이 날 입고 N건" 카드. 그날 들어온 로트를 한 줄씩 보여 준다.
/// 기록을 보는 카드라서 줄은 눌리지 않는다. 입고가 많은 날 카드가 끝없이 길어지지
/// 않도록 앞 [_kInboundPreviewCount]건만 그리고, 더 있으면 전체 보기 줄을 둔다.
class InboundDayCard extends StatelessWidget {
  const InboundDayCard({
    super.key,
    required this.title,
    required this.entries,
    required this.emptyMessage,
    this.onShowAll,
  });

  /// "오늘 입고" 또는 "이 날 입고". 뒤에 건수가 붙는다.
  final String title;
  final List<InboundEntry> entries;

  /// 입고가 한 건도 없을 때 보이는 문구 ("오늘 …" 또는 "이 날 …").
  final String emptyMessage;

  /// "전체 N건 보기" 줄을 눌렀을 때. 입고가 미리보기 건수 이하면 그 줄이 없다.
  final VoidCallback? onShowAll;

  @override
  Widget build(BuildContext context) {
    // 재고 카드와 같다: 테두리를 Container 장식에 맡기면 불투명한 자식이
    // 둥근 모서리의 테두리를 덮는다. Material의 shape는 자식 위에 그린다.
    return Material(
      key: const Key('inboundDayCard'),
      color: AppColors.surface,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        side: const BorderSide(color: AppColors.border),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 8),
            child: Text(
              '$title ${entries.length}건',
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: AppColors.textStrong,
              ),
            ),
          ),
          if (entries.isEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
              child: Text(
                emptyMessage,
                style: const TextStyle(
                  fontSize: 13,
                  color: AppColors.textMuted,
                ),
              ),
            )
          else
            for (final entry in entries.take(_kInboundPreviewCount)) ...[
              const Divider(height: 1, thickness: 1, color: AppColors.border),
              InboundRow(
                key: Key('inboundEntry_${entry.movement.id}'),
                entry: entry,
              ),
            ],
          if (entries.length > _kInboundPreviewCount) ...[
            const Divider(height: 1, thickness: 1, color: AppColors.border),
            InkWell(
              key: const Key('inboundShowAll'),
              onTap: onShowAll,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 12, 8, 12),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        '전체 ${entries.length}건 보기',
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: AppColors.primary,
                        ),
                      ),
                    ),
                    const Icon(
                      Icons.chevron_right,
                      size: 18,
                      color: AppColors.textMuted,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// 입고 한 줄: 품목 · 수량 · 매장 칩 · 거래처. 카드와 전체 보기 화면이 같이 쓴다.
class InboundRow extends StatelessWidget {
  const InboundRow({super.key, required this.entry});

  final InboundEntry entry;

  @override
  Widget build(BuildContext context) {
    final storeName = entry.storeName;
    final supplierName = entry.supplierName;

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  entry.ingredient.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textStrong,
                  ),
                ),
                if (storeName != null || supplierName != null) ...[
                  const SizedBox(height: 4),
                  Wrap(
                    spacing: 6,
                    runSpacing: 4,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      if (storeName != null) InfoChip(storeName),
                      if (supplierName != null)
                        Text(
                          supplierName,
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.textMuted,
                          ),
                        ),
                    ],
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text(
            '${formatQty(entry.movement.quantity)}${entry.ingredient.baseUnit}',
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: AppColors.textStrong,
              fontFeatures: AppTheme.tabularFigures,
            ),
          ),
        ],
      ),
    );
  }
}
