/// One traversal per lyric: opening hold, linear movement, then a still tail.
/// Like the player's marquee, it measures only the overflowing width; timed
/// lyrics distribute that distance across the available media time.
class DesktopLyricsMarquee {
  static const pause = Duration(seconds: 1);
  static const pixelsPerSecond = 30.0;

  Object? _layoutKey;
  Duration _startedAt = Duration.zero;
  double _textWidth = 0;
  double _viewportWidth = 0;
  double _scale = 1;
  Duration? _lineDuration;

  bool get isActive => _viewportWidth > 0 && _textWidth > _viewportWidth;

  void configure({
    required Object layoutKey,
    required double textWidth,
    required double viewportWidth,
    required Duration now,
    double scale = 1,
    Duration? lineDuration,
  }) {
    _lineDuration = lineDuration;
    if (_layoutKey == layoutKey &&
        _textWidth == textWidth &&
        _viewportWidth == viewportWidth &&
        _scale == scale) {
      return;
    }
    _layoutKey = layoutKey;
    _textWidth = textWidth;
    _viewportWidth = viewportWidth;
    _scale = scale;
    _startedAt = now;
  }

  double offsetAt(Duration now, {Duration? lineElapsed}) {
    if (!isActive) return 0;
    final elapsed = (lineElapsed ?? now - _startedAt).inMicroseconds / 1000000;
    if (elapsed <= 0) return 0;
    final tailOffset = _textWidth - _viewportWidth;
    final duration = _lineDuration;
    final totalSeconds = duration == null || duration <= Duration.zero
        ? null
        : duration.inMicroseconds / 1000000;
    // Very short cues reserve half their time for movement rather than using
    // the entire cue for the two one-second holds.
    final hold = totalSeconds != null && totalSeconds <= 2
        ? totalSeconds / 4
        : pause.inMicroseconds / 1000000;
    final travelSeconds = totalSeconds == null
        ? tailOffset / (pixelsPerSecond * _scale)
        : totalSeconds - hold * 2;
    final progress = ((elapsed - hold) / travelSeconds).clamp(0.0, 1.0);
    return tailOffset * progress;
  }

  void reset() {
    _layoutKey = null;
    _textWidth = 0;
    _viewportWidth = 0;
    _lineDuration = null;
  }
}
