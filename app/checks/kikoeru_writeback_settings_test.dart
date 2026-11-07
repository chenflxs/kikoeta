import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kikoeta_app/data.dart';
import 'package:kikoeta_app/l10n/generated/app_localizations.dart';
import 'package:kikoeta_app/src/rust/frb_generated.dart';
import 'package:kikoeta_app/widgets/kikoeru_writeback_settings.dart';

class _RealHttp extends HttpOverrides {}

class _SiteApi extends RustLibApi {
  @override
  String? crateApiSimpleGetSetting({required String key}) => null;
  @override
  String? crateApiSimpleGetToken({required String base}) => 'test-token';
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  setUpAll(() => RustLib.initMock(api: _SiteApi()));
  for (final mode in ['none', 'account', 'account_and_key', 'disabled']) {
    testWidgets(
      'shows a key only when $mode requires it, without writing files',
      (tester) async {
        await HttpOverrides.runWithHttpOverrides(() async {
          final server = await tester.runAsync(
            () => HttpServer.bind(InternetAddress.loopbackIPv4, 0),
          );
          final requests = <String>[];
          final checked = Completer<void>();
          server!.listen((request) async {
            requests.add(request.method);
            if (request.method == 'GET') {
              request.response.headers.contentType = ContentType.json;
              request.response.write(
                jsonEncode({
                  'version': 3,
                  'enabled': mode != 'disabled',
                  'authentication': mode == 'disabled'
                      ? 'account_and_key'
                      : mode,
                }),
              );
            } else if (mode == 'account_and_key') {
              request.response.statusCode = 403;
              request.response.headers.set(
                'X-Kikoeru-Writeback-Error',
                'key_invalid',
              );
            } else {
              request.response.statusCode = 204;
              request.response.headers.set('X-Kikoeru-Lyrics-Writeback', '2');
            }
            await request.response.close();
            if ((request.method == 'HEAD' || mode == 'disabled') &&
                !checked.isCompleted) {
              checked.complete();
            }
          });
          final app = AppState(languageSettingsWriter: (_, _) {});
          final url = TextEditingController(
            text: 'http://127.0.0.1:${server.port}',
          );
          final user = TextEditingController(
            text: mode == 'disabled' ? 'user1' : '',
          );
          final password = TextEditingController(
            text: mode == 'disabled' ? 'pass1' : '',
          );
          final key = TextEditingController();
          addTearDown(() async {
            await server.close(force: true);
            app.dispose();
            for (final controller in [url, user, password, key]) {
              controller.dispose();
            }
          });
          await tester.pumpWidget(
            MaterialApp(
              locale: const Locale('zh', 'CN'),
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              home: Scaffold(
                body: KikoeruWritebackSettings(
                  app: app,
                  url: url,
                  user: user,
                  password: password,
                  writebackKey: key,
                  keyField: (_) => TextField(
                    key: const ValueKey('writeback-key'),
                    controller: key,
                  ),
                ),
              ),
            ),
          );
          for (
            var attempt = 0;
            attempt < 100 && !checked.isCompleted;
            attempt++
          ) {
            await tester.runAsync(
              () => Future<void>.delayed(const Duration(milliseconds: 20)),
            );
            await tester.pump();
          }
          expect(
            checked.isCompleted,
            isTrue,
            reason: 'Observed requests: $requests',
          );
          await tester.pumpAndSettle();
          expect(
            find.byKey(const ValueKey('writeback-key')),
            mode == 'account_and_key' ? findsOneWidget : findsNothing,
          );
          expect(
            find.text(
              mode == 'disabled'
                  ? '服务端未开启写回'
                  : mode == 'account_and_key'
                  ? '请填写写回密钥'
                  : '已允许写回',
            ),
            findsOneWidget,
          );
          expect(requests, mode == 'disabled' ? ['GET'] : ['GET', 'HEAD']);
          if (mode == 'disabled') {
            await tester.tap(find.text('检查写回权限'));
            for (
              var attempt = 0;
              attempt < 100 &&
                  (requests.length < 2 ||
                      find.text('正在检查写回权限…').evaluate().isNotEmpty);
              attempt++
            ) {
              await tester.runAsync(
                () => Future<void>.delayed(const Duration(milliseconds: 20)),
              );
              await tester.pump();
            }
            await tester.pumpAndSettle();
            expect(find.text('服务端未开启写回'), findsOneWidget);
            expect(requests, ['GET', 'GET']);
          }
          url.text = 'http://127.0.0.1:1/another';
          await tester.pumpAndSettle();
          expect(find.byKey(const ValueKey('writeback-key')), findsNothing);
          expect(find.text('尚未检查写回权限'), findsOneWidget);
          await tester.pumpWidget(const SizedBox());
          expect(tester.takeException(), isNull);
        }, _RealHttp());
      },
    );
  }
}
