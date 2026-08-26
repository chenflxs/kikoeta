import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../data.dart';

/// Update checker backed by the project update service.
class UpdateService {
  static const _unknownVersion = '0.0.0';
  static const updateApi =
      'http://kikoeta-api.chenflxs.xin/?key=14bj234b2j343u423j4gj34';
  static const githubReleasesApi =
      'https://api.github.com/repos/chenflxs/kikoeta/releases/latest';

  static Timer? _startupTimer;
  static bool _checking = false;
  static String _currentVersion = _unknownVersion;

  static String get currentVersion => _currentVersion;

  /// Reads the version Flutter embedded from app/pubspec.yaml at build time.
  static Future<void> initialize() async {
    try {
      final packageInfo = await PackageInfo.fromPlatform();
      final version = _normalizeVersion(packageInfo.version);
      if (version.isNotEmpty) _currentVersion = version;
    } catch (_) {
      // The update check remains available but will not report a false update.
    }
  }

  static void startAutoCheck(
    AppState app,
    GlobalKey<NavigatorState> navigatorKey,
  ) {
    _startupTimer?.cancel();
    _startupTimer = Timer(const Duration(seconds: 3), () async {
      if (!app.updateCheckEnabled) return;
      final result = await check();
      final update = result.update;
      if (update == null || app.updateIgnoredVersion == update.version) return;
      final context = navigatorKey.currentState?.overlay?.context;
      if (context == null || !context.mounted) return;
      await showUpdateDialog(context, app, update);
    });
  }

  static Future<UpdateCheckResult> check() async {
    if (kIsWeb || _checking || currentVersion == _unknownVersion) {
      return const UpdateCheckResult();
    }
    _checking = true;
    final client = HttpClient()
      ..connectionTimeout = const Duration(seconds: 12);
    try {
      final raw = await _getLatestRelease(client);
      final tag = (raw['tag_name'] as String?)?.trim() ?? '';
      final version = _normalizeVersion(tag);
      final parsedUrl = Uri.tryParse(
        (raw['html_url'] as String?)?.trim() ?? '',
      );
      if (parsedUrl?.isAbsolute != true) {
        return const UpdateCheckResult(error: '更新服务未返回有效版本信息');
      }
      if (version.isEmpty || !isNewerVersion(version, currentVersion)) {
        return const UpdateCheckResult(upToDate: true);
      }
      return UpdateCheckResult(
        update: UpdateInfo(version: version, downloadUrl: parsedUrl!),
      );
    } catch (e) {
      if (e is SocketException) {
        return const UpdateCheckResult(error: '无法连接更新服务或 GitHub');
      }
      return const UpdateCheckResult(error: '更新服务连接失败');
    } finally {
      client.close(force: true);
      _checking = false;
    }
  }

  static Future<HttpClientResponse> _getUpdateResponse(
    HttpClient client,
  ) async {
    for (var attempt = 0; attempt < 3; attempt++) {
      try {
        final request = await client.getUrl(Uri.parse(updateApi));
        return await request.close();
      } on SocketException {
        if (attempt == 2) rethrow;
        await Future<void>.delayed(const Duration(seconds: 1));
      }
    }
    throw StateError('更新服务请求未执行');
  }

  static Future<Map<String, dynamic>> _getLatestRelease(
    HttpClient client,
  ) async {
    try {
      final response = await _getUpdateResponse(client);
      return await _parseReleaseResponse(response);
    } catch (_) {
      final request = await client.getUrl(Uri.parse(githubReleasesApi));
      request.headers.set(
        HttpHeaders.acceptHeader,
        'application/vnd.github+json',
      );
      request.headers.set(
        HttpHeaders.userAgentHeader,
        'Kikoeta Update Checker',
      );
      final response = await request.close();
      return _parseReleaseResponse(response);
    }
  }

  static Future<Map<String, dynamic>> _parseReleaseResponse(
    HttpClientResponse response,
  ) async {
    final body = await utf8.decodeStream(response);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw HttpException('HTTP ${response.statusCode}');
    }
    final raw = jsonDecode(body);
    if (raw is! Map<String, dynamic> ||
        raw['tag_name'] is! String ||
        raw['html_url'] is! String) {
      throw const FormatException('更新响应缺少版本信息');
    }
    return raw;
  }

  static Future<void> checkManually(BuildContext context, AppState app) async {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('正在检查更新…'), duration: Duration(seconds: 1)),
    );
    final result = await check();
    if (!context.mounted) return;
    if (result.update != null) {
      await showUpdateDialog(context, app, result.update!);
    } else if (result.error != null) {
      _toast(context, result.error!);
    } else {
      _toast(context, '当前已是最新版本');
    }
  }

  static Future<void> showUpdateDialog(
    BuildContext context,
    AppState app,
    UpdateInfo update,
  ) async {
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('发现新版本'),
        content: Text('最新版本：${update.version}\n当前版本：$currentVersion'),
        actions: [
          SizedBox(
            width: double.infinity,
            child: Row(
              children: [
                TextButton(
                  onPressed: () {
                    app.setUpdateIgnoredVersion(update.version);
                    Navigator.of(dialogContext).pop();
                  },
                  child: const Text('不再提示'),
                ),
                const Spacer(),
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(),
                  child: const Text('关闭'),
                ),
                const SizedBox(width: 8),
                FilledButton.icon(
                  onPressed: () async {
                    final ok = await launchUrl(
                      update.downloadUrl,
                      mode: LaunchMode.externalApplication,
                    );
                    if (dialogContext.mounted) {
                      Navigator.of(dialogContext).pop();
                    }
                    if (!ok && context.mounted) {
                      _toast(context, '打开下载页面失败');
                    }
                  },
                  icon: const Icon(Icons.download_outlined, size: 17),
                  label: const Text('跳转下载'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  static bool isNewerVersion(String candidate, String current) {
    final a = _versionParts(candidate);
    final b = _versionParts(current);
    for (var i = 0; i < 3; i++) {
      if (a.numbers[i] != b.numbers[i]) {
        return a.numbers[i] > b.numbers[i];
      }
    }
    if (a.prerelease == b.prerelease) return false;
    if (a.prerelease.isEmpty) return true;
    if (b.prerelease.isEmpty) return false;
    return _comparePrerelease(a.prerelease, b.prerelease) > 0;
  }

  static int _comparePrerelease(String a, String b) {
    final left = a.split(RegExp(r'[.-]'));
    final right = b.split(RegExp(r'[.-]'));
    for (var i = 0; i < left.length && i < right.length; i++) {
      final leftNumber = int.tryParse(left[i]);
      final rightNumber = int.tryParse(right[i]);
      if (leftNumber != null && rightNumber != null) {
        if (leftNumber != rightNumber) return leftNumber.compareTo(rightNumber);
      } else if (leftNumber != null) {
        return -1;
      } else if (rightNumber != null) {
        return 1;
      } else if (left[i] != right[i]) {
        return left[i].compareTo(right[i]);
      }
    }
    return left.length.compareTo(right.length);
  }

  static String _normalizeVersion(String value) =>
      value.replaceFirst(RegExp(r'^[vV]'), '').trim();

  static _VersionParts _versionParts(String value) {
    final normalized = _normalizeVersion(value);
    final separator = normalized.indexOf('-');
    final numberPart = separator < 0
        ? normalized
        : normalized.substring(0, separator);
    final prerelease = separator < 0 ? '' : normalized.substring(separator + 1);
    final numbers = numberPart
        .split('.')
        .take(3)
        .map((part) => int.tryParse(part) ?? 0)
        .toList();
    while (numbers.length < 3) {
      numbers.add(0);
    }
    return _VersionParts(numbers, prerelease);
  }

  static void _toast(BuildContext context, String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }
}

class UpdateInfo {
  final String version;
  final Uri downloadUrl;

  const UpdateInfo({required this.version, required this.downloadUrl});
}

class UpdateCheckResult {
  final UpdateInfo? update;
  final bool upToDate;
  final String? error;

  const UpdateCheckResult({this.update, this.upToDate = false, this.error});
}

class _VersionParts {
  final List<int> numbers;
  final String prerelease;

  const _VersionParts(this.numbers, this.prerelease);
}
