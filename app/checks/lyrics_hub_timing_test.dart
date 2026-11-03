// ignore_for_file: invalid_use_of_visible_for_testing_member

import 'package:flutter_test/flutter_test.dart';
import 'package:kikoeta_app/data.dart';
import 'package:kikoeta_app/services/desktop_lyrics_timing.dart';
import 'package:kikoeta_app/services/lyrics_hub.dart';

void main() {
  Future<LyricsHub> hubFor(
    List<LyricLine> lyrics, {
    required Duration Function() position,
    Duration Function()? duration,
    void Function(String, DesktopLyricsTiming?)? overlayUpdate,
  }) async {
    final app = AppState()
      ..currentWork = const Work(
        rj: 'RJ1',
        title: 'Work',
        circle: '',
        va: '',
        age: Age.all,
        dur: '',
        tags: [],
        grad: 0,
      )
      ..queue = const [
        MediaNode(title: 'track', type: 'audio', path: 'track.mp3'),
      ];
    final hub = LyricsHub.forTesting(
      libraryMatcher: (_) async => [],
      libraryLoader: (_) async => [],
      onlineLoader: (_, _) async => lyrics,
      position: position,
      duration: duration,
      playing: () => true,
      rate: () => 1,
      overlayUpdate: overlayUpdate,
    );
    addTearDown(() {
      hub.dispose();
      app.dispose();
    });
    hub.bind(app);
    await Future<void>.delayed(Duration.zero);
    return hub;
  }

  test(
    'cue duration uses next timestamp and the final cue uses track duration',
    () async {
      var position = const Duration(seconds: 4);
      final hub = await hubFor(
        const [LyricLine(2, 'first', ''), LyricLine(12, 'second', '')],
        position: () => position,
        duration: () => const Duration(seconds: 30),
      );
      expect(hub.currentOverlayCue.text, 'first');
      expect(
        hub.currentOverlayCue.timing!.duration,
        const Duration(seconds: 10),
      );
      expect(hub.currentOverlayCue.timing!.position, position);
      position = const Duration(seconds: 20);
      expect(hub.currentOverlayCue.text, 'second');
      expect(
        hub.currentOverlayCue.timing!.duration,
        const Duration(seconds: 18),
      );
      position = const Duration(seconds: 1);
      expect(hub.currentOverlayCue.text, 'first');
      expect(
        hub.currentOverlayCue.timing!.elapsedAt(Duration.zero),
        Duration.zero,
      );
    },
  );

  test('identical consecutive text still receives new cue timing', () async {
    var position = const Duration(seconds: 2);
    final sent = <DesktopLyricsTiming?>[];
    final hub = await hubFor(
      const [
        LyricLine(0, 'same', ''),
        LyricLine(10, 'same', ''),
        LyricLine(20, 'end', ''),
      ],
      position: () => position,
      overlayUpdate: (_, timing) => sent.add(timing),
    );
    expect(sent.last!.start, Duration.zero);
    position = const Duration(seconds: 12);
    hub.refreshOverlay();
    expect(sent.last!.start, const Duration(seconds: 10));
    expect(sent.last!.duration, const Duration(seconds: 10));
  });

  test(
    'duplicate timestamps use the next later time; unknown last end is null',
    () async {
      var position = Duration.zero;
      final hub = await hubFor(const [
        LyricLine(0, 'a', ''),
        LyricLine(0, 'b', ''),
        LyricLine(5, 'last', ''),
      ], position: () => position);
      expect(hub.currentOverlayCue.text, 'b');
      expect(
        hub.currentOverlayCue.timing!.duration,
        const Duration(seconds: 5),
      );
      position = const Duration(seconds: 6);
      expect(hub.currentOverlayCue.timing!.end, isNull);
    },
  );
}
