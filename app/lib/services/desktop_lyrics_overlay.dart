import 'dart:async';
import 'dart:ffi';
import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:ffi/ffi.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:win32/win32.dart';

import 'app_paths.dart';
import 'settings_store.dart';

typedef _WndProcNative = IntPtr Function(IntPtr, Uint32, IntPtr, IntPtr);

/// 桌面歌词悬浮窗（Windows）：
/// - 最顶层、无边框、透明背景（洋红色键，GDI 渲染文字与按钮）
/// - 未锁定：悬停显示边缘、字号 +/-、锁定按钮，可拖动/自由缩放（带最小尺寸）
/// - 锁定：点击穿透，悬停显示解锁按钮
class DesktopLyricsOverlay {
  DesktopLyricsOverlay._();

  static final DesktopLyricsOverlay instance = DesktopLyricsOverlay._();

  static const _className = 'KikoetaLyricsOverlay';
  static const int _minW = 240;
  static const int _minH = 48;
  static const int _edge = 6;

  int _hwnd = 0;
  bool _registered = false;
  bool _visible = false;
  bool _hover = false;
  int _lastPosX = 0x7FFFFFFF;
  int _lastPosY = 0x7FFFFFFF;

  String _text = '';
  double _fontSize = 20;
  int _textColor = 0xFFFFFFFF; // ARGB
  int _outlineColor = 0xFF000000; // ARGB 描边
  double _outlineWidth = 1;
  bool _locked = false;
  String _fontFace = 'Microsoft YaHei';

  ui.Rect _minusRect = ui.Rect.zero;
  ui.Rect _plusRect = ui.Rect.zero;
  ui.Rect _lockRect = ui.Rect.zero;
  ui.Rect _unlockRect = ui.Rect.zero;

  NativeCallable<_WndProcNative>? _wndProc;
  Pointer<Utf16>? _classNamePtr;
  Pointer<Utf16>? _windowTitlePtr;
  Timer? _pump;
  Timer? _hoverPoll;

  // 逐像素 alpha 渲染（UpdateLayeredWindowIndirect）
  int _memDc = 0;
  int _dib = 0;
  Pointer<Uint8>? _bits;
  int _dibW = 0;
  int _dibH = 0;

  // 文字以更高分辨率绘制为灰阶遮罩，再下采样到分层窗口。
  // GDI 直接绘制到透明 DIB 会丢失边缘覆盖率，导致明显锯齿。
  static const _textScale = 3;
  int _textMemDc = 0;
  int _textDib = 0;
  Pointer<Uint8>? _textBits;
  int _textDibW = 0;
  int _textDibH = 0;

  bool get isVisible => _visible;
  String get text => _text;

  static int _proc(int hwnd, int msg, int wParam, int lParam) {
    final overlay = instance;
    switch (msg) {
      case WM_PAINT:
        overlay._render();
        ValidateRect(hwnd, nullptr);
        return 0;
      case WM_SIZE:
        overlay._render();
        return 0;
      case 0x0232: // WM_EXITSIZEMOVE：拖动/缩放结束，记忆窗口状态
        overlay._saveWindowState();
        return 0;
      case WM_WINDOWPOSCHANGING:
        overlay._onPosChanging(lParam);
        return 0;
      case WM_NCHITTEST:
        return overlay._hitTest(hwnd, lParam);
      case WM_LBUTTONDOWN:
        overlay._onClick(hwnd, lParam);
        return 0;
      case WM_GETMINMAXINFO:
        overlay._onMinMax(lParam);
        return 0;
      case WM_DISPLAYCHANGE:
      case WM_MOVE:
        overlay._render();
        return 0;
      case WM_DESTROY:
        return 0;
      default:
        return DefWindowProc(hwnd, msg, wParam, lParam);
    }
  }

  void _ensureWindow() {
    if (_hwnd != 0) return;
    final hInst = GetModuleHandle(nullptr);
    _classNamePtr = _className.toNativeUtf16();
    _windowTitlePtr = 'Kikoeta 桌面歌词'.toNativeUtf16();
    _wndProc = NativeCallable<_WndProcNative>.isolateLocal(
      _proc,
      exceptionalReturn: 0,
    );
    if (!_registered) {
      final wc = calloc<WNDCLASS>();
      wc.ref.style = CS_HREDRAW | CS_VREDRAW;
      wc.ref.lpfnWndProc = _wndProc!.nativeFunction;
      wc.ref.hInstance = hInst;
      wc.ref.hCursor = LoadCursor(0, IDC_ARROW);
      wc.ref.hbrBackground = 0;
      wc.ref.lpszMenuName = nullptr;
      wc.ref.lpszClassName = _classNamePtr!;
      _registered = RegisterClass(wc) != 0;
      calloc.free(wc);
    }

    final screenW = GetSystemMetrics(SM_CXSCREEN);
    final screenH = GetSystemMetrics(SM_CYSCREEN);
    // 记忆并恢复上次的位置与大小
    var w = int.tryParse(SettingsStore.get('lyrics_win_w') ?? '') ?? 460;
    var h = int.tryParse(SettingsStore.get('lyrics_win_h') ?? '') ?? 88;
    w = w.clamp(_minW, screenW);
    h = h.clamp(_minH, screenH);
    var x = int.tryParse(SettingsStore.get('lyrics_win_x') ?? '') ?? 16;
    var y = int.tryParse(SettingsStore.get('lyrics_win_y') ?? '') ?? 16;
    x = x.clamp(0, math.max(0, screenW - w));
    y = y.clamp(0, math.max(0, screenH - h));
    _hwnd = CreateWindowEx(
      WS_EX_LAYERED | WS_EX_TOPMOST | WS_EX_TOOLWINDOW | WS_EX_NOACTIVATE,
      _classNamePtr!,
      _windowTitlePtr!,
      WS_POPUP,
      x,
      y,
      w,
      h,
      0,
      0,
      hInst,
      nullptr,
    );
    if (_hwnd == 0) return;
    _pump = Timer.periodic(
      const Duration(milliseconds: 16),
      (_) => _pumpOnce(),
    );
    _hoverPoll = Timer.periodic(
      const Duration(milliseconds: 100),
      (_) => _pollHover(),
    );
  }

  void _saveWindowState() {
    if (_hwnd == 0) return;
    final rc = calloc<RECT>();
    try {
      GetWindowRect(_hwnd, rc);
      SettingsStore.set('lyrics_win_x', '${rc.ref.left}');
      SettingsStore.set('lyrics_win_y', '${rc.ref.top}');
      SettingsStore.set('lyrics_win_w', '${rc.ref.right - rc.ref.left}');
      SettingsStore.set('lyrics_win_h', '${rc.ref.bottom - rc.ref.top}');
    } finally {
      calloc.free(rc);
    }
  }

  /// 注册内置思源黑体系字体（Sarasa UI SC），供 GDI 渲染使用
  Future<void> init() async {
    if (!Platform.isWindows) return;
    try {
      final data = await rootBundle.load(
        'assets/fonts/sarasa-ui-sc-regular.ttf',
      );
      // 写入应用数据目录（Windows 为 exe 旁 data/，不污染 Temp）
      final dir = await AppPaths.dataDir();
      final tmp = File('$dir${Platform.pathSeparator}kikoeta_sarasa_ui_sc.ttf');
      await tmp.writeAsBytes(
        data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes),
        flush: true,
      );
      final p = tmp.path.toNativeUtf16();
      final added = AddFontResourceEx(p, FR_PRIVATE, nullptr);
      calloc.free(p);
      if (added > 0) {
        _fontFace = 'Sarasa UI SC';
      }
    } catch (_) {
      // 字体加载失败时回退默认字体
    }
  }

  void _pumpOnce() {
    if (_hwnd == 0) return;
    final msg = calloc<MSG>();
    try {
      var n = 0;
      while (PeekMessage(msg, _hwnd, 0, 0, PM_REMOVE) != 0 && n < 50) {
        TranslateMessage(msg);
        DispatchMessage(msg);
        n++;
      }
    } finally {
      calloc.free(msg);
    }
  }

  void _pollHover() {
    if (_hwnd == 0) return;
    final pt = calloc<POINT>();
    final rc = calloc<RECT>();
    try {
      GetCursorPos(pt);
      GetWindowRect(_hwnd, rc);
      final inside =
          pt.ref.x >= rc.ref.left &&
          pt.ref.x <= rc.ref.right &&
          pt.ref.y >= rc.ref.top &&
          pt.ref.y <= rc.ref.bottom;
      if (inside != _hover) {
        _hover = inside;
        _render();
      }
    } finally {
      calloc.free(pt);
      calloc.free(rc);
    }
  }

  int _hitTest(int hwnd, int lParam) {
    final x = (lParam & 0xFFFF).toSigned(16);
    final y = ((lParam >> 16) & 0xFFFF).toSigned(16);
    final rc = calloc<RECT>();
    try {
      GetWindowRect(hwnd, rc);
      final cx = x - rc.ref.left;
      final cy = y - rc.ref.top;
      final cw = rc.ref.right - rc.ref.left;
      final ch = rc.ref.bottom - rc.ref.top;

      if (_locked) {
        if (_hover &&
            _unlockRect.width > 0 &&
            _unlockRect.contains(ui.Offset(cx.toDouble(), cy.toDouble()))) {
          return HTCLIENT;
        }
        return HTTRANSPARENT;
      }

      if (!_hover) return HTCLIENT;
      final left = cx <= _edge;
      final right = cx >= cw - _edge;
      final top = cy <= _edge;
      final bottom = cy >= ch - _edge;
      if (top && left) return HTTOPLEFT;
      if (top && right) return HTTOPRIGHT;
      if (bottom && left) return HTBOTTOMLEFT;
      if (bottom && right) return HTBOTTOMRIGHT;
      if (left) return HTLEFT;
      if (right) return HTRIGHT;
      if (top) return HTTOP;
      if (bottom) return HTBOTTOM;
      if (_minusRect.contains(ui.Offset(cx.toDouble(), cy.toDouble())) ||
          _plusRect.contains(ui.Offset(cx.toDouble(), cy.toDouble())) ||
          _lockRect.contains(ui.Offset(cx.toDouble(), cy.toDouble()))) {
        return HTCLIENT;
      }
      return HTCAPTION;
    } finally {
      calloc.free(rc);
    }
  }

  void _onClick(int hwnd, int lParam) {
    final x = (lParam & 0xFFFF).toSigned(16);
    final y = ((lParam >> 16) & 0xFFFF).toSigned(16);
    final pt = ui.Offset(x.toDouble(), y.toDouble());
    if (_locked) {
      if (_unlockRect.contains(pt)) {
        _locked = false;
        _syncLockCallback?.call(false);
        _render();
      }
      return;
    }
    if (_minusRect.contains(pt)) {
      _syncFontSizeCallback?.call(_fontSize - 2);
    } else if (_plusRect.contains(pt)) {
      _syncFontSizeCallback?.call(_fontSize + 2);
    } else if (_lockRect.contains(pt)) {
      _locked = true;
      _syncLockCallback?.call(true);
      _render();
    }
  }

  void _onMinMax(int lParam) {
    final mm = Pointer<MINMAXINFO>.fromAddress(lParam);
    mm.ref.ptMinTrackSize.x = _minW;
    mm.ref.ptMinTrackSize.y = _minH;
  }

  /// 拖动时吸附屏幕工作区边缘（约 6px）。
  /// 只向边缘方向移动时吸附；反向拖动立即释放，不会“吸住拖很远”。
  void _onPosChanging(int lParam) {
    const snap = 6;
    final wp = Pointer<WINDOWPOS>.fromAddress(lParam);
    if ((wp.ref.flags & SWP_NOMOVE) != 0) return;
    final w = wp.ref.cx;
    final h = wp.ref.cy;
    final work = calloc<RECT>();
    try {
      SystemParametersInfo(SPI_GETWORKAREA, 0, work, 0);
      final left = work.ref.left;
      final top = work.ref.top;
      final right = work.ref.right;
      final bottom = work.ref.bottom;
      if (_lastPosX != 0x7FFFFFFF) {
        final towardLeft = wp.ref.x < left + snap && wp.ref.x <= _lastPosX;
        final towardRight =
            wp.ref.x + w > right - snap && wp.ref.x >= _lastPosX;
        if (towardLeft) {
          wp.ref.x = left;
        } else if (towardRight) {
          wp.ref.x = right - w;
        }
        final towardTop = wp.ref.y < top + snap && wp.ref.y <= _lastPosY;
        final towardBottom =
            wp.ref.y + h > bottom - snap && wp.ref.y >= _lastPosY;
        if (towardTop) {
          wp.ref.y = top;
        } else if (towardBottom) {
          wp.ref.y = bottom - h;
        }
      }
      _lastPosX = wp.ref.x;
      _lastPosY = wp.ref.y;
    } finally {
      calloc.free(work);
    }
  }

  void _render() {
    if (_hwnd == 0) return;
    final rc = calloc<RECT>();
    try {
      GetClientRect(_hwnd, rc);
      final w = rc.ref.right - rc.ref.left;
      final h = rc.ref.bottom - rc.ref.top;
      if (w <= 0 || h <= 0) return;
      _ensureTarget(w, h);
      final bits = _bits;
      if (bits == null || _dib == 0) return;
      final n = w * h;

      // 1) 清屏为哨兵值（alpha=0, RGB=1,1,1）
      for (var i = 0; i < n; i++) {
        final p = i * 4;
        bits[p] = 1;
        bits[p + 1] = 1;
        bits[p + 2] = 1;
        bits[p + 3] = 0;
      }

      // 2) 仅解锁状态悬停时显示 25% 半透明黑圆角背景（alpha=64）
      if (!_locked && _hover) {
        _fillRounded(0, 0, w, h, 12, 64, 0, 0, 0);
      }

      // 3) 按钮背景（半透明灰）并更新命中区
      _drawButtonBgs(w, h);

      // 4) 高分辨率文字遮罩保留边缘覆盖率，避免分层窗口中的锯齿。
      _drawText(w, h);

      if (_locked) {
        if (_hover) _drawSvgIcon(_unlockRect, 'unlock');
      } else if (_hover) {
        _drawSvgIcon(_minusRect, 'minus');
        _drawSvgIcon(_plusRect, 'plus');
        _drawSvgIcon(_lockRect, 'lock');
      }

      // 5) 提交到分层窗口
      _updateLayered(w, h);
    } finally {
      calloc.free(rc);
    }
  }

  void _ensureTarget(int w, int h) {
    if (_memDc != 0 && _dib != 0 && _dibW == w && _dibH == h) return;
    _freeTarget();
    _memDc = CreateCompatibleDC(0);
    final bmi = calloc<BITMAPINFO>();
    try {
      bmi.ref.bmiHeader.biSize = sizeOf<BITMAPINFOHEADER>();
      bmi.ref.bmiHeader.biWidth = w;
      bmi.ref.bmiHeader.biHeight = h;
      bmi.ref.bmiHeader.biPlanes = 1;
      bmi.ref.bmiHeader.biBitCount = 32;
      bmi.ref.bmiHeader.biCompression = 0;
      final ppv = calloc<Pointer<Uint8>>();
      try {
        _dib = CreateDIBSection(
          _memDc,
          bmi,
          DIB_RGB_COLORS,
          ppv.cast<Pointer>(),
          0,
          0,
        );
        _bits = ppv.value;
      } finally {
        calloc.free(ppv);
      }
      if (_dib != 0) SelectObject(_memDc, _dib);
      _dibW = w;
      _dibH = h;
    } finally {
      calloc.free(bmi);
    }
  }

  void _freeTarget() {
    if (_dib != 0) {
      DeleteObject(_dib);
      _dib = 0;
    }
    if (_memDc != 0) {
      DeleteDC(_memDc);
      _memDc = 0;
    }
    _bits = null;
    _dibW = 0;
    _dibH = 0;
  }

  void _ensureTextTarget(int w, int h) {
    final scaledW = w * _textScale;
    final scaledH = h * _textScale;
    if (_textMemDc != 0 &&
        _textDib != 0 &&
        _textDibW == scaledW &&
        _textDibH == scaledH) {
      return;
    }
    _freeTextTarget();
    _textMemDc = CreateCompatibleDC(0);
    final bmi = calloc<BITMAPINFO>();
    try {
      bmi.ref.bmiHeader.biSize = sizeOf<BITMAPINFOHEADER>();
      bmi.ref.bmiHeader.biWidth = scaledW;
      bmi.ref.bmiHeader.biHeight = scaledH;
      bmi.ref.bmiHeader.biPlanes = 1;
      bmi.ref.bmiHeader.biBitCount = 32;
      bmi.ref.bmiHeader.biCompression = 0;
      final ppv = calloc<Pointer<Uint8>>();
      try {
        _textDib = CreateDIBSection(
          _textMemDc,
          bmi,
          DIB_RGB_COLORS,
          ppv.cast<Pointer>(),
          0,
          0,
        );
        _textBits = ppv.value;
      } finally {
        calloc.free(ppv);
      }
      if (_textDib != 0) SelectObject(_textMemDc, _textDib);
      _textDibW = scaledW;
      _textDibH = scaledH;
    } finally {
      calloc.free(bmi);
    }
  }

  void _freeTextTarget() {
    if (_textDib != 0) {
      DeleteObject(_textDib);
      _textDib = 0;
    }
    if (_textMemDc != 0) {
      DeleteDC(_textMemDc);
      _textMemDc = 0;
    }
    _textBits = null;
    _textDibW = 0;
    _textDibH = 0;
  }

  void _drawText(int w, int h) {
    _ensureTextTarget(w, h);
    final mask = _textBits;
    if (mask == null || _textDib == 0) return;
    final n = _textDibW * _textDibH;
    for (var i = 0; i < n * 4; i++) {
      mask[i] = 0;
    }

    final lf = calloc<LOGFONT>();
    final textPtr = (_text.isEmpty ? '暂无歌词' : _text).toNativeUtf16();
    try {
      final dpi = GetDeviceCaps(_textMemDc, LOGPIXELSY);
      lf.ref.lfHeight = -((_fontSize * _textScale * dpi / 72).round());
      lf.ref.lfWeight = 400;
      lf.ref.lfQuality = ANTIALIASED_QUALITY;
      lf.ref.lfFaceName = _fontFace;
      final font = CreateFontIndirect(lf);
      final oldFont = SelectObject(_textMemDc, font);
      try {
        SetBkMode(_textMemDc, TRANSPARENT);
        SetTextColor(_textMemDc, 0x00FFFFFF);
        final rect = calloc<RECT>();
        try {
          rect.ref.left = 8 * _textScale;
          rect.ref.top = 4 * _textScale;
          rect.ref.right = (w - 8) * _textScale;
          rect.ref.bottom = (h - 4) * _textScale;
          final ow = (_outlineWidth * _textScale).round();
          if (ow > 0) {
            for (var dy = -ow; dy <= ow; dy++) {
              for (var dx = -ow; dx <= ow; dx++) {
                if (dx == 0 && dy == 0) continue;
                final shifted = calloc<RECT>();
                try {
                  shifted.ref.left = rect.ref.left + dx;
                  shifted.ref.top = rect.ref.top + dy;
                  shifted.ref.right = rect.ref.right + dx;
                  shifted.ref.bottom = rect.ref.bottom + dy;
                  DrawText(
                    _textMemDc,
                    textPtr,
                    -1,
                    shifted,
                    DT_CENTER | DT_VCENTER | DT_SINGLELINE | DT_NOPREFIX,
                  );
                } finally {
                  calloc.free(shifted);
                }
              }
            }
            _blendTextMask(w, h, _outlineColor);
          }

          for (var i = 0; i < n * 4; i++) {
            mask[i] = 0;
          }
          DrawText(
            _textMemDc,
            textPtr,
            -1,
            rect,
            DT_CENTER | DT_VCENTER | DT_SINGLELINE | DT_NOPREFIX,
          );
          _blendTextMask(w, h, _textColor);
        } finally {
          calloc.free(rect);
        }
      } finally {
        SelectObject(_textMemDc, oldFont);
        DeleteObject(font);
      }
    } finally {
      calloc.free(lf);
      calloc.free(textPtr);
    }
  }

  void _blendTextMask(int w, int h, int color) {
    final mask = _textBits;
    if (mask == null) return;
    final sourceAlpha = (color >> 24) & 0xFF;
    if (sourceAlpha == 0) return;
    final r = (color >> 16) & 0xFF;
    final g = (color >> 8) & 0xFF;
    final b = color & 0xFF;
    final samples = _textScale * _textScale;
    for (var y = 0; y < h; y++) {
      for (var x = 0; x < w; x++) {
        var coverage = 0;
        for (var sy = 0; sy < _textScale; sy++) {
          final row = (_textDibH - 1 - (y * _textScale + sy)) * _textDibW;
          for (var sx = 0; sx < _textScale; sx++) {
            // 遮罩为白色，任一 RGB 分量均代表 GDI 的灰阶覆盖率。
            coverage += mask[(row + x * _textScale + sx) * 4];
          }
        }
        final alpha = (coverage * sourceAlpha / (255 * samples)).round();
        if (alpha > 0) _blendPx(x, y, alpha, r, g, b);
      }
    }
  }

  void _setPx(int x, int y, int a, int r, int g, int b) {
    final bits = _bits;
    if (bits == null || x < 0 || y < 0 || x >= _dibW || y >= _dibH) return;
    final i = ((_dibH - 1 - y) * _dibW + x) * 4;
    bits[i] = b;
    bits[i + 1] = g;
    bits[i + 2] = r;
    bits[i + 3] = a;
  }

  void _fillRounded(
    int x0,
    int y0,
    int x1,
    int y1,
    int radius,
    int a,
    int r,
    int g,
    int b,
  ) {
    for (var y = y0; y < y1; y++) {
      for (var x = x0; x < x1; x++) {
        if (_inRounded(x, y, x0, y0, x1, y1, radius)) {
          _setPx(x, y, a, r, g, b);
        }
      }
    }
  }

  bool _inRounded(int x, int y, int x0, int y0, int x1, int y1, int radius) {
    final dx = x < x0 + radius
        ? x0 + radius - x
        : (x >= x1 - radius ? x - (x1 - radius - 1) : 0);
    final dy = y < y0 + radius
        ? y0 + radius - y
        : (y >= y1 - radius ? y - (y1 - radius - 1) : 0);
    if (dx <= 0 || dy <= 0) return true;
    return dx * dx + dy * dy <= radius * radius;
  }

  void _drawButtonBgs(int w, int h) {
    const bs = 24;
    const gap = 6;
    const top = 4;
    _minusRect = ui.Rect.zero;
    _plusRect = ui.Rect.zero;
    _lockRect = ui.Rect.zero;
    _unlockRect = ui.Rect.zero;
    if (_locked) {
      // 锁定态：仅悬停时在顶部居中显示解锁按钮
      if (_hover) {
        final r = ui.Rect.fromLTWH(
          ((w - bs) / 2).toDouble(),
          top.toDouble(),
          bs.toDouble(),
          bs.toDouble(),
        );
        _unlockRect = r;
        _fillRounded(
          r.left.round(),
          r.top.round(),
          r.right.round(),
          r.bottom.round(),
          5,
          102,
          51,
          51,
          51,
        );
      }
    } else if (_hover) {
      // 解锁态悬停：顶部居中显示 减号 / 加号 / 锁定
      final total = bs * 3 + gap * 2;
      var x = (w - total) / 2;
      final minus = ui.Rect.fromLTWH(
        x.toDouble(),
        top.toDouble(),
        bs.toDouble(),
        bs.toDouble(),
      );
      x += bs + gap;
      final plus = ui.Rect.fromLTWH(
        x.toDouble(),
        top.toDouble(),
        bs.toDouble(),
        bs.toDouble(),
      );
      x += bs + gap;
      final lock = ui.Rect.fromLTWH(
        x.toDouble(),
        top.toDouble(),
        bs.toDouble(),
        bs.toDouble(),
      );
      _minusRect = minus;
      _plusRect = plus;
      _lockRect = lock;
      for (final r in [minus, plus, lock]) {
        _fillRounded(
          r.left.round(),
          r.top.round(),
          r.right.round(),
          r.bottom.round(),
          5,
          102,
          51,
          51,
          51,
        );
      }
    }
  }

  void _updateLayered(int w, int h) {
    final screenDc = GetDC(0);
    final rc = calloc<RECT>();
    final ptDst = calloc<POINT>();
    final size = calloc<SIZE>();
    final ptSrc = calloc<POINT>();
    final blend = calloc<BLENDFUNCTION>();
    final info = calloc<UPDATELAYEREDWINDOWINFO>();
    try {
      GetWindowRect(_hwnd, rc);
      ptDst.ref.x = rc.ref.left;
      ptDst.ref.y = rc.ref.top;
      size.ref.cx = w;
      size.ref.cy = h;
      ptSrc.ref.x = 0;
      ptSrc.ref.y = 0;
      blend.ref.BlendOp = 0; // AC_SRC_OVER
      blend.ref.BlendFlags = 0;
      blend.ref.SourceConstantAlpha = 255;
      blend.ref.AlphaFormat = 1; // AC_SRC_ALPHA
      info.ref.cbSize = sizeOf<UPDATELAYEREDWINDOWINFO>();
      info.ref.hdcDst = screenDc;
      info.ref.pptDst = ptDst;
      info.ref.psize = size;
      info.ref.hdcSrc = _memDc;
      info.ref.pptSrc = ptSrc;
      info.ref.crKey = 0;
      info.ref.pblend = blend;
      info.ref.dwFlags = ULW_ALPHA;
      info.ref.prcDirty = nullptr;
      UpdateLayeredWindowIndirect(_hwnd, info);
    } finally {
      ReleaseDC(0, screenDc);
      calloc.free(rc);
      calloc.free(ptDst);
      calloc.free(size);
      calloc.free(ptSrc);
      calloc.free(blend);
      calloc.free(info);
    }
  }

  /// 直接使用参考 SVG 的路径数据光栅化图标（抗锯齿描边）
  void _drawSvgIcon(ui.Rect r, String kind) {
    List<List<ui.Offset>> paths;
    switch (kind) {
      case 'minus':
        paths = _parsePath('M10.5 24L38.5 24');
        break;
      case 'plus':
        paths = _parsePath('M24.0605 10L24.0239 38M10 24L38 24');
        break;
      case 'lock':
        paths = [
          _roundedRect(6, 22, 42, 44, 2),
          ..._parsePath(
            'M14 22V14C14 8.47715 18.4772 4 24 4C29.5228 4 34 8.47715 34 14V22',
          ),
          ..._parsePath('M24 30V36'),
        ];
        break;
      case 'unlock':
        paths = [
          _roundedRect(7, 22.0476, 41, 44.0476, 2),
          ..._parsePath(
            'M14 22V14.0047C13.9948 8.87022 17.9227 4.56718 23.0859 4.05117C28.249 3.53516 32.9673 6.97408 34 12.0059',
          ),
          ..._parsePath('M24 30V36'),
        ];
        break;
      default:
        return;
    }

    // 原版 16px SVG：48 viewBox 按 1/3 缩放，居中于按钮，仅调整描边颜色为白色
    final scale = 16 / 48;
    final tx = r.center.dx;
    final ty = r.center.dy;
    final w = math.max(1.5, 4 * scale);
    ui.Offset tr(ui.Offset p) =>
        ui.Offset(tx + (p.dx - 24) * scale, ty + (p.dy - 24) * scale);

    for (final pl in paths) {
      for (var i = 1; i < pl.length; i++) {
        _drawThickSegment(tr(pl[i - 1]), tr(pl[i]), w);
      }
    }
  }

  void _drawThickSegment(ui.Offset a, ui.Offset b, double w) {
    final r2 = w / 2 + 1;
    final minX = (math.min(a.dx, b.dx) - r2).floor();
    final maxX = (math.max(a.dx, b.dx) + r2).ceil();
    final minY = (math.min(a.dy, b.dy) - r2).floor();
    final maxY = (math.max(a.dy, b.dy) + r2).ceil();
    for (var y = minY; y <= maxY; y++) {
      for (var x = minX; x <= maxX; x++) {
        final d = _segDist(x + 0.5, y + 0.5, a.dx, a.dy, b.dx, b.dy);
        final cover = w / 2 + 0.5 - d;
        if (cover <= 0) continue;
        final alpha = cover >= 1 ? 255 : (cover * 255).round();
        _blendPx(x, y, alpha, 255, 255, 255);
      }
    }
  }

  double _segDist(
    double px,
    double py,
    double x0,
    double y0,
    double x1,
    double y1,
  ) {
    final vx = x1 - x0;
    final vy = y1 - y0;
    final wx = px - x0;
    final wy = py - y0;
    final c1 = vx * wx + vy * wy;
    if (c1 <= 0) return math.sqrt(wx * wx + wy * wy);
    final c2 = vx * vx + vy * vy;
    if (c2 <= c1) {
      final ex = px - x1;
      final ey = py - y1;
      return math.sqrt(ex * ex + ey * ey);
    }
    final t = c1 / c2;
    final dx = px - (x0 + t * vx);
    final dy = py - (y0 + t * vy);
    return math.sqrt(dx * dx + dy * dy);
  }

  void _blendPx(int x, int y, int a, int r, int g, int b) {
    final bits = _bits;
    if (bits == null || x < 0 || y < 0 || x >= _dibW || y >= _dibH || a <= 0) {
      return;
    }
    final i = ((_dibH - 1 - y) * _dibW + x) * 4;
    final da = bits[i + 3];
    if (a >= 255) {
      bits[i] = b;
      bits[i + 1] = g;
      bits[i + 2] = r;
      bits[i + 3] = 255;
      return;
    }
    final outA = a + da * (255 - a) ~/ 255;
    if (outA == 0) return;
    final db = bits[i];
    final dg = bits[i + 1];
    final dr = bits[i + 2];
    final nr = (r * a + dr * da * (255 - a) ~/ 255) ~/ outA;
    final ng = (g * a + dg * da * (255 - a) ~/ 255) ~/ outA;
    final nb = (b * a + db * da * (255 - a) ~/ 255) ~/ outA;
    bits[i] = nb;
    bits[i + 1] = ng;
    bits[i + 2] = nr;
    bits[i + 3] = outA;
  }

  List<List<ui.Offset>> _parsePath(String d) {
    final out = <List<ui.Offset>>[];
    final numRe = RegExp(r'-?\d+\.?\d*');
    var idx = 0;
    var cmd = '';
    var x = 0.0;
    var y = 0.0;
    var cur = <ui.Offset>[];

    double nextNum() {
      while (idx < d.length) {
        final m = numRe.matchAsPrefix(d, idx);
        if (m != null) {
          idx = m.end;
          return double.parse(m.group(0)!);
        }
        idx++;
      }
      return 0;
    }

    void closePoly() {
      if (cur.length > 1) out.add(List.of(cur));
      cur = [];
    }

    while (idx < d.length) {
      final c = d[idx];
      if (RegExp(r'[MmLlHhVvCcZz]').hasMatch(c)) {
        cmd = c;
        idx++;
        continue;
      }
      if (!RegExp(r'[-0-9.]').hasMatch(c)) {
        idx++;
        continue;
      }
      switch (cmd) {
        case 'M':
        case 'm':
          x = nextNum();
          y = nextNum();
          closePoly();
          cur = [ui.Offset(x, y)];
          break;
        case 'L':
        case 'l':
          x = nextNum();
          y = nextNum();
          cur.add(ui.Offset(x, y));
          break;
        case 'H':
        case 'h':
          x = nextNum();
          cur.add(ui.Offset(x, y));
          break;
        case 'V':
        case 'v':
          y = nextNum();
          cur.add(ui.Offset(x, y));
          break;
        case 'C':
        case 'c':
          {
            final c1x = nextNum();
            final c1y = nextNum();
            final c2x = nextNum();
            final c2y = nextNum();
            final ex = nextNum();
            final ey = nextNum();
            _sampleCubic(cur, x, y, c1x, c1y, c2x, c2y, ex, ey);
            x = ex;
            y = ey;
            break;
          }
        case 'Z':
        case 'z':
          closePoly();
          break;
      }
    }
    closePoly();
    return out;
  }

  void _sampleCubic(
    List<ui.Offset> pts,
    double x0,
    double y0,
    double c1x,
    double c1y,
    double c2x,
    double c2y,
    double x1,
    double y1,
  ) {
    const steps = 24;
    for (var i = 1; i <= steps; i++) {
      final t = i / steps;
      final u = 1 - t;
      final x =
          u * u * u * x0 +
          3 * u * u * t * c1x +
          3 * u * t * t * c2x +
          t * t * t * x1;
      final y =
          u * u * u * y0 +
          3 * u * u * t * c1y +
          3 * u * t * t * c2y +
          t * t * t * y1;
      pts.add(ui.Offset(x, y));
    }
  }

  List<ui.Offset> _roundedRect(
    double x0,
    double y0,
    double x1,
    double y1,
    double radius,
  ) {
    final r = math.min(radius, math.min((x1 - x0) / 2, (y1 - y0) / 2));
    final pts = <ui.Offset>[];
    void arc(double cx, double cy, double a0, double a1) {
      const n = 8;
      for (var k = 1; k <= n; k++) {
        final t = a0 + (a1 - a0) * k / n;
        pts.add(ui.Offset(cx + r * math.cos(t), cy + r * math.sin(t)));
      }
    }

    pts.add(ui.Offset(x0 + r, y0));
    pts.add(ui.Offset(x1 - r, y0));
    arc(x1 - r, y0 + r, -math.pi / 2, 0);
    pts.add(ui.Offset(x1, y1 - r));
    arc(x1 - r, y1 - r, 0, math.pi / 2);
    pts.add(ui.Offset(x0 + r, y1));
    arc(x0 + r, y1 - r, math.pi / 2, math.pi);
    pts.add(ui.Offset(x0, y0 + r));
    arc(x0 + r, y0 + r, math.pi, math.pi * 3 / 2);
    return pts;
  }

  // ---------- 对外接口 ----------

  void Function(bool locked)? _syncLockCallback;
  void Function(double size)? _syncFontSizeCallback;

  void bind({
    required void Function(bool locked) onLockChanged,
    required void Function(double size) onFontSizeChanged,
  }) {
    _syncLockCallback = onLockChanged;
    _syncFontSizeCallback = onFontSizeChanged;
  }

  void show({
    required String text,
    required double fontSize,
    required int color,
    required int outlineColor,
    required double outlineWidth,
    required bool locked,
  }) {
    if (!Platform.isWindows) return;
    _ensureWindow();
    _text = text;
    _fontSize = fontSize;
    _textColor = color;
    _outlineColor = outlineColor;
    _outlineWidth = outlineWidth;
    _locked = locked;
    if (!_visible && _hwnd != 0) {
      ShowWindow(_hwnd, SW_SHOWNOACTIVATE);
      _visible = true;
    }
    _render();
  }

  void update(String text) {
    if (!_visible) return;
    if (text == _text) return;
    _text = text;
    _render();
  }

  void setStyle({
    required double fontSize,
    required int color,
    required int outlineColor,
    required double outlineWidth,
  }) {
    _fontSize = fontSize;
    _textColor = color;
    _outlineColor = outlineColor;
    _outlineWidth = outlineWidth;
    _render();
  }

  void setLocked(bool locked) {
    if (_locked == locked) return;
    _locked = locked;
    _render();
  }

  void hide() {
    if (!_visible) return;
    _visible = false;
    if (_hwnd != 0) ShowWindow(_hwnd, SW_HIDE);
  }

  void dispose() {
    _pump?.cancel();
    _hoverPoll?.cancel();
    _freeTarget();
    _freeTextTarget();
    if (_hwnd != 0) {
      DestroyWindow(_hwnd);
      _hwnd = 0;
    }
    _wndProc?.close();
    _wndProc = null;
    _classNamePtr = null;
    _windowTitlePtr = null;
  }
}
