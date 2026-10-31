import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:kikoeta_app/services/cloud_sync_service.dart';
import 'package:kikoeta_app/services/portable_backup.dart';
import 'package:kikoeta_app/services/webdav_client.dart';

const config = WebDavConfig(
  url: 'https://example.com/dav/',
  username: 'user',
  password: 'secret',
);

class FakeDav extends WebDavClient {
  WebDavFile? remote;
  int writes = 0;
  int reads = 0;
  int revision = 0;
  bool rejectWrite = false;
  Completer<void>? pause;
  FakeDav() : super(config);
  Future<void> setRemote(PortableBackup backup) async {
    remote = WebDavFile(await backup.encode(), '"${++revision}"');
  }

  @override
  Future<WebDavFile?> read() async {
    reads++;
    if (pause != null) await pause!.future;
    return remote;
  }

  @override
  Future<void> ensureDirectory() async {}
  @override
  Future<void> write(
    List<int> bytes, {
    required String? etag,
    required bool create,
  }) async {
    if (rejectWrite ||
        (create && remote != null) ||
        (!create && etag != remote?.etag)) {
      throw const WebDavException('webdavConflict', 412);
    }
    writes++;
    remote = WebDavFile(
      await PortableBackup.decode(bytes).then((v) => v.encode()),
      '"${++revision}"',
    );
  }
}

class Harness {
  final store = <String, String>{'webdav_enabled': '1'};
  final dav = FakeDav();
  DateTime clock = DateTime.utc(2026, 10, 30);
  int imports = 0;
  late final sync = createService();
  PortableBackup snapshot() => PortableBackup.capture((k) => store[k]);
  CloudSyncService createService() => CloudSyncService(
    readSetting: (k) => store[k],
    writeSetting: (k, v) => store[k] = v,
    makeClient: (_) => dav,
    now: () => clock,
    applyBackup: (b) async {
      imports++;
      store.addAll(b.settings);
    },
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'initial upload, unchanged sync, local update and remote update',
    () async {
      final h = Harness();
      await h.sync.sync();
      expect(h.dav.writes, 1);
      await h.sync.sync();
      expect(h.dav.writes, 1);
      h.store['theme'] = 'dark';
      await h.sync.sync();
      expect(h.dav.writes, 2);
      final other = Map<String, String>.of(h.snapshot().settings)
        ..['theme'] = 'light';
      await h.dav.setRemote(PortableBackup.capture((k) => other[k]));
      await h.sync.sync();
      expect(h.store['theme'], 'light');
      expect(h.imports, 1);
      expect(h.sync.error, isNull);
    },
  );

  test(
    'concurrent changes and first contact require an explicit choice',
    () async {
      final h = Harness();
      await h.sync.sync();
      h.store['theme'] = 'dark';
      await h.dav.setRemote(
        PortableBackup.capture((k) => k == 'theme' ? 'light' : null),
      );
      await h.sync.sync();
      expect(h.sync.hasConflict, isTrue);
      expect(h.imports, 0);
      expect(h.dav.writes, 1);
      await h.sync.sync(resolution: SyncResolution.cloud);
      expect(h.store['theme'], 'light');
      expect(h.sync.error, isNull);
      h.store['webdav_base'] = '';
      h.store['theme'] = 'dark';
      await h.sync.sync();
      expect(h.sync.hasConflict, isTrue);
      await h.sync.sync(resolution: SyncResolution.local);
      expect(
        (await PortableBackup.decode(h.dav.remote!.bytes)).settings['theme'],
        'dark',
      );
    },
  );

  test('hourly cooldown survives restart; manual sync bypasses it', () async {
    final h = Harness();
    await h.sync.syncIfDue();
    expect(h.dav.reads, 1);
    h.clock = h.clock.add(const Duration(minutes: 59));
    final restarted = h.createService();
    await restarted.syncIfDue();
    expect(h.dav.reads, 1);
    await restarted.sync();
    expect(h.dav.reads, 2);
    h.clock = h.clock.add(const Duration(hours: 1));
    await restarted.syncIfDue();
    expect(h.dav.reads, 3);
  });

  test(
    'a deleted cloud file and racing conditional writes never silently overwrite',
    () async {
      final h = Harness();
      await h.sync.sync();
      h.dav.remote = null;
      await h.sync.sync();
      expect(h.sync.hasConflict, isTrue);
      await h.sync.sync(resolution: SyncResolution.local);
      h.store['theme'] = 'dark';
      h.dav.rejectWrite = true;
      await h.sync.sync();
      expect(h.sync.hasConflict, isTrue);
      expect(h.dav.writes, 2);
    },
  );

  test(
    'corrupt cloud data and parallel requests preserve local data',
    () async {
      final h = Harness();
      await h.sync.sync();
      h.dav.pause = Completer<void>();
      final first = h.sync.sync();
      await h.sync.sync();
      expect(h.dav.reads, 2);
      h.dav.pause!.complete();
      await first;
      h.dav.pause = null;
      h.dav.remote = WebDavFile(
        await PortableBackup.capture(
          (k) => k == 'volume' ? 'NaN' : null,
        ).encode(),
        '"bad"',
      );
      await h.sync.sync();
      expect(h.sync.error, 'backupInvalid');
      expect(h.imports, 0);
    },
  );
}
