import 'package:flutter/material.dart';

/// 업무용 평면(Flat) 스타일: 그림자 없이 얇은 선으로 구분하고, 색은 슬레이트
/// 한 계열 + 경고용 빨강만 쓴다.
class AppColors {
  AppColors._();

  static const background = Color(0xFFF8FAFC);
  static const surface = Colors.white;
  static const border = Color(0xFFE2E8F0);

  static const textStrong = Color(0xFF0F172A);
  static const textBody = Color(0xFF334155);
  static const textMuted = Color(0xFF64748B);

  static const primary = Color(0xFF334155);
  static const chipBackground = Color(0xFFF1F5F9);

  static const danger = Color(0xFFB91C1C);
  static const dangerBackground = Color(0xFFFEF2F2);
  static const dangerBorder = Color(0xFFFECACA);
}

class AppTheme {
  AppTheme._();

  /// 수량처럼 자리를 맞춰 읽어야 하는 숫자에 쓴다.
  static const tabularFigures = [FontFeature.tabularFigures()];

  static ThemeData light() {
    final scheme = ColorScheme.fromSeed(
      seedColor: AppColors.primary,
      brightness: Brightness.light,
    ).copyWith(
      primary: AppColors.primary,
      onPrimary: Colors.white,
      surface: AppColors.surface,
      onSurface: AppColors.textStrong,
      error: AppColors.danger,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: AppColors.background,
      dividerColor: AppColors.border,
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.surface,
        foregroundColor: AppColors.textStrong,
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        shape: Border(bottom: BorderSide(color: AppColors.border)),
        titleTextStyle: TextStyle(
          color: AppColors.textStrong,
          fontSize: 18,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
