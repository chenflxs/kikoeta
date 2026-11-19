import '../data.dart';
import '../l10n/strings.dart';
import 'translation_service.dart';

class LyricsTranslationCancelled implements Exception {}

/// Bounded, sequential batches. Only text crosses the translation boundary;
/// timestamps and cue positions stay local.
class LyricsTranslationService {
  LyricsTranslationService({
    required this.isAi,
    required this.targetLanguage,
    required this.request,
    this.requestGap = const Duration(milliseconds: 350),
  });

  factory LyricsTranslationService.fromApp(
    AppState app, {
    void Function(TranslationFallback)? onFallback,
  }) {
    final translator = TranslationService.fromApp(app, onFallback: onFallback);
    if (translator.configurationError(appL10n) case final error?) {
      throw StateError(error);
    }
    return LyricsTranslationService(
      isAi: translator.isAi,
      targetLanguage: translator.targetLanguage,
      request: (text, {isCurrent}) =>
          translator.translate(text, lyrics: true, isCurrent: isCurrent),
    );
  }

  final bool isAi;
  final String targetLanguage;
  final Future<String> Function(String, {bool Function()? isCurrent}) request;
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
    // The traditional endpoints accept one text, so a response newline is
    // not a reliable boundary between cues. Send each unique piece separately.
    final maxLines = isAi ? 10 : 1;
    // Keep repeated cues in the result, but translate identical text only once.
    final piecesByCue = <List<String>>[];
    final translations = <String, String>{};
    for (final cue in source) {
      final pieces = <String>[];
      for (final line in cue.jp.split(RegExp(r'\r\n?|\n'))) {
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
      final output = await request(
        batch.join('\n'),
        isCurrent: () => !(isCancelled?.call() ?? false),
      );
      checkCancelled();
      final lines = isAi
          ? output.replaceAll('\r\n', '\n').trim().split('\n')
          : [output.replaceAll(RegExp(r'\s*[\r\n]+\s*'), ' ').trim()];
      if (lines.length != batch.length ||
          lines.any((line) => line.trim().isEmpty)) {
        if (batch.length == 1) {
          throw FormatException(appL10n.lyricsTranslationInvalidResponse);
        }
        // Retry ambiguous AI batches with smaller groups.
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
          source[i].timeMs,
          source[i].jp,
          piecesByCue[i].map((piece) => translations[piece]!).join(' '),
        ),
    ];
  }

  /// LRC stores the translated text; the original library file is untouched.
  static String toLrc(List<LyricLine> lyrics) => lyrics
      .map((cue) {
        final wholeSeconds = cue.timeMs ~/ 1000;
        final minutes = (wholeSeconds ~/ 60).toString().padLeft(2, '0');
        final seconds = (wholeSeconds % 60).toString().padLeft(2, '0');
        final millis = (cue.timeMs % 1000).toString().padLeft(3, '0');
        return '[$minutes:$seconds.$millis]${cue.zh}';
      })
      .join('\n');
}
