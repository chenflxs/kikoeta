import 'dart:async';
import 'dart:io';

import 'package:media_kit/media_kit.dart' hide Track;

import '../src/rust/api/proxy.dart';

const _eqHz = ['31', '62', '125', '250', '500', '1k', '2k', '4k', '8k', '16k'];

/// stop()/open() 后残留 completed 事件的抑制窗口：
/// mpv 卸载旧文件/加载新文件产生的伪 completed=true 会在这段时间内到达，
/// 而真正的“播完”（EOF）只会在媒体实际播放结束后发生，远晚于该窗口。
const _suppressWindow = Duration(seconds: 2);

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
      }),
      player.stream.error.listen((e) => _errorCtrl.add(e.toString())),
    ];
  }

  static final AppPlayer instance = AppPlayer._();

  final Player player = Player();

  /// 当前是否已打开媒体（页面可据此判断是否需要重新打开）
  bool opened = false;

  /// stop()/open() 后的 completed 抑制截止时间；到点自动失效，避免被去重流卡死
  DateTime? _suppressCompletedUntil;

  int _lastPos = 0;
  int _lastDur = 0;
  bool _nowPlaying = false;

  final _posCtrl = StreamController<int>.broadcast();
  final _durCtrl = StreamController<int>.broadcast();
  final _playingCtrl = StreamController<bool>.broadcast();
  final _bufferingCtrl = StreamController<bool>.broadcast();
  final _completedCtrl = StreamController<void>.broadcast();
  final _errorCtrl = StreamController<String>.broadcast();

  late final List<StreamSubscription> _subs;

  Stream<int> get position => _posCtrl.stream;
  Stream<int> get duration => _durCtrl.stream;
  Stream<bool> get playing => _playingCtrl.stream;
  Stream<bool> get buffering => _bufferingCtrl.stream;
  Stream<void> get completed => _completedCtrl.stream;
  Stream<String> get error => _errorCtrl.stream;

  /// 当前播放位置（秒）
  int get currentPosition => _lastPos;

  /// 当前媒体时长（秒，未知为 0）
  int get currentDuration => _lastDur;

  /// 当前是否正在播放
  bool get isNowPlaying => _nowPlaying;

  Future<void> open(Media media, {bool autoplay = true}) async {
    _suppressCompletedUntil = DateTime.now().add(_suppressWindow);
    await player.open(media, play: autoplay);
    opened = true;
  }

  /// 打开网络音频：Android 直连（mpv 自带 TLS），其余平台走本地 Rust 代理
  Future<void> openMediaUrl(String url, {bool autoplay = true}) async {
    await stop();
    final mediaUrl = Platform.isAndroid ? url : apiStreamProxyUrl(url: url);
    await open(
      Media(mediaUrl),
      autoplay: autoplay,
    ).timeout(const Duration(seconds: 20));
  }

  /// 停止播放（抑制 stop 后短时间内残留的 completed，避免被误判为播放完成）
  Future<void> stop() async {
    _suppressCompletedUntil = DateTime.now().add(_suppressWindow);
    try {
      await player.stop();
    } catch (_) {}
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

  /// 应用退出时释放（平时播放器常驻，不随页面销毁）
  void dispose() {
    for (final s in _subs) {
      s.cancel();
    }
    player.dispose();
  }
}
