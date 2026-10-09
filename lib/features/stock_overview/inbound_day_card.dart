import 'package:flutter/material.dart';

import '../../core/format/quantity_format.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/app_widgets.dart';
import '../../domain/stock_by_date.dart';

/// 재고 조회 화면의 "이 날 입고 N건" 카드. 그날 들어온 로트를 한 줄씩 보여 준다.
/// 기록을 보는 카드라서 줄은 눌리지 않는다.
class InboundDayCard extends StatelessWidget {
  const InboundDayCard({super.key, required this.title, required this.entries});

  /// "오늘 입고" 또는 "이 날 입고". 뒤에 건수가 붙는다.
  final String title;
  final List<InboundEntry> entries;

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
            const Padding(
              padding: EdgeInsets.fromLTRB(12, 0, 12, 12),
              child: Text(
                '이 날 입고된 재고가 없습니다',
                style: TextStyle(fontSize: 13, color: AppColors.textMuted),
              ),
            )
          else
            for (final entry in entries) ...[
              const Divider(height: 1, thickness: 1, color: AppColors.border),
              _InboundRow(
                key: Key('inboundEntry_${entry.movement.id}'),
                entry: entry,
              ),
            ],
        ],
      ),
    );
  }
}

class _InboundRow extends StatelessWidget {
  const _InboundRow({super.key, required this.entry});

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
