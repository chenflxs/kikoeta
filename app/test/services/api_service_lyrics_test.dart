import 'package:flutter_test/flutter_test.dart';
import 'package:kikoeta_app/services/api_service.dart';

void main() {
  group('ApiService.parseMediaNodes', () {
    test(
      'resolves kikoeru-express mediaStreamUrl against the selected site',
      () {
        final nodes = ApiService.parseMediaNodes([
          {
            'type': 'folder',
            'title': 'Main',
            'children': [
              {
                'type': 'audio',
                'title': '01.ogg',
                'hash': '42/0',
                'mediaStreamUrl': '/api/media/stream/42/0',
                'duration': 65.8,
              },
              {
                'type': 'text',
                'title': '01.lrc',
                'hash': '42/1',
                'mediaStreamUrl': '/api/media/stream/42/1',
              },
            ],
          },
        ], base: 'https://listen.example.test/');

        expect(nodes.single.isDir, isTrue);
        final audio = nodes.single.children.singleWhere(
          (n) => n.type == 'audio',
        );
        final lyric = nodes.single.children.singleWhere(
          (n) => n.type == 'text',
        );
        expect(audio.url, 'https://listen.example.test/api/media/stream/42/0');
        expect(audio.duration, 65);
        expect(lyric.url, 'https://listen.example.test/api/media/stream/42/1');
      },
    );

    test('keeps absolute asmr.one URLs unchanged', () {
      final nodes = ApiService.parseMediaNodes([
        {
          'type': 'audio',
          'title': 'track.mp3',
          'mediaUrl': 'https://cdn.asmr.one/media/track.mp3',
        },
      ], base: 'https://api.asmr.one');

      expect(nodes.single.url, 'https://cdn.asmr.one/media/track.mp3');
    });
  });

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

  group('ApiService.lyricMatchKey', () {
    test(
      'matches common Chinese subtitle language suffixes to the track name',
      () {
        expect(ApiService.lyricMatchKey('Track 01.mp3'), 'track 01');
        expect(ApiService.lyricMatchKey('Track 01.zh.srt'), 'track 01');
        expect(ApiService.lyricMatchKey('Track 01-zh.srt'), 'track 01');
        expect(ApiService.lyricMatchKey('Track 01_zh-CN.vtt'), 'track 01');
        expect(ApiService.lyricMatchKey('Track 01.简中.ass'), 'track 01');
        expect(ApiService.lyricMatchKey('Track 01.mp3.vtt'), 'track 01');
        expect(ApiService.lyricMatchKey('Track 01.mp3.zh.vtt'), 'track 01');
      },
    );

    test('keeps ordinary words in a filename unchanged', () {
      expect(ApiService.lyricMatchKey('Chinese Track.mp3'), 'chinese track');
      expect(ApiService.lyricMatchKey('special-en.lrc'), 'special-en');
    });
  });

  group('ApiService.lyricFormatPriority', () {
    test('orders timed lyric formats before plain text', () {
      expect(ApiService.lyricFormatPriority('track.lrc'), 5);
      expect(ApiService.lyricFormatPriority('track.srt'), 4);
      expect(ApiService.lyricFormatPriority('track.vtt'), 3);
      expect(ApiService.lyricFormatPriority('track.ass'), 2);
      expect(ApiService.lyricFormatPriority('track.ssa'), 2);
      expect(ApiService.lyricFormatPriority('track.txt'), 1);
    });
  });

  group('ApiService.lyricTrackOrdinal', () {
    test('matches numbered media and subtitle filenames with extra labels', () {
      expect(ApiService.lyricTrackOrdinal('01. track.mp3'), '1');
      expect(ApiService.lyricTrackOrdinal('[CHS] 01.vtt'), '1');
      expect(ApiService.lyricTrackOrdinal('(字幕) 01 - track.vtt'), '1');
      expect(ApiService.lyricTrackOrdinal('track.vtt'), isNull);
    });
  });
}
