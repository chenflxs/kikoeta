import 'dart:ffi';
import 'dart:io';

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
      final exeDir = File(exe).parent.path;
      final desktop = _knownFolder(FOLDERID_Desktop);
      final programs = _knownFolder(FOLDERID_Programs);
      if (desktop == null || programs == null) return;
      _createLink('$desktop\\$_appName.lnk', exe, exeDir);
      _createLink('$programs\\$_appName.lnk', exe, exeDir);
      SettingsStore.set(_doneKey, '1');
    } catch (_) {
      // 创建失败静默（不影响应用启动；下次运行会重试）
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
  /// COM 对象由 win32 的 Finalizer 自动释放，无需手动 Release。
  static void _createLink(String linkPath, String target, String workDir) {
    final hrInit = CoInitializeEx(nullptr, COINIT_APARTMENTTHREADED);
    final shellLink = ShellLink.createInstance();
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
      final linkW = linkPath.toNativeUtf16();
      try {
        final hrSave = persist.save(linkW, TRUE);
        if (hrSave != S_OK) throw WindowsException(hrSave);
      } finally {
        calloc.free(linkW);
      }
    } finally {
      calloc.free(targetW);
      calloc.free(workW);
      if (hrInit == S_OK || hrInit == 0x00000001 /* S_FALSE */) {
        CoUninitialize();
      }
    }
  }
}
