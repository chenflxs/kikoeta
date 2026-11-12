import 'package:flutter/material.dart';

import '../data.dart';
import '../l10n/strings.dart';
import '../services/api_service.dart';
import '../services/lyrics_hub.dart';
import '../services/lyrics_library_service.dart';
import '../services/lyrics_translation_service.dart';

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
      final translator = LyricsTranslationService.fromApp(widget.app);
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
      if (mounted) Navigator.pop(context, path);
    } on LyricsTranslationCancelled {
      // Cancellation is handled immediately by the dialog button.
    } catch (error) {
      if (mounted && !_cancelled) {
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
