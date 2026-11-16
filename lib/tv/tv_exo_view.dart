// The view for ExoPlayer on TV (docs/tv/PLAN.md, M17.8; M17.6, decision 7):
// the transparent view. Media3 draws into a `SurfaceView` under Flutter's
// view, Flutter's surface is see-through while a player view is mounted, and
// this widget clears a hole where the video goes and sends the hole's place
// on screen to the bridge. Danmaku, subtitles and the HUD draw over it as
// they do over mpv's texture. Adapted from Hunter-Clipper/OpenIPTV
// (GPL-3.0), commit 73ee38a, as `M17.4`'s spike and `M17.7`'s test page use
// it.
import 'dart:async';

import 'package:PiliPlus/plugin/pl_player/models/video_fit_type.dart';
import 'package:PiliPlus/tv/tv_exo_player.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:media_kit/media_kit.dart' show Player;

class TvExoView extends StatelessWidget {
  const TvExoView({
    required this.player,
    required this.videoFit,
    required this.alignment,
    this.fill = Colors.black,
    super.key,
  });

  /// `M17.9`'s hook before `Transform.flip` and `FittedBox` in the player's
  /// view, which a `SurfaceView` follows neither of. `null` for mpv.
  static Widget? of(
    Player? player,
    VideoFitType videoFit,
    Alignment alignment, {
    Color fill = Colors.black,
  }) => player is TvExoPlayer
      ? TvExoView(
          player: player,
          videoFit: videoFit,
          alignment: alignment,
          fill: fill,
        )
      : null;

  /// 降低画质 on the failure screen (M17.10, item 6): the next quality that
  /// can play and how to play it, from the TV HUD, which also takes Down for
  /// it. `null` when there's none.
  static ({String label, VoidCallback run})? Function()? lowerQuality;

  final TvExoPlayer player;
  final VideoFitType videoFit;
  final Alignment alignment;
  final Color fill;

  /// The fits a `SurfaceView` can show. It can't be clipped, so the ones
  /// that crop or overflow the box (裁剪, 等宽, 等高, 原始) aren't offered,
  /// and fall back to 自动 here (`M17.10` hides them in 画面比例).
  static const List<VideoFitType> supportedFits = <VideoFitType>[
    VideoFitType.fill,
    VideoFitType.contain,
    VideoFitType.scaleDown,
    VideoFitType.ratio_4x3,
    VideoFitType.ratio_16x9,
  ];

  /// Where the video goes in a [box], as upstream's `FittedBox` around
  /// `SimpleVideo` places it: a ratio fit forces that aspect ratio and
  /// contains it; the others fit the decoded size. Before the size is known
  /// the video fills the box.
  @visibleForTesting
  static Rect fitRect({
    required Size box,
    required Size? video,
    required VideoFitType fit,
    required Alignment alignment,
  }) {
    if (box.isEmpty) return Offset.zero & box;
    final used = supportedFits.contains(fit) ? fit : VideoFitType.contain;
    final size = video == null || video.isEmpty ? box : video;
    final ratio = used.aspectRatio;
    final source = ratio == null
        ? size
        : Size(size.height * ratio, size.height);
    return alignment.inscribe(
      applyBoxFit(used.boxFit, source, box).destination,
      Offset.zero & box,
    );
  }

  @override
  Widget build(BuildContext context) {
    final pixelRatio = MediaQuery.devicePixelRatioOf(context);
    return ColoredBox(
      color: fill,
      child: LayoutBuilder(
        builder: (context, constraints) => ListenableBuilder(
          listenable: Listenable.merge([player.videoSize, player.failed]),
          builder: (context, child) {
            final failed = player.failed.value;
            return Stack(
              children: [
                Positioned.fromRect(
                  rect: fitRect(
                    box: constraints.biggest,
                    video: player.videoSize.value,
                    fit: videoFit,
                    alignment: alignment,
                  ),
                  child: child!,
                ),
                if (failed != null)
                  Positioned.fill(
                    child: _FailureScreen(
                      text: failed,
                      lower: lowerQuality?.call()?.label,
                    ),
                  ),
              ],
            );
          },
          child: _VideoHole(pixelRatio: pixelRatio),
        ),
      ),
    );
  }
}

/// The adapter's failure screen (M17.6, decision 4). Upstream's spinner
/// doesn't draw over it, since the player reads as neither playing nor
/// buffering once it fails. Select retries on ExoPlayer: upstream's play and
/// pause toggle reaches `TvExoPlayer.play`, which reopens the media.
class _FailureScreen extends StatelessWidget {
  const _FailureScreen({required this.text, this.lower});

  final String text;

  /// The quality 降低画质 would play, if any.
  final String? lower;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: Colors.black,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                text,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white, fontSize: 18),
              ),
              const SizedBox(height: 12),
              Text(
                lower == null ? '按确认键重试' : '按确认键重试　·　按下键降低画质（$lower）',
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white70, fontSize: 14),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A hole in Flutter's frame, with its place on screen, in physical pixels,
/// sent to the `SurfaceView` under Flutter's view.
class _VideoHole extends StatefulWidget {
  const _VideoHole({required this.pixelRatio});

  final double pixelRatio;

  @override
  State<_VideoHole> createState() => _VideoHoleState();
}

class _VideoHoleState extends State<_VideoHole> {
  /// Holes on screen. A new page's hole can mount before the old one goes,
  /// so Flutter's surface turns see-through with the first and opaque again
  /// only when the last one goes.
  static int _mounted = 0;

  static MethodChannel get _channel => TvExoPlayer.channel;

  Timer? _timer;
  Rect? _sent;

  @override
  void initState() {
    super.initState();
    if (_mounted++ == 0) unawaited(_setTransparent(true));
    // An ancestor can move this box without repainting it.
    _timer = Timer.periodic(const Duration(milliseconds: 500), (_) => _send());
  }

  @override
  void dispose() {
    _timer?.cancel();
    if (--_mounted == 0) {
      // The bridge waits a moment before it lets the layer go, so a route
      // change that sends a new rect right after keeps it.
      unawaited(_call('layerRect'));
      unawaited(_setTransparent(false));
    }
    super.dispose();
  }

  static Future<void> _setTransparent(bool on) => _call('setTransparent', on);

  static Future<void> _call(String method, [Object? arguments]) async {
    try {
      await _channel.invokeMethod<Object?>(method, arguments);
    } on PlatformException catch (e) {
      if (kDebugMode) debugPrint('[TvExoView] $method failed: ${e.message}');
    } on MissingPluginException {
      // Not on Android.
    }
  }

  void _send() {
    if (!mounted) return;
    final box = context.findRenderObject();
    if (box is! RenderBox || !box.hasSize || !box.attached) return;
    final origin = box.localToGlobal(Offset.zero) * widget.pixelRatio;
    final rect = origin & (box.size * widget.pixelRatio);
    if (rect == _sent || rect.isEmpty) return;
    _sent = rect;
    unawaited(
      _call('layerRect', <String, int>{
        'l': rect.left.round(),
        't': rect.top.round(),
        'w': rect.width.round(),
        'h': rect.height.round(),
      }),
    );
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
