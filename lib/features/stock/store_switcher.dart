import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers/auth_providers.dart';
import '../../core/providers/store_providers.dart';
import '../../core/theme/app_theme.dart';
import '../../data/local/database.dart';

/// 닫힌 스위처의 선택값이 차지할 수 있는 화면 폭의 최대 비율. 앱바에는 제목,
/// 날짜 버튼, 스위처의 테두리·화살표도 함께 들어가서, 이보다 크면 폰 폭(320~360)에서
/// 제목이 자기 글자 폭보다 좁게 눌린다.
const _kSelectedMaxWidthFraction = 0.22;

/// 펼친 메뉴의 폭. 매장명이 한 줄에 들어갈 만큼 넓힌다.
const _kMenuWidth = 260.0;

class StoreSwitcher extends ConsumerWidget {
  const StoreSwitcher({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isOwner = ref.watch(authSessionProvider)?.isOwner ?? false;
    if (!isOwner) return const SizedBox.shrink();

    final dao = ref.watch(storeDaoProvider);
    final selected = ref.watch(selectedStoreProvider);

    return StreamBuilder<List<Store>>(
      stream: dao.watchAll(),
      builder: (context, snapshot) {
        // 목록이 도착하기 전에는 선택값을 담을 항목이 없어 드롭다운이 오류를 낸다.
        if (!snapshot.hasData) return const SizedBox.shrink();
        final stores = snapshot.data!;

        // 선택값은 목록 안의 같은 id 항목으로 맞춘다(객체가 달라도 안전하게).
        Store? current;
        if (selected != null) {
          for (final store in stores) {
            if (store.id == selected.id) current = store;
          }
        }

        // 닫힌 상태에서 보이는 선택값만 폭을 제한한다. 긴 매장명이 좁은 앱바에서
        // 제목을 밀어내지 않게 하려는 것이고, 펼친 메뉴의 항목은 전체 이름을 쓴다.
        // isExpanded는 앱바 actions의 무제한 폭에서 항상 최대 폭을 차지해 쓰지 않는다.
        final screenWidth = MediaQuery.sizeOf(context).width;
        final maxSelectedWidth = screenWidth * _kSelectedMaxWidthFraction;
        // 메뉴 폭은 기본이 닫힌 버튼의 폭이라, 위에서 줄인 버튼을 따라 메뉴도
        // 좁아져 이름이 줄바꿈된다. 메뉴는 따로 넓혀 전체 이름을 한 줄에 보인다.
        final menuWidth = screenWidth < _kMenuWidth + 32
            ? screenWidth - 32
            : _kMenuWidth;
        Widget selectedText(String text) => ConstrainedBox(
          constraints: BoxConstraints(maxWidth: maxSelectedWidth),
          child: Text(text, maxLines: 1, overflow: TextOverflow.ellipsis),
        );

        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              border: Border.all(color: AppColors.border),
              borderRadius: BorderRadius.circular(999),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<Store?>(
                key: const Key('storeSwitcherDropdown'),
                value: current,
                isDense: true,
                menuWidth: menuWidth,
                borderRadius: BorderRadius.circular(12),
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textBody,
                ),
                // items와 같은 길이·순서여야 한다.
                selectedItemBuilder: (context) => [
                  selectedText('전체 합산'),
                  for (final store in stores) selectedText(store.name),
                ],
                items: [
                  const DropdownMenuItem<Store?>(
                    value: null,
                    child: Text('전체 합산'),
                  ),
                  for (final store in stores)
                    DropdownMenuItem<Store?>(
                      value: store,
                      child: Text(store.name),
                    ),
                ],
                onChanged: (value) =>
                    ref.read(selectedStoreProvider.notifier).state = value,
              ),
            ),
          ),
        );
      },
    );
  }
}
