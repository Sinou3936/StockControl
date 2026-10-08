import 'package:flutter_riverpod/flutter_riverpod.dart';

/// 재고 조회에서 고른 날짜(시각 없는 로컬 날짜). `null`은 "오늘"이다 —
/// 화면을 자정 넘어 켜 둬도 오늘이 따라가도록 오늘 날짜를 저장하지 않는다.
final selectedStockDateProvider = StateProvider<DateTime?>((ref) => null);
