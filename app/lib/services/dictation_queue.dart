import 'dart:collection';

import 'package:flutter/foundation.dart';

import '../data.dart';
import '../l10n/strings.dart';
import 'kt_service.dart';

enum DictationQueueStatus { pending, running, completed, failed, cancelled }

class DictationQueueEntry {
  final Work work;
  final List<MediaNode> tracks;
  final bool automaticallyMatched;
  final String label;
  final String? sourceBase;
  final int? sourceLoginEpoch;
  final String lyricsWritebackKey;
  final Map<String, String> sourceHeaders;
  KtJobReference? backendJob;
  final Set<String> pendingWritebackPaths = {};
  bool retryingWriteback = false;
  DictationQueueStatus _status = DictationQueueStatus.pending;

  DictationQueueEntry._({
    required this.work,
    required List<MediaNode> tracks,
    required this.automaticallyMatched,
    required this.label,
    required this.sourceBase,
    required this.sourceLoginEpoch,
    required this.lyricsWritebackKey,
    required Map<String, String> sourceHeaders,
  }) : tracks = List.unmodifiable(tracks),
       sourceHeaders = Map.unmodifiable(sourceHeaders);

  DictationQueueStatus get status => _status;
}

/// Display order is newest first; execution takes the last pending entry.
/// Owned by the app session so navigating away does not stop the queue.
class DictationQueue extends ChangeNotifier {
  static final Expando<DictationQueue> _sessions = Expando();

  static DictationQueue forApp(AppState app) =>
      _sessions[app] ??= DictationQueue();

  final List<DictationQueueEntry> _entries = [];
  final Map<String, int> _nextBatch = {};
  int pendingRevision = 0;
  late final entries = UnmodifiableListView(_entries);
  DictationQueueEntry? current;
  final List<String> logs = [];
  bool running = false;
  bool cancelling = false;
  bool stopRequested = false;
  bool deleteOnFinish = false;
  bool preemptRequested = false;
  bool preempting = false;
  int runRevision = 0;
  String stage = appL10n.dictationTranslationPageInitStateText;
  String? jobId;
  KtService? activeService;
  int finishedFiles = 0;
  double stageFraction = 0;
  int savedFiles = 0;

  bool get hasPending =>
      _entries.any((e) => e.status == DictationQueueStatus.pending);
  bool get canStart =>
      hasPending ||
      _entries.any((e) => e.status == DictationQueueStatus.cancelled);
  List<MediaNode> get tracks => current?.tracks ?? const [];

  /// Restartable cancelled batches also reserve tracks; completed work can be
  /// translated again. Use source paths, not expiring URLs or matched titles.
  DictationQueueEntry? enqueue({
    required Work work,
    required List<MediaNode> tracks,
    bool automaticallyMatched = false,
    String? sourceBase,
    int? sourceLoginEpoch,
    String lyricsWritebackKey = '',
    Map<String, String> sourceHeaders = const {},
  }) {
    final id = work.rj.toUpperCase();
    final reservedPaths = <String>{
      for (final entry in _entries)
        if (entry.work.rj.toUpperCase() == id &&
            entry.sourceLoginEpoch == sourceLoginEpoch &&
            (entry.status == DictationQueueStatus.pending ||
                entry.status == DictationQueueStatus.running ||
                entry.status == DictationQueueStatus.cancelled))
          for (final track in entry.tracks) track.path,
    };
    final addedTracks = tracks
        .where((track) => reservedPaths.add(track.path))
        .toList();
    if (addedTracks.isEmpty) return null;
    final batch = _nextBatch[id] ?? 0;
    _nextBatch[id] = batch + 1;
    final entry = DictationQueueEntry._(
      work: work,
      tracks: addedTracks,
      automaticallyMatched: automaticallyMatched,
      label: batch == 0 ? work.rj : '${work.rj}-$batch',
      sourceBase: sourceBase,
      sourceLoginEpoch: sourceLoginEpoch,
      lyricsWritebackKey: lyricsWritebackKey,
      sourceHeaders: sourceHeaders,
    );
    _entries.insert(0, entry);
    pendingRevision++;
    notifyListeners();
    return entry;
  }

  /// Both identities must still be pending when a drag finishes. A job may
  /// have started, or another page may have imported a batch during the drag.
  void reorder(DictationQueueEntry entry, DictationQueueEntry target) {
    if (entry.status != DictationQueueStatus.pending ||
        target.status != DictationQueueStatus.pending ||
        !_entries.contains(entry) ||
        !_entries.contains(target)) {
      return;
    }
    final targetIndex = _entries.indexOf(target);
    _entries.remove(entry);
    _entries.insert(targetIndex, entry);
    pendingRevision++;
    notifyListeners();
  }

  bool canJump(DictationQueueEntry entry) =>
      entry.status == DictationQueueStatus.pending &&
      _entries.contains(entry) &&
      !cancelling;

  /// The last pending entry executes next. The processor returns the current
  /// batch to pending only after the backend confirms it has paused.
  bool jumpAhead(DictationQueueEntry entry) {
    if (!canJump(entry)) return false;
    _entries.remove(entry);
    _entries.add(entry);
    if (current?.status == DictationQueueStatus.running) {
      preemptRequested = true;
    }
    pendingRevision++;
    notifyListeners();
    return true;
  }

  bool retry(DictationQueueEntry entry) {
    if (entry.status != DictationQueueStatus.failed ||
        !_entries.contains(entry) ||
        cancelling) {
      return false;
    }
    entry._status = DictationQueueStatus.pending;
    _entries.remove(entry);
    _entries.add(entry);
    pendingRevision++;
    notifyListeners();
    return true;
  }

  /// Explicit Start restarts cancelled batches in their original queue order.
  /// Use the current connection and a fresh KT job, not the cancelled job's
  /// server or checkpoint. Failed retries retain their recovery reference.
  void restartCancelled() {
    if (running || cancelling) return;
    var changed = false;
    for (final entry in _entries) {
      if (entry.status != DictationQueueStatus.cancelled) continue;
      entry._status = DictationQueueStatus.pending;
      entry.backendJob = null;
      changed = true;
    }
    if (changed) {
      pendingRevision++;
      notifyListeners();
    }
  }

  bool remove(DictationQueueEntry entry) {
    if (entry.status == DictationQueueStatus.running) return false;
    if (!_entries.remove(entry)) return false;
    if (entry.status == DictationQueueStatus.pending) pendingRevision++;
    if (identical(current, entry)) current = null;
    notifyListeners();
    return true;
  }

  /// Keep the active entry visible until its cancellation has finished.
  void clear() {
    final hadPending = hasPending;
    _entries.removeWhere(
      (entry) => entry.status != DictationQueueStatus.running,
    );
    if (hadPending) pendingRevision++;
    if (current?.status != DictationQueueStatus.running) current = null;
    notifyListeners();
  }

  void expireDlsiteEntries(int epoch) {
    bool expired(DictationQueueEntry entry) => entry.sourceLoginEpoch == epoch;
    if (current case final entry?
        when expired(entry) && entry.status == DictationQueueStatus.running) {
      deleteOnFinish = true;
    }
    final before = _entries.length;
    _entries.removeWhere(
      (entry) => expired(entry) && entry.status != DictationQueueStatus.running,
    );
    if (before == _entries.length) return;
    if (current case final entry? when !_entries.contains(entry)) {
      current = null;
    }
    pendingRevision++;
    notifyListeners();
  }

  Future<void> run(
    Future<DictationQueueStatus> Function(DictationQueueEntry) process,
  ) async {
    if (running || !hasPending) return;
    running = true;
    stopRequested = false;
    logs.clear();
    try {
      while (!stopRequested && hasPending) {
        final entry = _entries.lastWhere(
          (e) => e.status == DictationQueueStatus.pending,
        );
        current = entry;
        runRevision++;
        entry._status = DictationQueueStatus.running;
        pendingRevision++;
        jobId = null;
        cancelling = false;
        deleteOnFinish = false;
        preemptRequested = false;
        preempting = false;
        finishedFiles = 0;
        stageFraction = 0;
        savedFiles = 0;
        stage = appL10n.dictationTranslationPageStartUpdate6;
        notifyListeners();
        try {
          entry._status = await process(entry);
        } catch (_) {
          entry._status = DictationQueueStatus.failed;
          rethrow;
        } finally {
          if (deleteOnFinish) remove(entry);
        }
        if (entry.status == DictationQueueStatus.cancelled) {
          stopRequested = true;
        }
        notifyListeners();
      }
    } finally {
      running = false;
      cancelling = false;
      preemptRequested = false;
      preempting = false;
      jobId = null;
      notifyListeners();
    }
  }

  void update(void Function() change) {
    change();
    notifyListeners();
  }

  void appendLog(String message) {
    if (message.trim().isEmpty) return;
    logs.add(message.trim());
    if (logs.length > 500) logs.removeRange(0, logs.length - 500);
    notifyListeners();
  }
}
