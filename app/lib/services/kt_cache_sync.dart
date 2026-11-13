import '../data.dart';
import 'api_service.dart';
import 'dlsite_play_service.dart';
import 'kt_service.dart';
import 'kikoeru_lyrics_writeback.dart';
import 'kikoeru_writeback_access.dart';

class KtCacheSyncReport {
  int saved = 0;
  int skipped = 0;
  int failed = 0;
  int written = 0;
  int notWritten = 0;
  bool missingSource = false;
  final failures = <KikoeruWritebackStatus, int>{};
  final errors = <({String jobId, String name, Object error})>[];

  void writebackFailed(KikoeruWritebackStatus status) {
    notWritten++;
    failures.update(status, (count) => count + 1, ifAbsent: () => 1);
  }
}

/// Shares the normal writeback protocol, but resolves current media metadata
/// before using a cached path. Cache data never selects an unconfigured site.
class KtCacheSync {
  final Future<String> Function(String url) download;
  final Future<void> Function(String workId, String path, String content) save;
  final Future<List<MediaNode>> Function(String base, int id) loadTracks;
  final KikoeruWritebackCredentials Function(String base) credentials;
  final Map<String, String> _configuredBases;
  final String? legacySourceBase;

  KtCacheSync({
    required this.download,
    required this.save,
    required this.loadTracks,
    required this.credentials,
    required Iterable<String> configuredBases,
    this.legacySourceBase,
  }) : _configuredBases = _bindSites(configuredBases);

  static Map<String, String> _bindSites(Iterable<String> sites) {
    final bindings = <String, String>{};
    for (final site in sites) {
      final normalized = KikoeruWritebackAccess.normalizeBase(site);
      if (normalized != null) {
        bindings.putIfAbsent(
          normalized,
          () => site.trim().replaceFirst(RegExp(r'/+$'), ''),
        );
      }
    }
    return bindings;
  }

  Future<KtCacheSyncReport> run(List<KtCachedResult> entries) async {
    final report = KtCacheSyncReport();
    final localTargets = <String>{};
    final remoteTargets = <String>{};
    final writers = <String, KikoeruLyricsWriteback>{};
    final metadata = <String, Future<Map<String, List<MediaNode>>>>{};
    try {
      for (final entry in entries) {
        final work = entry.workId.trim().toUpperCase();
        final origin = entry.sourceBase?.trim();
        final source = KikoeruWritebackAccess.normalizeBase(
          origin == null || origin.isEmpty ? legacySourceBase : origin,
        );
        // Keep the configured spelling for token lookup and media-cache keys.
        final dlsite = source == DlsitePlaySession.origin;
        final base = dlsite ? null : _configuredBases[source];
        if (origin?.isNotEmpty == true && base == null && !dlsite) {
          report.missingSource = true;
        }
        for (final file in entry.files) {
          if (file.trackPath.isEmpty || file.downloadUrl.isEmpty) {
            report.skipped++;
            continue;
          }
          final path = ktLyricsRelativePath(work, file.trackPath);
          final local = localTargets.add('$work\u0000$path');
          if (!local) report.skipped++;
          final remote =
              base != null &&
              remoteTargets.add(
                '$base\u0000$work\u0000${file.trackPath.replaceAll('\\', '/')}',
              );
          if (!local && !remote) continue;
          var localSaved = !local;
          try {
            final content = await download(file.downloadUrl);
            if (ApiService.parseLyrics(content).isEmpty) {
              throw const FormatException('Invalid cached lyrics');
            }
            if (local) {
              await save(work, path, content);
              report.saved++;
              localSaved = true;
            }
            if (!remote) {
              if (local && !dlsite) report.notWritten++;
              continue;
            }
            final writer = writers.putIfAbsent(
              base,
              () => KikoeruLyricsWriteback.connect(
                base,
                const {},
                key: '',
                credentials: () => credentials(base),
              )!,
            );
            if (await writer.check() != true) {
              report.writebackFailed(writer.status);
              continue;
            }
            final id = RegExp(r'^RJ[0-9]+$').hasMatch(work)
                ? ApiService.apiIdFromRj(work)
                : null;
            if (id == null || id <= 0) {
              report.writebackFailed(KikoeruWritebackStatus.sourceUnavailable);
              continue;
            }
            final index = await metadata.putIfAbsent(
              '$base|$id',
              () => loadTracks(base, id).then(_indexTracks),
            );
            final matches =
                index[file.trackPath.replaceAll('\\', '/')] ?? const [];
            if (matches.length != 1) {
              report.writebackFailed(KikoeruWritebackStatus.sourceUnavailable);
              continue;
            }
            final track = matches.single;
            final result = await writer.write(
              workId: id,
              mediaUrl: track.downloadUrl ?? track.url,
              trackPath: track.path,
              content: content,
            );
            if (result == true) {
              report.written++;
              ApiService.invalidateTracks(base, id);
            } else {
              report.writebackFailed(
                result == null &&
                        writer.status == KikoeruWritebackStatus.allowed
                    ? KikoeruWritebackStatus.sourceUnavailable
                    : writer.status,
              );
            }
          } catch (error) {
            // A failed upload must not turn a successfully saved local lyric
            // into a local-import failure.
            if (!localSaved) {
              report.failed++;
              report.errors.add((
                jobId: entry.jobId,
                name: file.name,
                error: error,
              ));
            } else {
              report.writebackFailed(KikoeruWritebackStatus.failed);
            }
          }
        }
      }
      return report;
    } finally {
      for (final writer in writers.values) {
        writer.close();
      }
    }
  }

  static Map<String, List<MediaNode>> _indexTracks(List<MediaNode> nodes) {
    final index = <String, List<MediaNode>>{};
    final pending = [...nodes];
    while (pending.isNotEmpty) {
      final node = pending.removeLast();
      if (node.isDir) {
        pending.addAll(node.children);
      } else {
        index.putIfAbsent(node.path.replaceAll('\\', '/'), () => []).add(node);
      }
    }
    return index;
  }
}
