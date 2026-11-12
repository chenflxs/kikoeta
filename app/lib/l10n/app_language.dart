import 'dart:ui' show PlatformDispatcher;

import 'package:flutter/widgets.dart';

import 'generated/app_localizations.dart';

/// UI 语言偏好与可用资源。未开放的语言不参与系统语言匹配。
class AppLanguage {
  AppLanguage._();

  static const system = 'system';
  static const simplifiedChinese = 'zh-CN';
  static const traditionalChinese = 'zh-TW';
  static const english = 'en';
  static const japanese = 'ja';
  static const russian = 'ru';
  static const selectablePreferences = [
    system,
    simplifiedChinese,
    traditionalChinese,
    english,
    japanese,
    russian,
  ];
  static String _preference = system;

  static String get preference => _preference;

  static void setPreference(String value) {
    if (selectablePreferences.contains(value)) _preference = value;
  }

  static Locale? get localeOverride => switch (_preference) {
    simplifiedChinese => const Locale('zh', 'CN'),
    traditionalChinese => const Locale.fromSubtags(
      languageCode: 'zh',
      scriptCode: 'Hant',
      countryCode: 'TW',
    ),
    english => const Locale('en'),
    japanese => const Locale('ja'),
    russian => const Locale('ru'),
    _ => null,
  };

  static Locale resolveLocale(List<Locale> systemLocales) => resolveLocales(
    localeOverride == null ? systemLocales : [localeOverride!],
    AppLocalizations.supportedLocales,
  );

  static Locale resolveLocales(
    List<Locale>? preferredLocales,
    Iterable<Locale> supportedLocales,
  ) => basicLocaleListResolution(
    preferredLocales?.map((locale) {
      // Some platforms report traditional regions without a script subtag.
      if (locale.languageCode == 'zh' &&
          locale.scriptCode == null &&
          const ['TW', 'HK', 'MO'].contains(locale.countryCode)) {
        return Locale.fromSubtags(
          languageCode: 'zh',
          scriptCode: 'Hant',
          countryCode: locale.countryCode,
        );
      }
      return locale;
    }).toList(),
    supportedLocales,
  );

  static Locale get resolvedLocale =>
      resolveLocale(PlatformDispatcher.instance.locales);

  static String get translationTarget => _translationTag(resolvedLocale);

  static String get systemTranslationTag =>
      _translationTag(WidgetsBinding.instance.platformDispatcher.locale);

  static String _translationTag(Locale locale) {
    if (locale.languageCode == 'zh') {
      return (locale.scriptCode == 'Hant' ||
              (locale.scriptCode == null &&
                  const ['TW', 'HK', 'MO'].contains(locale.countryCode)))
          ? 'zh-TW'
          : 'zh-CN';
    }
    return locale.languageCode;
  }

  static AppLocalizations? _cachedStrings;
  static Locale? _cachedLocale;

  /// 无 BuildContext 的服务提示使用同一套已解析的 UI 语言。
  static AppLocalizations get strings {
    final locale = resolvedLocale;
    if (_cachedLocale != locale || _cachedStrings == null) {
      _cachedLocale = locale;
      _cachedStrings = lookupAppLocalizations(locale);
    }
    return _cachedStrings!;
  }
}
