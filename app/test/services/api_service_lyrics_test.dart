import 'package:flutter_test/flutter_test.dart';
import 'package:kikoeta_app/services/api_service.dart';

void main() {
  group('ApiService.parseLyrics', () {
    test('keeps LRC parsing compatible and sorts timestamps', () {
      final lyrics = ApiService.parseLyrics('''
[00:10.50]second
[00:02.00]first
''');

      expect(lyrics.map((line) => line.t), [2, 10]);
      expect(lyrics.map((line) => line.jp), ['first', 'second']);
    });

    test('parses WebVTT cues and removes markup', () {
      final lyrics = ApiService.parseLyrics('''
WEBVTT

00:01.250 --> 00:03.000 align:start
<c.green>First line</c>
Second line

00:05.000 --> 00:06.000
Next
''');

      expect(lyrics.map((line) => line.t), [1, 5]);
      expect(lyrics.first.jp, 'First line\nSecond line');
    });

    test('parses SRT cues with comma millisecond separators', () {
      final lyrics = ApiService.parseLyrics('''
1
00:00:02,500 --> 00:00:04,000
Hello

2
00:01:00,000 --> 00:01:01,000
World
''');

      expect(lyrics.map((line) => line.t), [2, 60]);
      expect(lyrics.map((line) => line.jp), ['Hello', 'World']);
    });

    test('parses ASS and SSA dialogue fields and strips overrides', () {
      final lyrics = ApiService.parseLyrics('''
[Events]
Dialogue: 0,0:00:03.50,0:00:05.00,Default,Actor,0,0,0,,{\\i1}Hello\\NWorld
Dialogue: 0,0:01:02.00,0:01:03.00,Default,,0,0,0,,Again
''');

      expect(lyrics.map((line) => line.t), [3, 62]);
      expect(lyrics.first.jp, 'Hello\nWorld');
      expect(lyrics.last.jp, 'Again');
    });
  });
}
