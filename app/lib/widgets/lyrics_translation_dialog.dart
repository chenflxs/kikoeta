import 'package:flutter/material.dart';

import '../data.dart';
import '../l10n/strings.dart';
import '../services/api_service.dart';
import '../services/app_log.dart';
import '../services/lyrics_hub.dart';
import '../services/lyrics_library_service.dart';
import '../services/lyrics_translation_service.dart';
import '../services/translation_service.dart';

typedef LyricsTranslationResult = ({
  String path,
  TranslationFallback? fallback,
});

class LyricsTranslationDialog extends StatefulWidget {
  const LyricsTranslationDialog({
    super.key,
    required this.app,
    required this.selection,
    required this.source,
  });

  final AppState app;
  final LyricsTrackSelection selection;
  final List<LyricLine> source;

  @override
  State<LyricsTranslationDialog> createState() =>
      _LyricsTranslationDialogState();
}

class _LyricsTranslationDialogState extends State<LyricsTranslationDialog> {
  bool _cancelled = false;
  bool _saving = false;
  int _completed = 0;
  int _total = 0;
  String? _error;
  TranslationFallback? _fallback;

  @override
  void initState() {
    super.initState();
    _translate();
  }

  @override
  void dispose() {
    _cancelled = true;
    super.dispose();
  }

  Future<void> _translate() async {
    try {
      final translator = LyricsTranslationService.fromApp(
        widget.app,
        onFallback: (fallback) {
          if (mounted) setState(() => _fallback = fallback);
        },
      );
      final translated = await translator.translate(
        widget.source,
        isCancelled: () => _cancelled,
        onProgress: (completed, total) {
          if (mounted) {
            setState(() {
              _completed = completed;
              _total = total;
            });
          }
        },
      );
      if (_cancelled || !mounted) return;
      setState(() => _saving = true);
      final path = LyricsLibraryService.translationPath(
        widget.selection.work.rj,
        widget.selection.track.path,
        targetLanguage: translator.targetLanguage,
      );
      final content = LyricsTranslationService.toLrc(translated);
      await LyricsLibraryService.instance.saveTranslatedLyrics(
        workId: widget.selection.work.rj,
        relativePath: path,
        content: content,
        isTranslated: true,
      );
      final hub = LyricsHub.instance;
      if (hub.isSelectionCurrent(widget.selection) &&
          identical(hub.allLyrics, widget.source)) {
        await hub.loadManualLyrics(
          widget.selection,
          () async => ApiService.parseLyrics(content),
          sourceName: path,
        );
      }
      if (mounted) {
        Navigator.pop<LyricsTranslationResult>(context, (
          path: path,
          fallback: _fallback,
        ));
      }
    } on LyricsTranslationCancelled {
      // Cancellation is handled immediately by the dialog button.
    } catch (error, stack) {
      if (mounted && !_cancelled) {
        AppLog.recordError(
          _saving ? 'lyrics save translation' : 'lyrics translate',
          error,
          stack,
        );
        setState(() {
          _error = error.toString();
          _saving = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: _error != null || _cancelled,
    child: AlertDialog(
      scrollable: true,
      title: Text(context.l10n.lyricsTranslate),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (_error != null)
            Text(_error!)
          else ...[
            LinearProgressIndicator(
              value: _total == 0 ? null : _completed / _total,
            ),
            const SizedBox(height: 12),
            Text(context.l10n.lyricsTranslationProgress(_completed, _total)),
          ],
          if (_fallback case final fallback?) ...[
            const SizedBox(height: 8),
            Semantics(
              liveRegion: true,
              child: Text(fallback.message(context.l10n)),
            ),
          ],
        ],
      ),
      actions: [
        TextButton(
          onPressed: _saving
              ? null
              : () {
                  setState(() => _cancelled = true);
                  Navigator.pop(context);
                },
          child: Text(
            _error == null ? context.l10n.cancel : context.l10n.close,
          ),
        ),
      ],
    ),
  );
}
