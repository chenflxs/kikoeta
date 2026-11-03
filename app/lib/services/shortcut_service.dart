import 'dart:ffi';
import 'dart:io';
import 'dart:isolate';

import 'package:ffi/ffi.dart';
import 'package:flutter/foundation.dart';
import 'package:win32/win32.dart';

import 'settings_store.dart';

/// Windows 桌面/开始菜单快捷方式（绿色版首次运行自动创建）：
/// - 仅在 release 版、Windows 平台执行
/// - 成功创建一次后写入设置标记，不再重复创建
/// - 创建失败静默（不影响应用启动）
class ShortcutService {
  ShortcutService._();

  static const _appName = 'Kikoeta';
  static const _doneKey = 'shortcuts_created';

  /// 首次运行创建桌面与开始菜单快捷方式（幂等）
  static Future<void> ensureShortcuts() async {
    if (!Platform.isWindows || kReleaseMode == false) return;
    try {
      if (SettingsStore.get(_doneKey) == '1') return;
      final exe = Platform.resolvedExecutable;
      if (await Isolate.run(() => _createShortcuts(exe))) {
        SettingsStore.set(_doneKey, '1');
      }
    } catch (_) {
      // 创建失败静默（不影响应用启动；下次运行会重试）
    }
  }

  @visibleForTesting
  static Future<bool> createForTesting(
    String exe,
    String desktop,
    String programs,
  ) => Isolate.run(
    () => _createShortcuts(exe, desktop: desktop, programs: programs),
  );

  // Keep all Shell/COM calls synchronous on the worker, so interfaces never
  // cross an await or an isolate boundary. Shell extensions can block here
  // without blocking Flutter's UI or the tray message loop.
  static bool _createShortcuts(
    String exe, {
    String? desktop,
    String? programs,
  }) {
    final hr = CoInitializeEx(nullptr, COINIT_APARTMENTTHREADED);
    if (FAILED(hr)) return false;
    try {
      desktop ??= _knownFolder(FOLDERID_Desktop);
      programs ??= _knownFolder(FOLDERID_Programs);
      if (desktop == null || programs == null) return false;
      final exeDir = File(exe).parent.path;
      _createLink('$desktop\\$_appName.lnk', exe, exeDir);
      _createLink('$programs\\$_appName.lnk', exe, exeDir);
      return true;
    } finally {
      CoUninitialize();
    }
  }

  /// 解析已知文件夹路径（桌面 / 开始菜单 Programs），失败返回 null
  static String? _knownFolder(String folderId) {
    final guid = GUIDFromString(folderId);
    try {
      final pathPtr = calloc<Pointer<Utf16>>();
      try {
        final hr = SHGetKnownFolderPath(guid, 0, 0, pathPtr);
        if (hr != S_OK || pathPtr.value == nullptr) return null;
        return pathPtr.value.toDartString();
      } finally {
        if (pathPtr.value != nullptr) CoTaskMemFree(pathPtr.value);
        calloc.free(pathPtr);
      }
    } finally {
      calloc.free(guid);
    }
  }

  /// 创建指向 [target] 的 .lnk（工作目录 + 图标均指向应用）。
  /// Release both interfaces before uninitializing their COM apartment.
  static void _createLink(String linkPath, String target, String workDir) {
    final shellLink = ShellLink.createInstance();
    shellLink.detach();
    final targetW = target.toNativeUtf16();
    final workW = workDir.toNativeUtf16();
    try {
      final hrPath = shellLink.setPath(targetW);
      final hrWork = shellLink.setWorkingDirectory(workW);
      final hrIcon = shellLink.setIconLocation(targetW, 0);
      if (hrPath != S_OK) throw WindowsException(hrPath);
      if (hrWork != S_OK) throw WindowsException(hrWork);
      if (hrIcon != S_OK) throw WindowsException(hrIcon);
      final persist = IPersistFile.from(shellLink);
      persist.detach();
      final linkW = linkPath.toNativeUtf16();
      try {
        final hrSave = persist.save(linkW, TRUE);
        if (hrSave != S_OK) throw WindowsException(hrSave);
      } finally {
        calloc.free(linkW);
        persist.release();
        calloc.free(persist.ptr);
      }
    } finally {
      calloc.free(targetW);
      calloc.free(workW);
      shellLink.release();
      calloc.free(shellLink.ptr);
    }
  }
}
