/// Media-time anchor for one desktop lyric, refreshed by playback events.
class DesktopLyricsTiming {
  const DesktopLyricsTiming({
    required this.start,
    required this.end,
    required this.position,
    required this.playing,
    this.rate = 1,
  });

  final Duration start;
  final Duration? end;
  final Duration position;
  final bool playing;
  final double rate;

  Duration? get duration {
    final end = this.end;
    return end != null && end > start ? end - start : null;
  }

  /// Interpolate between player events; pausing/buffering freezes the anchor.
  Duration elapsedAt(Duration sinceUpdate) {
    final advance = playing
        ? Duration(microseconds: (sinceUpdate.inMicroseconds * rate).round())
        : Duration.zero;
    final elapsed = position + advance - start;
    if (elapsed.isNegative) return Duration.zero;
    final duration = this.duration;
    return duration != null && elapsed > duration ? duration : elapsed;
  }
}
