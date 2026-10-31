import 'dart:async';

import 'package:flutter/widgets.dart';

import 'portable_backup.dart';
import 'webdav_client.dart';

enum SyncResolution { local, cloud, merge }

/// One shared gate for cloud sync and file import; widget lifetime does not
/// control synchronization. Only portable data is read, once per operation.
class CloudSyncService extends ChangeNotifier with WidgetsBindingObserver {
  static const interval = Duration(hours: 1);
  final String? Function(String) readSetting;
  final void Function(String, String) writeSetting;
  final Future<void> Function(PortableBackup) applyBackup;
  final WebDavClient Function(WebDavConfig) makeClient;
  final DateTime Function() now;
  CloudSyncService({
    required this.readSetting,
    required this.writeSetting,
    required this.applyBackup,
    WebDavClient Function(WebDavConfig)? makeClient,
    DateTime Function()? now,
  }) : makeClient = makeClient ?? WebDavClient.new,
       now = now ?? DateTime.now;

  Timer? _timer;
  bool _started = false;
  bool busy = false;
  String? error;
  bool get enabled => readSetting('webdav_enabled') == '1';
  String? get lastSuccess => readSetting('webdav_last_success');
  bool get hasConflict => error == 'webdavConflict';
  WebDavConfig get config => WebDavConfig(
    url: readSetting('webdav_url') ?? '',
    username: readSetting('webdav_username') ?? '',
    password: readSetting('webdav_password') ?? '',
    folder: readSetting('webdav_folder') ?? 'Kikoeta',
  );
  PortableBackup capture() => PortableBackup.capture(readSetting);

  void start() {
    if (_started) return;
    _started = true;
    WidgetsBinding.instance.addObserver(this);
    unawaited(syncIfDue());
    _scheduleNext();
  }

  void _scheduleNext() {
    _timer?.cancel();
    if (!_started || !enabled) return;
    final last = DateTime.tryParse(readSetting('webdav_last_attempt') ?? '');
    final remaining = last == null
        ? Duration.zero
        : interval - now().difference(last);
    _timer = Timer(remaining.isNegative ? Duration.zero : remaining, () async {
      if (busy) {
        _timer = Timer(const Duration(minutes: 1), _scheduleNext);
      } else {
        await syncIfDue();
      }
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) unawaited(syncIfDue());
  }

  Future<void> syncIfDue() async {
    if (!enabled || busy) return;
    final last = DateTime.tryParse(readSetting('webdav_last_attempt') ?? '');
    if (last != null && now().difference(last) < interval) {
      _scheduleNext();
      return;
    }
    await sync();
  }

  void saveConfig(WebDavConfig value, {required bool autoSync}) {
    if (busy) throw StateError('webdavBusy');
    value.directory; // Validate before writing anything.
    final old = config;
    final changed =
        old.url != value.url ||
        old.username != value.username ||
        old.password != value.password ||
        old.folder != value.folder;
    writeSetting('webdav_url', value.url.trim());
    writeSetting('webdav_username', value.username.trim());
    writeSetting('webdav_password', value.password);
    writeSetting('webdav_folder', value.folder);
    writeSetting('webdav_enabled', autoSync ? '1' : '0');
    if (changed) {
      writeSetting('webdav_base', '');
      writeSetting('webdav_last_attempt', '');
      writeSetting('webdav_last_success', '');
      error = null;
    }
    notifyListeners();
    _scheduleNext();
    if (autoSync) unawaited(syncIfDue());
  }

  Future<void> test(WebDavConfig value) async {
    if (busy) throw StateError('webdavBusy');
    busy = true;
    notifyListeners();
    try {
      await makeClient(value).testConnection();
    } finally {
      busy = false;
      _scheduleNext();
      notifyListeners();
    }
  }

  Future<void> importFile(PortableBackup backup) async {
    if (busy) throw StateError('webdavBusy');
    busy = true;
    notifyListeners();
    try {
      await applyBackup(backup);
      error = null;
    } finally {
      busy = false;
      _scheduleNext();
      notifyListeners();
    }
  }

  Future<void> sync({SyncResolution? resolution}) async {
    if (busy) return;
    busy = true;
    error = null;
    notifyListeners();
    try {
      writeSetting('webdav_last_attempt', now().toUtc().toIso8601String());
      final client = makeClient(config);
      final remoteFile = await client.read();
      final remote = remoteFile == null || resolution == SyncResolution.local
          ? null
          : await PortableBackup.decode(remoteFile.bytes);
      final local = capture();
      final base = readSetting('webdav_base');
      String agreed;
      if (resolution == SyncResolution.local) {
        if (remoteFile == null) {
          await client.ensureDirectory();
        }
        await client.write(
          await local.encode(),
          etag: remoteFile?.etag,
          create: remoteFile == null,
        );
        agreed = local.fingerprint;
      } else if (remote?.fingerprint == local.fingerprint) {
        agreed = local.fingerprint;
      } else if (resolution == SyncResolution.cloud) {
        if (remote == null) throw const WebDavException('webdavNoBackup');
        await applyBackup(remote);
        agreed = remote.fingerprint;
      } else if (remote == null) {
        // A previously synchronized file disappearing can be a remote deletion.
        if ((base?.isNotEmpty ?? false) && resolution != SyncResolution.merge) {
          throw const WebDavException('webdavConflict');
        }
        await client.ensureDirectory();
        await client.write(await local.encode(), etag: null, create: true);
        agreed = local.fingerprint;
      } else if (resolution == SyncResolution.merge) {
        final merged = await local.merge(remote);
        final bytes = await merged.encode();
        if (capture().fingerprint != local.fingerprint) {
          throw const WebDavException('webdavConflict');
        }
        if (merged.fingerprint != remote.fingerprint) {
          await client.write(bytes, etag: remoteFile!.etag, create: false);
        }
        if (capture().fingerprint != local.fingerprint) {
          throw const WebDavException('webdavConflict');
        }
        if (merged.fingerprint != local.fingerprint) {
          await applyBackup(merged);
        }
        agreed = merged.fingerprint;
      } else if (base == remote.fingerprint) {
        await client.write(
          await local.encode(),
          etag: remoteFile!.etag,
          create: false,
        );
        agreed = local.fingerprint;
      } else if (base == local.fingerprint) {
        await applyBackup(remote);
        agreed = remote.fingerprint;
      } else {
        throw const WebDavException('webdavConflict');
      }
      writeSetting('webdav_base', agreed);
      writeSetting('webdav_last_success', now().toUtc().toIso8601String());
    } on WebDavException catch (e) {
      error = e.code;
    } on FormatException catch (e) {
      error = e.message == 'backupTooLarge'
          ? 'backupTooLarge'
          : 'backupInvalid';
    } catch (_) {
      // Never expose request headers, endpoints containing secrets, or payloads.
      error = 'webdavRequestFailed';
    } finally {
      busy = false;
      _scheduleNext();
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _started = false;
    _timer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }
}
