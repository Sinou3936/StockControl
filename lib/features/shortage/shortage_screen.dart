import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/format/quantity_format.dart';
import '../../core/providers/auth_providers.dart';
import '../../core/providers/shortage_providers.dart';
import '../../core/providers/store_providers.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/app_widgets.dart';
import '../../domain/stock_shortage.dart';
import '../inbound/inbound_form_screen.dart';
import '../stock/store_switcher.dart';

const _kContentMaxWidth = 1100.0;
const _kPagePadding = 16.0;
const _kGap = 12.0;
const _kMinCardWidth = 240.0;
const _kMaxColumns = 4;

class ShortageScreen extends ConsumerWidget {
  const ShortageScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final shortages = ref.watch(shortagesProvider);
    final ingredients =
        ref.watch(ingredientsStreamProvider).valueOrNull ?? const [];
    final hasTrackedIngredient = ingredients.any(
      (i) => (i.safetyStockQty ?? 0) > 0,
    );
    final session = ref.watch(authSessionProvider);
    final isOwner = session?.isOwner ?? false;
    final hasStoreInScope = ref.watch(shortageStoresProvider).isNotEmpty;

    return Scaffold(
      appBar: AppBar(
        title: const Text('부족 재고'),
        actions: const [StoreSwitcher()],
      ),
      body: shortages.isEmpty
          ? _buildEmpty(
              hasTrackedIngredient: hasTrackedIngredient,
              hasStoreInScope: hasStoreInScope,
              isOwner: isOwner,
              hasAssignedStore: session?.storeId != null,
            )
          : _buildGrid(shortages, showStoreName: isOwner),
    );
  }

  Widget _buildEmpty({
    required bool hasTrackedIngredient,
    required bool hasStoreInScope,
    required bool isOwner,
    required bool hasAssignedStore,
  }) {
    // 판정할 매장이 없으면 부족이 없는 것이 아니라 아무것도 보지 않은 것이다.
    // 이걸 "기준 이상"으로 안내하면 재고가 충분하다는 뜻으로 읽혀서, 알림
    // 기능이 있으나 마나 해진다.
    //
    // 원인이 역할마다 다르고, 할 수 있는 조치도 다르다. 사장은 매장을 등록하면
    // 되고, 매장이 지정되지 않은 직원은 사장에게 요청해야 하고, 지정은 됐는데
    // 그 매장이 로컬에 없는 직원은 동기화를 기다려야 한다. 한 문구로 뭉치면
    // 세 경우 중 둘에게는 거짓이 된다.
    if (!hasStoreInScope) {
      return EmptyState(
        icon: Icons.storefront_outlined,
        title: '판정할 매장이 없습니다',
        message: isOwner
            ? '매장 관리에서 매장을 등록하면 매장별로 부족한 품목을 확인할 수 있습니다'
            : hasAssignedStore
                ? '매장 정보를 아직 받지 못했습니다. 동기화한 뒤 다시 확인해주세요'
                : '계정에 매장이 지정되지 않았습니다. 사장님께 매장 지정을 요청해주세요',
      );
    }
    if (!hasTrackedIngredient) {
      return const EmptyState(
        icon: Icons.tune,
        title: '안전재고가 설정된 품목이 없습니다',
        message: '품목 관리에서 안전재고를 정하면 부족한 품목이 여기에 표시됩니다',
      );
    }
    return const EmptyState(
      icon: Icons.check_circle_outline,
      title: '모든 품목이 기준 이상입니다',
      message: '안전재고 밑으로 떨어지면 여기에 표시됩니다',
    );
  }

  Widget _buildGrid(
    List<StockShortage> shortages, {
    required bool showStoreName,
  }) {
    return CenteredContent(
      maxWidth: _kContentMaxWidth,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final columns = _columnsFor(constraints.maxWidth);
          final rowCount = (shortages.length / columns).ceil();

          return ListView.builder(
            padding: const EdgeInsets.all(_kPagePadding),
            itemCount: rowCount,
            itemBuilder: (context, rowIndex) {
              final start = rowIndex * columns;
              return Padding(
                padding: const EdgeInsets.only(bottom: _kGap),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (var i = 0; i < columns; i++) ...[
                      if (i > 0) const SizedBox(width: _kGap),
                      Expanded(
                        child: start + i < shortages.length
                            ? _ShortageCard(
                                shortage: shortages[start + i],
                                showStoreName: showStoreName,
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

  int _columnsFor(double maxWidth) {
    final available = maxWidth - _kPagePadding * 2;
    final fit = ((available + _kGap) / (_kMinCardWidth + _kGap)).floor();
    return fit.clamp(1, _kMaxColumns);
  }
}

class _ShortageCard extends ConsumerWidget {
  const _ShortageCard({required this.shortage, required this.showStoreName});

  final StockShortage shortage;
  final bool showStoreName;

  /// 부족한 품목을 바로 채울 수 있도록 입고 등록으로 보낸다. 사장이 전체 합산을
  /// 보던 중이었다면 그 카드의 매장으로 선택을 옮긴다 — 입고 등록은 매장이
  /// 정해져야 동작하고, 이 카드를 눌렀다는 것은 그 매장 일을 하겠다는 뜻이다.
  void _openInbound(BuildContext context, WidgetRef ref) {
    final session = ref.read(authSessionProvider);
    if (session?.isOwner ?? false) {
      ref.read(selectedStoreProvider.notifier).state = shortage.store;
    }
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => InboundFormScreen(
          initialIngredient: shortage.ingredient,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final empty = shortage.currentQty <= 0;
    final unit = shortage.ingredient.baseUnit;

    // 배경·테두리·반지름을 Material 하나가 맡고 그 안에 InkWell을 둔다.
    //
    // 불투명한 Container를 InkWell의 자식으로 두면 물결이 그 배경 아래에 깔려
    // 보이지 않는다. 반대로 테두리를 바깥 Container의 decoration에 맡기면,
    // Container가 자식을 테두리 두께만큼 사각으로만 밀어 넣기 때문에 둥근
    // 모서리의 호 구간에서 자식 배경이 테두리를 덮어 모서리 테두리가 사라진다.
    // shape를 쓰면 Material이 테두리를 자식보다 위에 그릴 경로를 직접 알아서,
    // 모서리가 남고 물결도 같은 경로로 잘린다.
    return Material(
      color: empty ? AppColors.dangerBackground : AppColors.surface,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        side: BorderSide(
          color: empty ? AppColors.dangerBorder : AppColors.border,
        ),
        borderRadius: BorderRadius.circular(12),
      ),
      child: InkWell(
        key: Key(
          'shortageCard_${shortage.ingredient.id}_${shortage.store.id}',
        ),
        onTap: () => _openInbound(context, ref),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      shortage.ingredient.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textStrong,
                      ),
                    ),
                  ),
                  if (showStoreName) ...[
                    const SizedBox(width: 8),
                    InfoChip(shortage.store.name),
                  ],
                ],
              ),
              const SizedBox(height: 8),
              Text(
                '${formatQty(shortage.currentQty)}$unit'
                ' / 기준 ${formatQty(shortage.safetyStockQty)}$unit',
                style: TextStyle(
                  fontSize: 13,
                  color: empty ? AppColors.danger : AppColors.textBody,
                  fontFeatures: AppTheme.tabularFigures,
                ),
              ),
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(999),
                child: LinearProgressIndicator(
                  value: shortage.fillRatio.clamp(0.0, 1.0),
                  minHeight: 6,
                  backgroundColor: AppColors.chipBackground,
                  valueColor: AlwaysStoppedAnimation(
                    empty ? AppColors.danger : AppColors.primary,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                '${formatQty(shortage.shortfall)}$unit 부족',
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: AppColors.danger,
                  fontFeatures: AppTheme.tabularFigures,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
