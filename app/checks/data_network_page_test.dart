import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kikoeta_app/data.dart';
import 'package:kikoeta_app/l10n/generated/app_localizations.dart';
import 'package:kikoeta_app/pages/more_page.dart';
import 'package:kikoeta_app/pages/settings_page.dart';
import 'package:kikoeta_app/services/app_data_service.dart';
import 'package:kikoeta_app/services/cloud_sync_service.dart';
import 'package:kikoeta_app/theme.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() {
    cloudSync = CloudSyncService(
      readSetting: (_) => null,
      writeSetting: (_, _) {},
      applyBackup: (_) async {},
    );
  });
  tearDownAll(() => cloudSync.dispose());
  for (final locale in [const Locale('zh'), const Locale('en')]) {
    for (final width in [360.0, 1024.0]) {
      testWidgets('data tools and cloud settings fit $locale at width $width', (
        tester,
      ) async {
        tester.view.physicalSize = Size(width, 900);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final app = AppState();
        addTearDown(app.dispose);
        await tester.pumpWidget(
          MaterialApp(
            locale: locale,
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            theme: buildTheme(Brightness.light),
            home: Scaffold(body: MorePage(app: app)),
          ),
        );
        await tester.pumpAndSettle();
        final english = locale.languageCode == 'en';
        expect(find.text(english ? 'More' : '更多'), findsOneWidget);
        expect(find.text(english ? 'Sync now' : '立即同步'), findsNothing);
        await tester.pumpWidget(
          MaterialApp(
            locale: locale,
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            theme: buildTheme(Brightness.light),
            home: SettingsPage(app: app, sectionKey: 'other'),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.text(english ? 'Data & Network' : '数据与网络'), findsOneWidget);
        expect(find.text(english ? 'Sync now' : '立即同步'), findsOneWidget);
        expect(tester.takeException(), isNull);
        await tester.tap(
          find.text(english ? 'WebDAV cloud sync' : 'WebDAV 云同步'),
        );
        await tester.pumpAndSettle();
        expect(
          find.text(english ? 'Sync automatically every hour' : '每小时自动同步'),
          findsOneWidget,
        );
        expect(tester.takeException(), isNull);
        await tester.tap(find.text(english ? 'Save' : '保存'));
        await tester.pumpAndSettle();
        expect(find.byType(AlertDialog), findsOneWidget);
        expect(tester.takeException(), isNull);
      });
    }
  }
}
