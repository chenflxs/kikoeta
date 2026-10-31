import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../data.dart';
import '../services/android_battery.dart';
import '../services/android_lyrics_overlay.dart';
import '../services/api_service.dart';
import '../services/desktop_lyrics_overlay.dart';
import '../services/lyrics_library_broadcast_service.dart';
import '../services/lyrics_library_service.dart';
import '../services/player_service.dart';
import '../services/theme_reveal.dart';
import '../services/update_service.dart';
import '../smooth_scroll.dart';
import '../src/rust/api/translate.dart';
import '../sheets.dart';
import '../theme.dart';
import '../widgets.dart';
import '../widgets/playback_seek_seconds_control.dart';
import '../widgets/data_sync_settings.dart';
import '../l10n/strings.dart';
import '../l10n/app_language.dart';

class SettingsPage extends StatefulWidget {
  final AppState app;
  final String? sectionKey;

  const SettingsPage({super.key, required this.app, this.sectionKey});

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

  final Map<String, AsyncSnapshot<int>> _health = {};
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

  String? get _sectionKey => widget.sectionKey;

  @override
  void initState() {
    super.initState();
    // 设置页大量控件直接渲染 AppState 字段（开关、分段按钮等），
    // 自行监听以在状态变化时刷新（此前依赖根级全树重建）
    app.addListener(_onAppChanged);
    _aiBase = TextEditingController(text: app.activeAiConfig['base']);
    _aiModel = TextEditingController(text: app.activeAiConfig['model']);
    _aiKey = TextEditingController(text: app.activeAiConfig['key']);
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
    'ui' => context.l10n.followInterfaceLanguage,
    'zh-TW' => context.l10n.traditionalChineseShort,
    'en' => context.l10n.englishLanguage,
    _ => context.l10n.simplifiedChineseShort,
  };

  void _onAppChanged() {
    if (mounted) setState(() {});
  }

  Widget? _healthBadge(String key) {
    final health = _health[key];
    if (health == null) return null;
    final l10n = context.l10n;
    final text = health.hasData
        ? '${l10n.settingsPageHealthBadgeStartsWith} · ${health.data}ms'
        : health.hasError
        ? l10n.settingsPageAutoCheckSetState2
        : l10n.settingsPageAutoCheckSetState;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 11,
          color: health.hasData
              ? p.green
              : health.hasError
              ? p.red
              : p.muted,
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
      _health[key] = const AsyncSnapshot<int>.waiting();
      _loginStatus[key] = 'gray';
    });
    int health;
    try {
      health = await ApiService.checkHealth(app, base);
    } catch (error, stackTrace) {
      if (!mounted) return;
      setState(() {
        _health[key] = AsyncSnapshot<int>.withError(
          ConnectionState.done,
          error,
          stackTrace,
        );
        _loginStatus[key] = 'gray';
      });
      return;
    }
    if (!mounted) return;
    setState(() {
      _health[key] = AsyncSnapshot<int>.withData(ConnectionState.done, health);
    });
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
    final l10n = context.l10n;
    final base = _aiBase.text.trim().replaceFirst(RegExp(r'/+$'), '');
    if (base.isEmpty) {
      _toast(l10n.settingsPageDetectOpenAiModelsToast2);
      return;
    }
    _toast(l10n.settingsPageDetectOpenAiModelsToast);
    try {
      final client = HttpClient()
        ..connectionTimeout = const Duration(seconds: 12);
      final request = await client.getUrl(Uri.parse('$base/models'));
      final key = _aiKey.text.trim();
      if (base.contains('index-translate.bilibili.com')) {
        request.headers.set('User-Agent', 'Index-Translate-Client/1.0');
      } else if (key.isNotEmpty) {
        request.headers.set('Authorization', 'Bearer $key');
      }
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
      if (models.isEmpty) {
        throw FormatException(
          l10n.settingsPageDetectOpenAiModelsFormatException,
        );
      }
      app.openAiModels
        ..clear()
        ..addAll(models);
      if (_aiModel.text.trim().isEmpty) _aiModel.text = models.first;
      app.setAiConfig(_aiBase.text, _aiModel.text, _aiKey.text);
      if (mounted) setState(() {});
      _toast(
        l10n.settingsPageDetectOpenAiModelsToast4((models.length).toString()),
      );
    } catch (e) {
      _toast(l10n.settingsPageDetectOpenAiModelsToast3((e).toString()));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          _sectionKey == null
              ? context.l10n.settings
              : _sectionTitle(_sectionKey!),
        ),
        leading: const BackButton(),
      ),
      body: SafeArea(
        top: false,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final sections = <Widget>[
              _section(
                'account',
                context.l10n.settingsPageSectionsSection5,
                _group([
                  _row(
                    icon: Icons.dns_outlined,
                    title: 'ASMR.ONE',
                    sub: app.asmrUser.isEmpty
                        ? context.l10n.settingsPageSectionsSub
                        : context.l10n.settingsPageSectionsSub8(
                            (app.asmrUser).toString(),
                          ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _healthBadge('asmr') ?? const SizedBox.shrink(),
                        _loginDot('asmr'),
                        _miniBtn(
                          context.l10n.settingsPageSectionsMiniBtn,
                          () => _autoCheck(
                            'asmr',
                            'https://api.asmr.one',
                            app.asmrUser,
                            app.asmrPass,
                          ),
                        ),
                        const SizedBox(width: 8),
                        _miniBtn(
                          context.l10n.settingsPageSectionsMiniBtn2,
                          () async {
                            await showOneConfigSheet(context, app);
                            _autoCheck(
                              'asmr',
                              'https://api.asmr.one',
                              app.asmrUser,
                              app.asmrPass,
                            );
                          },
                        ),
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
                            context.l10n.settingsPageSectionsMiniBtn,
                            () => _autoCheck('site$i', s.url, s.user, s.pass),
                          ),
                          const SizedBox(width: 4),
                          IconButton(
                            visualDensity: VisualDensity.compact,
                            icon: Icon(
                              Icons.edit_outlined,
                              size: 17,
                              color: p.dim,
                            ),
                            onPressed: () async {
                              await showSiteSheet(context, app, editIndex: i);
                              final fresh = app.customSites[i];
                              _autoCheck(
                                'site$i',
                                fresh.url,
                                fresh.user,
                                fresh.pass,
                              );
                            },
                          ),
                          IconButton(
                            visualDensity: VisualDensity.compact,
                            icon: Icon(
                              Icons.delete_outline,
                              size: 17,
                              color: p.dim,
                            ),
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
                      label: Text(
                        context.l10n.settingsPageSectionsText9,
                        style: TextStyle(fontSize: 13),
                      ),
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
                rootVisible: true,
              ),
              _section(
                'translation',
                context.l10n.languageAndTranslation,
                _group([
                  _row(
                    icon: Icons.language_outlined,
                    title: context.l10n.interfaceLanguage,
                    trailing: _uiLanguageDropdown(),
                  ),
                  _row(
                    icon: Icons.translate,
                    title: context.l10n.translationEngine,
                    trailing: _engineDropdown(),
                    showDivider: false,
                  ),
                  if (app.engine == 'deepl') ...[
                    Padding(
                      padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
                      child: Column(
                        children: [
                          _input(
                            _deeplKey,
                            context.l10n.settingsPageSectionsInput3,
                            context.l10n.settingsPageSectionsInput4,
                            obscure: true,
                            onChanged: (_) => app.setDeeplKey(_deeplKey.text),
                          ),
                          OutlinedButton(
                            onPressed: () async {
                              final l10n = context.l10n;
                              _toast(l10n.settingsPageSectionsToast3);
                              try {
                                final r = await apiTranslateDeepl(
                                  text: 'こんにちは',
                                  src: 'ja',
                                  dst: 'zh-CN',
                                  apiKey: _deeplKey.text,
                                );
                                if (mounted) {
                                  _toast(
                                    l10n.settingsPageSectionsToast7(
                                      (r).toString(),
                                    ),
                                  );
                                }
                              } catch (e) {
                                if (mounted) {
                                  _toast(
                                    l10n.settingsPageSectionsToast6(
                                      (e).toString(),
                                    ),
                                  );
                                }
                              }
                            },
                            style: OutlinedButton.styleFrom(
                              foregroundColor: p.muted,
                              side: BorderSide(color: p.line),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: Text(
                              context.l10n.testConnection,
                              style: TextStyle(fontSize: 13),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  if (app.engine == 'openai' || app.engine == 'index') ...[
                    Padding(
                      padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
                      child: Column(
                        children: [
                          _input(
                            _aiBase,
                            context.l10n.settingsPageSectionsInput2,
                            context.l10n.settingsPageSectionsInput5,
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
                                  child: Text(
                                    context.l10n.settingsPageSectionsText8,
                                    style: TextStyle(fontSize: 13),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          _input(
                            _aiKey,
                            context.l10n.settingsPageSectionsInput,
                            'sk-...',
                            obscure: true,
                          ),
                          OutlinedButton(
                            onPressed: () async {
                              final l10n = context.l10n;
                              _toast(l10n.settingsPageSectionsToast2);
                              try {
                                final r = await apiTranslateTest(
                                  baseUrl: _aiBase.text,
                                  model: _aiModel.text,
                                  apiKey: _aiKey.text,
                                );
                                if (mounted) _toast(r);
                              } catch (e) {
                                if (mounted) {
                                  _toast(
                                    l10n.settingsPageSectionsToast(
                                      (e).toString(),
                                    ),
                                  );
                                }
                              }
                            },
                            style: OutlinedButton.styleFrom(
                              foregroundColor: p.muted,
                              side: BorderSide(color: p.line),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: Text(
                              context.l10n.testConnection,
                              style: TextStyle(fontSize: 13),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  _row(
                    icon: null,
                    title: context.l10n.sourceAndTargetLanguage,
                    sub: context.l10n.settingsPageSectionsSub11(
                      (_translationTargetLabel(
                        app.translationTarget,
                      )).toString(),
                    ),
                    trailing: _translationTargetDropdown(),
                    showDivider: false,
                  ),
                ]),
                rootVisible: false,
                rootCardRadius: const BorderRadius.vertical(
                  top: Radius.circular(16),
                ),
                rootCardMargin: const EdgeInsets.only(top: 14),
              ),
              _section(
                'lyrics_desktop',
                context.l10n.lyrics,
                _group([
                  _row(
                    icon: null,
                    title: context.l10n.chineseConversion,
                    sub: context.l10n.settingsPageSectionsSub3,
                    trailing: _convDropdown(),
                    showDivider: false,
                  ),
                ]),
                rootVisible: false,
                rootEntry: false,
              ),
              _section(
                'lyrics_desktop',
                context.l10n.settingsPageSectionsSection6,
                _group([
                  _switchRow(
                    Icons.lyrics_outlined,
                    context.l10n.desktopLyrics,
                    context.l10n.settingsPageSectionsSwitchRow9,
                    app.desktopLyricsOn,
                    (v) async {
                      final l10n = context.l10n;
                      if (v && Platform.isAndroid) {
                        // 开启时先请求悬浮窗权限（未授权会拉起系统授权页）
                        final ok = await AndroidLyricsOverlay.instance
                            .requestPermission();
                        if (!ok) {
                          if (mounted) {
                            _toast(l10n.playerPageToggleDesktopLyricsToast);
                          }
                          return; // 保持关闭
                        }
                      }
                      app.setDesktopLyricsOn(v);
                    },
                  ),
                  _switchRow(
                    Icons.cell_tower,
                    context.l10n.settingsPageSectionsSwitchRow2,
                    context.l10n.settingsPageSectionsSwitchRow25,
                    app.lyricsLibraryBroadcastOn,
                    (v) async {
                      final l10n = context.l10n;
                      try {
                        await LyricsLibraryBroadcastService.instance.setEnabled(
                          v,
                        );
                        app.setLyricsLibraryBroadcastOn(v);
                      } catch (e) {
                        if (mounted) {
                          _toast(
                            v
                                ? l10n.settingsPageSectionsToast5(
                                    (e).toString(),
                                  )
                                : l10n.settingsPageSectionsToast4(
                                    (e).toString(),
                                  ),
                          );
                        }
                      }
                    },
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(14, 4, 14, 4),
                    child: Row(
                      children: [
                        Icon(Icons.format_size, size: 17, color: p.accent),
                        const SizedBox(width: 12),
                        Text(
                          context.l10n.settingsPageSectionsText6,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
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
                    label: context.l10n.settingsPageSectionsLabel,
                    value: app.lyricsColor,
                    onChanged: (v) => app.setLyricsColor(v),
                    hexCtrl: _colorHexCtrl,
                  ),
                  _colorRow(
                    icon: Icons.border_color_outlined,
                    label: context.l10n.settingsPageSectionsLabel2,
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
                        Expanded(
                          child: Text(
                            context.l10n.settingsPageSectionsText5,
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
                  _lockRow(
                    context.l10n.settingsPageSectionsLockRow,
                    app.lyricsLockedDesktop,
                    () {
                      app.setLyricsLockedDesktop(false);
                    },
                  ),
                  _lockRow(
                    context.l10n.settingsPageSectionsLockRow3,
                    app.lyricsLockedPortrait,
                    () {
                      app.setLyricsLockedPortrait(false);
                    },
                  ),
                  _lockRow(
                    context.l10n.settingsPageSectionsLockRow2,
                    app.lyricsLockedLandscape,
                    () {
                      app.setLyricsLockedLandscape(false);
                    },
                    showDivider: false,
                  ),
                ]),
                rootVisible: false,
                rootCardRadius: BorderRadius.zero,
              ),
              _section(
                'playback',
                context.l10n.play,
                _group([
                  _switchRow(
                    Icons.content_paste_search,
                    context.l10n.settingsPageSectionsSwitchRow3,
                    context.l10n.settingsPageSectionsSwitchRow15,
                    app.clipboardDetect,
                    (v) {
                      app.setClipboardDetect(v);
                    },
                  ),
                  _switchRow(
                    Icons.restart_alt_outlined,
                    context.l10n.settingsPageSectionsSwitchRow7,
                    context.l10n.settingsPageSectionsSwitchRow24,
                    app.doNotRememberPlaybackProgress,
                    app.setDoNotRememberPlaybackProgress,
                  ),
                  _switchRow(
                    Icons.speed,
                    context.l10n.playbackSpeedEntry,
                    context.l10n.playbackSpeedEntryDescription,
                    app.playbackSpeedEnabled,
                    app.setPlaybackSpeedEnabled,
                  ),
                  _row(
                    icon: Icons.fast_rewind,
                    title: context.l10n.settingsPageSectionsTitle3,
                    sub: context.l10n.settingsPageSectionsSub6,
                    trailing: PlaybackSeekSecondsControl(
                      label: context.l10n.seekBackward,
                      value: app.playbackSeekBackwardSeconds,
                      onChanged: app.setPlaybackSeekBackwardSeconds,
                    ),
                  ),
                  _row(
                    icon: Icons.fast_forward,
                    title: context.l10n.settingsPageSectionsTitle4,
                    sub: context.l10n.settingsPageSectionsSub6,
                    trailing: PlaybackSeekSecondsControl(
                      label: context.l10n.seekForward,
                      value: app.playbackSeekForwardSeconds,
                      onChanged: app.setPlaybackSeekForwardSeconds,
                    ),
                  ),
                  _row(
                    icon: Icons.keyboard_outlined,
                    title: context.l10n.playbackShortcuts,
                    trailing: Icon(Icons.chevron_right, size: 20, color: p.dim),
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => SettingsPage(
                          app: app,
                          sectionKey: 'playback_shortcuts',
                        ),
                      ),
                    ),
                  ),
                  if (Platform.isAndroid) ...[
                    _switchRow(
                      Icons.headphones_outlined,
                      context.l10n.settingsPageSectionsSwitchRow8,
                      context.l10n.settingsPageSectionsSwitchRow18,
                      app.earPause,
                      (v) => app.setEarPause(v),
                    ),
                    _switchRow(
                      Icons.speaker_group_outlined,
                      context.l10n.settingsPageSectionsSwitchRow5,
                      context.l10n.settingsPageSectionsSwitchRow19,
                      app.ignoreAudioFocus,
                      (v) => app.setIgnoreAudioFocus(v),
                    ),
                  ],
                  if (Platform.isAndroid)
                    _row(
                      icon: _batteryIgnoring == true
                          ? Icons.battery_saver
                          : Icons.battery_alert_outlined,
                      title: context.l10n.settingsPageSectionsTitle10,
                      sub: _batteryIgnoring == true
                          ? context.l10n.settingsPageSectionsSub7
                          : context.l10n.settingsPageSectionsSub4,
                      onTap: _requestBatteryIgnore,
                      trailing: _batteryIgnoring == null
                          ? null
                          : _miniBtn(
                              _batteryIgnoring!
                                  ? context.l10n.settingsPageSectionsMiniBtn4
                                  : context.l10n.settingsPageSectionsMiniBtn3,
                              _requestBatteryIgnore,
                            ),
                    ),
                  if (Platform.isWindows)
                    _switchRow(
                      Icons.desktop_windows_outlined,
                      context.l10n.settingsPageSectionsSwitchRow10,
                      app.keepTrayOnClose
                          ? context.l10n.settingsPageSectionsSwitchRow23
                          : context.l10n.settingsPageSectionsSwitchRow22,
                      app.keepTrayOnClose,
                      app.setKeepTrayOnClose,
                    ),
                  _mediaCacheLimitRow(showDivider: false),
                ]),
                rootVisible: false,
                rootEntry: true,
                rootCardRadius: BorderRadius.zero,
              ),
              _section(
                'tracks',
                context.l10n.settingsPageSectionsSection,
                _group([
                  _switchRow(
                    Icons.route_outlined,
                    context.l10n.settingsPageSectionsSwitchRow,
                    context.l10n.settingsPageSectionsSwitchRow14,
                    app.initialPathBehavior == 'auto',
                    (v) => app.setInitialPathBehavior(v ? 'auto' : 'root'),
                    showDivider: app.initialPathBehavior == 'auto',
                  ),
                  if (app.initialPathBehavior == 'auto') ...[
                    _switchRow(
                      Icons.hearing_outlined,
                      context.l10n.settingsPageSectionsSwitchRow4,
                      context.l10n.settingsPageSectionsSwitchRow13,
                      app.sePreference,
                      (v) => app.setSePreference(v),
                    ),
                    _row(
                      icon: Icons.audiotrack_outlined,
                      title: context.l10n.settingsPageSectionsTitle8,
                      sub: app.audioTypePreference.join(' > '),
                      onTap: _editAudioTypePreference,
                      trailing: Icon(
                        Icons.drag_indicator,
                        size: 18,
                        color: p.dim,
                      ),
                      showDivider: false,
                    ),
                  ],
                ]),
                rootVisible: false,
                rootEntry: true,
                rootCardRadius: BorderRadius.zero,
              ),
              _section(
                'privacy',
                context.l10n.settingsPageSectionTitleText,
                _group([
                  _switchRow(
                    Icons.notifications_off_outlined,
                    context.l10n.settingsPageSectionsSwitchRow11,
                    context.l10n.settingsPageSectionsSwitchRow20,
                    app.lsCover,
                    app.setLsCover,
                  ),
                  _switchRow(
                    Icons.branding_watermark_outlined,
                    context.l10n.settingsPageSectionsSwitchRow21,
                    context.l10n.settingsPageSectionsSwitchRow26,
                    app.notifCover,
                    app.setNotifCover,
                  ),
                  _switchRow(
                    Icons.privacy_tip_outlined,
                    context.l10n.settingsPageSectionsSwitchRow12,
                    context.l10n.settingsPageSectionsSwitchRow16,
                    app.releaseInterface,
                    app.setReleaseInterface,
                    showDivider: false,
                  ),
                ]),
                rootVisible: false,
                rootCardRadius: BorderRadius.zero,
                // 下一张卡（数据与网络）是圆角收尾卡，它自己的上边框负责这条线
                bottomDivider: false,
              ),
              _section(
                'other',
                context.l10n.settingsPageSectionsSection2,
                Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    DataSyncSettings(rowBuilder: _row, groupBuilder: _group),
                    const SizedBox(height: 10),
                    _group([_proxySettings()]),
                  ],
                ),
                rootVisible: false,
                rootEntry: true,
                rootCardRadius: const BorderRadius.vertical(
                  bottom: Radius.circular(16),
                ),
                rootCardMargin: const EdgeInsets.only(bottom: 14),
              ),
              _section(
                'appearance',
                context.l10n.settingsPageSectionsSection3,
                _group([
                  Padding(
                    padding: const EdgeInsets.fromLTRB(14, 10, 14, 6),
                    child: Row(
                      children: [
                        Icon(
                          Icons.zoom_out_map_outlined,
                          size: 17,
                          color: p.accent,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            context.l10n.settingsPageSectionsText7,
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
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 12,
                    ),
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
                        Text(
                          context.l10n.settingsPageSectionsText,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const Spacer(),
                        // 三段按钮按内容自适应宽度，不撑满整行
                        SegmentedButton<ThemeMode>(
                          segments: [
                            ButtonSegment(
                              value: ThemeMode.system,
                              label: Text(context.l10n.followSystem),
                            ),
                            ButtonSegment(
                              value: ThemeMode.light,
                              label: Text(
                                context.l10n.settingsPageSectionsText2,
                              ),
                            ),
                            ButtonSegment(
                              value: ThemeMode.dark,
                              label: Text(
                                context.l10n.settingsPageSectionsText3,
                              ),
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
                            // 选中段加一圈同色细边：浅色调下 12% 底色对比很弱，
                            // 只靠底色不容易一眼看出当前选的是哪一段
                            side: WidgetStateProperty.resolveWith(
                              (states) => BorderSide(
                                color: states.contains(WidgetState.selected)
                                    ? p.accent.withValues(alpha: .6)
                                    : p.line,
                                width: 1,
                              ),
                            ),
                            // 视觉高度收窄到与设置页其它内联控件（如 _selectPill）齐平；
                            // 点击热区仍由 MaterialTapTargetSize.padded 保证 48
                            minimumSize: const WidgetStatePropertyAll(
                              Size(0, 36),
                            ),
                            // 字号只在这里定义：段内 Text 不再各写一个 fontSize，
                            // 否则 11.5 与 12 互相覆盖，且字重拿不到 w600
                            textStyle: const WidgetStatePropertyAll(
                              TextStyle(
                                fontFamily: kAppFontFamily,
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            padding: const WidgetStatePropertyAll(
                              EdgeInsets.symmetric(horizontal: 10),
                            ),
                            visualDensity: VisualDensity.compact,
                          ),
                          // 设置页切换主题：圆形揭示从窗口中心扩散
                          onSelectionChanged: (s) =>
                              ThemeReveal.instance.fromCenter(s.first),
                        ),
                      ],
                    ),
                  ),
                ]),
                rootVisible: true,
              ),
              _section(
                'other',
                context.l10n.settingsPageSectionsSection2,
                _group([
                  _row(
                    icon: Icons.restart_alt,
                    title: context.l10n.settingsPageSectionsTitle12,
                    sub: context.l10n.settingsPageSectionsSub5,
                    onTap: _confirmReset,
                    trailing: Text(
                      context.l10n.settingsPageSectionsText4,
                      style: TextStyle(fontSize: 12, color: p.red),
                    ),
                    showDivider: false,
                  ),
                ]),
                rootVisible: false,
                rootEntry: false,
              ),
              _section(
                'about',
                context.l10n.settingsPageSectionsSection4,
                _group([
                  _switchRow(
                    Icons.system_update_outlined,
                    context.l10n.settingsPageSectionsSwitchRow6,
                    context.l10n.settingsPageSectionsSwitchRow17,
                    app.updateCheckEnabled,
                    app.setUpdateCheckEnabled,
                  ),
                  _row(
                    icon: Icons.refresh_outlined,
                    title: context.l10n.settingsPageSectionsTitle5,
                    sub: context.l10n.settingsPageSectionsSub2,
                    onTap: () => UpdateService.checkManually(context, app),
                  ),
                  _row(
                    icon: null,
                    title: context.l10n.settingsPageSectionsTitle,
                    sub: null,
                    trailing: Text(
                      'Kikoeta ${UpdateService.currentVersion}',
                      style: TextStyle(fontSize: 12),
                    ),
                    onTap: _onVersionTap,
                  ),
                  _row(
                    icon: null,
                    title: context.l10n.settingsPageSectionsTitle2,
                    sub: null,
                    trailing: const Text(
                      'https://github.com/chenflxs/kikoeta',
                      style: TextStyle(fontSize: 12),
                    ),
                    onTap: _openRepo,
                    showDivider: false,
                  ),
                ]),
              ),
              _section(
                'playback_shortcuts',
                context.l10n.playbackShortcuts,
                _group([
                  _playbackShortcutRow(
                    icon: Icons.play_circle_outline,
                    title: context.l10n.settingsPageSectionsTitle14,
                    action: 'toggle',
                    keyId: app.playbackToggleShortcutKey,
                    onChanged: app.setPlaybackToggleShortcutKey,
                  ),
                  _playbackShortcutRow(
                    icon: Icons.skip_previous_outlined,
                    title: context.l10n.settingsPageSectionsTitle9,
                    action: 'previous',
                    keyId: app.playbackPreviousShortcutKey,
                    onChanged: app.setPlaybackPreviousShortcutKey,
                  ),
                  _playbackShortcutRow(
                    icon: Icons.skip_next_outlined,
                    title: context.l10n.settingsPageSectionsTitle11,
                    action: 'next',
                    keyId: app.playbackNextShortcutKey,
                    onChanged: app.setPlaybackNextShortcutKey,
                  ),
                  _playbackShortcutRow(
                    icon: Icons.fast_rewind,
                    title: context.l10n.settingsPageSectionsTitle6,
                    action: 'seek_backward',
                    keyId: app.playbackSeekBackwardShortcutKey,
                    onChanged: app.setPlaybackSeekBackwardShortcutKey,
                  ),
                  _playbackShortcutRow(
                    icon: Icons.fast_forward,
                    title: context.l10n.settingsPageSectionsTitle7,
                    action: 'seek_forward',
                    keyId: app.playbackSeekForwardShortcutKey,
                    onChanged: app.setPlaybackSeekForwardShortcutKey,
                  ),
                  _row(
                    icon: Icons.restart_alt_outlined,
                    title: context.l10n.settingsPageSectionsTitle13,
                    sub: context.l10n.settingsPageSectionsSub9,
                    trailing: Icon(Icons.refresh, size: 18, color: p.dim),
                    onTap: app.resetPlaybackShortcutKeys,
                    showDivider: false,
                  ),
                ]),
                rootVisible: false,
                rootEntry: false,
              ),
            ];
            // Keep the detailed settings pages as a single readable column.
            // The root page follows the same wide two-column treatment as the
            // dictation translation page, while retaining the connected
            // navigation-row group in the right column.
            final isWideRoot =
                _sectionKey == null && constraints.maxWidth >= 900;
            final content = isWideRoot
                ? Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [sections[0], sections[8], sections[10]],
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: sections.sublist(1, 8),
                        ),
                      ),
                    ],
                  )
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: sections,
                  );
            return SmoothSingleChildScrollView(
              padding: EdgeInsets.fromLTRB(
                16,
                _sectionKey == null ? 4 : 8,
                16,
                40,
              ),
              child: Align(
                alignment: Alignment.topCenter,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 1120),
                  child: content,
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  String _sectionTitle(String key) => switch (key) {
    'translation' => context.l10n.languageAndTranslation,
    'lyrics_desktop' => context.l10n.settingsPageSectionsSection6,
    'playback' => context.l10n.play,
    'playback_shortcuts' => context.l10n.playbackShortcuts,
    'tracks' => context.l10n.settingsPageSectionsSection,
    'privacy' => context.l10n.settingsPageSectionTitleText,
    'other' => context.l10n.settingsPageSectionsSection2,
    _ => key,
  };

  Widget _section(
    String key,
    String title,
    Widget content, {
    bool rootVisible = true,
    bool rootEntry = true,
    BorderRadius? rootCardRadius,
    EdgeInsets? rootCardMargin,
    bool bottomDivider = true,
  }) {
    if (_sectionKey != null) {
      return _sectionKey == key
          ? Padding(padding: const EdgeInsets.only(bottom: 10), child: content)
          : const SizedBox.shrink();
    }
    if (rootVisible) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [_sec(title), content],
      );
    }
    if (!rootEntry) return const SizedBox.shrink();
    final hasTopRadius =
        rootCardRadius != null &&
        (rootCardRadius.topLeft.x > 0 || rootCardRadius.topRight.x > 0);
    final hasBottomRadius =
        rootCardRadius != null &&
        (rootCardRadius.bottomLeft.x > 0 || rootCardRadius.bottomRight.x > 0);
    final row = _row(
      icon: _sectionIcon(key),
      title: title,
      sub: context.l10n.settingsPageRowSub,
      trailing: Icon(Icons.chevron_right, size: 20, color: p.dim),
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => SettingsPage(app: app, sectionKey: key),
        ),
      ),
      // 有圆角的卡片由它自己的边框负责上/下那条分隔线：
      // _row 再画一条会差 1px，两条线叠成 2px 的粗线
      showDivider: bottomDivider && !hasBottomRadius && !hasTopRadius,
    );
    if (rootCardRadius == null) return row;
    return Container(
      margin: rootCardMargin,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: p.surface,
        // 有圆角时必须用「均匀」边框：Flutter 的非均匀 Border（只画部分边）会忽略
        // borderRadius，release 下按直角把边画到圆角之外（圆角处多出一小段方角，
        // 就是鼠标划过时看到的那块异常阴影），debug 下更是直接断言失败。
        // 均匀边框沿圆角路径绘制，圆角才正确。
        border: hasTopRadius || hasBottomRadius
            ? Border.all(color: p.line)
            : Border(
                left: BorderSide(color: p.line),
                right: BorderSide(color: p.line),
              ),
        borderRadius: rootCardRadius,
      ),
      // 同 _group：让卡片自带墨水层，悬停高亮才受这张卡的圆角裁剪
      child: Material(type: MaterialType.transparency, child: row),
    );
  }

  IconData _sectionIcon(String key) => switch (key) {
    'translation' => Icons.translate_outlined,
    'lyrics_desktop' => Icons.lyrics_outlined,
    'playback' => Icons.play_arrow_outlined,
    'tracks' => Icons.audiotrack_outlined,
    'privacy' => Icons.privacy_tip_outlined,
    'other' => Icons.tune_outlined,
    _ => Icons.settings_outlined,
  };

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
    width: double.infinity,
    clipBehavior: Clip.antiAlias,
    decoration: BoxDecoration(
      color: p.surface,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: p.line),
    ),
    // 卡片内的悬停高亮 / 水波纹由最近的 Material 绘制。卡片自带一层透明 Material，
    // 墨水才会被这张卡自己的圆角裁掉；否则会画到页面级 Material 上（在卡片裁剪之外），
    // 鼠标划过时圆角缺口处就会漏出一块方形灰影。
    child: Material(
      type: MaterialType.transparency,
      child: Column(children: children),
    ),
  );

  Widget _row({
    IconData? icon,
    required String title,
    String? sub,
    Widget? trailing,
    VoidCallback? onTap,
    bool showDivider = true,
  }) {
    final content = Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
      decoration: showDivider
          ? BoxDecoration(
              border: Border(bottom: BorderSide(color: p.line)),
            )
          : null,
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
    final l10n = context.l10n;
    final ok = await launchUrl(
      Uri.parse('https://github.com/chenflxs/kikoeta'),
      mode: LaunchMode.externalApplication,
    );
    if (!ok) _toast(l10n.settingsPageOpenRepoToast);
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
          title: Text(
            context.l10n.settingsPageOnVersionTapText2,
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
          ),
          content: Text(
            context.l10n.settingsPageOnVersionTapText3,
            style: TextStyle(fontSize: 13),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(
                context.l10n.settingsPageOnVersionTapText,
                style: TextStyle(color: p.accent),
              ),
            ),
          ],
        ),
      );
      return;
    }
    if (_devTaps > 3) {
      _toast(
        context.l10n.settingsPageOnVersionTapToast((7 - _devTaps).toString()),
      );
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
    ValueChanged<bool> onChanged, {
    bool showDivider = true,
  }) {
    return _row(
      icon: icon,
      title: title,
      sub: sub,
      showDivider: showDivider,
      trailing: Switch(
        value: value,
        onChanged: onChanged,
        activeTrackColor: p.accent,
      ),
    );
  }

  Widget _playbackShortcutRow({
    required IconData icon,
    required String title,
    required String action,
    required int keyId,
    bool physical = false,
    required ValueChanged<int> onChanged,
  }) {
    return _row(
      icon: icon,
      title: title,
      sub: context.l10n.settingsPagePlaybackShortcutRowSub,
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            _shortcutLabel(keyId, physical: physical),
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: p.accent,
            ),
          ),
          const SizedBox(width: 6),
          Icon(Icons.chevron_right, size: 18, color: p.dim),
        ],
      ),
      onTap: () => _editPlaybackShortcut(
        action: action,
        title: title,
        keyId: keyId,
        physical: physical,
        onChanged: onChanged,
      ),
    );
  }

  String _shortcutLabel(int keyId, {bool physical = false}) {
    final key = LogicalKeyboardKey.findKeyByKeyId(keyId);
    if (key == LogicalKeyboardKey.space) return 'Space';
    if (key == LogicalKeyboardKey.pageUp) return 'PageUp';
    if (key == LogicalKeyboardKey.pageDown) return 'PageDown';
    if (key == LogicalKeyboardKey.arrowLeft) {
      return context.l10n.settingsPageShortcutLabelText3;
    }
    if (key == LogicalKeyboardKey.arrowRight) {
      return context.l10n.settingsPageShortcutLabelText2;
    }
    return key?.debugName ??
        key?.keyLabel ??
        context.l10n.settingsPageShortcutLabelText;
  }

  Future<void> _editPlaybackShortcut({
    required String action,
    required String title,
    required int keyId,
    required bool physical,
    required ValueChanged<int> onChanged,
  }) async {
    final l10n = context.l10n;
    final focusNode = FocusNode();
    try {
      final nextKeyId = await showDialog<int>(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: p.surface,
          title: Text(
            title,
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
          ),
          content: KeyboardListener(
            focusNode: focusNode,
            autofocus: true,
            onKeyEvent: (event) {
              if (event is! KeyDownEvent) return;
              final key = event.logicalKey;
              if (key == LogicalKeyboardKey.escape) {
                Navigator.of(ctx).pop();
              } else if (!_isModifierKey(key)) {
                Navigator.of(
                  ctx,
                ).pop(physical ? event.physicalKey.usbHidUsage : key.keyId);
              }
            },
            child: SizedBox(
              width: 260,
              child: Text(
                l10n.settingsPageNextKeyIdText(
                  (_shortcutLabel(keyId, physical: physical)).toString(),
                ),
                style: TextStyle(fontSize: 13, color: p.text),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: Text(l10n.cancel),
            ),
          ],
        ),
      );
      if (!mounted || nextKeyId == null) return;
      final conflict = _shortcutConflict(action, nextKeyId, physical: physical);
      if (conflict != null) {
        _toast(
          l10n.settingsPageEditPlaybackShortcutToast((conflict).toString()),
        );
        return;
      }
      onChanged(nextKeyId);
    } finally {
      focusNode.dispose();
    }
  }

  String? _shortcutConflict(
    String action,
    int keyId, {
    required bool physical,
  }) {
    if (physical) {
      if (action != 'seek_forward' &&
          keyId == app.playbackSeekForwardShortcutKey) {
        return context.l10n.seekForward;
      }
      if (action != 'seek_backward' &&
          keyId == app.playbackSeekBackwardShortcutKey) {
        return context.l10n.seekBackward;
      }
      return null;
    }
    if (action != 'toggle' && keyId == app.playbackToggleShortcutKey) {
      return context.l10n.settingsPageShortcutConflictText3;
    }
    if (action != 'previous' && keyId == app.playbackPreviousShortcutKey) {
      return context.l10n.settingsPageShortcutConflictText2;
    }
    if (action != 'next' && keyId == app.playbackNextShortcutKey) {
      return context.l10n.settingsPageShortcutConflictText;
    }
    return null;
  }

  bool _isModifierKey(LogicalKeyboardKey key) =>
      key == LogicalKeyboardKey.controlLeft ||
      key == LogicalKeyboardKey.controlRight ||
      key == LogicalKeyboardKey.shiftLeft ||
      key == LogicalKeyboardKey.shiftRight ||
      key == LogicalKeyboardKey.altLeft ||
      key == LogicalKeyboardKey.altRight ||
      key == LogicalKeyboardKey.metaLeft ||
      key == LogicalKeyboardKey.metaRight;

  Widget _mediaCacheLimitRow({bool showDivider = true}) {
    final limit = app.mediaCacheLimitMb;
    final label = limit < 1024
        ? '$limit MB'
        : '${(limit / 1024).toStringAsFixed(limit % 1024 == 0 ? 0 : 1)} GB';

    return Container(
      padding: const EdgeInsets.fromLTRB(14, 13, 14, 10),
      decoration: showDivider
          ? BoxDecoration(
              border: Border(bottom: BorderSide(color: p.line)),
            )
          : null,
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
                    Expanded(
                      child: Text(
                        context.l10n.settingsPageMediaCacheLimitRowText,
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
                  context.l10n.settingsPageMediaCacheLimitRowText2,
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
              ? context.l10n.settingsPageStatusStatus4(
                  (_proxyCtrl.text.trim()).toString(),
                )
              : context.l10n.settingsPageStatusStatus2
        : hasAddress
        ? context.l10n.settingsPageStatusStatus
        : context.l10n.settingsPageStatusStatus3;

    return Column(
      children: [
        _switchRow(
          Icons.vpn_lock_outlined,
          context.l10n.settingsPageProxySettingsSwitchRow,
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
              labelText: context.l10n.loginPageShowProxyDialogLabelText,
              labelStyle: TextStyle(fontSize: 12, color: p.muted),
              hintText: context.l10n.loginPageShowProxyDialogHintText,
              hintStyle: TextStyle(fontSize: 12, color: p.dim),
              helperText: enabled
                  ? context.l10n.settingsPageProxySettingsHelperText
                  : context.l10n.settingsPageProxySettingsHelperText2,
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
                      tooltip: context.l10n.settingsPageProxySettingsTooltip,
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
          title: Text(
            context.l10n.settingsPageSectionsTitle8,
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
              child: Text(context.l10n.settingsPageEditAudioTypePreferenceText),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(context.l10n.cancel),
            ),
            TextButton(
              onPressed: () {
                app.setAudioTypePreference(List.of(order));
                Navigator.pop(ctx);
              },
              child: Text(context.l10n.save),
            ),
          ],
        ),
      ),
    );
  }

  /// 请求关闭省电优化（安卓）：拉起系统「忽略电池优化」授权页
  Future<void> _requestBatteryIgnore() async {
    final l10n = context.l10n;
    if (!Platform.isAndroid) return;
    final v = await AndroidBattery.instance.requestIgnore();
    if (mounted) setState(() => _batteryIgnoring = v);
    if (v != true && mounted) {
      _toast(l10n.settingsPageRequestBatteryIgnoreToast);
    }
  }

  /// 完全重置：5 秒倒计时确认 → 停止播放/隐藏悬浮窗 → 清空全部数据 → 自动回到登录页
  Future<void> _confirmReset() async {
    final l10n = context.l10n;
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
    await LyricsLibraryBroadcastService.instance.stop();
    // 清空内存 + SQLite（loginRequired 回到 true，自动切到登录页）
    app.resetAll();
    LyricsLibraryService.instance.resetIndexCache();
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(content: Text(l10n.settingsPageConfirmResetText)),
      );
  }

  void _selectEngine(String engine) {
    app.setEngine(engine);
    _aiBase.text = app.activeAiConfig['base']!;
    _aiModel.text = app.activeAiConfig['model']!;
    _aiKey.text = app.activeAiConfig['key']!;
    setState(() {});
  }

  Widget _engineDropdown() {
    final labels = {
      'google': 'Google',
      'microsoft': 'Microsoft',
      'deepl': 'DeepL',
      'index': 'Index-Translate',
      'openai': context.l10n.settingsPageLabelsLabels,
    };
    return _translationDropdown(
      label: labels[app.engine]!,
      icon: Icons.translate_outlined,
      tooltip: context.l10n.translationEngine,
      items: [
        _menuHead(context, context.l10n.translationEngine),
        ...labels.entries.map(
          (e) => PopupMenuItem(
            value: e.key,
            height: 42,
            child: MenuItem(label: e.value, selected: app.engine == e.key),
          ),
        ),
      ],
      onSelected: _selectEngine,
    );
  }

  Widget _translationTargetDropdown() {
    final labels = {
      'ui': context.l10n.followInterfaceLanguage,
      'zh-CN': context.l10n.simplifiedChineseShort,
      'zh-TW': context.l10n.traditionalChineseShort,
      'en': context.l10n.englishLanguage,
    };
    return _translationDropdown(
      label: labels[app.translationTarget]!,
      icon: Icons.language_outlined,
      tooltip: context.l10n.translationTargetLanguage,
      items: [
        _menuHead(context, context.l10n.targetLanguage),
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

  Widget _uiLanguageDropdown() {
    final labels = {
      'system': context.l10n.followSystem,
      'zh-CN': context.l10n.simplifiedChinese,
      'zh-TW': context.l10n.traditionalChinese,
      'ja': '日本語',
      'en': 'English (beta)',
      'ru': 'Русский',
    };
    return _translationDropdown(
      label: labels[app.uiLanguage]!,
      icon: Icons.language_outlined,
      tooltip: context.l10n.interfaceLanguage,
      items: [
        _menuHead(context, context.l10n.interfaceLanguage),
        ...labels.entries.map((entry) {
          final enabled = AppLanguage.selectablePreferences.contains(entry.key);
          return PopupMenuItem<String>(
            value: entry.key,
            enabled: enabled,
            height: 42,
            child: MenuItem(
              label: entry.value,
              selected: app.uiLanguage == entry.key,
              enabled: enabled,
            ),
          );
        }),
      ],
      onSelected: app.setUiLanguage,
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
      // 悬停高亮跟随 child 的圆角（8），否则从圆角缺口漏出方形灰影
      borderRadius: BorderRadius.circular(8),
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
    final labels = {
      'orig': context.l10n.close,
      'tw': context.l10n.simplifiedToTraditional,
      'zh': context.l10n.traditionalToSimplified,
    };
    return _selectPill(
      labels[app.conv]!,
      (ctx) => [
        _menuHead(ctx, context.l10n.chineseConversion),
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
      // _selectPill 的 child 是胶囊形（999），悬停高亮同样要跟着圆角走
      borderRadius: BorderRadius.circular(999),
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
            labelText: context.l10n.settingsPageAiModelInputLabelText,
            labelStyle: TextStyle(fontSize: 11.5, color: p.muted),
            hintText: hasModels
                ? context.l10n.settingsPageAiModelInputHintText
                : context.l10n.settingsPageAiModelInputHintText2,
            hintStyle: TextStyle(fontSize: 12, color: p.dim),
            helperText: hasModels
                ? context.l10n.settingsPageAiModelInputHelperText(
                    (app.openAiModels.length).toString(),
                  )
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
              tooltip: hasModels
                  ? context.l10n.settingsPageAiModelInputTooltip
                  : context.l10n.settingsPageAiModelInputTooltip2,
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

  Widget _lockRow(
    String label,
    bool locked,
    VoidCallback onUnlock, {
    bool showDivider = true,
  }) {
    return _row(
      icon: locked ? Icons.lock_outline : Icons.lock_open_outlined,
      title: context.l10n.settingsPageLockRowTitle((label).toString()),
      sub: locked
          ? context.l10n.settingsPageLockRowSub2
          : context.l10n.settingsPageLockRowSub,
      showDivider: showDivider,
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
                  context.l10n.settingsPageLockRowText,
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
      title: Row(
        children: [
          Icon(Icons.warning_amber_rounded, color: Colors.deepOrange, size: 22),
          SizedBox(width: 8),
          Text(context.l10n.settingsPageBuildText),
        ],
      ),
      content: Text(
        context.l10n.settingsPageBuildText4,
        style: TextStyle(fontSize: 13.5, height: 1.5),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: Text(context.l10n.cancel),
        ),
        TextButton(
          onPressed: canConfirm ? () => Navigator.pop(context, true) : null,
          style: canConfirm
              ? TextButton.styleFrom(foregroundColor: Colors.red)
              : null,
          child: Text(
            canConfirm
                ? context.l10n.settingsPageBuildText2
                : context.l10n.settingsPageBuildText3((_count).toString()),
          ),
        ),
      ],
    );
  }
}
