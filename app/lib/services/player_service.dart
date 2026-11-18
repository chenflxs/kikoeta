import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart' show debugPrint, visibleForTesting;
import 'package:media_kit/media_kit.dart' hide Track;

import '../src/rust/api/proxy.dart';
import '../src/rust/api/simple.dart';
import 'api_service.dart';
import 'android_audio.dart';
import 'app_log.dart';
import 'audio_effects.dart';

/// stop()/open() 后残留 completed 事件的抑制窗口：
/// mpv 卸载旧文件/加载新文件产生的伪 completed=true 会在这段时间内到达，
/// 而真正的“播完”（EOF）只会在媒体实际播放结束后发生，远晚于该窗口。
const _suppressWindow = Duration(seconds: 2);

const _tracePlayback = bool.fromEnvironment('KIKOETA_PLAYBACK_TRACE');

// mpv can report the timestamp of the packet just before a requested start.
const _reconnectPositionTolerance = Duration(milliseconds: 100);

/// 网络流中断后的自动重连间隔。最后一档会持续重试，避免网络恢复后仍
/// 需要切歌才能重新建立 mpv 的媒体会话。
const _reconnectDelays = <Duration>[
  Duration(seconds: 1),
  Duration(seconds: 2),
  Duration(seconds: 4),
  Duration(seconds: 8),
  Duration(seconds: 15),
];

/// 全局媒体播放器单例。
///
/// 播放器随应用生命周期常驻，退出播放器页面时不会销毁，
/// 重新进入页面可继续播放（不再从头开始）。
class AppPlayer {
  AppPlayer._({
    Player? backend,
    Future<Media> Function(String)? resolveMedia,
    this._audioOutputReleased,
  }) : player =
           backend ??
           Player(configuration: const PlayerConfiguration(pitch: false)),
       _resolveMedia = resolveMedia ?? ((url) => _networkMedia(url)),
       _usesDefaultMediaResolver = resolveMedia == null {
    if (_tracePlayback) unawaited(_trace('created'));
    _subs = [
      player.stream.position.listen((d) {
        final resumePosition = _reconnectPosition;
        if (resumePosition != null) {
          final attempt = _reconnectAttempt;
          if (attempt == null ||
              attempt.isCompleted ||
              d <= Duration.zero ||
              d + _reconnectPositionTolerance < resumePosition) {
            return;
          }
          attempt.complete(true);
        }
        _position = d;
        _lastPos = d.inSeconds;
        _posCtrl.add(_lastPos);
      }),
      player.stream.duration.listen((d) {
        if (_reconnectPosition != null && d == Duration.zero) return;
        _lastDur = d.inSeconds;
        _durCtrl.add(_lastDur);
      }),
      player.stream.playing.listen((p) {
        _nowPlaying = p;
        _playingCtrl.add(p);
      }),
      player.stream.buffering.listen((b) => _bufferingCtrl.add(b)),
      player.stream.completed.listen((completed) {
        // completed 流是去重流：stop()/open()/seek() 会把它复位为 false，
        // 只有 mpv 真正播到结尾（EOF）才会置为 true，仅此时才算播放完成。
        if (!completed || _mediaOperationActive) return;
        // 主动 stop()/open()（切歌、重开媒体、手动停止）后短时间内 mpv 会残留
        // 触发一次 completed=true，需要抑制避免误判播放完成。
        // 用时间窗口而不是等事件复位：去重流可能吞掉复位用的 false 事件，
        // 导致标志卡死、播完不自动切下一首。
        if (_suppressCompletedUntil != null &&
            DateTime.now().isBefore(_suppressCompletedUntil!)) {
          return;
        }
        _completedCtrl.add(null);
        if (Platform.isAndroid) {
          unawaited(AndroidAudio.setPlaybackActive(false));
        }
      }),
      player.stream.error.listen((e) {
        AppLog.recordError('playback backend', e);
        _errorCtrl.add(e.toString());
        _finishReconnectAttempt();
        _scheduleReconnect();
      }),
    ];
  }

  static final AppPlayer instance = AppPlayer._();

  @visibleForTesting
  factory AppPlayer.forTesting({
    required Player player,
    required Future<Media> Function(String) resolveMedia,
    Duration openTimeout = const Duration(seconds: 20),
    Future<bool> Function()? audioOutputReleased,
    Duration stopTimeout = const Duration(seconds: 5),
  }) =>
      AppPlayer._(
          backend: player,
          resolveMedia: resolveMedia,
          audioOutputReleased: audioOutputReleased,
        )
        .._openTimeout = openTimeout
        .._stopTimeout = stopTimeout;

  // Keep pitch control disabled: media_kit then sets mpv speed directly instead
  // of replacing af with its own scaletempo filter when changing the rate.
  final Player player;
  final Future<Media> Function(String) _resolveMedia;
  final bool _usesDefaultMediaResolver;
  final Future<bool> Function()? _audioOutputReleased;
  Duration _stopTimeout = const Duration(seconds: 5);
  Future<void> _mediaOperations = Future<void>.value();
  bool _mediaOperationActive = false;
  Duration _openTimeout = const Duration(seconds: 20);

  bool _equalizerEnabled = false;
  List<double> _equalizerGains = const [];
  AudioChannelMode _channelMode = AudioChannelMode.stereo;
  Future<void> _audioFilterUpdates = Future<void>.value();
  String? _appliedAudioFilterChain;

  /// 当前是否已打开媒体。自动重连期间保留媒体关联。
  bool opened = false;

  /// 最后成功打开的原始媒体 URL（不含桌面本地代理地址）。
  String? openedUrl;

  /// stop()/open() 后的 completed 抑制截止时间；到点自动失效，避免被去重流卡死
  DateTime? _suppressCompletedUntil;
  int _mediaGeneration = 0;
  int _reconnectGeneration = 0;
  String? _remoteUrl;
  bool _playbackRequested = false;
  bool _reconnecting = false;
  Duration? _reconnectPosition;
  Completer<bool>? _reconnectAttempt;

  Duration _position = Duration.zero;
  int _lastPos = 0;
  int _lastDur = 0;
  bool _nowPlaying = false;

  final _posCtrl = StreamController<int>.broadcast();
  final _durCtrl = StreamController<int>.broadcast();
  final _playingCtrl = StreamController<bool>.broadcast();
  final _bufferingCtrl = StreamController<bool>.broadcast();
  final _completedCtrl = StreamController<void>.broadcast();
  final _releasedCtrl = StreamController<void>.broadcast();
  final _errorCtrl = StreamController<String>.broadcast();
  final _reconnectingCtrl = StreamController<bool>.broadcast();

  late final List<StreamSubscription> _subs;

  Stream<int> get position => _posCtrl.stream;
  Stream<int> get duration => _durCtrl.stream;
  Stream<bool> get playing => _playingCtrl.stream;
  Stream<bool> get buffering => _bufferingCtrl.stream;
  Stream<void> get completed => _completedCtrl.stream;
  Stream<void> get released => _releasedCtrl.stream;
  Stream<String> get error => _errorCtrl.stream;
  Stream<bool> get reconnecting => _reconnectingCtrl.stream;

  /// 当前网络媒体是否正等待下一次重连。
  bool get isReconnecting => _reconnecting;

  /// 当前播放位置（秒）
  int get currentPosition => _lastPos;
  Duration get currentPositionPrecise => _position;

  /// 当前媒体时长（秒，未知为 0）
  int get currentDuration => _lastDur;

  /// 当前是否正在播放
  bool get isNowPlaying => _nowPlaying;

  /// Opt-in native snapshots for Android device debugging; no media URLs/tokens.
  Future<void> _trace(String event) async {
    if (AppLog.enabled) {
      AppLog.record(
        'playback $event generation=$_mediaGeneration position_sec=$_lastPos '
        'opened=$opened requested=$_playbackRequested',
      );
    }
    if (!_tracePlayback) return;
    try {
      final backend = player.platform;
      final values = <String>[];
      if (backend is NativePlayer) {
        values.add('handle=${await backend.handle}');
        for (final key in [
          'mpv-version',
          'playlist-count',
          'idle-active',
          'pause',
          'current-ao',
          'audio-out-params',
          'gapless-audio',
          'time-pos',
        ]) {
          values.add('$key=${await backend.getProperty(key)}');
        }
      }
      debugPrint(
        '[playback] pid=$pid instance=${identityHashCode(this)} '
        'generation=$_mediaGeneration event=$event pos=$_lastPos '
        'opened=$opened requested=$_playbackRequested ${values.join(' ')}',
      );
    } catch (_) {
      // Diagnostics must not change playback error handling.
    }
  }

  // Match media_kit's serialized native commands, but keep stop, URL resolution
  // and open in one operation. A timeout must not release this queue while the
  // underlying open is still running (Future.timeout does not cancel it).
  Future<void> _enqueueMediaOperation(Future<void> Function() operation) {
    final result = _mediaOperations.then((_) async {
      _mediaOperationActive = true;
      try {
        await operation();
      } finally {
        _mediaOperationActive = false;
      }
    });
    _mediaOperations = result.then<void>(
      (_) {},
      onError: (Object _, StackTrace _) {},
    );
    return result;
  }

  static Future<Media> _networkMedia(
    String url, {
    bool includeAuthorization = true,
  }) async {
    final httpProxy = await httpProxyConfig();
    final direct =
        !includeAuthorization || (Platform.isAndroid && httpProxy == null);
    final mediaUrl = direct ? url : apiStreamProxyUrl(url: url);
    final uri = Uri.tryParse(url);
    final base = uri == null || !uri.hasScheme
        ? ''
        : '${uri.scheme}://${uri.authority}';
    final token = includeAuthorization && base.isNotEmpty
        ? getToken(base: base)
        : null;
    return Media(
      mediaUrl,
      httpHeaders: direct && token != null && token.isNotEmpty
          ? {'Authorization': 'Bearer $token'}
          : null,
    );
  }

  /// 打开网络音频：桌面经本地代理；Android 未启用 HTTP 代理时直连。
  Future<void> openMediaUrl(String url, {bool autoplay = true}) => _openSource(
    url,
    () => _resolveNetworkMedia(url),
    autoplay: autoplay,
    remote: true,
  );

  Future<Media> _resolveNetworkMedia(String url) async {
    if (!url.startsWith('dlsite-play:')) return _resolveMedia(url);
    final signedUrl = await ApiService.resolveActiveMediaUrl(url);
    // Signed DLsite URLs carry their own authorization. Keep them out of the
    // Rust stream proxy, which may attach a Kikoeta bearer token by origin.
    return _usesDefaultMediaResolver
        ? _networkMedia(signedUrl, includeAuthorization: false)
        : _resolveMedia(signedUrl);
  }

  /// 打开已下载的真实文件，不经过网络代理。
  Future<void> openLocalPath(String path, {bool autoplay = true}) =>
      _openSource(
        path,
        () async => Media(path),
        autoplay: autoplay,
        remote: false,
      );

  Future<void> _openSource(
    String source,
    Future<Media> Function() resolve, {
    required bool autoplay,
    required bool remote,
    Duration? resumePosition,
  }) {
    final generation = ++_mediaGeneration;
    if (resumePosition == null) {
      _cancelReconnect();
      _reconnectPosition = null;
      _position = Duration.zero;
      opened = false;
      openedUrl = null;
    }
    _playbackRequested = autoplay;
    _remoteUrl = remote ? source : null;
    final operation = _enqueueMediaOperation(() async {
      if (generation != _mediaGeneration) return;
      await _stop();
      if (generation != _mediaGeneration) return;
      var media = await resolve();
      if (generation != _mediaGeneration) return;
      _suppressCompletedUntil = DateTime.now().add(_suppressWindow);
      if (resumePosition == null) {
        _position = Duration.zero;
        _lastPos = 0;
        _lastDur = 0;
        _posCtrl.add(0);
        _durCtrl.add(0);
      } else if (!_reconnecting || !_playbackRequested) {
        return;
      } else if (resumePosition > Duration.zero) {
        // media_kit applies start in mpv's on_load hook, before playback starts.
        media = media.copyWith(start: resumePosition);
      }
      final attempt = resumePosition == null ? null : Completer<bool>();
      _reconnectAttempt = attempt;
      try {
        // Open paused so a superseded/late request can never start old audio.
        await _trace('open-begin');
        await player.open(media, play: false);
        await _trace('open-end');
        if (generation != _mediaGeneration) {
          await _stop();
          return;
        }
        // At position zero, the clock needs to advance to distinguish a working
        // stream from the zero emitted by stop/open.
        final waitBeforePlaying =
            resumePosition != null && resumePosition > Duration.zero;
        if (!waitBeforePlaying && _playbackRequested) await _play(generation);
        // open() only queues the media in mpv. Wait for its playback clock to
        // reach the checkpoint before treating the reconnect as successful.
        final resumed = attempt == null || await attempt.future;
        if (generation != _mediaGeneration) {
          await _stop();
          return;
        }
        if (!resumed) {
          if (_reconnecting && _playbackRequested) {
            throw StateError('Playback did not resume');
          }
          return;
        }
        if (waitBeforePlaying) {
          await _play(generation);
          if (generation != _mediaGeneration) {
            await _stop();
            return;
          }
        }
        opened = true;
        openedUrl = source;
        if (resumePosition == null) {
          _cancelReconnect();
        } else {
          _reconnectPosition = null;
          _setReconnecting(false);
        }
      } finally {
        _reconnectAttempt = null;
      }
    });
    return operation
        .catchError((Object error, StackTrace stack) {
          // Superseded callers must not retry their old URL or change new UI state.
          if (generation != _mediaGeneration) return;
          AppLog.recordError('playback open', error, stack);
          Error.throwWithStackTrace(error, stack);
        })
        .timeout(
          _openTimeout,
          onTimeout: () {
            if (generation != _mediaGeneration) return;
            // Invalidate late completion without cancelling the reconnect loop's
            // playback intent. The queued operation still owns native cleanup.
            _mediaGeneration++;
            _finishReconnectAttempt();
            if (resumePosition == null) {
              opened = false;
              openedUrl = null;
            }
            final error = TimeoutException(
              'Opening media timed out',
              _openTimeout,
            );
            AppLog.recordError('playback open', error, StackTrace.current);
            throw error;
          },
        );
  }

  /// 停止播放，并使所有尚未完成的媒体加载失效。
  Future<void> stop() {
    final generation = ++_mediaGeneration;
    _cancelReconnect();
    _reconnectPosition = null;
    _playbackRequested = false;
    _remoteUrl = null;
    opened = false;
    openedUrl = null;
    return _enqueueMediaOperation(() async {
      if (generation == _mediaGeneration) await _stop();
    });
  }

  Future<void> _stop() async {
    _suppressCompletedUntil = DateTime.now().add(_suppressWindow);
    if (Platform.isAndroid) {
      await AndroidAudio.setPlaybackActive(false);
    }
    await _trace('stop-begin');
    // Android must stop rendering buffered audio before the device is closed.
    if (Platform.isAndroid || _audioOutputReleased != null) {
      await player.pause();
    }
    await player.stop();
    await _waitForAudioOutputRelease();
    _suppressCompletedUntil = DateTime.now().add(_suppressWindow);
    await _trace('stop-end');
  }

  Future<void> _waitForAudioOutputRelease() async {
    final backend = player.platform;
    if (_audioOutputReleased == null &&
        (!Platform.isAndroid || backend is! NativePlayer)) {
      return;
    }
    final clock = Stopwatch()..start();
    while (true) {
      final bool released;
      if (_audioOutputReleased != null) {
        released = await _audioOutputReleased();
      } else {
        final native = backend as NativePlayer;
        released =
            await native.getProperty('idle-active') == 'yes' &&
            (await native.getProperty('current-ao')).isEmpty;
      }
      if (released) return;
      if (clock.elapsed >= _stopTimeout) {
        // Keep the new source closed if the old Android output cannot close.
        throw StateError('Previous audio output did not close');
      }
      await Future<void>.delayed(const Duration(milliseconds: 10));
    }
  }

  /// 暂停时保留媒体，同时阻止尚未完成的 open 自动启播。
  Future<void> pause() {
    _cancelReconnect();
    _playbackRequested = false;
    final generation = _mediaGeneration;
    return _enqueueMediaOperation(() async {
      if (generation != _mediaGeneration || _playbackRequested) return;
      if (Platform.isAndroid) await AndroidAudio.setPlaybackActive(false);
      await player.pause();
      await _trace('pause-end');
    });
  }

  Future<void> play() {
    _playbackRequested = true;
    if (_reconnectPosition != null && _remoteUrl != null) {
      _cancelReconnect();
      _scheduleReconnect(immediate: true);
      return Future<void>.value();
    }
    final generation = _mediaGeneration;
    return _enqueueMediaOperation(() => _play(generation));
  }

  Future<void> _play(int generation) async {
    if (generation != _mediaGeneration || !_playbackRequested) return;
    if (Platform.isAndroid) await AndroidAudio.setPlaybackActive(true);
    if (generation != _mediaGeneration || !_playbackRequested) return;
    try {
      await player.play();
      await _trace('play-end');
    } catch (_) {
      if (Platform.isAndroid) await AndroidAudio.setPlaybackActive(false);
      rethrow;
    }
  }

  void _cancelReconnect() {
    _reconnectGeneration++;
    _finishReconnectAttempt();
    _setReconnecting(false);
  }

  void _finishReconnectAttempt() {
    final attempt = _reconnectAttempt;
    if (attempt != null && !attempt.isCompleted) attempt.complete(false);
  }

  void _setReconnecting(bool value) {
    if (_reconnecting == value) return;
    _reconnecting = value;
    AppLog.record(
      value ? 'playback reconnect started' : 'playback reconnect ended',
    );
    _reconnectingCtrl.add(value);
  }

  void _scheduleReconnect({bool immediate = false}) {
    final url = _remoteUrl;
    if (url == null || !_playbackRequested || _reconnecting) return;
    final resumePosition = _reconnectPosition ??= _position;
    final generation = ++_reconnectGeneration;
    _setReconnecting(true);
    unawaited(
      _reconnect(url, generation, resumePosition, immediate: immediate),
    );
  }

  Future<void> _reconnect(
    String url,
    int generation,
    Duration resumePosition, {
    required bool immediate,
  }) async {
    var attempt = immediate ? -1 : 0;
    while (generation == _reconnectGeneration && _playbackRequested) {
      if (attempt >= 0) {
        final delayIndex = attempt
            .clamp(0, _reconnectDelays.length - 1)
            .toInt();
        final delay = _reconnectDelays[delayIndex];
        await Future<void>.delayed(delay);
      }
      if (generation != _reconnectGeneration || !_playbackRequested) return;

      try {
        await _openSource(
          url,
          () => _resolveNetworkMedia(url),
          autoplay: true,
          remote: true,
          resumePosition: resumePosition,
        );
        return;
      } catch (_) {
        attempt++;
      }
    }
  }

  /// 停止并解除当前媒体关联，用于隐私模式等需要立即丢弃播放上下文的场景。
  Future<void> releaseMedia() async {
    final stopping = stop();
    final generation = _mediaGeneration;
    await stopping;
    if (generation != _mediaGeneration) return;
    opened = false;
    openedUrl = null;
    _position = Duration.zero;
    _lastPos = 0;
    _lastDur = 0;
    _posCtrl.add(_lastPos);
    _durCtrl.add(_lastDur);
    _releasedCtrl.add(null);
  }

  /// 应用 10 段 EQ（mpv af 链）。
  /// media_kit 在 Android 端同样基于 libmpv（NativePlayer），因此桌面与 Android 均生效；
  /// 仅 Web 播放器不支持。
  Future<void> applyEqualizer({
    required bool enabled,
    required List<double> gains,
  }) {
    _equalizerEnabled = enabled;
    _equalizerGains = List<double>.of(gains);
    return _applyAudioFilters();
  }

  Future<void> setChannelMode(AudioChannelMode mode) {
    _channelMode = mode;
    return _applyAudioFilters();
  }

  Future<void> setPlaybackRate(double rate) =>
      player.setRate(normalizePlaybackRate(rate));

  Future<void> _applyAudioFilters() {
    // Serialize rapid changes and build from the latest combined state after
    // prior writes finish, so an older EQ update cannot overwrite channel mode.
    _audioFilterUpdates = _audioFilterUpdates.then((_) async {
      try {
        final platform = player.platform;
        if (platform is! NativePlayer) return;
        final chain = buildAudioFilterChain(
          equalizerEnabled: _equalizerEnabled,
          gains: _equalizerGains,
          channelMode: _channelMode,
        );
        if (chain == _appliedAudioFilterChain) return;
        await platform.setProperty('af', chain);
        _appliedAudioFilterChain = chain;
      } catch (_) {
        // 某些后端不支持动态 af：沿用原有 EQ 的兼容处理。
      }
    });
    return _audioFilterUpdates;
  }

  /// 设置 mpv 网络媒体缓冲上限，只影响在线播放时占用的内存。
  Future<void> setMediaCacheLimitMb(int megabytes) async {
    final platform = player.platform;
    if (platform is! NativePlayer) return;
    final bytes = megabytes.clamp(512, 10240) * 1024 * 1024;
    try {
      await platform.setProperty('demuxer-max-bytes', '$bytes');
    } catch (_) {
      // 某些后端不支持运行时调整该 mpv 属性：保持播放器默认值。
    }
  }

  /// Android 的音频输出优先使用 AudioTrack，并在不可用时回退到 OpenSL ES。
  ///
  /// AudioTrack 由 Android 音频服务直接管理，在前台界面高频重绘、切换后台
  /// 等调度抖动场景中通常比自动选择的后端更稳定。1 秒缓冲是为音声播放
  /// 取的保守值：牺牲少量 seek/倍速切换响应，换取不把短暂 underrun 听成
  /// 环境声缺失或爆音。必须在首次 open 前调用。
  Future<void> configureAndroidAudioStability() async {
    if (!Platform.isAndroid) return;
    final platform = player.platform;
    if (platform is! NativePlayer) return;
    const options = <String, String>{
      // 列表中前一个后端不可用时，mpv 会继续尝试后面的后端。
      'ao': 'audiotrack,opensles',
      'audio-buffer': '1.0',
      // Manual replacement must close the old device, even for identical PCM
      // formats. mpv's default weak gapless mode may retain the old output.
      'gapless-audio': 'no',
    };
    for (final entry in options.entries) {
      try {
        await platform.setProperty(entry.key, entry.value);
      } catch (_) {
        // 不同 media_kit/libmpv 构建支持的后端不同，保持原后端可用。
      }
    }
  }

  /// 应用退出时释放（平时播放器常驻，不随页面销毁）
  void dispose() {
    _mediaGeneration++;
    _cancelReconnect();
    _playbackRequested = false;
    if (Platform.isAndroid) {
      unawaited(AndroidAudio.setPlaybackActive(false));
    }
    for (final s in _subs) {
      s.cancel();
    }
    _releasedCtrl.close();
    _reconnectingCtrl.close();
    player.dispose();
  }
}
