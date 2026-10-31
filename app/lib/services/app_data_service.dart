import 'dart:io';

import '../data.dart';
import 'android_audio.dart';
import 'app_paths.dart';
import 'cloud_sync_service.dart';
import 'player_service.dart';
import 'portable_backup.dart';
import 'settings_store.dart';
import 'webdav_client.dart';

late final CloudSyncService cloudSync;

void initializeDataSync(AppState app) {
  cloudSync = CloudSyncService(
    readSetting: SettingsStore.get,
    writeSetting: SettingsStore.set,
    applyBackup: (backup) async {
      final previous = PortableBackup.capture(SettingsStore.get);
      final bytes = await previous.encode();
      final dir = await AppPaths.dataDir();
      final file = File('$dir${Platform.pathSeparator}before-data-import.json');
      final temp = File('${file.path}.tmp');
      await temp.writeAsBytes(bytes, flush: true);
      await temp.rename(file.path);
      // Playback and settings can keep changing while the safety copy is saved.
      if (PortableBackup.capture(SettingsStore.get).fingerprint !=
          previous.fingerprint) {
        throw const WebDavException('webdavConflict');
      }
      SettingsStore.importPortable(backup.settings);
      await app.loadFromRust(restorePlayback: false);
      if (Platform.isAndroid) {
        AndroidAudio.setEarPause(app.earPause);
        AndroidAudio.setIgnoreAudioFocus(app.ignoreAudioFocus);
      }
      await AppPlayer.instance.player.setVolume(app.volume);
      await AppPlayer.instance.applyEqualizer(
        enabled: app.eqOn,
        gains: app.eqGains,
      );
      await AppPlayer.instance.setMediaCacheLimitMb(app.mediaCacheLimitMb);
      app.favVersion++;
      app.notify();
    },
  );
  cloudSync.start();
}
