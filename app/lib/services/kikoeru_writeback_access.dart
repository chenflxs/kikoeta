import 'dart:convert';

import 'package:http/http.dart' as http;

enum KikoeruWritebackStatus {
  unknown,
  allowed,
  disabled,
  unsupported,
  loginRequired,
  roleForbidden,
  keyRequired,
  keyInvalid,
  unconfigured,
  sourceUnavailable,
  directoryUnwritable,
  conflict,
  networkError,
  failed,
}

class KikoeruWritebackCredentials {
  static final _keyPattern = RegExp(r'^[A-Za-z0-9]{16}$');
  final String? authorization;
  final String key;
  const KikoeruWritebackCredentials({this.authorization, this.key = ''});

  static bool isValidKey(String key) =>
      key.length == 16 && _keyPattern.hasMatch(key);

  Map<String, String> get headers => {
    if (authorization?.isNotEmpty == true) 'Authorization': authorization!,
    if (isValidKey(key)) 'X-Kikoeru-Writeback-Key': key,
  };
}

/// Read-only policy discovery and permission checks; uploading uses the same
/// protected endpoint as older servers.
class KikoeruWritebackAccess {
  final Uri endpoint;
  final KikoeruWritebackCredentials Function() credentials;
  final http.Client _client = http.Client();
  String authentication = 'unknown';
  KikoeruWritebackStatus status = KikoeruWritebackStatus.unknown;

  KikoeruWritebackAccess._(this.endpoint, this.credentials);

  static String? normalizeBase(String? sourceBase) {
    final base = sourceBase == null ? null : Uri.tryParse(sourceBase.trim());
    if (base == null ||
        !const {'http', 'https'}.contains(base.scheme) ||
        base.host.isEmpty ||
        base.userInfo.isNotEmpty ||
        base.hasQuery ||
        base.hasFragment) {
      return null;
    }
    final path = base.path.replaceFirst(RegExp(r'/+$'), '');
    return base.replace(path: path).toString();
  }

  static KikoeruWritebackAccess? connect(
    String? sourceBase,
    KikoeruWritebackCredentials Function() credentials,
  ) {
    final normalized = normalizeBase(sourceBase);
    if (normalized == null) return null;
    final base = Uri.parse(normalized);
    return KikoeruWritebackAccess._(
      base.replace(path: '${base.path}/api/media/kikoeta-lyrics'),
      credentials,
    );
  }

  bool get needsKey =>
      !const {
        KikoeruWritebackStatus.disabled,
        KikoeruWritebackStatus.unsupported,
      }.contains(status) &&
      (authentication == 'account_and_key' ||
          (authentication == 'legacy' &&
              (credentials().key.isNotEmpty ||
                  status == KikoeruWritebackStatus.loginRequired ||
                  status == KikoeruWritebackStatus.failed)));

  Future<KikoeruWritebackStatus> check() async {
    try {
      final policy = await send(
        http.Request(
          'GET',
          endpoint.replace(path: '${endpoint.path}/capabilities'),
        ),
        authenticated: false,
      );
      Map? data;
      try {
        final decoded = jsonDecode(policy.body);
        if (decoded is Map) data = decoded;
      } on FormatException {
        /* Older servers may return HTML. */
      }
      if (policy.statusCode == 200 &&
          data?['version'] == 3 &&
          data?['enabled'] is bool &&
          const [
            'none',
            'account',
            'account_and_key',
          ].contains(data?['authentication'])) {
        authentication = data!['authentication'] as String;
        if (data['enabled'] == false) {
          return status = KikoeruWritebackStatus.disabled;
        }
      } else if (const [200, 401, 403, 404].contains(policy.statusCode)) {
        authentication = 'legacy';
      } else {
        return status = KikoeruWritebackStatus.failed;
      }
      final probe = await send(http.Request('HEAD', endpoint));
      if (probe.statusCode == 204 &&
          probe.headers['x-kikoeru-lyrics-writeback'] == '2') {
        return status = KikoeruWritebackStatus.allowed;
      }
      if (probe.statusCode == 204) {
        return status = KikoeruWritebackStatus.unsupported;
      }
      return status = failure(probe);
    } on Exception {
      return status = KikoeruWritebackStatus.networkError;
    }
  }

  KikoeruWritebackStatus failure(http.Response response) {
    String? code;
    try {
      final data = jsonDecode(response.body);
      if (data is Map && data['code'] is String) code = data['code'] as String;
    } on FormatException {
      /* Legacy responses do not carry a reason. */
    }
    // HEAD has no body, so the server also exposes its reason in a header.
    code ??= response.headers['x-kikoeru-writeback-error'];
    if (response.statusCode == 401) return KikoeruWritebackStatus.loginRequired;
    return switch (code) {
      'writeback_disabled' => KikoeruWritebackStatus.disabled,
      'role_forbidden' => KikoeruWritebackStatus.roleForbidden,
      'key_invalid' =>
        credentials().key.isEmpty
            ? KikoeruWritebackStatus.keyRequired
            : KikoeruWritebackStatus.keyInvalid,
      'writeback_unconfigured' => KikoeruWritebackStatus.unconfigured,
      'source_unavailable' => KikoeruWritebackStatus.sourceUnavailable,
      'directory_unwritable' => KikoeruWritebackStatus.directoryUnwritable,
      'lyrics_conflict' => KikoeruWritebackStatus.conflict,
      _ => switch (response.statusCode) {
        403 => KikoeruWritebackStatus.failed,
        404 =>
          authentication == 'legacy'
              ? KikoeruWritebackStatus.unsupported
              : KikoeruWritebackStatus.disabled,
        409 => KikoeruWritebackStatus.conflict,
        _ => KikoeruWritebackStatus.failed,
      },
    };
  }

  Future<http.Response> send(
    http.Request request, {
    bool authenticated = true,
  }) async {
    request.followRedirects = false;
    if (authenticated) request.headers.addAll(credentials().headers);
    final streamed = await _client
        .send(request)
        .timeout(const Duration(seconds: 4));
    return http.Response.fromStream(
      streamed,
    ).timeout(const Duration(seconds: 4));
  }

  void close() => _client.close();
}
