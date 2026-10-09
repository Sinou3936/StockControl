import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

/// 앱의 언어는 한국어 하나다. 이 설정이 없으면 Flutter 기본 문구가 영어로 나온다
/// (날짜 선택 달력의 "Select date"/"OK"/"Cancel", 뒤로 가기 말풍선 "Back" 등).
const appLocale = Locale('ko');

const appSupportedLocales = [appLocale];

const appLocalizationsDelegates = <LocalizationsDelegate<dynamic>>[
  GlobalMaterialLocalizations.delegate,
  GlobalWidgetsLocalizations.delegate,
  GlobalCupertinoLocalizations.delegate,
];
