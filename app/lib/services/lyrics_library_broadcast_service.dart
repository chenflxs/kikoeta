import 'dart:convert';
import 'dart:io';

import 'lyrics_library_service.dart';

/// Read-only HTTP broadcast for the local lyrics library.
class LyricsLibraryBroadcastService {
  LyricsLibraryBroadcastService._();

  static final instance = LyricsLibraryBroadcastService._();
  static const port = 2377;

  HttpServer? _server;

  bool get isRunning => _server != null;

  Future<void> start() async {
    if (_server != null) return;
    final server = await HttpServer.bind(InternetAddress.anyIPv4, port);
    _server = server;
    server.listen(_handleRequest, onError: (_) => stop());
  }

  Future<void> stop() async {
    final server = _server;
    _server = null;
    await server?.close(force: true);
  }

  Future<void> setEnabled(bool enabled) async {
    if (enabled) {
      await start();
    } else {
      await stop();
    }
  }

  Future<void> _handleRequest(HttpRequest request) async {
    try {
      if (request.method != 'GET') {
        await _writeJson(request.response, 405, {'error': 'read_only'});
        return;
      }
      final segments = request.uri.pathSegments;
      if (segments.length < 4 ||
          segments[0] != 'api' ||
          segments[1] != 'lyrics-library' ||
          segments[2] != 'v1' ||
          segments[3] != 'works') {
        await _writeJson(request.response, 404, {'error': 'not_found'});
        return;
      }

      final service = LyricsLibraryService.instance;
      final records = (await service.records())
          .where((record) => !record.online)
          .toList();
      if (segments.length == 4) {
        final ids = records.map((record) => record.workId).toSet().toList()
          ..sort();
        final counts = await service.countFilesForWorks(ids);
        await _writeJson(request.response, 200, {
          'version': 1,
          'works': ids
              .where((id) => (counts[id] ?? 0) > 0)
              .map(
                (id) => {
                  'workId': id,
                  'isAi': records.any(
                    (record) => record.workId == id && record.isAi,
                  ),
                  'fileCount': counts[id] ?? 0,
                },
              )
              .toList(),
        });
        return;
      }

      if (segments.length != 6) {
        await _writeJson(request.response, 404, {'error': 'not_found'});
        return;
      }
      final workId = segments[4].toUpperCase();
      if (!RegExp(r'^(?:RJ|VJ|BJ)\d+$').hasMatch(workId) ||
          !records.any((record) => record.workId == workId)) {
        await _writeJson(request.response, 404, {'error': 'work_not_found'});
        return;
      }
      final operation = segments[5];
      final files = await service.listFiles(workId: workId);
      if (operation == 'files') {
        await _writeJson(request.response, 200, {
          'workId': workId,
          'files': files.map((file) => _fileMetadata(file, records)).toList(),
        });
        return;
      }
      if (operation == 'lyrics') {
        final output = <Map<String, dynamic>>[];
        for (final file in files) {
          try {
            final bytes = await File(file.absolutePath).readAsBytes();
            output.add({
              ..._fileMetadata(file, records),
              'content': base64Encode(bytes),
            });
          } catch (_) {}
        }
        await _writeJson(request.response, 200, {
          'workId': workId,
          'files': output,
        });
        return;
      }
      await _writeJson(request.response, 404, {'error': 'not_found'});
    } catch (_) {
      try {
        await _writeJson(request.response, 500, {'error': 'request_failed'});
      } catch (_) {}
    }
  }

  Map<String, dynamic> _fileMetadata(
    LyricsLibraryFile file,
    List<LyricsLibraryRecord> records,
  ) {
    final owners =
        records
            .where(
              (record) =>
                  record.workId == file.workId &&
                  !record.online &&
                  (file.relativePath == record.relativePath ||
                      file.relativePath.startsWith('${record.relativePath}/')),
            )
            .toList()
          ..sort(
            (a, b) => b.relativePath.length.compareTo(a.relativePath.length),
          );
    final owner = owners.isEmpty ? null : owners.first;
    final prefix = '${owner?.relativePath ?? file.workId}/';
    final relativePath = file.relativePath.startsWith(prefix)
        ? file.relativePath.substring(prefix.length)
        : file.name;
    return {
      'relativePath': relativePath,
      'name': file.name,
      'extension': file.extension,
      'isAi': owner?.isAi ?? false,
    };
  }

  Future<void> _writeJson(
    HttpResponse response,
    int status,
    Map<String, Object?> data,
  ) async {
    response.statusCode = status;
    response.headers.contentType = ContentType.json;
    response.headers.set(HttpHeaders.cacheControlHeader, 'no-store');
    response.headers.set('x-content-type-options', 'nosniff');
    response.write(jsonEncode(data));
    await response.close();
  }
}
