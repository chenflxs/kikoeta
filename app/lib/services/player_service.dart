import 'dart:async';
import 'dart:io';

import 'package:media_kit/media_kit.dart' hide Track;

import '../src/rust/api/proxy.dart';
import '../src/rust/api/simple.dart';
import 'android_audio.dart';

const _eqHz = ['31', '62', '125', '250', '500', '1k', '2k', '4k', '8k', '16k'];

/// stop()/open() 后残留 completed 事件的抑制窗口：
/// mpv 卸载旧文件/加载新文件产生的伪 completed=true 会在这段时间内到达，
/// 而真正的“播完”（EOF）只会在媒体实际播放结束后发生，远晚于该窗口。
const _suppressWindow = Duration(seconds: 2);

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
  AppPlayer._() {
    _subs = [
      player.stream.position.listen((d) {
        _lastPos = d.inSeconds;
        _posCtrl.add(_lastPos);
      }),
      player.stream.duration.listen((d) {
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
        if (!completed) return;
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
        _errorCtrl.add(e.toString());
        _scheduleReconnect();
      }),
    ];
  }

  static final AppPlayer instance = AppPlayer._();

  final Player player = Player();

  /// 当前是否已打开媒体（页面可据此判断是否需要重新打开）
  bool opened = false;

  /// 最后成功打开的原始媒体 URL（不含桌面本地代理地址）。
  String? openedUrl;

  /// stop()/open() 后的 completed 抑制截止时间；到点自动失效，避免被去重流卡死
  DateTime? _suppressCompletedUntil;
  int _releaseGeneration = 0;
  int _reconnectGeneration = 0;
  String? _remoteUrl;
  bool _playbackRequested = false;
  bool _reconnecting = false;

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

  /// 当前媒体时长（秒，未知为 0）
  int get currentDuration => _lastDur;

  /// 当前是否正在播放
  bool get isNowPlaying => _nowPlaying;

  Future<void> open(Media media, {bool autoplay = true}) async {
    _suppressCompletedUntil = DateTime.now().add(_suppressWindow);
    _lastPos = 0;
    _lastDur = 0;
    _posCtrl.add(_lastPos);
    _durCtrl.add(_lastDur);
    if (Platform.isAndroid && autoplay) {
      await AndroidAudio.setPlaybackActive(true);
    }
    try {
      await player.open(media, play: autoplay);
    } catch (_) {
      if (Platform.isAndroid && autoplay) {
        await AndroidAudio.setPlaybackActive(false);
      }
      rethrow;
    }
    opened = true;
  }

  /// 打开网络音频：桌面始终经本地代理转发；Android 在启用应用 HTTP
  /// 代理时也走本地代理，未启用时直连并附带该媒体域的 Bearer token。
  Future<void> openMediaUrl(
    String url, {
    bool autoplay = true,
    bool preserveReconnect = false,
  }) async {
    if (!preserveReconnect) _cancelReconnect();
    _playbackRequested = autoplay;
    _remoteUrl = url;
    final generation = _releaseGeneration;
    await _stop(preservePlaybackRequest: true);
    if (generation != _releaseGeneration) return;
    final httpProxy = await httpProxyConfig();
    if (generation != _releaseGeneration) return;
    final direct = Platform.isAndroid && httpProxy == null;
    final mediaUrl = direct ? url : apiStreamProxyUrl(url: url);
    final uri = Uri.tryParse(url);
    final base = uri == null || !uri.hasScheme
        ? ''
        : '${uri.scheme}://${uri.authority}';
    final token = base.isEmpty ? null : getToken(base: base);
    await open(
      Media(
        mediaUrl,
        httpHeaders: direct && token != null && token.isNotEmpty
            ? {'Authorization': 'Bearer $token'}
            : null,
      ),
      autoplay: autoplay,
    ).timeout(const Duration(seconds: 20));
    if (generation != _releaseGeneration) {
      await stop();
      opened = false;
      openedUrl = null;
      return;
    }
    openedUrl = url;
    // stop() 期间可能刚好收到旧媒体的错误事件；新媒体已经成功打开时，
    // 取消其排队的旧重连，避免稍后又把当前媒体重新打开一次。
    if (!preserveReconnect) _cancelReconnect();
  }

  /// 打开已下载的真实文件，不经过网络代理。
  Future<void> openLocalPath(String path, {bool autoplay = true}) async {
    _cancelReconnect();
    _playbackRequested = autoplay;
    _remoteUrl = null;
    final generation = _releaseGeneration;
    await _stop(preservePlaybackRequest: true);
    if (generation != _releaseGeneration) return;
    await open(Media(path), autoplay: autoplay);
    openedUrl = path;
  }

  /// 停止播放（抑制 stop 后短时间内残留的 completed，避免被误判为播放完成）
  Future<void> stop() async {
    _cancelReconnect();
    _playbackRequested = false;
    await _stop();
  }

  Future<void> _stop({bool preservePlaybackRequest = false}) async {
    if (!preservePlaybackRequest) _playbackRequested = false;
    _suppressCompletedUntil = DateTime.now().add(_suppressWindow);
    if (Platform.isAndroid) {
      await AndroidAudio.setPlaybackActive(false);
    }
    try {
      await player.stop();
    } catch (_) {}
  }

  /// 带播放意图地暂停。网络重连等待期间调用时会同时取消后续重试。
  Future<void> pause() async {
    _cancelReconnect();
    _playbackRequested = false;
    if (Platform.isAndroid) {
      await AndroidAudio.setPlaybackActive(false);
    }
    await player.pause();
  }

  /// 恢复播放。若上一次是网络流错误，不复用已失效的 mpv 会话，而是立即
  /// 重开原始 URL；这样网络恢复后点击一次播放即可生效。
  Future<void> play() async {
    _playbackRequested = true;
    if (_reconnecting && _remoteUrl != null) {
      _cancelReconnect();
      _scheduleReconnect(immediate: true);
      return;
    }
    if (Platform.isAndroid) {
      await AndroidAudio.setPlaybackActive(true);
    }
    try {
      await player.play();
    } catch (_) {
      if (Platform.isAndroid) {
        await AndroidAudio.setPlaybackActive(false);
      }
      rethrow;
    }
  }

  void _cancelReconnect() {
    _reconnectGeneration++;
    _setReconnecting(false);
  }

  void _setReconnecting(bool value) {
    if (_reconnecting == value) return;
    _reconnecting = value;
    _reconnectingCtrl.add(value);
  }

  void _scheduleReconnect({bool immediate = false}) {
    final url = _remoteUrl;
    if (url == null || !_playbackRequested || _reconnecting) return;
    final generation = ++_reconnectGeneration;
    _setReconnecting(true);
    unawaited(_reconnect(url, generation, immediate: immediate));
  }

  Future<void> _reconnect(
    String url,
    int generation, {
    required bool immediate,
  }) async {
    var attempt = immediate ? -1 : 0;
    // open() 会把 position 流归零；重试失败时仍保留第一次断流前的位置。
    final resumePosition = Duration(seconds: _lastPos);
    while (generation == _reconnectGeneration && _playbackRequested) {
      if (attempt >= 0) {
        final delayIndex = attempt
            .clamp(0, _reconnectDelays.length - 1)
            .toInt();
        final delay = _reconnectDelays[delayIndex];
        await Future<void>.delayed(delay);
      }
      if (generation != _reconnectGeneration || !_playbackRequested) return;

      // 位置由播放器最后一个有效 position 事件提供；网络中断后该值不会被
      // stop() 归零，因此可从中断处附近恢复，而不是从开头重新播放。
      opened = false;
      try {
        await openMediaUrl(url, autoplay: true, preserveReconnect: true);
        if (generation != _reconnectGeneration || !_playbackRequested) {
          // 用户在 open() 尚未完成时点了暂停；仅在仍是同一媒体时补一次暂停，
          // 不影响期间已切换到的新媒体。
          if (_remoteUrl == url && !_playbackRequested) {
            await player.pause();
          }
          return;
        }
        if (resumePosition > Duration.zero) {
          try {
            await player.seek(resumePosition);
          } catch (_) {}
        }
        _setReconnecting(false);
        return;
      } catch (_) {
        attempt++;
      }
    }
  }

  /// 停止并解除当前媒体关联，用于隐私模式等需要立即丢弃播放上下文的场景。
  Future<void> releaseMedia() async {
    _releaseGeneration++;
    _cancelReconnect();
    await stop();
    opened = false;
    openedUrl = null;
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
  }) async {
    try {
      final p = player.platform;
      if (p is! NativePlayer) return; // Android/其他后端暂不支持 af
      if (!enabled || gains.every((g) => g.abs() < 0.05)) {
        await p.setProperty('af', '');
        return;
      }
      final chain = List.generate(10, (i) {
        final hz = _eqHz[i];
        final g = gains[i].clamp(-12, 12).toStringAsFixed(1);
        return 'equalizer=f=$hz:t=q:w=1.0:g=$g';
      }).join(',');
      await p.setProperty('af', chain);
    } catch (_) {
      // 某些后端不支持动态 af：静默忽略
    }
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
