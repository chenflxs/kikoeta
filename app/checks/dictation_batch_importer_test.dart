import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kikoeta_app/data.dart';
import 'package:kikoeta_app/l10n/generated/app_localizations.dart';
import 'package:kikoeta_app/pages/favorites_page.dart';
import 'package:kikoeta_app/services/api_service.dart';
import 'package:kikoeta_app/services/dictation_batch_importer.dart';
import 'package:kikoeta_app/src/rust/frb_generated.dart';
import 'package:kikoeta_app/widgets/dictation_batch_import_dialog.dart';

Work work(int id) => Work(
  rj: 'RJ$id',
  title: 'Work $id',
  circle: '',
  va: '',
  age: Age.all,
  dur: '',
  tags: const [],
  grad: 0,
  apiId: id,
);

MediaNode file(String path) => MediaNode(
  title: path.split('/').last,
  type: 'file',
  path: path,
  url: 'https://library.test/$path',
);

WorksPage page(List<Work> works, {bool hasMore = false}) => WorksPage(
  works: works,
  page: 1,
  pageSize: 20,
  totalCount: 4,
  hasMore: hasMore,
);

void main() {
  setUpAll(() => RustLib.initMock(api: _Api()));

  testWidgets(
    'batch button is left of playlists and restricted to custom sites',
    (tester) async {
      final strings = lookupAppLocalizations(const Locale('en'));
      for (final custom in [false, true]) {
        final app = AppState(languageSettingsWriter: (_, _) {});
        addTearDown(app.dispose);
        app.customServer = custom;
        app.customSites.add(
          CustomSite(alias: 'Local', url: 'https://library.test'),
        );
        await tester.pumpWidget(
          MaterialApp(
            locale: const Locale('en'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(
              body: FavoritesPage(key: ValueKey(custom), app: app),
            ),
          ),
        );
        await tester.pumpAndSettle();
        final batch = find.byTooltip(strings.batchTranslation);
        if (custom) {
          expect(batch, findsOneWidget);
          expect(
            tester.getCenter(batch).dx,
            lessThan(
              tester
                  .getCenter(find.byTooltip(strings.favoritesPageBuildTooltip))
                  .dx,
            ),
          );
        } else {
          expect(batch, findsNothing);
        }
        expect(tester.takeException(), isNull);
      }
    },
  );
  test(
    'all pages are imported in order, deduplicating overlapping works',
    () async {
      final requested = <int>[];
      final result = await DictationBatchImporter(
        fetchPage: (number) async {
          requested.add(number);
          return number == 1
              ? page([work(1), work(2)], hasMore: true)
              : page([work(2), work(3), work(4)]);
        },
        fetchTracks: (_) async => [file('01.mp3')],
        fetchLocalLyrics: (_) async => [],
      ).prepare(shouldCancel: () => false, onProgress: (_, _, _) {});
      expect(requested, [1, 2]);
      expect(result!.batches.map((b) => b.work.rj), [
        'RJ1',
        'RJ2',
        'RJ3',
        'RJ4',
      ]);
    },
  );

  test(
    'retains existing lyrics until an explicit skip or retranslate choice',
    () async {
      final result = await DictationBatchImporter(
        fetchPage: (_) async => page([work(1)]),
        fetchTracks: (_) async => [
          file('01.mp3'),
          file('02.mp3'),
          file('03.mp3'),
          file('04.mp3'),
          file('05.mp3'),
          file('06.mp3'),
          file('01.lrc'),
          file('02.srt'),
          file('03.ass'),
          file('06.txt'),
        ],
        fetchLocalLyrics: (_) async => [file('RJ1/04.zh-CN.lrc')],
      ).prepare(shouldCancel: () => false, onProgress: (_, _, _) {});
      expect(result!.skippedTracks, 0);
      expect(result.existingTracks, 4);
      expect(result.batches.single.tracks.length, 6);
      final skipped = result.resolveExistingLyrics(retranslate: false);
      expect(skipped.skippedTracks, 4);
      expect(skipped.batches.single.tracks.map((t) => t.title), [
        '05.mp3',
        '06.mp3',
      ]);
      final retranslated = result.resolveExistingLyrics(retranslate: true);
      expect(retranslated.skippedTracks, 0);
      expect(retranslated.batches.single.tracks.length, 6);
    },
  );

  test('a failed work is reported and remaining works are imported', () async {
    final result = await DictationBatchImporter(
      fetchPage: (_) async => page([work(1), work(2)]),
      fetchTracks: (w) async {
        if (w.apiId == 1) throw StateError('unavailable');
        return [file('01.mp3')];
      },
      fetchLocalLyrics: (_) async => [],
    ).prepare(shouldCancel: () => false, onProgress: (_, _, _) {});
    expect(result!.failedWorks, ['RJ1']);
    expect(result.batches.single.work.rj, 'RJ2');
  });

  test(
    'cancel during an in-flight request discards all prepared batches',
    () async {
      final pending = Completer<List<MediaNode>>();
      var cancelled = false;
      var localScans = 0;
      final future =
          DictationBatchImporter(
            fetchPage: (_) async => page([work(1), work(2)]),
            fetchTracks: (w) =>
                w.apiId == 1 ? Future.value([file('01.mp3')]) : pending.future,
            fetchLocalLyrics: (_) async {
              localScans++;
              return [];
            },
          ).prepare(
            shouldCancel: () => cancelled,
            onProgress: (_, _, id) {
              if (id == 'RJ2') cancelled = true;
            },
          );
      pending.complete([file('01.mp3')]);
      expect(await future, isNull);
      expect(localScans, 1);
    },
  );

  test(
    'page errors and a backend ignoring pagination cannot truncate silently',
    () async {
      for (final repeatPage in [false, true]) {
        final importer = DictationBatchImporter(
          fetchPage: (number) async {
            if (number > 1 && !repeatPage) throw StateError('offline');
            return page([work(1)], hasMore: true);
          },
          fetchTracks: (_) async => [file('01.mp3')],
          fetchLocalLyrics: (_) async => [],
        );
        await expectLater(
          importer.prepare(shouldCancel: () => false, onProgress: (_, _, _) {}),
          throwsStateError,
        );
      }
    },
  );

  testWidgets('closing preparation cannot later pop the underlying page', (
    tester,
  ) async {
    final pending = Completer<List<MediaNode>>();
    var requested = 0;
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              child: const Text('Open'),
              onPressed: () => showDictationBatchImportDialog(
                context,
                sourceChanged: () => false,
                importer: DictationBatchImporter(
                  fetchPage: (_) async => page([work(1), work(2)]),
                  fetchTracks: (_) {
                    requested++;
                    return pending.future;
                  },
                  fetchLocalLyrics: (_) async => [],
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(requested, 1);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    pending.complete([file('01.mp3')]);
    await tester.pumpAndSettle();
    expect(requested, 1);
    expect(find.text('Open'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  for (final choice in ['Cancel', 'Skip existing lyrics', 'Translate again']) {
    testWidgets('existing lyrics wait for the user choice: $choice', (
      tester,
    ) async {
      DictationBatchImportResult? returned;
      var completed = false;
      var sourceChanged = false;
      var scans = 0;
      await tester.pumpWidget(
        MaterialApp(
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                child: const Text('Open'),
                onPressed: () async {
                  returned = await showDictationBatchImportDialog(
                    context,
                    sourceChanged: () => sourceChanged,
                    importer: DictationBatchImporter(
                      fetchPage: (_) async => page([work(1), work(2)]),
                      fetchTracks: (_) async {
                        scans++;
                        return [file('01.mp3'), file('01.lrc')];
                      },
                      fetchLocalLyrics: (_) async => [],
                    ),
                  );
                  completed = true;
                },
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
      expect(scans, 2);
      expect(completed, isFalse);
      expect(
        find.text(
          '2 tracks already have lyrics. How would you like to proceed?',
        ),
        findsOneWidget,
      );
      await tester.tap(find.text(choice));
      await tester.pumpAndSettle();
      expect(completed, isTrue);
      if (choice == 'Cancel') {
        expect(returned, isNull);
      } else if (choice == 'Skip existing lyrics') {
        expect(returned!.batches, isEmpty);
        expect(returned!.skippedTracks, 2);
      } else {
        expect(returned!.batches.length, 2);
        expect(returned!.skippedTracks, 0);
      }
      expect(scans, 2);

      // A source change while the decision is open invalidates preparation.
      completed = false;
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
      sourceChanged = true;
      await tester.tap(find.text('Translate again'));
      await tester.pumpAndSettle();
      expect(completed, isTrue);
      expect(returned, isNull);
      expect(tester.takeException(), isNull);
    });
  }
}

class _Api extends RustLibApi {
  @override
  Future<String> crateApiKikoeruApiApiGetMyReviews({
    required String base,
    required int page,
    required int perPage,
    required String order,
    required String sort,
    String? filter,
  }) async => '{"works":[],"totalCount":0}';

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
