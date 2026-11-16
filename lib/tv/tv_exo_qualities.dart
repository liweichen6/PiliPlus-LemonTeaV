// The quality list on ExoPlayer (docs/tv/PLAN.md, M17.9; M17.6, decision 9):
// a video's streams are checked against what the TV's decoders declare and
// what its display reports, before upstream picks a quality. A stream that
// can't play is taken out of the response, so upstream's own rules fall back
// to the next quality that can, its quality list greys the row (as it does
// for a quality the account can't have) with the reason in its name, and
// 解码格式 doesn't offer the codec.
//
// The bridge's `supports` applies the renderer's own rule
// (`TvExoRules.videoFormatSupport`, M17.7), so what the list offers is what
// track selection accepts.
import 'package:PiliPlus/models/video/play/url.dart';
import 'package:PiliPlus/tv/tv_exo_player.dart';
import 'package:PiliPlus/tv/tv_platform.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

abstract final class TvExoQualities {
  // Bilibili's quality codes.
  static const int hdr = 125;
  static const int dolbyVision = 126;
  static const int hdrVivid = 129;

  // `Display.HdrCapabilities`' HDR types.
  static const int displayDolbyVision = 1;
  static const int displayHdr10 = 2;
  static const int displayHlg = 3;
  static const int displayHdr10Plus = 4;

  /// Appended to a quality's name when no stream of it can play here.
  static const String unsupportedSuffix = '（此设备不支持）';

  /// Appended to 杜比视界 when it plays as its HLG base layer (Profile 8.4
  /// with no Dolby Vision decoder for it).
  static const String hlgSuffix = '（HLG）';

  static Set<int>? _displayHdr;

  /// The hook in the video page's `_queryVideoUrl`, after the response and
  /// its supplement are in: [apply] with the bridge's answers on TV, where
  /// every player is ExoPlayer; nothing elsewhere.
  static Future<void> onTv(PlayUrlModel data) async {
    if (!TvPlatform.isTv) return;
    final videos = data.dash?.video;
    if (videos == null || videos.isEmpty) return;
    try {
      final support =
          await TvExoPlayer.channel.invokeMethod<List>('supports', [
            for (final v in videos)
              <String, Object?>{
                'codecs': v.codecs,
                'width': v.width,
                'height': v.height,
                'frameRate': double.tryParse(v.frameRate ?? ''),
              },
          ]) ??
          const [];
      _displayHdr ??= {
        ...?(await TvExoPlayer.channel.invokeMethod<List>(
          'displayHdr',
        ))?.whereType<int>(),
      };
      final removed = apply(
        data,
        [for (final s in support) s.toString()],
        _displayHdr!,
      );
      if (removed.isNotEmpty) {
        debugPrint('[TvExoQualities] not offered: ${removed.join(', ')}');
      }
    } on PlatformException catch (e) {
      // The list stays as served; track selection still refuses a stream
      // its decoder can't take, and the failure screen says why.
      debugPrint('[TvExoQualities] supports failed: ${e.message}');
    }
  }

  /// Whether a stream with the bridge's answer [support] plays here, for a
  /// display reporting [displayHdr].
  @visibleForTesting
  static bool playable(int quality, String support, Set<int> displayHdr) =>
      switch (support) {
        'dolbyVision' => displayHdr.contains(displayDolbyVision),
        'baseLayer' => displayHdr.contains(displayHlg),
        'yes' when quality == hdr || quality == hdrVivid =>
          displayHdr.contains(displayHdr10) ||
              displayHdr.contains(displayHlg) ||
              displayHdr.contains(displayHdr10Plus),
        'yes' => true,
        _ => false,
      };

  /// Takes the streams that can't play out of [data], one answer in
  /// [support] per `dash.video` entry, in order. Returns what was taken out,
  /// as `quality codecs` strings. If nothing would be left, [data] is kept as
  /// served, so the open fails on the failure screen with the reason.
  @visibleForTesting
  static List<String> apply(
    PlayUrlModel data,
    List<String> support,
    Set<int> displayHdr,
  ) {
    final videos = data.dash?.video;
    if (videos == null || videos.length != support.length) return const [];
    final keep = <VideoItem>[];
    final drop = <VideoItem>[];
    final baseLayerOnly = <int, bool>{};
    for (final (i, v) in videos.indexed) {
      if (playable(v.id, support[i], displayHdr)) {
        keep.add(v);
        baseLayerOnly[v.id] =
            (baseLayerOnly[v.id] ?? true) && support[i] == 'baseLayer';
      } else {
        drop.add(v);
      }
    }
    if (drop.isEmpty || keep.isEmpty) return const [];
    videos
      ..clear()
      ..addAll(keep);
    final kept = {for (final v in keep) v.id};
    final gone = {for (final v in drop) v.id}.difference(kept);
    data.acceptQuality?.removeWhere(gone.contains);
    for (final f in data.supportFormats ?? const <FormatItem>[]) {
      final q = f.quality;
      if (q == null) continue;
      f.codecs?.removeWhere(
        (c) => drop.any((v) => v.id == q && v.codecs == c),
      );
      if (gone.contains(q)) {
        f.newDesc = '${f.newDesc ?? q}$unsupportedSuffix';
      } else if (q == dolbyVision && baseLayerOnly[q] == true) {
        f.newDesc = '${f.newDesc ?? q}$hlgSuffix';
      }
    }
    return [for (final v in drop) '${v.id} ${v.codecs}'];
  }
}
