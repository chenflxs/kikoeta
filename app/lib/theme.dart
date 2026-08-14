import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// 与 HTML demo 一致的蓝色系配色
class AppColors {
  AppColors._();

  static const dark = Palette(
    bg: Color(0xFF0B0E15),
    bg2: Color(0xFF10141F),
    surface: Color(0xFF131826),
    surface2: Color(0xFF1A2133),
    surface3: Color(0xFF232C44),
    track: Color(0xFF3A4A6E),
    text: Color(0xFFE9EEFB),
    muted: Color(0xFF9DB0D4),
    dim: Color(0xFF6C7EA3),
    accent: Color(0xFF4F8EF7),
    accent2: Color(0xFF3B6FE0),
    green: Color(0xFF3ECF9A),
    orange: Color(0xFFF0B44C),
    red: Color(0xFFEF6B7C),
    line: Color(0x22000000),
    tabbar: Color(0xE60B0E15),
    mini: Color(0xF7131826),
    toast: Color(0xF7181F30),
    border: Color(0xFF242E46),
    stageTop: Color(0xFF18233D),
    stageBottom: Color(0xFF0A0D15),
  );

  static const light = Palette(
    bg: Color(0xFFF2F5FB),
    bg2: Color(0xFFE9EEF8),
    surface: Color(0xFFFFFFFF),
    surface2: Color(0xFFEEF2FA),
    surface3: Color(0xFFDCE5F2),
    track: Color(0xFFB7C4DC),
    text: Color(0xFF17233D),
    muted: Color(0xFF5D6F96),
    dim: Color(0xFF8A97B8),
    accent: Color(0xFF2F6FE4),
    accent2: Color(0xFF4F46E5),
    green: Color(0xFF0EA371),
    orange: Color(0xFFC07E12),
    red: Color(0xFFD6455A),
    line: Color(0x1A17233D),
    tabbar: Color(0xF0FFFFFF),
    mini: Color(0xFAFFFFFF),
    toast: Color(0xFFFFFFFF),
    border: Color(0xFFD5DDED),
    stageTop: Color(0xFFDFE7F7),
    stageBottom: Color(0xFFEEF1F8),
  );
}

class Palette {
  const Palette({
    required this.bg,
    required this.bg2,
    required this.surface,
    required this.surface2,
    required this.surface3,
    required this.track,
    required this.text,
    required this.muted,
    required this.dim,
    required this.accent,
    required this.accent2,
    required this.green,
    required this.orange,
    required this.red,
    required this.line,
    required this.tabbar,
    required this.mini,
    required this.toast,
    required this.border,
    required this.stageTop,
    required this.stageBottom,
  });

  final Color bg;
  final Color bg2;
  final Color surface;
  final Color surface2;
  final Color surface3;
  final Color track; // 进度条未播放段颜色
  final Color text;
  final Color muted;
  final Color dim;
  final Color accent;
  final Color accent2;
  final Color green;
  final Color orange;
  final Color red;
  final Color line;
  final Color tabbar;
  final Color mini;
  final Color toast;
  final Color border;
  final Color stageTop;
  final Color stageBottom;
}

ThemeData buildTheme(Brightness brightness) {
  final p = brightness == Brightness.dark ? AppColors.dark : AppColors.light;
  final scheme = ColorScheme.fromSeed(
    seedColor: p.accent,
    brightness: brightness,
    primary: p.accent,
    secondary: p.accent2,
    surface: p.surface,
  );
  return ThemeData(
    useMaterial3: true,
    brightness: brightness,
    colorScheme: scheme,
    scaffoldBackgroundColor: p.bg,
    fontFamily: 'SarasaUI',
    appBarTheme: AppBarTheme(
      backgroundColor: p.bg,
      foregroundColor: p.text,
      elevation: 0,
      centerTitle: true,
      systemOverlayStyle: SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: brightness == Brightness.dark
            ? Brightness.light
            : Brightness.dark,
        statusBarBrightness: brightness == Brightness.dark
            ? Brightness.dark
            : Brightness.light,
      ),
    ),
    splashFactory: InkSparkle.splashFactory,
    dividerColor: p.line,
    textTheme: const TextTheme(
      titleLarge: TextStyle(fontWeight: FontWeight.w800, letterSpacing: .2),
      bodyMedium: TextStyle(height: 1.4),
    ),
    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: p.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
    ),
    popupMenuTheme: PopupMenuThemeData(
      color: p.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 16,
      textStyle: TextStyle(color: p.muted, fontSize: 13),
    ),
  );
}
