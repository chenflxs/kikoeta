// Tests live in checks/ rather than the analyzer's conventional test/ path.
// ignore_for_file: invalid_use_of_visible_for_testing_member

import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:kikoeta_app/services/desktop_lyrics_marquee.dart';
import 'package:kikoeta_app/services/desktop_lyrics_overlay.dart';
import 'package:kikoeta_app/services/desktop_lyrics_timing.dart';

void main() {
  DesktopLyricsMarquee motion({
    double width = 600,
    double viewport = 300,
    Duration? duration = const Duration(seconds: 10),
    double scale = 1,
  }) => DesktopLyricsMarquee()
    ..configure(
      layoutKey: 'lyric',
      textWidth: width,
      viewportWidth: viewport,
      lineDuration: duration,
      scale: scale,
      now: Duration.zero,
    );

  test(
    'holds the opening one second then distributes overflow over cue time',
    () {
      final marquee = motion();
      expect(marquee.offsetAt(const Duration(milliseconds: 999)), 0);
      expect(marquee.offsetAt(const Duration(seconds: 1)), 0);
      expect(marquee.offsetAt(const Duration(seconds: 2)), closeTo(37.5, .001));
      expect(
        marquee.offsetAt(const Duration(seconds: 6)),
        closeTo(187.5, .001),
      );
      expect(marquee.offsetAt(const Duration(seconds: 9)), 300);
    },
  );

  test('reaching the tail never resumes movement or loops back', () {
    final marquee = motion();
    for (final ms in [9000, 9500, 10000, 12000, 25000, 1000000]) {
      expect(marquee.offsetAt(Duration(milliseconds: ms)), 300);
    }
  });

  test(
    'longer text and shorter cues increase speed by their actual overflow',
    () {
      expect(motion(width: 900).offsetAt(const Duration(seconds: 2)), 75);
      expect(
        motion(
          duration: const Duration(seconds: 6),
        ).offsetAt(const Duration(seconds: 2)),
        75,
      );
      expect(
        motion(
          width: 1200,
          viewport: 600,
          scale: 2,
        ).offsetAt(const Duration(seconds: 2)),
        75,
      );
    },
  );

  test('very short cues retain time to scroll by shortening both holds', () {
    for (final ms in [1000, 2000]) {
      final marquee = motion(duration: Duration(milliseconds: ms));
      expect(marquee.offsetAt(Duration(milliseconds: ms ~/ 4)), 0);
      expect(marquee.offsetAt(Duration(milliseconds: ms ~/ 2)), 150);
      expect(marquee.offsetAt(Duration(milliseconds: ms * 3 ~/ 4)), 300);
      expect(marquee.offsetAt(const Duration(minutes: 1)), 300);
    }
  });

  test('missing or invalid end time uses a bounded single traversal', () {
    for (final duration in [null, Duration.zero, const Duration(seconds: -1)]) {
      final marquee = motion(duration: duration);
      expect(marquee.offsetAt(const Duration(seconds: 2)), 30);
      expect(marquee.offsetAt(const Duration(seconds: 11)), 300);
      expect(marquee.offsetAt(const Duration(days: 1)), 300);
    }
  });

  test('playback elapsed time wins over wall time, including seeks', () {
    final marquee = motion();
    expect(
      marquee.offsetAt(
        const Duration(days: 1),
        lineElapsed: const Duration(seconds: 2),
      ),
      37.5,
    );
    expect(
      marquee.offsetAt(
        const Duration(days: 2),
        lineElapsed: const Duration(seconds: 2),
      ),
      37.5,
    );
    expect(
      marquee.offsetAt(
        const Duration(days: 2),
        lineElapsed: const Duration(milliseconds: 1500),
      ),
      18.75,
    );
  });

  test(
    'a late duration update uses media progress without restarting the cue',
    () {
      final marquee = motion(duration: null);
      marquee.configure(
        layoutKey: 'lyric',
        textWidth: 600,
        viewportWidth: 300,
        now: const Duration(seconds: 5),
        lineDuration: const Duration(seconds: 10),
      );
      expect(
        marquee.offsetAt(
          const Duration(seconds: 5),
          lineElapsed: const Duration(seconds: 5),
        ),
        150,
      );
    },
  );

  test('fitting and empty lyrics remain static', () {
    for (final width in [0.0, 200.0, 300.0]) {
      final marquee = motion(width: width);
      expect(marquee.isActive, isFalse);
      expect(marquee.offsetAt(const Duration(days: 1)), 0);
    }
    final marquee = motion()..reset();
    expect(marquee.isActive, isFalse);
  });

  test('media anchor freezes while paused and follows rate while playing', () {
    const paused = DesktopLyricsTiming(
      start: Duration(seconds: 2),
      end: Duration(seconds: 12),
      position: Duration(seconds: 5),
      playing: false,
    );
    expect(
      paused.elapsedAt(const Duration(seconds: 10)),
      const Duration(seconds: 3),
    );
    const playing = DesktopLyricsTiming(
      start: Duration(seconds: 2),
      end: Duration(seconds: 12),
      position: Duration(seconds: 5),
      playing: true,
      rate: 2,
    );
    expect(
      playing.elapsedAt(const Duration(milliseconds: 500)),
      const Duration(seconds: 4),
    );
    expect(
      playing.elapsedAt(const Duration(minutes: 1)),
      const Duration(seconds: 10),
    );
    const upcoming = DesktopLyricsTiming(
      start: Duration(seconds: 10),
      end: Duration(seconds: 20),
      position: Duration(seconds: 2),
      playing: true,
    );
    expect(upcoming.elapsedAt(const Duration(seconds: 1)), Duration.zero);
  });

  group('native GDI viewport', () {
    const text =
        '这是按单句时间动态滚动的桌面歌词，句尾不会继续滚走。'
        'Long lyrics keep their ending, 日本語とРусскийも表示します。';
    late DesktopLyricsOverlay overlay;
    setUp(() => overlay = DesktopLyricsOverlay.forTesting());
    tearDown(() => overlay.dispose());
    DesktopLyricsTiming timing(Duration position) => DesktopLyricsTiming(
      start: Duration.zero,
      end: const Duration(seconds: 10),
      position: position,
      playing: true,
    );

    test('long lyrics move without drawing into the toolbar', () {
      const width = 360;
      const height = 88;
      final first = overlay.renderTextForTesting(
        text: text,
        width: width,
        height: height,
        elapsed: Duration.zero,
        timing: timing(Duration.zero),
      );
      final moving = overlay.renderTextForTesting(
        text: text,
        width: width,
        height: height,
        elapsed: const Duration(seconds: 4),
        timing: timing(const Duration(seconds: 4)),
      );
      expect(first.scrolling, isTrue);
      expect(moving.offset, greaterThan(0));
      expect(moving.pixels, isNot(equals(first.pixels)));
      expect(moving.pixels.any((value) => value > 0), isTrue);
      for (var y = 0; y < height; y++) {
        for (var x = 0; x < width; x++) {
          if (y >= 38 && x >= 14 && x < width - 14) continue;
          expect(moving.pixels[((height - 1 - y) * width + x) * 4 + 3], 0);
        }
      }
    });

    test('the tail pixels remain unchanged after the cue ends', () {
      overlay.renderTextForTesting(
        text: text,
        width: 360,
        height: 88,
        elapsed: Duration.zero,
        timing: timing(Duration.zero),
      );
      final tail = overlay.renderTextForTesting(
        text: text,
        width: 360,
        height: 88,
        elapsed: const Duration(seconds: 9),
        timing: timing(const Duration(seconds: 9)),
      );
      expect(tail.offset, greaterThan(0));
      for (final seconds in [10, 12, 25, 120]) {
        final frame = overlay.renderTextForTesting(
          text: text,
          width: 360,
          height: 88,
          elapsed: Duration(seconds: seconds),
          timing: timing(Duration(seconds: seconds)),
        );
        expect(frame.offset, tail.offset);
        expect(frame.pixels, equals(tail.pixels));
      }
    });

    test('seeking back changes position; a new cue starts at its head', () {
      overlay.renderTextForTesting(
        text: text,
        width: 360,
        height: 88,
        elapsed: Duration.zero,
        timing: timing(Duration.zero),
      );
      final late = overlay.renderTextForTesting(
        text: text,
        width: 360,
        height: 88,
        elapsed: const Duration(seconds: 7),
        timing: timing(const Duration(seconds: 7)),
      );
      final sought = overlay.renderTextForTesting(
        text: text,
        width: 360,
        height: 88,
        elapsed: const Duration(seconds: 8),
        timing: timing(const Duration(seconds: 3)),
      );
      expect(sought.offset, lessThan(late.offset));
      final next = overlay.renderTextForTesting(
        text: text,
        width: 360,
        height: 88,
        elapsed: const Duration(seconds: 10),
        timing: const DesktopLyricsTiming(
          start: Duration(seconds: 10),
          end: Duration(seconds: 20),
          position: Duration(seconds: 10),
          playing: true,
        ),
      );
      expect(next.offset, 0);
    });

    test('short lyrics and a tall multiline window remain static', () {
      for (final (lyric, height) in [('Short lyric', 88), (text, 180)]) {
        final first = overlay.renderTextForTesting(
          text: lyric,
          width: 360,
          height: height,
          elapsed: Duration.zero,
          timing: timing(Duration.zero),
        );
        final later = overlay.renderTextForTesting(
          text: lyric,
          width: 360,
          height: height,
          elapsed: const Duration(seconds: 5),
          timing: timing(const Duration(seconds: 5)),
        );
        expect(first.scrolling, isFalse);
        expect(later.pixels, equals(first.pixels));
      }
    });
  }, skip: !Platform.isWindows);
}
