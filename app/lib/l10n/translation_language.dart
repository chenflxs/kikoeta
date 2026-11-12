import 'dart:ui' show Locale;

class TranslationLanguage {
  TranslationLanguage._();

  // Translation APIs use the language, script and region parts of BCP 47.
  static final _code = RegExp(
    r'^([a-z]{2,3})(?:-([a-z]{4}))?(?:-([a-z]{2}|[0-9]{3}))?$',
  );

  static String? normalizeCode(String? value) {
    if (value == null) return null;
    final match = _code.firstMatch(
      value.trim().toLowerCase().replaceAll('_', '-'),
    );
    if (match == null || match[1] == 'ui') return null;
    final script = match[2];
    return Locale.fromSubtags(
      languageCode: match[1]!,
      scriptCode: script == null
          ? null
          : '${script[0].toUpperCase()}${script.substring(1)}',
      countryCode: match[3]?.toUpperCase(),
    ).toLanguageTag();
  }

  static String? normalizeSetting(String? value) =>
      value?.trim().toLowerCase() == 'ui' ? 'ui' : normalizeCode(value);
}
