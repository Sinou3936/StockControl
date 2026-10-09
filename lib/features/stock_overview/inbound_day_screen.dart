import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers/dao_providers.dart';
import '../../core/providers/store_providers.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/app_widgets.dart';
import '../../domain/stock_by_date.dart';
import 'inbound_day_card.dart';

const _kContentMaxWidth = 1100.0;
const _kPagePadding = 16.0;

/// 재고 조회 화면의 입고 카드에서 "전체 N건 보기"를 누르면 열리는 화면. 그날
/// 들어온 입고 전부를 한 줄씩 보여 준다. 기록을 보는 화면이라 줄은 눌리지 않는다.
///
/// 여는 순간의 [day]로 고정된다 (잠깐 보고 닫는 화면이라 자정을 넘겨 켜 두는
/// 경우는 따로 다루지 않는다). 매장 범위는 재고 조회 화면과 같은
/// `activeStoreIdProvider`이고, 열려 있는 동안 새 입고가 들어오면 바로 반영된다.
class InboundDayScreen extends ConsumerWidget {
  const InboundDayScreen({super.key, required this.day, required this.title});

  /// 보여 줄 날짜. 시각은 쓰지 않는다 (하루의 경계는 [dayEnd]가 정한다).
  final DateTime day;

  /// 앱바 제목의 앞부분: "오늘 입고" 또는 "10월 5일 입고". 뒤에 건수가 붙는다.
  final String title;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stream = ref
        .watch(stockMovementDaoProvider)
        .watchInboundOn(
          dayStart(day),
          dayEnd(day),
          storeId: ref.watch(activeStoreIdProvider),
        );

    return StreamBuilder<List<InboundEntry>>(
      stream: stream,
      builder: (context, snapshot) {
        final entries = snapshot.data;
        return Scaffold(
          key: const Key('inboundDayScreen'),
          appBar: AppBar(
            title: Text(entries == null ? title : '$title ${entries.length}건'),
          ),
          body: entries == null
              ? const SizedBox.shrink()
              : CenteredContent(
                  maxWidth: _kContentMaxWidth,
                  child: ListView.builder(
                    padding: const EdgeInsets.all(_kPagePadding),
                    itemCount: entries.length,
                    itemBuilder: (context, index) =>
                        _InboundRowCard(entry: entries[index]),
                  ),
                ),
        );
      },
    );
  }
}

/// 줄 하나를 테두리 있는 카드로 감싼다. 입고 카드와 같은 모양이다: 테두리는
/// Container 장식이 아니라 Material의 shape로 그려 자식이 둥근 모서리를 덮지 않게 한다.
class _InboundRowCard extends StatelessWidget {
  const _InboundRowCard({required this.entry});

  final InboundEntry entry;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: AppColors.surface,
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(
          side: const BorderSide(color: AppColors.border),
          borderRadius: BorderRadius.circular(12),
        ),
        child: InboundRow(
          key: Key('inboundEntry_${entry.movement.id}'),
          entry: entry,
        ),
      ),
    );
  }
}
