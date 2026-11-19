import 'package:flutter/material.dart';

class MiniPlayerTitles extends StatelessWidget {
  const MiniPlayerTitles({
    super.key,
    required this.playing,
    required this.lyric,
    required this.trackTitle,
    required this.workTitle,
    required this.secondaryColor,
  });

  final bool playing;
  final String? lyric;
  final String trackTitle;
  final String workTitle;
  final Color secondaryColor;

  static const _titleStyle = TextStyle(
    fontSize: 13,
    fontWeight: FontWeight.w600,
  );

  @override
  Widget build(BuildContext context) {
    final defaultStyle = DefaultTextStyle.of(context).style;
    final titleStyle = defaultStyle.merge(_titleStyle);
    final subtitleStyle = defaultStyle.merge(
      TextStyle(fontSize: 11, color: secondaryColor),
    );
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    final line = lyric;
    final showLyric = playing && line != null;
    final lyricLine = _line(
      line == null || line.isEmpty ? '\u200B' : line,
      titleStyle,
    );
    final workLine = _line(workTitle, subtitleStyle);

    return Semantics(
      label: showLyric
          ? [if (line.isNotEmpty) line, trackTitle].join('\n')
          : '$trackTitle\n$workTitle',
      excludeSemantics: true,
      child: ClipRect(
        child: TweenAnimationBuilder<double>(
          key: ValueKey(reduceMotion),
          tween: Tween(end: showLyric ? 1 : 0),
          duration: reduceMotion
              ? Duration.zero
              : const Duration(milliseconds: 240),
          curve: Curves.easeInOut,
          builder: (context, progress, _) => Stack(
            children: [
              Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Opacity(
                    opacity: Curves.easeIn.transform(progress),
                    child: FractionalTranslation(
                      translation: Offset(0, progress - 1),
                      child: lyricLine,
                    ),
                  ),
                  Opacity(
                    opacity: 1 - Curves.easeOut.transform(progress),
                    child: workLine,
                  ),
                ],
              ),
              Positioned.fill(
                child: Align(
                  alignment: AlignmentDirectional(-1, 2 * progress - 1),
                  child: _line(
                    trackTitle,
                    TextStyle.lerp(titleStyle, subtitleStyle, progress)!,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _line(String text, TextStyle style) =>
      Text(text, style: style, maxLines: 1, overflow: TextOverflow.ellipsis);
}
