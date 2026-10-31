import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../l10n/strings.dart';
import '../services/app_data_service.dart';
import '../services/cloud_sync_service.dart';
import '../services/portable_backup.dart';
import '../services/webdav_client.dart';
import '../theme.dart';
import 'webdav_settings_dialog.dart';

typedef DataSettingsRowBuilder =
    Widget Function({
      IconData? icon,
      required String title,
      String? sub,
      Widget? trailing,
      VoidCallback? onTap,
      required bool showDivider,
    });

/// Uses the owning settings page's complete row and card implementation.
class DataSyncSettings extends StatefulWidget {
  final DataSettingsRowBuilder rowBuilder;
  final Widget Function(List<Widget>) groupBuilder;
  const DataSyncSettings({
    super.key,
    required this.rowBuilder,
    required this.groupBuilder,
  });

  @override
  State<DataSyncSettings> createState() => _DataSyncSettingsState();
}

class _DataSyncSettingsState extends State<DataSyncSettings> {
  bool _dataBusy = false;

  String _syncStatus(BuildContext context) {
    if (cloudSync.busy) return context.l10n.webdavSyncing;
    if (cloudSync.error != null) {
      return dataErrorText(context.l10n, cloudSync.error);
    }
    final date = DateTime.tryParse(cloudSync.lastSuccess ?? '')?.toLocal();
    if (date == null) return context.l10n.webdavNever;
    final local = MaterialLocalizations.of(context);
    return '${local.formatFullDate(date)} ${local.formatTimeOfDay(TimeOfDay.fromDateTime(date))}';
  }

  void _toast(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _transferData({required bool importing}) async {
    if (_dataBusy || cloudSync.busy) return;
    setState(() => _dataBusy = true);
    final l = context.l10n;
    try {
      if (importing) {
        final selection = await FilePicker.pickFiles(
          type: FileType.custom,
          allowedExtensions: ['json'],
          withData: false,
        );
        if (selection == null || !mounted) return;
        final selected = selection.files.single;
        if (selected.size > PortableBackup.maxBytes) {
          throw const FormatException('backupTooLarge');
        }
        final path = selected.path;
        final bytes = path != null
            ? await File(path).readAsBytes()
            : selected.bytes;
        if (bytes == null) throw const FormatException('backupInvalid');
        final backup = await PortableBackup.decode(bytes);
        if (!mounted) return;
        final confirmed = await showDialog<bool>(
          context: context,
          builder: (_) => AlertDialog(
            title: Text(l.dataImport),
            content: Text(l.dataImportConfirm),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: Text(l.cancel),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: Text(l.confirm),
              ),
            ],
          ),
        );
        if (confirmed != true) return;
        await cloudSync.importFile(backup);
        _toast(l.dataImportDone);
      } else {
        final bytes = await cloudSync.capture().encode();
        final date = DateTime.now().toIso8601String().substring(0, 10);
        final path = await FilePicker.saveFile(
          fileName: 'kikoeta-$date.json',
          type: FileType.custom,
          allowedExtensions: ['json'],
          bytes: bytes,
        );
        if (path != null) _toast(l.dataExportDone);
      }
    } catch (e) {
      final code = e is FormatException
          ? e.message
          : e is WebDavException
          ? e.code
          : e is StateError
          ? e.message
          : null;
      _toast(code == null ? l.dataOperationFailed : dataErrorText(l, code));
    } finally {
      if (mounted) setState(() => _dataBusy = false);
    }
  }

  Future<void> _sync() async {
    if (_dataBusy || cloudSync.busy) return;
    final l = context.l10n;
    final p = Theme.of(context).brightness == Brightness.dark
        ? AppColors.dark
        : AppColors.light;
    final resolution = await showDialog<SyncResolution>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: p.surface,
        constraints: const BoxConstraints(minWidth: 280, maxWidth: 480),
        scrollable: true,
        title: Text(l.webdavSyncNow),
        content: SizedBox(
          width: 420,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (final option in [
                (
                  SyncResolution.local,
                  Icons.cloud_upload_outlined,
                  l.webdavUploadOverwrite,
                ),
                (
                  SyncResolution.cloud,
                  Icons.cloud_download_outlined,
                  l.webdavDownloadOverwrite,
                ),
                (SyncResolution.merge, Icons.merge_outlined, l.webdavMergeData),
              ])
                widget.rowBuilder(
                  icon: option.$2,
                  title: option.$3,
                  sub: option.$1 == SyncResolution.merge
                      ? l.webdavMergeHint
                      : null,
                  onTap: () => Navigator.pop(dialogContext, option.$1),
                  showDivider: option.$1 != SyncResolution.merge,
                ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text(l.cancel),
          ),
        ],
      ),
    );
    if (!mounted || resolution == null) return;
    if (_dataBusy || cloudSync.busy) {
      _toast(l.webdavBusy);
      return;
    }
    await cloudSync.sync(resolution: resolution);
    if (!cloudSync.hasConflict) {
      _toast(
        cloudSync.error == null
            ? l.webdavSyncDone
            : dataErrorText(l, cloudSync.error),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: cloudSync,
      builder: (context, _) {
        final p = Theme.of(context).brightness == Brightness.dark
            ? AppColors.dark
            : AppColors.light;
        final blocked = _dataBusy || cloudSync.busy;
        Widget chevron() => Icon(Icons.chevron_right, size: 20, color: p.dim);
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            widget.groupBuilder([
              widget.rowBuilder(
                icon: Icons.file_upload_outlined,
                title: context.l10n.dataExport,
                sub: context.l10n.dataScope,
                trailing: chevron(),
                onTap: blocked ? null : () => _transferData(importing: false),
                showDivider: true,
              ),
              widget.rowBuilder(
                icon: Icons.file_download_outlined,
                title: context.l10n.dataImport,
                trailing: chevron(),
                onTap: blocked ? null : () => _transferData(importing: true),
                showDivider: true,
              ),
              widget.rowBuilder(
                icon: Icons.cloud_outlined,
                title: context.l10n.webdavTitle,
                trailing: chevron(),
                onTap: blocked
                    ? null
                    : () => showDialog<void>(
                        context: context,
                        barrierDismissible: false,
                        builder: (_) => WebDavSettingsDialog(sync: cloudSync),
                      ),
                showDivider: true,
              ),
              widget.rowBuilder(
                icon: Icons.sync,
                title: context.l10n.webdavSyncNow,
                sub: _syncStatus(context),
                onTap: blocked ? null : () => _sync(),
                trailing: blocked
                    ? SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: p.accent,
                        ),
                      )
                    : chevron(),
                showDivider: false,
              ),
            ]),
          ],
        );
      },
    );
  }
}
