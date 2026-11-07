import 'generated/app_localizations.dart';
import '../services/kikoeru_writeback_access.dart';

extension WritebackStrings on KikoeruWritebackStatus {
  String label(AppLocalizations l10n) => switch (this) {
    KikoeruWritebackStatus.unknown => l10n.writebackUnknown,
    KikoeruWritebackStatus.allowed => l10n.writebackReady,
    KikoeruWritebackStatus.disabled => l10n.writebackDisabled,
    KikoeruWritebackStatus.unsupported => l10n.writebackUnsupported,
    KikoeruWritebackStatus.loginRequired => l10n.writebackLoginRequired,
    KikoeruWritebackStatus.roleForbidden => l10n.writebackRoleForbidden,
    KikoeruWritebackStatus.keyRequired => l10n.writebackKeyRequired,
    KikoeruWritebackStatus.keyInvalid => l10n.writebackKeyInvalid,
    KikoeruWritebackStatus.unconfigured => l10n.writebackUnconfigured,
    KikoeruWritebackStatus.sourceUnavailable => l10n.writebackSourceUnavailable,
    KikoeruWritebackStatus.directoryUnwritable =>
      l10n.writebackDirectoryUnwritable,
    KikoeruWritebackStatus.conflict => l10n.writebackConflict,
    KikoeruWritebackStatus.networkError => l10n.writebackNetworkError,
    KikoeruWritebackStatus.failed => l10n.writebackFailed,
  };
}
