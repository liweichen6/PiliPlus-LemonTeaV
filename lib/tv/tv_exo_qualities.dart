// The quality list on ExoPlayer (docs/tv/PLAN.md, M17.9; M17.6, decision 9):
// a video's streams are checked against what the TV's decoders declare and
// what its display reports, before upstream picks a quality. A stream that
// can't play is taken out of the response, so upstream's own rules fall back
// to the next quality that can, its quality list greys the row (as it does
// for a quality the account can't have), and 解码格式 doesn't offer the
// codec.
//
// `M17.10` says why: each refused stream keeps its reason
// ([TvExoQualityReport], from the bridge's `supports` and the display), the
// row's name carries it ("4K 超高清（HEVC 5.2 超出解码器 5.1）"), a quality
// where only some codecs play says which ("（仅 AVC）"), and when the saved
// quality or codec can't play, a toast at open says what the app used
// instead.
//
// The bridge's `supports` applies the renderer's own rule
// (`TvExoRules.videoFormatSupport`, M17.7), so what the list offers is what
// track selection accepts.
import 'package:PiliPlus/models/common/video/base_quality.dart';
import 'package:PiliPlus/models/common/video/video_decode_type.dart';
import 'package:PiliPlus/models/video/play/url.dart';
import 'package:PiliPlus/tv/tv_exo_player.dart';
import 'package:PiliPlus/tv/tv_exo_support.dart';
import 'package:PiliPlus/tv/tv_platform.dart';
import 'package:PiliPlus/utils/video_utils.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_smart_dialog/flutter_smart_dialog.dart';

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

  /// Appended to a quality's name when none of its streams can play here
  /// and the bridge gave no reason.
  static const String unsupportedSuffix = '（此设备不支持）';

  /// Appended to 杜比视界 when it plays as its HLG base layer (Profile 8.4
  /// with no Dolby Vision decoder for it).
  static const String hlgSuffix = '（HLG）';

  /// 仍要尝试 on a greyed row (M17.10, item 5). On since the guarded run on
  /// `<physical-tv>` (2026-11-16): HEVC 5.2 at 4K120, AV1 and HEVC at 8K
  /// each failed cleanly in the decoder within 5 s, with nothing worse. A
  /// build can turn it off with `--dart-define=TV_EXO_TRY_ANYWAY=false`.
  static const bool tryAnywayEnabled = bool.fromEnvironment(
    'TV_EXO_TRY_ANYWAY',
    defaultValue: true,
  );

  static Set<int>? _displayHdr;

  static final Expando<TvExoQualityReport> _reports = Expando(
    'TvExoQualityReport',
  );

  /// What [apply] found for [data]: every stream as served, with its answer.
  static TvExoQualityReport? reportOf(PlayUrlModel? data) =>
      data == null ? null : _reports[data];

  /// The hook in the video page's `_queryVideoUrl`, after the response and
  /// its supplement are in: [apply] with the bridge's answers on TV, where
  /// every player is ExoPlayer; nothing elsewhere. With [preferQuality] and
  /// [preferCodecs] (the saved quality and codec order), a toast says so
  /// when what they'd pick can't play here and the app picks another.
  static Future<void> onTv(
    PlayUrlModel data, {
    int? preferQuality,
    List<VideoDecodeFormatType> preferCodecs = const [],
  }) async {
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
      final served = preferQuality == null
          ? null
          : _pick(data, preferQuality, preferCodecs);
      final removed = apply(
        data,
        support,
        _displayHdr!,
        preferCodecs: preferCodecs,
      );
      if (removed.isNotEmpty) {
        debugPrint('[TvExoQualities] not offered: ${removed.join(', ')}');
        if (served != null) {
          final text = fallbackText(
            data,
            served,
            _pick(data, preferQuality!, preferCodecs),
          );
          if (text != null) SmartDialog.showToast(text);
        }
      }
    } on PlatformException catch (e) {
      // The list stays as served; track selection still refuses a stream
      // its decoder can't take, and the failure screen says why.
      debugPrint('[TvExoQualities] supports failed: ${e.message}');
    } on MissingPluginException {
      // No bridge (tests).
    }
  }

  /// What upstream's `findTargetVideo` picks from [data] as it stands.
  static VideoItem? _pick(
    PlayUrlModel data,
    int preferQuality,
    List<VideoDecodeFormatType> preferCodecs,
  ) {
    final videos = data.dash?.video;
    final formats = data.supportFormats;
    if (videos == null || videos.isEmpty || formats == null) return null;
    try {
      // Copies, since [apply] changes the formats' codec lists afterwards.
      final (_, _, _, video) = VideoUtils.findTargetVideo(
        List.of(videos),
        preferQuality,
        data.acceptQuality == null ? null : List.of(data.acceptQuality!),
        [
          for (final f in formats)
            FormatItem(
              quality: f.quality,
              format: f.format,
              newDesc: f.newDesc,
              displayDesc: f.displayDesc,
              codecs: f.codecs == null ? null : List.of(f.codecs!),
            ),
        ],
        preferCodecs,
      );
      return video;
    } catch (_) {
      return null;
    }
  }

  /// The toast at open when the saved quality or codec ([served], what
  /// upstream would have picked from the list as served) can't play here
  /// and [picked] plays instead: "4K 超高清 HEVC：HEVC 5.2 超出解码器 5.1，
  /// 本次使用 4K 超高清 AVC". `null` when nothing changed.
  @visibleForTesting
  static String? fallbackText(
    PlayUrlModel data,
    VideoItem served,
    VideoItem? picked,
  ) {
    if (picked == null || identical(served, picked)) return null;
    final report = reportOf(data);
    final refusal = report?.streamOf(served)?.refusal;
    if (refusal == null) return null;
    final from =
        '${report!.nameOf(served.id)} ${TvExoCodec.name(served.codecs)}';
    final to = '${report.nameOf(picked.id)} ${TvExoCodec.name(picked.codecs)}';
    return '$from：${refusal.short}，本次使用 $to';
  }

  /// Whether a stream with the bridge's answer [support] plays here, for a
  /// display reporting [displayHdr].
  @visibleForTesting
  static bool playable(int quality, String support, Set<int> displayHdr) =>
      displayRefusal(quality, support, displayHdr) == null && support != 'no';

  /// The HDR type the display would have to report for this stream, when
  /// it doesn't: `杜比视界`, `HLG` or `HDR10`; `null` when it does or none is
  /// needed.
  @visibleForTesting
  static String? displayRefusal(
    int quality,
    String support,
    Set<int> displayHdr,
  ) => switch (support) {
    'dolbyVision' when !displayHdr.contains(displayDolbyVision) => '杜比视界',
    'baseLayer' when !displayHdr.contains(displayHlg) => 'HLG',
    'yes'
        when (quality == hdr || quality == hdrVivid) &&
            !displayHdr.contains(displayHdr10) &&
            !displayHdr.contains(displayHlg) &&
            !displayHdr.contains(displayHdr10Plus) =>
      'HDR10',
    _ => null,
  };

  /// Takes the streams that can't play out of [data], one answer in
  /// [support] per `dash.video` entry, in order (the bridge's maps, or bare
  /// `yes` / `no` strings). Returns what was taken out, as `quality codecs`
  /// strings, and keeps every stream's answer in [reportOf]. If nothing would
  /// be left, [data] is kept as served, so the open fails on the failure
  /// screen with the reason.
  @visibleForTesting
  static List<String> apply(
    PlayUrlModel data,
    List<Object?> support,
    Set<int> displayHdr, {
    List<VideoDecodeFormatType> preferCodecs = const [],
  }) {
    final videos = data.dash?.video;
    if (videos == null || videos.length != support.length) return const [];
    final names = <int, String>{};
    for (final f in data.supportFormats ?? const <FormatItem>[]) {
      final q = f.quality;
      if (q != null) {
        names[q] = f.newDesc ?? f.displayDesc ?? VideoQuality.fromCode(q).desc;
      }
    }
    final streams = <TvExoStreamReport>[];
    for (final (i, v) in videos.indexed) {
      final stream = TvExoStream(
        codecs: v.codecs,
        width: v.width,
        height: v.height,
        frameRate: double.tryParse(v.frameRate ?? ''),
      );
      var answer = TvExoSupport.parse(support[i], stream);
      if (displayRefusal(v.id, answer.support, displayHdr) case final need?) {
        answer = TvExoSupport(
          'no',
          decoder: answer.decoder,
          refusal: TvExoRefusal.display(stream, need),
        );
      }
      streams.add(TvExoStreamReport(v, stream, answer));
    }
    final keep = [
      for (final s in streams)
        if (s.playable) s.video,
    ];
    final drop = [
      for (final s in streams)
        if (!s.playable) s.video,
    ];
    final report = TvExoQualityReport._(streams, names, preferCodecs);
    _reports[data] = report;
    if (keep.isEmpty) return const [];
    // Suffixes even when nothing is dropped: 杜比视界 on its HLG base layer
    // (M17.11 review).
    for (final f in data.supportFormats ?? const <FormatItem>[]) {
      final q = f.quality;
      if (q == null) continue;
      f.codecs?.removeWhere(
        (c) => drop.any((v) => v.id == q && v.codecs == c),
      );
      final suffix = report.suffixOf(q);
      if (suffix.isNotEmpty) f.newDesc = '${f.newDesc ?? q}$suffix';
    }
    if (drop.isEmpty) return const [];
    videos
      ..clear()
      ..addAll(keep);
    final kept = {for (final v in keep) v.id};
    final gone = {for (final v in drop) v.id}.difference(kept);
    data.acceptQuality?.removeWhere(gone.contains);
    return [for (final v in drop) '${v.id} ${v.codecs}'];
  }

  /// 仍要尝试: puts a refused [stream] back into [data] for one try, so
  /// upstream's `updatePlayer` can pick it; the caller sets
  /// [TvExoPlayer.tryAnywayNext]. Returns whether it's there.
  static bool restore(PlayUrlModel data, VideoItem stream) {
    final videos = data.dash?.video;
    if (videos == null) return false;
    if (!videos.contains(stream)) {
      final at = videos.indexWhere((v) => v.id < stream.id);
      videos.insert(at == -1 ? videos.length : at, stream);
    }
    final accept = data.acceptQuality;
    if (accept != null && !accept.contains(stream.id)) {
      final at = accept.indexWhere((q) => q < stream.id);
      accept.insert(at == -1 ? accept.length : at, stream.id);
    }
    for (final f in data.supportFormats ?? const <FormatItem>[]) {
      if (f.quality == stream.id && f.codecs != null) {
        if (!f.codecs!.contains(stream.codecs)) f.codecs!.add(stream.codecs!);
      }
    }
    return true;
  }
}

/// One served stream and the bridge's answer for it.
class TvExoStreamReport {
  TvExoStreamReport(this.video, this.stream, this.answer);

  final VideoItem video;
  final TvExoStream stream;
  final TvExoSupport answer;

  TvExoRefusal? get refusal => answer.refusal;

  bool get playable => answer.refusal == null;

  /// Plays as its HLG base layer (Dolby Vision Profile 8.4).
  bool get baseLayer => answer.support == 'baseLayer';
}

/// Every stream of a video as served, with what the bridge and the display
/// said about it (M17.10).
class TvExoQualityReport {
  TvExoQualityReport._(this.streams, this._names, this._preferCodecs);

  final List<TvExoStreamReport> streams;
  final Map<int, String> _names;
  final List<VideoDecodeFormatType> _preferCodecs;

  /// The quality's name as served, without this file's suffixes.
  String nameOf(int quality) =>
      _names[quality] ?? VideoQuality.fromCode(quality).desc;

  TvExoStreamReport? streamOf(VideoItem video) =>
      streams.firstWhereOrNull((s) => identical(s.video, video)) ??
      streams.firstWhereOrNull(
        (s) => s.video.id == video.id && s.video.codecs == video.codecs,
      );

  List<TvExoStreamReport> of(int quality) => [
    for (final s in streams)
      if (s.video.id == quality) s,
  ];

  /// The quality's streams that can't play, the preferred codec first.
  List<TvExoStreamReport> refusedOf(
    int quality, [
    List<VideoDecodeFormatType> preferCodecs = const [],
  ]) {
    final refused = [
      for (final s in of(quality))
        if (!s.playable) s,
    ];
    int rank(TvExoStreamReport s) {
      final i = preferCodecs.indexWhere(
        (t) => t.codes.any((c) => s.video.codecs?.startsWith(c) ?? false),
      );
      return i == -1 ? preferCodecs.length : i;
    }

    refused.sort((a, b) => rank(a).compareTo(rank(b)));
    return refused;
  }

  /// Whether none of the quality's streams can play.
  bool refused(int quality) {
    final all = of(quality);
    return all.isNotEmpty && all.every((s) => !s.playable);
  }

  /// What the quality's name gets: the reason when nothing plays, the codecs
  /// that do when only some play, `（HLG）` for 杜比视界 on its base layer.
  String suffixOf(int quality) {
    final all = of(quality);
    if (all.isEmpty) return '';
    final playing = [
      for (final s in all)
        if (s.playable) s,
    ];
    if (playing.isEmpty) {
      // The codec the 画质 list's detail lines put first.
      final r = refusedOf(quality, _preferCodecs).first.refusal;
      return r == null || r.kind == 'unknown' && r.decoder == null
          ? TvExoQualities.unsupportedSuffix
          : '（${r.short}）';
    }
    if (quality == TvExoQualities.dolbyVision &&
        playing.every((s) => s.baseLayer)) {
      return TvExoQualities.hlgSuffix;
    }
    if (playing.length < all.length) {
      String family(TvExoStreamReport s) => TvExoCodec.name(s.video.codecs);
      final names = {for (final s in playing) family(s)};
      // Two streams of one codec (Dolby Vision Profile 8 and 5): by profile.
      final byProfile = names.length == {for (final s in all) family(s)}.length;
      final shown = byProfile
          ? {for (final s in playing) TvExoCodec.profileLevel(s.video.codecs)}
          : names;
      return '（仅 ${shown.join('、')}）';
    }
    return '';
  }
}

extension<T> on List<T> {
  T? firstWhereOrNull(bool Function(T) test) {
    for (final e in this) {
      if (test(e)) return e;
    }
    return null;
  }
}
