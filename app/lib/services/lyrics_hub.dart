import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';

import '../data.dart';
import '../src/rust/api/textconv.dart';
import 'api_service.dart';
import 'android_lyrics_overlay.dart';
import 'desktop_lyrics_overlay.dart';
import 'lyrics_library_service.dart';
import 'player_service.dart';

/// A selection remains bound to the track for which its picker was opened.
class LyricsTrackSelection {
  final AppState app;
  final Work work;
  final MediaNode track;
  final String key;
  final int generation;

  const LyricsTrackSelection._({
    required this.app,
    required this.work,
    required this.track,
    required this.key,
    required this.generation,
  });
}

typedef LibraryLyricsMatcher =
    Future<List<LyricsLibraryFile>> Function(LyricsTrackSelection selection);
typedef OnlineLyricsLoader =
    Future<List<LyricLine>> Function(
      LyricsTrackSelection selection,
      LyricCandidate? pick,
    );

/// 歌词的唯一加载入口：播放器页与悬浮歌词共用当前曲目的结果。
class LyricsHub extends ChangeNotifier {
  LyricsHub._({
    LibraryLyricsMatcher? libraryMatcher,
    Future<List<LyricLine>> Function(LyricsLibraryFile)? libraryLoader,
    OnlineLyricsLoader? onlineLoader,
    ValueListenable<int>? libraryRevision,
    int Function()? position,
    void Function(String)? overlayUpdate,
  }) : _libraryMatcher = libraryMatcher ?? _matchLibrary,
       _libraryLoader = libraryLoader ?? LyricsLibraryService.instance.loadFile,
       _onlineLoader = onlineLoader ?? _loadOnline,
       _libraryRevision =
           libraryRevision ?? LyricsLibraryService.instance.revision,
       _position = position ?? (() => AppPlayer.instance.currentPosition),
       _overlayUpdate = overlayUpdate ?? _updateOverlay;

  @visibleForTesting
  factory LyricsHub.forTesting({
    required LibraryLyricsMatcher libraryMatcher,
    required Future<List<LyricLine>> Function(LyricsLibraryFile) libraryLoader,
    required OnlineLyricsLoader onlineLoader,
    ValueListenable<int>? libraryRevision,
  }) => LyricsHub._(
    libraryMatcher: libraryMatcher,
    libraryLoader: libraryLoader,
    onlineLoader: onlineLoader,
    libraryRevision: libraryRevision ?? ValueNotifier<int>(0),
    position: () => 0,
    overlayUpdate: (_) {},
  );

  static final LyricsHub instance = LyricsHub._();
  final LibraryLyricsMatcher _libraryMatcher;
  final Future<List<LyricLine>> Function(LyricsLibraryFile) _libraryLoader;
  final OnlineLyricsLoader _onlineLoader;
  final ValueListenable<int> _libraryRevision;
  final int Function() _position;
  final void Function(String) _overlayUpdate;
  final List<StreamSubscription> _subscriptions = [];
  List<LyricLine> _lyrics = const [];
  String? _sourceName;
  bool _loading = false;
  String _conv = 'orig';
  final Map<String, String> _convCache = {};
  bool _started = false;
  bool _disposed = false;
  String _lastSent = '';
  AppState? _app;
  String? _trackKey;
  String? _manualTrackKey;
  String? _pendingManualTrackKey;
  bool? _libraryAuto;
  int _trackGeneration = 0;
  int _matchSeq = 0;
  bool _libraryRefreshPending = false;

  List<LyricLine> get lyrics => _lyrics;
  String? get sourceName => _sourceName;
  bool get loading => _loading;

  void start() {
    if (_started) return;
    _started = true;
    _subscriptions.add(AppPlayer.instance.position.listen((_) => _tick()));
    _subscriptions.add(AppPlayer.instance.released.listen((_) => clear()));
  }

  /// 重进同一曲目只订阅已有结果，不会再次发起自动匹配。
  void bind(AppState app) {
    if (!identical(_app, app)) {
      _app?.removeListener(_onAppChanged);
      if (_app != null) _libraryRevision.removeListener(_onLibraryChanged);
      _app = app;
      _trackKey = null;
      _manualTrackKey = null;
      _pendingManualTrackKey = null;
      _libraryAuto = null;
      _trackGeneration++;
      _matchSeq++;
      app.addListener(_onAppChanged);
      _libraryRevision.addListener(_onLibraryChanged);
    }
    _onAppChanged();
  }

  LyricsTrackSelection? captureSelection() {
    final app = _app;
    if (app == null || app.playWork == null || app.queue.isEmpty) return null;
    final index = app.trackIdx.clamp(0, app.queue.length - 1).toInt();
    final key = _currentTrackKey(app);
    if (key == null || key != _trackKey) return null;
    return LyricsTrackSelection._(
      app: app,
      work: app.playWork!,
      track: app.queue[index],
      key: key,
      generation: _trackGeneration,
    );
  }

  bool isSelectionCurrent(LyricsTrackSelection selection) =>
      !_disposed &&
      identical(selection.app, _app) &&
      selection.key == _trackKey &&
      selection.generation == _trackGeneration &&
      selection.key == _currentTrackKey(selection.app);

  Future<bool> loadOnlineSelection(
    LyricsTrackSelection selection,
    LyricCandidate? pick,
  ) => loadManualLyrics(
    selection,
    () => _onlineLoader(selection, pick),
    sourceName: pick?.title,
  );

  /// 在发起读取前抢占自动请求；迟到结果与已切走曲目的选择都不能覆盖当前歌词。
  Future<bool> loadManualLyrics(
    LyricsTrackSelection selection,
    Future<List<LyricLine>> Function() load, {
    String? sourceName,
  }) async {
    if (!isSelectionCurrent(selection)) return false;
    final seq = ++_matchSeq;
    final previousManualKey = _manualTrackKey;
    final automaticWasLoading = _loading && previousManualKey != selection.key;
    final libraryAuto = selection.app.lyricsLibraryAuto;
    final revision = _libraryRevision.value;
    var loaded = false;
    _pendingManualTrackKey = selection.key;
    _libraryRefreshPending = false;
    _setLoading(true);
    try {
      final result = await load();
      if (!isSelectionCurrent(selection) || seq != _matchSeq) return false;
      if (result.isEmpty) return false;
      loaded = true;
      _manualTrackKey = selection.key;
      _setResult(result, sourceName: sourceName);
      return true;
    } catch (_) {
      return false;
    } finally {
      if (isSelectionCurrent(selection) && seq == _matchSeq) {
        _pendingManualTrackKey = null;
        if (!loaded) _manualTrackKey = previousManualKey;
        if (!loaded &&
            previousManualKey != selection.key &&
            (automaticWasLoading ||
                _lyrics.isEmpty ||
                libraryAuto != selection.app.lyricsLibraryAuto ||
                revision != _libraryRevision.value)) {
          unawaited(_matchCurrentTrack(selection.app, keepExisting: true));
        } else {
          _setLoading(false);
        }
      }
    }
  }

  /// 真正释放媒体时立即废弃尚未完成的请求。
  void clear() {
    _matchSeq++;
    _trackGeneration++;
    _trackKey = null;
    _manualTrackKey = null;
    _pendingManualTrackKey = null;
    _libraryRefreshPending = false;
    _loading = false;
    _setResult(const []);
  }

  void setConv(String conv) {
    if (_conv == conv) return;
    _conv = conv;
    _convCache.clear();
    refreshOverlay();
  }

  void refreshOverlay() => _tick(force: true);

  void _onAppChanged() {
    final app = _app;
    if (app == null || _disposed) return;
    setConv(app.conv);
    final key = _currentTrackKey(app);
    final trackChanged = key != _trackKey;
    final settingChanged = _libraryAuto != app.lyricsLibraryAuto;
    _libraryAuto = app.lyricsLibraryAuto;
    if (trackChanged) {
      _trackKey = key;
      _manualTrackKey = null;
      _pendingManualTrackKey = null;
      _trackGeneration++;
    }
    if (trackChanged ||
        (settingChanged &&
            (key == null ||
                (_manualTrackKey != key && _pendingManualTrackKey != key)))) {
      unawaited(_matchCurrentTrack(app));
    }
  }

  void _onLibraryChanged() {
    final app = _app;
    if (app == null ||
        !app.lyricsLibraryAuto ||
        _trackKey == null ||
        _manualTrackKey == _trackKey ||
        _pendingManualTrackKey == _trackKey) {
      return;
    }
    // 在线作品下载本身也会刷新索引；等当前请求结束后再校准，避免重入下载。
    if (_loading) {
      _libraryRefreshPending = true;
      return;
    }
    unawaited(_matchCurrentTrack(app, keepExisting: true));
  }

  String? _currentTrackKey(AppState app) {
    final work = app.playWork;
    if (work == null || app.queue.isEmpty) return null;
    final index = app.trackIdx.clamp(0, app.queue.length - 1).toInt();
    final track = app.queue[index];
    return '${work.rj}|${track.path}|${track.url ?? ''}';
  }

  Future<void> _matchCurrentTrack(
    AppState app, {
    bool keepExisting = false,
  }) async {
    final seq = ++_matchSeq;
    _libraryRefreshPending = false;
    final selection = captureSelection();
    _loading = selection != null;
    if (keepExisting && selection != null) {
      notifyListeners();
    } else {
      _setResult(const []);
    }
    if (selection == null) return;
    bool isCurrent() =>
        seq == _matchSeq &&
        isSelectionCurrent(selection) &&
        _manualTrackKey != selection.key;
    try {
      List<LyricLine> result = const [];
      String? sourceName;
      if (app.lyricsLibraryAuto) {
        try {
          final library = await _libraryMatcher(selection);
          if (!isCurrent()) return;
          final title = selection.track.title;
          var matched = library
              .where((file) => ApiService.lyricMatchScore(title, file.name) > 0)
              .toList();
          if (matched.isEmpty) {
            final ordinal = ApiService.lyricTrackOrdinal(title);
            if (ordinal != null) {
              matched = library
                  .where(
                    (file) =>
                        ApiService.lyricTrackOrdinal(file.name) == ordinal,
                  )
                  .toList();
            }
          }
          final candidates = matched.isNotEmpty
              ? matched
              : (library.length == 1 ? library : const <LyricsLibraryFile>[]);
          for (final file in candidates) {
            result = await _libraryLoader(file);
            if (!isCurrent()) return;
            if (result.isNotEmpty) {
              sourceName = file.relativePath;
              break;
            }
          }
        } catch (_) {
          // 歌词库读取失败也应继续在线回退。
        }
      }
      if (!isCurrent()) return;
      if (result.isEmpty) {
        result = await _onlineLoader(selection, null);
      }
      if (!isCurrent()) return;
      _setResult(result, sourceName: sourceName);
    } catch (_) {
      // 开始时已清空旧曲歌词，失败时保持空列表。
    } finally {
      if (isCurrent()) {
        _setLoading(false);
        if (_libraryRefreshPending) {
          unawaited(_matchCurrentTrack(app, keepExisting: true));
        }
      }
    }
  }

  void _setLoading(bool value) {
    if (_loading == value) return;
    _loading = value;
    notifyListeners();
  }

  void _setResult(List<LyricLine> lyrics, {String? sourceName}) {
    _lyrics = List.unmodifiable(lyrics);
    _sourceName = sourceName;
    _convCache.clear();
    _lastSent = '';
    _tick(force: true);
    if (!_disposed) notifyListeners();
  }

  static Future<List<LyricsLibraryFile>> _matchLibrary(
    LyricsTrackSelection selection,
  ) => LyricsLibraryService.instance.matchingFiles(
    workId: selection.work.rj,
    trackTitle: selection.track.title,
    trackPath: selection.track.path,
  );

  static Future<List<LyricLine>> _loadOnline(
    LyricsTrackSelection selection,
    LyricCandidate? pick,
  ) => ApiService.fetchLrc(
    selection.app,
    selection.work,
    trackTitle: selection.track.title,
    trackPath: selection.track.path,
    trackUrl: selection.track.url,
    pick: pick,
  );

  /// 当前应显示的歌词行（保留首句时间之前显示首句的行为）。
  String get currentLine {
    if (_lyrics.isEmpty) return '';
    final pos = _position();
    var idx = 0;
    for (var i = 0; i < _lyrics.length; i++) {
      if (pos >= _lyrics[i].t) {
        idx = i;
      } else {
        break;
      }
    }
    return _display(_lyrics[idx]);
  }

  void _tick({bool force = false}) {
    final line = currentLine;
    if (!force && line == _lastSent) return;
    _lastSent = line;
    _overlayUpdate(line);
  }

  static void _updateOverlay(String line) {
    if (Platform.isWindows && DesktopLyricsOverlay.instance.isVisible) {
      DesktopLyricsOverlay.instance.update(line);
    } else if (Platform.isAndroid) {
      AndroidLyricsOverlay.instance.update(line);
    }
  }

  String _display(LyricLine l) {
    if (_conv == 'orig') return l.jp;
    var zh = l.zh;
    if (_conv == 'tw' || _conv == 'zh') {
      final mode = _conv == 'tw' ? 's2t' : 't2s';
      final key = '$mode|$zh';
      var out = _convCache[key];
      if (out == null) {
        try {
          out = apiConvertText(text: zh, mode: mode);
        } catch (_) {
          out = zh;
        }
        _convCache[key] = out;
      }
      return out;
    }
    return zh;
  }

  @override
  void dispose() {
    _disposed = true;
    _matchSeq++;
    _app?.removeListener(_onAppChanged);
    if (_app != null) _libraryRevision.removeListener(_onLibraryChanged);
    for (final subscription in _subscriptions) {
      unawaited(subscription.cancel());
    }
    super.dispose();
  }
}
