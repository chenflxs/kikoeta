import 'dart:convert';
import 'dart:io' show HttpClient;

import 'package:http/http.dart' as http;
import 'package:http/io_client.dart';
import '../l10n/strings.dart';

const lyricsLibraryApiPath = 'api/lyrics-library/v1';

class RemoteLibraryWork {
  final String workId;
  final bool isAi;
  final bool isTranslated;
  final int fileCount;

  const RemoteLibraryWork({
    required this.workId,
    required this.isAi,
    this.isTranslated = false,
    required this.fileCount,
  });
}

class RemoteLibraryFileInfo {
  final String relativePath;
  final String name;
  final String extension;
  final bool isAi;
  final bool isTranslated;

  const RemoteLibraryFileInfo({
    required this.relativePath,
    required this.name,
    required this.extension,
    required this.isAi,
    this.isTranslated = false,
  });
}

class RemoteLibraryFile {
  final String relativePath;
  final List<int> bytes;
  final bool isAi;
  final bool isTranslated;

  const RemoteLibraryFile({
    required this.relativePath,
    required this.bytes,
    required this.isAi,
    this.isTranslated = false,
  });
}

/// HTTP client for the read-only lyrics library broadcast API.
class LyricsLibraryRemoteClient {
  LyricsLibraryRemoteClient._();

  static http.Client _newClient() =>
      IOClient(HttpClient()..connectionTimeout = const Duration(seconds: 10));

  static Uri normalizeBaseUrl(String value) {
    final input = value.trim();
    final uri = Uri.tryParse(input);
    if (uri == null ||
        !const {'http', 'https'}.contains(uri.scheme.toLowerCase()) ||
        uri.host.isEmpty ||
        uri.userInfo.isNotEmpty ||
        uri.hasQuery ||
        uri.hasFragment) {
      throw FormatException(
        appL10n.lyricsLibraryRemoteClientNormalizeBaseUrlFormatException,
      );
    }
    return uri.replace(path: uri.path.replaceFirst(RegExp(r'/+$'), ''));
  }

  static Uri _uri(String baseUrl, String suffix) {
    final base = normalizeBaseUrl(baseUrl);
    final basePath = base.path.replaceFirst(RegExp(r'/+$'), '');
    return base.replace(path: '$basePath/$lyricsLibraryApiPath/$suffix');
  }

  static Future<Map<String, dynamic>> _getJson(
    Uri uri, {
    Duration timeout = const Duration(seconds: 30),
    http.Client? client,
  }) async {
    final activeClient = client ?? _newClient();
    try {
      final request = http.Request('GET', uri)
        ..headers['accept'] = 'application/json';
      final response = await activeClient.send(request).timeout(timeout);
      if (response.statusCode != 200) {
        throw HttpException(
          appL10n.lyricsLibraryRemoteClientGetJsonHttpException(
            (response.statusCode).toString(),
          ),
        );
      }
      final bytes = await http.ByteStream(
        response.stream.timeout(const Duration(seconds: 30)),
      ).toBytes();
      final decoded = jsonDecode(utf8.decode(bytes));
      if (decoded is! Map<String, dynamic>) {
        throw FormatException(
          appL10n.lyricsLibraryRemoteClientGetJsonFormatException,
        );
      }
      return decoded;
    } finally {
      if (client == null) activeClient.close();
    }
  }

  static Future<List<RemoteLibraryWork>> fetchWorks(String baseUrl) async {
    final works = <RemoteLibraryWork>[];
    final client = _newClient();
    String? cursor;
    try {
      do {
        final params = <String, String>{'limit': '1000'};
        if (cursor != null) params['after'] = cursor;
        final uri = _uri(baseUrl, 'works').replace(queryParameters: params);
        // Older servers ignore pagination and return the entire index. Allow
        // them more time while newer servers send bounded pages.
        final response = await _getJson(
          uri,
          timeout: const Duration(minutes: 3),
          client: client,
        );
        final rawWorks = response['works'];
        if (rawWorks is! List) {
          throw FormatException(
            appL10n.lyricsLibraryRemoteClientFetchWorksFormatException2,
          );
        }
        works.addAll(_parseWorks(rawWorks));
        final next = response['nextCursor'];
        if (next == null) break;
        if (next is! String ||
            !RegExp(r'^(?:RJ|VJ|BJ)\d+$').hasMatch(next) ||
            (cursor != null && next.compareTo(cursor) <= 0)) {
          throw FormatException(
            appL10n.lyricsLibraryRemoteClientFetchWorksFormatException,
          );
        }
        cursor = next;
      } while (true);
    } finally {
      client.close();
    }
    return works;
  }

  static List<RemoteLibraryWork> _parseWorks(List rawWorks) => rawWorks
      .whereType<Map>()
      .map((raw) {
        final id = raw['workId']?.toString().toUpperCase() ?? '';
        final count = raw['fileCount'];
        return RemoteLibraryWork(
          workId: id,
          isAi: raw['isAi'] == true,
          isTranslated: raw['isTranslated'] == true,
          fileCount: count is num ? count.toInt().clamp(0, 100000) : 0,
        );
      })
      .where((work) => RegExp(r'^(?:RJ|VJ|BJ)\d+$').hasMatch(work.workId))
      .toList();

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
            isTranslated: raw['isTranslated'] == true,
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
      throw FormatException(
        appL10n.lyricsLibraryRemoteClientFetchLyricsFormatException,
      );
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
            isTranslated: raw['isTranslated'] == true,
          ),
        );
      } on FormatException {
        // Ignore a malformed file while retaining other valid files.
      }
    }
    if (files.isEmpty) {
      throw FormatException(
        appL10n.lyricsLibraryRemoteClientFetchLyricsFormatException2,
      );
    }
    return files;
  }

  static String _validateWorkId(String value) {
    final id = value.trim().toUpperCase();
    if (!RegExp(r'^(?:RJ|VJ|BJ)\d+$').hasMatch(id)) {
      throw FormatException(
        appL10n.lyricsLibraryRemoteClientValidateWorkIdFormatException,
      );
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
