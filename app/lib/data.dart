import 'dart:convert';
import 'dart:math';

import 'package:flutter/material.dart';

import 'services/android_audio.dart';
import 'services/player_service.dart';
import 'services/settings_store.dart';

enum Age { all, r15, r18 }

/// 同一作品的其它语言版本（由作品详情接口提供）。
class LanguageEdition {
  final int id;
  final String title;
  final String? language;
  final bool isOriginal;

  const LanguageEdition({
    required this.id,
    required this.title,
    this.language,
    this.isOriginal = false,
  });
}

class Work {
  final String rj;
  final String title;
  final String circle;
  final String va;
  final Age age;
  final String dur;
  final List<String> tags;
  final List<String> grayTags; // 低愿力标签（需投票，显示为灰色）
  final int grad; // 封面渐变索引
  final String? coverUrl;
  final bool hasSubtitle;
  final int? apiId;
  // 评价接口是否返回了当前用户的评价关联；null 表示接口未提供该字段。
  final bool? hasReview;
  final List<LanguageEdition> languageEditions;

  const Work({
    required this.rj,
    required this.title,
    required this.circle,
    required this.va,
    required this.age,
    required this.dur,
    required this.tags,
    this.grayTags = const [],
    required this.grad,
    this.coverUrl,
    this.hasSubtitle = false,
    this.apiId,
    this.hasReview,
    this.languageEditions = const [],
  });
}

/// 作品媒体树节点（文件夹 / 文件）
class MediaNode {
  final String title;
  final String type; // folder / file
  final String path;
  final List<MediaNode> children;
  final String? url;
  final int duration; // 音频时长（秒），文件夹为 0
  const MediaNode({
    required this.title,
    required this.type,
    required this.path,
    this.children = const [],
    this.url,
    this.duration = 0,
  });

  bool get isDir => type == 'folder';
}

class LyricLine {
  final int t;
  final String jp;
  final String zh;
  const LyricLine(this.t, this.jp, this.zh);
}

class CustomSite {
  String alias;
  String url;
  String user;
  String pass;
  CustomSite({
    required this.alias,
    required this.url,
    this.user = '',
    this.pass = '',
  });
}

/// 播放列表条目（关联作品信息）
class PlaylistEntry {
  final String rj;
  final String title;
  final String circle;
  final List<String> tracks;
  const PlaylistEntry({
    required this.rj,
    required this.title,
    required this.circle,
    this.tracks = const [],
  });
}

/// 服务器歌单（one 站）
class PlaylistInfo {
  final String id;
  final String name;
  final int worksCount;
  final String? coverUrl;
  final bool isSystemLiked;
  const PlaylistInfo({
    required this.id,
    required this.name,
    required this.worksCount,
    this.coverUrl,
    this.isSystemLiked = false,
  });
}

class AppState extends ChangeNotifier {
  ThemeMode themeMode = ThemeMode.system; // 跟随系统 / 浅色 / 深色
  int uiScalePercent = 100; // 应用 UI 缩放：25% - 200%，每档 25%
  int tab = 0; // 0 首页 / 1 收藏 / 2 更多

  // 服务器
  bool customServer = false;
  int customServerIdx = 0;
  final List<CustomSite> customSites = [];
  String asmrUser = '';
  String asmrPass = '';

  // 首页
  String category = 'all'; // all / hot / rec
  String sort = 'collect'; // 默认按收录时间
  bool orderAsc = false;
  int? randomSeed;
  String recommenderUuid = '';
  int serverEpoch = 0;
  int loginEpoch = 0;
  int? ageFilter; // null / 0(全年龄) / 1(R15) / 2(R18)
  bool subOnly = false;
  bool sfwMode = false; // SFW 模式：启动后只显示全年龄（非 R18）内容
  String? _pendingSearch;
  bool pendingClear = false;
  bool searchExpanded = false; // 搜索栏展开（Shell 层全屏遮罩用）

  // 远程数据（asmr.one）
  List<Work> remoteWorks = [];
  String? remoteError;
  bool loadingRemote = false;
  int worksPage = 1;
  bool worksLoadingMore = false;
  bool worksHasMore = true;
  Work? currentWork;
  List<MediaNode> queue = [];
  int trackIdx = 0;
  bool playing = false;
  int resumePosition = 0; // 上次播放位置（秒），重启恢复用（默认暂停）

  // 收藏 / 历史 / 播放列表 / 黑名单 / 标签
  final List<String> favoriteRjs = [];
  final Set<int> favIds = {}; // 服务器收藏的作品 API id
  int favVersion = 0; // 收藏变更版本（供收藏页刷新）
  int favoritesEntryVersion = 0; // 进入收藏页版本（每次切入时刷新）
  int homeRefreshVersion = 0; // 再次点击首页时刷新首页数据
  final List<String> history = [];
  final Map<String, List<PlaylistEntry>> playlists = {};
  final List<Map<String, dynamic>> playHistory = []; // {rj,title,circle,at}
  final List<Map<String, dynamic>> blacklist = []; // {type,value}
  final Map<String, Map<String, dynamic>> translated =
      {}; // rj -> {title, tracks}

  bool eqOn = true;
  final List<double> eqGains = List.filled(10, 0);
  String conv = 'orig'; // orig / zh / tw
  int playMode = 0; // 0 列表播放 / 1 循环播放 / 2 单曲循环

  // 播放器音量（0-200；响度提升依次解锁至 120、200）
  double volume = 100;
  int volumeBoostLevel = 0;
  bool get volumeBoost => volumeBoostLevel > 0;
  int get volumeMax => switch (volumeBoostLevel) {
    1 => 120,
    2 => 200,
    _ => 100,
  };

  // 设置开关
  bool clipboardDetect = true;
  bool lsCover = false; // 不显示通知栏媒体卡片（隐私）
  bool notifCover = false; // 通知栏封面显示项目 logo（隐私，暂无 logo 用占位图）
  bool releaseInterface = true;
  bool doNotRememberPlaybackProgress = false;
  // 安卓音频（默认关闭）
  bool earPause = false; // 拔出耳机自动暂停
  bool ignoreAudioFocus = false; // 忽略音频焦点

  // 智能路径（对齐 asmr.one：打开作品自动进入最佳目录）
  String initialPathBehavior = 'auto'; // auto / root
  bool sePreference = true; // 效果音偏好
  final List<String> audioTypePreference = [
    'mp3',
    'flac',
    'wav',
    'opus',
    'm4a',
    'aac',
  ];

  // 网络代理（仅 HTTP）
  bool httpProxyEnabled = false;
  String httpProxyUrl = '';

  // 更新服务检测
  bool updateCheckEnabled = true;
  String updateIgnoredVersion = '';

  // 在线播放缓冲上限（MB）；仅作用于 mpv 的媒体缓存，不影响未来下载。
  int mediaCacheLimitMb = 1024;

  // 桌面歌词
  bool desktopLyricsOn = false;
  double lyricsFontSize = 20;
  int lyricsColor = 0xFFFFFFFF;
  int lyricsOutlineColor = 0xFF000000;
  double lyricsOutlineWidth = 1;
  bool lyricsLockedDesktop = false; // 桌面端
  bool lyricsLockedPortrait = false; // 安卓竖屏
  bool lyricsLockedLandscape = false; // 安卓横屏

  // 翻译引擎
  String engine = 'google'; // google / deepl / openai
  String translationTarget = 'zh-CN'; // zh-CN / zh-TW / en
  final List<String> openAiModels = [];
  final Map<String, String> aiConfig = {'base': '', 'model': '', 'key': ''};
  String deeplKey = '';

  // Windows 关闭窗口后的行为
  bool keepTrayOnClose = true;

  // 定时关闭
  String sleepMode = 'after'; // after / at
  bool sleepPlayEndArmed = false; // 「播放完毕」模式已开启
  int sleepMin = 10;
  TimeOfDay? sleepTime;
  DateTime? sleepEndAt;

  void notify() => notifyListeners();

  /// 请求首页执行一次搜索（供作品详情点击社团/CV/标签跳转）
  void requestSearch(String q) {
    final t = q.trim();
    if (t.isEmpty) return;
    addHistory(t); // 所有入口（回车/历史/标签点击）都计入搜索历史
    _pendingSearch = t;
    tab = 0;
    notifyListeners();
  }

  /// 首页消费待执行搜索，返回后清空
  String? takePendingSearch() {
    final q = _pendingSearch;
    _pendingSearch = null;
    return q;
  }

  /// 非消费式读取待执行搜索（供搜索栏组件同步输入框文本）
  String? peekPendingSearch() => _pendingSearch;

  void setSearchExpanded(bool v) {
    if (searchExpanded == v) return;
    searchExpanded = v;
    notifyListeners();
  }

  /// 请求清空搜索（输入与结果）
  void requestSearchClear() {
    pendingClear = true;
    notifyListeners();
  }

  bool takePendingClear() {
    final v = pendingClear;
    pendingClear = false;
    return v;
  }

  List<Work> get homeList => remoteWorks;
  bool get hasQueue => queue.isNotEmpty;
  Work? get playWork => currentWork;

  /// 需要显示登录页：未登录 one 站（账密缺失）且未配置自建服务器
  bool get loginRequired =>
      (asmrUser.isEmpty || asmrPass.isEmpty) &&
      !(customServer && customSites.isNotEmpty);

  List<int> get homeOrder {
    final n = homeList.length;
    var order = List.generate(n, (i) => i);
    if (ageFilter != null) {
      order = order.where((i) => homeList[i].age.index == ageFilter).toList();
    }
    order = order.where((i) => !isBlacklistedWork(homeList[i])).toList();
    return order;
  }

  List<Work> get favoriteWorks =>
      remoteWorks.where((w) => favoriteRjs.contains(w.rj)).toList();

  void selectTab(int value) {
    final reselected = tab == value;
    tab = value;
    if (value == 1) favoritesEntryVersion++;
    if (reselected && value == 0) homeRefreshVersion++;
    notifyListeners();
  }

  void toggleFav(Work w) {
    if (favoriteRjs.contains(w.rj)) {
      favoriteRjs.remove(w.rj);
    } else {
      favoriteRjs.add(w.rj);
    }
    _persistFavs();
    notifyListeners();
  }

  /// 是否已收藏（服务器收藏 + 历史本地收藏兜底）
  bool isFavorited(Work w) =>
      favoriteRjs.contains(w.rj) ||
      (w.apiId != null && favIds.contains(w.apiId));

  /// 用作品详情中的评价关联刷新本地收藏镜像。
  void syncFavoriteFromServer(Work w, bool value) {
    var changed = false;
    if (value) {
      if (w.apiId != null) changed = favIds.add(w.apiId!) || changed;
      if (!favoriteRjs.contains(w.rj)) {
        favoriteRjs.add(w.rj);
        changed = true;
      }
    } else {
      if (w.apiId != null) changed = favIds.remove(w.apiId!) || changed;
      changed = favoriteRjs.remove(w.rj) || changed;
    }
    if (changed) {
      _persistFavs();
      notifyListeners();
    }
  }

  /// 收藏成功后记录（本地镜像，保持界面即时一致）
  void addFavorite(Work w) {
    if (w.apiId != null) favIds.add(w.apiId!);
    if (!favoriteRjs.contains(w.rj)) favoriteRjs.add(w.rj);
    favVersion++;
    _persistFavs();
    notifyListeners();
  }

  /// 取消收藏后移除本地镜像
  void removeFavorite(Work w) {
    if (w.apiId != null) favIds.remove(w.apiId!);
    favoriteRjs.remove(w.rj);
    favVersion++;
    _persistFavs();
    notifyListeners();
  }

  /// 用服务器收藏歌单的作品同步收藏状态
  void syncFavorites(List<Work> works) {
    favIds
      ..clear()
      ..addAll(works.where((w) => w.apiId != null).map((w) => w.apiId!));
    favoriteRjs
      ..clear()
      ..addAll(works.map((w) => w.rj));
    _persistFavs();
    notifyListeners();
  }

  void startPlayback(
    Work w,
    List<MediaNode> files, {
    int initialTrackIndex = 0,
  }) {
    currentWork = w;
    queue = List.of(files);
    trackIdx = initialTrackIndex.clamp(0, queue.length - 1);
    playing = true;
    resumePosition = 0;
    recordPlayHistory(w);
    // 播放器页面可能尚未建立，立即保存队列以覆盖异常退出窗口。
    savePlayState();
    notifyListeners();
  }

  // ---------- 播放状态记忆（重启恢复，默认暂停） ----------
  void savePlayState() {
    final w = currentWork;
    if (w == null || queue.isEmpty) {
      SettingsStore.set('play_state', '');
      return;
    }
    SettingsStore.set(
      'play_state',
      jsonEncode({
        'work': {
          'rj': w.rj,
          'title': w.title,
          'circle': w.circle,
          'va': w.va,
          'age': w.age.index,
          'dur': w.dur,
          'tags': w.tags,
          'grayTags': w.grayTags,
          'grad': w.grad,
          'coverUrl': w.coverUrl,
          'hasSubtitle': w.hasSubtitle,
          'apiId': w.apiId,
          'hasReview': w.hasReview,
        },
        'queue': queue.map(_nodeToJson).toList(),
        'trackIdx': trackIdx,
        'position': doNotRememberPlaybackProgress ? 0 : resumePosition,
      }),
    );
  }

  /// 清空播放状态记忆（重置/播放完成时）
  void clearPlayState() {
    SettingsStore.set('play_state', '');
    resumePosition = 0;
  }

  Map<String, dynamic> _nodeToJson(MediaNode n) => {
    'title': n.title,
    'type': n.type,
    'path': n.path,
    'children': n.children.map(_nodeToJson).toList(),
    if (n.url != null) 'url': n.url,
    if (n.duration > 0) 'duration': n.duration,
  };

  MediaNode _nodeFromJson(Map<String, dynamic> m) => MediaNode(
    title: m['title'] as String,
    type: m['type'] as String,
    path: m['path'] as String,
    children: ((m['children'] as List?) ?? const [])
        .map((e) => _nodeFromJson(e as Map<String, dynamic>))
        .toList(),
    url: m['url'] as String?,
    duration: (m['duration'] as num?)?.toInt() ?? 0,
  );

  void addToPlaylist(String name, List<String> titles) {
    // 兼容旧调用：无作品上下文时仅存标题
    addWorkToPlaylist(name, null, titles);
  }

  void addWorkToPlaylist(String name, Work? w, List<String> tracks) {
    final list = playlists.putIfAbsent(name, () => []);
    final entry = PlaylistEntry(
      rj: w?.rj ?? '',
      title: w?.title ?? (tracks.isNotEmpty ? tracks.first : name),
      circle: w?.circle ?? '',
      tracks: List.of(tracks),
    );
    list.add(entry);
    _persistPlaylists();
    notifyListeners();
  }

  void createPlaylist(String name) {
    final n = name.trim();
    if (n.isEmpty || playlists.containsKey(n)) return;
    playlists[n] = [];
    _persistPlaylists();
    notifyListeners();
  }

  void removeFromPlaylist(String name, int index) {
    final list = playlists[name];
    if (list == null || index < 0 || index >= list.length) return;
    list.removeAt(index);
    if (list.isEmpty) playlists.remove(name);
    _persistPlaylists();
    notifyListeners();
  }

  void renamePlaylist(String oldName, String newName) {
    if (oldName == newName || newName.trim().isEmpty) return;
    final list = playlists.remove(oldName);
    if (list != null) playlists[newName.trim()] = list;
    _persistPlaylists();
    notifyListeners();
  }

  void deletePlaylist(String name) {
    playlists.remove(name);
    _persistPlaylists();
    notifyListeners();
  }

  void addHistory(String q) {
    history.remove(q);
    history.insert(0, q);
    if (history.length > 10) history.removeRange(10, history.length);
    _persistSearchHistory();
    notifyListeners();
  }

  void clearHistory() {
    history.clear();
    _persistSearchHistory();
    notifyListeners();
  }

  void removeHistory(String query) {
    if (!history.remove(query)) return;
    _persistSearchHistory();
    notifyListeners();
  }

  /// 记录播放历史（去重、上限 50）
  void recordPlayHistory(Work w) {
    playHistory.removeWhere((e) => e['rj'] == w.rj);
    playHistory.insert(0, {
      'rj': w.rj,
      'title': w.title,
      'circle': w.circle,
      'coverUrl': w.coverUrl,
      'tags': w.tags,
      'grayTags': w.grayTags,
      'at': DateTime.now().millisecondsSinceEpoch,
    });
    if (playHistory.length > 50) {
      playHistory.removeRange(50, playHistory.length);
    }
    _persistPlayHistory();
    notifyListeners();
  }

  void clearPlayHistory() {
    playHistory.clear();
    _persistPlayHistory();
    notifyListeners();
  }

  bool isBlacklistedWork(Work w) {
    for (final b in blacklist) {
      final type = b['type'];
      final value = b['value'] ?? '';
      if (value.isEmpty) continue;
      if (type == 'rj' && w.rj == value) return true;
      if (type == 'circle' && w.circle == value) return true;
      if (type == 'va' && w.va.contains(value)) return true;
      if (type == 'tag' && w.tags.contains(value)) return true;
    }
    return false;
  }

  void toggleBlacklist(String type, String value) {
    final idx = blacklist.indexWhere(
      (e) => e['type'] == type && e['value'] == value,
    );
    if (idx >= 0) {
      blacklist.removeAt(idx);
    } else {
      blacklist.add({'type': type, 'value': value});
    }
    _persistBlacklist();
    notifyListeners();
  }

  void saveTranslated(String rj, String title, Map<String, String> tracks) {
    translated[rj] = {
      'title': title,
      'tracks': tracks,
      'at': DateTime.now().millisecondsSinceEpoch,
    };
    notifyListeners();
  }

  /// 取消翻译（恢复原文），仅清除内存，不记忆
  void removeTranslated(String rj) {
    translated.remove(rj);
    notifyListeners();
  }

  String? translatedTitle(String rj) =>
      (translated[rj]?['title'] as String?)?.isNotEmpty == true
      ? translated[rj]!['title'] as String
      : null;

  String? translatedTrack(String rj, String path) =>
      (translated[rj]?['tracks'] as Map<String, dynamic>?)?[path] as String?;

  // ---------- Rust 设置持久化 ----------
  Future<void> loadFromRust() async {
    final theme = SettingsStore.get('theme');
    if (theme == 'light') {
      themeMode = ThemeMode.light;
    } else if (theme == 'dark') {
      themeMode = ThemeMode.dark;
    } else {
      themeMode = ThemeMode.system;
    }
    final uiScale = int.tryParse(SettingsStore.get('ui_scale_percent') ?? '');
    if (uiScale != null) {
      uiScalePercent = _normalizeUiScalePercent(uiScale);
    }
    final engine = SettingsStore.get('engine');
    if (engine != null && engine.isNotEmpty) this.engine = engine;
    final asmrUser = SettingsStore.get('asmr_user');
    if (asmrUser != null && asmrUser.isNotEmpty) this.asmrUser = asmrUser;
    final asmrPass = SettingsStore.get('asmr_pass');
    if (asmrPass != null) this.asmrPass = asmrPass;
    final sites = SettingsStore.get('sites');
    if (sites != null && sites.isNotEmpty) {
      try {
        final list = jsonDecode(sites) as List;
        customSites
          ..clear()
          ..addAll(
            list.map(
              (e) => CustomSite(
                alias: e['alias'] as String,
                url: e['url'] as String,
                user: (e['user'] as String?) ?? '',
                pass: (e['pass'] as String?) ?? '',
              ),
            ),
          );
      } catch (_) {}
    }
    // 服务器选择持久化恢复（容错：无站点时回退 one 站）
    final srvCustom = SettingsStore.get('server_custom');
    if (srvCustom != null) customServer = srvCustom == '1';
    final srvIdx = SettingsStore.get('server_idx');
    if (srvIdx != null) customServerIdx = int.tryParse(srvIdx) ?? 0;
    if (customSites.isEmpty) customServer = false;
    if (customServer && customServerIdx >= customSites.length) {
      customServer = false;
      customServerIdx = 0;
    }
    final recommenderUuid = SettingsStore.get('recommender_uuid');
    if (recommenderUuid != null && recommenderUuid.isNotEmpty) {
      this.recommenderUuid = recommenderUuid;
    } else {
      this.recommenderUuid = _newRecommenderUuid();
      SettingsStore.set('recommender_uuid', this.recommenderUuid);
    }
    final volume = SettingsStore.get('volume');
    if (volume != null) {
      this.volume = (double.tryParse(volume) ?? 100)
          .clamp(0, volumeMax)
          .toDouble();
    }
    final cd = SettingsStore.get('clipboard_detect');
    if (cd != null) clipboardDetect = cd == '1';
    final lsCoverSetting = SettingsStore.get('ls_cover');
    if (lsCoverSetting != null) lsCover = lsCoverSetting == '1';
    final ep = SettingsStore.get('ear_pause');
    if (ep != null) earPause = ep == '1';
    final iae = SettingsStore.get('ignore_audio_focus');
    if (iae != null) ignoreAudioFocus = iae == '1';
    final ipb = SettingsStore.get('initial_path_behavior');
    if (ipb != null && ipb.isNotEmpty) initialPathBehavior = ipb;
    final sep = SettingsStore.get('se_preference');
    if (sep != null) sePreference = sep == '1';
    final atp = SettingsStore.get('audio_type_preference');
    if (atp != null && atp.isNotEmpty) {
      try {
        audioTypePreference
          ..clear()
          ..addAll((jsonDecode(atp) as List).cast<String>());
      } catch (_) {}
    }
    final sfw = SettingsStore.get('sfw');
    if (sfw == '1') {
      sfwMode = true;
      ageFilter = 0;
    }
    final dl = SettingsStore.get('desktop_lyrics');
    if (dl != null) desktopLyricsOn = dl == '1';
    final lfs = SettingsStore.get('lyrics_font_size');
    if (lfs != null) {
      lyricsFontSize = (double.tryParse(lfs) ?? 20).clamp(12, 64);
    }
    final lc = SettingsStore.get('lyrics_color');
    if (lc != null) lyricsColor = int.tryParse(lc) ?? 0xFFFFFFFF;
    final loc = SettingsStore.get('lyrics_outline_color');
    if (loc != null) lyricsOutlineColor = int.tryParse(loc) ?? 0xFF000000;
    final low = SettingsStore.get('lyrics_outline_width');
    if (low != null) {
      lyricsOutlineWidth = (double.tryParse(low) ?? 1).clamp(0, 4);
    }
    final lld = SettingsStore.get('lyrics_locked_desktop');
    if (lld != null) lyricsLockedDesktop = lld == '1';
    final llp = SettingsStore.get('lyrics_locked_portrait');
    if (llp != null) lyricsLockedPortrait = llp == '1';
    final lll = SettingsStore.get('lyrics_locked_landscape');
    if (lll != null) lyricsLockedLandscape = lll == '1';
    final conv = SettingsStore.get('conv');
    if (conv != null && conv.isNotEmpty) this.conv = conv;
    final eqOn = SettingsStore.get('eq_on');
    if (eqOn != null) this.eqOn = eqOn == '1';
    final eqGains = SettingsStore.get('eq_gains');
    if (eqGains != null && eqGains.isNotEmpty) {
      try {
        final list = jsonDecode(eqGains) as List;
        for (var i = 0; i < 10 && i < list.length; i++) {
          this.eqGains[i] = (list[i] as num).toDouble();
        }
      } catch (_) {}
    }
    final favs = SettingsStore.get('favs');
    if (favs != null && favs.isNotEmpty) {
      try {
        favoriteRjs
          ..clear()
          ..addAll((jsonDecode(favs) as List).cast<String>());
      } catch (_) {}
    }
    final sh = SettingsStore.get('search_history');
    if (sh != null && sh.isNotEmpty) {
      try {
        history
          ..clear()
          ..addAll((jsonDecode(sh) as List).cast<String>());
      } catch (_) {}
    }
    final ph = SettingsStore.get('play_history');
    if (ph != null && ph.isNotEmpty) {
      try {
        playHistory
          ..clear()
          ..addAll((jsonDecode(ph) as List).cast<Map<String, dynamic>>());
      } catch (_) {}
    }
    final pl = SettingsStore.get('playlists');
    if (pl != null && pl.isNotEmpty) {
      try {
        final raw = jsonDecode(pl) as Map<String, dynamic>;
        playlists.clear();
        raw.forEach((name, entries) {
          playlists[name] = (entries as List)
              .map(
                (e) => PlaylistEntry(
                  rj: (e as Map<String, dynamic>)['rj'] as String? ?? '',
                  title: e['title'] as String? ?? '',
                  circle: e['circle'] as String? ?? '',
                  tracks: ((e['tracks'] as List?) ?? const []).cast<String>(),
                ),
              )
              .toList();
        });
      } catch (_) {}
    }
    final bl = SettingsStore.get('blacklist');
    if (bl != null && bl.isNotEmpty) {
      try {
        blacklist
          ..clear()
          ..addAll((jsonDecode(bl) as List).cast<Map<String, dynamic>>());
      } catch (_) {}
    }
    final ai = SettingsStore.get('ai_config');
    if (ai != null && ai.isNotEmpty) {
      try {
        final raw = jsonDecode(ai) as Map<String, dynamic>;
        aiConfig['base'] = raw['base'] as String? ?? '';
        aiConfig['model'] = raw['model'] as String? ?? '';
        aiConfig['key'] = raw['key'] as String? ?? '';
      } catch (_) {}
    }
    final dk = SettingsStore.get('deepl_key');
    if (dk != null) deeplKey = dk;
    final translationTarget = SettingsStore.get('translation_target');
    if (translationTarget != null &&
        const ['zh-CN', 'zh-TW', 'en'].contains(translationTarget)) {
      this.translationTarget = translationTarget;
    }
    final tray = SettingsStore.get('keep_tray_on_close');
    if (tray != null) keepTrayOnClose = tray == '1';
    final se = SettingsStore.get('sleep_end_at');
    if (se != null && se.isNotEmpty) {
      final t = DateTime.tryParse(se);
      if (t != null && t.isAfter(DateTime.now())) {
        sleepEndAt = t;
      } else {
        SettingsStore.set('sleep_end_at', '');
      }
    }
    final sm = SettingsStore.get('sleep_mode');
    if (sm != null && sm.isNotEmpty) sleepMode = sm;
    final pe = SettingsStore.get('http_proxy_enabled');
    if (pe != null) httpProxyEnabled = pe == '1';
    final pu = SettingsStore.get('http_proxy');
    if (pu != null) httpProxyUrl = pu;
    final uc = SettingsStore.get('update_check_enabled');
    if (uc != null) updateCheckEnabled = uc == '1';
    final uiv = SettingsStore.get('update_ignored_version');
    if (uiv != null) updateIgnoredVersion = uiv;
    final cacheLimit = int.tryParse(
      SettingsStore.get('media_cache_limit_mb') ?? '',
    );
    if (cacheLimit != null) {
      mediaCacheLimitMb = cacheLimit.clamp(512, 10240).toInt();
    }
    final hs = SettingsStore.get('home_sort');
    if (hs != null && hs.isNotEmpty) sort = hs;
    final ho = SettingsStore.get('home_order_asc');
    if (ho != null) orderAsc = ho == '1';
    final doNotRememberProgress = SettingsStore.get(
      'do_not_remember_playback_progress',
    );
    if (doNotRememberProgress != null) {
      doNotRememberPlaybackProgress = doNotRememberProgress == '1';
    }
    // 恢复上次播放状态（作品/队列/位置，默认暂停，不自动播放）
    final ps = SettingsStore.get('play_state');
    if (ps != null && ps.isNotEmpty) {
      try {
        final m = jsonDecode(ps) as Map<String, dynamic>;
        final wm = m['work'] as Map<String, dynamic>;
        currentWork = Work(
          rj: wm['rj'] as String,
          title: wm['title'] as String,
          circle: wm['circle'] as String,
          va: wm['va'] as String,
          age: Age.values[(wm['age'] as int?) ?? 0],
          dur: wm['dur'] as String? ?? '',
          tags: List<String>.from((wm['tags'] as List?) ?? const []),
          grayTags: List<String>.from((wm['grayTags'] as List?) ?? const []),
          grad: (wm['grad'] as int?) ?? 0,
          coverUrl: wm['coverUrl'] as String?,
          hasSubtitle: (wm['hasSubtitle'] as bool?) ?? false,
          apiId: wm['apiId'] as int?,
          hasReview: wm['hasReview'] as bool?,
        );
        queue
          ..clear()
          ..addAll(
            ((m['queue'] as List?) ?? const []).map(
              (e) => _nodeFromJson(e as Map<String, dynamic>),
            ),
          );
        trackIdx = ((m['trackIdx'] as int?) ?? 0).clamp(0, queue.length - 1);
        resumePosition = doNotRememberPlaybackProgress
            ? 0
            : (m['position'] as int?) ?? 0;
        if (queue.isEmpty) {
          currentWork = null;
          trackIdx = 0;
          resumePosition = 0;
        }
      } catch (_) {
        currentWork = null;
        queue.clear();
        trackIdx = 0;
        resumePosition = 0;
      }
    }
  }

  void setThemeMode(ThemeMode m) {
    themeMode = m;
    SettingsStore.set(
      'theme',
      m == ThemeMode.dark
          ? 'dark'
          : m == ThemeMode.light
          ? 'light'
          : 'system',
    );
    notifyListeners();
  }

  void setUiScalePercent(int value) {
    final normalized = _normalizeUiScalePercent(value);
    if (uiScalePercent == normalized) return;
    uiScalePercent = normalized;
    SettingsStore.set('ui_scale_percent', '$uiScalePercent');
    notifyListeners();
  }

  static int _normalizeUiScalePercent(int value) {
    final clamped = value.clamp(25, 200).toInt();
    return (clamped / 25).round() * 25;
  }

  void setVolume(double v) {
    volume = v.clamp(0, volumeMax).toDouble();
    SettingsStore.set('volume', volume.clamp(0, 100).toStringAsFixed(0));
    notifyListeners();
  }

  void cycleVolumeBoost() {
    volumeBoostLevel = (volumeBoostLevel + 1) % 3;
    if (volumeBoostLevel == 0 && volume > 100) volume = 100;
    notifyListeners();
  }

  void setTranslationTarget(String value) {
    if (!const ['zh-CN', 'zh-TW', 'en'].contains(value)) return;
    translationTarget = value;
    SettingsStore.set('translation_target', value);
    notifyListeners();
  }

  void setKeepTrayOnClose(bool value) {
    keepTrayOnClose = value;
    SettingsStore.set('keep_tray_on_close', value ? '1' : '0');
    notifyListeners();
  }

  void setConv(String c) {
    conv = c;
    SettingsStore.set('conv', c);
    notifyListeners();
  }

  void setEqOn(bool on) {
    eqOn = on;
    SettingsStore.set('eq_on', on ? '1' : '0');
    notifyListeners();
  }

  void setEqGains(List<double> gains) {
    for (var i = 0; i < 10; i++) {
      eqGains[i] = gains[i].clamp(-12, 12);
    }
    SettingsStore.set('eq_gains', jsonEncode(eqGains));
    notifyListeners();
  }

  void setAiConfig(String base, String model, String key) {
    aiConfig['base'] = base;
    aiConfig['model'] = model;
    aiConfig['key'] = key;
    SettingsStore.set(
      'ai_config',
      jsonEncode({'base': base, 'model': model, 'key': key}),
    );
    notifyListeners();
  }

  void setDeeplKey(String key) {
    deeplKey = key;
    SettingsStore.set('deepl_key', key);
    notifyListeners();
  }

  void setClipboardDetect(bool v) {
    clipboardDetect = v;
    SettingsStore.set('clipboard_detect', v ? '1' : '0');
    notifyListeners();
  }

  void setDoNotRememberPlaybackProgress(bool value) {
    if (doNotRememberPlaybackProgress == value) return;
    doNotRememberPlaybackProgress = value;
    SettingsStore.set('do_not_remember_playback_progress', value ? '1' : '0');
    // 立即覆盖已保存的进度，确保刚切换后关闭程序也遵循新设置。
    savePlayState();
    notifyListeners();
  }

  void setLsCover(bool v) {
    lsCover = v;
    SettingsStore.set('ls_cover', v ? '1' : '0');
    notifyListeners();
  }

  void setDesktopLyricsOn(bool v) {
    desktopLyricsOn = v;
    SettingsStore.set('desktop_lyrics', v ? '1' : '0');
    notifyListeners();
  }

  void setLyricsFontSize(double v) {
    lyricsFontSize = v.clamp(12, 64);
    SettingsStore.set('lyrics_font_size', lyricsFontSize.toStringAsFixed(1));
    notifyListeners();
  }

  void setLyricsColor(int v) {
    lyricsColor = v;
    SettingsStore.set('lyrics_color', '$v');
    notifyListeners();
  }

  void setLyricsOutlineColor(int v) {
    lyricsOutlineColor = v;
    SettingsStore.set('lyrics_outline_color', '$v');
    notifyListeners();
  }

  void setLyricsOutlineWidth(double v) {
    lyricsOutlineWidth = v.clamp(0, 4);
    SettingsStore.set(
      'lyrics_outline_width',
      lyricsOutlineWidth.toStringAsFixed(1),
    );
    notifyListeners();
  }

  void setLyricsLockedDesktop(bool v) {
    lyricsLockedDesktop = v;
    SettingsStore.set('lyrics_locked_desktop', v ? '1' : '0');
    notifyListeners();
  }

  void setLyricsLockedPortrait(bool v) {
    lyricsLockedPortrait = v;
    SettingsStore.set('lyrics_locked_portrait', v ? '1' : '0');
    notifyListeners();
  }

  void setLyricsLockedLandscape(bool v) {
    lyricsLockedLandscape = v;
    SettingsStore.set('lyrics_locked_landscape', v ? '1' : '0');
    notifyListeners();
  }

  void setHttpProxyEnabled(bool v) {
    httpProxyEnabled = v;
    SettingsStore.set('http_proxy_enabled', v ? '1' : '0');
    notifyListeners();
  }

  void setHttpProxyUrl(String v) {
    httpProxyUrl = v.trim();
    SettingsStore.set('http_proxy', httpProxyUrl);
    notifyListeners();
  }

  void setUpdateCheckEnabled(bool value) {
    updateCheckEnabled = value;
    SettingsStore.set('update_check_enabled', value ? '1' : '0');
    notifyListeners();
  }

  void setUpdateIgnoredVersion(String value) {
    updateIgnoredVersion = value;
    SettingsStore.set('update_ignored_version', value);
    notifyListeners();
  }

  void setMediaCacheLimitMb(int v) {
    mediaCacheLimitMb = v.clamp(512, 10240).toInt();
    SettingsStore.set('media_cache_limit_mb', mediaCacheLimitMb.toString());
    notifyListeners();
  }

  void setSort(String v) {
    sort = v;
    SettingsStore.set('home_sort', v);
    notifyListeners();
  }

  void setOrderAsc(bool v) {
    orderAsc = v;
    SettingsStore.set('home_order_asc', v ? '1' : '0');
    notifyListeners();
  }

  /// 切换 SFW 模式：开启后只显示全年龄内容，并释放当前播放媒体。
  Future<void> toggleSfw() async {
    sfwMode = !sfwMode;
    ageFilter = sfwMode ? 0 : null;
    SettingsStore.set('sfw', sfwMode ? '1' : '0');
    if (sfwMode) {
      currentWork = null;
      queue.clear();
      trackIdx = 0;
      playing = false;
      clearPlayState();
    }
    notifyListeners();
    if (sfwMode) await AppPlayer.instance.releaseMedia();
  }

  /// 拔出耳机自动暂停（安卓）
  void setEarPause(bool v) {
    earPause = v;
    SettingsStore.set('ear_pause', v ? '1' : '0');
    AndroidAudio.setEarPause(v);
    notifyListeners();
  }

  /// 忽略音频焦点（安卓；其他应用抢占焦点时不暂停）
  void setIgnoreAudioFocus(bool v) {
    ignoreAudioFocus = v;
    SettingsStore.set('ignore_audio_focus', v ? '1' : '0');
    AndroidAudio.setIgnoreAudioFocus(v);
    notifyListeners();
  }

  /// 智能路径：auto=打开作品自动进入最佳目录 / root=停在根目录
  void setInitialPathBehavior(String v) {
    initialPathBehavior = v;
    SettingsStore.set('initial_path_behavior', v);
    notifyListeners();
  }

  /// 效果音偏好
  void setSePreference(bool v) {
    sePreference = v;
    SettingsStore.set('se_preference', v ? '1' : '0');
    notifyListeners();
  }

  /// 音频类型偏好顺序（可拖拽排序）
  void setAudioTypePreference(List<String> v) {
    audioTypePreference
      ..clear()
      ..addAll(v);
    SettingsStore.set('audio_type_preference', jsonEncode(v));
    notifyListeners();
  }

  void armSleep(DateTime end) {
    sleepEndAt = end;
    SettingsStore.set('sleep_end_at', end.toIso8601String());
    notifyListeners();
  }

  void clearSleep() {
    sleepEndAt = null;
    SettingsStore.set('sleep_end_at', '');
    notifyListeners();
  }

  void setSleepMode(String m) {
    sleepMode = m;
    SettingsStore.set('sleep_mode', m);
    notifyListeners();
  }

  void armPlayEnd() {
    sleepPlayEndArmed = true;
    notifyListeners();
  }

  void disarmPlayEnd() {
    sleepPlayEndArmed = false;
    notifyListeners();
  }

  void saveSite(CustomSite site, {int? index}) {
    if (index == null) {
      customSites.add(site);
    } else {
      customSites[index] = site;
    }
    _persistSites();
    notifyListeners();
  }

  void removeSite(int i) {
    customSites.removeAt(i);
    if (customServer && customServerIdx >= customSites.length) {
      customServer = customSites.isNotEmpty;
      customServerIdx = 0;
    }
    _persistSites();
    _persistServer();
    notifyListeners();
  }

  void saveAsmr(String user, String pass) {
    asmrUser = user;
    asmrPass = pass;
    SettingsStore.set('asmr_user', user);
    SettingsStore.set('asmr_pass', pass);
    notifyListeners();
  }

  /// 完全重置：清空本地存储并恢复全部内存状态为初始值。
  /// 调用方应同时停止播放器、隐藏桌面歌词，重置后 loginRequired 会回到 true。
  void resetAll() {
    SettingsStore.clearAll();
    themeMode = ThemeMode.system;
    uiScalePercent = 100;
    tab = 0;
    customServer = false;
    customServerIdx = 0;
    customSites.clear();
    asmrUser = '';
    asmrPass = '';
    category = 'all';
    sort = 'collect';
    orderAsc = false;
    randomSeed = null;
    serverEpoch = 0;
    loginEpoch = 0;
    ageFilter = null;
    subOnly = false;
    sfwMode = false;
    _pendingSearch = null;
    pendingClear = false;
    searchExpanded = false;
    remoteWorks.clear();
    remoteError = null;
    loadingRemote = false;
    worksPage = 1;
    worksLoadingMore = false;
    worksHasMore = true;
    currentWork = null;
    queue.clear();
    trackIdx = 0;
    playing = false;
    resumePosition = 0;
    favoriteRjs.clear();
    favIds.clear();
    favVersion++;
    history.clear();
    playlists.clear();
    playHistory.clear();
    blacklist.clear();
    translated.clear();
    eqOn = true;
    eqGains.fillRange(0, eqGains.length, 0);
    conv = 'orig';
    playMode = 0;
    volume = 100;
    volumeBoostLevel = 0;
    clipboardDetect = true;
    lsCover = false;
    notifCover = false;
    releaseInterface = true;
    doNotRememberPlaybackProgress = false;
    earPause = false;
    ignoreAudioFocus = false;
    initialPathBehavior = 'auto';
    sePreference = true;
    audioTypePreference
      ..clear()
      ..addAll(['mp3', 'flac', 'wav', 'opus', 'm4a', 'aac']);
    httpProxyEnabled = false;
    httpProxyUrl = '';
    updateCheckEnabled = true;
    updateIgnoredVersion = '';
    mediaCacheLimitMb = 1024;
    desktopLyricsOn = false;
    lyricsFontSize = 20;
    lyricsColor = 0xFFFFFFFF;
    lyricsOutlineColor = 0xFF000000;
    lyricsOutlineWidth = 1;
    lyricsLockedDesktop = false;
    lyricsLockedPortrait = false;
    lyricsLockedLandscape = false;
    engine = 'google';
    aiConfig
      ..clear()
      ..addAll({'base': '', 'model': '', 'key': ''});
    deeplKey = '';
    sleepMode = 'after';
    sleepPlayEndArmed = false;
    sleepMin = 10;
    sleepTime = null;
    sleepEndAt = null;
    notifyListeners();
  }

  /// 应用服务器选择并持久化（登录页/服务器弹层共用）
  void applyServer(bool custom, int idx) {
    customServer = custom;
    customServerIdx = customSites.isEmpty
        ? 0
        : idx.clamp(0, customSites.length - 1).toInt();
    _persistServer();
    serverEpoch++;
    notifyListeners();
  }

  void _persistServer() {
    SettingsStore.set('server_custom', customServer ? '1' : '0');
    SettingsStore.set('server_idx', '$customServerIdx');
  }

  static String _newRecommenderUuid() {
    final random = Random.secure();
    String group(int length) {
      const hex = '0123456789abcdef';
      return List.generate(
        length,
        (_) => hex[random.nextInt(hex.length)],
      ).join();
    }

    return '${group(8)}-${group(4)}-4${group(3)}-'
        '${const ['8', '9', 'a', 'b'][random.nextInt(4)]}${group(3)}-${group(12)}';
  }

  void setEngine(String e) {
    engine = e;
    SettingsStore.set('engine', e);
    notifyListeners();
  }

  void _persistSites() {
    SettingsStore.set(
      'sites',
      jsonEncode(
        customSites
            .map(
              (s) => {
                'alias': s.alias,
                'url': s.url,
                'user': s.user,
                'pass': s.pass,
              },
            )
            .toList(),
      ),
    );
  }

  void _persistFavs() => SettingsStore.set('favs', jsonEncode(favoriteRjs));

  void _persistSearchHistory() =>
      SettingsStore.set('search_history', jsonEncode(history));

  void _persistPlayHistory() =>
      SettingsStore.set('play_history', jsonEncode(playHistory));

  void _persistPlaylists() => SettingsStore.set(
    'playlists',
    jsonEncode(
      playlists.map(
        (name, entries) => MapEntry(
          name,
          entries
              .map(
                (e) => {
                  'rj': e.rj,
                  'title': e.title,
                  'circle': e.circle,
                  'tracks': e.tracks,
                },
              )
              .toList(),
        ),
      ),
    ),
  );

  void _persistBlacklist() =>
      SettingsStore.set('blacklist', jsonEncode(blacklist));
}
