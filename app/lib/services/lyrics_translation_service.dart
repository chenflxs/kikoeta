import '../data.dart';
import '../l10n/strings.dart';
import '../src/rust/api/translate.dart';

class LyricsTranslationCancelled implements Exception {}

/// Bounded, sequential batches. Only text crosses the translation boundary;
/// timestamps and cue positions stay local.
class LyricsTranslationService {
  LyricsTranslationService({
    required this.isAi,
    required this.request,
    this.requestGap = const Duration(milliseconds: 350),
  });

  factory LyricsTranslationService.fromApp(AppState app) {
    final engine = app.engine;
    final source = app.translationSource;
    final target = app.resolvedTranslationTarget;
    final config = Map<String, String>.of(app.activeAiConfig);
    final key = app.deeplKey;
    final ai = engine == 'openai' || engine == 'index';
    if (ai &&
        ((config['base'] ?? '').trim().isEmpty ||
            (config['model'] ?? '').trim().isEmpty)) {
      throw StateError(appL10n.workPageTranslateTitlesToast4);
    }
    if (engine == 'deepl' && key.trim().isEmpty) {
      throw StateError(appL10n.workPageTranslateTitlesToast6);
    }
    if (!ai && !const {'google', 'microsoft', 'deepl'}.contains(engine)) {
      throw StateError(appL10n.workPageTranslateTitlesToast2);
    }
    return LyricsTranslationService(
      isAi: ai,
      request: (text) => switch (engine) {
        'google' => apiTranslateGoogle(text: text, src: source, dst: target),
        'microsoft' => apiTranslateMicrosoft(
          text: text,
          src: source,
          dst: target,
        ),
        'deepl' => apiTranslateDeepl(
          text: text,
          src: source,
          dst: target,
          apiKey: key,
        ),
        _ => apiTranslateOpenai(
          baseUrl: config['base']!,
          model: config['model']!,
          apiKey: config['key'] ?? '',
          temperature: 0.2,
          text:
              '[[KIKOETA_TARGET:$target]]\n[[KIKOETA_SOURCE:$source]]\n'
              '[[KIKOETA_LYRICS]]\n$text',
        ),
      },
    );
  }

  final bool isAi;
  final Future<String> Function(String) request;
  final Duration requestGap;

  Future<List<LyricLine>> translate(
    List<LyricLine> source, {
    bool Function()? isCancelled,
    void Function(int completed, int total)? onProgress,
  }) async {
    void checkCancelled() {
      if (isCancelled?.call() ?? false) throw LyricsTranslationCancelled();
    }

    final maxUnits = isAi ? 1600 : 800;
    final maxLines = isAi ? 10 : 8;
    // Keep repeated cues in the result, but translate identical text only once.
    final piecesByCue = <List<String>>[];
    final translations = <String, String>{};
    for (final cue in source) {
      final pieces = <String>[];
      for (final line in cue.jp.replaceAll('\r', '').split('\n')) {
        var piece = StringBuffer();
        var units = 0;
        for (final rune in line.trim().runes) {
          final text = String.fromCharCode(rune);
          if (units + text.length > maxUnits) {
            pieces.add(piece.toString());
            piece = StringBuffer();
            units = 0;
          }
          piece.write(text);
          units += text.length;
        }
        if (piece.isNotEmpty) pieces.add(piece.toString());
      }
      piecesByCue.add(pieces);
      for (final piece in pieces) {
        translations.putIfAbsent(piece, () => '');
      }
    }
    final pending = translations.keys.toList();
    var completed = 0;
    var requested = false;
    onProgress?.call(0, pending.length);

    Future<void> translateBatch(List<String> batch) async {
      checkCancelled();
      if (requested) await Future<void>.delayed(requestGap);
      checkCancelled();
      requested = true;
      final output = await request(batch.join('\n'));
      checkCancelled();
      final lines = output.replaceAll('\r\n', '\n').trim().split('\n');
      if (lines.length != batch.length ||
          lines.any((line) => line.trim().isEmpty)) {
        if (batch.length == 1) {
          throw FormatException(appL10n.lyricsTranslationInvalidResponse);
        }
        // Machine engines may merge lines; AI engines may omit IDs. Splitting
        // reduces ambiguity without ever shifting a translation to another cue.
        final middle = batch.length ~/ 2;
        await translateBatch(batch.sublist(0, middle));
        await translateBatch(batch.sublist(middle));
        return;
      }
      for (var i = 0; i < batch.length; i++) {
        translations[batch[i]] = lines[i].trim();
      }
      completed += batch.length;
      onProgress?.call(completed, pending.length);
    }

    for (var start = 0; start < pending.length;) {
      checkCancelled();
      var end = start;
      var units = 0;
      while (end < pending.length && end - start < maxLines) {
        final size = pending[end].length + (end == start ? 0 : 1);
        if (units + size > maxUnits) break;
        units += size;
        end++;
      }
      await translateBatch(pending.sublist(start, end));
      start = end;
    }
    checkCancelled();
    return [
      for (var i = 0; i < source.length; i++)
        LyricLine(
          source[i].t,
          source[i].jp,
          piecesByCue[i].map((piece) => translations[piece]!).join(' '),
        ),
    ];
  }

  /// LRC stores the translated text; the original library file is untouched.
  static String toLrc(List<LyricLine> lyrics) => lyrics
      .map((cue) {
        final minutes = (cue.t ~/ 60).toString().padLeft(2, '0');
        final seconds = (cue.t % 60).toString().padLeft(2, '0');
        return '[$minutes:$seconds]${cue.zh}';
      })
      .join('\n');
}
