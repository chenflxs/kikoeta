import 'dart:convert';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';

/// Explicit portable scope. Never copy the database, tokens, credentials,
/// downloads, lyric files/indexes, caches, or a device's active playback queue.
class PortableBackup {
  static const maxBytes = 16 * 1024 * 1024;
  static const defaults = <String, String>{
    'favs': '[]',
    'blacklist': '[]',
    'playlists': '{}',
    'play_history': '[]',
    'search_history': '[]',
    'theme': 'system',
    'ui_scale_percent': '100',
    'ui_language': 'system',
    'engine': 'google',
    'translation_target': 'zh-CN',
    'volume': '100',
    'clipboard_detect': '1',
    'ls_cover': '0',
    'notif_cover': '0',
    'release_interface': '1',
    'ear_pause': '0',
    'ignore_audio_focus': '0',
    'playback_seek_backward_seconds': '10',
    'playback_seek_forward_seconds': '10',
    'playback_shortcut_toggle': '32',
    'playback_shortcut_previous': '4294968072',
    'playback_shortcut_next': '4294968071',
    'playback_shortcut_seek_backward': '4294968066',
    'playback_shortcut_seek_forward': '4294968067',
    'initial_path_behavior': 'auto',
    'media_files_only': '0',
    'se_preference': '1',
    'audio_type_preference': '["mp3","flac","wav","opus","m4a","aac"]',
    'sfw': '0',
    'desktop_lyrics': '0',
    'lyrics_library_auto': '0',
    'lyrics_font_size': '20',
    'lyrics_color': '4294967295',
    'lyrics_outline_color': '4278190080',
    'lyrics_outline_width': '1',
    'lyrics_locked_desktop': '0',
    'lyrics_locked_portrait': '0',
    'lyrics_locked_landscape': '0',
    'conv': 'orig',
    'eq_on': '1',
    'eq_gains': '[0,0,0,0,0,0,0,0,0,0]',
    'playback_speed_enabled': '0',
    'playback_rate': '1.0',
    'audio_channel_mode': 'stereo',
    'keep_tray_on_close': '1',
    'sleep_mode': 'after',
    'update_check_enabled': '1',
    'media_cache_limit_mb': '1024',
    'home_sort': 'collect',
    'home_order_asc': '0',
    'home_category': 'all',
    'home_age_filter': '',
    'home_sub_only': '0',
    'do_not_remember_playback_progress': '0',
  };

  final Map<String, String> settings;
  PortableBackup._(Map<String, String> settings)
    : settings = Map.unmodifiable(settings);

  factory PortableBackup.capture(String? Function(String) read) {
    return PortableBackup._({
      for (final entry in defaults.entries)
        entry.key: read(entry.key) ?? entry.value,
    });
  }

  String get fingerprint =>
      sha256.convert(utf8.encode(_canonical(settings))).toString();

  /// Collection identities follow AppState's existing persistence rules.
  /// Keep local ordering/preferences; retain cloud-only entries and newer history.
  Future<PortableBackup> merge(PortableBackup cloud) {
    final localValues = settings;
    final cloudValues = cloud.settings;
    return Isolate.run(() {
      _validate(localValues);
      _validate(cloudValues);
      final merged = Map<String, String>.of(localValues);
      List<dynamic> list(Map<String, String> values, String key) =>
          jsonDecode(values[key]!) as List;
      List<dynamic> unique(
        Iterable<dynamic> values,
        Object Function(dynamic) key,
      ) {
        final entries = <Object, dynamic>{};
        for (final value in values) {
          entries.putIfAbsent(key(value), () => value);
        }
        return entries.values.toList();
      }
      Object workKey(dynamic row) => (row['rj'] as String).isNotEmpty
          ? ('rj', row['rj'])
          : ('work', row['title'], row['circle']);
      String trackKey(dynamic track) {
        if (track is String) return track;
        final path = track['path'] as String;
        return path.isEmpty ? track['title'] as String : path;
      }

      for (final key in ['favs', 'search_history', 'blacklist']) {
        final values = unique(
          [...list(localValues, key), ...list(cloudValues, key)],
          (value) => key == 'blacklist'
              ? (value['type'], value['value'])
              : value as String,
        );
        merged[key] = jsonEncode(
          key == 'search_history' ? values.take(10).toList() : values,
        );
      }

      final history = <Object, dynamic>{};
      for (final row in [
        ...list(localValues, 'play_history'),
        ...list(cloudValues, 'play_history'),
      ]) {
        final key = workKey(row);
        if (!history.containsKey(key) ||
            (row['at'] as int) > (history[key]['at'] as int)) {
          history[key] = row;
        }
      }
      final sortedHistory = history.values.toList()..sort((a, b) {
        final order = (b['at'] as int).compareTo(a['at'] as int);
        return order != 0 ? order : (a['rj'] as String).compareTo(b['rj'] as String);
      });
      merged['play_history'] = jsonEncode(sortedHistory.take(50).toList());

      final localPlaylists =
          jsonDecode(localValues['playlists']!) as Map<String, dynamic>;
      final cloudPlaylists =
          jsonDecode(cloudValues['playlists']!) as Map<String, dynamic>;
      final playlists = <String, dynamic>{};
      for (final name in {...localPlaylists.keys, ...cloudPlaylists.keys}) {
        final works = <Object, Map<String, dynamic>>{};
        final rows = <dynamic>[
          ...?(localPlaylists[name] as List?),
          ...?(cloudPlaylists[name] as List?),
        ];
        for (final raw in rows) {
          final row = Map<String, dynamic>.from(raw as Map);
          final previous = works[workKey(row)];
          if (previous == null) {
            row['tracks'] = unique(row['tracks'] as List, trackKey);
            works[workKey(row)] = row;
            continue;
          }
          final tracks = <String, dynamic>{};
          for (final track in [
            ...(previous['tracks'] as List),
            ...(row['tracks'] as List),
          ]) {
            final key = trackKey(track);
            final preferred = tracks[key];
            if (preferred == null || (preferred is String && track is Map)) {
              tracks[key] = track;
            } else if (preferred is Map && track is Map) {
              tracks[key] = {
                ...track,
                ...preferred,
                if ((preferred['url'] == null || preferred['url'] == '') &&
                    track['url'] is String)
                  'url': track['url'],
                if (((preferred['duration'] as num?) ?? 0) <= 0 &&
                    track['duration'] is num)
                  'duration': track['duration'],
              };
            }
          }
          previous['tracks'] = tracks.values.toList();
        }
        playlists[name] = works.values.toList();
      }
      merged['playlists'] = jsonEncode(playlists);
      _validate(merged);
      return PortableBackup._(merged);
    });
  }

  Future<Uint8List> encode() {
    final values = settings;
    return Isolate.run(() {
      final bytes = Uint8List.fromList(
        utf8.encode(
          jsonEncode({
            'format': 'kikoeta-portable-backup',
            'version': 1,
            'createdAt': DateTime.now().toUtc().toIso8601String(),
            'sha256': sha256
                .convert(utf8.encode(_canonical(values)))
                .toString(),
            'settings': values,
          }),
        ),
      );
      if (bytes.length > maxBytes) {
        throw const FormatException('backupTooLarge');
      }
      return bytes;
    });
  }

  static Future<PortableBackup> decode(List<int> bytes) async {
    if (bytes.length > maxBytes) throw const FormatException('backupTooLarge');
    return Isolate.run(() {
      final raw = jsonDecode(utf8.decode(bytes));
      if (raw is! Map ||
          raw['format'] != 'kikoeta-portable-backup' ||
          raw['version'] != 1 ||
          raw['settings'] is! Map) {
        throw const FormatException('backupInvalid');
      }
      final settings = <String, String>{};
      for (final entry in (raw['settings'] as Map).entries) {
        if (!defaults.containsKey(entry.key) || entry.value is! String) {
          throw const FormatException('backupInvalid');
        }
        settings[entry.key as String] = entry.value as String;
      }
      if (settings.length != defaults.length ||
          raw['sha256'] !=
              sha256.convert(utf8.encode(_canonical(settings))).toString()) {
        throw const FormatException('backupInvalid');
      }
      _validate(settings);
      return PortableBackup._(settings);
    });
  }

  static String _canonical(Map<String, String> values) {
    final keys = values.keys.toList()..sort();
    return jsonEncode({for (final key in keys) key: values[key]});
  }

  static void _validate(Map<String, String> values) {
    Never invalid() => throw const FormatException('backupInvalid');
    dynamic decode(String key) => jsonDecode(values[key]!);
    bool strings(dynamic value) =>
        value is List && value.every((e) => e is String);
    for (final key in ['favs', 'search_history', 'audio_type_preference']) {
      if (!strings(decode(key))) invalid();
    }
    for (final key in ['blacklist', 'play_history']) {
      final list = decode(key);
      if (list is! List) invalid();
      for (final row in list) {
        if (row is! Map) invalid();
        final fields = key == 'blacklist'
            ? ['type', 'value']
            : ['rj', 'title', 'circle'];
        for (final field in fields) {
          if (row[field] is! String) invalid();
        }
        if (key == 'blacklist' &&
            !['rj', 'va', 'circle', 'tag'].contains(row['type'])) {
          invalid();
        }
        if (key == 'play_history' && row['at'] is! int) invalid();
        if (key == 'play_history') {
          if (row['coverUrl'] != null && row['coverUrl'] is! String) invalid();
          for (final field in ['tags', 'grayTags']) {
            if (row[field] != null && !strings(row[field])) invalid();
          }
          final names = row['tagNames'];
          if (names != null &&
              (names is! Map ||
                  !names.values.every(
                    (n) => n is Map && n.values.every((v) => v is String),
                  ))) {
            invalid();
          }
        }
      }
    }
    final playlists = decode('playlists');
    if (playlists is! Map) invalid();
    for (final rows in playlists.values) {
      if (rows is! List) invalid();
      for (final row in rows) {
        if (row is! Map || row['tracks'] is! List) invalid();
        for (final field in ['rj', 'title', 'circle']) {
          if (row[field] is! String) invalid();
        }
        for (final track in row['tracks'] as List) {
          if (track is String) continue; // legacy playlists
          if (track is! Map ||
              track['title'] is! String ||
              track['path'] is! String ||
              (track['url'] != null && track['url'] is! String) ||
              (track['duration'] != null && track['duration'] is! num)) {
            invalid();
          }
        }
      }
    }
    final gains = decode('eq_gains');
    if (gains is! List ||
        gains.length != 10 ||
        !gains.every((e) => e is num && e.isFinite && e >= -20 && e <= 20)) {
      invalid();
    }
    for (final entry in values.entries) {
      final fallback = defaults[entry.key]!;
      if (fallback == '0' || fallback == '1') {
        // Numeric controls below have a wider range than boolean switches.
        if (!['lyrics_outline_width', 'home_sub_only'].contains(entry.key) &&
            !['0', '1'].contains(entry.value)) {
          invalid();
        }
      }
    }
    const ranges = <String, (double, double)>{
      'ui_scale_percent': (25, 200),
      'volume': (0, 200),
      'lyrics_font_size': (12, 64),
      'lyrics_outline_width': (0, 4),
      'lyrics_color': (0, 4294967295),
      'lyrics_outline_color': (0, 4294967295),
      'playback_seek_backward_seconds': (5, 60),
      'playback_seek_forward_seconds': (5, 60),
      'playback_rate': (0.25, 4),
      'media_cache_limit_mb': (512, 10240),
    };
    for (final entry in ranges.entries) {
      final n = double.tryParse(values[entry.key]!);
      if (n == null ||
          !n.isFinite ||
          n < entry.value.$1 ||
          n > entry.value.$2) {
        invalid();
      }
    }
    for (final key in values.keys.where(
      (k) => k.startsWith('playback_shortcut_'),
    )) {
      if ((int.tryParse(values[key]!) ?? -1) < 0) invalid();
    }
    const choices = {
      'theme': ['system', 'light', 'dark'],
      'ui_language': ['system', 'zh-CN', 'zh-TW', 'en'],
      'translation_target': ['ui', 'zh-CN', 'zh-TW', 'en'],
      'audio_channel_mode': ['stereo', 'swap', 'mono'],
      'initial_path_behavior': ['auto', 'root'],
      'home_category': ['all', 'hot', 'rec'],
      'conv': ['orig', 'zh', 'tw'],
      'home_sub_only': ['0', '1', '2', 'all', 'online'],
    };
    for (final entry in choices.entries) {
      if (!entry.value.contains(values[entry.key])) invalid();
    }
  }
}
