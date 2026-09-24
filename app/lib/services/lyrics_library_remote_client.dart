import 'dart:convert';

import 'package:http/http.dart' as http;

const lyricsLibraryApiPath = 'api/lyrics-library/v1';

class RemoteLibraryWork {
  final String workId;
  final bool isAi;
  final int fileCount;

  const RemoteLibraryWork({
    required this.workId,
    required this.isAi,
    required this.fileCount,
  });
}

class RemoteLibraryFileInfo {
  final String relativePath;
  final String name;
  final String extension;
  final bool isAi;

  const RemoteLibraryFileInfo({
    required this.relativePath,
    required this.name,
    required this.extension,
    required this.isAi,
  });
}

class RemoteLibraryFile {
  final String relativePath;
  final List<int> bytes;
  final bool isAi;

  const RemoteLibraryFile({
    required this.relativePath,
    required this.bytes,
    required this.isAi,
  });
}

/// HTTP client for the read-only lyrics library broadcast API.
class LyricsLibraryRemoteClient {
  LyricsLibraryRemoteClient._();

  static Uri normalizeBaseUrl(String value) {
    final input = value.trim();
    final uri = Uri.tryParse(input);
    if (uri == null ||
        !const {'http', 'https'}.contains(uri.scheme.toLowerCase()) ||
        uri.host.isEmpty ||
        uri.userInfo.isNotEmpty ||
        uri.hasQuery ||
        uri.hasFragment) {
      throw const FormatException('请输入有效的 HTTP 或 HTTPS 地址');
    }
    return uri.replace(path: uri.path.replaceFirst(RegExp(r'/+$'), ''));
  }

  static Uri _uri(String baseUrl, String suffix) {
    final base = normalizeBaseUrl(baseUrl);
    final basePath = base.path.replaceFirst(RegExp(r'/+$'), '');
    return base.replace(path: '$basePath/$lyricsLibraryApiPath/$suffix');
  }

  static Future<Map<String, dynamic>> _getJson(Uri uri) async {
    final response = await http
        .get(uri, headers: const {'accept': 'application/json'})
        .timeout(const Duration(seconds: 30));
    if (response.statusCode != 200) {
      throw HttpException('远程歌词库返回 HTTP ${response.statusCode}');
    }
    final decoded = jsonDecode(utf8.decode(response.bodyBytes));
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('远程歌词库返回的数据格式无效');
    }
    return decoded;
  }

  static Future<List<RemoteLibraryWork>> fetchWorks(String baseUrl) async {
    final response = await _getJson(_uri(baseUrl, 'works'));
    final rawWorks = response['works'];
    if (rawWorks is! List) {
      throw const FormatException('远程歌词库未提供作品列表');
    }
    return rawWorks
        .whereType<Map>()
        .map((raw) {
          final id = raw['workId']?.toString().toUpperCase() ?? '';
          final count = raw['fileCount'];
          return RemoteLibraryWork(
            workId: id,
            isAi: raw['isAi'] == true,
            fileCount: count is num ? count.toInt().clamp(0, 100000) : 0,
          );
        })
        .where((work) => RegExp(r'^(?:RJ|VJ|BJ)\d+$').hasMatch(work.workId))
        .toList();
  }

  static Future<List<RemoteLibraryFileInfo>> fetchFileIndex(
    String baseUrl,
    String workId,
  ) async {
    final id = _validateWorkId(workId);
    final response = await _getJson(_uri(baseUrl, 'works/$id/files'));
    final rawFiles = response['files'];
    if (rawFiles is! List) return const [];
    return rawFiles
        .whereType<Map>()
        .map((raw) {
          final path = _safeRelativePath(raw['relativePath']?.toString() ?? '');
          final name = raw['name']?.toString() ?? path.split('/').last;
          final extension = raw['extension']?.toString().toLowerCase() ?? '';
          return RemoteLibraryFileInfo(
            relativePath: path,
            name: name,
            extension: extension,
            isAi: raw['isAi'] == true,
          );
        })
        .where((file) => file.relativePath.isNotEmpty)
        .toList();
  }

  static Future<List<RemoteLibraryFile>> fetchLyrics(
    String baseUrl,
    String workId,
  ) async {
    final id = _validateWorkId(workId);
    final response = await _getJson(_uri(baseUrl, 'works/$id/lyrics'));
    final rawFiles = response['files'];
    if (rawFiles is! List) {
      throw const FormatException('远程作品没有歌词文件列表');
    }
    final files = <RemoteLibraryFile>[];
    for (final raw in rawFiles.whereType<Map>()) {
      final path = _safeRelativePath(raw['relativePath']?.toString() ?? '');
      final encoded = raw['content']?.toString() ?? '';
      if (path.isEmpty || encoded.isEmpty) continue;
      try {
        files.add(
          RemoteLibraryFile(
            relativePath: path,
            bytes: base64Decode(encoded),
            isAi: raw['isAi'] == true,
          ),
        );
      } on FormatException {
        // Ignore a malformed file while retaining other valid files.
      }
    }
    if (files.isEmpty) throw const FormatException('远程作品没有可用歌词文件');
    return files;
  }

  static String _validateWorkId(String value) {
    final id = value.trim().toUpperCase();
    if (!RegExp(r'^(?:RJ|VJ|BJ)\d+$').hasMatch(id)) {
      throw const FormatException('无效的作品号');
    }
    return id;
  }

  static String _safeRelativePath(String value) {
    final normalized = value.replaceAll('\\', '/');
    if (normalized.startsWith('/') ||
        normalized.contains(':') ||
        normalized
            .split('/')
            .any((part) => part.isEmpty || part == '.' || part == '..')) {
      return '';
    }
    return normalized;
  }
}

class HttpException implements Exception {
  final String message;
  const HttpException(this.message);

  @override
  String toString() => message;
}
