import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/format/quantity_format.dart';
import '../../core/providers/dao_providers.dart';
import '../../core/providers/stock_date_providers.dart';
import '../../core/providers/store_providers.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/app_widgets.dart';
import '../../data/local/database.dart';
import '../../domain/stock_by_date.dart';
import '../../domain/stock_overview.dart';
import '../stock/store_switcher.dart';
import '../stock_adjustment/stock_adjustment_form_screen.dart';

const _kContentMaxWidth = 1100.0;
const _kPagePadding = 16.0;
const _kGap = 12.0;
const _kMinCardWidth = 220.0;
const _kMaxColumns = 4;

/// 이 폭보다 좁으면 앱바의 날짜 버튼이 아이콘만 남는다.
const _kNarrowWidth = 600.0;

class StockOverviewScreen extends ConsumerWidget {
  const StockOverviewScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lotDao = ref.watch(lotDaoProvider);
    final movementDao = ref.watch(stockMovementDaoProvider);
    final storeDao = ref.watch(storeDaoProvider);
    final storeId = ref.watch(activeStoreIdProvider);
    final selected = ref.watch(selectedStockDateProvider);
    final now = DateTime.now();
    final isToday = selected == null || isSameDay(selected, now);
    // isToday가 거짓이면 selected는 널이 아니다 (Dart가 isToday 변수로 타입을 좁힌다).
    final day = isToday ? dayStart(now) : selected;

    // 오늘은 지금처럼 로트의 남은 수량, 지난 날짜는 그날 끝까지의 기록 합계.
    final Stream<List<LotWithIngredient>> stockStream = isToday
        ? lotDao.watchAvailableLotsWithIngredient(storeId: storeId)
        : movementDao.watchStockAsOf(dayEnd(day), storeId: storeId);

    // 화면을 자정 넘어 켜 둬도 달력의 "오늘"이 따라가도록 누른 순간의 시각을 쓴다.
    Future<void> pickDate() async {
      final last = dayStart(DateTime.now());
      final picked = await showDatePicker(
        context: context,
        // 저장된 날짜가 미래(자정을 넘긴 경우 등)여도 달력이 단정 오류를 내지 않게.
        initialDate: day.isAfter(last) ? last : day,
        firstDate: DateTime(2020),
        lastDate: last,
      );
      if (picked == null) return;
      ref.read(selectedStockDateProvider.notifier).state = stockDateSelection(
        picked,
        now: DateTime.now(),
      );
    }

    // 폰 폭에서는 제목·날짜 버튼·매장 선택이 한 줄에 다 들어가지 않는다. 날짜는
    // 아이콘만 두고(글자는 툴팁), 지난 날짜일 때는 배너가 날짜를 보여 준다.
    final dateLabel = stockDateLabel(selected, now: now);
    final narrow = MediaQuery.sizeOf(context).width < _kNarrowWidth;
    final Widget dateButton = narrow
        ? IconButton(
            key: const Key('stockDateButton'),
            tooltip: dateLabel,
            icon: const Icon(Icons.calendar_today_outlined, size: 20),
            onPressed: pickDate,
          )
        : TextButton.icon(
            key: const Key('stockDateButton'),
            icon: const Icon(Icons.calendar_today_outlined, size: 18),
            label: Text(dateLabel),
            onPressed: pickDate,
          );

    return Scaffold(
      appBar: AppBar(
        title: const Text('재고 조회'),
        actions: [dateButton, const StoreSwitcher()],
      ),
      body: Column(
        children: [
          if (!isToday)
            _PastDateBanner(
              label: stockDateLabel(day, now: now),
              onBack: () =>
                  ref.read(selectedStockDateProvider.notifier).state = null,
            ),
          Expanded(
            child: StreamBuilder<List<Store>>(
              stream: storeDao.watchAll(),
              builder: (context, storeSnapshot) {
                final storeNames = {
                  for (final s in storeSnapshot.data ?? <Store>[]) s.id: s.name,
                };
                return StreamBuilder<List<LotWithIngredient>>(
                  // 날짜(모드)가 바뀌면 이전 모드의 마지막 값이 새 모드로 한 프레임
                  // 그려지지 않도록 상태를 새로 만든다.
                  key: ValueKey(isToday ? 'live' : day),
                  stream: stockStream,
                  builder: (context, snapshot) {
                    if (!snapshot.hasData) return const SizedBox.shrink();
                    return _StockBody(
                      rows: snapshot.data!,
                      storeNames: storeNames,
                      // 값이 올 때마다 지금 시각으로: 자정을 넘겨 켜 둔 화면의
                      // 임박 판정이 어제 기준에 머물지 않게 (옛 코드와 같다).
                      now: DateTime.now(),
                      isToday: isToday,
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

/// 지난 날짜를 보고 있다는 안내와 오늘로 돌아가는 버튼.
class _PastDateBanner extends StatelessWidget {
  const _PastDateBanner({required this.label, required this.onBack});

  final String label;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return CenteredContent(
      key: const Key('pastDateBanner'),
      maxWidth: _kContentMaxWidth,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(_kPagePadding, 12, _kPagePadding, 0),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          decoration: BoxDecoration(
            color: AppColors.chipBackground,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  '$label 기준 (조회 전용)',
                  style: const TextStyle(
                    fontSize: 13,
                    color: AppColors.textBody,
                  ),
                ),
              ),
              TextButton(
                key: const Key('backToTodayButton'),
                onPressed: onBack,
                child: const Text('오늘로 돌아가기'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StockBody extends StatelessWidget {
  const _StockBody({
    required this.rows,
    required this.storeNames,
    required this.now,
    required this.isToday,
  });

  final List<LotWithIngredient> rows;
  final Map<String, String> storeNames;
  final DateTime now;
  final bool isToday;

  @override
  Widget build(BuildContext context) {
    final groups = groupLotsByIngredient(
      rows,
      now: now,
      flagNearExpiry: isToday,
    );
    if (groups.isEmpty) {
      return EmptyState(
        icon: Icons.inventory_2_outlined,
        title: isToday ? '표시할 재고가 없습니다' : '이 날에는 표시할 재고가 없습니다',
        message: isToday ? '입고를 등록하면 여기에 나타납니다' : null,
      );
    }

    final nearExpiryLots = groups.fold<int>(
      0,
      (sum, g) =>
          sum +
          g.lots.where((l) => isNearExpiry(l.expiryDate, now: now)).length,
    );

    return CenteredContent(
      maxWidth: _kContentMaxWidth,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final columns = _columnsFor(constraints.maxWidth);
          final rowCount = (groups.length / columns).ceil();

          // 카드 줄 단위로 만들어 화면에 보이는 줄만 그린다.
          return ListView.builder(
            padding: const EdgeInsets.all(_kPagePadding),
            itemCount: rowCount + 1,
            itemBuilder: (context, index) {
              if (index == 0) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: _kGap),
                  child: _SummaryStrip(
                    itemCount: groups.length,
                    nearExpiryCount: isToday ? nearExpiryLots : null,
                  ),
                );
              }

              final start = (index - 1) * columns;
              return Padding(
                padding: const EdgeInsets.only(bottom: _kGap),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (var i = 0; i < columns; i++) ...[
                      if (i > 0) const SizedBox(width: _kGap),
                      Expanded(
                        child: start + i < groups.length
                            ? _IngredientCard(
                                group: groups[start + i],
                                storeNames: storeNames,
                                now: now,
                                readOnly: !isToday,
                              )
                            : const SizedBox.shrink(),
                      ),
                    ],
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }

  /// 카드가 [_kMinCardWidth]보다 좁아지지 않는 선에서 한 줄에 최대한 많이.
  int _columnsFor(double maxWidth) {
    final available = maxWidth - _kPagePadding * 2;
    final fit = ((available + _kGap) / (_kMinCardWidth + _kGap)).floor();
    return fit.clamp(1, _kMaxColumns);
  }
}

class _SummaryStrip extends StatelessWidget {
  const _SummaryStrip({required this.itemCount, this.nearExpiryCount});

  final int itemCount;

  /// `null`이면 유통기한 임박 타일을 그리지 않는다 (지난 날짜 조회).
  final int? nearExpiryCount;

  @override
  Widget build(BuildContext context) {
    final near = nearExpiryCount;

    return Row(
      children: [
        Expanded(
          child: _StatTile(
            label: '재고 품목',
            value: '$itemCount',
            unit: '종',
            valueKey: const Key('summaryItemCount'),
          ),
        ),
        if (near != null) ...[
          const SizedBox(width: _kGap),
          Expanded(
            child: _StatTile(
              label: '유통기한 임박',
              value: '$near',
              unit: '건',
              valueKey: const Key('summaryNearExpiryCount'),
              alert: near > 0,
            ),
          ),
        ],
      ],
    );
  }
}

class _StatTile extends StatelessWidget {
  const _StatTile({
    required this.label,
    required this.value,
    required this.unit,
    required this.valueKey,
    this.alert = false,
  });

  final String label;
  final String value;
  final String unit;
  final Key valueKey;
  final bool alert;

  @override
  Widget build(BuildContext context) {
    final color = alert ? AppColors.danger : AppColors.textStrong;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: alert ? AppColors.dangerBackground : AppColors.surface,
        border: Border.all(
          color: alert ? AppColors.dangerBorder : AppColors.border,
        ),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: alert ? AppColors.danger : AppColors.textMuted,
              ),
            ),
          ),
          Text(
            value,
            key: valueKey,
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w700,
              color: color,
              fontFeatures: AppTheme.tabularFigures,
            ),
          ),
          const SizedBox(width: 4),
          Text(unit, style: TextStyle(fontSize: 13, color: color)),
        ],
      ),
    );
  }
}

class _IngredientCard extends StatelessWidget {
  const _IngredientCard({
    required this.group,
    required this.storeNames,
    required this.now,
    this.readOnly = false,
  });

  final IngredientStockGroup group;
  final Map<String, String> storeNames;
  final DateTime now;

  /// 지난 날짜 조회: 지금 기준의 경고와 탭 이동을 없앤다.
  final bool readOnly;

  @override
  Widget build(BuildContext context) {
    final alert = group.hasNearExpiryLot;

    // 테두리를 Container의 decoration에 맡기면 마지막 로트 줄의 불투명한 배경이
    // 아래쪽 두 모서리의 호 구간 테두리를 덮는다. Material의 shape는 테두리를
    // 자식 위에 그린다.
    return Material(
      key: Key('ingredientCard_${group.ingredient.id}'),
      color: AppColors.surface,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        side: BorderSide(
          color: alert ? AppColors.dangerBorder : AppColors.border,
        ),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 8),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    group.ingredient.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textStrong,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  '${formatQty(group.totalRemainingQty)}'
                  '${group.ingredient.baseUnit}',
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textStrong,
                    fontFeatures: AppTheme.tabularFigures,
                  ),
                ),
              ],
            ),
          ),
          for (final lot in group.lots) ...[
            const Divider(height: 1, thickness: 1, color: AppColors.border),
            _LotRow(
              lot: lot,
              ingredient: group.ingredient,
              now: now,
              storeName: storeNames[lot.storeId],
              readOnly: readOnly,
            ),
          ],
        ],
      ),
    );
  }
}

class _LotRow extends StatelessWidget {
  const _LotRow({
    required this.lot,
    required this.ingredient,
    required this.now,
    this.storeName,
    this.readOnly = false,
  });

  final Lot lot;
  final Ingredient ingredient;
  final DateTime now;
  final String? storeName;
  final bool readOnly;

  @override
  Widget build(BuildContext context) {
    final near = !readOnly && isNearExpiry(lot.expiryDate, now: now);
    final expiryText = lot.expiryDate == null
        ? '유통기한 관리 안 함'
        : '기한 ${lot.expiryDate!.toIso8601String().substring(0, 10)}';

    return Material(
      color: near ? AppColors.dangerBackground : AppColors.surface,
      child: InkWell(
        onTap: readOnly
            ? null
            : () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => StockAdjustmentFormScreen(
                    lot: lot,
                    ingredient: ingredient,
                  ),
                ),
              ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 8, 8),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      expiryText,
                      style: TextStyle(
                        fontSize: 13,
                        color: lot.expiryDate == null
                            ? AppColors.textMuted
                            : AppColors.textBody,
                      ),
                    ),
                    if (storeName != null || near) ...[
                      const SizedBox(height: 4),
                      Wrap(
                        spacing: 6,
                        runSpacing: 4,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          if (storeName != null) _StoreChip(name: storeName!),
                          if (near) const _NearExpiryBadge(),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Text(
                formatQty(lot.remainingQty),
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textStrong,
                  fontFeatures: AppTheme.tabularFigures,
                ),
              ),
              if (!readOnly)
                const Icon(
                  Icons.chevron_right,
                  size: 18,
                  color: AppColors.textMuted,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StoreChip extends StatelessWidget {
  const _StoreChip({required this.name});

  final String name;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: AppColors.chipBackground,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        name,
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: AppColors.textBody,
        ),
      ),
    );
  }
}

class _NearExpiryBadge extends StatelessWidget {
  const _NearExpiryBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border.all(color: AppColors.dangerBorder),
        borderRadius: BorderRadius.circular(999),
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.schedule, size: 11, color: AppColors.danger),
          SizedBox(width: 3),
          Text(
            '임박',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: AppColors.danger,
            ),
          ),
        ],
      ),
    );
  }
}
