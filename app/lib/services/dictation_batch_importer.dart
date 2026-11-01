import '../data.dart';
import 'api_service.dart';
import 'dictation_media_matcher.dart';
import 'media_tree.dart';

class DictationBatch {
  final Work work;
  final List<MediaNode> tracks;
  final Set<String> existingLyricPaths;
  const DictationBatch(
    this.work,
    this.tracks, {
    this.existingLyricPaths = const {},
  });
}

class DictationBatchImportResult {
  final batches = <DictationBatch>[];
  int skippedTracks = 0;
  final failedWorks = <String>[];

  int get existingTracks => batches.fold(
    0,
    (count, batch) => count + batch.existingLyricPaths.length,
  );

  DictationBatchImportResult resolveExistingLyrics({
    required bool retranslate,
  }) {
    final result = DictationBatchImportResult()
      ..failedWorks.addAll(failedWorks);
    for (final batch in batches) {
      final tracks = retranslate
          ? batch.tracks
          : batch.tracks
                .where(
                  (track) => !batch.existingLyricPaths.contains(track.path),
                )
                .toList();
      result.skippedTracks += batch.tracks.length - tracks.length;
      if (tracks.isNotEmpty) {
        result.batches.add(DictationBatch(batch.work, tracks));
      }
    }
    return result;
  }
}

/// Serial metadata preparation; the caller commits batches only after success.
/// Cancelling (including a source change) discards the uncommitted result.
class DictationBatchImporter {
  final Future<WorksPage> Function(int page) fetchPage;
  final Future<List<MediaNode>> Function(Work work) fetchTracks;
  final Future<List<MediaNode>> Function(Work work) fetchLocalLyrics;

  const DictationBatchImporter({
    required this.fetchPage,
    required this.fetchTracks,
    required this.fetchLocalLyrics,
  });

  Future<DictationBatchImportResult?> prepare({
    required bool Function() shouldCancel,
    required void Function(int processed, int total, String workId) onProgress,
  }) async {
    final result = DictationBatchImportResult();
    final seen = <String>{};
    var processed = 0;
    for (var page = 1; ; page++) {
      if (shouldCancel()) return null;
      final worksPage = await fetchPage(page);
      if (shouldCancel()) return null;
      var newWorks = 0;
      for (final work in worksPage.works) {
        if (!seen.add(work.rj.toUpperCase())) continue;
        newWorks++;
        onProgress(processed, worksPage.totalCount, work.rj);
        try {
          final tree = await fetchTracks(work);
          if (shouldCancel()) return null;
          final tracks = await DictationMediaMatcher.selectForDictation(
            MediaTreeIndex(tree),
          );
          if (shouldCancel()) return null;
          final localLyrics = await fetchLocalLyrics(work);
          if (shouldCancel()) return null;
          final existing = ApiService.tracksWithLyrics([
            ...tree,
            ...localLyrics,
          ], tracks);
          if (tracks.isNotEmpty) {
            result.batches.add(
              DictationBatch(work, tracks, existingLyricPaths: existing),
            );
          }
        } catch (_) {
          if (shouldCancel()) return null;
          result.failedWorks.add(work.rj);
        }
        processed++;
        onProgress(processed, worksPage.totalCount, work.rj);
      }
      if (!worksPage.hasMore) return result;
      // A backend ignoring pagination must not silently truncate the import
      // or loop forever. A page failure leaves the queue untouched.
      if (newWorks == 0) throw StateError('Pagination made no progress');
    }
  }
}
