// ignore_for_file: invalid_use_of_visible_for_testing_member

import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:kikoeta_app/services/player_service.dart';
import 'package:media_kit/media_kit.dart';

class _Backend extends PlatformPlayer {
  _Backend() : super(configuration: const PlayerConfiguration());

  final openedSources = <String>[];
  final playedSources = <String>[];
  final openStarted = StreamController<String>.broadcast();
  final gates = <String, Completer<void>>{};
  String? source;
  bool failStop = false;

  void emitCompletion(bool completed) => completedController.add(completed);

  @override
  Future<void> open(Playable playable, {bool play = true}) async {
    final uri = (playable as Media).uri;
    openedSources.add(uri);
    openStarted.add(uri);
    await gates[uri]?.future;
    source = uri;
    if (play) playedSources.add(uri);
  }

  @override
  Future<void> stop() async {
    if (failStop) throw StateError('stop failed');
    source = null;
  }

  @override
  Future<void> play() async {
    if (source != null) playedSources.add(source!);
  }

  @override
  Future<void> pause() async {}

  @override
  Future<void> dispose() async {
    await openStarted.close();
    await super.dispose();
  }
}

void main() {
  late _Backend backend;
  late AppPlayer player;

  setUp(() {
    backend = _Backend();
    player = AppPlayer.forTesting(
      player: Player(platformPlayer: backend),
      resolveMedia: (url) async => Media(url),
    );
  });
  tearDown(() => player.dispose());

  test(
    'normal work switch stops playing audio before preparing the next',
    () async {
      player.dispose();
      backend = _Backend();
      const old = 'https://example.com/old.mp3';
      const latest = 'https://example.com/latest.mp3';
      final preparingNext = Completer<void>();
      final nextMedia = Completer<Media>();
      player = AppPlayer.forTesting(
        player: Player(platformPlayer: backend),
        resolveMedia: (url) async {
          if (url == latest) {
            expect(backend.source, isNull);
            preparingNext.complete();
            return nextMedia.future;
          }
          return Media(url);
        },
      );
      await player.openMediaUrl(old);
      expect(backend.source, old);
      expect(backend.playedSources, [old]);

      final switching = player.openMediaUrl(latest);
      await preparingNext.future;
      expect(backend.source, isNull);
      expect(player.opened, isFalse);
      expect(backend.playedSources, [old]);
      nextMedia.complete(Media(latest));
      await switching;
      expect(backend.source, latest);
      expect(backend.playedSources, [old, latest]);
      expect(player.openedUrl, latest);
    },
  );

  test('replacement waits until the old output is actually released', () async {
    player.dispose();
    backend = _Backend();
    var released = true;
    final waiting = Completer<void>();
    player = AppPlayer.forTesting(
      player: Player(platformPlayer: backend),
      resolveMedia: (url) async => Media(url),
      audioOutputReleased: () async {
        if (!released && !waiting.isCompleted) waiting.complete();
        return released;
      },
    );
    await player.openMediaUrl('https://example.com/old.mp3');
    released = false;
    final replacement = player.openMediaUrl('https://example.com/new.mp3');
    await waiting.future;
    expect(backend.openedSources, ['https://example.com/old.mp3']);
    expect(backend.playedSources, ['https://example.com/old.mp3']);
    released = true;
    await replacement;
    expect(backend.source, 'https://example.com/new.mp3');
    expect(player.openedUrl, 'https://example.com/new.mp3');
  });

  test(
    'an output that cannot close never starts another audio source',
    () async {
      player.dispose();
      backend = _Backend();
      var released = false;
      player = AppPlayer.forTesting(
        player: Player(platformPlayer: backend),
        resolveMedia: (url) async => Media(url),
        audioOutputReleased: () async => released,
        stopTimeout: const Duration(milliseconds: 20),
      );
      await expectLater(player.openLocalPath('new.mp3'), throwsStateError);
      expect(backend.openedSources, isEmpty);
      expect(backend.playedSources, isEmpty);
      expect(player.opened, isFalse);
      released = true;
      await player.openLocalPath('latest.mp3');
      expect(player.openedUrl, 'latest.mp3');
    },
  );

  test(
    'a switch while waiting for release only opens the latest work',
    () async {
      player.dispose();
      backend = _Backend();
      var released = false;
      final waiting = Completer<void>();
      player = AppPlayer.forTesting(
        player: Player(platformPlayer: backend),
        resolveMedia: (url) async => Media(url),
        audioOutputReleased: () async {
          if (!waiting.isCompleted) waiting.complete();
          return released;
        },
      );
      final old = player.openLocalPath('superseded.mp3');
      await waiting.future;
      final latest = player.openLocalPath('latest.mp3');
      released = true;
      await Future.wait([old, latest]);
      expect(backend.openedSources, [Media('latest.mp3').uri]);
    },
  );

  test(
    'late completion while old output closes cannot advance the new queue',
    () async {
      player.dispose();
      backend = _Backend();
      var released = true;
      final waiting = Completer<void>();
      player = AppPlayer.forTesting(
        player: Player(platformPlayer: backend),
        resolveMedia: (url) async => Media(url),
        audioOutputReleased: () async {
          if (!released && !waiting.isCompleted) waiting.complete();
          return released;
        },
      );
      var completions = 0;
      final subscription = player.completed.listen((_) => completions++);
      await player.openLocalPath('old.mp3');
      released = false;
      final replacement = player.openLocalPath('new.mp3');
      await waiting.future;
      // Older stop/open code only suppresses EOF for two seconds. Slow output
      // teardown must remain guarded even after that timer expires.
      await Future<void>.delayed(const Duration(milliseconds: 2100));
      backend.emitCompletion(true);
      await Future<void>.delayed(Duration.zero);
      expect(completions, 0);
      released = true;
      await replacement;
      backend.emitCompletion(false);
      await Future<void>.delayed(const Duration(milliseconds: 2100));
      backend.emitCompletion(true);
      await Future<void>.delayed(Duration.zero);
      expect(completions, 1); // The new track's genuine EOF must still advance.
      await subscription.cancel();
    },
  );

  test('switch during native open never starts the superseded work', () async {
    const old = 'https://example.com/old.mp3';
    const latest = 'https://example.com/latest.mp3';
    final gate = backend.gates[old] = Completer<void>();
    final started = backend.openStarted.stream.first;
    final oldOpen = player.openMediaUrl(old);
    await started;
    final newOpen = player.openMediaUrl(latest);
    gate.complete();
    await Future.wait([oldOpen, newOpen]);
    expect(backend.playedSources, [latest]);
    expect(backend.source, latest);
    expect(player.openedUrl, latest);
  });

  test('rapid switches discard queued intermediate works', () async {
    const old = 'https://example.com/old.mp3';
    const latest = 'https://example.com/latest.mp3';
    final gate = backend.gates[old] = Completer<void>();
    final started = backend.openStarted.stream.first;
    final oldOpen = player.openMediaUrl(old);
    await started;
    final middleOpen = player.openMediaUrl('https://example.com/middle.mp3');
    final newOpen = player.openMediaUrl(latest);
    gate.complete();
    await Future.wait([oldOpen, middleOpen, newOpen]);
    expect(backend.openedSources, [old, latest]);
    expect(backend.playedSources, [latest]);
  });

  test(
    'network preparation cannot reopen a work after a local switch',
    () async {
      player.dispose();
      backend = _Backend();
      final resolved = Completer<Media>();
      final resolving = Completer<void>();
      player = AppPlayer.forTesting(
        player: Player(platformPlayer: backend),
        resolveMedia: (_) {
          resolving.complete();
          return resolved.future;
        },
      );
      final oldOpen = player.openMediaUrl('https://example.com/old.mp3');
      await resolving.future;
      final newOpen = player.openLocalPath('latest.mp3');
      resolved.complete(Media('https://example.com/old.mp3'));
      await Future.wait([oldOpen, newOpen]);
      expect(backend.openedSources, [Media('latest.mp3').uri]);
      expect(player.openedUrl, 'latest.mp3');
    },
  );

  for (final action in ['stop', 'release', 'pause']) {
    test('$action during open prevents late autoplay', () async {
      const url = 'https://example.com/old.mp3';
      final gate = backend.gates[url] = Completer<void>();
      final started = backend.openStarted.stream.first;
      final opening = player.openMediaUrl(url);
      await started;
      final control = switch (action) {
        'stop' => player.stop(),
        'release' => player.releaseMedia(),
        _ => player.pause(),
      };
      gate.complete();
      await Future.wait([opening, control]);
      expect(backend.playedSources, isEmpty);
      expect(player.opened, action == 'pause');
      if (action != 'pause') expect(backend.source, isNull);
    });
  }

  test(
    'a timed out open stays serialized and cannot start late audio',
    () async {
      player.dispose();
      backend = _Backend();
      player = AppPlayer.forTesting(
        player: Player(platformPlayer: backend),
        resolveMedia: (url) async => Media(url),
        openTimeout: const Duration(milliseconds: 50),
      );
      const old = 'https://example.com/old.mp3';
      const latest = 'https://example.com/latest.mp3';
      final gate = backend.gates[old] = Completer<void>();
      final started = backend.openStarted.stream.first;
      final oldOpen = player.openMediaUrl(old);
      final failed = expectLater(oldOpen, throwsA(isA<TimeoutException>()));
      await started;
      await failed;
      final newOpen = player.openMediaUrl(latest);
      gate.complete();
      await newOpen;
      expect(backend.playedSources, [latest]);
      expect(player.openedUrl, latest);
    },
  );

  test('late failure of an old open cannot fail the new selection', () async {
    const old = 'https://example.com/old.mp3';
    const latest = 'https://example.com/latest.mp3';
    final gate = backend.gates[old] = Completer<void>();
    final started = backend.openStarted.stream.first;
    final oldOpen = player.openMediaUrl(old);
    await started;
    final newOpen = player.openMediaUrl(latest);
    gate.completeError(TimeoutException('old native request'));
    await Future.wait([oldOpen, newOpen]);
    expect(backend.playedSources, [latest]);
    expect(player.openedUrl, latest);
  });

  test('paused loading remains paused until explicitly resumed', () async {
    await player.openLocalPath('latest.mp3', autoplay: false);
    expect(backend.playedSources, isEmpty);
    expect(player.opened, isTrue);
    await player.play();
    expect(backend.playedSources, [Media('latest.mp3').uri]);
  });

  test(
    'stop failure aborts replacement and does not poison later opens',
    () async {
      backend.failStop = true;
      await expectLater(player.openLocalPath('old.mp3'), throwsStateError);
      expect(backend.openedSources, isEmpty);
      backend.failStop = false;
      await player.openLocalPath('latest.mp3');
      expect(player.openedUrl, 'latest.mp3');
    },
  );
}
