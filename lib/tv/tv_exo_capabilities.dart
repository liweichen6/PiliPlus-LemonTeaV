// 解码能力 (docs/tv/PLAN.md, M17.10, the user's request on 2026-11-16): what
// this TV's decoders and display declare, as ExoPlayer reads them, so a
// quality the app refuses can be checked against the whole picture. Read
// from the bridge's `capabilities`; reached from 音视频设置 on TV only.
import 'package:PiliPlus/common/widgets/scaffold/simple_scaffold.dart';
import 'package:PiliPlus/tv/tv_exo_player.dart';
import 'package:PiliPlus/tv/tv_exo_support.dart';
import 'package:PiliPlus/utils/utils.dart';
import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';

/// One video decoder and what it declares.
@immutable
class TvExoVideoDecoder {
  const TvExoVideoDecoder({
    required this.name,
    required this.mime,
    required this.hardware,
    this.maxWidth,
    this.maxHeight,
    this.profiles = const [],
    this.fps1080,
    this.fps2160,
    this.fps4320,
  });

  factory TvExoVideoDecoder.fromMap(Map m) => TvExoVideoDecoder(
    name: '${m['name']}',
    mime: '${m['mime']}',
    hardware: m['hardware'] == true,
    maxWidth: _int(m['maxWidth']),
    maxHeight: _int(m['maxHeight']),
    profiles: [
      for (final p in (m['profiles'] as List?) ?? const [])
        if (p case [final num profile, final num level])
          (profile.toInt(), level.toInt()),
    ],
    fps1080: _int(m['fps1080']),
    fps2160: _int(m['fps2160']),
    fps4320: _int(m['fps4320']),
  );

  final String name;
  final String mime;
  final bool hardware;
  final int? maxWidth;
  final int? maxHeight;

  /// Android's profile and the highest level declared for it.
  final List<(int, int)> profiles;
  final int? fps1080;
  final int? fps2160;
  final int? fps4320;

  String get _codecs => TvExoCodec.codecsOfMime(mime);

  /// `HEVC · c2.mtk.hevc.decoder（硬件）`.
  String get title =>
      '${TvExoCodec.name(_codecs)} · $name（${hardware ? '硬件' : '软件'}）';

  /// `最大 4096×2304 · 1080P 120 帧 · 4K 64 帧 · 8K 不支持`.
  String get sizes {
    String rate(String label, int? fps) =>
        '$label ${fps == null ? '不支持' : '$fps 帧'}';
    return [
      if (maxWidth != null && maxHeight != null) '最大 $maxWidth×$maxHeight',
      rate('1080P', fps1080),
      rate('4K', fps2160),
      rate('8K', fps4320),
    ].join(' · ');
  }

  /// `Main 最高 5.1 High · Main 10 最高 5.1 High`, sorted by profile.
  String get profileLine {
    final sorted = [...profiles]..sort((a, b) => a.$1.compareTo(b.$1));
    return [
      for (final (profile, level) in sorted)
        '${TvExoCodec.androidProfile(_codecs, profile) ?? 'Profile $profile'}'
            ' 最高 ${TvExoCodec.androidLevel(_codecs, level) ?? '$level'}',
    ].join(' · ');
  }
}

/// One audio decoder.
@immutable
class TvExoAudioDecoder {
  const TvExoAudioDecoder({
    required this.name,
    required this.mime,
    this.maxChannels,
    this.maxSampleRate,
  });

  factory TvExoAudioDecoder.fromMap(Map m) => TvExoAudioDecoder(
    name: '${m['name']}',
    mime: '${m['mime']}',
    maxChannels: _int(m['maxChannels']),
    maxSampleRate: _int(m['maxSampleRate']),
  );

  final String name;
  final String mime;
  final int? maxChannels;
  final int? maxSampleRate;

  String get title => '${TvExoCapabilities.audioName(mime)} · $name';

  String get detail => [
    if (maxChannels != null) '最多 $maxChannels 声道',
    if (maxSampleRate != null) '最高 ${maxSampleRate! ~/ 1000} kHz',
  ].join(' · ');
}

/// What the bridge's `capabilities` answers.
@immutable
class TvExoCapabilities {
  const TvExoCapabilities({
    this.video = const [],
    this.audio = const [],
    this.passthrough = const {},
    this.maxChannels,
    this.displayHdr = const {},
    this.display,
    this.modes = const [],
  });

  factory TvExoCapabilities.fromMap(Map m) => TvExoCapabilities(
    video: [
      for (final d in (m['video'] as List?) ?? const [])
        if (d is Map) TvExoVideoDecoder.fromMap(d),
    ],
    audio: [
      for (final d in (m['audio'] as List?) ?? const [])
        if (d is Map) TvExoAudioDecoder.fromMap(d),
    ],
    passthrough: {
      for (final MapEntry e in ((m['passthrough'] as Map?) ?? const {}).entries)
        '${e.key}': e.value == true,
    },
    maxChannels: _int(m['maxChannels']),
    displayHdr: {...?(m['displayHdr'] as List?)?.whereType<int>()},
    display: _mode(m['display']),
    modes: [
      for (final mode in (m['modes'] as List?) ?? const []) ?_mode(mode),
    ],
  );

  /// Asks the bridge; `null` when it can't answer.
  static Future<TvExoCapabilities?> load() async {
    try {
      final m = await TvExoPlayer.channel.invokeMethod<Map>('capabilities');
      return m == null ? null : TvExoCapabilities.fromMap(m);
    } on PlatformException catch (e) {
      debugPrint('[TvExoCapabilities] failed: ${e.message}');
      return null;
    } on MissingPluginException {
      return null;
    }
  }

  final List<TvExoVideoDecoder> video;
  final List<TvExoAudioDecoder> audio;

  /// By key (`eac3joc`, `eac3`, `ac3`, `ac4`, `dts`, `dtshd`, `truehd`):
  /// whether the audio output takes it undecoded.
  final Map<String, bool> passthrough;
  final int? maxChannels;
  final Set<int> displayHdr;
  final (int, int, double)? display;
  final List<(int, int, double)> modes;

  static (int, int, double)? _mode(Object? v) =>
      v is List && v.length == 3 && v[0] is num && v[1] is num && v[2] is num
      ? ((v[0] as num).toInt(), (v[1] as num).toInt(), (v[2] as num).toDouble())
      : null;

  static String modeText((int, int, double) m) {
    // Android reports 60 Hz as 60.000004.
    final hz = (m.$3 - m.$3.round()).abs() < 0.01
        ? '${m.$3.round()}'
        : m.$3.toStringAsFixed(2);
    return '${m.$1}×${m.$2} @ $hz Hz';
  }

  /// `杜比视界 · HDR10 · HLG · HDR10+`, or that it reports none.
  String get hdrText {
    const names = {1: '杜比视界', 2: 'HDR10', 3: 'HLG', 4: 'HDR10+'};
    final reported = [
      for (final t in displayHdr.toList()..sort()) names[t] ?? '类型 $t',
    ];
    return reported.isEmpty ? '未报告 HDR' : reported.join(' · ');
  }

  static const passthroughNames = {
    'eac3joc': 'E-AC-3 JOC（杜比全景声）',
    'eac3': 'E-AC-3',
    'ac3': 'AC-3',
    'ac4': 'AC-4',
    'dts': 'DTS',
    'dtshd': 'DTS-HD',
    'truehd': 'Dolby TrueHD',
  };

  /// `E-AC-3 JOC（杜比全景声） · E-AC-3 · AC-3`, or none.
  String get passthroughText {
    final yes = [
      for (final MapEntry(:key, :value) in passthrough.entries)
        if (value) passthroughNames[key] ?? key,
    ];
    return yes.isEmpty ? '无（全部在电视上解码）' : yes.join(' · ');
  }

  static String audioName(String mime) => switch (mime) {
    'audio/mp4a-latm' => 'AAC',
    'audio/flac' => 'FLAC',
    'audio/eac3' => 'E-AC-3',
    'audio/eac3-joc' => 'E-AC-3 JOC',
    'audio/ac3' => 'AC-3',
    'audio/ac4' => 'AC-4',
    'audio/opus' => 'Opus',
    'audio/mpeg' => 'MP3',
    'audio/vnd.dts' => 'DTS',
    _ => mime,
  };

  /// The page's rows: sections with a title, a detail and a line to copy.
  List<({String? section, String title, String detail})> get rows => [
    (
      section: '显示器',
      title: '当前模式',
      detail: display == null ? '—' : modeText(display!),
    ),
    (section: null, title: 'HDR', detail: hdrText),
    if (modes.isNotEmpty)
      (
        section: null,
        title: '支持的模式',
        detail: {for (final m in modes) modeText(m)}.join('\n'),
      ),
    (
      section: '音频输出',
      title: '直通（不解码，不做音量均衡）',
      detail: passthroughText,
    ),
    if (maxChannels != null)
      (section: null, title: '最多声道', detail: '$maxChannels'),
    for (final (i, d) in video.indexed)
      (
        section: i == 0 ? '视频解码器' : null,
        title: d.title,
        detail: [d.sizes, d.profileLine].where((s) => s.isNotEmpty).join('\n'),
      ),
    for (final (i, d) in audio.indexed)
      (
        section: i == 0 ? '音频解码器' : null,
        title: d.title,
        detail: d.detail,
      ),
  ];
}

int? _int(Object? v) => v is num ? v.toInt() : null;

/// The page: one focusable row per fact, so the D-pad scrolls it; Select
/// copies the row.
class TvExoCapabilitiesPage extends StatefulWidget {
  const TvExoCapabilitiesPage({super.key, this.debugCapabilities});

  /// Tests pass the answer here instead of asking the bridge.
  @visibleForTesting
  final TvExoCapabilities? debugCapabilities;

  @override
  State<TvExoCapabilitiesPage> createState() => _TvExoCapabilitiesPageState();
}

class _TvExoCapabilitiesPageState extends State<TvExoCapabilitiesPage> {
  TvExoCapabilities? _caps;
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    if (widget.debugCapabilities case final caps?) {
      _caps = caps;
      _loaded = true;
    } else {
      TvExoCapabilities.load().then((caps) {
        if (!mounted) return;
        setState(() {
          _caps = caps;
          _loaded = true;
        });
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final caps = _caps;
    final Widget body;
    if (!_loaded) {
      body = const Center(child: CircularProgressIndicator());
    } else if (caps == null) {
      body = const Center(child: Text('无法读取解码能力'));
    } else {
      final rows = caps.rows;
      body = ListView.builder(
        padding:
            MediaQuery.viewPaddingOf(context).copyWith(top: 0) +
            const EdgeInsets.only(bottom: 24),
        itemCount: rows.length,
        itemBuilder: (context, index) {
          final row = rows[index];
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (row.section case final section?)
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 18, 20, 6),
                  child: Text(
                    section,
                    style: theme.textTheme.titleSmall?.copyWith(
                      color: theme.colorScheme.primary,
                    ),
                  ),
                ),
              ListTile(
                autofocus: index == 0,
                title: Text(row.title),
                subtitle: Text(row.detail),
                onTap: () => Utils.copyText('${row.title}\n${row.detail}'),
              ),
            ],
          );
        },
      );
    }
    return SimpleScaffold(
      appBar: AppBar(
        title: Text(
          '解码能力${caps == null ? '' : '（视频 ${caps.video.length} · 音频 ${caps.audio.length}）'}',
        ),
      ),
      body: body,
    );
  }
}
