import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../data.dart';
import '../services/android_battery.dart';
import '../services/android_lyrics_overlay.dart';
import '../services/api_service.dart';
import '../services/desktop_lyrics_overlay.dart';
import '../services/player_service.dart';
import '../services/update_service.dart';
import '../src/rust/api/translate.dart';
import '../sheets.dart';
import '../theme.dart';
import '../widgets.dart';

class SettingsPage extends StatefulWidget {
  final AppState app;
  const SettingsPage({super.key, required this.app});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  static const _lyricsColors = [
    0xFF000000,
    0xFFFFFFFF,
    0xFFFFEB3B,
    0xFF00E5FF,
    0xFFFF4081,
    0xFF76FF03,
    0xFFFFA726,
  ];

  final Map<String, String> _health = {};
  final Map<String, String> _loginStatus = {};
  // 电池优化白名单状态（仅安卓）：true=已关闭省电优化 / false=未关闭 / null=未知或非安卓
  bool? _batteryIgnoring;
  // 版本号彩蛋：连续点击计数（前 3 次静默，超过 3 秒未点击则重置）
  int _devTaps = 0;
  Timer? _devTimer;
  late final TextEditingController _aiBase;
  late final TextEditingController _aiModel;
  final MenuController _aiModelMenu = MenuController();
  late final TextEditingController _aiKey;
  late final TextEditingController _deeplKey;
  late final TextEditingController _colorHexCtrl;
  late final TextEditingController _outlineHexCtrl;
  late final TextEditingController _proxyCtrl;

  AppState get app => widget.app;

  @override
  void initState() {
    super.initState();
    // 设置页大量控件直接渲染 AppState 字段（开关、分段按钮等），
    // 自行监听以在状态变化时刷新（此前依赖根级全树重建）
    app.addListener(_onAppChanged);
    _aiBase = TextEditingController(text: app.aiConfig['base']);
    _aiModel = TextEditingController(text: app.aiConfig['model']);
    _aiKey = TextEditingController(text: app.aiConfig['key']);
    _deeplKey = TextEditingController(text: app.deeplKey);
    _colorHexCtrl = TextEditingController(text: _toHex(app.lyricsColor));
    _outlineHexCtrl = TextEditingController(
      text: _toHex(app.lyricsOutlineColor),
    );
    _proxyCtrl = TextEditingController(text: app.httpProxyUrl);
    if (Platform.isAndroid) {
      AndroidBattery.instance.isIgnoring().then((v) {
        if (mounted) setState(() => _batteryIgnoring = v);
      });
    }
    WidgetsBinding.instance.addPostFrameCallback((_) => _autoCheckAll());
  }

  @override
  void dispose() {
    app.removeListener(_onAppChanged);
    _devTimer?.cancel();
    _aiBase.dispose();
    _aiModel.dispose();
    _aiKey.dispose();
    _deeplKey.dispose();
    _colorHexCtrl.dispose();
    _outlineHexCtrl.dispose();
    _proxyCtrl.dispose();
    super.dispose();
  }

  Palette get p => Theme.of(context).brightness == Brightness.dark
      ? AppColors.dark
      : AppColors.light;

  String _translationTargetLabel(String code) => switch (code) {
    'zh-TW' => '繁中',
    'en' => '英语',
    _ => '简中',
  };

  void _onAppChanged() {
    if (mounted) setState(() {});
  }

  Widget? _healthBadge(String key) {
    final s = _health[key];
    if (s == null) return null;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: Text(
        s,
        style: TextStyle(
          fontSize: 11,
          color: s == '检测中…'
              ? p.muted
              : s.startsWith('正常')
              ? p.green
              : p.red,
        ),
      ),
    );
  }

  Future<void> _autoCheckAll() {
    final jobs = <Future<void>>[];
    if (app.asmrUser.isNotEmpty && app.asmrPass.isNotEmpty) {
      jobs.add(
        _autoCheck('asmr', 'https://api.asmr.one', app.asmrUser, app.asmrPass),
      );
    }
    for (var i = 0; i < app.customSites.length; i++) {
      final s = app.customSites[i];
      if (s.user.isNotEmpty && s.pass.isNotEmpty) {
        jobs.add(_autoCheck('site$i', s.url, s.user, s.pass));
      }
    }
    return Future.wait(jobs);
  }

  /// 检测服务器；可达且已配置账密时自动登录；灰点=服务器不可达/未配置
  Future<void> _autoCheck(
    String key,
    String base,
    String user,
    String pass,
  ) async {
    setState(() {
      _health[key] = '检测中…';
      _loginStatus[key] = 'gray';
    });
    String? health;
    try {
      health = await ApiService.checkHealth(app, base);
    } catch (_) {
      health = null;
    }
    if (!mounted) return;
    if (health == null) {
      setState(() {
        _health[key] = '连接失败';
        _loginStatus[key] = 'gray';
      });
      return;
    }
    final h = health;
    setState(() => _health[key] = h);
    if (user.isEmpty || pass.isEmpty) {
      setState(() => _loginStatus[key] = 'gray');
      return;
    }
    try {
      await ApiService.login(app, base, user, pass);
      app.loginEpoch++;
      app.notify();
      if (mounted) setState(() => _loginStatus[key] = 'ok');
    } catch (_) {
      if (mounted) setState(() => _loginStatus[key] = 'fail');
    }
  }

  Widget _loginDot(String key) {
    final s = _loginStatus[key];
    final color = s == 'ok'
        ? p.green
        : s == 'fail'
        ? p.red
        : p.dim;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: Container(
        width: 9,
        height: 9,
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      ),
    );
  }

  Future<void> _detectOpenAiModels() async {
    final base = _aiBase.text.trim().replaceFirst(RegExp(r'/+$'), '');
    if (base.isEmpty) {
      _toast('请先填写 API 地址');
      return;
    }
    _toast('正在获取模型列表…');
    try {
      final client = HttpClient()
        ..connectionTimeout = const Duration(seconds: 12);
      final request = await client.getUrl(Uri.parse('$base/models'));
      final key = _aiKey.text.trim();
      if (key.isNotEmpty) request.headers.set('Authorization', 'Bearer $key');
      final response = await request.close();
      final body = await utf8.decodeStream(response);
      client.close(force: true);
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw HttpException('HTTP ${response.statusCode}');
      }
      final raw = jsonDecode(body) as Map<String, dynamic>;
      final models =
          ((raw['data'] as List?) ?? const [])
              .map((item) => (item as Map?)?['id']?.toString() ?? '')
              .where((id) => id.isNotEmpty)
              .toSet()
              .toList()
            ..sort();
      if (models.isEmpty) throw const FormatException('响应未包含 data[].id');
      app.openAiModels
        ..clear()
        ..addAll(models);
      if (_aiModel.text.trim().isEmpty) _aiModel.text = models.first;
      app.setAiConfig(_aiBase.text, _aiModel.text, _aiKey.text);
      if (mounted) setState(() {});
      _toast('已获取 ${models.length} 个模型');
    } catch (e) {
      _toast('模型列表获取失败：$e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('设置'), leading: const BackButton()),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 40),
        children: [
          _sec('账号设置'),
          _group([
            _row(
              icon: Icons.dns_outlined,
              title: 'ASMR.ONE',
              sub: app.asmrUser.isEmpty ? '未配置账号' : '账号：${app.asmrUser}',
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _healthBadge('asmr') ?? const SizedBox.shrink(),
                  _loginDot('asmr'),
                  _miniBtn(
                    '检测',
                    () => _autoCheck(
                      'asmr',
                      'https://api.asmr.one',
                      app.asmrUser,
                      app.asmrPass,
                    ),
                  ),
                  const SizedBox(width: 8),
                  _miniBtn('配置', () async {
                    await showOneConfigSheet(context, app);
                    _autoCheck(
                      'asmr',
                      'https://api.asmr.one',
                      app.asmrUser,
                      app.asmrPass,
                    );
                  }),
                ],
              ),
            ),
            ...app.customSites.asMap().entries.map((e) {
              final s = e.value;
              final i = e.key;
              return _row(
                icon: Icons.dns_outlined,
                title: s.alias,
                sub: s.url + (s.user.isEmpty ? '' : ' · ${s.user}'),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _healthBadge('site$i') ?? const SizedBox.shrink(),
                    _loginDot('site$i'),
                    _miniBtn(
                      '检测',
                      () => _autoCheck('site$i', s.url, s.user, s.pass),
                    ),
                    const SizedBox(width: 4),
                    IconButton(
                      visualDensity: VisualDensity.compact,
                      icon: Icon(Icons.edit_outlined, size: 17, color: p.dim),
                      onPressed: () async {
                        await showSiteSheet(context, app, editIndex: i);
                        final fresh = app.customSites[i];
                        _autoCheck('site$i', fresh.url, fresh.user, fresh.pass);
                      },
                    ),
                    IconButton(
                      visualDensity: VisualDensity.compact,
                      icon: Icon(Icons.delete_outline, size: 17, color: p.dim),
                      onPressed: () {
                        app.removeSite(i);
                      },
                    ),
                  ],
                ),
              );
            }),
            Padding(
              padding: const EdgeInsets.all(14),
              child: OutlinedButton.icon(
                onPressed: () async {
                  await showSiteSheet(context, app);
                  if (app.customSites.isNotEmpty) {
                    final fresh = app.customSites.last;
                    _autoCheck(
                      'site${app.customSites.length - 1}',
                      fresh.url,
                      fresh.user,
                      fresh.pass,
                    );
                  }
                },
                icon: const Icon(Icons.add, size: 17),
                label: const Text('添加自建站点', style: TextStyle(fontSize: 13)),
                style: OutlinedButton.styleFrom(
                  foregroundColor: p.muted,
                  side: BorderSide(color: p.line),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
          ]),
          _sec('翻译'),
          _group([
            _row(
              icon: Icons.translate,
              title: '翻译引擎',
              sub: 'Google / Microsoft 免费 · DeepL 免费 Key · OpenAI 兼容',
              trailing: _engineDropdown(),
            ),
            if (app.engine == 'deepl') ...[
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
                child: Column(
                  children: [
                    _input(
                      _deeplKey,
                      'DeepL 免费版 API Key',
                      '在 deepl.com 免费注册后获取（api-free）',
                      obscure: true,
                      onChanged: (_) => app.setDeeplKey(_deeplKey.text),
                    ),
                    OutlinedButton(
                      onPressed: () async {
                        _toast('正在检测 DeepL…');
                        try {
                          final r = await apiTranslateDeepl(
                            text: 'こんにちは',
                            src: 'ja',
                            dst: 'zh-CN',
                            apiKey: _deeplKey.text,
                          );
                          if (mounted) _toast('DeepL 连接正常：$r');
                        } catch (e) {
                          if (mounted) _toast('DeepL 连接失败：$e');
                        }
                      },
                      style: OutlinedButton.styleFrom(
                        foregroundColor: p.muted,
                        side: BorderSide(color: p.line),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text('测试连接', style: TextStyle(fontSize: 13)),
                    ),
                  ],
                ),
              ),
            ],
            if (app.engine == 'openai') ...[
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
                child: Column(
                  children: [
                    _input(
                      _aiBase,
                      'API 地址 (Base URL)',
                      'https://api.openai.com/v1 或 http://127.0.0.1:11434/v1',
                    ),
                    _aiModelInput(),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: _detectOpenAiModels,
                            style: OutlinedButton.styleFrom(
                              foregroundColor: p.muted,
                              side: BorderSide(color: p.line),
                            ),
                            child: const Text(
                              '检测模型列表',
                              style: TextStyle(fontSize: 13),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    _input(_aiKey, 'API Key（本地服务可留空）', 'sk-...', obscure: true),
                    OutlinedButton(
                      onPressed: () async {
                        _toast('正在检测连接…');
                        try {
                          final r = await apiTranslateTest(
                            baseUrl: _aiBase.text,
                            model: _aiModel.text,
                            apiKey: _aiKey.text,
                          );
                          if (mounted) _toast(r);
                        } catch (e) {
                          if (mounted) _toast('连接失败：$e');
                        }
                      },
                      style: OutlinedButton.styleFrom(
                        foregroundColor: p.muted,
                        side: BorderSide(color: p.line),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text('测试连接', style: TextStyle(fontSize: 13)),
                    ),
                  ],
                ),
              ),
            ],
            _row(
              icon: null,
              title: '源语言 / 目标语言',
              sub: '日语 → ${_translationTargetLabel(app.translationTarget)}',
              trailing: _translationTargetDropdown(),
            ),
          ]),
          _sec('歌词'),
          _group([
            _row(
              icon: null,
              title: '繁简转换',
              sub: '歌词中文部分自动转换',
              trailing: _convDropdown(),
            ),
          ]),
          _sec('桌面歌词'),
          _group([
            _switchRow(
              Icons.lyrics_outlined,
              '桌面歌词',
              '最顶层悬浮歌词窗',
              app.desktopLyricsOn,
              (v) async {
                if (v && Platform.isAndroid) {
                  // 开启时先请求悬浮窗权限（未授权会拉起系统授权页）
                  final ok = await AndroidLyricsOverlay.instance
                      .requestPermission();
                  if (!ok) {
                    if (mounted) _toast('未授予悬浮窗权限，桌面歌词无法显示');
                    return; // 保持关闭
                  }
                }
                app.setDesktopLyricsOn(v);
              },
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 4, 14, 4),
              child: Row(
                children: [
                  Icon(Icons.format_size, size: 17, color: p.accent),
                  const SizedBox(width: 12),
                  const Text(
                    '字体大小',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                  ),
                  const Spacer(),
                  Text(
                    '${app.lyricsFontSize.round()}',
                    style: TextStyle(fontSize: 12, color: p.dim),
                  ),
                  Expanded(
                    child: Slider(
                      value: app.lyricsFontSize,
                      min: 12,
                      max: 64,
                      activeColor: p.accent,
                      onChanged: (v) => app.setLyricsFontSize(v),
                    ),
                  ),
                ],
              ),
            ),
            _colorRow(
              icon: Icons.palette_outlined,
              label: '字体颜色',
              value: app.lyricsColor,
              onChanged: (v) => app.setLyricsColor(v),
              hexCtrl: _colorHexCtrl,
            ),
            _colorRow(
              icon: Icons.border_color_outlined,
              label: '描边颜色',
              value: app.lyricsOutlineColor,
              onChanged: (v) => app.setLyricsOutlineColor(v),
              hexCtrl: _outlineHexCtrl,
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
              child: Row(
                children: [
                  Icon(Icons.line_weight, size: 17, color: p.accent),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text(
                      '描边宽度',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  Text(
                    app.lyricsOutlineWidth.toStringAsFixed(1),
                    style: TextStyle(fontSize: 12, color: p.dim),
                  ),
                  SizedBox(
                    width: 120,
                    child: Slider(
                      value: app.lyricsOutlineWidth,
                      min: 0,
                      max: 4,
                      divisions: 8,
                      activeColor: p.accent,
                      onChanged: (v) => app.setLyricsOutlineWidth(v),
                    ),
                  ),
                ],
              ),
            ),
            _lockRow('桌面端', app.lyricsLockedDesktop, () {
              app.setLyricsLockedDesktop(false);
            }),
            _lockRow('安卓（竖屏）', app.lyricsLockedPortrait, () {
              app.setLyricsLockedPortrait(false);
            }),
            _lockRow('安卓（横屏）', app.lyricsLockedLandscape, () {
              app.setLyricsLockedLandscape(false);
            }),
          ]),
          _sec('播放'),
          _group([
            _switchRow(
              Icons.content_paste_search,
              '剪贴板检测',
              '自动识别复制的 RJ 链接',
              app.clipboardDetect,
              (v) {
                app.setClipboardDetect(v);
              },
            ),
            if (Platform.isAndroid) ...[
              _switchRow(
                Icons.headphones_outlined,
                '拔出耳机自动暂停',
                '拔出耳机或断开蓝牙时自动暂停',
                app.earPause,
                (v) => app.setEarPause(v),
              ),
              _switchRow(
                Icons.speaker_group_outlined,
                '忽略音频焦点',
                '其他应用抢占音频焦点时不暂停',
                app.ignoreAudioFocus,
                (v) => app.setIgnoreAudioFocus(v),
              ),
            ],
            if (Platform.isAndroid)
              _row(
                icon: _batteryIgnoring == true
                    ? Icons.battery_saver
                    : Icons.battery_alert_outlined,
                title: '关闭省电优化',
                sub: _batteryIgnoring == true
                    ? '已加入白名单，后台播放不受省电限制'
                    : '防止后台播放被系统中断',
                onTap: _requestBatteryIgnore,
                trailing: _batteryIgnoring == null
                    ? null
                    : _miniBtn(
                        _batteryIgnoring! ? '已关闭' : '去关闭',
                        _requestBatteryIgnore,
                      ),
              ),
            if (Platform.isWindows)
              _switchRow(
                Icons.desktop_windows_outlined,
                '关闭窗口后保留托盘',
                app.keepTrayOnClose
                    ? '关闭后继续在后台播放，可从系统托盘恢复'
                    : '关闭窗口时将停止后台运行并退出程序',
                app.keepTrayOnClose,
                app.setKeepTrayOnClose,
              ),
            _mediaCacheLimitRow(),
          ]),
          _sec('曲目'),
          _group([
            _switchRow(
              Icons.route_outlined,
              '智能路径',
              '打开作品自动进入最佳目录',
              app.initialPathBehavior == 'auto',
              (v) => app.setInitialPathBehavior(v ? 'auto' : 'root'),
            ),
            if (app.initialPathBehavior == 'auto') ...[
              _switchRow(
                Icons.hearing_outlined,
                '效果音偏好',
                '优先进入包含效果音的目录',
                app.sePreference,
                (v) => app.setSePreference(v),
              ),
              _row(
                icon: Icons.audiotrack_outlined,
                title: '音频类型偏好',
                sub: app.audioTypePreference.join(' > '),
                onTap: _editAudioTypePreference,
                trailing: Icon(Icons.drag_indicator, size: 18, color: p.dim),
              ),
            ],
          ]),
          _sec('网络'),
          _group([_proxySettings()]),
          _sec('隐私'),
          _group([
            _switchRow(
              Icons.notifications_off_outlined,
              '不显示通知栏媒体卡片',
              '播放时不在通知栏显示媒体卡片',
              app.lsCover,
              app.setLsCover,
            ),
            _switchRow(
              Icons.branding_watermark_outlined,
              '通知栏封面显示项目 logo',
              '开启后封面位置显示项目 logo，不显示真实封面',
              app.notifCover,
              (v) {
                app.notifCover = v;
                app.notify();
              },
            ),
            _switchRow(
              Icons.privacy_tip_outlined,
              '定时关闭后释放系统接口',
              '到点清除锁屏媒体卡片与通知',
              app.releaseInterface,
              (v) {
                app.releaseInterface = v;
                app.notify();
              },
            ),
          ]),
          _sec('外观'),
          _group([
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 10, 14, 6),
              child: Row(
                children: [
                  Icon(Icons.zoom_out_map_outlined, size: 17, color: p.accent),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text(
                      '界面缩放',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  Text(
                    '${app.uiScalePercent}%',
                    style: TextStyle(fontSize: 12, color: p.dim),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 0, 14, 10),
              child: Slider(
                value: (app.uiScalePercent / 25 - 1).toDouble(),
                min: 0,
                max: 7,
                divisions: 7,
                label: '${app.uiScalePercent}%',
                activeColor: p.accent,
                onChanged: (value) =>
                    app.setUiScalePercent((value.round() + 1) * 25),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              child: Row(
                children: [
                  Icon(
                    app.themeMode == ThemeMode.system
                        ? Icons.brightness_auto_outlined
                        : app.themeMode == ThemeMode.light
                        ? Icons.light_mode_outlined
                        : Icons.dark_mode_outlined,
                    size: 17,
                    color: p.accent,
                  ),
                  const SizedBox(width: 12),
                  const Text(
                    '主题',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                  ),
                  const Spacer(),
                  // 三段按钮按内容自适应宽度，不撑满整行
                  SegmentedButton<ThemeMode>(
                    segments: const [
                      ButtonSegment(
                        value: ThemeMode.system,
                        label: Text('跟随系统', style: TextStyle(fontSize: 12)),
                      ),
                      ButtonSegment(
                        value: ThemeMode.light,
                        label: Text('浅色', style: TextStyle(fontSize: 12)),
                      ),
                      ButtonSegment(
                        value: ThemeMode.dark,
                        label: Text('深色', style: TextStyle(fontSize: 12)),
                      ),
                    ],
                    selected: {app.themeMode},
                    showSelectedIcon: false,
                    style: ButtonStyle(
                      backgroundColor: WidgetStateProperty.resolveWith(
                        (states) => states.contains(WidgetState.selected)
                            ? p.accent.withValues(alpha: .12)
                            : p.surface2,
                      ),
                      foregroundColor: WidgetStateProperty.resolveWith(
                        (states) => states.contains(WidgetState.selected)
                            ? p.accent
                            : p.muted,
                      ),
                      // 边框粗细与设置页其他选项一致（p.line 1px）
                      side: WidgetStatePropertyAll(
                        BorderSide(color: p.line, width: 1),
                      ),
                      textStyle: WidgetStatePropertyAll(
                        const TextStyle(fontSize: 11.5),
                      ),
                      padding: WidgetStatePropertyAll(
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      ),
                      visualDensity: VisualDensity.compact,
                    ),
                    onSelectionChanged: (s) => app.setThemeMode(s.first),
                  ),
                ],
              ),
            ),
          ]),
          _sec('危险操作'),
          _group([
            _row(
              icon: Icons.restart_alt,
              title: '完全重置软件',
              sub: '清除本机全部数据，恢复初始状态',
              onTap: _confirmReset,
              trailing: Text(
                '重置',
                style: TextStyle(fontSize: 12, color: p.red),
              ),
            ),
          ]),
          _sec('关于'),
          _group([
            _switchRow(
              Icons.system_update_outlined,
              '自动检测更新',
              '启动后 3 秒请求更新服务',
              app.updateCheckEnabled,
              app.setUpdateCheckEnabled,
            ),
            _row(
              icon: Icons.refresh_outlined,
              title: '检查更新',
              sub: '手动请求更新服务',
              onTap: () => UpdateService.checkManually(context, app),
            ),
            _row(
              icon: null,
              title: '版本',
              sub: null,
              trailing: Text(
                'Kikoeta ${UpdateService.currentVersion}',
                style: TextStyle(fontSize: 12),
              ),
              onTap: _onVersionTap,
            ),
            _row(
              icon: null,
              title: '仓库',
              sub: null,
              trailing: const Text(
                'https://github.com/chenflxs/kikoeta',
                style: TextStyle(fontSize: 12),
              ),
              onTap: _openRepo,
            ),
          ]),
        ],
      ),
    );
  }

  Widget _sec(String t) => Padding(
    padding: const EdgeInsets.fromLTRB(4, 18, 4, 8),
    child: Text(
      t,
      style: TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w700,
        letterSpacing: .5,
        color: p.muted,
      ),
    ),
  );

  Widget _group(List<Widget> children) => Container(
    decoration: BoxDecoration(
      color: p.surface,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: p.line),
    ),
    child: Column(children: children),
  );

  Widget _row({
    IconData? icon,
    required String title,
    String? sub,
    Widget? trailing,
    VoidCallback? onTap,
  }) {
    final content = Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: p.line)),
      ),
      child: Row(
        children: [
          if (icon != null) ...[
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: p.surface2,
                borderRadius: BorderRadius.circular(9),
              ),
              child: Icon(icon, size: 17, color: p.accent),
            ),
            const SizedBox(width: 12),
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (sub != null) ...[
                  const SizedBox(height: 2),
                  Text(sub, style: TextStyle(fontSize: 11, color: p.dim)),
                ],
              ],
            ),
          ),
          ?trailing,
        ],
      ),
    );
    if (onTap == null) return content;
    return InkWell(onTap: onTap, child: content);
  }

  /// 打开项目仓库主页
  Future<void> _openRepo() async {
    final ok = await launchUrl(
      Uri.parse('https://github.com/chenflxs/kikoeta'),
      mode: LaunchMode.externalApplication,
    );
    if (!ok) _toast('打开失败');
  }

  /// 版本号彩蛋：像安卓开发者模式一样连续点击——前 3 次静默，
  /// 之后提示剩余步数；3 秒内没有下一次点击则重置计数；归零后弹窗
  void _onVersionTap() {
    _devTimer?.cancel();
    _devTaps++;
    if (_devTaps >= 7) {
      _devTaps = 0;
      showDialog<void>(
        context: context,
        builder: (_) => AlertDialog(
          backgroundColor: p.surface,
          title: const Text(
            '开发者模式',
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
          ),
          content: const Text('你不会真以为有开发者模式吧？', style: TextStyle(fontSize: 13)),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text('好吧', style: TextStyle(color: p.accent)),
            ),
          ],
        ),
      );
      return;
    }
    if (_devTaps > 3) {
      _toast('再执行 ${7 - _devTaps} 步进入开发者模式');
    }
    _devTimer = Timer(const Duration(seconds: 3), () {
      _devTaps = 0;
      _devTimer = null;
    });
  }

  Widget _switchRow(
    IconData icon,
    String title,
    String sub,
    bool value,
    ValueChanged<bool> onChanged,
  ) {
    return _row(
      icon: icon,
      title: title,
      sub: sub,
      trailing: Switch(
        value: value,
        onChanged: onChanged,
        activeTrackColor: p.accent,
      ),
    );
  }

  Widget _mediaCacheLimitRow() {
    final limit = app.mediaCacheLimitMb;
    final label = limit < 1024
        ? '$limit MB'
        : '${(limit / 1024).toStringAsFixed(limit % 1024 == 0 ? 0 : 1)} GB';

    return Container(
      padding: const EdgeInsets.fromLTRB(14, 13, 14, 10),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: p.line)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: p.surface2,
              borderRadius: BorderRadius.circular(9),
            ),
            child: Icon(Icons.memory_outlined, size: 17, color: p.accent),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Expanded(
                      child: Text(
                        '媒体缓存上限',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    Text(
                      label,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: p.accent,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  '仅限制在线播放缓冲，不影响下载功能',
                  style: TextStyle(fontSize: 11, color: p.dim),
                ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    Text(
                      '512 MB',
                      style: TextStyle(fontSize: 10, color: p.dim),
                    ),
                    Expanded(
                      child: Slider(
                        value: limit.toDouble(),
                        min: 512,
                        max: 10240,
                        divisions: 19,
                        label: label,
                        activeColor: p.accent,
                        semanticFormatterCallback: (_) => label,
                        onChanged: (value) {
                          final next = value.round();
                          app.setMediaCacheLimitMb(next);
                          unawaited(
                            AppPlayer.instance.setMediaCacheLimitMb(next),
                          );
                        },
                      ),
                    ),
                    Text('10 GB', style: TextStyle(fontSize: 10, color: p.dim)),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _proxySettings() {
    final enabled = app.httpProxyEnabled;
    final hasAddress = _proxyCtrl.text.trim().isNotEmpty;
    final status = enabled
        ? hasAddress
              ? '已启用：${_proxyCtrl.text.trim()}'
              : '已启用，请填写 HTTP 代理地址'
        : hasAddress
        ? '已保存地址，开启后生效'
        : '仅支持 HTTP 协议代理，对所有网络请求生效';

    return Column(
      children: [
        _switchRow(
          Icons.vpn_lock_outlined,
          'HTTP 代理',
          status,
          enabled,
          app.setHttpProxyEnabled,
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 10, 14, 14),
          child: TextField(
            controller: _proxyCtrl,
            enabled: enabled,
            autocorrect: false,
            enableSuggestions: false,
            keyboardType: TextInputType.url,
            textInputAction: TextInputAction.done,
            style: TextStyle(fontSize: 13, color: enabled ? p.text : p.dim),
            decoration: InputDecoration(
              labelText: '代理服务器',
              labelStyle: TextStyle(fontSize: 12, color: p.muted),
              hintText: '127.0.0.1:7890 或 http://127.0.0.1:7890',
              hintStyle: TextStyle(fontSize: 12, color: p.dim),
              helperText: enabled ? '留空将不使用代理' : '开启 HTTP 代理后可编辑',
              helperStyle: TextStyle(fontSize: 11, color: p.dim),
              isDense: true,
              filled: true,
              fillColor: enabled ? p.surface2 : p.bg2,
              prefixIcon: Icon(
                Icons.lan_outlined,
                size: 18,
                color: enabled ? p.accent : p.dim,
              ),
              suffixIcon: enabled && hasAddress
                  ? IconButton(
                      tooltip: '清空代理地址',
                      icon: Icon(Icons.close_rounded, size: 17, color: p.dim),
                      onPressed: () {
                        _proxyCtrl.clear();
                        app.setHttpProxyUrl('');
                      },
                    )
                  : null,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: p.line),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: p.border),
              ),
              disabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: p.line),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: p.accent, width: 1.5),
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 12,
              ),
            ),
            onChanged: app.setHttpProxyUrl,
          ),
        ),
      ],
    );
  }

  Widget _miniBtn(String label, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: p.surface2,
          border: Border.all(color: p.line),
          borderRadius: BorderRadius.circular(999),
        ),
        child: Text(label, style: TextStyle(fontSize: 11.5, color: p.muted)),
      ),
    );
  }

  /// 音频类型偏好：拖拽排序弹窗（可恢复默认）
  void _editAudioTypePreference() {
    final order = List<String>.from(app.audioTypePreference);
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlg) => AlertDialog(
          backgroundColor: p.surface,
          title: const Text(
            '音频类型偏好',
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
          ),
          content: SizedBox(
            width: 280,
            height: 260,
            child: ReorderableListView(
              onReorderItem: (oldI, newI) {
                setDlg(() {
                  final x = order.removeAt(oldI);
                  order.insert(newI, x);
                });
              },
              buildDefaultDragHandles: false,
              children: order
                  .map(
                    (t) => ListTile(
                      key: ValueKey(t),
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      leading: ReorderableDragStartListener(
                        index: order.indexOf(t),
                        child: Icon(Icons.drag_handle, size: 20, color: p.dim),
                      ),
                      title: Text(t, style: const TextStyle(fontSize: 13.5)),
                    ),
                  )
                  .toList(),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => setDlg(() {
                order
                  ..clear()
                  ..addAll(['mp3', 'flac', 'wav', 'opus', 'm4a', 'aac']);
              }),
              child: const Text('恢复默认'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('取消'),
            ),
            TextButton(
              onPressed: () {
                app.setAudioTypePreference(List.of(order));
                Navigator.pop(ctx);
              },
              child: const Text('保存'),
            ),
          ],
        ),
      ),
    );
  }

  /// 请求关闭省电优化（安卓）：拉起系统「忽略电池优化」授权页
  Future<void> _requestBatteryIgnore() async {
    if (!Platform.isAndroid) return;
    final v = await AndroidBattery.instance.requestIgnore();
    if (mounted) setState(() => _batteryIgnoring = v);
    if (v != true && mounted) {
      _toast('请在系统设置中允许「忽略电池优化」');
    }
  }

  /// 完全重置：5 秒倒计时确认 → 停止播放/隐藏悬浮窗 → 清空全部数据 → 自动回到登录页
  Future<void> _confirmReset() async {
    final ok = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const _ResetConfirmDialog(),
    );
    if (ok != true || !mounted) return;
    // 停止播放与悬浮窗
    try {
      await AppPlayer.instance.stop();
    } catch (_) {}
    DesktopLyricsOverlay.instance.hide();
    await AndroidLyricsOverlay.instance.hide();
    // 清空内存 + SQLite（loginRequired 回到 true，自动切到登录页）
    app.resetAll();
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(const SnackBar(content: Text('已重置：账号与全部本地数据已清除')));
  }

  Widget _engineDropdown() {
    const labels = {
      'google': 'Google',
      'microsoft': 'Microsoft',
      'deepl': 'DeepL',
      'openai': 'OpenAI 兼容',
    };
    return _translationDropdown(
      label: labels[app.engine]!,
      icon: Icons.translate_outlined,
      tooltip: '翻译引擎',
      items: [
        _menuHead(context, '翻译引擎'),
        ...labels.entries.map(
          (e) => PopupMenuItem(
            value: e.key,
            height: 42,
            child: MenuItem(label: e.value, selected: app.engine == e.key),
          ),
        ),
      ],
      onSelected: app.setEngine,
    );
  }

  Widget _translationTargetDropdown() {
    const labels = {'zh-CN': '简中', 'zh-TW': '繁中', 'en': '英语'};
    return _translationDropdown(
      label: labels[app.translationTarget]!,
      icon: Icons.language_outlined,
      tooltip: '翻译目标语言',
      items: [
        _menuHead(context, '目标语言'),
        ...labels.entries.map(
          (e) => PopupMenuItem(
            value: e.key,
            height: 42,
            child: MenuItem(
              label: e.value,
              selected: app.translationTarget == e.key,
            ),
          ),
        ),
      ],
      onSelected: app.setTranslationTarget,
    );
  }

  Widget _translationDropdown({
    required String label,
    required IconData icon,
    required String tooltip,
    required List<PopupMenuEntry<String>> items,
    required ValueChanged<String> onSelected,
  }) {
    return PopupMenuButton<String>(
      tooltip: tooltip,
      onSelected: onSelected,
      offset: const Offset(0, 38),
      constraints: const BoxConstraints(minWidth: 148),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      color: p.surface,
      itemBuilder: (_) => items,
      child: Container(
        height: 34,
        padding: const EdgeInsets.symmetric(horizontal: 9),
        decoration: BoxDecoration(
          color: p.surface2,
          border: Border.all(color: p.line),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 15, color: p.dim),
            const SizedBox(width: 6),
            Text(label, style: TextStyle(fontSize: 12, color: p.muted)),
            const SizedBox(width: 2),
            Icon(Icons.keyboard_arrow_down, size: 16, color: p.dim),
          ],
        ),
      ),
    );
  }

  Widget _convDropdown() {
    const labels = {'orig': '关闭', 'tw': '简 → 繁', 'zh': '繁 → 简'};
    return _selectPill(
      labels[app.conv]!,
      (ctx) => [
        _menuHead(ctx, '繁简转换'),
        ...labels.entries.map(
          (e) => PopupMenuItem(
            value: e.key,
            height: 44,
            child: MenuItem(label: e.value, selected: app.conv == e.key),
          ),
        ),
      ],
      (v) {
        app.setConv(v);
      },
    );
  }

  PopupMenuItem<String> _menuHead(BuildContext ctx, String title) {
    return PopupMenuItem<String>(
      enabled: false,
      height: 30,
      child: Align(
        alignment: Alignment.centerLeft,
        child: Text(
          title,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            letterSpacing: .6,
            color: p.dim,
          ),
        ),
      ),
    );
  }

  Widget _selectPill(
    String label,
    List<PopupMenuEntry<String>> Function(BuildContext) items,
    ValueChanged<String> onSelected,
  ) {
    return PopupMenuButton<String>(
      onSelected: onSelected,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      color: p.surface,
      itemBuilder: items,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
        decoration: BoxDecoration(
          color: p.surface2,
          border: Border.all(color: p.line),
          borderRadius: BorderRadius.circular(999),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(label, style: TextStyle(fontSize: 12, color: p.muted)),
            const SizedBox(width: 5),
            Icon(Icons.keyboard_arrow_down, size: 14, color: p.dim),
          ],
        ),
      ),
    );
  }

  Widget _input(
    TextEditingController ctrl,
    String label,
    String hint, {
    bool obscure = false,
    ValueChanged<String>? onChanged,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: TextField(
        controller: ctrl,
        obscureText: obscure,
        style: TextStyle(fontSize: 13, color: p.text),
        onChanged:
            onChanged ??
            (_) {
              app.setAiConfig(_aiBase.text, _aiModel.text, _aiKey.text);
            },
        decoration: InputDecoration(
          labelText: label,
          labelStyle: TextStyle(fontSize: 11.5, color: p.muted),
          hintText: hint,
          hintStyle: TextStyle(fontSize: 12, color: p.dim),
          filled: true,
          fillColor: p.surface2,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(11),
            borderSide: BorderSide(color: p.line),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(11),
            borderSide: BorderSide(color: p.line),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(11),
            borderSide: BorderSide(color: p.accent),
          ),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 12,
            vertical: 10,
          ),
        ),
      ),
    );
  }

  Widget _aiModelInput() {
    final hasModels = app.openAiModels.isNotEmpty;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: MenuAnchor(
        controller: _aiModelMenu,
        style: MenuStyle(
          backgroundColor: WidgetStatePropertyAll(p.surface),
          side: WidgetStatePropertyAll(BorderSide(color: p.line)),
          shape: WidgetStatePropertyAll(
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
          padding: const WidgetStatePropertyAll(
            EdgeInsets.symmetric(vertical: 4),
          ),
        ),
        menuChildren: hasModels
            ? app.openAiModels
                  .map(
                    (model) => MenuItemButton(
                      onPressed: () {
                        _aiModel.text = model;
                        app.setAiConfig(_aiBase.text, model, _aiKey.text);
                        _aiModelMenu.close();
                      },
                      child: SizedBox(
                        width: 260,
                        child: Text(
                          model,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(fontSize: 13, color: p.text),
                        ),
                      ),
                    ),
                  )
                  .toList()
            : const [],
        builder: (_, menuController, _) => TextField(
          controller: _aiModel,
          style: TextStyle(fontSize: 13, color: p.text),
          onChanged: (_) {
            app.setAiConfig(_aiBase.text, _aiModel.text, _aiKey.text);
          },
          decoration: InputDecoration(
            labelText: '模型名称',
            labelStyle: TextStyle(fontSize: 11.5, color: p.muted),
            hintText: hasModels ? '输入模型名或从列表选择' : '例如 gpt-4o-mini',
            hintStyle: TextStyle(fontSize: 12, color: p.dim),
            helperText: hasModels
                ? '已检测到 ${app.openAiModels.length} 个模型'
                : null,
            helperStyle: TextStyle(fontSize: 10.5, color: p.dim),
            filled: true,
            fillColor: p.surface2,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: p.line),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: p.line),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: p.accent),
            ),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 10,
            ),
            suffixIcon: IconButton(
              tooltip: hasModels ? '选择已检测模型' : '请先检测模型列表',
              onPressed: hasModels
                  ? () {
                      if (menuController.isOpen) {
                        menuController.close();
                      } else {
                        menuController.open();
                      }
                    }
                  : null,
              icon: Icon(
                Icons.keyboard_arrow_down,
                color: hasModels ? p.dim : p.track,
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _toast(String msg) {
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(
        SnackBar(
          content: Text(msg),
          duration: const Duration(milliseconds: 1600),
        ),
      );
  }

  Widget _colorRow({
    required IconData icon,
    required String label,
    required int value,
    required ValueChanged<int> onChanged,
    required TextEditingController hexCtrl,
  }) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 6, 14, 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 17, color: p.accent),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                // 色块 + hex 用 Wrap：窄屏（竖屏）下自动换行，不截断
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    ..._lyricsColors.map((c) {
                      final selected = value == c;
                      return GestureDetector(
                        onTap: () {
                          onChanged(c);
                          hexCtrl.text = _toHex(c);
                        },
                        child: Container(
                          width: 24,
                          height: 24,
                          decoration: BoxDecoration(
                            color: Color(c),
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: selected ? p.accent : p.line,
                              width: selected ? 2 : 1,
                            ),
                          ),
                          child: selected
                              ? Icon(
                                  Icons.check,
                                  size: 14,
                                  color: c == 0xFFFFFFFF || c == 0xFFFFEB3B
                                      ? Colors.black54
                                      : Colors.white,
                                )
                              : null,
                        ),
                      );
                    }),
                    SizedBox(
                      width: 88,
                      height: 30,
                      child: TextField(
                        controller: hexCtrl,
                        style: const TextStyle(fontSize: 12),
                        decoration: InputDecoration(
                          hintText: '#RRGGBB',
                          hintStyle: TextStyle(fontSize: 11, color: p.dim),
                          isDense: true,
                          filled: true,
                          fillColor: p.surface2,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: BorderSide(color: p.line),
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 6,
                          ),
                        ),
                        onChanged: (s) {
                          final v = _parseHex(s);
                          if (v != null) onChanged(v);
                        },
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _toHex(int c) =>
      '#${(c & 0xFFFFFFFF).toRadixString(16).toUpperCase().padLeft(8, '0')}';

  int? _parseHex(String s) {
    var t = s.trim().replaceFirst('#', '');
    if (t.length == 6) t = 'FF$t';
    if (t.length != 8) return null;
    return int.tryParse(t, radix: 16);
  }

  Widget _lockRow(String label, bool locked, VoidCallback onUnlock) {
    return _row(
      icon: locked ? Icons.lock_outline : Icons.lock_open_outlined,
      title: '$label 歌词锁定',
      sub: locked ? '已锁定：点击歌词不会响应，可在设置中解锁' : '未锁定',
      trailing: locked
          ? GestureDetector(
              onTap: onUnlock,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: p.surface2,
                  border: Border.all(color: p.line),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  '解锁',
                  style: TextStyle(fontSize: 11.5, color: p.accent),
                ),
              ),
            )
          : null,
    );
  }
}

/// 「完全重置」确认弹窗：等待 5 秒倒计时结束后「确定重置」才可点击
class _ResetConfirmDialog extends StatefulWidget {
  const _ResetConfirmDialog();

  @override
  State<_ResetConfirmDialog> createState() => _ResetConfirmDialogState();
}

class _ResetConfirmDialogState extends State<_ResetConfirmDialog> {
  static const _seconds = 5;
  int _count = _seconds;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (_count <= 1) {
        t.cancel();
        setState(() => _count = 0);
      } else {
        setState(() => _count--);
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final canConfirm = _count == 0;
    return AlertDialog(
      title: const Row(
        children: [
          Icon(Icons.warning_amber_rounded, color: Colors.deepOrange, size: 22),
          SizedBox(width: 8),
          Text('完全重置'),
        ],
      ),
      content: const Text(
        '将清除本机全部数据，且不可恢复：\n\n'
        '· ASMR.ONE 账号与自建站点配置\n'
        '· 收藏 / 播放历史 / 播放列表 / 黑名单\n'
        '· 翻译结果、均衡器、桌面歌词、定时关闭等全部设置\n\n'
        '请确认是否继续。',
        style: TextStyle(fontSize: 13.5, height: 1.5),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('取消'),
        ),
        TextButton(
          onPressed: canConfirm ? () => Navigator.pop(context, true) : null,
          style: canConfirm
              ? TextButton.styleFrom(foregroundColor: Colors.red)
              : null,
          child: Text(canConfirm ? '确定重置' : '确定重置（$_count 秒）'),
        ),
      ],
    );
  }
}
