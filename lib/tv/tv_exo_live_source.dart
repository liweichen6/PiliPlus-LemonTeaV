// The live source rule for ExoPlayer on TV (docs/tv/PLAN.md, M17.7 and
// M17.8): Media3 1.11.1 can't read FLV with HEVC (its FLV reader takes only
// codec ID 7, and Bilibili's HEVC FLV is ID 12), so such a stream plays as
// HLS fMP4 with HEVC at the same quality instead (the user, 2026-11-15).
//
// Pure, so `M17.11` tests it; `M17.9`'s hook in the live room's
// `initLiveUrl` calls [TvExoLiveSource.onTv] before the URL is built.
import 'package:PiliPlus/models_new/live/live_room_play_info/codec.dart';
import 'package:PiliPlus/models_new/live/live_room_play_info/stream.dart';
import 'package:PiliPlus/tv/tv_platform.dart';

/// Indices into a live room's `stream` list: protocol, format and codec, as
/// upstream's `initLiveUrl` takes them.
typedef TvExoLiveChoice = ({int stream, int format, int codec});

abstract final class TvExoLiveSource {
  static const String flv = 'flv';
  static const String fmp4 = 'fmp4';
  static const String hls = 'http_hls';
  static const String hevc = 'hevc';

  /// The hook in `initLiveUrl`: [resolve] on TV, where every player is
  /// ExoPlayer; `null` elsewhere, so mpv keeps upstream's choice.
  static TvExoLiveChoice? onTv(
    List<Stream> streams,
    TvExoLiveChoice choice,
  ) => TvPlatform.isTv ? resolve(streams, choice) : null;

  /// Whether Media3 can't read this stream: FLV with HEVC.
  static bool unreadable(String? formatName, String? codecName) =>
      formatName == flv && codecName == hevc;

  /// The choice to open for [choice]. Unchanged unless it is FLV with HEVC;
  /// then HLS fMP4 with HEVC, preferring the same quality as the FLV stream
  /// served. `null` when the server offers no HLS fMP4 HEVC stream, so the
  /// caller keeps its own choice and the adapter's failure screen says why.
  ///
  /// An index out of range means the first entry, as `getOrFirst` reads it.
  static TvExoLiveChoice? resolve(
    List<Stream> streams,
    TvExoLiveChoice choice,
  ) {
    if (streams.isEmpty) return null;
    final s = _index(streams.length, choice.stream);
    final formats = streams[s].format;
    if (formats.isEmpty) return null;
    final f = _index(formats.length, choice.format);
    final codecs = formats[f].codec;
    if (codecs.isEmpty) return null;
    final c = _index(codecs.length, choice.codec);
    final picked = codecs[c];
    if (!unreadable(formats[f].formatName, picked.codecName)) {
      return (stream: s, format: f, codec: c);
    }
    TvExoLiveChoice? any;
    for (final (i, stream) in streams.indexed) {
      if (stream.protocolName != hls) continue;
      for (final (j, format) in stream.format.indexed) {
        if (format.formatName != fmp4) continue;
        for (final (k, codec) in format.codec.indexed) {
          if (codec.codecName != hevc) continue;
          if (_sameQuality(codec, picked)) {
            return (stream: i, format: j, codec: k);
          }
          any ??= (stream: i, format: j, codec: k);
        }
      }
    }
    return any;
  }

  static int _index(int length, int index) =>
      index < 0 || index >= length ? 0 : index;

  static bool _sameQuality(CodecItem a, CodecItem b) =>
      a.currentQn.code == b.currentQn.code;
}
