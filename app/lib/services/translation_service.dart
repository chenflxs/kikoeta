import '../data.dart';
import '../l10n/generated/app_localizations.dart';
import '../l10n/strings.dart';
import '../src/rust/api/translate.dart';
import 'app_log.dart';

class TranslationFallback {
  const TranslationFallback(this.from, this.to, this.errorCode);

  final String from;
  final String to;
  final String? errorCode;

  String message(AppLocalizations l10n) {
    final failed = _providerName(from);
    final next = _providerName(to);
    final code = errorCode;
    return code == null
        ? l10n.translationFallback(failed, next)
        : l10n.translationFallbackWithCode(failed, code, next);
  }

  static String _providerName(String provider) => switch (provider) {
    'google' => 'Google',
    'microsoft' => 'Microsoft',
    'deepl' => 'DeepL',
    'index' => 'Index-Translate',
    _ => provider,
  };
}

/// Captures the settings for a translation job. Fallback only changes the
/// provider for the current batch.
class TranslationService {
  TranslationService.fromApp(AppState app, {this.onFallback})
    : engine = app.engine,
      sourceLanguage = app.translationSource,
      targetLanguage = app.resolvedTranslationTarget,
      _deeplKey = app.deeplKey.trim(),
      _openAiConfig = Map.of(app.aiConfig),
      _indexConfig = app.indexAiConfig;

  final String engine;
  final String sourceLanguage;
  final String targetLanguage;
  final String _deeplKey;
  final Map<String, String> _openAiConfig;
  final Map<String, String> _indexConfig;
  final void Function(TranslationFallback)? onFallback;
  final _reportedFallbacks = <(String, String)>{};
  static final _httpErrorCode = RegExp(r'\bHTTP\s+([45]\d{2})\b');
  static final _microsoftErrorCode = RegExp(
    r'^微软翻译(?:拒绝请求|授权失效或请求受限)（([45]\d{2})）',
  );

  bool get isAi => engine == 'openai' || engine == 'index';

  String? configurationError(AppLocalizations l10n) => switch (engine) {
    'google' || 'microsoft' || 'index' => null,
    'deepl' => _deeplKey.isEmpty ? l10n.workPageTranslateTitlesToast6 : null,
    'openai' =>
      (_openAiConfig['base'] ?? '').trim().isEmpty ||
              (_openAiConfig['model'] ?? '').trim().isEmpty
          ? l10n.workPageTranslateTitlesToast4
          : null,
    _ => l10n.workPageTranslateTitlesToast2,
  };

  /// The caller discards the result when the job is no longer current.
  Future<String> translate(
    String text, {
    bool lyrics = false,
    bool Function()? isCurrent,
  }) async {
    if (text.trim().isEmpty || isCurrent?.call() == false) return '';
    if (engine != 'google' && engine != 'microsoft') {
      return _request(engine, text, lyrics: lyrics);
    }

    final candidates = [
      engine,
      engine == 'google' ? 'microsoft' : 'google',
      if (_deeplKey.isNotEmpty) 'deepl',
      'index',
    ];
    final expectedLines = text.split('\n').length;
    String? incomplete;
    late Object lastError;
    late StackTrace lastStack;
    for (var i = 0; i < candidates.length; i++) {
      if (isCurrent?.call() == false) return '';
      final candidate = candidates[i];
      try {
        final output = await _request(candidate, text, lyrics: lyrics);
        if (isCurrent?.call() == false) return '';
        if (output.trim().isNotEmpty) {
          if (expectedLines == 1) return output;
          final lines = output.split('\n');
          if (lines.length == expectedLines &&
              lines.every((line) => line.trim().isNotEmpty)) {
            return output;
          }
          // Preserve the existing title batch recovery when no provider can
          // return a complete result for this batch.
          incomplete ??= output;
        }
        throw FormatException(
          lyrics
              ? appL10n.lyricsTranslationInvalidResponse
              : appL10n.workPageTranslateTitlesFormatException,
        );
      } catch (error, stack) {
        // Rust's Result<String, String> can surface a raw String through FRB.
        if (error is! String && error is! Exception) rethrow;
        if (isCurrent?.call() == false) return '';
        AppLog.recordError('Translation provider $candidate', error, stack);
        lastError = error;
        lastStack = stack;
        final notify = onFallback;
        if (notify != null && i + 1 < candidates.length) {
          final next = candidates[i + 1];
          if (_reportedFallbacks.add((candidate, next))) {
            final code = error is String
                ? (_microsoftErrorCode.firstMatch(error) ??
                          _httpErrorCode.firstMatch(error))
                      ?.group(1)
                : null;
            notify(TranslationFallback(candidate, next, code));
          }
        }
      }
    }
    if (incomplete != null) return incomplete;
    Error.throwWithStackTrace(lastError, lastStack);
  }

  Future<String> _request(
    String provider,
    String text, {
    required bool lyrics,
  }) {
    switch (provider) {
      case 'google':
        return apiTranslateGoogle(
          text: text,
          src: sourceLanguage,
          dst: targetLanguage,
        );
      case 'microsoft':
        return apiTranslateMicrosoft(
          text: text,
          src: sourceLanguage,
          dst: targetLanguage,
        );
      case 'deepl':
        return apiTranslateDeepl(
          text: text,
          src: sourceLanguage,
          dst: targetLanguage,
          apiKey: _deeplKey,
        );
      case 'index':
      case 'openai':
        final config = provider == 'index' ? _indexConfig : _openAiConfig;
        return apiTranslateOpenai(
          baseUrl: config['base']!,
          model: config['model']!,
          apiKey: config['key'] ?? '',
          temperature: 0.2,
          text:
              '[[KIKOETA_TARGET:$targetLanguage]]\n'
              '[[KIKOETA_SOURCE:$sourceLanguage]]\n'
              '${lyrics ? '[[KIKOETA_LYRICS]]\n' : ''}$text',
        );
      default:
        throw StateError(appL10n.workPageTranslateTitlesToast2);
    }
  }
}
