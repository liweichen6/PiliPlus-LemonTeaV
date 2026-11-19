// A test page for the dev build (docs/tv/PLAN.md, M17.7): it plays a video
// or a live room through the Kotlin Media3 bridge directly, with no Dart
// player code behind it, so the bridge can be checked on a TV before the
// adapter (M17.8) exists.
//
// Opened only in `PiliPlus TV dev`, by a launch extra:
//
//   adb shell am start -n com.lemontea.piliplus.tv.dev/com.example.piliplus.MainActivity \
//     --es tv_exo_test "'live=ROOM qn=400 proto=http_hls fmt=fmp4 codec=hevc'"
//   ... --es tv_exo_test "'video=BV1fiHN6zEfx qn=80 codec=avc seek=60'"
//
// Keys for a spec: `video` (a BV id) with `p`, `qn`, `codec` (avc, hevc or
// av1), `ripper=1` (through the thread ripper) and `seek` (seconds, once, 8 s
// after the first frame); or `live` (a room id) with `qn`, `proto`
// (http_stream or http_hls), `fmt` (flv, ts or fmp4) and `codec` (avc or
// hevc). Every stream is capped at 1920 × 1080 pixels unless `nocap=1`.
// The page asks as a signed-out viewer unless `signedIn=1`.
//
// On the page: Select plays or pauses, Left and Right seek 10 s, Up logs the
// bridge's stats, Back leaves. Every bridge event is logged with `[tvexo]`.
import 'dart:async';

import 'package:PiliPlus/http/browser_ua.dart';
import 'package:PiliPlus/http/constants.dart';
import 'package:PiliPlus/http/live.dart';
import 'package:PiliPlus/http/loading_state.dart';
import 'package:PiliPlus/http/search.dart';
import 'package:PiliPlus/http/video.dart';
import 'package:PiliPlus/models/common/account_type.dart';
import 'package:PiliPlus/models/common/video/video_type.dart';
import 'package:PiliPlus/models/video/play/url.dart';
import 'package:PiliPlus/models_new/live/live_room_play_info/data.dart';
import 'package:PiliPlus/services/thread_ripper/range_proxy.dart';
import 'package:PiliPlus/utils/accounts.dart';
import 'package:PiliPlus/utils/accounts/account.dart';
import 'package:PiliPlus/utils/storage_pref.dart';
import 'package:PiliPlus/utils/video_utils.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';

class TvExoTestPage extends StatefulWidget {
  const TvExoTestPage({required this.spec, super.key});

  final Map<String, String> spec;

  static const MethodChannel channel = MethodChannel(
    'com.example.piliplus/tv_exo',
  );

  /// Opens the page if the dev build was launched with `tv_exo_test`.
  static void openIfAsked() {
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final String? text;
      try {
        text = await channel.invokeMethod<String>('testRequest');
      } on MissingPluginException {
        return;
      }
      if (text == null || text.isEmpty) return;
      // Let the home page settle before pushing over it.
      await Future<void>.delayed(const Duration(seconds: 2));
      Get.to<void>(() => TvExoTestPage(spec: parseSpec(text!)));
    });
  }

  @visibleForTesting
  static Map<String, String> parseSpec(String text) => <String, String>{
    for (final part in text.split(RegExp(r'\s+')))
      if (part.contains('='))
        part.substring(0, part.indexOf('=')): part.substring(
          part.indexOf('=') + 1,
        ),
  };

  @override
  State<TvExoTestPage> createState() => _TvExoTestPageState();
}

class _TvExoTestPageState extends State<TvExoTestPage>
    with WidgetsBindingObserver {
  static const int _cap = 1920 * 1080;

  final FocusNode _focus = FocusNode();
  final ValueNotifier<String> _status = ValueNotifier<String>('准备中');
  final Map<String, Object?> _facts = <String, Object?>{};
  RipperRangeProxy? _ripper;
  int _gen = 0;
  bool _live = false;
  bool _seekDone = false;
  int _pos = 0;
  int _dur = 0;
  bool _playing = false;

  Map<String, String> get spec => widget.spec;

  static void _log(String text) => debugPrint('[tvexo] $text');

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // 无痕模式 for this process unless `signedIn=1`. The heartbeat account
    // also asks for live play URLs, so anonymous means signed-out qualities.
    // This page never sends a heartbeat or a room entry either way.
    if (widget.spec['signedIn'] != '1') {
      Accounts.accountMode[AccountType.heartbeat.index] = AnonymousAccount();
    }
    TvExoTestPage.channel.setMethodCallHandler(_onEvent);
    unawaited(TvExoTestPage.channel.invokeMethod<bool>('setTransparent', true));
    unawaited(_start());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    TvExoTestPage.channel
      ..setMethodCallHandler(null)
      ..invokeMethod<void>('dispose')
      ..invokeMethod<void>('layerRect')
      ..invokeMethod<bool>('setTransparent', false);
    _ripper?.close();
    _focus.dispose();
    _status.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Home and back: the surface goes and comes back; the player stays.
    _log('lifecycle $state');
    if (state == AppLifecycleState.paused) {
      TvExoTestPage.channel.invokeMethod<void>('pause');
    } else if (state == AppLifecycleState.resumed) {
      TvExoTestPage.channel.invokeMethod<void>('play');
    }
  }

  Future<void> _start() async {
    _log('spec $spec');
    final heap = await TvExoTestPage.channel.invokeMethod<int>('heapLimit');
    _log('heapLimit ${heap == null ? '-' : heap ~/ 0x100000} MB');
    final decoders = await TvExoTestPage.channel.invokeMethod<List>('decoders');
    for (final d in decoders ?? const []) {
      _log('decoder $d');
    }
    try {
      final open = spec.containsKey('live')
          ? await _liveSource()
          : await _videoSource();
      if (open == null) return;
      await TvExoTestPage.channel.invokeMethod<void>('create');
      _gen++;
      await TvExoTestPage.channel.invokeMethod<void>('open', <String, Object?>{
        ...open,
        'gen': _gen,
        'play': true,
        'headers': <String, String>{
          'User-Agent': BrowserUa.pc,
          'Referer': HttpString.baseUrl,
        },
        if (spec['nocap'] != '1') 'maxPixels': _cap,
      });
      _status.value = '打开中';
    } catch (e) {
      _log('start failed: $e');
      _status.value = '失败: $e';
    }
  }

  Future<Map<String, Object?>?> _videoSource() async {
    final bvid = spec['video']!;
    final qn = int.tryParse(spec['qn'] ?? '') ?? 80;
    final cid = await SearchHttp.ab2c(
      bvid: bvid,
      part: int.tryParse(spec['p'] ?? ''),
    );
    if (cid == null) {
      _status.value = '找不到 cid';
      return null;
    }
    final res = await VideoHttp.videoUrl(
      bvid: bvid,
      cid: cid,
      qn: qn,
      tryLook: false,
      videoType: VideoType.ugc,
    );
    if (res case Success(:final response)) {
      return _pickVideo(response, qn);
    }
    _status.value = '取流失败: $res';
    return null;
  }

  Future<Map<String, Object?>?> _pickVideo(PlayUrlModel data, int qn) async {
    final videos = data.dash?.video ?? const [];
    for (final v in videos) {
      _log(
        'offered video ${v.id} ${v.codecs} ${v.width}x${v.height}@${v.frameRate}',
      );
    }
    final supported =
        await TvExoTestPage.channel.invokeMethod<List>('supports', [
          for (final v in videos)
            <String, Object?>{
              'codecs': v.codecs,
              'width': v.width,
              'height': v.height,
              'frameRate': double.tryParse(v.frameRate ?? ''),
            },
        ]) ??
        const [];
    for (final (i, v) in videos.indexed) {
      _log('supports ${v.id} ${v.codecs}: ${supported.elementAtOrNull(i)}');
    }
    final prefix = switch (spec['codec']) {
      'hevc' => const ['hev1', 'hvc1'],
      'av1' => const ['av01'],
      _ => const ['avc1'],
    };
    VideoItem? video;
    for (final v in videos) {
      if (v.id <= qn &&
          prefix.any((p) => v.codecs?.startsWith(p) ?? false) &&
          (video == null || v.id > video.id)) {
        video = v;
      }
    }
    final audio = (data.dash?.audio ?? const []).firstOrNull;
    if (video == null) {
      _status.value = '没有 ${spec['codec'] ?? 'avc'} ≤ $qn 的流';
      return null;
    }
    _log('picked video ${video.id} ${video.codecs} audio ${audio?.id}');
    var videoUrl = VideoUtils.getCdnUrl(video.playUrls);
    String? audioUrl = audio == null
        ? null
        : VideoUtils.getCdnUrl(audio.playUrls, isAudio: true);
    if (spec['ripper'] == '1') {
      final proxy = RipperRangeProxy(
        concurrency: Pref.threadRipperConcurrency,
        overseas: Pref.threadRipperOverseas,
        customHosts: Pref.threadRipperCustomHosts,
        userAgent: BrowserUa.pc,
      );
      await proxy.start();
      _ripper = proxy;
      videoUrl = proxy.register(video.playUrls);
      if (audio != null) {
        audioUrl = proxy.register(audio.playUrls, isAudio: true);
      }
    }
    return <String, Object?>{
      'video': videoUrl,
      'audio': audioUrl,
      'live': false,
      'startMs': 0,
      'bufferBytes': (Pref.bufferSize * 0x100000).round(),
      'bufferMs': (Pref.bufferSec * 1000).round(),
    };
  }

  Future<Map<String, Object?>?> _liveSource() async {
    final room = spec['live']!;
    final res = await LiveHttp.liveRoomInfo(
      roomId: room,
      qn: int.tryParse(spec['qn'] ?? '') ?? 400,
    );
    if (res case Success(:final response)) {
      return _pickLive(response);
    }
    _status.value = '取流失败: $res';
    return null;
  }

  Map<String, Object?>? _pickLive(RoomPlayInfoData info) {
    if (info.liveStatus != 1) {
      _status.value = '未开播';
      return null;
    }
    final streams = info.playurlInfo?.playurl?.stream ?? const [];
    for (final s in streams) {
      for (final f in s.format) {
        for (final c in f.codec) {
          _log(
            'offered live ${s.protocolName}/${f.formatName}/${c.codecName} '
            'qn=${c.currentQn.code} accept=${c.acceptQn.map((q) => q.code).toList()}',
          );
        }
      }
    }
    for (final s in streams) {
      if (s.protocolName != (spec['proto'] ?? 'http_stream')) continue;
      for (final f in s.format) {
        if (f.formatName != (spec['fmt'] ?? 'flv')) continue;
        for (final c in f.codec) {
          if (c.codecName != (spec['codec'] ?? 'avc')) continue;
          _live = true;
          _facts['qn'] = c.currentQn.code;
          _log(
            'picked live ${s.protocolName}/${f.formatName}/${c.codecName} '
            'qn=${c.currentQn.code}',
          );
          final liveBytes = Pref.liveBufferSize > 0
              ? Pref.liveBufferSize
              : Pref.bufferSize * 2;
          return <String, Object?>{
            'video': VideoUtils.getLiveCdnUrl(c),
            'live': true,
            'hls': s.protocolName == 'http_hls',
            'bufferBytes': (liveBytes * 0x100000).round(),
            'bufferMs': (Pref.liveBufferSec * 1000).round(),
          };
        }
      }
    }
    _status.value = '服务器没有提供 ${spec['proto']}/${spec['fmt']}/${spec['codec']}';
    return null;
  }

  Future<void> _onEvent(MethodCall call) async {
    final args = Map<String, Object?>.from(call.arguments as Map);
    if (args['gen'] != _gen) return;
    if (call.method == 'position') {
      _pos = (args['pos'] as num).toInt();
      _dur = (args['dur'] as num).toInt();
    } else if (call.method != 'frameRate') {
      _log('${call.method} $args');
    }
    switch (call.method) {
      case 'state':
        _playing = args['playing'] == true;
      case 'videoFormat':
        _facts['video'] =
            '${args['codecs']} ${args['width']}x${args['height']}'
            '@${(args['frameRate'] as num?)?.toStringAsFixed(2)} '
            '${args['hdr']} ${args['decoder']}';
      case 'audioFormat':
        _facts['audio'] = '${args['mime']} ${args['decoder']}';
      case 'frameRate':
        _facts['fps'] = (args['fps'] as num).toStringAsFixed(1);
      case 'dropped':
        _facts['dropped'] = args['count'];
      case 'error':
        _facts['error'] = '${args['kind']} ${args['code'] ?? ''}';
      case 'firstFrame':
        _facts['firstFrame'] = '${args['ms']} ms';
        if (int.tryParse(spec['seek'] ?? '') case final s? when !_seekDone) {
          _seekDone = true;
          Timer(const Duration(seconds: 8), () {
            _log('auto seek to ${s}s');
            TvExoTestPage.channel.invokeMethod<void>('seek', {'ms': s * 1000});
          });
        }
    }
    _status.value =
        '${_live ? '直播' : '视频'} ${_playing ? '播放' : '暂停'} '
        '${_pos ~/ 1000}/${_dur ~/ 1000}s\n'
        '${_facts.entries.map((e) => '${e.key}: ${e.value}').join('\n')}';
  }

  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;
    final key = event.logicalKey;
    if (key == LogicalKeyboardKey.select || key == LogicalKeyboardKey.enter) {
      TvExoTestPage.channel.invokeMethod<void>(_playing ? 'pause' : 'play');
    } else if (!_live && key == LogicalKeyboardKey.arrowLeft) {
      _seek(-10000);
    } else if (!_live && key == LogicalKeyboardKey.arrowRight) {
      _seek(10000);
    } else if (key == LogicalKeyboardKey.arrowUp) {
      TvExoTestPage.channel
          .invokeMethod<Map>('stats')
          .then((s) => _log('stats $s'));
    } else {
      return KeyEventResult.ignored;
    }
    return KeyEventResult.handled;
  }

  void _seek(int by) {
    final to = (_pos + by).clamp(0, _dur > 0 ? _dur : _pos + by);
    _log('seek to ${to ~/ 1000}s');
    TvExoTestPage.channel.invokeMethod<void>('seek', {'ms': to});
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      type: MaterialType.transparency,
      child: Focus(
        focusNode: _focus,
        autofocus: true,
        onKeyEvent: _onKey,
        child: Stack(
          children: [
            Positioned.fill(
              child: _VideoHole(
                pixelRatio: MediaQuery.devicePixelRatioOf(context),
              ),
            ),
            Positioned(
              left: 24,
              top: 24,
              child: ColoredBox(
                color: const Color(0x99000000),
                child: Padding(
                  padding: const EdgeInsets.all(8),
                  child: ValueListenableBuilder<String>(
                    valueListenable: _status,
                    builder: (context, text, _) => Text(
                      text,
                      style: const TextStyle(color: Colors.white, fontSize: 14),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A hole in Flutter's frame, with its place on screen sent to the
/// `SurfaceView` under Flutter's view. Adapted from Hunter-Clipper/OpenIPTV
/// (GPL-3.0), commit 73ee38a.
class _VideoHole extends StatefulWidget {
  const _VideoHole({required this.pixelRatio});

  final double pixelRatio;

  @override
  State<_VideoHole> createState() => _VideoHoleState();
}

class _VideoHoleState extends State<_VideoHole> {
  Timer? _timer;
  Rect? _sent;

  @override
  void initState() {
    super.initState();
    // An ancestor can move this box without repainting it.
    _timer = Timer.periodic(const Duration(milliseconds: 500), (_) => _send());
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _send() {
    if (!mounted) return;
    final box = context.findRenderObject();
    if (box is! RenderBox || !box.hasSize || !box.attached) return;
    final origin = box.localToGlobal(Offset.zero) * widget.pixelRatio;
    final rect = origin & (box.size * widget.pixelRatio);
    if (rect == _sent || rect.isEmpty) return;
    _sent = rect;
    TvExoTestPage.channel.invokeMethod<void>('layerRect', <String, int>{
      'l': rect.left.round(),
      't': rect.top.round(),
      'w': rect.width.round(),
      'h': rect.height.round(),
    });
  }

  @override
  Widget build(BuildContext context) {
    WidgetsBinding.instance.addPostFrameCallback((_) => _send());
    return const CustomPaint(painter: _HolePainter(), size: Size.infinite);
  }
}

class _HolePainter extends CustomPainter {
  const _HolePainter();

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, Paint()..blendMode = BlendMode.clear);
  }

  @override
  bool shouldRepaint(_HolePainter oldDelegate) => false;
}
