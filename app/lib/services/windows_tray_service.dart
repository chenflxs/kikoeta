import 'dart:async';
import 'dart:io';

import 'package:tray_manager/tray_manager.dart';
import 'package:window_manager/window_manager.dart';
import 'package:flutter/services.dart';
import 'package:win32/win32.dart' as win32;

import '../data.dart';
import 'api_service.dart';
import 'desktop_lyrics_overlay.dart';
import 'download_service.dart';
import 'player_service.dart';
import 'startup_trace.dart';
import '../l10n/strings.dart';

class WindowsTrayService with TrayListener, WindowListener {
  WindowsTrayService._();
  static final instance = WindowsTrayService._();
  static const _lifecycle = MethodChannel('kikoeta/lifecycle');

  late AppState _app;
  bool _initialized = false;
  bool _exiting = false;
  bool? _menuLyricsOn;
  bool? _menuPlaying;
  String? _menuLanguage;

  Future<void> init(AppState app) async {
    _app = app;
    if (_initialized || !Platform.isWindows) return;
    _initialized = true;
    await StartupTrace.stage(
      'tray.window-manager',
      windowManager.ensureInitialized,
    );
    // Use the Flutter caption rendered by the app instead of the native title bar.
    await StartupTrace.stage(
      'tray.title-bar',
      () => windowManager.setTitleBarStyle(TitleBarStyle.hidden),
    );
    // 拦截原生关闭事件，交由 onWindowClose 根据用户设置隐藏或退出。
    await windowManager.setPreventClose(true);
    windowManager.addListener(this);
    trayManager.addListener(this);
    _app.addListener(_syncContextMenu);
    await StartupTrace.stage(
      'tray.icon',
      () => trayManager.setIcon('assets/tray_icon.ico'),
    );
    await StartupTrace.stage(
      'tray.tooltip',
      () => trayManager.setToolTip('Kikoeta'),
    );
    await StartupTrace.stage('tray.menu', _setContextMenu);
  }

  Future<void> _setContextMenu() async {
    _menuLyricsOn = _app.desktopLyricsOn;
    _menuPlaying = _app.playing;
    _menuLanguage = _app.uiLanguage;
    await trayManager.setContextMenu(
      Menu(
        items: [
          MenuItem(
            key: 'show-home',
            label: appL10n.windowsTrayServiceSetContextMenuLabel,
          ),
          MenuItem.checkbox(
            key: 'desktop-lyrics',
            label: appL10n.desktopLyrics,
            checked: _app.desktopLyricsOn,
          ),
          MenuItem(
            key: 'toggle-playback',
            label: _app.playing ? appL10n.pause : appL10n.play,
          ),
          MenuItem(key: 'exit', label: appL10n.quit),
        ],
      ),
    );
  }

  void _syncContextMenu() {
    if (!_initialized ||
        (_menuLyricsOn == _app.desktopLyricsOn &&
            _menuPlaying == _app.playing &&
            _menuLanguage == _app.uiLanguage)) {
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
      await AppPlayer.instance.pause();
      _app.playing = false;
      _app.notify();
      return;
    }
    if (!AppPlayer.instance.opened) {
      if (_app.queue.isEmpty) return;
      final node = _app.queue[_app.trackIdx];
      final local = _app.currentWork == null
          ? null
          : DownloadManager.instance.localPathFor(
              server: ApiService.resolveBase(_app),
              work: _app.currentWork!,
              node: node,
            );
      if (local != null) {
        await AppPlayer.instance.openLocalPath(local);
      } else {
        final url = node.url;
        if (url == null) return;
        await AppPlayer.instance.openMediaUrl(url);
      }
      await AppPlayer.instance.player.setVolume(_app.volume);
      await AppPlayer.instance.applyEqualizer(
        enabled: _app.eqOn,
        gains: _app.eqGains,
      );
      _app.playing = true;
      _app.notify();
      return;
    }
    await AppPlayer.instance.play();
    _app.playing = true;
    _app.notify();
  }

  Future<void> _exit() async {
    if (_exiting) return;
    _exiting = true;
    // Arm native fallback before any cleanup: Dart timers cannot run while
    // synchronous Win32 calls or Flutter engine destruction are blocked.
    try {
      await _lifecycle.invokeMethod<void>('beginExit');
    } catch (_) {
      // Also support an older runner while developing with hot restart.
      Timer(const Duration(seconds: 3), _terminateProcess);
    }
    _app.removeListener(_syncContextMenu);
    try {
      // 窗口关闭不会触发播放器页 dispose；退出前强制保存播放器当前位置。
      if (_app.queue.isNotEmpty &&
          (AppPlayer.instance.opened ||
              _app.playing ||
              _app.resumePosition == 0)) {
        _app.resumePosition = AppPlayer.instance.currentPosition;
        _app.savePlayState();
      }
      DesktopLyricsOverlay.instance.dispose();
      await trayManager.destroy();
      await windowManager.setPreventClose(false);
      await windowManager.close();
    } catch (_) {
      _terminateProcess();
    }
  }

  static void _terminateProcess() {
    win32.TerminateProcess(win32.GetCurrentProcess(), 0);
  }
}
