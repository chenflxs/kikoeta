import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../data.dart';
import '../src/rust/api/kikoeru_api.dart';
import '../src/rust/api/simple.dart';
import '../src/rust/api/textcodec.dart';

/// 一页作品 + 服务端分页信息（用于 hasMore 判断）
class WorksPage {
  final List<Work> works;
  final int page;
  final int pageSize;
  final int totalCount;
  final bool hasMore;
  const WorksPage({
    required this.works,
    required this.page,
    required this.pageSize,
    required this.totalCount,
    required this.hasMore,
  });
}

/// 高级筛选页中的一个参数项。
class AdvancedFilterEntry {
  final String id;
  final String name;
  final int count;

  const AdvancedFilterEntry({
    required this.id,
    required this.name,
    required this.count,
  });
}

/// asmr.one API 客户端（网络请求统一由 Rust 核心执行）。
class ApiService {
  static String resolveBase(AppState app) {
    if (app.customServer && app.customSites.isNotEmpty) {
      return app.customSites[app.customServerIdx].url;
    }
    return 'https://api.asmr.one';
  }

  /// 读取高级筛选页的声音、社团或标签列表。
  ///
  /// 这三个列表接口是 kikoeru/one 站通用的元数据接口，返回形如
  /// [{"id": 1, "name": "...", "count": 12}] 的数组。
  static Future<List<AdvancedFilterEntry>> fetchAdvancedFilterEntries(
    AppState app,
    String kind,
  ) async {
    const allowed = {'vas', 'circles', 'tags'};
    if (!allowed.contains(kind)) {
      throw ArgumentError.value(kind, 'kind', '不支持的高级筛选类型');
    }
    final base = resolveBase(app).replaceFirst(RegExp(r'/+$'), '');
    final uri = Uri.parse('$base/api/$kind/');
    // 与作品/封面请求一样走 Rust reqwest：它会复用应用代理配置，
    // 避免 Windows 上 Dart HttpClient 的 TLS 握手失败。
    final bytes = await apiGetBytes(url: uri.toString());
    final decoded = jsonDecode(utf8.decode(bytes));
    final raw = decoded is List
        ? decoded
        : decoded is Map
        ? (decoded['data'] ?? decoded['items'] ?? decoded['results'] ?? const [])
        : const [];
    if (raw is! List) throw const FormatException('高级筛选数据格式无效');

    final entries = <AdvancedFilterEntry>[];
    for (final value in raw) {
      if (value is! Map) continue;
      final name = value['name']?.toString().trim() ?? '';
      if (name.isEmpty) continue;
      final count = _metadataCount(value);
      entries.add(
        AdvancedFilterEntry(
          id: value['id']?.toString() ?? name,
          name: name,
          count: count,
        ),
      );
    }
    entries.sort((a, b) {
      final countOrder = b.count.compareTo(a.count);
      return countOrder != 0 ? countOrder : a.name.compareTo(b.name);
    });
    return entries;
  }

  static int _metadataCount(Map value) {
    for (final key in const [
      'count',
      'works_count',
      'work_count',
      'worksCount',
    ]) {
      final raw = value[key];
      if (raw is num) return raw.toInt();
      final parsed = int.tryParse(raw?.toString() ?? '');
      if (parsed != null) return parsed;
    }
    return 0;
  }

  static Future<WorksPage> fetchWorks(
    AppState app, {
    int page = 1,
    int perPage = 20,
  }) async {
    final base = resolveBase(app);
    if (app.customServer) {
      // kikoeru-express：分页大小由服务器配置决定，年龄用 nsfw、字幕用 lyric
      final json = await apiGetCustomWorks(
        base: base,
        page: page,
        order: orderParam(app),
        sort: app.orderAsc ? 'asc' : 'desc',
        nsfw: customNsfw(app.ageFilters),
        lyric: app.subtitleFilter == SubtitleFilter.online
            ? 'ai_local'
            : null,
        seed: app.category == 'rec' ? app.randomSeed?.toString() : null,
      );
      return parseWorks(json, base: base, perPage: perPage);
    }
    if (app.category == 'hot' || app.category == 'rec') {
      final json = await _fetchOneCategoryWorks(
        app,
        page: page,
        perPage: perPage,
      );
      return parseWorks(json, base: base, perPage: perPage);
    }
    // asmr.one：年龄筛选改为搜索对应的年龄 tag，由服务端过滤，避免客户端逐页补拉
    final ageTag = oneAgeTag(app.ageFilters);
    if (ageTag != null) {
      final json = await apiSearch(
        base: base,
        query: ageTag,
        page: page,
        perPage: perPage,
        order: orderParam(app),
        sort: app.orderAsc ? 'asc' : 'desc',
        subtitle: app.subtitleFilter == SubtitleFilter.online ? true : null,
        seed: app.category == 'rec' ? app.randomSeed?.toString() : null,
      );
      return parseWorks(json, base: base, perPage: perPage);
    }
    final json = await apiGetWorks(
      base: base,
      page: page,
      perPage: perPage,
      order: orderParam(app),
      sort: app.orderAsc ? 'asc' : 'desc',
      subtitle: app.subtitleFilter == SubtitleFilter.online ? true : null,
      seed: app.category == 'rec' ? app.randomSeed?.toString() : null,
    );
    return parseWorks(json, base: base, perPage: perPage);
  }

  /// asmr.one 热门/推荐页面实际使用 recommender POST 接口，而不是
  /// GET /api/works/{popular,recommend}。后者不存在，会导致页面显示无网络连接。
  static Future<String> _fetchOneCategoryWorks(
    AppState app, {
    required int page,
    required int perPage,
  }) async {
    final base = resolveBase(app);
    final keyword = oneAgeTag(app.ageFilters) ?? '';
    if (app.category == 'hot') {
      return apiGetRecommenderPopular(
        base: base,
        keyword: keyword,
        page: page,
        subtitle: app.subtitleFilter == SubtitleFilter.online,
      );
    }
    return apiGetRecommenderRecommend(
      base: base,
      recommenderUuid: app.recommenderUuid,
      keyword: keyword,
      page: page,
      subtitle: app.subtitleFilter == SubtitleFilter.online,
    );
  }

  static Future<WorksPage> searchWorks(
    AppState app,
    String query, {
    int page = 1,
    int perPage = 20,
  }) async {
    final base = resolveBase(app);
    if (app.customServer) {
      // kikoeru-express：搜索走 /api/search?keyword=，年龄用 nsfw 过滤
      final json = await apiSearchCustom(
        base: base,
        keyword: query.trim(),
        page: page,
        order: orderParam(app),
        sort: app.orderAsc ? 'asc' : 'desc',
        nsfw: customNsfw(app.ageFilters),
        seed: app.category == 'rec' ? app.randomSeed?.toString() : null,
      );
      return parseWorks(json, base: base, perPage: perPage);
    }
    // asmr.one：把年龄 tag 拼进搜索关键词，由服务端一并 AND 过滤
    final ageTag = oneAgeTag(app.ageFilters);
    final q = ageTag == null ? query : '${query.trim()} $ageTag'.trim();
    final json = await apiSearch(
      base: base,
      query: q,
      page: page,
      perPage: perPage,
      order: orderParam(app),
      sort: app.orderAsc ? 'asc' : 'desc',
      subtitle: app.subtitleFilter == SubtitleFilter.online ? true : null,
      seed: app.category == 'rec' ? app.randomSeed?.toString() : null,
    );
    return parseWorks(json, base: base, perPage: perPage);
  }

  /// 随心听使用 asmr.one 的专用随机作品请求。
  ///
  /// 服务端会以 `betterRandom` 返回一个随机作品，客户端必须直接使用响应
  /// 的首项，不能将首页筛选、分页或本地历史逻辑混入这个请求。
  static Future<Work?> fetchRandomWork(AppState app) async {
    final base = resolveBase(app);
    final json = await apiGetRandomWork(base: base);
    return parseWorks(json, base: base, perPage: 1).works.firstOrNull;
  }

  /// 读取单部作品详情，以取得首页列表未携带的多语言版本信息。
  static Future<Work> fetchWork(AppState app, int id) async {
    final json = await apiGetWork(base: resolveBase(app), rj: id.toString());
    final decoded = jsonDecode(json);
    if (decoded is! Map) {
      throw const FormatException('作品详情格式无效');
    }
    return _mapWork(Map<String, dynamic>.from(decoded), 0, resolveBase(app));
  }

  /// 首页/搜索排序参数：所有分类均按用户选择传递给服务器。
  static String orderParam(AppState app) {
    return switch (app.sort) {
      // 发布时间 = DLsite 发布日期；收录时间 = one 站收录日期（两个参数行为不同）
      'date' => 'release',
      // 自建站（kikoeru-express）的入库时间排序参数是 created_at
      'collect' => app.customServer ? 'created_at' : 'create_date',
      'myrating' => 'rating',
      'sales' => 'dl_count',
      'price' => 'price',
      'rating' => 'rate_average_2dp',
      'comments' => 'review_count',
      'rj' => 'id',
      _ => 'release',
    };
  }

  /// kikoeru-express 的 nsfw 参数：1=全年龄 2=仅R18（服务端无 R15 分级，按全年龄处理）。
  static int? customNsfw(Object? ageFilters) {
    final filters = _normalizeAgeFilters(ageFilters);
    if (filters.isEmpty || filters.length == 3) return null;
    if (filters.length == 1) {
      return filters.single == 2 ? 2 : 1;
    }
    // 自建站只支持“全年龄/非全年龄”两档；无法精确表达的组合不加限制。
    if (filters.contains(2) && !filters.contains(0)) return 2;
    if (!filters.contains(2)) return 1;
    return null;
  }

  /// asmr.one 的年龄标签（用作搜索关键词）。
  ///
  /// 单选仍使用一个正向标签；多选时使用排除标签，避免把多个年龄标签
  /// 拼成 AND 条件。空选和全选都表示不过滤年龄。
  static String? oneAgeTag(Object? ageFilters) {
    final filters = _normalizeAgeFilters(ageFilters);
    if (filters.isEmpty || filters.length == 3) return null;
    if (filters.length == 1) {
      return switch (filters.single) {
        0 => r'$age:general$',
        1 => r'$age:r15$',
        2 => r'$age:adult$',
        _ => null,
      };
    }
    if (filters.contains(1) && filters.contains(2)) {
      return r'$-age:adult$';
    }
    if (filters.contains(0) && filters.contains(1)) {
      return r'$-age:adult$';
    }
    if (filters.contains(0) && filters.contains(2)) {
      return r'$-age:r15$';
    }
    return null;
  }

  static Set<int> _normalizeAgeFilters(Object? value) {
    if (value is int) return {value};
    if (value is Iterable) return value.whereType<int>().toSet();
    return <int>{};
  }

  static Future<String> checkHealth(AppState app, String base) async {
    return apiHealth(base: base);
  }

  /// 歌单列表（需登录）
  static Future<List<PlaylistInfo>> fetchPlaylists(AppState app) async {
    final json = await apiGetPlaylists(base: resolveBase(app));
    final data = jsonDecode(json) as Map<String, dynamic>;
    final list = (data['playlists'] as List?) ?? const [];
    return list
        .map((e) {
          final m = e as Map<String, dynamic>;
          final id = m['id']?.toString() ?? '';
          final name = m['name'] as String? ?? '未命名歌单';
          final type = m['type']?.toString().toLowerCase() ?? '';
          return PlaylistInfo(
            id: id,
            name: name,
            worksCount: (m['works_count'] as num?)?.toInt() ?? 0,
            coverUrl: m['mainCoverUrl'] as String?,
            isSystemLiked:
                m['is_sys'] == true ||
                m['isSystem'] == true ||
                m['is_system'] == true ||
                type == 'liked' ||
                id == '__SYS_PLAYLIST_LIKED',
          );
        })
        .where((p) => p.id.isNotEmpty)
        .toList();
  }

  /// 歌单作品（需登录），结构与作品列表一致
  static Future<WorksPage> fetchPlaylistWorks(
    AppState app,
    String id, {
    int page = 1,
    int perPage = 20,
  }) async {
    final json = await apiGetPlaylistWorks(
      base: resolveBase(app),
      id: id,
      page: page,
      perPage: perPage,
    );
    return parseWorks(json, base: resolveBase(app), perPage: perPage);
  }

  /// 我的评价/收藏列表（GET /api/review，需登录）
  static Future<WorksPage> fetchMyReviews(
    AppState app, {
    int page = 1,
    int perPage = 20,
    String order = 'updated_at',
    String sort = 'desc',
    String? filter,
  }) async {
    final json = await apiGetMyReviews(
      base: resolveBase(app),
      page: page,
      perPage: perPage,
      order: order,
      sort: sort,
      filter: filter,
    );
    return parseWorks(json, base: resolveBase(app), perPage: perPage);
  }

  static String _reviewUserName(AppState app) {
    if (app.customServer && app.customSites.isNotEmpty) {
      return app.customSites[app.customServerIdx].user;
    }
    return app.asmrUser;
  }

  /// 系统「收藏」实际是我的评价中的无评分 listening 评价。
  static Future<bool> toggleFavorite(AppState app, Work w) async {
    final id = w.apiId;
    if (id == null) {
      throw Exception('该作品缺少编号，无法收藏');
    }
    final fav = app.isFavorited(w);
    if (fav) {
      await apiDeleteFavoriteReview(
        base: resolveBase(app),
        workId: BigInt.from(id),
      );
      app.removeFavorite(w);
    } else {
      await apiCreateFavoriteReview(
        base: resolveBase(app),
        userName: _reviewUserName(app),
        workId: BigInt.from(id),
      );
      app.addFavorite(w);
    }
    return !fav;
  }

  static Future<String> login(
    AppState app,
    String base,
    String name,
    String password,
  ) {
    return apiLogin(base: base, name: name, password: password);
  }

  static String? tokenFor(AppState app, String base) => getToken(base: base);

  static Future<List<LyricLine>> fetchLrc(
    AppState app,
    Work w, {
    String? trackTitle,
    String? trackPath,
    String? trackUrl,
    LyricCandidate? pick,
  }) async {
    final apiId = w.apiId;
    if (apiId == null) return const [];
    if (app.customServer && pick == null) {
      final serverLyrics = await _fetchCustomServerLyrics(
        app,
        workId: apiId,
        trackUrl: trackUrl,
      );
      if (serverLyrics != null) return serverLyrics;
    }
    final nodes = await fetchTracks(app, apiId);
    final candidates = _findLyricCandidates(nodes);
    if (candidates.isEmpty) return const [];
    // 指定候选（在线歌词选择）
    if (pick != null) {
      _LyricCandidate? match;
      for (final c in candidates) {
        if (c.url != null && c.url == pick.url) {
          match = c;
          break;
        }
      }
      if (match != null) return _loadLyricCandidate(match);
      return const [];
    }
    // TXT 仅能由用户手动选择，避免将作品说明等普通文本误判为歌词。
    final automaticCandidates = candidates
        .where((candidate) => !_isPlainTextLyric(candidate.title))
        .toList();
    if (automaticCandidates.isEmpty) return const [];
    final matched = _trackMatchedLyrics(
      automaticCandidates,
      trackTitle: trackTitle,
      trackPath: trackPath,
    );
    // 多个歌词文件时不回退到其它曲目歌词；唯一歌词仍可作为整部作品通用歌词。
    final selected = matched.isNotEmpty
        ? matched
        : (automaticCandidates.length == 1
              ? automaticCandidates
              : const <_LyricCandidate>[]);
    // 按曲目匹配、格式优先级和语言评分尝试，直到解析出带时间轴的歌词。
    for (final c in selected) {
      final lrc = await _loadLyricCandidate(c);
      if (lrc.isNotEmpty) return lrc;
    }
    return const [];
  }

  /// 歌词候选列表（供「选择在线歌词」使用，已按分数排序）
  static Future<List<LyricCandidate>> lyricCandidates(
    AppState app,
    Work w, {
    String? trackTitle,
    String? trackPath,
  }) async {
    final apiId = w.apiId;
    if (apiId == null) return const [];
    final nodes = await fetchTracks(app, apiId);
    final candidates = _findLyricCandidates(nodes);
    _sortLyricCandidates(
      candidates,
      trackTitle: trackTitle,
      trackPath: trackPath,
    );
    return candidates
        .map(
          (c) => LyricCandidate(
            title: c.title,
            path: c.path,
            url: c.url,
            score: c.score,
          ),
        )
        .toList();
  }

  static Future<List<LyricLine>> _loadLyricCandidate(_LyricCandidate c) async {
    final url = c.url;
    if (url == null) return const [];
    try {
      final bytes = await apiGetBytes(url: url);
      final decoded = apiDecodeText(bytes: bytes, encoding: '');
      return parseLyrics(decoded.text);
    } catch (_) {
      return const [];
    }
  }

  /// 自建站可根据媒体流索引在服务端完成歌词匹配，能正确处理音频与歌词
  /// 位于不同目录、或文件名不完全相同的作品。null 表示接口不可用，交由旧规则兜底。
  static Future<List<LyricLine>?> _fetchCustomServerLyrics(
    AppState app, {
    required int workId,
    required String? trackUrl,
  }) async {
    final index = _mediaStreamIndex(trackUrl);
    if (index == null) return null;
    try {
      final base = resolveBase(app).replaceFirst(RegExp(r'/+$'), '');
      final bytes = await apiGetBytes(
        url: '$base/api/media/check-lrc/$workId/$index',
      );
      final json = jsonDecode(utf8.decode(bytes));
      if (json is! Map || json['result'] != true) return const [];
      final rows = json['lrc'];
      if (rows is! List) return const [];
      return rows
          .whereType<Map>()
          .map((row) {
            final time = (row['time'] as num?)?.toInt() ?? 0;
            final text = row['text']?.toString().trim() ?? '';
            return LyricLine(time ~/ 1000, text, text);
          })
          .where((line) => line.jp.isNotEmpty)
          .toList();
    } catch (_) {
      return null;
    }
  }

  static int? _mediaStreamIndex(String? url) {
    final uri = url == null ? null : Uri.tryParse(url);
    final segments = uri?.pathSegments;
    if (segments == null || segments.length < 2) return null;
    final mediaSegment = segments.indexOf('media');
    if (mediaSegment < 0 || mediaSegment + 3 >= segments.length) return null;
    if (segments[mediaSegment + 1] != 'stream') return null;
    return int.tryParse(segments.last);
  }

  /// 歌词候选：收集歌词/字幕文件并按中文优先打分
  static List<_LyricCandidate> _findLyricCandidates(
    List<MediaNode> nodes, [
    String folder = '',
  ]) {
    final out = <_LyricCandidate>[];
    for (final n in nodes) {
      final path = folder.isEmpty ? n.title : '$folder/${n.title}';
      if (n.isDir) {
        out.addAll(_findLyricCandidates(n.children, path));
        continue;
      }
      final lower = n.title.toLowerCase();
      if (!const {
        '.lrc',
        '.txt',
        '.vtt',
        '.srt',
        '.ass',
        '.ssa',
      }.any(lower.endsWith)) {
        continue;
      }
      final pathLower = path.toLowerCase();
      var score = 0;
      // 文件夹带歌词/字幕含义
      if (pathLower.contains('lyric') ||
          pathLower.contains('lrc') ||
          path.contains('歌词') ||
          path.contains('字幕') ||
          path.contains('台本') ||
          pathLower.contains('subtitle')) {
        score += 10;
      }
      // 中文优先：简/繁/zh/sc/tc 等字样（文件或文件夹名）
      for (final h in _zhLyricHints) {
        if (_pathHas(pathLower, h)) {
          score += 100;
          break;
        }
      }
      // 非中文（日/英/韩等）降权
      for (final h in _otherLangHints) {
        if (_pathHas(pathLower, h)) {
          score -= 60;
          break;
        }
      }
      out.add(
        _LyricCandidate(title: n.title, path: path, url: n.url, score: score),
      );
    }
    return out;
  }

  static const _zhLyricHints = [
    '简体',
    '繁体',
    '简中',
    '繁中',
    '中文',
    '中字',
    '汉化',
    '汉',
    '简',
    '繁',
    'zh',
    'sc',
    'tc',
  ];
  static const _otherLangHints = [
    '日本語',
    '日语',
    '日文',
    '日',
    'jp',
    'ja',
    '英语',
    '英文',
    'en',
    'eng',
    'english',
    '韓国',
    '韩语',
    '한국어',
    'ko',
    'kr',
  ];

  static const _lyricExtensions = {
    '.lrc',
    '.txt',
    '.vtt',
    '.srt',
    '.ass',
    '.ssa',
  };
  static const _audioExtensions = {
    '.mp3',
    '.flac',
    '.wav',
    '.ogg',
    '.opus',
    '.m4a',
    '.aac',
    '.wma',
    '.webm',
  };

  /// 歌词格式优先级：LRC > SRT > VTT > ASS/SSA > TXT。
  /// TXT 仅供用户手动选择歌词时使用。
  @visibleForTesting
  static int lyricFormatPriority(String name) {
    final lower = name.toLowerCase();
    if (lower.endsWith('.lrc')) return 5;
    if (lower.endsWith('.srt')) return 4;
    if (lower.endsWith('.vtt')) return 3;
    if (lower.endsWith('.ass') || lower.endsWith('.ssa')) return 2;
    if (lower.endsWith('.txt')) return 1;
    return 0;
  }

  static bool _isPlainTextLyric(String name) =>
      name.toLowerCase().endsWith('.txt');

  /// 拉丁语种码按整词匹配，避免误伤（如 en 不匹配 special/English 以外的单词）
  static bool _pathHas(String s, String hint) {
    if (RegExp(r'^[a-z][a-z0-9-]*$').hasMatch(hint)) {
      return RegExp(
        '(?<![a-z0-9])${RegExp.escape(hint)}(?![a-z0-9])',
      ).hasMatch(s);
    }
    return s.contains(hint);
  }

  /// 用于音轨和歌词文件名配对的标准化名称。
  ///
  /// 只移除末尾的语言标记，避免把 `track.zh.srt`、`track-zh.srt`
  /// 等中文字幕当成不同曲目，同时不影响文件名中间的普通文字。
  static String lyricMatchKey(String name) {
    var stem = name.trim().toLowerCase();
    for (var i = 0; i < 3; i++) {
      final before = stem;
      stem = _stripKnownExtension(stem, _lyricExtensions);
      stem = _stripLanguageSuffix(stem);
      // 某些字幕会以 `track.mp3.vtt` 或 `track.mp3.zh.vtt` 命名；
      // 去掉字幕扩展名和语言后，还要继续去掉嵌套的音频扩展名。
      stem = _stripKnownExtension(stem, _audioExtensions);
      stem = _stripLanguageSuffix(stem);
      if (stem == before) break;
    }
    return stem.trim();
  }

  /// 返回两个媒体/歌词文件名的标题匹配分数。
  ///
  /// 先保留完整标准化名称的精确匹配；不相等时，再从分隔符外的连续片段
  /// 中寻找双方共有的标题。这样 `01-标题-NOSE`、`标题-SE_HIGH` 和
  /// `标题(seなし)` 可以归到同一标题，而不会把某一侧各自最长的附加标记
  /// 当作曲名。纯数字片段仍由 [lyricTrackOrdinal] 单独兜底。
  static int lyricMatchScore(String trackName, String lyricName) {
    final trackKey = lyricMatchKey(trackName);
    final lyricKey = lyricMatchKey(lyricName);
    if (trackKey.isEmpty || lyricKey.isEmpty) return 0;
    // 足够大的固定值，保证完整名精确匹配永远优于片段匹配。
    if (trackKey == lyricKey) return 100000;

    final trackSpans = _lyricTitleSpans(trackKey);
    final lyricSpans = _lyricTitleSpans(lyricKey);
    var best = 0;
    for (final entry in trackSpans.entries) {
      final other = lyricSpans[entry.key];
      if (other == null) continue;
      // 相同片段的权重通常相等；取较小值使将来调整标准化规则时仍保守。
      final score = entry.value < other ? entry.value : other;
      if (score > best) best = score;
    }
    // 片段命中也要先于格式、语言等候选排序；权重仅用于同级标题比较。
    return best == 0 ? 0 : 1000 + best;
  }

  /// 文件名按常见分隔符拆开后生成所有连续标题片段。
  ///
  /// 括号内通常是 `seなし`、语言、版本等注释，因此不参与主标题匹配；只有
  /// 文件名没有任何括号外内容时才退回使用其中的文字，避免完全无法匹配。
  static Map<String, int> _lyricTitleSpans(String name) {
    final primary = _splitLyricTitleParts(name, includeAnnotations: false);
    final parts = primary.isNotEmpty
        ? primary
        : _splitLyricTitleParts(name, includeAnnotations: true);
    final spans = <String, int>{};
    for (var start = 0; start < parts.length; start++) {
      var joined = '';
      for (var end = start; end < parts.length; end++) {
        joined += parts[end];
        if (!_hasNonNumericTitleContent(joined)) continue;
        final weight = _lyricTitleWeight(joined);
        final previous = spans[joined];
        if (previous == null || weight > previous) spans[joined] = weight;
      }
    }
    return spans;
  }

  static List<String> _splitLyricTitleParts(
    String name, {
    required bool includeAnnotations,
  }) {
    const openBrackets = '([{（［【';
    const closeBrackets = ')]}）］】';
    const separators = '-_./\\·・,，、:：;；|｜~～—–−';
    final parts = <String>[];
    final current = StringBuffer();
    var bracketDepth = 0;

    void flush() {
      final part = current.toString().trim();
      current.clear();
      if (part.isNotEmpty) parts.add(part);
    }

    for (final rune in name.runes) {
      final char = String.fromCharCode(rune);
      if (openBrackets.contains(char)) {
        if (bracketDepth == 0) flush();
        bracketDepth++;
        continue;
      }
      if (closeBrackets.contains(char)) {
        if (bracketDepth > 0) bracketDepth--;
        if (bracketDepth == 0) flush();
        continue;
      }
      if (bracketDepth > 0 && !includeAnnotations) continue;
      if (char.trim().isEmpty || separators.contains(char)) {
        flush();
      } else {
        current.write(char);
      }
    }
    flush();
    return parts;
  }

  static bool _hasNonNumericTitleContent(String value) => value.runes.any(
    (rune) =>
        !(rune >= 0x30 && rune <= 0x39) && !(rune >= 0xff10 && rune <= 0xff19),
  );

  static int _lyricTitleWeight(String value) {
    var weight = 0;
    for (final rune in value.runes) {
      weight += _isHanOrKana(rune) ? 2 : 1;
    }
    return weight;
  }

  static bool _isHanOrKana(int rune) =>
      (rune >= 0x3400 && rune <= 0x4dbf) || // CJK Unified Ideographs Ext. A
      (rune >= 0x4e00 && rune <= 0x9fff) || // CJK Unified Ideographs
      (rune >= 0xf900 && rune <= 0xfaff) || // CJK Compatibility Ideographs
      (rune >= 0x20000 && rune <= 0x2fa1f) || // supplementary Han blocks
      (rune >= 0x3040 && rune <= 0x309f) || // Hiragana
      (rune >= 0x30a0 && rune <= 0x30ff) || // Katakana
      (rune >= 0x31f0 && rune <= 0x31ff) || // Katakana Phonetic Extensions
      (rune >= 0xff66 && rune <= 0xff9d); // Half-width Katakana

  static String _stripKnownExtension(String value, Set<String> extensions) {
    final dot = value.lastIndexOf('.');
    if (dot <= 0 || !extensions.contains(value.substring(dot))) return value;
    return value.substring(0, dot).trim();
  }

  static String _stripLanguageSuffix(String value) {
    var stem = value.replaceFirst(
      RegExp(
        r'(?:[.\-_\s]+|[\[\(])(?:zh|zho|chi|chs|cht|sc|tc)'
        r'(?:[-_](?:cn|tw|hans|hant))?[\]\)]?$',
      ),
      '',
    );
    stem = stem.replaceFirst(
      RegExp(r'(?:[.\-_\s]+|[\[\(])(?:简体|繁体|简中|繁中|中文|中字|汉化)[\]\)]?$'),
      '',
    );
    return stem.trim();
  }

  static List<_LyricCandidate> _trackMatchedLyrics(
    List<_LyricCandidate> candidates, {
    required String? trackTitle,
    required String? trackPath,
  }) {
    if (lyricMatchKey(trackTitle ?? '').isEmpty) return const [];
    final trackFolder = _parentPath(trackPath ?? '');
    final nameScores = <_LyricCandidate, int>{
      for (final candidate in candidates)
        candidate: lyricMatchScore(trackTitle ?? '', candidate.title),
    };
    var sameName = candidates
        .where((candidate) => (nameScores[candidate] ?? 0) > 0)
        .toList();
    // 部分作品的字幕仅保留曲目编号，或附加了额外标题/语言标签，无法与
    // 完整音频名相等。仅在没有完整匹配时，以同目录前置编号兜底。
    if (sameName.isEmpty) {
      final ordinal = lyricTrackOrdinal(trackTitle ?? '');
      if (ordinal != null) {
        sameName = candidates
            .where((candidate) => lyricTrackOrdinal(candidate.title) == ordinal)
            .toList();
      }
    }
    final sameFolderName = sameName
        .where((candidate) => _parentPath(candidate.path) == trackFolder)
        .toList();
    final matched = sameFolderName.isNotEmpty ? sameFolderName : sameName;
    matched.sort((a, b) {
      final nameScore = (nameScores[b] ?? 0).compareTo(nameScores[a] ?? 0);
      if (nameScore != 0) return nameScore;
      return _compareLyricCandidates(a, b);
    });
    return matched;
  }

  static String? lyricTrackOrdinal(String name) {
    var stem = lyricMatchKey(name);
    // 删除开头的语言/字幕标签，例如 [CHS]、(字幕)。
    stem = stem.replaceFirst(RegExp(r'^\s*(?:\[[^\]]*\]|\([^)]*\))\s*'), '');
    final match = RegExp(
      r'^(?:track|tr|第)?\s*0*(\d{1,4})(?!\d)',
      caseSensitive: false,
    ).firstMatch(stem);
    final value = int.tryParse(match?.group(1) ?? '');
    return value?.toString();
  }

  static int _compareLyricCandidates(_LyricCandidate a, _LyricCandidate b) {
    final format = lyricFormatPriority(
      b.title,
    ).compareTo(lyricFormatPriority(a.title));
    if (format != 0) return format;
    final score = b.score.compareTo(a.score);
    if (score != 0) return score;
    return a.path.toLowerCase().compareTo(b.path.toLowerCase());
  }

  static String _parentPath(String path) {
    final i = path.lastIndexOf('/');
    return i < 0 ? '' : path.substring(0, i).toLowerCase();
  }

  /// 精确匹配当前媒体文件名及目录的歌词必须排在其它候选之前。
  static void _sortLyricCandidates(
    List<_LyricCandidate> candidates, {
    required String? trackTitle,
    required String? trackPath,
  }) {
    final matched = _trackMatchedLyrics(
      candidates,
      trackTitle: trackTitle,
      trackPath: trackPath,
    );
    final matchOrder = <_LyricCandidate, int>{
      for (var i = 0; i < matched.length; i++) matched[i]: i,
    };
    candidates.sort((a, b) {
      final aOrder = matchOrder[a] ?? candidates.length;
      final bOrder = matchOrder[b] ?? candidates.length;
      if (aOrder != bOrder) return aOrder.compareTo(bOrder);
      return _compareLyricCandidates(a, b);
    });
  }

  /// Parses LRC and common subtitle formats into timestamped lyric lines.
  static List<LyricLine> parseLyrics(String text) {
    final normalized = text.replaceFirst('\uFEFF', '').replaceAll('\r\n', '\n');
    final trimmed = normalized.trimLeft();
    if (trimmed.startsWith('WEBVTT')) return _parseTimedSubtitles(normalized);
    if (RegExp(r'^\s*\[Events\]', multiLine: true).hasMatch(normalized) ||
        RegExp(r'^\s*Dialogue\s*:', multiLine: true).hasMatch(normalized)) {
      return _parseAss(normalized);
    }
    if (RegExp(
      r'^\s*(?:\d+\s*\n)?\d{1,2}:\d{2}:\d{2}[,.]\d{1,3}\s*-->',
      multiLine: true,
    ).hasMatch(normalized)) {
      return _parseTimedSubtitles(normalized);
    }
    return parseLrc(normalized);
  }

  static List<LyricLine> parseLrc(String text) {
    final lines = <LyricLine>[];
    final re = RegExp(r'\[(\d{1,2}):(\d{1,2})(?:[.:](\d{1,3}))?\]');
    for (final raw in text.split('\n')) {
      final line = raw.trim();
      if (line.isEmpty) continue;
      final matches = re.allMatches(line).toList();
      if (matches.isEmpty) continue;
      final content = line.substring(line.lastIndexOf(']') + 1).trim();
      for (final m in matches) {
        final mm = int.parse(m.group(1)!);
        final ss = int.parse(m.group(2)!);
        lines.add(LyricLine(mm * 60 + ss, content, content));
      }
    }
    return _sortedLyrics(lines);
  }

  static List<LyricLine> _parseTimedSubtitles(String text) {
    final lines = <LyricLine>[];
    final blocks = text.replaceAll('\r\n', '\n').split(RegExp(r'\n\s*\n'));
    final timing = RegExp(
      r'^\s*(\d{1,2}:\d{2}:\d{2}[,.]\d{1,3}|\d{1,2}:\d{2}[,.]\d{1,3})\s*-->.*$',
    );
    for (final block in blocks) {
      final blockLines = block.split('\n');
      var timingIndex = -1;
      RegExpMatch? match;
      for (var i = 0; i < blockLines.length; i++) {
        final candidate = timing.firstMatch(blockLines[i]);
        if (candidate != null) {
          timingIndex = i;
          match = candidate;
          break;
        }
      }
      if (match == null) continue;
      final content = _cleanSubtitleText(
        blockLines.skip(timingIndex + 1).join('\n'),
      );
      if (content.isEmpty) continue;
      final seconds = _parseSubtitleTime(match.group(1)!);
      if (seconds != null) lines.add(LyricLine(seconds, content, content));
    }
    return _sortedLyrics(lines);
  }

  static List<LyricLine> _parseAss(String text) {
    final lines = <LyricLine>[];
    for (final raw in text.replaceAll('\r\n', '\n').split('\n')) {
      final line = raw.trim();
      if (!line.toLowerCase().startsWith('dialogue:')) continue;
      final fields = line.substring(line.indexOf(':') + 1).split(',');
      if (fields.length < 10) continue;
      final seconds = _parseAssTime(fields[1].trim());
      if (seconds == null) continue;
      final content = _cleanSubtitleText(fields.sublist(9).join(','));
      if (content.isNotEmpty) lines.add(LyricLine(seconds, content, content));
    }
    return _sortedLyrics(lines);
  }

  static List<LyricLine> _sortedLyrics(List<LyricLine> lines) {
    lines.sort((a, b) => a.t.compareTo(b.t));
    return lines;
  }

  static int? _parseSubtitleTime(String value) {
    final parts = value.trim().replaceAll(',', '.').split(':');
    if (parts.length == 2) parts.insert(0, '0');
    if (parts.length != 3) return null;
    final hours = int.tryParse(parts[0]);
    final minutes = int.tryParse(parts[1]);
    final seconds = double.tryParse(parts[2]);
    if (hours == null || minutes == null || seconds == null) return null;
    return (hours * 3600 + minutes * 60 + seconds).floor();
  }

  static int? _parseAssTime(String value) {
    final parts = value.trim().split(':');
    if (parts.length != 3) return null;
    final hours = int.tryParse(parts[0]);
    final minutes = int.tryParse(parts[1]);
    final seconds = double.tryParse(parts[2]);
    if (hours == null || minutes == null || seconds == null) return null;
    return (hours * 3600 + minutes * 60 + seconds).floor();
  }

  static String _cleanSubtitleText(String value) {
    return value
        .replaceAll(r'\N', '\n')
        .replaceAll(r'\n', '\n')
        .replaceAll(RegExp(r'\{[^}]*\}'), '')
        .replaceAll(RegExp(r'<[^>]*>'), '')
        .split('\n')
        .map((line) => line.trim())
        .where((line) => line.isNotEmpty)
        .join('\n');
  }

  static Future<List<MediaNode>> fetchTracks(
    AppState app,
    int workApiId, {
    bool forceRefresh = false,
  }) async {
    final key = _tracksKey(app, workApiId);
    final cached = _tracksCache[key];
    if (!forceRefresh && cached != null) return cached;
    final json = await apiGetTracks(base: resolveBase(app), rj: '$workApiId');
    final nodes = parseMediaNodes(jsonDecode(json), base: resolveBase(app));
    if (_tracksCache.length >= 10) _tracksCache.remove(_tracksCache.keys.first);
    _tracksCache[key] = nodes;
    return nodes;
  }

  static final Map<String, List<MediaNode>> _tracksCache = {};
  static String _tracksKey(AppState app, int id) => '${resolveBase(app)}|$id';

  /// 将 asmr.one 与 kikoeru-express 的曲目树统一为客户端模型。
  /// 自建站返回的 mediaStreamUrl 通常是相对地址，必须按该站点的 base
  /// 解析；否则播放器会把它当成本地路径，无法打开媒体或歌词文件。
  static List<MediaNode> parseMediaNodes(
    dynamic list, {
    required String base,
  }) => _parseNodes(list, '', base);

  static List<MediaNode> _parseNodes(
    dynamic list,
    String parentPath,
    String base,
  ) {
    if (list is! List) return const [];
    final nodes = list.map((e) {
      final m = e as Map<String, dynamic>;
      final title = m['title'] as String? ?? '';
      final type = m['type'] as String? ?? 'folder';
      final path = parentPath.isEmpty ? title : '$parentPath/$title';
      final raw = m['children'];
      final hash = m['hash']?.toString();
      final rawDownloadUrl =
          m['mediaDownloadUrl'] as String? ??
          m['downloadUrl'] as String? ??
          m['mediaUrl'] as String? ??
          m['mediaStreamUrl'] as String? ??
          m['streamUrl'] as String? ??
          m['url'] as String? ??
          (hash != null ? '/api/media/stream/$hash' : null);
      final rawStreamUrl =
          m['mediaStreamUrl'] as String? ??
          m['streamUrl'] as String? ??
          m['mediaUrl'] as String? ??
          m['url'] as String? ??
          rawDownloadUrl;
      final url = rawStreamUrl == null
          ? null
          : _resolveMediaUrl(base, rawStreamUrl);
      final downloadUrl = rawDownloadUrl == null
          ? null
          : _resolveMediaUrl(base, rawDownloadUrl);
      return MediaNode(
        title: title,
        type: type,
        path: path,
        url: url,
        downloadUrl: downloadUrl,
        duration: (m['duration'] as num?)?.toInt() ?? 0,
        children: _parseNodes(raw is List ? raw : null, path, base),
      );
    }).toList();
    nodes.sort(_compareMediaNodes);
    return nodes;
  }

  /// 为已保存的媒体树补上与在线曲目相同的同级排序，不修改下载记录。
  static List<MediaNode> sortedMediaNodes(List<MediaNode> nodes) {
    return (nodes
          .map(
            (node) => MediaNode(
              title: node.title,
              type: node.type,
              path: node.path,
              url: node.url,
              downloadUrl: node.downloadUrl,
              duration: node.duration,
              children: sortedMediaNodes(node.children),
            ),
          )
          .toList())
      ..sort(_compareMediaNodes);
  }

  static int _compareMediaNodes(MediaNode a, MediaNode b) {
    final byTitle = _naturalCompare(a.title, b.title);
    if (byTitle != 0) return byTitle;
    if (a.isDir != b.isDir) return a.isDir ? -1 : 1;
    return 0;
  }

  static String _resolveMediaUrl(String base, String value) {
    final parsed = Uri.tryParse(value);
    if (parsed != null && parsed.hasScheme) return parsed.toString();
    return Uri.parse(
      '${base.replaceFirst(RegExp(r'/+$'), '')}/',
    ).resolve(value).toString();
  }

  static int _naturalCompare(String a, String b) {
    final pa = RegExp(
      r'\d+|\D+',
    ).allMatches(a.toLowerCase()).map((m) => m.group(0)!).toList();
    final pb = RegExp(
      r'\d+|\D+',
    ).allMatches(b.toLowerCase()).map((m) => m.group(0)!).toList();
    final n = pa.length < pb.length ? pa.length : pb.length;
    for (var i = 0; i < n; i++) {
      final x = pa[i];
      final y = pb[i];
      final xd = int.tryParse(x);
      final yd = int.tryParse(y);
      if (xd != null && yd != null) {
        if (xd != yd) return xd.compareTo(yd);
      } else {
        final c = x.compareTo(y);
        if (c != 0) return c;
      }
    }
    return pa.length.compareTo(pb.length);
  }

  static WorksPage parseWorks(String json, {String? base, int perPage = 20}) {
    final data = jsonDecode(json) as Map<String, dynamic>;
    final list = (data['works'] as List?) ?? const [];
    final works = list
        .asMap()
        .entries
        .map((e) => _mapWork(e.value as Map<String, dynamic>, e.key, base))
        .toList();
    // one 站与 kikoeru-express 均返回 {works, pagination:{currentPage,pageSize,totalCount}}
    var page = 1;
    var pageSize = perPage;
    var total = -1;
    final pag = data['pagination'];
    if (pag is Map<String, dynamic>) {
      page = (pag['currentPage'] as num?)?.toInt() ?? page;
      pageSize = (pag['pageSize'] as num?)?.toInt() ?? pageSize;
      total = (pag['totalCount'] as num?)?.toInt() ?? -1;
    }
    final hasMore = total >= 0
        ? page * pageSize < total
        : works.length == perPage;
    return WorksPage(
      works: works,
      page: page,
      pageSize: pageSize,
      totalCount: total,
      hasMore: hasMore,
    );
  }

  static Work _mapWork(Map<String, dynamic> m, int i, [String? base]) {
    final rawId = m['id'];
    final apiId = rawId is num
        ? rawId.toInt()
        : rawId is String
        ? int.tryParse(rawId)
        : null;
    final ageStr = m['age_category_string'] as String?;
    final Age age;
    if (ageStr == 'adult') {
      age = Age.r18;
    } else if (ageStr == 'r15') {
      age = Age.r15;
    } else {
      // kikoeru-express 无 age_category_string，用 nsfw 布尔区分 R18
      age = (m['nsfw'] == true) ? Age.r18 : Age.all;
    }
    final vas = ((m['vas'] as List?) ?? const [])
        .map((v) => (v as Map)['name'] as String? ?? '')
        .where((s) => s.isNotEmpty)
        .join(' / ');
    final tags = <String>[];
    final grayTags = <String>[];
    for (final t in ((m['tags'] as List?) ?? const [])) {
      final name = (t as Map)['name'] as String? ?? '';
      if (name.isEmpty) continue;
      // 反编译原版 + 实测：Tag 模型 voteStatus 为每作品维度状态：
      // 0=低愿力（需投票，显示灰色，默认不在列表展示）
      // 1=普通（作品自带或已获认同，实心；字段缺失时默认 1）
      // >=2=否决（完全不展示，服务端通常已过滤）
      final status =
          (t['voteStatus'] as num?)?.toInt() ??
          (t['vote_status'] as num?)?.toInt() ??
          1;
      if (status >= 2) continue;
      tags.add(name);
      if (status == 0) grayTags.add(name);
    }
    final circle =
        (m['circle'] as Map?)?['name'] as String? ??
        (m['name'] as String? ?? '');
    final lyricStatus = m['lyric_status'];
    final hasReview = m.containsKey('user_name')
        ? m['user_name'] != null
        : null;
    final languageEditions = _mapLanguageEditions(m, apiId);
    return Work(
      rj:
          m['source_id'] as String? ??
          (apiId != null ? 'RJ$apiId' : 'RJ00000000'),
      title: m['title'] as String? ?? '未知作品',
      circle: circle,
      va: vas.isEmpty ? 'CV. 未知' : 'CV. $vas',
      age: age,
      dur: _fmtDuration((m['duration'] as num?)?.toInt() ?? 0),
      releaseDate: _formatReleaseDate(
        m['release'] ?? m['release_date'] ?? m['releaseDate'],
      ),
      tags: tags,
      grayTags: grayTags,
      grad: i % 8,
      coverUrl:
          m['mainCoverUrl'] as String? ??
          m['thumbnailCoverUrl'] as String? ??
          // kikoeru-express 不返回封面 URL，按 {base}/api/cover/{id} 构造
          (base != null && apiId != null
              ? '${base.replaceAll(RegExp(r'/+$'), '')}/api/cover/$apiId'
              : null),
      hasSubtitle:
          m['has_subtitle'] as bool? ??
          (lyricStatus is String && lyricStatus.isNotEmpty),
      apiId: apiId,
      hasReview: hasReview,
      languageEditions: languageEditions,
    );
  }

  static String _formatReleaseDate(Object? raw) {
    if (raw == null) return '';
    if (raw is num) {
      final value = raw.toInt();
      final millis = value.abs() < 100000000000 ? value * 1000 : value;
      final date = DateTime.fromMillisecondsSinceEpoch(millis, isUtc: true);
      return '${date.year.toString().padLeft(4, '0')}-'
          '${date.month.toString().padLeft(2, '0')}-'
          '${date.day.toString().padLeft(2, '0')}';
    }
    final text = raw.toString().trim();
    if (text.isEmpty) return '';
    final date = DateTime.tryParse(text);
    if (date != null) {
      return '${date.year.toString().padLeft(4, '0')}-'
          '${date.month.toString().padLeft(2, '0')}-'
          '${date.day.toString().padLeft(2, '0')}';
    }
    return text.length >= 10 ? text.substring(0, 10) : text;
  }

  static List<LanguageEdition> _mapLanguageEditions(
    Map<String, dynamic> work,
    int? currentId,
  ) {
    final editions = <LanguageEdition>[];
    final seen = <int>{};

    void addAll(Object? rawEditions) {
      if (rawEditions is! List) return;
      for (final raw in rawEditions) {
        if (raw is! Map) continue;
        final idValue = raw['id'];
        final id = idValue is num
            ? idValue.toInt()
            : idValue is String
            ? int.tryParse(idValue)
            : null;
        if (id == null || id == currentId || !seen.add(id)) continue;
        final title = (raw['title'] ?? raw['name'] ?? '').toString().trim();
        if (title.isEmpty) continue;
        final language = (raw['lang'] ?? raw['language'])?.toString().trim();
        editions.add(
          LanguageEdition(
            id: id,
            title: title,
            language: language == null || language.isEmpty ? null : language,
            isOriginal: raw['is_original'] == true || raw['isOriginal'] == true,
          ),
        );
      }
    }

    // asmr.one 使用前者；自建 Kikoeru 使用后者，后者没有语言代码。
    addAll(work['other_language_editions_in_db']);
    addAll(work['relatedWorks']);
    return editions;
  }

  static String _fmtDuration(int seconds) {
    if (seconds <= 0) return '--:--';
    final h = seconds ~/ 3600;
    final m = (seconds % 3600) ~/ 60;
    final s = seconds % 60;
    if (h > 0) {
      return '$h:${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
    }
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }
}

class _LyricCandidate {
  final String title;
  final String path;
  final String? url;
  int score;
  _LyricCandidate({
    required this.title,
    required this.path,
    required this.url,
    required this.score,
  });
}

/// 在线歌词候选（公开给播放器选择）
class LyricCandidate {
  final String title;
  final String path;
  final String? url;
  final int score;
  const LyricCandidate({
    required this.title,
    required this.path,
    required this.url,
    required this.score,
  });
}
