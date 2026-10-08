import 'dart:convert';
import 'dart:io';

class DownloadTransferCancelled implements Exception {
  const DownloadTransferCancelled();
}

/// Downloads to a temporary file and promotes it only after a complete response.
/// A saved validator ties resumable bytes to the same remote representation.
Future<void> downloadToFile({
  required Uri uri,
  required File target,
  required String sourceUrl,
  required bool Function() isCancelled,
  required void Function(HttpClientRequest?) onRequest,
  required void Function(int downloaded, int total) onProgress,
  void Function(void Function()? cancel)? onCancel,
}) async {
  void checkCancelled() {
    if (isCancelled()) throw const DownloadTransferCancelled();
  }

  checkCancelled();
  await target.parent.create(recursive: true);
  final partial = File('${target.path}.part');
  final metadata = File('${partial.path}.json');
  var saved = await _PartialInfo.read(metadata, sourceUrl);
  var existing = await partial.exists() ? await partial.length() : 0;
  if (saved == null || (saved.total != null && existing > saved.total!)) {
    // Older or unrelated partial files cannot establish representation identity.
    existing = 0;
    saved = null;
  }
  final client = HttpClient()
    ..autoUncompress = false
    ..connectionTimeout = const Duration(seconds: 20)
    ..idleTimeout = const Duration(minutes: 5);
  RandomAccessFile? output;
  try {
    // Request.abort cannot stop a response stream after its headers arrived.
    // Closing this transfer's client also interrupts a stalled response body.
    onCancel?.call(() => client.close(force: true));
    while (true) {
      checkCancelled();
      final request = await client.getUrl(uri);
      onRequest(request);
      checkCancelled();
      request.headers.set(HttpHeaders.acceptEncodingHeader, 'identity');
      if (existing > 0 && saved != null) {
        request.headers.set(HttpHeaders.rangeHeader, 'bytes=$existing-');
        request.headers.set(HttpHeaders.ifRangeHeader, saved.validator);
      }
      final response = await request.close();
      checkCancelled();
      final status = response.statusCode;
      if (status == HttpStatus.requestedRangeNotSatisfiable && existing > 0) {
        final total = _unsatisfiedTotal(response);
        if (total != null &&
            total == existing &&
            saved?.total == total &&
            saved!.matches(response)) {
          await response.listen(null).cancel();
          checkCancelled();
          if (await partial.length() != total) {
            throw HttpException('下载分片长度发生变化', uri: uri);
          }
          onProgress(total, total);
          checkCancelled();
          await partial.rename(target.path);
          await _deleteMetadata(metadata, ignoreErrors: true);
          return;
        }
        // A 416 alone cannot prove that the local bytes are complete or current.
        await response.listen(null).cancel();
        existing = 0;
        saved = null;
        continue;
      }
      if (status != HttpStatus.ok && status != HttpStatus.partialContent) {
        throw HttpException('下载失败 HTTP $status', uri: uri);
      }
      final encoding = response.headers.value(
        HttpHeaders.contentEncodingHeader,
      );
      if (encoding != null && encoding.toLowerCase() != 'identity') {
        throw HttpException('下载响应使用了非原始字节编码', uri: uri);
      }

      final range = status == HttpStatus.partialContent
          ? _ContentRange.parse(response)
          : null;
      final responseLength = response.contentLength;
      if (status == HttpStatus.partialContent) {
        if (range == null ||
            range.start != existing ||
            range.end != range.total - 1 ||
            (responseLength >= 0 && responseLength != range.length)) {
          throw HttpException('下载响应的字节范围不匹配', uri: uri);
        }
        if (existing > 0 &&
            (saved == null ||
                !saved.matches(response) ||
                (saved.total != null && saved.total != range.total))) {
          await response.listen(null).cancel();
          existing = 0;
          saved = null;
          continue;
        }
      } else {
        // A full response to If-Range is the current file, never an append.
        existing = 0;
      }
      final total = range?.total ?? (responseLength >= 0 ? responseLength : 0);
      final expectedLength = range?.length ?? responseLength;
      final info = _PartialInfo.fromResponse(response, sourceUrl, total);
      checkCancelled();
      output = await partial.open(
        mode: existing > 0 ? FileMode.append : FileMode.write,
      );
      // Clear old identity before writing new bytes. Missing validators still
      // permit full downloads, but their interrupted bytes are restarted later.
      await _deleteMetadata(metadata);
      if (info != null) {
        await metadata.writeAsString(jsonEncode(info.toJson()), flush: true);
      }
      checkCancelled();
      var received = existing;
      onProgress(received, total);
      await for (final chunk in response) {
        checkCancelled();
        if (expectedLength >= 0 &&
            received - existing + chunk.length > expectedLength) {
          throw HttpException('下载响应超过声明的文件长度', uri: uri);
        }
        await output.writeFrom(chunk);
        received += chunk.length;
        onProgress(received, total);
        checkCancelled();
      }
      checkCancelled();
      if (expectedLength >= 0 && received - existing != expectedLength) {
        throw HttpException('下载响应不完整', uri: uri);
      }
      await output.flush();
      await output.close();
      output = null;
      checkCancelled();
      if (await partial.length() != received ||
          (total > 0 && received != total)) {
        throw HttpException('下载文件长度校验失败', uri: uri);
      }
      checkCancelled();
      await partial.rename(target.path);
      await _deleteMetadata(metadata, ignoreErrors: true);
      return;
    }
  } catch (_) {
    if (isCancelled()) throw const DownloadTransferCancelled();
    rethrow;
  } finally {
    try {
      await output?.close();
    } finally {
      onRequest(null);
      onCancel?.call(null);
      client.close(force: true);
    }
  }
}

Future<void> _deleteMetadata(File metadata, {bool ignoreErrors = false}) async {
  try {
    if (await metadata.exists()) await metadata.delete();
  } catch (_) {
    if (!ignoreErrors) rethrow;
  }
}

class _PartialInfo {
  const _PartialInfo(this.sourceUrl, this.header, this.validator, this.total);

  final String sourceUrl;
  final String header;
  final String validator;
  final int? total;

  bool matches(HttpClientResponse response) =>
      response.headers.value(header) == validator;

  Map<String, Object?> toJson() => {
    'sourceUrl': sourceUrl,
    if (header == HttpHeaders.etagHeader) 'etag': validator,
    if (header == HttpHeaders.lastModifiedHeader) 'lastModified': validator,
    'total': total,
  };

  static _PartialInfo? fromResponse(
    HttpClientResponse response,
    String sourceUrl,
    int total,
  ) => _fromValues(
    sourceUrl,
    response.headers.value(HttpHeaders.etagHeader),
    response.headers.value(HttpHeaders.lastModifiedHeader),
    total > 0 ? total : null,
  );

  static Future<_PartialInfo?> read(File file, String sourceUrl) async {
    try {
      if (!await file.exists()) return null;
      final json = jsonDecode(await file.readAsString());
      if (json is! Map || json['sourceUrl'] != sourceUrl) return null;
      final total = json['total'];
      if (total != null && (total is! int || total < 0)) return null;
      return _fromValues(
        sourceUrl,
        json['etag'],
        json['lastModified'],
        total as int?,
      );
    } catch (_) {
      return null;
    }
  }

  static _PartialInfo? _fromValues(
    String sourceUrl,
    Object? etag,
    Object? lastModified,
    int? total,
  ) {
    if (etag is String &&
        RegExp(r'^"[\x21\x23-\x7e\x80-\xff]*"$').hasMatch(etag)) {
      return _PartialInfo(sourceUrl, HttpHeaders.etagHeader, etag, total);
    }
    if (lastModified is String) {
      try {
        HttpDate.parse(lastModified);
        return _PartialInfo(
          sourceUrl,
          HttpHeaders.lastModifiedHeader,
          lastModified,
          total,
        );
      } catch (_) {
        return null;
      }
    }
    return null;
  }
}

class _ContentRange {
  const _ContentRange(this.start, this.end, this.total);

  final int start;
  final int end;
  final int total;
  int get length => end - start + 1;

  static _ContentRange? parse(HttpClientResponse response) {
    final value = response.headers.value(HttpHeaders.contentRangeHeader);
    final match = value == null
        ? null
        : RegExp(r'^bytes ([0-9]+)-([0-9]+)/([0-9]+)$').firstMatch(value);
    if (match == null) return null;
    final start = int.tryParse(match.group(1)!);
    final end = int.tryParse(match.group(2)!);
    final total = int.tryParse(match.group(3)!);
    if (start == null ||
        end == null ||
        total == null ||
        start > end ||
        end >= total) {
      return null;
    }
    return _ContentRange(start, end, total);
  }
}

int? _unsatisfiedTotal(HttpClientResponse response) {
  final value = response.headers.value(HttpHeaders.contentRangeHeader);
  final match = value == null
      ? null
      : RegExp(r'^bytes \*/([0-9]+)$').firstMatch(value);
  return match == null ? null : int.tryParse(match.group(1)!);
}
