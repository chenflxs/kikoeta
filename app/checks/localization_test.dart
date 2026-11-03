import 'dart:isolate';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kikoeta_app/data.dart';
import 'package:kikoeta_app/l10n/app_language.dart';
import 'package:kikoeta_app/l10n/generated/app_localizations.dart';
import 'package:kikoeta_app/l10n/strings.dart';
import 'package:kikoeta_app/pages/settings_page.dart';
import 'package:kikoeta_app/theme.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => AppLanguage.setPreference(AppLanguage.system));
  tearDown(() => AppLanguage.setPreference(AppLanguage.system));

  test(
    'system locales resolve supported languages and fall back to English',
    () {
      expect(AppLanguage.preference, 'system');
      expect(AppLanguage.localeOverride, isNull);
      for (final locale in const [Locale('en', 'US'), Locale('ru')]) {
        final resolved = AppLanguage.resolveLocale([locale]);
        final strings = lookupAppLocalizations(resolved);
        expect(strings.languageAndTranslation, 'Language and translation');
        expect(strings.confirm, 'Confirm');
      }
      expect(AppLanguage.resolveLocale([]), const Locale('en'));
      expect(
        AppLanguage.resolveLocale([const Locale('zh', 'CN')]),
        const Locale('zh', 'CN'),
      );
      expect(AppLocalizations.supportedLocales.first, const Locale('en'));
    },
  );

  test(
    'language preferences persist and unavailable languages are rejected',
    () {
      final saved = <String, String>{};
      final app = AppState(
        languageSettingsWriter: (key, value) => saved[key] = value,
      );
      addTearDown(app.dispose);
      var notifications = 0;
      app.addListener(() => notifications++);

      for (final value in ['ru', 'invalid']) {
        app.setUiLanguage(value);
      }
      expect(saved, isEmpty);
      expect(app.uiLanguage, 'system');
      app.setUiLanguage('zh-CN');
      expect(saved, {'ui_language': 'zh-CN'});
      expect(AppLanguage.localeOverride, const Locale('zh', 'CN'));
      expect(notifications, 1);
      app.setUiLanguage('zh-CN');
      expect(notifications, 1);
      app.setUiLanguage('en');
      expect(app.uiLanguage, 'en');
      expect(saved, {'ui_language': 'en'});
      expect(AppLanguage.localeOverride, const Locale('en'));
      expect(
        AppLanguage.resolveLocale([const Locale('zh', 'CN')]),
        const Locale('en'),
      );
      expect(appL10n.confirm, 'Confirm');
      expect(notifications, 2);
      app.setUiLanguage('en');
      expect(notifications, 2);
      app.setUiLanguage('zh-TW');
      expect(app.uiLanguage, 'zh-TW');
      expect(saved, {'ui_language': 'zh-TW'});
      expect(
        AppLanguage.localeOverride,
        const Locale.fromSubtags(
          languageCode: 'zh',
          scriptCode: 'Hant',
          countryCode: 'TW',
        ),
      );
      expect(appL10n.settings, '設定');
      expect(notifications, 3);
      app.setUiLanguage('ja');
      expect(app.uiLanguage, 'ja');
      expect(saved, {'ui_language': 'ja'});
      expect(AppLanguage.localeOverride, const Locale('ja'));
      expect(appL10n.settings, '設定');
      expect(appL10n.confirm, '確認');
      expect(notifications, 4);
    },
  );

  test(
    'background import workers can read localized progress messages',
    () async {
      expect(await Isolate.run(() => appL10n.confirm), 'Confirm');
    },
  );

  testWidgets(
    'follow UI resolves English and follows explicit language changes',
    (tester) async {
      tester.binding.platformDispatcher.localesTestValue = const [
        Locale('en', 'US'),
      ];
      addTearDown(tester.binding.platformDispatcher.clearLocalesTestValue);
      final saved = <String, String>{};
      final app = AppState(
        languageSettingsWriter: (key, value) => saved[key] = value,
      );
      addTearDown(app.dispose);
      app.setTranslationTarget('ui');
      expect(saved['translation_target'], 'ui');
      expect(app.translationTarget, 'ui');
      expect(app.resolvedTranslationTarget, 'en');
      app.setUiLanguage('zh-CN');
      expect(app.resolvedTranslationTarget, 'zh-CN');
      app.setUiLanguage('zh-TW');
      expect(app.resolvedTranslationTarget, 'zh-TW');
      app.setUiLanguage('ja');
      expect(app.resolvedTranslationTarget, 'ja');
      app.setUiLanguage('en');
      expect(app.resolvedTranslationTarget, 'en');
      app.setTranslationTarget('en');
      expect(app.resolvedTranslationTarget, 'en');
      app.setTranslationTarget('zh-TW');
      expect(app.resolvedTranslationTarget, 'zh-TW');
      app.setTranslationTarget('invalid');
      expect(app.translationTarget, 'zh-TW');
    },
  );

  Future<void> showSettings(
    WidgetTester tester,
    AppState app, {
    String? section = 'translation',
  }) async {
    await tester.pumpWidget(
      AnimatedBuilder(
        animation: app,
        builder: (context, _) => MaterialApp(
          locale: AppLanguage.localeOverride,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          localeListResolutionCallback: AppLanguage.resolveLocales,
          theme: buildTheme(Brightness.light),
          home: SettingsPage(app: app, sectionKey: section),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('language menu switches Japanese, English, Chinese, and system', (
    tester,
  ) async {
    final saved = <String, String>{};
    final app = AppState(
      languageSettingsWriter: (key, value) => saved[key] = value,
    );
    addTearDown(app.dispose);
    await showSettings(tester, app);
    expect(find.text('Language and translation'), findsOneWidget);
    expect(
      tester.getTopLeft(find.text('Interface language')).dy,
      lessThan(tester.getTopLeft(find.text('Translation engine')).dy),
    );
    expect(find.text('Follow system'), findsOneWidget);

    await tester.tap(find.byTooltip('Interface language'));
    await tester.pumpAndSettle();
    final entries = tester
        .widgetList<PopupMenuItem<String>>(find.byType(PopupMenuItem<String>))
        .where((entry) => entry.value != null)
        .toList();
    expect(entries.map((entry) => entry.value), [
      'system',
      'zh-CN',
      'zh-TW',
      'ja',
      'en',
      'ru',
    ]);
    expect(
      entries.where((entry) => entry.enabled).map((entry) => entry.value),
      ['system', 'zh-CN', 'zh-TW', 'ja', 'en'],
    );
    for (final label in ['繁體中文', '日本語 (beta)', 'English (beta)', 'Русский']) {
      expect(find.text(label), findsOneWidget);
    }
    await tester.tap(find.text('日本語 (beta)'));
    await tester.pumpAndSettle();
    expect(app.uiLanguage, 'ja');
    expect(saved['ui_language'], 'ja');
    expect(find.text('言語と翻訳'), findsOneWidget);
    await tester.tap(find.byTooltip('表示言語'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('English (beta)'));
    await tester.pumpAndSettle();
    expect(app.uiLanguage, 'en');
    expect(saved['ui_language'], 'en');
    expect(find.text('English (beta)'), findsOneWidget);
    expect(find.text('Language and translation'), findsOneWidget);
    await tester.tap(find.byTooltip('Interface language'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('简体中文'));
    await tester.pumpAndSettle();
    expect(app.uiLanguage, 'zh-CN');
    expect(saved['ui_language'], 'zh-CN');
    expect(find.text('简体中文'), findsOneWidget);
    expect(find.text('语言与翻译'), findsOneWidget);
    await tester.tap(find.byTooltip('界面语言'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('English (beta)'));
    await tester.pumpAndSettle();
    expect(app.uiLanguage, 'en');
    expect(find.text('Language and translation'), findsOneWidget);
    await tester.tap(find.byTooltip('Interface language'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('繁體中文'));
    await tester.pumpAndSettle();
    expect(app.uiLanguage, 'zh-TW');
    expect(saved['ui_language'], 'zh-TW');
    expect(find.text('繁體中文'), findsOneWidget);
    expect(find.text('語言與翻譯'), findsOneWidget);
    await tester.tap(find.byTooltip('介面語言'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('English (beta)'));
    await tester.pumpAndSettle();
    tester.binding.platformDispatcher.localesTestValue = const [
      Locale('zh', 'CN'),
    ];
    addTearDown(tester.binding.platformDispatcher.clearLocalesTestValue);
    await tester.tap(find.byTooltip('Interface language'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Follow system'));
    await tester.pumpAndSettle();
    expect(app.uiLanguage, 'system');
    expect(saved['ui_language'], 'system');
    expect(AppLanguage.localeOverride, isNull);
    expect(find.text('跟随系统'), findsOneWidget);
    expect(find.text('语言与翻译'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  test(
    'traditional system locales resolve through Flutter script and region matching',
    () {
      for (final locale in const [
        Locale('zh', 'TW'),
        Locale('zh', 'HK'),
        Locale('zh', 'MO'),
        Locale.fromSubtags(languageCode: 'zh', scriptCode: 'Hant'),
        Locale.fromSubtags(
          languageCode: 'zh',
          scriptCode: 'Hant',
          countryCode: 'TW',
        ),
        Locale.fromSubtags(
          languageCode: 'zh',
          scriptCode: 'Hant',
          countryCode: 'HK',
        ),
        Locale.fromSubtags(
          languageCode: 'zh',
          scriptCode: 'Hant',
          countryCode: 'CN',
        ),
      ]) {
        final resolved = AppLanguage.resolveLocale([locale]);
        expect(resolved.scriptCode, 'Hant');
        expect(lookupAppLocalizations(resolved).settings, '設定');
      }
      for (final locale in const [
        Locale('zh', 'CN'),
        Locale('zh', 'SG'),
        Locale.fromSubtags(languageCode: 'zh', scriptCode: 'Hans'),
        Locale.fromSubtags(
          languageCode: 'zh',
          scriptCode: 'Hans',
          countryCode: 'TW',
        ),
        Locale.fromSubtags(
          languageCode: 'zh',
          scriptCode: 'Hans',
          countryCode: 'HK',
        ),
      ]) {
        expect(
          lookupAppLocalizations(AppLanguage.resolveLocale([locale])).settings,
          '设置',
        );
      }
    },
  );

  testWidgets('Japanese system locale renders and fits a phone viewport', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    tester.binding.platformDispatcher.localesTestValue = const [
      Locale('ja', 'JP'),
    ];
    addTearDown(tester.binding.platformDispatcher.clearLocalesTestValue);
    final app = AppState(languageSettingsWriter: (_, _) {});
    addTearDown(app.dispose);
    app.setTranslationTarget('ui');
    await showSettings(tester, app);
    expect(find.text('言語と翻訳'), findsOneWidget);
    expect(find.text('システムに従う'), findsOneWidget);
    expect(
      AppLanguage.resolveLocale(const [Locale('ja', 'JP')]),
      const Locale('ja'),
    );
    expect(
      Localizations.localeOf(tester.element(find.text('言語と翻訳'))),
      const Locale('ja'),
    );
    await tester.tap(find.byTooltip('表示言語'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('日本語 (beta)'));
    await tester.pumpAndSettle();
    expect(app.uiLanguage, 'ja');
    expect(app.resolvedTranslationTarget, 'ja');
    expect(find.text('日本語 (beta)'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('English language settings fit a phone viewport', (tester) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final app = AppState(languageSettingsWriter: (_, _) {});
    addTearDown(app.dispose);
    app.setUiLanguage('en');
    await showSettings(tester, app);
    await tester.tap(find.byTooltip('Interface language'));
    await tester.pumpAndSettle();
    expect(find.text('English (beta)'), findsNWidgets(2));
    expect(tester.takeException(), isNull);
  });

  testWidgets('traditional Chinese language settings fit a phone viewport', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final app = AppState(languageSettingsWriter: (_, _) {});
    addTearDown(app.dispose);
    app.setUiLanguage('zh-TW');
    await showSettings(tester, app);
    expect(find.text('語言與翻譯'), findsOneWidget);
    await tester.tap(find.byTooltip('介面語言'));
    await tester.pumpAndSettle();
    expect(find.text('繁體中文'), findsNWidgets(2));
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'follow system renders traditional regions and updates with the system locale',
    (tester) async {
      tester.binding.platformDispatcher.localesTestValue = const [
        Locale('zh', 'HK'),
      ];
      addTearDown(tester.binding.platformDispatcher.clearLocalesTestValue);
      final app = AppState(languageSettingsWriter: (_, _) {});
      addTearDown(app.dispose);
      app.setTranslationTarget('ui');
      await showSettings(tester, app);
      expect(find.text('語言與翻譯'), findsOneWidget);
      expect(find.text('跟隨系統'), findsOneWidget);
      expect(
        Localizations.localeOf(tester.element(find.text('語言與翻譯'))).scriptCode,
        'Hant',
      );
      tester.binding.platformDispatcher.localesTestValue = const [
        Locale('zh', 'CN'),
      ];
      await tester.pumpAndSettle();
      expect(find.text('语言与翻译'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'translation menu offers follow UI and retains explicit targets',
    (tester) async {
      final saved = <String, String>{};
      final app = AppState(
        languageSettingsWriter: (key, value) => saved[key] = value,
      );
      addTearDown(app.dispose);
      app.setUiLanguage('zh-CN');
      await showSettings(tester, app);
      await tester.tap(find.byTooltip('翻译目标语言'));
      await tester.pumpAndSettle();
      for (final code in ['ui', 'zh-CN', 'zh-TW', 'en']) {
        expect(
          tester
              .widget<PopupMenuItem<String>>(
                find.byWidgetPredicate(
                  (widget) =>
                      widget is PopupMenuItem<String> && widget.value == code,
                ),
              )
              .enabled,
          isTrue,
        );
      }
      await tester.tap(find.text('跟随界面语言'));
      await tester.pumpAndSettle();
      expect(app.translationTarget, 'ui');
      expect(app.resolvedTranslationTarget, 'zh-CN');
      expect(saved['translation_target'], 'ui');
      expect(find.textContaining('自动 → 跟随界面语言'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'source language defaults to auto and offers Japanese, Chinese, English',
    (tester) async {
      tester.view.physicalSize = const Size(360, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final saved = <String, String>{};
      final app = AppState(
        languageSettingsWriter: (key, value) => saved[key] = value,
      );
      addTearDown(app.dispose);
      app.setUiLanguage('zh-CN');
      expect(app.translationSource, 'auto');
      await showSettings(tester, app);
      for (final entry in const {
        'ja': '日',
        'zh': '中',
        'en': '英',
        'auto': '自动',
      }.entries) {
        await tester.tap(find.byTooltip('翻译源语言'));
        await tester.pumpAndSettle();
        final options = tester
            .widgetList<PopupMenuItem<String>>(
              find.byType(PopupMenuItem<String>),
            )
            .where((item) => item.value != null);
        expect(options.map((item) => item.value), ['auto', 'ja', 'zh', 'en']);
        await tester.tap(
          find.byWidgetPredicate(
            (widget) =>
                widget is PopupMenuItem<String> && widget.value == entry.key,
          ),
        );
        await tester.pumpAndSettle();
        expect(app.translationSource, entry.key);
        expect(saved['translation_source'], entry.key);
        expect(find.text('${entry.value} → 简中'), findsOneWidget);
        expect(tester.takeException(), isNull);
      }
      app.setTranslationSource('invalid');
      expect(app.translationSource, 'auto');
    },
  );
}
