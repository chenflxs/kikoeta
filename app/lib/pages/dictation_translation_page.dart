import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../data.dart';
import '../services/api_service.dart';
import '../services/kikoeru_lyrics_writeback.dart';
import '../services/kikoeru_writeback_access.dart';
import '../services/kikoeru_writeback_site.dart';
import '../l10n/writeback_strings.dart';
import '../services/kt_service.dart';
import '../services/kt_cache_sync.dart';
import '../services/dictation_queue.dart';
import '../widgets/dictation_queue_list.dart';
import '../l10n/generated/app_localizations.dart';
import '../services/lyrics_library_service.dart';
import '../services/settings_store.dart';
import '../smooth_scroll.dart';
import '../theme.dart';
import '../l10n/strings.dart';

class DictationTranslationPage extends StatefulWidget {
  final AppState app;
  final Work? work;
  final List<MediaNode> tracks;
  final bool automaticallyMatched;

  const DictationTranslationPage({
    super.key,
    required this.app,
    this.work,
    this.tracks = const [],
    this.automaticallyMatched = false,
  });

  @override
  State<DictationTranslationPage> createState() =>
      _DictationTranslationPageState();
}

class _DictationTranslationPageState extends State<DictationTranslationPage> {
  static const _localEndpoint = '127.0.0.1:2370';
  late final TextEditingController _networkController;
  late final TextEditingController _usernameController;
  late final TextEditingController _passwordController;
  late bool _useLocal;
  late final DictationQueue _session;
  bool _testing = false;
  bool _obscurePassword = true;
  bool _syncing = false;

  AppState get app => widget.app;
  Palette get p => Theme.of(context).brightness == Brightness.dark
      ? AppColors.dark
      : AppColors.light;

  @override
  void initState() {
    super.initState();
    _session = DictationQueue.forApp(widget.app);
    if (widget.work != null && widget.tracks.isNotEmpty) {
      final base = ApiService.resolveBase(app);
      final token = ApiService.tokenFor(app, base);
      final site = app.customServer && app.customSites.isNotEmpty
          ? app.customSites[app.customServerIdx]
          : null;
      _session.enqueue(
        work: widget.work!,
        tracks: widget.tracks,
        automaticallyMatched: widget.automaticallyMatched,
        sourceBase: site?.url,
        lyricsWritebackKey: site?.lyricsWritebackKey ?? '',
        sourceHeaders: token == null || token.isEmpty
            ? const {}
            : {'Authorization': 'Bearer $token'},
      );
    }
    _session.addListener(_onSessionChanged);
    _useLocal =
        !Platform.isAndroid &&
        SettingsStore.get('kt_connection_mode') != 'network';
    _networkController = TextEditingController(
      text: SettingsStore.get('kt_network_endpoint') ?? '',
    );
    _usernameController = TextEditingController(
      text: SettingsStore.get('kt_username') ?? KtService.defaultUsername,
    );
    _passwordController = TextEditingController(
      text: SettingsStore.get('kt_password') ?? KtService.defaultPassword,
    );
  }

  @override
  void dispose() {
    _session.removeListener(_onSessionChanged);
    _networkController.dispose();
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _onSessionChanged() {
    if (mounted) setState(() {});
  }

  List<MediaNode> get _tracks => _session.tracks;
  String get _endpoint => _useLocal ? _localEndpoint : _networkController.text;
  double get _progress {
    if (_tracks.isEmpty) return 0;
    return ((_session.finishedFiles + _session.stageFraction) / _tracks.length)
        .clamp(0.0, 1.0);
  }

  void _persistConnection() {
    SettingsStore.set('kt_connection_mode', _useLocal ? 'local' : 'network');
    SettingsStore.set('kt_network_endpoint', _networkController.text.trim());
    SettingsStore.set('kt_username', _usernameController.text.trim());
    SettingsStore.set('kt_password', _passwordController.text);
  }

  KtService _service() {
    final username = _usernameController.text.trim();
    final password = _passwordController.text;
    if (username.isEmpty || password.isEmpty) {
      throw FormatException(
        context.l10n.dictationTranslationPageServiceFormatException2,
      );
    }
    if (username.contains(':')) {
      throw FormatException(
        context.l10n.dictationTranslationPageServiceFormatException,
      );
    }
    return KtService(_endpoint, username: username, password: password);
  }

  Future<void> _testConnection() async {
    final l10n = context.l10n;
    if (_testing) return;
    setState(() => _testing = true);
    KtService? service;
    try {
      service = _service();
      final result = await service.health();
      if (result['ok'] != true) {
        throw FormatException(
          l10n.dictationTranslationPageTestConnectionFormatException,
        );
      }
      _persistConnection();
      _toast(l10n.dictationTranslationPageTestConnectionToast);
    } catch (error) {
      _toast(
        l10n.dictationTranslationPageTestConnectionToast2((error).toString()),
      );
    } finally {
      service?.close();
      if (mounted) setState(() => _testing = false);
    }
  }

  Future<void> _openKikoetaTranslDownload() async {
    final l10n = context.l10n;
    final opened = await launchUrl(
      Uri.parse('https://github.com/chenflxs/kikoeta-transl'),
      mode: LaunchMode.externalApplication,
    );
    if (!opened) {
      _toast(l10n.dictationTranslationPageOpenKikoetaTranslDownloadToast);
    }
  }

  Future<void> _start({bool restartCancelled = true}) async {
    final l10n = context.l10n;
    if (_session.running ||
        !(restartCancelled ? _session.canStart : _session.hasPending)) {
      return;
    }
    KtService? service;
    try {
      final connection = _service();
      service = connection;
      _session.activeService = connection;
      _persistConnection();
      if (restartCancelled) _session.restartCancelled();
      await _session.run((entry) => _processEntry(connection, entry, l10n));
    } catch (error) {
      _appendLog(l10n.dictationTranslationPageStartAppendLog(error.toString()));
      _toast(l10n.dictationTranslationPageStartToast(error.toString()));
    } finally {
      service?.close();
      _session.activeService = null;
    }
  }

  // Connection and strings are captured before navigation can dispose this page.
  Future<DictationQueueStatus> _processEntry(
    KtService connection,
    DictationQueueEntry entry,
    AppLocalizations l10n,
  ) async {
    final currentWork = entry.work;
    final tracks = entry.tracks;
    final pausedJob = entry.backendJob;
    final service = pausedJob?.connect() ?? connection;
    _session.activeService = service;
    var submissionAttempted = false;
    var terminalObserved = false;
    _appendLog(l10n.dictationQueueProcessing(entry.label));
    try {
      if (tracks.isEmpty) {
        throw FormatException(l10n.dictationTranslationPageStartToast3);
      }
      final missing = tracks.where((track) {
        final url = track.downloadUrl ?? track.url;
        return url == null || url.isEmpty;
      }).length;
      if (missing > 0) {
        throw FormatException(
          l10n.dictationTranslationPageStartToast4(missing.toString()),
        );
      }
      await service.health();
      if (_session.stopRequested) return DictationQueueStatus.cancelled;
      if (_session.preemptRequested) return DictationQueueStatus.pending;
      final sources = <KtSourceFile>[];
      for (var i = 0; i < tracks.length; i++) {
        final track = tracks[i];
        sources.add(
          KtSourceFile(
            url: track.downloadUrl ?? track.url!,
            name: ktUploadName(i, track.title),
            headers: entry.sourceHeaders,
          ),
        );
      }
      submissionAttempted = true;
      final created = await service.startOrRecoverJob(
        sources,
        existingJobId: pausedJob?.jobId,
        cacheWorkId: currentWork.rj,
        cacheSourceBase: entry.sourceBase,
        cacheTrackPaths: tracks.map((track) => track.path).toList(),
      );
      final jobId = created['job_id']?.toString() ?? '';
      if (jobId.isEmpty) {
        throw FormatException(
          l10n.dictationTranslationPageStartFormatException,
        );
      }
      _session.jobId = jobId;
      entry.backendJob = service.reference(jobId);
      if (_session.stopRequested) {
        await _cancelSubmittedJob(service, jobId, l10n);
      } else if (_session.preemptRequested) {
        await _preemptSubmittedJob(service, jobId, l10n);
      }
      _appendLog(
        l10n.dictationTranslationPageStartAppendLog2(
          (jobId).toString(),
          (tracks.length).toString(),
        ),
      );
      _session.update(
        () => _session.stage = l10n.dictationTranslationPageStartUpdate2,
      );

      var cursor = (created['event_cursor'] as num?)?.toInt() ?? 0;
      _session.update(() {
        _session.finishedFiles =
            (created['completed_files'] as num?)?.toInt() ?? 0;
      });
      var closed = false;
      while (!closed) {
        final batch = await service.events(jobId, cursor);
        cursor = batch.cursor;
        closed = batch.closed;
        for (final event in batch.events) {
          _applyEvent(event);
          if (event['type'] == 'job_done') closed = true;
        }
      }

      final job = await service.job(jobId);
      final status = job['status']?.toString() ?? 'failed';
      if (status == 'completed' ||
          status == 'failed' ||
          status == 'cancelled' ||
          status == 'paused') {
        terminalObserved = true;
        _session.update(() {
          _session.stage = l10n.dictationTranslationPageStartUpdate5;
          if (status == 'completed') {
            _session.finishedFiles = tracks.length;
          } else {
            _session.finishedFiles =
                (job['completed_files'] as num?)?.toInt() ??
                _session.finishedFiles;
          }
          _session.stageFraction = 0;
        });
        try {
          _session.savedFiles = await _saveOutputs(service, job, entry, l10n);
        } catch (error) {
          // The backend checkpoint remains resumable even if writing an
          // already finished lyric to the local library fails.
          if (status != 'paused') rethrow;
          _appendLog(
            l10n.dictationTranslationPageStartAppendLog(error.toString()),
          );
          _toast(l10n.dictationTranslationPageStartToast(error.toString()));
        }
        if (_session.savedFiles > 0) {
          _appendLog(
            l10n.dictationTranslationPageStartAppendLog3(
              (currentWork.rj).toString(),
              (_session.savedFiles).toString(),
            ),
          );
        }
      }
      if (status == 'completed') {
        if (_session.savedFiles == 0) {
          throw FormatException(
            l10n.dictationTranslationPageStartFormatException2,
          );
        }
        _session.update(
          () => _session.stage = l10n.dictationTranslationPageStartUpdate4,
        );
        return DictationQueueStatus.completed;
      } else if (status == 'paused') {
        _session.update(() => _session.stage = l10n.dictationQueuePending);
        return DictationQueueStatus.pending;
      } else if (status == 'cancelled') {
        _session.update(
          () => _session.stage = l10n.dictationTranslationPageStartUpdate3,
        );
        return DictationQueueStatus.cancelled;
      } else {
        throw Exception(
          job['error']?.toString().trim().isNotEmpty == true
              ? job['error'].toString()
              : l10n.dictationTranslationPageStartException,
        );
      }
    } catch (error) {
      // A polling/submission error does not prove the backend stopped. Pause
      // rather than submit another work while the first job may still run.
      if (submissionAttempted && !terminalObserved) {
        _session.stopRequested = true;
      }
      _appendLog(l10n.dictationTranslationPageStartAppendLog(error.toString()));
      _session.update(
        () => _session.stage = l10n.dictationTranslationPageStartUpdate,
      );
      _toast(l10n.dictationTranslationPageStartToast(error.toString()));
      return DictationQueueStatus.failed;
    } finally {
      if (!identical(service, connection)) service.close();
    }
  }

  Future<int> _saveOutputs(
    KtService service,
    Map<String, dynamic> job,
    DictationQueueEntry entry,
    AppLocalizations l10n,
  ) async {
    final rawResults = job['results'];
    if (rawResults is! List) return 0;
    final files = job['files'];
    final tracks = entry.tracks;
    final work = entry.work;
    final workId = work.apiId;
    final sourceBase = entry.sourceBase;
    final writeback = job['status'] == 'completed' && workId != null
        ? KikoeruLyricsWriteback.connect(
            sourceBase,
            entry.sourceHeaders,
            key: entry.lyricsWritebackKey,
            credentials: sourceBase == null
                ? null
                : () => writebackCredentialsFor(widget.app, sourceBase),
          )
        : null;
    var saved = 0;
    var wroteToSource = false;
    final sourceFailures = <KikoeruWritebackStatus>{};
    try {
      for (
        var index = 0;
        index < rawResults.length && index < tracks.length;
        index++
      ) {
        final raw = rawResults[index];
        if (raw is! Map || raw['status'] != 'done') continue;
        final trackIndex =
            (raw['file_index'] as num?)?.toInt() ??
            (files is List ? files.indexOf(raw['path']) : index);
        if (trackIndex < 0 || trackIndex >= tracks.length) continue;
        final urls = raw['download_urls'];
        if (urls is! List || urls.isEmpty) continue;
        String? lrcUrl;
        final outputs = raw['outputs'];
        if (outputs is List) {
          for (var i = 0; i < outputs.length && i < urls.length; i++) {
            if (outputs[i].toString().toLowerCase().endsWith('.lrc')) {
              lrcUrl = urls[i].toString();
              break;
            }
          }
        }
        final bytes = await service.download(lrcUrl ?? urls.first.toString());
        final content = utf8.decode(bytes, allowMalformed: true);
        final track = tracks[trackIndex];
        await LyricsLibraryService.instance.saveTranslatedLyrics(
          workId: work.rj,
          relativePath: ktLyricsRelativePath(work.rj, track.path),
          content: content,
        );
        saved++;
        if (writeback != null && workId != null && lrcUrl != null) {
          final written = await writeback.write(
            workId: workId,
            mediaUrl: track.downloadUrl ?? track.url,
            trackPath: track.path,
            content: content,
          );
          if (written == true) {
            wroteToSource = true;
            entry.pendingWritebackPaths.remove(track.path);
          }
          if (written == false) {
            entry.pendingWritebackPaths.add(track.path);
            sourceFailures.add(writeback.status);
          }
        }
      }
      return saved;
    } finally {
      writeback?.close();
      if (wroteToSource && sourceBase != null && workId != null) {
        ApiService.invalidateTracks(sourceBase, workId);
      }
      if (sourceFailures.isNotEmpty) {
        _appendLog(
          '${l10n.dictationSourceWritebackFailed} ${sourceFailures.map((status) => status.label(l10n)).join(' / ')}',
        );
      }
    }
  }

  void _applyEvent(Map<String, dynamic> event) {
    final type = event['type']?.toString() ?? '';
    final message = event['message']?.toString() ?? '';
    if (message.isNotEmpty) _appendLog(message);
    _session.update(() {
      if (type == 'status') {
        final stage = event['stage']?.toString() ?? '';
        _session.stage = message.isEmpty ? stage : message;
        _session.stageFraction = switch (stage) {
          'running' => 0.02,
          'transcoding' => 0.12,
          'asr' => 0.38,
          'correcting' => 0.62,
          'translating' => 0.74,
          'exporting' => 0.92,
          _ => _session.stageFraction,
        };
      } else if (type == 'file_done' || type == 'file_error') {
        _session.finishedFiles = (_session.finishedFiles + 1).clamp(
          0,
          _session.tracks.length,
        );
        _session.stageFraction = 0;
      }
    });
  }

  void _appendLog(String message) {
    _session.appendLog(message);
  }

  Future<void> _retryEntry(DictationQueueEntry entry) async {
    if (_syncing || !_session.retry(entry)) return;
    if (!_session.running) await _start(restartCancelled: false);
  }

  Future<void> _retryWriteback(DictationQueueEntry entry) async {
    final base = entry.sourceBase;
    final id = entry.work.apiId;
    if (base == null || id == null || entry.retryingWriteback) return;
    final writer = KikoeruLyricsWriteback.connect(
      base,
      const {},
      key: '',
      credentials: () => writebackCredentialsFor(widget.app, base),
    );
    if (writer == null) return;
    final l10n = context.l10n;
    _session.update(() => entry.retryingWriteback = true);
    final failures = <KikoeruWritebackStatus>{};
    var wrote = false;
    try {
      for (final track
          in entry.tracks
              .where(
                (track) => entry.pendingWritebackPaths.contains(track.path),
              )
              .toList()) {
        final local = await LyricsLibraryService.instance.readForTranslation(
          workId: entry.work.rj,
          relativePath: ktLyricsRelativePath(entry.work.rj, track.path),
        );
        if (local == null) {
          failures.add(KikoeruWritebackStatus.sourceUnavailable);
          continue;
        }
        final result = await writer.write(
          workId: id,
          mediaUrl: track.downloadUrl ?? track.url,
          trackPath: track.path,
          content: local.sourceText,
        );
        if (result == true) {
          entry.pendingWritebackPaths.remove(track.path);
          wrote = true;
        } else {
          failures.add(writer.status);
        }
      }
    } catch (_) {
      failures.add(KikoeruWritebackStatus.failed);
    } finally {
      writer.close();
      if (wrote) ApiService.invalidateTracks(base, id);
      _session.update(() => entry.retryingWriteback = false);
      for (final failure in failures) {
        _appendLog(failure.label(l10n));
      }
    }
  }

  Future<void> _jumpEntry(DictationQueueEntry entry) async {
    final l10n = context.l10n;
    if (!_session.jumpAhead(entry)) return;
    final service = _session.activeService;
    final jobId = _session.jobId;
    if (service != null && jobId != null) {
      await _preemptSubmittedJob(service, jobId, l10n);
    }
  }

  Future<void> _preemptSubmittedJob(
    KtService service,
    String jobId,
    AppLocalizations l10n,
  ) async {
    if (_session.jobId != jobId ||
        !_session.preemptRequested ||
        _session.preempting ||
        _session.stopRequested) {
      return;
    }
    final revision = _session.runRevision;
    _session.update(() => _session.preempting = true);
    try {
      await service.preempt(jobId);
    } catch (error) {
      if (_session.jobId != jobId || _session.runRevision != revision) return;
      _session.update(() {
        _session.preemptRequested = false;
        _session.preempting = false;
      });
      _toast(l10n.dictationTranslationPageStartToast(error.toString()));
    }
  }

  Future<void> _deleteEntry(DictationQueueEntry entry) async {
    if (entry.status == DictationQueueStatus.running) {
      await _cancel(deleteOnFinish: true);
    } else {
      _session.remove(entry);
    }
  }

  Future<void> _clearQueue() async {
    final current = _session.current;
    _session.clear();
    if (current?.status == DictationQueueStatus.running) {
      await _cancel(deleteOnFinish: true);
    }
  }

  Future<void> _cancel({bool deleteOnFinish = false}) async {
    final l10n = context.l10n;
    final service = _session.activeService;
    if (!_session.running || service == null) return;
    if (_session.cancelling) {
      if (deleteOnFinish) _session.update(() => _session.deleteOnFinish = true);
      return;
    }
    _session.update(() {
      _session.stopRequested = true;
      _session.cancelling = true;
      _session.deleteOnFinish = deleteOnFinish;
    });
    final jobId = _session.jobId;
    if (jobId != null) await _cancelSubmittedJob(service, jobId, l10n);
  }

  Future<void> _cancelSubmittedJob(
    KtService service,
    String jobId,
    AppLocalizations l10n,
  ) async {
    final revision = _session.runRevision;
    try {
      await service.cancel(jobId);
      if (_session.jobId == jobId && _session.runRevision == revision) {
        _appendLog(l10n.dictationTranslationPageCancelAppendLog);
      }
    } catch (error) {
      if (_session.jobId != jobId || _session.runRevision != revision) return;
      _toast(l10n.dictationTranslationPageCancelToast(error.toString()));
      _session.update(() {
        _session.cancelling = false;
        _session.stopRequested = false;
        _session.deleteOnFinish = false;
      });
    }
  }

  Future<String?> _chooseCachedWritebackSite(List<CustomSite> sites) =>
      showDialog<String>(
        context: context,
        builder: (ctx) => SimpleDialog(
          title: Text(ctx.l10n.cacheWritebackLegacyTitle),
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 12),
              child: Text(ctx.l10n.cacheWritebackLegacyHint),
            ),
            SimpleDialogOption(
              onPressed: () => Navigator.pop(ctx),
              child: Text(ctx.l10n.cacheWritebackLocalOnly),
            ),
            for (final site in sites)
              SimpleDialogOption(
                onPressed: () => Navigator.pop(ctx, site.url),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(site.alias),
                    Text(site.url, style: Theme.of(ctx).textTheme.bodySmall),
                  ],
                ),
              ),
          ],
        ),
      );

  Future<void> _syncCachedResults() async {
    final l10n = context.l10n;
    if (_syncing || _session.running) return;
    KtService? service;
    var saved = 0;
    var skipped = 0;
    var failed = 0;
    try {
      setState(() => _syncing = true);
      service = _service();
      _persistConnection();
      final entries = await service.cachedResults();
      if (entries.isEmpty) {
        _toast(l10n.dictationTranslationPageSyncCachedResultsToast2);
        return;
      }
      _appendLog(
        l10n.dictationTranslationPageSyncCachedResultsAppendLog4(
          (entries.length).toString(),
        ),
      );
      final sites = app.customSites
          .where(
            (site) => KikoeruWritebackAccess.normalizeBase(site.url) != null,
          )
          .toList();
      final hasLegacy = entries.any(
        (entry) => entry.sourceBase?.trim().isNotEmpty != true,
      );
      final legacyBase = hasLegacy && sites.isNotEmpty && mounted
          ? await _chooseCachedWritebackSite(sites)
          : null;
      if (!mounted) return;
      final connection = service;
      final report = await KtCacheSync(
        download: (url) async =>
            utf8.decode(await connection.download(url), allowMalformed: true),
        save: (work, path, content) async {
          await LyricsLibraryService.instance.saveTranslatedLyrics(
            workId: work,
            relativePath: path,
            content: content,
          );
        },
        loadTracks: (base, id) =>
            ApiService.fetchTracksFromBase(base, id, forceRefresh: true),
        credentials: (base) => writebackCredentialsFor(app, base),
        configuredBases: sites.map((site) => site.url),
        legacySourceBase: legacyBase,
      ).run(entries);
      saved = report.saved;
      skipped = report.skipped;
      failed = report.failed;
      for (final error in report.errors) {
        _appendLog(
          l10n.dictationTranslationPageSyncCachedResultsAppendLog2(
            error.jobId,
            error.name,
            error.error.toString(),
          ),
        );
      }
      _appendLog(
        l10n.cacheWritebackSummary(
          report.written.toString(),
          report.notWritten.toString(),
        ),
      );
      for (final status in report.failures.keys) {
        _appendLog(status.label(l10n));
      }
      if (report.missingSource) _appendLog(l10n.cacheWritebackSourceMissing);
      _appendLog(
        l10n.dictationTranslationPageSyncCachedResultsAppendLog3(
          (saved).toString(),
          (skipped).toString(),
          (failed).toString(),
        ),
      );
      _session.update(
        () => _session.stage =
            l10n.dictationTranslationPageSyncCachedResultsUpdate,
      );
      _toast(
        l10n.dictationTranslationPageSyncCachedResultsToast3(
          (saved).toString(),
          (skipped > 0
                  ? l10n.dictationTranslationPageSyncCachedResultsToast(
                      (skipped).toString(),
                    )
                  : '')
              .toString(),
        ),
      );
    } catch (error) {
      _appendLog(
        l10n.dictationTranslationPageSyncCachedResultsAppendLog(
          (error).toString(),
        ),
      );
      _toast(
        l10n.dictationTranslationPageSyncCachedResultsAppendLog(
          (error).toString(),
        ),
      );
    } finally {
      service?.close();
      if (mounted) setState(() => _syncing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(context.l10n.dictationTranslationPageBuildText),
        actions: [
          IconButton(
            tooltip: context.l10n.dictationTranslationPageBuildTooltip,
            onPressed: _session.running || _syncing ? null : _syncCachedResults,
            icon: _syncing
                ? const SizedBox.square(
                    dimension: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.sync),
          ),
        ],
      ),
      body: SafeArea(
        top: false,
        child: LayoutBuilder(
          builder: (context, constraints) => SmoothSingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
            child: Align(
              alignment: Alignment.topCenter,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1120),
                child: constraints.maxWidth >= 900
                    ? Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(child: _connectionCard()),
                          const SizedBox(width: 16),
                          Expanded(child: _taskCards()),
                        ],
                      )
                    : Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _connectionCard(),
                          const SizedBox(height: 14),
                          _taskCards(),
                        ],
                      ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _taskCards() => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      _workCard(),
      if (_session.current != null) ...[
        const SizedBox(height: 14),
        _progressCard(),
      ],
      if (_session.logs.isNotEmpty) ...[const SizedBox(height: 14), _logCard()],
    ],
  );

  InputDecoration _inputDecoration(
    String label,
    IconData icon, {
    String? hint,
  }) => InputDecoration(
    labelText: label,
    labelStyle: TextStyle(fontSize: 11.5, color: p.muted),
    hintText: hint,
    hintStyle: TextStyle(fontSize: 12, color: p.dim),
    prefixIcon: Icon(icon, size: 18, color: p.muted),
    filled: true,
    fillColor: p.surface2,
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(11),
      borderSide: BorderSide(color: p.line),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(11),
      borderSide: BorderSide(color: p.line),
    ),
    disabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(11),
      borderSide: BorderSide(color: p.line),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(11),
      borderSide: BorderSide(color: p.accent),
    ),
    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
  );

  Widget _connectionCard() => _card(
    title: context.l10n.dictationTranslationPageConnectionCardTitle,
    icon: Icons.cable_outlined,
    children: [
      Container(
        width: double.infinity,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: p.surface2,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: p.line),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.download_outlined, color: p.accent),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    context.l10n.dictationTranslationPageConnectionCardText4,
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    context.l10n.dictationTranslationPageConnectionCardText5,
                    style: TextStyle(color: p.muted, fontSize: 12, height: 1.4),
                  ),
                  const SizedBox(height: 6),
                  TextButton.icon(
                    onPressed: _openKikoetaTranslDownload,
                    icon: const Icon(Icons.open_in_new, size: 16),
                    label: Text(
                      context.l10n.dictationTranslationPageConnectionCardText3,
                    ),
                    style: TextButton.styleFrom(
                      padding: EdgeInsets.zero,
                      minimumSize: const Size(0, 32),
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      const SizedBox(height: 12),
      if (!Platform.isAndroid)
        SegmentedButton<bool>(
          segments: [
            ButtonSegment(
              value: true,
              icon: Icon(Icons.computer_outlined, size: 17),
              label: Text(context.l10n.local),
            ),
            ButtonSegment(
              value: false,
              icon: Icon(Icons.wifi_outlined, size: 17),
              label: Text(context.l10n.network),
            ),
          ],
          style: SegmentedButton.styleFrom(
            backgroundColor: p.surface2,
            foregroundColor: p.muted,
            selectedBackgroundColor: p.accent.withValues(alpha: .12),
            selectedForegroundColor: p.accent,
            side: BorderSide(color: p.line),
            textStyle: const TextStyle(
              fontFamily: kAppFontFamily,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(11),
            ),
          ),
          selected: {_useLocal},
          onSelectionChanged: _session.running
              ? null
              : (value) => setState(() => _useLocal = value.first),
        ),
      if (!Platform.isAndroid) const SizedBox(height: 12),
      if (_useLocal)
        TextFormField(
          initialValue: _localEndpoint,
          enabled: false,
          style: TextStyle(fontSize: 13, color: p.muted),
          decoration: _inputDecoration(
            context.l10n.dictationTranslationPageConnectionCardInputDecoration2,
            Icons.dns_outlined,
          ),
        )
      else
        TextField(
          controller: _networkController,
          enabled: !_session.running,
          keyboardType: TextInputType.url,
          style: TextStyle(fontSize: 13, color: p.text),
          decoration: _inputDecoration(
            context.l10n.dictationTranslationPageConnectionCardInputDecoration,
            Icons.dns_outlined,
            hint: '192.168.1.20:2370',
          ),
        ),
      if (Platform.isAndroid)
        Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Text(
            context.l10n.dictationTranslationPageConnectionCardText2,
            style: TextStyle(color: p.muted, fontSize: 12),
          ),
        ),
      const SizedBox(height: 12),
      TextField(
        controller: _usernameController,
        enabled: !_session.running,
        autofillHints: const [AutofillHints.username],
        style: TextStyle(fontSize: 13, color: p.text),
        decoration: _inputDecoration(
          context.l10n.username,
          Icons.person_outline,
        ),
      ),
      const SizedBox(height: 10),
      TextField(
        controller: _passwordController,
        enabled: !_session.running,
        obscureText: _obscurePassword,
        autofillHints: const [AutofillHints.password],
        style: TextStyle(fontSize: 13, color: p.text),
        decoration: _inputDecoration(context.l10n.password, Icons.lock_outline)
            .copyWith(
              suffixIcon: IconButton(
                tooltip: _obscurePassword
                    ? context.l10n.dictationTranslationPageConnectionCardTooltip
                    : context
                          .l10n
                          .dictationTranslationPageConnectionCardTooltip2,
                onPressed: () =>
                    setState(() => _obscurePassword = !_obscurePassword),
                icon: Icon(
                  _obscurePassword
                      ? Icons.visibility_outlined
                      : Icons.visibility_off_outlined,
                ),
              ),
            ),
      ),
      Align(
        alignment: Alignment.centerRight,
        child: TextButton(
          onPressed: _session.running
              ? null
              : () => setState(() {
                  _usernameController.text = KtService.defaultUsername;
                  _passwordController.text = KtService.defaultPassword;
                }),
          child: Text(context.l10n.dictationTranslationPageConnectionCardText),
        ),
      ),
      const SizedBox(height: 10),
      Align(
        alignment: Alignment.centerRight,
        child: OutlinedButton.icon(
          onPressed: _testing || _session.running ? null : _testConnection,
          icon: _testing
              ? const SizedBox.square(
                  dimension: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.wifi_tethering, size: 18),
          label: Text(context.l10n.testConnection),
        ),
      ),
    ],
  );

  Widget _workCard() {
    final clearButton = TextButton.icon(
      onPressed: _session.entries.isEmpty ? null : _clearQueue,
      icon: const Icon(Icons.playlist_remove_outlined, size: 18),
      label: Text(context.l10n.dictationQueueClear),
      style: TextButton.styleFrom(
        foregroundColor: p.muted,
        textStyle: const TextStyle(fontFamily: kAppFontFamily, fontSize: 12),
        padding: const EdgeInsets.symmetric(horizontal: 8),
        minimumSize: const Size(0, 36),
      ),
    );
    if (_session.entries.isEmpty) {
      return _card(
        title: context.l10n.dictationQueueTitle,
        icon: Icons.library_music_outlined,
        action: clearButton,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 24),
            child: Center(
              child: Text(
                context.l10n.dictationQueueEmpty,
                style: TextStyle(color: p.dim, fontSize: 13),
              ),
            ),
          ),
        ],
      );
    }
    return _card(
      title: context.l10n.dictationQueueTitle,
      icon: Icons.library_music_outlined,
      action: clearButton,
      children: [
        DictationQueueList(
          queue: _session,
          onDelete: _deleteEntry,
          onJump: _jumpEntry,
          onRetry: _syncing || _session.cancelling ? null : _retryEntry,
          onRetryWriteback: _retryWriteback,
        ),
        const SizedBox(height: 10),
        SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            style: FilledButton.styleFrom(
              backgroundColor: _session.running ? p.red : p.accent,
              minimumSize: const Size.fromHeight(44),
              textStyle: const TextStyle(
                fontFamily: kAppFontFamily,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            onPressed: _session.running
                ? (_session.cancelling ? null : _cancel)
                : (_syncing || !_session.canStart ? null : _start),
            icon: Icon(
              _session.running ? Icons.stop_circle_outlined : Icons.graphic_eq,
            ),
            label: Text(
              _session.running
                  ? (_session.cancelling
                        ? context.l10n.dictationTranslationPageWorkCardText2
                        : context.l10n.dictationTranslationPageWorkCardText)
                  : context.l10n.dictationTranslationPageWorkCardText3,
            ),
          ),
        ),
      ],
    );
  }

  Widget _progressCard() => _card(
    title: context.l10n.dictationTranslationPageProgressCardTitle,
    icon: Icons.timeline,
    children: [
      LinearProgressIndicator(
        value: _progress,
        minHeight: 6,
        borderRadius: BorderRadius.circular(999),
        backgroundColor: p.surface3,
        color: p.accent,
      ),
      const SizedBox(height: 10),
      Row(
        children: [
          Expanded(
            child: Text(
              _session.stage,
              style: TextStyle(
                color: p.text,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Text(
            '${(_progress * 100).round()}%',
            style: TextStyle(
              color: p.accent,
              fontSize: 13,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
      if (_tracks.isNotEmpty) ...[
        const SizedBox(height: 4),
        Text(
          context.l10n.dictationTranslationPageProgressCardText2(
            (_session.finishedFiles).toString(),
            (_tracks.length).toString(),
            (_session.savedFiles > 0
                    ? context.l10n.dictationTranslationPageProgressCardText(
                        (_session.savedFiles).toString(),
                      )
                    : '')
                .toString(),
          ),
          style: TextStyle(color: p.muted, fontSize: 12),
        ),
      ],
    ],
  );

  Widget _logCard() => _card(
    title: context.l10n.dictationTranslationPageLogCardTitle,
    icon: Icons.terminal,
    children: [
      Container(
        width: double.infinity,
        constraints: const BoxConstraints(minHeight: 140, maxHeight: 280),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: p.surface2,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: p.line),
        ),
        child: SmoothSingleChildScrollView(
          reverse: true,
          child: SelectableText(
            _session.logs.isEmpty
                ? context.l10n.dictationTranslationPageLogCardSelectableText
                : _session.logs.join('\n'),
            style: TextStyle(
              color: _session.logs.isEmpty ? p.dim : p.text,
              fontSize: 12,
              height: 1.65,
            ),
          ),
        ),
      ),
    ],
  );

  Widget _card({
    required String title,
    required IconData icon,
    required List<Widget> children,
    Widget? action,
  }) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: p.surface,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: p.line),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 19, color: p.accent),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                title,
                style: TextStyle(
                  color: p.text,
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            ?action,
          ],
        ),
        const SizedBox(height: 14),
        ...children,
      ],
    ),
  );

  void _toast(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(SnackBar(content: Text(message)));
  }
}
