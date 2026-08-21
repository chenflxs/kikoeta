import 'dart:convert';
import 'dart:io';

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

/// asmr.one API 客户端（网络层由 Rust 核心执行）
class ApiService {
  static String resolveBase(AppState app) {
    if (app.customServer && app.customSites.isNotEmpty) {
      return app.customSites[app.customServerIdx].url;
    }
    return 'https://api.asmr.one';
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
        nsfw: customNsfw(app.ageFilter),
        lyric: app.subOnly ? 'ai_local' : null,
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
    final ageTag = oneAgeTag(app.ageFilter);
    if (ageTag != null) {
      final json = await apiSearch(
        base: base,
        query: ageTag,
        page: page,
        perPage: perPage,
        order: orderParam(app),
        sort: app.orderAsc ? 'asc' : 'desc',
        subtitle: app.subOnly ? true : null,
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
      subtitle: app.subOnly ? true : null,
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
    final keyword = oneAgeTag(app.ageFilter) ?? '';
    if (app.category == 'hot') {
      return _postOneRecommender(
        base: base,
        path: 'popular',
        keyword: keyword,
        page: page,
        pageSize: perPage,
        subtitle: app.subOnly,
      );
    }
    return _postOneRecommender(
      base: base,
      path: 'recommend-for-user',
      recommenderUuid: app.recommenderUuid,
      keyword: keyword,
      page: page,
      pageSize: perPage,
      subtitle: app.subOnly,
    );
  }

  static Future<String> _postOneRecommender({
    required String base,
    required String path,
    required String keyword,
    required int page,
    required int pageSize,
    required bool subtitle,
    String? recommenderUuid,
  }) async {
    final endpoint = Uri.parse(
      '${base.replaceFirst(RegExp(r'/+$'), '')}/api/recommender/$path',
    );
    final body = <String, dynamic>{
      'keyword': keyword,
      'page': page,
      'pageSize': pageSize,
      'subtitle': subtitle ? 1 : 0,
      'localSubtitledWorks': const [],
      'withPlaylistStatus': const [],
      if (recommenderUuid != null && recommenderUuid.isNotEmpty)
        'recommenderUuid': recommenderUuid,
    };
    final client = HttpClient()
      ..connectionTimeout = const Duration(seconds: 20);
    try {
      final request = await client.postUrl(endpoint);
      request.headers.contentType = ContentType.json;
      request.write(jsonEncode(body));
      final response = await request.close();
      final text = await utf8.decodeStream(response);
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw HttpException(
          'HTTP ${response.statusCode}: ${text.substring(0, text.length.clamp(0, 200))}',
          uri: endpoint,
        );
      }
      return text;
    } finally {
      client.close(force: true);
    }
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
        nsfw: customNsfw(app.ageFilter),
        seed: app.category == 'rec' ? app.randomSeed?.toString() : null,
      );
      return parseWorks(json, base: base, perPage: perPage);
    }
    // asmr.one：把年龄 tag 拼进搜索关键词，由服务端一并 AND 过滤
    final ageTag = oneAgeTag(app.ageFilter);
    final q = ageTag == null ? query : '${query.trim()} $ageTag'.trim();
    final json = await apiSearch(
      base: base,
      query: q,
      page: page,
      perPage: perPage,
      order: orderParam(app),
      sort: app.orderAsc ? 'asc' : 'desc',
      subtitle: app.subOnly ? true : null,
      seed: app.category == 'rec' ? app.randomSeed?.toString() : null,
    );
    return parseWorks(json, base: base, perPage: perPage);
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

  /// kikoeru-express 的 nsfw 参数：1=全年龄 2=仅R18（服务端无 R15 分级，按全年龄处理）
  static int? customNsfw(int? ageFilter) {
    return switch (ageFilter) {
      null => null,
      0 => 1,
      1 => 1,
      2 => 2,
      _ => null,
    };
  }

  /// asmr.one 的年龄标签（用作搜索关键词）
  static String? oneAgeTag(int? ageFilter) {
    return switch (ageFilter) {
      0 => r'$age:general$',
      1 => r'$age:r15$',
      2 => r'$age:adult$',
      _ => null,
    };
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
  }) async {
    final json = await apiGetMyReviews(
      base: resolveBase(app),
      page: page,
      perPage: perPage,
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
    LyricCandidate? pick,
  }) async {
    final apiId = w.apiId;
    if (apiId == null) return const [];
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
    // 与当前曲目同名的歌词优先（如 Track01.mp3 -> Track01.lrc）
    final trackBase = _baseName(trackTitle ?? '');
    if (trackBase.isNotEmpty) {
      for (final c in candidates) {
        if (_baseName(c.title) == trackBase) c.score += 80;
      }
    }
    candidates.sort((a, b) => b.score.compareTo(a.score));
    // 按分数从高到低尝试，直到解析出带时间轴的歌词
    for (final c in candidates.take(3)) {
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
  }) async {
    final apiId = w.apiId;
    if (apiId == null) return const [];
    final nodes = await fetchTracks(app, apiId);
    final candidates = _findLyricCandidates(nodes);
    final trackBase = _baseName(trackTitle ?? '');
    if (trackBase.isNotEmpty) {
      for (final c in candidates) {
        if (_baseName(c.title) == trackBase) c.score += 80;
      }
    }
    candidates.sort((a, b) => b.score.compareTo(a.score));
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
      if (lower.endsWith('.lrc')) score += 20;
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

  /// 拉丁语种码按整词匹配，避免误伤（如 en 不匹配 special/English 以外的单词）
  static bool _pathHas(String s, String hint) {
    if (RegExp(r'^[a-z][a-z0-9-]*$').hasMatch(hint)) {
      return RegExp(
        '(?<![a-z0-9])${RegExp.escape(hint)}(?![a-z0-9])',
      ).hasMatch(s);
    }
    return s.contains(hint);
  }

  static String _baseName(String name) {
    final i = name.lastIndexOf('.');
    return i > 0 ? name.substring(0, i).toLowerCase() : name.toLowerCase();
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
    int workApiId,
  ) async {
    final key = _tracksKey(app, workApiId);
    final cached = _tracksCache[key];
    if (cached != null) return cached;
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
      final rawUrl =
          m['mediaUrl'] as String? ??
          m['mediaStreamUrl'] as String? ??
          m['streamUrl'] as String? ??
          m['url'] as String? ??
          (hash != null ? '/api/media/stream/$hash' : null);
      final url = rawUrl == null ? null : _resolveMediaUrl(base, rawUrl);
      return MediaNode(
        title: title,
        type: type,
        path: path,
        url: url,
        duration: (m['duration'] as num?)?.toInt() ?? 0,
        children: _parseNodes(raw is List ? raw : null, path, base),
      );
    }).toList();
    // 文件夹始终在文件前，同级按文件名自然排序（数字感知）
    nodes.sort((a, b) {
      if (a.isDir != b.isDir) return a.isDir ? -1 : 1;
      return _naturalCompare(a.title, b.title);
    });
    return nodes;
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
    return Work(
      rj:
          m['source_id'] as String? ??
          (apiId != null ? 'RJ$apiId' : 'RJ00000000'),
      title: m['title'] as String? ?? '未知作品',
      circle: circle,
      va: vas.isEmpty ? 'CV. 未知' : 'CV. $vas',
      age: age,
      dur: _fmtDuration((m['duration'] as num?)?.toInt() ?? 0),
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
    );
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
