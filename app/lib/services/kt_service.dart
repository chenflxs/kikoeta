import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

class KtSourceFile {
  final String url;
  final String name;
  final Map<String, String> headers;

  const KtSourceFile({
    required this.url,
    required this.name,
    this.headers = const {},
  });

  Map<String, dynamic> toJson() => {
    'url': url,
    'name': name,
    if (headers.isNotEmpty) 'headers': headers,
  };
}

class KtEventsBatch {
  final List<Map<String, dynamic>> events;
  final int cursor;
  final bool closed;

  const KtEventsBatch({
    required this.events,
    required this.cursor,
    required this.closed,
  });
}

class KtCachedLyricsFile {
  final String trackPath;
  final String name;
  final String downloadUrl;

  const KtCachedLyricsFile({
    required this.trackPath,
    required this.name,
    required this.downloadUrl,
  });

  factory KtCachedLyricsFile.fromJson(Map<String, dynamic> json) =>
      KtCachedLyricsFile(
        trackPath: json['track_path']?.toString() ?? '',
        name: json['name']?.toString() ?? '',
        downloadUrl: json['download_url']?.toString() ?? '',
      );
}

class KtCachedResult {
  final String jobId;
  final String workId;
  final List<KtCachedLyricsFile> files;

  const KtCachedResult({
    required this.jobId,
    required this.workId,
    required this.files,
  });

  factory KtCachedResult.fromJson(Map<String, dynamic> json) {
    final rawFiles = json['files'];
    return KtCachedResult(
      jobId: json['job_id']?.toString() ?? '',
      workId: json['work_id']?.toString() ?? '',
      files: rawFiles is List
          ? rawFiles
                .whereType<Map>()
                .map(
                  (item) => KtCachedLyricsFile.fromJson(
                    Map<String, dynamic>.from(item),
                  ),
                )
                .toList()
          : const [],
    );
  }
}

class KtService {
  static const defaultUsername = 'admin';
  static const defaultPassword = 'kikoeta';

  final String endpoint;
  final http.Client _client;
  final String username;
  final String password;

  KtService(
    String endpoint, {
    this.username = defaultUsername,
    this.password = defaultPassword,
    http.Client? client,
  }) : endpoint = normalizeEndpoint(endpoint),
       _client = client ?? http.Client();

  static String normalizeEndpoint(String value) {
    var text = value.trim();
    if (text.isEmpty) {
      throw const FormatException('请输入 kikoeta-transl 的 IP/域名与端口');
    }
    if (!text.contains('://')) text = 'http://$text';
    final uri = Uri.tryParse(text);
    if (uri == null ||
        (uri.scheme != 'http' && uri.scheme != 'https') ||
        uri.host.isEmpty ||
        !_hasExplicitPort(text)) {
      throw const FormatException('连接地址格式应为 IP/域名:端口');
    }
    final clean = uri.replace(
      path: uri.path == '/' ? '' : uri.path.replaceFirst(RegExp(r'/+$'), ''),
      query: null,
      fragment: null,
    );
    return clean.toString().replaceFirst(RegExp(r'/+$'), '');
  }

  static bool _hasExplicitPort(String value) {
    final match = RegExp(
      r'^[A-Za-z][A-Za-z0-9+.-]*://([^/?#]+)',
    ).firstMatch(value);
    final authority = match?.group(1) ?? '';
    if (authority.startsWith('[')) {
      return RegExp(r'\]:\d+$').hasMatch(authority);
    }
    return RegExp(r':\d+$').hasMatch(authority);
  }

  Future<Map<String, dynamic>> health() => _getJson('/api/v1/health');

  Future<Map<String, dynamic>> createJob(
    List<KtSourceFile> files, {
    String? cacheWorkId,
    List<String> cacheTrackPaths = const [],
  }) => _postJson('/api/v1/jobs', {
    'files': files.map((file) => file.toJson()).toList(),
    'flags': {'enable_correct': false, 'enable_translate': true},
    'settings': {
      'output': {
        'preset': 'target_lrc',
        'formats': ['lrc'],
        'bilingual': false,
      },
    },
    if (cacheWorkId != null &&
        cacheWorkId.trim().isNotEmpty &&
        cacheTrackPaths.isNotEmpty)
      'cache': {'work_id': cacheWorkId.trim(), 'track_paths': cacheTrackPaths},
  });

  Future<Map<String, dynamic>> job(String jobId) =>
      _getJson('/api/v1/jobs/$jobId');

  Future<KtEventsBatch> events(String jobId, int cursor) async {
    final body = await _getJson('/api/v1/jobs/$jobId/events?after=$cursor');
    final raw = body['events'];
    return KtEventsBatch(
      events: raw is List
          ? raw
                .whereType<Map>()
                .map((item) => Map<String, dynamic>.from(item))
                .toList()
          : const [],
      cursor: (body['cursor'] as num?)?.toInt() ?? cursor,
      closed: body['closed'] == true,
    );
  }

  Future<List<KtCachedResult>> cachedResults() async {
    final body = await _getJson('/api/v1/cache');
    final raw = body['entries'];
    if (raw is! List) return const [];
    return raw
        .whereType<Map>()
        .map((item) => KtCachedResult.fromJson(Map<String, dynamic>.from(item)))
        .where((entry) => entry.workId.isNotEmpty && entry.files.isNotEmpty)
        .toList();
  }

  Future<void> cancel(String jobId) async {
    await _postJson('/api/v1/jobs/$jobId/cancel', const {});
  }

  Future<Uint8List> download(String path) async {
    final response = await _client
        .get(_uri(path), headers: _headers())
        .timeout(const Duration(seconds: 60));
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw KtServiceException(_errorMessage(response), response.statusCode);
    }
    return response.bodyBytes;
  }

  void close() => _client.close();

  Future<Map<String, dynamic>> _getJson(String path) async {
    final response = await _client
        .get(_uri(path), headers: _headers())
        .timeout(const Duration(seconds: 30));
    return _decode(response);
  }

  Future<Map<String, dynamic>> _postJson(
    String path,
    Map<String, dynamic> body,
  ) async {
    final response = await _client
        .post(_uri(path), headers: _headers(json: true), body: jsonEncode(body))
        .timeout(const Duration(seconds: 120));
    return _decode(response);
  }

  Uri _uri(String path) =>
      Uri.parse('$endpoint${path.startsWith('/') ? path : '/$path'}');

  Map<String, String> _headers({bool json = false}) => {
    'accept': 'application/json',
    'authorization':
        'Basic ${base64Encode(utf8.encode('$username:$password'))}',
    if (json) 'content-type': 'application/json; charset=utf-8',
  };

  Map<String, dynamic> _decode(http.Response response) {
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw KtServiceException(_errorMessage(response), response.statusCode);
    }
    final value = jsonDecode(utf8.decode(response.bodyBytes));
    if (value is! Map) {
      throw const FormatException('kikoeta-transl 返回了无效响应');
    }
    return Map<String, dynamic>.from(value);
  }

  String _errorMessage(http.Response response) {
    try {
      final value = jsonDecode(utf8.decode(response.bodyBytes));
      if (value is Map && value['error'] != null) {
        return value['error'].toString();
      }
    } catch (_) {}
    return 'kikoeta-transl 请求失败（HTTP ${response.statusCode}）';
  }
}

class KtServiceException implements Exception {
  final String message;
  final int statusCode;
  const KtServiceException(this.message, this.statusCode);

  @override
  String toString() => message;
}

String ktLyricsRelativePath(String workId, String trackPath) {
  final id = workId.trim().toUpperCase();
  final raw = trackPath.replaceAll('\\', '/').split('/');
  final safe = raw
      .where((part) => part.isNotEmpty && part != '.' && part != '..')
      .map(_safePathPart)
      .where((part) => part.isNotEmpty)
      .toList();
  final leaf = safe.isEmpty ? 'track' : safe.removeLast();
  final dot = leaf.lastIndexOf('.');
  final stem = dot > 0 ? leaf.substring(0, dot) : leaf;
  final result = <String>[
    id,
    ...safe,
    '${stem.isEmpty ? 'track' : stem}.zh.lrc',
  ];
  return result.join('/');
}

String ktUploadName(int index, String title) {
  final safe = _safePathPart(title.trim());
  return '${index.toString().padLeft(3, '0')}_${safe.isEmpty ? 'track.mp3' : safe}';
}

String _safePathPart(String value) => value
    .replaceAll(RegExp(r'[<>:"/\\|?*\x00-\x1F]'), '_')
    .replaceAll(RegExp(r'[. ]+$'), '')
    .trim();
