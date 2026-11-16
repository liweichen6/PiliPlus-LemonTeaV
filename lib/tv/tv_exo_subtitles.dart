// Subtitles for ExoPlayer on TV (docs/tv/PLAN.md, M17.8): the WebVTT text
// the app already has, parsed into cues in Dart and looked up by position, so
// upstream's `SubtitleView` and its settings work as they do on mpv.
import 'dart:convert';

/// One cue: text shown from [start] until [end].
class TvExoCue {
  const TvExoCue(this.start, this.end, this.text);

  final Duration start;
  final Duration end;
  final String text;

  @override
  String toString() => 'TvExoCue($start, $end, $text)';
}

/// Cues sorted by start, with a lookup by position.
class TvExoCues {
  TvExoCues._(this.cues) : _maxLength = _longest(cues);

  static final TvExoCues empty = TvExoCues._(const <TvExoCue>[]);

  /// Parses WebVTT. Also takes SRT-style comma decimals and cues without a
  /// `WEBVTT` header. Skips `NOTE`, `STYLE` and `REGION` blocks, cue ids and
  /// cue settings; strips tags (`<b>`, `<c.x>`, `<v Name>`, timestamps) and
  /// decodes the common entities. A cue whose end is not after its start is
  /// dropped.
  factory TvExoCues.parse(String text) {
    final lines = const LineSplitter().convert(
      text.startsWith('﻿') ? text.substring(1) : text,
    );
    final cues = <TvExoCue>[];
    var i = 0;
    while (i < lines.length) {
      final line = lines[i].trim();
      if (line.isEmpty) {
        i++;
        continue;
      }
      if (line.startsWith('NOTE') ||
          line.startsWith('STYLE') ||
          line.startsWith('REGION') ||
          line.startsWith('WEBVTT')) {
        // A block runs to the next blank line.
        while (i < lines.length && lines[i].trim().isNotEmpty) {
          i++;
        }
        continue;
      }
      // An optional cue id, then the timing line.
      var timing = _timing.firstMatch(line);
      if (timing == null && i + 1 < lines.length) {
        timing = _timing.firstMatch(lines[i + 1].trim());
        if (timing != null) i++;
      }
      if (timing == null) {
        // Not a cue: skip the block.
        while (i < lines.length && lines[i].trim().isNotEmpty) {
          i++;
        }
        continue;
      }
      i++;
      final body = <String>[];
      while (i < lines.length && lines[i].trim().isNotEmpty) {
        // A timing line with no blank line before it starts the next cue.
        if (_timing.hasMatch(lines[i])) break;
        body.add(lines[i]);
        i++;
      }
      final start = _at(timing, 1);
      final end = _at(timing, 5);
      if (end <= start) continue;
      final cueText = _clean(body.join('\n'));
      if (cueText.isEmpty) continue;
      cues.add(TvExoCue(start, end, cueText));
    }
    // A stable sort: cues that start together keep the file's order.
    final indexed = cues.indexed.toList()
      ..sort((a, b) {
        final c = a.$2.start.compareTo(b.$2.start);
        return c != 0 ? c : a.$1.compareTo(b.$1);
      });
    return TvExoCues._(List.unmodifiable(indexed.map((e) => e.$2)));
  }

  final List<TvExoCue> cues;

  /// The longest cue, which bounds how far back a lookup has to look.
  final Duration _maxLength;

  bool get isEmpty => cues.isEmpty;

  /// The text at [position]: every cue showing then, in start order, one per
  /// line. Empty when none is.
  String textAt(Duration position) {
    if (cues.isEmpty) return '';
    // The first cue that starts after [position].
    var lo = 0, hi = cues.length;
    while (lo < hi) {
      final mid = (lo + hi) >> 1;
      if (cues[mid].start <= position) {
        lo = mid + 1;
      } else {
        hi = mid;
      }
    }
    final showing = <String>[];
    final earliest = position - _maxLength;
    for (var i = lo - 1; i >= 0 && cues[i].start >= earliest; i--) {
      final cue = cues[i];
      if (position < cue.end) showing.add(cue.text);
    }
    return showing.reversed.join('\n');
  }

  static Duration _longest(List<TvExoCue> cues) {
    var longest = Duration.zero;
    for (final cue in cues) {
      final length = cue.end - cue.start;
      if (length > longest) longest = length;
    }
    return longest;
  }

  // `hh:mm:ss.mmm`, `mm:ss.mmm` or a comma for the dot, then the settings.
  static final RegExp _timing = RegExp(
    r'^\s*(?:(\d+):)?(\d{1,2}):(\d{1,2})[.,](\d{1,3})\s*-->\s*'
    r'(?:(\d+):)?(\d{1,2}):(\d{1,2})[.,](\d{1,3})',
  );

  static Duration _at(RegExpMatch m, int group) {
    final fraction = m.group(group + 3)!;
    return Duration(
      hours: int.parse(m.group(group) ?? '0'),
      minutes: int.parse(m.group(group + 1)!),
      seconds: int.parse(m.group(group + 2)!),
      milliseconds: int.parse(fraction.padRight(3, '0')),
    );
  }

  static final RegExp _tag = RegExp(r'<[^>]*>');

  static String _clean(String text) => text
      .replaceAll(_tag, '')
      .replaceAll('&lt;', '<')
      .replaceAll('&gt;', '>')
      .replaceAll('&nbsp;', ' ')
      .replaceAll('&lrm;', '')
      .replaceAll('&rlm;', '')
      .replaceAll('&amp;', '&')
      .trim();
}
