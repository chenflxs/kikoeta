import 'package:flutter/material.dart';

import '../l10n/generated/app_localizations.dart';
import '../l10n/strings.dart';
import '../services/cloud_sync_service.dart';
import '../services/webdav_client.dart';

String dataErrorText(AppLocalizations l, String? code) => switch (code) {
  'backupInvalid' => l.backupInvalid,
  'backupTooLarge' => l.backupTooLarge,
  'webdavInvalidConfig' => l.webdavInvalidConfig,
  'webdavAuthError' => l.webdavAuthError,
  'webdavTimeout' => l.webdavTimeout,
  'webdavNetworkError' => l.webdavNetworkError,
  'webdavRateLimited' => l.webdavRateLimited,
  'webdavNoEtag' => l.webdavNoEtag,
  'webdavNoBackup' => l.webdavNoBackup,
  'webdavCleanupFailed' => l.webdavCleanupFailed,
  'webdavBusy' => l.webdavBusy,
  'webdavConflict' => l.webdavConflict,
  _ => l.webdavRequestFailed,
};

class WebDavSettingsDialog extends StatefulWidget {
  final CloudSyncService sync;
  const WebDavSettingsDialog({super.key, required this.sync});
  @override
  State<WebDavSettingsDialog> createState() => _WebDavSettingsDialogState();
}

class _WebDavSettingsDialogState extends State<WebDavSettingsDialog> {
  late final _url = TextEditingController(text: widget.sync.config.url);
  late final _user = TextEditingController(text: widget.sync.config.username);
  late final _password = TextEditingController(
    text: widget.sync.config.password,
  );
  late final _folder = TextEditingController(text: widget.sync.config.folder);
  late bool _auto = widget.sync.enabled;
  bool _testing = false;
  String? _message;
  bool _success = false;
  WebDavConfig get _value => WebDavConfig(
    url: _url.text.trim(),
    username: _user.text.trim(),
    password: _password.text,
    folder: _folder.text.trim(),
  );

  Future<void> _test() async {
    setState(() {
      _testing = true;
      _message = null;
      _success = false;
    });
    try {
      await widget.sync.test(_value);
      if (mounted) {
        setState(() {
          _message = context.l10n.webdavTestDone;
          _success = true;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(
          () => _message = dataErrorText(
            context.l10n,
            e is WebDavException
                ? e.code
                : e is StateError
                ? e.message
                : null,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _testing = false);
    }
  }

  void _save() {
    try {
      widget.sync.saveConfig(_value, autoSync: _auto);
      Navigator.pop(context);
    } catch (e) {
      setState(() {
        _success = false;
        _message = dataErrorText(
          context.l10n,
          e is WebDavException ? e.code : null,
        );
      });
    }
  }

  @override
  void dispose() {
    for (final c in [_url, _user, _password, _folder]) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return PopScope(
      canPop: !_testing,
      child: AlertDialog(
        title: Text(l.webdavTitle),
        content: SizedBox(
          width: 420,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (final field in [
                  (_url, l.webdavUrl),
                  (_user, l.webdavUsername),
                  (_password, l.webdavPassword),
                  (_folder, l.webdavFolder),
                ])
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: TextField(
                      controller: field.$1,
                      enabled: !_testing,
                      obscureText: field.$1 == _password,
                      autocorrect: false,
                      enableSuggestions: false,
                      decoration: InputDecoration(labelText: field.$2),
                    ),
                  ),
                SwitchListTile.adaptive(
                  contentPadding: EdgeInsets.zero,
                  title: Text(l.webdavAuto),
                  value: _auto,
                  onChanged: _testing ? null : (v) => setState(() => _auto = v),
                ),
                Text(
                  l.webdavAutoHint,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                if (_message != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: Text(
                      _message!,
                      style: TextStyle(
                        color: _success
                            ? null
                            : Theme.of(context).colorScheme.error,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: _testing ? null : _test,
            child: Text(l.webdavTest),
          ),
          TextButton(
            onPressed: _testing ? null : () => Navigator.pop(context),
            child: Text(l.cancel),
          ),
          FilledButton(
            onPressed: _testing ? null : _save,
            child: _testing
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Text(l.save),
          ),
        ],
      ),
    );
  }
}
