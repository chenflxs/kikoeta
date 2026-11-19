import 'package:flutter/services.dart';

/// A Windows global shortcut, stored independently of the player-page keys.
class DesktopLyricsShortcut {
  static const settingKey = 'desktop_lyrics_shortcut';
  static const defaultSetting = '3:107';
  static const defaultValue = DesktopLyricsShortcut._(
    LogicalKeyboardKey.keyK,
    _control | _alt,
  );

  // Win32 RegisterHotKey modifier flags.
  static const _alt = 1;
  static const _control = 2;
  static const _shift = 4;

  final LogicalKeyboardKey key;
  final int modifiers;
  const DesktopLyricsShortcut._(this.key, this.modifiers);

  bool get control => (modifiers & _control) != 0;
  bool get alt => (modifiers & _alt) != 0;
  bool get shift => (modifiers & _shift) != 0;
  int get virtualKey => _virtualKey(key)!;

  String encode() => '$modifiers:${key.keyId}';

  static DesktopLyricsShortcut? decode(String? value) {
    final parts = value?.split(':');
    if (parts == null || parts.length != 2) return null;
    final modifiers = int.tryParse(parts.first);
    final keyId = int.tryParse(parts.last);
    if (modifiers == null || keyId == null) return null;
    final key = LogicalKeyboardKey.findKeyByKeyId(keyId);
    return key == null ? null : _create(key, modifiers);
  }

  static DesktopLyricsShortcut? fromKey(
    LogicalKeyboardKey key, {
    required bool control,
    required bool alt,
    required bool shift,
  }) => _create(
    key,
    (control ? _control : 0) | (alt ? _alt : 0) | (shift ? _shift : 0),
  );

  static DesktopLyricsShortcut? _create(LogicalKeyboardKey key, int modifiers) {
    if ((modifiers & ~(_control | _alt | _shift)) != 0 ||
        (modifiers & (_control | _alt)) == 0 ||
        _virtualKey(key) == null) {
      return null;
    }
    return DesktopLyricsShortcut._(key, modifiers);
  }

  static int? _virtualKey(LogicalKeyboardKey key) {
    final id = key.keyId;
    if (id >= 0x61 && id <= 0x7A) return id - 0x20;
    if (id >= 0x30 && id <= 0x39) return id;
    // Windows reserves F12 for the debugger.
    if (id >= LogicalKeyboardKey.f1.keyId &&
        id <= LogicalKeyboardKey.f24.keyId &&
        key != LogicalKeyboardKey.f12) {
      return 0x70 + id - LogicalKeyboardKey.f1.keyId;
    }
    return switch (key) {
      LogicalKeyboardKey.backspace => 0x08,
      LogicalKeyboardKey.tab => 0x09,
      LogicalKeyboardKey.enter => 0x0D,
      LogicalKeyboardKey.space => 0x20,
      LogicalKeyboardKey.pageUp => 0x21,
      LogicalKeyboardKey.pageDown => 0x22,
      LogicalKeyboardKey.end => 0x23,
      LogicalKeyboardKey.home => 0x24,
      LogicalKeyboardKey.arrowLeft => 0x25,
      LogicalKeyboardKey.arrowUp => 0x26,
      LogicalKeyboardKey.arrowRight => 0x27,
      LogicalKeyboardKey.arrowDown => 0x28,
      LogicalKeyboardKey.insert => 0x2D,
      LogicalKeyboardKey.delete => 0x2E,
      _ => null,
    };
  }

  @override
  bool operator ==(Object other) =>
      other is DesktopLyricsShortcut &&
      key == other.key &&
      modifiers == other.modifiers;

  @override
  int get hashCode => Object.hash(key, modifiers);
}
