import 'dart:async';
import 'dart:io';

import 'package:tray_manager/tray_manager.dart';
import 'package:window_manager/window_manager.dart';

import '../data.dart';
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
      _exit();
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
        _exit();
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
      return;
    }
    await AppPlayer.instance.player.play();
  }

  void _exit() {
    if (_exiting) return;
    _exiting = true;
    // destroy() 直接销毁原生窗口，不会再次触发 onWindowClose；托盘插件会在
    // WM_DESTROY 时自动移除图标。不要在菜单回调中串行等待多个平台调用，
    // 否则可见窗口会在退出前短暂无响应。
    unawaited(windowManager.destroy());
  }
}
