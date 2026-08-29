import 'dart:async';
import 'dart:io';

import 'package:tray_manager/tray_manager.dart';
import 'package:window_manager/window_manager.dart';

import '../data.dart';
import 'desktop_lyrics_overlay.dart';
import 'player_service.dart';

class WindowsTrayService with TrayListener, WindowListener {
  WindowsTrayService._();
  static final instance = WindowsTrayService._();

  late AppState _app;
  bool _initialized = false;
  bool _exiting = false;
  bool? _menuLyricsOn;
  bool? _menuPlaying;

  Future<void> init(AppState app) async {
    _app = app;
    if (_initialized || !Platform.isWindows) return;
    _initialized = true;
    await windowManager.ensureInitialized();
    // 拦截原生关闭事件，交由 onWindowClose 根据用户设置隐藏或退出。
    await windowManager.setPreventClose(true);
    windowManager.addListener(this);
    trayManager.addListener(this);
    _app.addListener(_syncContextMenu);
    await trayManager.setIcon('assets/tray_icon.ico');
    await trayManager.setToolTip('Kikoeta');
    await _setContextMenu();
  }

  Future<void> _setContextMenu() async {
    _menuLyricsOn = _app.desktopLyricsOn;
    _menuPlaying = _app.playing;
    await trayManager.setContextMenu(
      Menu(
        items: [
          MenuItem(key: 'show-home', label: '显示首页'),
          MenuItem.checkbox(
            key: 'desktop-lyrics',
            label: '桌面歌词',
            checked: _app.desktopLyricsOn,
          ),
          MenuItem(key: 'toggle-playback', label: _app.playing ? '暂停' : '播放'),
          MenuItem(key: 'exit', label: '退出'),
        ],
      ),
    );
  }

  void _syncContextMenu() {
    if (!_initialized ||
        (_menuLyricsOn == _app.desktopLyricsOn &&
            _menuPlaying == _app.playing)) {
      return;
    }
    unawaited(_setContextMenu());
  }

  @override
  Future<void> onWindowClose() async {
    if (_exiting) return;
    if (_app.keepTrayOnClose) {
      await windowManager.hide();
    } else {
      unawaited(_exit());
    }
  }

  @override
  void onTrayIconMouseDown() {
    _showHome();
  }

  @override
  void onTrayIconRightMouseDown() {
    unawaited(trayManager.popUpContextMenu());
  }

  @override
  void onTrayMenuItemClick(MenuItem menuItem) {
    switch (menuItem.key) {
      case 'show-home':
        unawaited(_showHome());
      case 'desktop-lyrics':
        _app.setDesktopLyricsOn(!_app.desktopLyricsOn);
      case 'toggle-playback':
        unawaited(_togglePlayback());
      case 'exit':
        unawaited(_exit());
    }
  }

  Future<void> _showHome() async {
    _app.selectTab(0);
    await windowManager.show();
    await windowManager.focus();
  }

  Future<void> _togglePlayback() async {
    if (_app.playing) {
      await AppPlayer.instance.player.pause();
      _app.playing = false;
      _app.notify();
      return;
    }
    if (!AppPlayer.instance.opened) {
      if (_app.queue.isEmpty) return;
      final url = _app.queue[_app.trackIdx].url;
      if (url == null) return;
      await AppPlayer.instance.openMediaUrl(url);
      await AppPlayer.instance.player.setVolume(_app.volume);
      await AppPlayer.instance.applyEqualizer(
        enabled: _app.eqOn,
        gains: _app.eqGains,
      );
      _app.playing = true;
      _app.notify();
      return;
    }
    await AppPlayer.instance.player.play();
    _app.playing = true;
    _app.notify();
  }

  Future<void> _exit() async {
    if (_exiting) return;
    _exiting = true;
    // 窗口关闭不会触发播放器页 dispose；退出前强制保存播放器当前位置。
    if (_app.queue.isNotEmpty &&
        (AppPlayer.instance.opened ||
            _app.playing ||
            _app.resumePosition == 0)) {
      _app.resumePosition = AppPlayer.instance.currentPosition;
      _app.savePlayState();
    }
    // Prevent a stuck native close callback from keeping the Dart isolate and
    // the lyrics window alive after the user explicitly chose "Exit".
    Timer(const Duration(seconds: 2), () => exit(0));
    DesktopLyricsOverlay.instance.dispose();
    try {
      await trayManager.destroy();
      await windowManager.setPreventClose(false);
      await windowManager.close();
    } catch (_) {
      exit(0);
    }
  }
}
