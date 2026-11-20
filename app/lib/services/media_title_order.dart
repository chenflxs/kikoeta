import 'package:unorm_dart/unorm_dart.dart' as unorm;

enum MediaTitleOrderVersion { original, chapters, current }

/// Shared title ordering for media trees and the restored playback queue.
abstract final class MediaTitleOrder {
  static List<String> parts(
    String title, {
    MediaTitleOrderVersion version = MediaTitleOrderVersion.current,
  }) {
    final sortTitle = switch (version) {
      MediaTitleOrderVersion.original => title.toLowerCase(),
      MediaTitleOrderVersion.chapters => _legacyChapterSortTitle(
        title.toLowerCase(),
      ),
      MediaTitleOrderVersion.current => _mediaSortTitle(title),
    };
    return [
      for (final match in _mediaTitleParts.allMatches(sortTitle))
        if (version == MediaTitleOrderVersion.current)
          match[0]!.replaceFirst(_leadingZeroes, '')
        else
          match[0]!,
    ];
  }

  static int compare(
    List<String> a,
    List<String> b, {
    MediaTitleOrderVersion version = MediaTitleOrderVersion.current,
  }) {
    final n = a.length < b.length ? a.length : b.length;
    for (var i = 0; i < n; i++) {
      final x = a[i];
      final y = b[i];
      if (_startsWithDigit(x) && _startsWithDigit(y)) {
        if (version == MediaTitleOrderVersion.current) {
          // Parts have no leading zeroes, so length gives the magnitude.
          final byLength = x.length.compareTo(y.length);
          if (byLength != 0) return byLength;
        } else {
          final xd = int.tryParse(x);
          final yd = int.tryParse(y);
          if (xd != null && yd != null) {
            if (xd != yd) return xd.compareTo(yd);
            continue;
          }
        }
      }
      final byText = x.compareTo(y);
      if (byText != 0) return byText;
    }
    return a.length.compareTo(b.length);
  }

  static bool _startsWithDigit(String part) {
    final first = part.codeUnitAt(0);
    return first >= 0x30 && first <= 0x39;
  }

  static final _mediaTitleParts = RegExp(r'\d+|\D+');
  static final _leadingZeroes = RegExp(r'^0+(?=\d)');
  static final _nonAscii = RegExp(r'[^\x00-\x7F]');
  static final _circledNumberBeforeNumber = RegExp(
    r'[\u2460-\u2473\u24EA\u3251-\u325F\u32B1-\u32BF](?=\p{N})',
    unicode: true,
  );
  static final _trackNumber = RegExp(
    r'^\s*(?:(tr(?:ack)?|トラック|音[轨軌])[\s._-]*)?'
    r'(?:\((\d+)\)|\[(\d+)\]|(\d+)(?=(?:[a-z])?(?:$|[^a-z0-9⁄])))',
  );
  static const _hanChapter = r'[〇零一二两兩三四五六七八九十百千]{1,7}';
  static const _chapterUnit = r'[篇章节節话話集回卷巻部轨軌]';
  static final _legacyChapterPrefix = RegExp(
    r'^(\s*第)('
    '$_hanChapter'
    r')(?=\s*'
    '$_chapterUnit)',
  );
  static final _chapterPrefix = RegExp(
    r'^\s*第\s*(\d+|'
    '$_hanChapter'
    r')\s*(?='
    '$_chapterUnit)',
  );
  static const _hanUnitValues = {'十': 10, '百': 100, '千': 1000};

  static String _mediaSortTitle(String title) {
    // Use Unicode compatibility forms for the sort key only.
    var folded = title;
    if (_nonAscii.hasMatch(title)) {
      // Keep ①2 as two numbers when the circle disappears.
      final separated = title.replaceAllMapped(
        _circledNumberBeforeNumber,
        (match) => '${match[0]} ',
      );
      folded = unorm.nfkc(separated);
    }
    folded = folded.toLowerCase();
    final track = _trackNumber.matchAsPrefix(folded);
    if (track != null) {
      final label = track[1] == null ? '' : 'track';
      final number = track[2] ?? track[3] ?? track[4]!;
      final suffix = folded.substring(track.end);
      final separator = suffix.isNotEmpty && _startsWithDigit(suffix)
          ? ' '
          : '';
      return '$label$number$separator$suffix';
    }
    final chapter = _chapterPrefix.matchAsPrefix(folded);
    if (chapter != null) {
      final ordinal = chapter[1]!;
      final number = _startsWithDigit(ordinal)
          ? ordinal
          : _hanChapterNumber(ordinal)?.toString();
      if (number != null) return '第$number${folded.substring(chapter.end)}';
    }
    return folded;
  }

  static String _legacyChapterSortTitle(String title) {
    return title.replaceFirstMapped(_legacyChapterPrefix, (match) {
      final number = _hanChapterNumber(match.group(2)!);
      return number == null ? match.group(0)! : '${match.group(1)}$number';
    });
  }

  static int? _hanChapterNumber(String text) {
    var number = 0;
    var lastUnit = 10000;
    var digits = 0;
    for (final character in text.split('')) {
      final unit = _hanUnitValues[character];
      if (unit == null) {
        final digit = switch (character) {
          '零' => 0,
          '两' || '兩' => 2,
          _ => '〇一二三四五六七八九'.indexOf(character),
        };
        digits = digits * 10 + digit;
      } else {
        // Unit notation is descending, e.g. 一百零二 or 十二.
        if (unit >= lastUnit || digits > 9) return null;
        if (digits == 0 && (unit != 10 || number != 0)) return null;
        number += (digits == 0 ? 1 : digits) * unit;
        lastUnit = unit;
        digits = 0;
      }
    }
    if (lastUnit != 10000 && digits > 9) return null;
    return number + digits;
  }
}
