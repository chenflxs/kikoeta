import '../data.dart';
import 'api_service.dart';
import 'kikoeru_writeback_access.dart';

/// Always resolves credentials for the job's original site, independently of
/// the server currently selected in the player.
KikoeruWritebackCredentials writebackCredentialsFor(AppState app, String base) {
  final normalized = KikoeruWritebackAccess.normalizeBase(base) ?? base;
  final site = app.customSites
      .where(
        (site) => KikoeruWritebackAccess.normalizeBase(site.url) == normalized,
      )
      .firstOrNull;
  final tokenBase =
      site?.url.trim().replaceFirst(RegExp(r'/+$'), '') ?? normalized;
  final token = ApiService.tokenFor(app, tokenBase);
  return KikoeruWritebackCredentials(
    authorization: token == null || token.isEmpty ? null : 'Bearer $token',
    key: site?.lyricsWritebackKey ?? '',
  );
}
