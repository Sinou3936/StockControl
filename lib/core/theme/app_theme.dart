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
    final scheme =
        ColorScheme.fromSeed(
          seedColor: AppColors.primary,
          brightness: Brightness.light,
        ).copyWith(
          primary: AppColors.primary,
          onPrimary: Colors.white,
          surface: AppColors.surface,
          onSurface: AppColors.textStrong,
          error: AppColors.danger,
        );

    final fieldBorder = OutlineInputBorder(
      borderRadius: BorderRadius.circular(10),
      borderSide: const BorderSide(color: AppColors.border),
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: AppColors.background,
      dividerColor: AppColors.border,
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.surface,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 14,
        ),
        border: fieldBorder,
        enabledBorder: fieldBorder,
        focusedBorder: fieldBorder.copyWith(
          borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
        ),
        errorBorder: fieldBorder.copyWith(
          borderSide: const BorderSide(color: AppColors.danger),
        ),
        focusedErrorBorder: fieldBorder.copyWith(
          borderSide: const BorderSide(color: AppColors.danger, width: 1.5),
        ),
        labelStyle: const TextStyle(color: AppColors.textMuted),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          elevation: 0,
          minimumSize: const Size(0, 48),
          padding: const EdgeInsets.symmetric(horizontal: 20),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppColors.primary,
          textStyle: const TextStyle(fontWeight: FontWeight.w600),
        ),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: AppColors.surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: AppColors.border),
        ),
        titleTextStyle: const TextStyle(
          color: AppColors.textStrong,
          fontSize: 18,
          fontWeight: FontWeight.w700,
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: AppColors.textStrong,
        contentTextStyle: const TextStyle(color: Colors.white, fontSize: 14),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
      listTileTheme: const ListTileThemeData(
        titleTextStyle: TextStyle(
          color: AppColors.textStrong,
          fontSize: 15,
          fontWeight: FontWeight.w600,
        ),
        subtitleTextStyle: TextStyle(color: AppColors.textMuted, fontSize: 13),
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: AppColors.surface,
        selectedItemColor: AppColors.primary,
        unselectedItemColor: AppColors.textMuted,
        type: BottomNavigationBarType.fixed,
        elevation: 0,
        selectedLabelStyle: TextStyle(fontWeight: FontWeight.w700),
      ),
      navigationRailTheme: const NavigationRailThemeData(
        backgroundColor: AppColors.surface,
        indicatorColor: AppColors.chipBackground,
        selectedIconTheme: IconThemeData(color: AppColors.primary),
        unselectedIconTheme: IconThemeData(color: AppColors.textMuted),
        selectedLabelTextStyle: TextStyle(
          color: AppColors.primary,
          fontSize: 12,
          fontWeight: FontWeight.w700,
        ),
        unselectedLabelTextStyle: TextStyle(
          color: AppColors.textMuted,
          fontSize: 12,
        ),
      ),
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
