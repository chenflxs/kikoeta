import 'package:flutter/material.dart';

import '../data.dart';
import '../l10n/strings.dart';
import '../l10n/writeback_strings.dart';
import '../services/api_service.dart';
import '../services/kikoeru_writeback_access.dart';
import '../services/kikoeru_writeback_site.dart';
import '../theme.dart';

class KikoeruWritebackSettings extends StatefulWidget {
  final AppState app;
  final TextEditingController url;
  final TextEditingController user;
  final TextEditingController password;
  final TextEditingController writebackKey;
  final WidgetBuilder keyField;

  const KikoeruWritebackSettings({
    super.key,
    required this.app,
    required this.url,
    required this.user,
    required this.password,
    required this.writebackKey,
    required this.keyField,
  });

  @override
  State<KikoeruWritebackSettings> createState() =>
      _KikoeruWritebackSettingsState();
}

class _KikoeruWritebackSettingsState extends State<KikoeruWritebackSettings> {
  KikoeruWritebackStatus _status = KikoeruWritebackStatus.unknown;
  bool _needsKey = false;
  bool _checking = false;
  int _revision = 0;
  KikoeruWritebackAccess? _access;

  @override
  void initState() {
    super.initState();
    widget.url.addListener(_urlChanged);
    if (widget.url.text.trim().isNotEmpty) _check();
  }

  void _urlChanged() {
    _revision++;
    _access?.close();
    setState(() {
      _checking = false;
      _needsKey = false;
      _status = KikoeruWritebackStatus.unknown;
    });
  }

  Future<void> _check({bool login = false}) async {
    final base = widget.url.text.trim().replaceFirst(RegExp(r'/+$'), '');
    final revision = ++_revision;
    _access?.close();
    final access = KikoeruWritebackAccess.connect(base, () {
      final saved = writebackCredentialsFor(widget.app, base);
      return KikoeruWritebackCredentials(
        authorization: saved.authorization,
        key: widget.writebackKey.text,
      );
    });
    _access = access;
    setState(() => _checking = true);
    try {
      var status = access == null
          ? KikoeruWritebackStatus.failed
          : await access.check();
      if (login &&
          access != null &&
          !const {
            KikoeruWritebackStatus.disabled,
            KikoeruWritebackStatus.unsupported,
            KikoeruWritebackStatus.networkError,
            KikoeruWritebackStatus.unconfigured,
          }.contains(status) &&
          const [
            'account',
            'account_and_key',
            'legacy',
          ].contains(access.authentication) &&
          widget.user.text.trim().isNotEmpty &&
          widget.password.text.isNotEmpty) {
        try {
          await ApiService.login(
            widget.app,
            base,
            widget.user.text.trim(),
            widget.password.text,
          );
          if (!mounted || revision != _revision) return;
          status = await access.check();
        } catch (_) {
          status = KikoeruWritebackStatus.loginRequired;
        }
      }
      if (!mounted || revision != _revision) return;
      setState(() {
        _status = status;
        _needsKey = access?.needsKey == true;
      });
    } finally {
      access?.close();
      if (mounted && revision == _revision) setState(() => _checking = false);
    }
  }

  @override
  void dispose() {
    _revision++;
    widget.url.removeListener(_urlChanged);
    _access?.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = Theme.of(context).brightness == Brightness.dark
        ? AppColors.dark
        : AppColors.light;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (_needsKey) widget.keyField(context),
        Row(
          children: [
            Expanded(
              child: Text(
                _checking
                    ? context.l10n.writebackChecking
                    : _status.label(context.l10n),
                style: TextStyle(
                  fontSize: 12,
                  color: _status == KikoeruWritebackStatus.allowed
                      ? p.green
                      : p.muted,
                ),
              ),
            ),
            TextButton.icon(
              onPressed: _checking ? null : () => _check(login: true),
              icon: const Icon(Icons.verified_user_outlined, size: 16),
              label: Text(
                context.l10n.writebackCheck,
                style: const TextStyle(fontSize: 12),
              ),
            ),
          ],
        ),
        const SizedBox(height: 13),
      ],
    );
  }
}
