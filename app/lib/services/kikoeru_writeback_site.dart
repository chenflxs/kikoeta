import '../data.dart';
import 'api_service.dart';
import 'kikoeru_writeback_access.dart';

/// Always resolves credentials for the job's original site, independently of
/// the server currently selected in the player.
KikoeruWritebackCredentials writebackCredentialsFor(AppState app, String base) {
  final normalized = base.replaceFirst(RegExp(r'/+$'), '');
  final site = app.customSites
      .where((site) => site.url.replaceFirst(RegExp(r'/+$'), '') == normalized)
      .firstOrNull;
  final token = ApiService.tokenFor(app, normalized);
  return KikoeruWritebackCredentials(
    authorization: token == null || token.isEmpty ? null : 'Bearer $token',
    key: site?.lyricsWritebackKey ?? '',
  );
}
