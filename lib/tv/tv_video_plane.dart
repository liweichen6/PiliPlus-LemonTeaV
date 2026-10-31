import 'dart:async';
import 'dart:math' as math;

import 'package:PiliPlus/pages/setting/models/model.dart';
import 'package:PiliPlus/plugin/pl_player/models/video_fit_type.dart';
import 'package:PiliPlus/tv/tv_platform.dart';
import 'package:PiliPlus/utils/storage.dart';
import 'package:PiliPlus/utils/storage_key.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_smart_dialog/flutter_smart_dialog.dart';
import 'package:hive_ce/hive.dart';
import 'package:material_ui/material_ui.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';

/// The mpv calls [TvVideoPlane] makes, so its tests can run without libmpv.
abstract interface class TvPlaneMpv {
  void setOption(String name, String value);
  void setProperty(String name, String value);
  String getProperty(String name);
  Future<void> stop();
}

class _NativePlaneMpv implements TvPlaneMpv {
  const _NativePlaneMpv(this._player);

  final NativePlayer _player;

  @override
  void setOption(String name, String value) => _player.setOption(name, value);

  @override
  void setProperty(String name, String value) =>
      _player.setProperty(name, value);

  @override
  String getProperty(String name) => _player.getProperty(name);

  @override
  Future<void> stop() => _player.stop();
}

/// mpv's `vo=mediacodec_embed` on a real `SurfaceView`, so the decoder goes to
/// the TV's video plane and the GPU stays out of the path (docs/tv/PLAN.md,
/// M16). One per player, for videos only, behind an opt-in TV setting.
///
/// Fails closed. 4K60 through the GPU shuts `<physical-tv>` down, so nothing
/// here may leave mpv on Flutter's texture:
///  * [configuration] gives media_kit no way to attach it: with a `vo` other
///    than `gpu` and `androidAttachSurfaceAfterVideoParameters: true` it never
///    sets `wid` or `vo` at all, so a hook that doesn't run leaves `vo=null`;
///  * the hook reads `vo` and `wid` back before it lets mpv go on;
///  * any error, or no surface in time, takes the video off and stops playback.
///
/// mpv events are handled one at a time and the hook runs inside that handler,
/// so nothing in the hook may wait for an mpv reply (`player.command`, any
/// async property): it would never arrive. The hook can't wait for the surface
/// either: the view mounts only after `_initializePlayer`, which awaits a reply
/// when the saved speed isn't 1x. With no surface yet the file loads with
/// `vid=no`, and the surface attaches when it arrives.
class TvVideoPlane {
  TvVideoPlane._();

  /// Fork-only, so `storage_key.dart` stays upstream's. Off when missing.
  static const String settingKey = 'tvVideoPlane';

  static const String viewType = 'com.example.piliplus/tv_video_plane';
  static const Duration surfaceTimeout = Duration(seconds: 8);

  static const String _vo = 'mediacodec_embed';
  static const String _hwdec = 'mediacodec';

  // Decoding on its own thread: with it on mpv's main thread, 4K60 AV1 lost
  // 5-8 % of its frames, and with 4 frames queued about 0.2 %
  // (docs/tv/PROGRESS.md, M16.3). Queued frames are held from the decoder, so
  // this stays small.
  static const int _decodeQueueFrames = 4;

  // VideoQuality.high108060.code, and the long side of the frames it allows.
  static const int _maxTextureQa = 116;
  static const int _maxTextureSide = 1920;

  static const MethodChannel _channel = MethodChannel(viewType);

  /// The modes that fit inside the box. A `SurfaceView` can't be clipped, so a
  /// mode that crops would spill over the page in split-screen.
  static const List<VideoFitType> supportedFits = <VideoFitType>[
    VideoFitType.fill,
    VideoFitType.contain,
    VideoFitType.scaleDown,
    VideoFitType.ratio_4x3,
    VideoFitType.ratio_16x9,
  ];

  static bool get enabled =>
      TvPlatform.isTv && GStorage.setting.get(settingKey, defaultValue: false);

  @visibleForTesting
  static ValueChanged<String> showToast = SmartDialog.showToast;

  static SettingsModel get settingsModel => SwitchModel(
    title: '4K 视频平面',
    subtitle: '解码器直接输出到电视的视频层，可播放 4K，重新打开视频后生效；超分辨率、镜像、缩放和截图不可用',
    leading: const Icon(Icons.layers_outlined),
    setKey: settingKey,
    onChanged: (value) {
      if (!value) capStoredQuality(GStorage.setting);
    },
  );

  /// 4K is safe with the setting on and not with it off, so turning it off
  /// takes a stored quality above 1080P60 back down.
  @visibleForTesting
  static void capStoredQuality(Box<dynamic> box) {
    for (final key in const <String>[
      SettingBoxKey.defaultVideoQa,
      SettingBoxKey.defaultVideoQaCellular,
    ]) {
      if (box.get(key) case final int qa when qa > _maxTextureQa) {
        box.put(key, _maxTextureQa);
      }
    }
  }

  /// With the setting on, a stored quality can be 4K, but a player created
  /// before it was turned on, or for a live room, stays on the texture and
  /// serves the next video too. That can't play above 1080P60.
  static bool refusesTexture(
    TvVideoPlane? plane,
    bool isLive,
    int? width,
    int? height,
  ) {
    if (plane != null || isLive || !enabled) return false;
    if (math.max(width ?? 0, height ?? 0) <= _maxTextureSide) return false;
    showToast('此播放器未使用视频平面，无法播放 4K，请返回首页后重新打开视频');
    return true;
  }

  static TvVideoPlane? _current;

  /// The plane for a player that's about to be created, or `null` to leave it
  /// on Flutter's texture.
  static TvVideoPlane? forNewPlayer({required bool isLive}) {
    if (isLive || !enabled) return null;
    _channel.setMethodCallHandler(_onSurfaceEvent);
    return TvVideoPlane._();
  }

  static Future<void> _onSurfaceEvent(MethodCall call) async {
    final plane = _current;
    if (plane == null) return;
    final int wid = call.arguments['wid'];
    switch (call.method) {
      case 'surfaceReady':
        plane.onSurfaceReady(wid);
      case 'surfaceLost':
        plane.onSurfaceLost(wid);
    }
  }

  VideoControllerConfiguration get configuration =>
      const VideoControllerConfiguration(
        vo: _vo,
        hwdec: _hwdec,
        androidAttachSurfaceAfterVideoParameters: true,
      );

  /// Whether playback stopped because the plane failed. The view shows it, and
  /// Select in the HUD retries.
  final ValueNotifier<bool> failed = ValueNotifier<bool>(false);

  TvPlaneMpv? _mpv;
  ValueListenable<Rect?>? _videoRect;
  VoidCallback? _onFail;

  /// The surface mpv can attach to, `null` while there is none.
  int? _wid;
  Timer? _surfaceTimer;

  /// The surface mpv sits on right now. A page pushed over another can bring
  /// the new surface first, so this isn't always [_wid].
  int? _attachedWid;

  // media_kit zeroes the rect around every parameter change.
  Size? _videoSize;

  /// Takes [player], right after `VideoController.create`.
  void attach(
    NativePlayer player,
    VideoController controller, {
    required VoidCallback onFail,
  }) {
    _current = this;
    bind(_NativePlaneMpv(player), controller.rect, onFail: onFail);
    player.onLoadHooks.add(onLoad);
    // media_kit's own unload hook sets vo=null and wid=0.
    player.onUnloadHooks.add(onUnload);
    player.release.add(() async {
      release();
      if (identical(_current, this)) _current = null;
    });
  }

  @visibleForTesting
  void bind(
    TvPlaneMpv mpv,
    ValueListenable<Rect?> videoRect, {
    required VoidCallback onFail,
  }) {
    _mpv = mpv;
    _videoRect = videoRect;
    _onFail = onFail;
    mpv
      ..setOption('vd-queue-enable', 'yes')
      ..setOption('vd-queue-max-samples', '$_decodeQueueFrames');
  }

  @visibleForTesting
  void release() {
    _surfaceTimer?.cancel();
    _mpv = null;
    _onFail = null;
  }

  @visibleForTesting
  void onLoad() {
    final mpv = _mpv;
    if (mpv == null) return;
    failed.value = false;
    try {
      if (_wid case final wid?) {
        mpv
          ..setOption('vid', 'auto')
          ..setOption('hwdec', _hwdec)
          ..setOption('wid', '$wid')
          ..setOption('vo', _vo);
        _verify(mpv, wid);
        return;
      }
      mpv.setOption('vid', 'no');
      _surfaceTimer?.cancel();
      _surfaceTimer = Timer(surfaceTimeout, () {
        _failClosed(mpv);
      });
    } catch (_) {
      // No await here: see the class comment.
      _failClosed(mpv);
    }
  }

  @visibleForTesting
  void onUnload() {
    _attachedWid = null;
    _surfaceTimer?.cancel();
  }

  /// `setOption` reports no errors, so this is the only proof.
  void _verify(TvPlaneMpv mpv, int wid) {
    final vo = mpv.getProperty('vo');
    final actual = mpv.getProperty('wid');
    if (vo != _vo || actual != '$wid') {
      throw StateError('vo=$vo wid=$actual, wanted $_vo $wid');
    }
    _attachedWid = wid;
  }

  void _failClosed(TvPlaneMpv mpv) {
    if (_mpv == null) return;
    _surfaceTimer?.cancel();
    _attachedWid = null;
    mpv
      ..setProperty('vid', 'no')
      ..setProperty('pause', 'yes')
      ..setOption('vo', 'null')
      ..setOption('wid', '0');
    failed.value = true;
    // The view may be what never came, so it can't be the only message.
    showToast(failedText);
    // Waits for an mpv reply, so it can't be awaited inside the hook.
    Future.microtask(() {
      unawaited(mpv.stop().catchError((Object _) {}));
      _onFail?.call();
    });
  }

  static const String failedText = '视频平面启动失败，已停止播放';

  @visibleForTesting
  void onSurfaceReady(int wid) {
    _wid = wid;
    _surfaceTimer?.cancel();
    final mpv = _mpv;
    // After a failure only a new load attaches: this may be the late surface.
    if (mpv == null || failed.value || _attachedWid != null) return;
    if (mpv.getProperty('path').isEmpty) return;
    try {
      mpv
        ..setProperty('wid', '$wid')
        ..setProperty('vo', _vo);
      _verify(mpv, wid);
      mpv.setProperty('vid', 'auto');
    } catch (_) {
      _failClosed(mpv);
    }
  }

  /// The surface went away, maybe under a running decoder.
  @visibleForTesting
  void onSurfaceLost(int wid) {
    if (_wid == wid) _wid = null;
    final mpv = _mpv;
    if (mpv == null || _attachedWid != wid) return;
    _attachedWid = null;
    mpv
      ..setProperty('vid', 'no')
      ..setProperty('vo', 'null')
      ..setProperty('wid', '0');
    if (_wid case final next?) onSurfaceReady(next);
  }

  Widget view(VideoFitType videoFit, Alignment alignment) => TvVideoPlaneView(
    plane: this,
    videoFit: videoFit,
    alignment: alignment,
  );

  /// Where the `SurfaceView` goes in [box]: the fitted rect for [video]. Flutter
  /// transforms don't reach a `SurfaceView`, so nothing else can place it.
  @visibleForTesting
  static Rect fitRect({
    required Size box,
    required Size? video,
    required VideoFitType videoFit,
    required Alignment alignment,
  }) {
    final fit = supportedFits.contains(videoFit)
        ? videoFit
        : VideoFitType.contain;
    final size = video ?? box;
    final source = fit.aspectRatio == null
        ? size
        : Size(size.height * fit.aspectRatio!, size.height);
    return alignment.inscribe(
      applyBoxFit(fit.boxFit, source, box).destination,
      Offset.zero & box,
    );
  }
}

/// The `SurfaceView`, fitted to the video. It sits above `FittedBox` and
/// `Transform.flip` in the player's view, because it follows neither.
class TvVideoPlaneView extends StatelessWidget {
  const TvVideoPlaneView({
    super.key,
    required this.plane,
    required this.videoFit,
    required this.alignment,
  });

  final TvVideoPlane plane;
  final VideoFitType videoFit;
  final Alignment alignment;

  @override
  Widget build(BuildContext context) {
    final ratio = MediaQuery.devicePixelRatioOf(context);
    final rect = plane._videoRect!;
    return LayoutBuilder(
      builder: (context, constraints) => ListenableBuilder(
        listenable: Listenable.merge([rect, plane.failed]),
        builder: (context, child) {
          if (rect.value case final value? when value.width > 1) {
            plane._videoSize = value.size / ratio;
          }
          return Stack(
            children: [
              Positioned.fromRect(
                rect: TvVideoPlane.fitRect(
                  box: constraints.biggest,
                  video: plane._videoSize,
                  videoFit: videoFit,
                  alignment: alignment,
                ),
                child: child!,
              ),
              if (plane.failed.value) const _PlaneFailure(),
            ],
          );
        },
        child: const ExcludeFocus(child: _PlaneSurface()),
      ),
    );
  }
}

class _PlaneFailure extends StatelessWidget {
  const _PlaneFailure();

  @override
  Widget build(BuildContext context) {
    return const Positioned.fill(
      child: ColoredBox(
        color: Colors.black,
        child: Center(
          child: Text(
            '${TvVideoPlane.failedText}\n按确认键重试，按返回键退出',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.white, fontSize: 20),
          ),
        ),
      ),
    );
  }
}

class _PlaneSurface extends StatelessWidget {
  const _PlaneSurface();

  @override
  Widget build(BuildContext context) {
    return PlatformViewLink(
      viewType: TvVideoPlane.viewType,
      surfaceFactory: (context, controller) => AndroidViewSurface(
        controller: controller as AndroidViewController,
        gestureRecognizers: const <Factory<OneSequenceGestureRecognizer>>{},
        hitTestBehavior: PlatformViewHitTestBehavior.transparent,
      ),
      // Always Hybrid Composition: anything else falls back to a virtual
      // display for a SurfaceView, which puts the GPU back in the path.
      onCreatePlatformView: (params) =>
          PlatformViewsService.initExpensiveAndroidView(
              id: params.id,
              viewType: TvVideoPlane.viewType,
              layoutDirection: TextDirection.ltr,
            )
            ..addOnPlatformViewCreatedListener(params.onPlatformViewCreated)
            ..create(),
    );
  }
}
