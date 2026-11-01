import 'package:flutter/material.dart';

import '../l10n/strings.dart';
import '../services/dictation_batch_importer.dart';

Future<DictationBatchImportResult?> showDictationBatchImportDialog(
  BuildContext context, {
  required DictationBatchImporter importer,
  required bool Function() sourceChanged,
}) => showDialog<DictationBatchImportResult>(
  context: context,
  barrierDismissible: false,
  builder: (_) =>
      _BatchImportDialog(importer: importer, sourceChanged: sourceChanged),
);

class _BatchImportDialog extends StatefulWidget {
  final DictationBatchImporter importer;
  final bool Function() sourceChanged;
  const _BatchImportDialog({
    required this.importer,
    required this.sourceChanged,
  });

  @override
  State<_BatchImportDialog> createState() => _BatchImportDialogState();
}

class _BatchImportDialogState extends State<_BatchImportDialog> {
  int _processed = 0;
  int _total = -1;
  String _workId = '';
  String? _error;
  DictationBatchImportResult? _prepared;

  bool get _active => mounted && (ModalRoute.of(context)?.isCurrent ?? false);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _prepare());
  }

  Future<void> _prepare() async {
    try {
      final result = await widget.importer.prepare(
        shouldCancel: () => !_active || widget.sourceChanged(),
        onProgress: (processed, total, workId) {
          if (!_active) return;
          setState(() {
            _processed = processed;
            _total = total;
            _workId = workId;
          });
        },
      );
      if (!mounted || !_active) return;
      if (result != null && result.existingTracks > 0) {
        setState(() => _prepared = result);
      } else {
        Navigator.pop(context, result);
      }
    } catch (error) {
      if (_active) setState(() => _error = error.toString());
    }
  }

  void _resolveExistingLyrics({required bool retranslate}) {
    if (widget.sourceChanged()) {
      Navigator.pop(context);
      return;
    }
    Navigator.pop(
      context,
      _prepared!.resolveExistingLyrics(retranslate: retranslate),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(context.l10n.batchTranslation),
      content: SizedBox(
        width: 340,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (_error != null)
              Text(context.l10n.batchTranslationFailed(_error!))
            else if (_prepared != null)
              Text(
                context.l10n.batchTranslationExistingLyrics(
                  _prepared!.existingTracks.toString(),
                ),
              )
            else ...[
              Text(context.l10n.batchTranslationPreparing),
              const SizedBox(height: 12),
              LinearProgressIndicator(
                value: _total > 0 ? (_processed / _total).clamp(0, 1) : null,
              ),
              const SizedBox(height: 10),
              Text(
                '$_workId  $_processed${_total >= 0 ? ' / $_total' : ''}',
                style: TextStyle(
                  fontSize: 11,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(
            _error == null ? context.l10n.cancel : context.l10n.close,
          ),
        ),
        if (_prepared != null) ...[
          TextButton(
            onPressed: () => _resolveExistingLyrics(retranslate: false),
            child: Text(context.l10n.batchTranslationSkipExisting),
          ),
          FilledButton(
            onPressed: () => _resolveExistingLyrics(retranslate: true),
            child: Text(context.l10n.batchTranslationRetranslate),
          ),
        ],
      ],
    );
  }
}
