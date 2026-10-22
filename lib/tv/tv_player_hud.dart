import 'dart:async';
import 'dart:math' as math;

import 'package:PiliPlus/models/common/video/live_quality.dart';
import 'package:PiliPlus/models/common/video/video_quality.dart';
import 'package:PiliPlus/models_new/pgc/pgc_info_model/episode.dart' as pgc_ep;
import 'package:PiliPlus/models_new/video/video_detail/episode.dart';
import 'package:PiliPlus/models_new/video/video_detail/page.dart';
import 'package:PiliPlus/pages/common/common_intro_controller.dart';
import 'package:PiliPlus/pages/live_room/controller.dart';
import 'package:PiliPlus/pages/video/controller.dart';
import 'package:PiliPlus/pages/video/introduction/pgc/controller.dart';
import 'package:PiliPlus/pages/video/introduction/ugc/controller.dart';
import 'package:PiliPlus/plugin/pl_player/controller.dart';
import 'package:PiliPlus/plugin/pl_player/models/video_fit_type.dart';
import 'package:PiliPlus/plugin/pl_player/utils/danmaku_options.dart';
import 'package:PiliPlus/utils/connectivity_utils.dart';
import 'package:PiliPlus/utils/duration_utils.dart';
import 'package:PiliPlus/utils/storage.dart';
import 'package:PiliPlus/utils/storage_key.dart';
import 'package:collection/collection.dart';
import 'package:flutter/services.dart';
import 'package:flutter_smart_dialog/flutter_smart_dialog.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart' show DateFormat;
import 'package:material_ui/material_ui.dart';

/// Self-contained 10-foot Android TV player HUD & D-pad controller.
///
/// Wraps [child] inside `PlayerFocus` when `TvPlatform.isTv` is true:
/// - In split-screen mode (`!isFullScreen` and `!_hudVisible`), renders a
///   compact top-left **Quick Strip** (`[⛶ 全屏播放]`, `[⏯ 暂停/播放]`,
///   `[⚙ 播控面板]`, `[← 返回]`) and lets D-pad arrow keys pass through to
///   `TvFocusTraversalPolicy` so the user can freely navigate UP owner,
///   Like/Coin/Fav buttons, Episodes, Related Videos, and Comments.
/// - In fullscreen mode (`isFullScreen`) or when the 10-foot HUD is open,
///   intercepts remote keys for direct `-10s / +10s` seeking (with hold
///   acceleration and centered OSD time preview), Play/Pause, and a full
///   10-foot bottom transport bar (Play/Pause, Prev/Next, Episodes, Danmaku
///   toggle & settings, Quality, Speed, Aspect Ratio, Like/Triple-Like, Coin,
///   Favorite).
class TvPlayerHud extends StatefulWidget {
  const TvPlayerHud({
    super.key,
    required this.child,
    required this.plPlayerController,
    this.introController,
    required this.onSendDanmaku,
    this.canPlay,
    this.onSkipSegment,
    this.onRefresh,
  });

  final Widget child;
  final PlPlayerController plPlayerController;
  final CommonIntroController? introController;
  final VoidCallback onSendDanmaku;
  final ValueGetter<bool>? canPlay;
  final ValueGetter<bool>? onSkipSegment;
  final VoidCallback? onRefresh;

  @override
  State<TvPlayerHud> createState() => _TvPlayerHudState();
}

class _TvPlayerHudState extends State<TvPlayerHud> {
  static final DateFormat _clockFormat = DateFormat('HH:mm');

  final FocusNode _playPauseFocusNode = FocusNode(debugLabel: 'TvHudPlayPause');
  final FocusNode _quickFullscreenFocusNode = FocusNode(
    debugLabel: 'TvQuickFullscreen',
  );

  bool _hudVisible = false;
  Timer? _autoHideTimer;
  Timer? _seekPreviewTimer;
  String? _seekPreviewText;
  int _consecutiveSeekSteps = 0;
  DateTime? _lastSeekKeyTime;

  PlPlayerController get _pl => widget.plPlayerController;

  bool get _hasPlayer => _pl.videoPlayerController != null;

  bool get _isFullScreen => _pl.isFullScreen.value;

  VideoDetailController? get _videoDetailCtr {
    if (widget.introController case final intro?) {
      try {
        return intro.videoDetailCtr;
      } catch (_) {}
    }
    final tag = PlPlayerController.playOwner?.tag;
    if (tag != null && Get.isRegistered<VideoDetailController>(tag: tag)) {
      return Get.find<VideoDetailController>(tag: tag);
    }
    return null;
  }

  LiveRoomController? get _liveRoomCtr {
    if (!_pl.isLive) return null;
    final tag = PlPlayerController.playOwner?.tag;
    if (tag != null && Get.isRegistered<LiveRoomController>(tag: tag)) {
      return Get.find<LiveRoomController>(tag: tag);
    }
    return null;
  }

  @override
  void initState() {
    super.initState();
    // Suppress upstream touch controls when fullscreen or TV HUD is active
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _pl.showControls.value = false;
      if (!_isFullScreen &&
          FocusManager.instance.primaryFocus == null &&
          _quickFullscreenFocusNode.canRequestFocus) {
        _quickFullscreenFocusNode.requestFocus();
      }
    });
  }

  @override
  void dispose() {
    _autoHideTimer?.cancel();
    _seekPreviewTimer?.cancel();
    _playPauseFocusNode.dispose();
    _quickFullscreenFocusNode.dispose();
    super.dispose();
  }

  void _showHud() {
    _pl.showControls.value = false;
    if (!_hudVisible) {
      setState(() {
        _hudVisible = true;
      });
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _playPauseFocusNode.canRequestFocus) {
          _playPauseFocusNode.requestFocus();
        }
      });
    }
    _resetAutoHideTimer();
  }

  void _hideHud() {
    _autoHideTimer?.cancel();
    if (_hudVisible && mounted) {
      setState(() {
        _hudVisible = false;
      });
    }
  }

  void _resetAutoHideTimer() {
    _autoHideTimer?.cancel();
    _autoHideTimer = Timer(const Duration(seconds: 5), () {
      if (mounted && !(widget.introController?.isTripling ?? false)) {
        _hideHud();
      }
    });
  }

  bool _isSelectKey(LogicalKeyboardKey key) {
    return key == LogicalKeyboardKey.select ||
        key == LogicalKeyboardKey.enter ||
        key == LogicalKeyboardKey.numpadEnter ||
        key == LogicalKeyboardKey.space ||
        key == LogicalKeyboardKey.gameButtonA;
  }

  bool _isBackKey(LogicalKeyboardKey key) {
    return key == LogicalKeyboardKey.escape ||
        key == LogicalKeyboardKey.goBack ||
        key == LogicalKeyboardKey.browserBack;
  }

  bool _isMenuKey(LogicalKeyboardKey key) {
    return key == LogicalKeyboardKey.contextMenu ||
        key == LogicalKeyboardKey.info ||
        key == LogicalKeyboardKey.settings ||
        key == LogicalKeyboardKey.keyM;
  }

  void _togglePlayPause() {
    if (_pl.isLive || (widget.canPlay?.call() ?? true)) {
      if (_hasPlayer) {
        _pl.onDoubleTapCenter();
        if (mounted) setState(() {});
      }
    }
  }

  void _seekRelative({required bool forward}) {
    if (_pl.isLive || !_hasPlayer) return;
    final now = DateTime.now();
    if (_lastSeekKeyTime != null &&
        now.difference(_lastSeekKeyTime!) < const Duration(milliseconds: 450)) {
      _consecutiveSeekSteps = math.min(_consecutiveSeekSteps + 1, 12);
    } else {
      _consecutiveSeekSteps = 1;
    }
    _lastSeekKeyTime = now;

    final int baseSec = _pl.fastForBackwardDuration.inSeconds.clamp(5, 30);
    final int multiplier = _consecutiveSeekSteps >= 6
        ? 3
        : _consecutiveSeekSteps >= 3
        ? 2
        : 1;
    final delta = Duration(
      seconds: (forward ? 1 : -1) * baseSec * multiplier,
    );

    final state = _pl.videoPlayerController!.state;
    final totalDuration = state.duration.inSeconds > 0
        ? state.duration
        : Duration(seconds: _pl.duration.value);
    final targetMs = (state.position + delta).inMilliseconds
        .clamp(0, math.max<int>(0, totalDuration.inMilliseconds))
        .toInt();
    final target = Duration(milliseconds: targetMs);

    _pl.onForwardBackward(target);

    final posStr = DurationUtils.formatDuration(target.inSeconds);
    final durStr = DurationUtils.formatDuration(totalDuration.inSeconds);
    final prefix = forward ? '⏩' : '⏪';
    setState(() {
      _seekPreviewText = '$prefix $posStr / $durStr';
    });
    _seekPreviewTimer?.cancel();
    _seekPreviewTimer = Timer(const Duration(milliseconds: 1400), () {
      if (mounted) {
        setState(() {
          _seekPreviewText = null;
        });
      }
    });
  }

  KeyEventResult _handleRootKeyEvent(FocusNode node, KeyEvent event) {
    final key = event.logicalKey;

    // Media transport keys work anywhere on the player page
    if (event is KeyDownEvent) {
      if (key == LogicalKeyboardKey.mediaPlayPause ||
          key == LogicalKeyboardKey.mediaPlay ||
          key == LogicalKeyboardKey.mediaPause) {
        _togglePlayPause();
        return KeyEventResult.handled;
      }
      if (key == LogicalKeyboardKey.mediaFastForward) {
        _seekRelative(forward: true);
        return KeyEventResult.handled;
      }
      if (key == LogicalKeyboardKey.mediaRewind) {
        _seekRelative(forward: false);
        return KeyEventResult.handled;
      }
      if (_isMenuKey(key)) {
        if (_hudVisible) {
          _hideHud();
        } else {
          _showHud();
        }
        return KeyEventResult.handled;
      }
    }

    // When the 10-foot HUD is open, reset inactivity timer on any key event
    // and let Back/Escape close the HUD first.
    if (_hudVisible) {
      _resetAutoHideTimer();
      if (event is KeyDownEvent && _isBackKey(key)) {
        _hideHud();
        return KeyEventResult.handled;
      }
      // Let FocusScope inside the HUD handle directional navigation & select
      return KeyEventResult.ignored;
    }

    // In split-screen mode (!isFullScreen) with HUD closed:
    // Do NOT intercept arrow keys or select keys so TvFocusTraversalPolicy
    // can freely navigate the entire VideoDetailPage / LiveRoomPage!
    if (!_isFullScreen) {
      return KeyEventResult.ignored;
    }

    // Fullscreen mode with HUD closed:
    _pl.showControls.value = false;
    if (event is KeyDownEvent || event is KeyRepeatEvent) {
      if (key == LogicalKeyboardKey.arrowLeft) {
        _seekRelative(forward: false);
        return KeyEventResult.handled;
      }
      if (key == LogicalKeyboardKey.arrowRight) {
        _seekRelative(forward: true);
        return KeyEventResult.handled;
      }
    }

    if (event is KeyDownEvent) {
      if (_isBackKey(key)) {
        _pl.triggerFullScreen(status: false);
        return KeyEventResult.handled;
      }
      if (_isSelectKey(key)) {
        if (widget.onSkipSegment?.call() ?? false) {
          return KeyEventResult.handled;
        }
        _togglePlayPause();
        _showHud();
        return KeyEventResult.handled;
      }
      if (key == LogicalKeyboardKey.arrowUp ||
          key == LogicalKeyboardKey.arrowDown) {
        _showHud();
        return KeyEventResult.handled;
      }
    }

    return KeyEventResult.ignored;
  }

  String _resolveTitle() {
    if (_pl.isLive) {
      final liveTitle = _liveRoomCtr?.title.value;
      if (liveTitle != null && liveTitle.isNotEmpty) return liveTitle;
      return '直播间';
    }
    if (widget.introController case final PgcIntroController pgcCtr) {
      final baseTitle = pgcCtr.pgcItem.title ?? '';
      final ep = pgcCtr.pgcItem.episodes?.firstWhereOrNull(
        (e) => e.cid == _pl.cid,
      );
      final sub = ep?.showTitle ?? ep?.longTitle ?? ep?.title ?? '';
      if (sub.isNotEmpty && sub != baseTitle) {
        return '$baseTitle · $sub';
      }
      if (baseTitle.isNotEmpty) return baseTitle;
    }
    if (widget.introController case final intro?) {
      final detail = intro.videoDetail.value;
      final baseTitle = detail.title ?? '';
      final pages = detail.pages;
      if (pages != null && pages.length > 1) {
        final currPart = pages.firstWhereOrNull((p) => p.cid == _pl.cid);
        if (currPart?.part != null && currPart!.part!.isNotEmpty) {
          return '$baseTitle · P${currPart.page ?? ''} ${currPart.part}';
        }
      }
      if (baseTitle.isNotEmpty) return baseTitle;
    }
    return '';
  }

  List<({String label, BaseEpisodeItem item, bool isCurrent})>
  _collectEpisodes() {
    final result = <({String label, BaseEpisodeItem item, bool isCurrent})>[];
    final currentCid = _videoDetailCtr?.cid.value ?? _pl.cid;
    if (widget.introController case final PgcIntroController pgcCtr) {
      final episodes = pgcCtr.pgcItem.episodes;
      if (episodes != null) {
        for (var i = 0; i < episodes.length; i++) {
          final pgc_ep.EpisodeItem ep = episodes[i];
          final title =
              ep.showTitle ?? ep.longTitle ?? ep.title ?? '第${i + 1}话';
          final badge = (ep.badge != null && ep.badge!.isNotEmpty)
              ? ' [${ep.badge}]'
              : '';
          result.add((
            label: '$title$badge',
            item: ep,
            isCurrent: ep.cid == currentCid,
          ));
        }
      }
    } else if (widget.introController case final UgcIntroController ugcCtr) {
      final detail = ugcCtr.videoDetail.value;
      final pages = detail.pages;
      if (pages != null && pages.length > 1) {
        for (var i = 0; i < pages.length; i++) {
          final Part p = pages[i];
          final pNum = p.page ?? (i + 1);
          result.add((
            label: 'P$pNum  ${p.part ?? ''}',
            item: p,
            isCurrent: p.cid == currentCid,
          ));
        }
      } else if (detail.ugcSeason?.sections case final sections?
          when sections.isNotEmpty) {
        for (final section in sections) {
          final eps = section.episodes;
          if (eps == null) continue;
          for (final ep in eps) {
            result.add((
              label: ep.title ?? ep.page?.part ?? '剧集',
              item: ep,
              isCurrent: ep.cid == currentCid || ep.bvid == ugcCtr.bvid,
            ));
          }
        }
      }
    }
    return result;
  }

  Future<void> _showEpisodeDialog() async {
    final episodes = _collectEpisodes();
    if (episodes.isEmpty) {
      SmartDialog.showToast('当前视频无分P或剧集');
      return;
    }
    _hideHud();
    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return _TvOptionListDialog(
          title: '选集 (${episodes.length})',
          items: [
            for (final ep in episodes)
              _TvDialogOptionItem(
                title: ep.label,
                selected: ep.isCurrent,
                onSelect: () {
                  Navigator.of(dialogContext).pop();
                  if (widget.introController
                      case final PgcIntroController pgcCtr) {
                    pgcCtr.onChangeEpisode(ep.item);
                  } else if (widget.introController
                      case final UgcIntroController ugcCtr) {
                    ugcCtr.onChangeEpisode(ep.item);
                  }
                },
              ),
          ],
        );
      },
    );
  }

  Future<void> _showQualityDialog() async {
    if (_pl.isLive) {
      final liveCtr = _liveRoomCtr;
      if (liveCtr == null || liveCtr.acceptQnList.isEmpty) {
        SmartDialog.showToast('当前直播不支持切换画质');
        return;
      }
      final currentQn = liveCtr.currentQn.value;
      _hideHud();
      await showDialog<void>(
        context: context,
        builder: (dialogContext) {
          return _TvOptionListDialog(
            title: '选择直播画质',
            items: [
              for (final LiveQuality qn in liveCtr.acceptQnList)
                _TvDialogOptionItem(
                  title: qn.desc,
                  selected: currentQn?.code == qn.code,
                  onSelect: () {
                    Navigator.of(dialogContext).pop();
                    liveCtr.changeQn(qn);
                    SmartDialog.showToast('画质已切换为：${qn.desc}');
                  },
                ),
            ],
          );
        },
      );
      return;
    }

    final videoCtr = _videoDetailCtr;
    if (videoCtr == null ||
        videoCtr.isFileSource ||
        videoCtr.data.dash == null ||
        videoCtr.data.supportFormats == null) {
      SmartDialog.showToast('当前视频不支持切换画质');
      return;
    }
    final formats = videoCtr.data.supportFormats!;
    final availableQa =
        videoCtr.data.dash!.video?.map((e) => e.id).toSet() ?? const <int?>{};
    final currentQaCode = videoCtr.currentVideoQa.value?.code;
    _hideHud();
    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return _TvOptionListDialog(
          title: '选择视频画质',
          items: [
            for (final fmt in formats)
              if (fmt.quality != null && availableQa.contains(fmt.quality))
                _TvDialogOptionItem(
                  title: fmt.newDesc ?? VideoQuality.fromCode(fmt.quality!).desc,
                  subtitle: fmt.format,
                  selected: currentQaCode == fmt.quality,
                  onSelect: () async {
                    Navigator.of(dialogContext).pop();
                    final quality = fmt.quality!;
                    final newQa = VideoQuality.fromCode(quality);
                    videoCtr
                      ..plPlayerController.cacheVideoQa = newQa.code
                      ..currentVideoQa.value = newQa
                      ..updatePlayer();
                    SmartDialog.showToast('画质已切换为：${newQa.desc}');
                    if (!_pl.tempPlayerConf) {
                      GStorage.setting.put(
                        await ConnectivityUtils.isWiFi
                            ? SettingBoxKey.defaultVideoQa
                            : SettingBoxKey.defaultVideoQaCellular,
                        quality,
                      );
                    }
                  },
                ),
          ],
        );
      },
    );
  }

  Future<void> _showSpeedDialog() async {
    if (_pl.isLive) return;
    final speeds = _pl.speedList;
    final currentSpeed = _pl.playbackSpeed;
    _hideHud();
    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return _TvOptionListDialog(
          title: '选择播放倍速',
          items: [
            for (final s in speeds)
              _TvDialogOptionItem(
                title: '${s}x',
                selected: (s - currentSpeed).abs() < 0.01,
                onSelect: () {
                  Navigator.of(dialogContext).pop();
                  _pl.setPlaybackSpeed(s);
                  SmartDialog.showToast('播放倍速：${s}x');
                },
              ),
          ],
        );
      },
    );
  }

  Future<void> _showVideoFitDialog() async {
    final currentFit = _pl.videoFit.value;
    _hideHud();
    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return _TvOptionListDialog(
          title: '选择画面比例',
          items: [
            for (final fit in VideoFitType.values)
              _TvDialogOptionItem(
                title: fit.desc,
                selected: fit == currentFit,
                onSelect: () {
                  Navigator.of(dialogContext).pop();
                  _pl.toggleVideoFit(fit);
                  SmartDialog.showToast('画面比例：${fit.desc}');
                },
              ),
          ],
        );
      },
    );
  }

  Future<void> _showDanmakuSettingsDialog() async {
    _hideHud();
    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            void applyDanmakuOption() {
              _pl.danmakuController?.updateOption(
                DanmakuOptions.get(
                  notFullscreen: !_isFullScreen,
                  speed: _pl.playbackSpeed,
                ),
              );
              DanmakuOptions.save(_pl.danmakuOpacity.value);
              setDialogState(() {});
            }

            const areas = [
              (label: '1/4 屏', value: 0.25),
              (label: '半屏', value: 0.5),
              (label: '3/4 屏', value: 0.75),
              (label: '满屏', value: 1.0),
            ];
            const opacities = [
              (label: '25%', value: 0.25),
              (label: '50%', value: 0.5),
              (label: '75%', value: 0.75),
              (label: '100%', value: 1.0),
            ];
            const scales = [
              (label: '小 (0.8x)', value: 0.8),
              (label: '标准 (1.0x)', value: 1.0),
              (label: '大 (1.2x)', value: 1.2),
              (label: '特大 (1.5x)', value: 1.5),
            ];
            const durations = [
              (label: '慢 (12s)', value: 12.0),
              (label: '标准 (8s)', value: 8.0),
              (label: '快 (6s)', value: 6.0),
            ];
            const filters = [
              (label: '滚动弹幕', type: 2),
              (label: '顶部弹幕', type: 5),
              (label: '底部弹幕', type: 4),
              (label: '彩色弹幕', type: 6),
            ];

            return AlertDialog(
              backgroundColor: const Color(0xF21A1C1E),
              title: const Text(
                '弹幕设置 (遥控器方向键选择)',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
              ),
              content: SizedBox(
                width: 560,
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    spacing: 14,
                    children: [
                      _buildSettingGroup(
                        title: '显示区域',
                        children: [
                          for (var i = 0; i < areas.length; i++)
                            _TvHudPillButton(
                              autofocus: i == 0,
                              label: areas[i].label,
                              active:
                                  (DanmakuOptions.danmakuShowArea -
                                          areas[i].value)
                                      .abs() <
                                  0.05,
                              onPressed: () {
                                DanmakuOptions.danmakuShowArea = areas[i].value;
                                applyDanmakuOption();
                              },
                            ),
                        ],
                      ),
                      _buildSettingGroup(
                        title: '不透明度',
                        children: [
                          for (final op in opacities)
                            _TvHudPillButton(
                              label: op.label,
                              active:
                                  (_pl.danmakuOpacity.value - op.value).abs() <
                                  0.05,
                              onPressed: () {
                                _pl.danmakuOpacity.value = op.value;
                                applyDanmakuOption();
                              },
                            ),
                        ],
                      ),
                      _buildSettingGroup(
                        title: '弹幕字号',
                        children: [
                          for (final sc in scales)
                            _TvHudPillButton(
                              label: sc.label,
                              active:
                                  (DanmakuOptions.danmakuFontScaleFS - sc.value)
                                      .abs() <
                                  0.05,
                              onPressed: () {
                                DanmakuOptions.danmakuFontScale = sc.value;
                                DanmakuOptions.danmakuFontScaleFS = sc.value;
                                applyDanmakuOption();
                              },
                            ),
                        ],
                      ),
                      _buildSettingGroup(
                        title: '弹幕速度',
                        children: [
                          for (final dur in durations)
                            _TvHudPillButton(
                              label: dur.label,
                              active:
                                  (DanmakuOptions.danmakuDuration - dur.value)
                                      .abs() <
                                  0.5,
                              onPressed: () {
                                DanmakuOptions.danmakuDuration = dur.value;
                                applyDanmakuOption();
                              },
                            ),
                        ],
                      ),
                      _buildSettingGroup(
                        title: '屏蔽类型 (选中即屏蔽)',
                        children: [
                          for (final f in filters)
                            _TvHudPillButton(
                              label: f.label,
                              active: DanmakuOptions.blockTypes.contains(
                                f.type,
                              ),
                              onPressed: () {
                                if (DanmakuOptions.blockTypes.contains(
                                  f.type,
                                )) {
                                  DanmakuOptions.blockTypes.remove(f.type);
                                } else {
                                  DanmakuOptions.blockTypes.add(f.type);
                                }
                                DanmakuOptions.blockColorful = DanmakuOptions
                                    .blockTypes
                                    .contains(6);
                                applyDanmakuOption();
                              },
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                _TvHudPillButton(
                  label: '关闭',
                  icon: Icons.check,
                  onPressed: () => Navigator.of(dialogContext).pop(),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildSettingGroup({
    required String title,
    required List<Widget> children,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      spacing: 8,
      children: [
        Text(
          title,
          style: const TextStyle(
            color: Colors.white70,
            fontSize: 13,
            fontWeight: FontWeight.w500,
          ),
        ),
        Wrap(
          spacing: 10,
          runSpacing: 8,
          children: children,
        ),
      ],
    );
  }

  void _toggleDanmaku() {
    final newVal = !_pl.enableShowDanmakuAdaptive.value;
    _pl.enableShowDanmakuAdaptive.value = newVal;
    if (!_pl.tempPlayerConf) {
      GStorage.setting.put(
        _pl.isLive
            ? SettingBoxKey.enableShowLiveDanmaku
            : SettingBoxKey.enableShowDanmaku,
        newVal,
      );
    }
    SmartDialog.showToast(newVal ? '已开启弹幕' : '已关闭弹幕');
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Focus(
      autofocus: true,
      onKeyEvent: _handleRootKeyEvent,
      child: Obx(() {
        final isFullScreen = _pl.isFullScreen.value;
        if (isFullScreen && _pl.showControls.value) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) _pl.showControls.value = false;
          });
        }
        return Stack(
          fit: StackFit.passthrough,
          children: [
            widget.child,
            // Split-screen quick control strip so D-pad users can enter
            // fullscreen, play/pause, open the 10-foot HUD, or navigate down
            // to UP / Like / Coin / Fav / Related Videos / Comments.
            if (!isFullScreen && !_hudVisible) _buildSplitScreenQuickStrip(),
            // Centered OSD seek preview banner
            if (_seekPreviewText != null)
              IgnorePointer(
                child: Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 14,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xCC000000),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: Colors.white24,
                        width: 1.5,
                      ),
                    ),
                    child: Text(
                      _seekPreviewText!,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        decoration: TextDecoration.none,
                      ),
                    ),
                  ),
                ),
              ),
            // Full 10-foot TV HUD overlay
            if (_hudVisible) _buildFullHudOverlay(isFullScreen: isFullScreen),
          ],
        );
      }),
    );
  }

  Widget _buildSplitScreenQuickStrip() {
    final topPadding = MediaQuery.paddingOf(context).top;
    return Positioned(
      top: topPadding + 8,
      left: 12,
      child: Material(
        color: Colors.transparent,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          decoration: BoxDecoration(
            color: const Color(0xB8101214),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.white12),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            spacing: 8,
            children: [
              _TvHudPillButton(
                focusNode: _quickFullscreenFocusNode,
                autofocus: true,
                compact: true,
                icon: Icons.fullscreen,
                label: '全屏',
                onPressed: () {
                  if (!_pl.isLive && !(widget.canPlay?.call() ?? true)) {
                    return;
                  }
                  _pl.triggerFullScreen(status: true);
                },
              ),
              _TvHudPillButton(
                compact: true,
                icon: Icons.play_arrow_rounded,
                label: '播/暂',
                onPressed: _togglePlayPause,
              ),
              _TvHudPillButton(
                compact: true,
                icon: Icons.tune_rounded,
                label: '播控',
                onPressed: _showHud,
              ),
              _TvHudPillButton(
                compact: true,
                icon: Icons.arrow_back_rounded,
                label: '返回',
                onPressed: () =>
                    _pl.onPopInvokedWithResult(false, null),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFullHudOverlay({required bool isFullScreen}) {
    final title = _resolveTitle();
    final nowStr = _clockFormat.format(DateTime.now());
    final episodes = _collectEpisodes();
    final intro = widget.introController;
    final videoCtr = _videoDetailCtr;
    final liveCtr = _liveRoomCtr;

    return Positioned.fill(
      child: FocusScope(
        autofocus: true,
        child: Material(
          color: Colors.transparent,
          child: Stack(
            children: [
              // Top gradient & info bar
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: Container(
                  padding: const EdgeInsets.fromLTRB(28, 22, 28, 32),
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Color(0xDD000000),
                        Color(0x00000000),
                      ],
                    ),
                  ),
                  child: Row(
                    children: [
                      _TvHudPillButton(
                        compact: true,
                        icon: isFullScreen
                            ? Icons.fullscreen_exit_rounded
                            : Icons.close_rounded,
                        label: isFullScreen ? '退出全屏' : '关闭面板',
                        onPressed: () {
                          _hideHud();
                          if (isFullScreen) {
                            _pl.triggerFullScreen(status: false);
                          }
                        },
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Text(
                          title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      if (intro != null && intro.isShowOnlineTotal)
                        Obx(
                          () => Padding(
                            padding: const EdgeInsets.only(right: 16),
                            child: Text(
                              '${intro.total.value}人正在看',
                              style: const TextStyle(
                                color: Colors.white70,
                                fontSize: 14,
                              ),
                            ),
                          ),
                        ),
                      Text(
                        nowStr,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              // Bottom gradient, seek bar & 10-foot transport pills
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: Container(
                  padding: const EdgeInsets.fromLTRB(28, 36, 28, 24),
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.bottomCenter,
                      end: Alignment.topCenter,
                      colors: [
                        Color(0xEE000000),
                        Color(0x99000000),
                        Color(0x00000000),
                      ],
                    ),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    spacing: 14,
                    children: [
                      if (!_pl.isLive)
                        _TvSeekBar(
                          plPlayerController: _pl,
                          onSeekStep: (forward) {
                            _resetAutoHideTimer();
                            _seekRelative(forward: forward);
                          },
                        ),
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          spacing: 10,
                          children: [
                            // 1. Play / Pause
                            _TvHudPillButton(
                              focusNode: _playPauseFocusNode,
                              autofocus: true,
                              icon: _pl.playerStatus.isPlaying
                                  ? Icons.pause_rounded
                                  : Icons.play_arrow_rounded,
                              label: _pl.playerStatus.isPlaying ? '暂停' : '播放',
                              onPressed: () {
                                _resetAutoHideTimer();
                                _togglePlayPause();
                              },
                            ),
                            // 2. Fullscreen toggle (when opened in split-screen)
                            if (!isFullScreen)
                              _TvHudPillButton(
                                icon: Icons.fullscreen_rounded,
                                label: '全屏播放',
                                onPressed: () {
                                  _hideHud();
                                  _pl.triggerFullScreen(status: true);
                                },
                              ),
                            // 3. Prev / Next / Episodes
                            if (episodes.length > 1) ...[
                              _TvHudPillButton(
                                icon: Icons.skip_previous_rounded,
                                label: '上一集',
                                onPressed: () {
                                  _resetAutoHideTimer();
                                  if (!(intro?.prevPlay() ?? false)) {
                                    SmartDialog.showToast('已经是第一集了');
                                  }
                                },
                              ),
                              _TvHudPillButton(
                                icon: Icons.skip_next_rounded,
                                label: '下一集',
                                onPressed: () {
                                  _resetAutoHideTimer();
                                  if (!(intro?.nextPlay() ?? false)) {
                                    SmartDialog.showToast('已经是最后一集了');
                                  }
                                },
                              ),
                              _TvHudPillButton(
                                icon: Icons.playlist_play_rounded,
                                label: '选集 (${episodes.length})',
                                onPressed: _showEpisodeDialog,
                              ),
                            ],
                            // 4. Danmaku toggle & settings
                            Obx(() {
                              final dmOn =
                                  _pl.enableShowDanmakuAdaptive.value;
                              return _TvHudPillButton(
                                icon: dmOn
                                    ? Icons.subtitles_rounded
                                    : Icons.subtitles_off_rounded,
                                label: dmOn ? '弹幕: 开' : '弹幕: 关',
                                active: dmOn,
                                onPressed: () {
                                  _resetAutoHideTimer();
                                  _toggleDanmaku();
                                },
                              );
                            }),
                            _TvHudPillButton(
                              icon: Icons.tune_rounded,
                              label: '弹幕设置',
                              onPressed: _showDanmakuSettingsDialog,
                            ),
                            // 5. Video / Live Quality
                            if (_pl.isLive && liveCtr != null)
                              Obx(
                                () => _TvHudPillButton(
                                  icon: Icons.hd_rounded,
                                  label:
                                      '画质: ${liveCtr.currentQn.value?.desc ?? '默认'}',
                                  onPressed: _showQualityDialog,
                                ),
                              )
                            else if (videoCtr != null &&
                                !videoCtr.isFileSource)
                              Obx(
                                () => _TvHudPillButton(
                                  icon: Icons.hd_rounded,
                                  label:
                                      '画质: ${videoCtr.currentVideoQa.value?.shortDesc ?? '自动'}',
                                  onPressed: _showQualityDialog,
                                ),
                              ),
                            // 6. Playback speed
                            if (!_pl.isLive)
                              _TvHudPillButton(
                                icon: Icons.speed_rounded,
                                label: '倍速: ${_pl.playbackSpeed}x',
                                onPressed: _showSpeedDialog,
                              ),
                            // 7. Aspect Ratio / VideoFit
                            Obx(
                              () => _TvHudPillButton(
                                icon: Icons.aspect_ratio_rounded,
                                label: '画面: ${_pl.videoFit.value.desc}',
                                onPressed: _showVideoFitDialog,
                              ),
                            ),
                            // 8. Like / Hold-to-Triple-Like, Coin, Favorite
                            if (intro != null && !_pl.isLive) ...[
                              Obx(
                                () => _TvTripleLikePill(
                                  hasLike: intro.hasLike.value,
                                  tripleAnimation: intro.tripleAnimation,
                                  onStartTriple: () {
                                    _autoHideTimer?.cancel();
                                    _pl.tripling = true;
                                    intro.onStartTriple();
                                  },
                                  onCancelTriple: (isTapUp) {
                                    _pl.tripling = false;
                                    intro.onCancelTriple(isTapUp);
                                    _resetAutoHideTimer();
                                  },
                                ),
                              ),
                              Obx(
                                () => _TvHudPillButton(
                                  icon: Icons.monetization_on_rounded,
                                  label: intro.hasCoin ? '已投币' : '投币',
                                  active: intro.hasCoin,
                                  onPressed: () {
                                    _hideHud();
                                    intro.actionCoinVideo();
                                  },
                                ),
                              ),
                              Obx(
                                () => _TvHudPillButton(
                                  icon: intro.hasFav.value
                                      ? Icons.star_rounded
                                      : Icons.star_border_rounded,
                                  label: intro.hasFav.value ? '已收藏' : '收藏',
                                  active: intro.hasFav.value,
                                  onPressed: () {
                                    _hideHud();
                                    intro.showFavBottomSheet(context);
                                  },
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Focusable 10-foot seek bar that responds to Left/Right D-pad keys.
class _TvSeekBar extends StatefulWidget {
  const _TvSeekBar({
    required this.plPlayerController,
    required this.onSeekStep,
  });

  final PlPlayerController plPlayerController;
  final ValueChanged<bool> onSeekStep;

  @override
  State<_TvSeekBar> createState() => _TvSeekBarState();
}

class _TvSeekBarState extends State<_TvSeekBar> {
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Focus(
      onFocusChange: (hasFocus) => setState(() => _focused = hasFocus),
      onKeyEvent: (node, event) {
        if (event is KeyDownEvent || event is KeyRepeatEvent) {
          if (event.logicalKey == LogicalKeyboardKey.arrowLeft) {
            widget.onSeekStep(false);
            return KeyEventResult.handled;
          }
          if (event.logicalKey == LogicalKeyboardKey.arrowRight) {
            widget.onSeekStep(true);
            return KeyEventResult.handled;
          }
        }
        return KeyEventResult.ignored;
      },
      child: Obx(() {
        final posSec = widget.plPlayerController.position.value;
        final durSec = widget.plPlayerController.duration.value;
        final bufSec = widget.plPlayerController.buffered.value;
        final ratio = durSec > 0 ? (posSec / durSec).clamp(0.0, 1.0) : 0.0;
        final bufRatio = durSec > 0 ? (bufSec / durSec).clamp(0.0, 1.0) : 0.0;

        return AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: _focused ? const Color(0x44FFFFFF) : const Color(0x22000000),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: _focused ? colorScheme.primary : Colors.white12,
              width: _focused ? 2.5 : 1.0,
            ),
          ),
          child: Row(
            children: [
              Text(
                DurationUtils.formatDuration(posSec),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: SizedBox(
                  height: _focused ? 10 : 6,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(5),
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        const ColoredBox(color: Colors.white24),
                        FractionallySizedBox(
                          alignment: Alignment.centerLeft,
                          widthFactor: bufRatio,
                          child: const ColoredBox(color: Colors.white38),
                        ),
                        FractionallySizedBox(
                          alignment: Alignment.centerLeft,
                          widthFactor: ratio,
                          child: ColoredBox(color: colorScheme.primary),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Text(
                DurationUtils.formatDuration(durSec),
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 15,
                ),
              ),
              if (_focused) ...[
                const SizedBox(width: 12),
                const Text(
                  '◀ ▶ 快退/快进',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 12,
                  ),
                ),
              ],
            ],
          ),
        );
      }),
    );
  }
}

/// 10-foot pill button used across the TV player HUD and option dialogs.
class _TvHudPillButton extends StatefulWidget {
  const _TvHudPillButton({
    this.focusNode,
    this.autofocus = false,
    this.compact = false,
    this.active = false,
    this.icon,
    required this.label,
    required this.onPressed,
  });

  final FocusNode? focusNode;
  final bool autofocus;
  final bool compact;
  final bool active;
  final IconData? icon;
  final String label;
  final VoidCallback onPressed;

  @override
  State<_TvHudPillButton> createState() => _TvHudPillButtonState();
}

class _TvHudPillButtonState extends State<_TvHudPillButton> {
  bool _focused = false;

  bool _isSelectKey(LogicalKeyboardKey key) {
    return key == LogicalKeyboardKey.select ||
        key == LogicalKeyboardKey.enter ||
        key == LogicalKeyboardKey.numpadEnter ||
        key == LogicalKeyboardKey.space ||
        key == LogicalKeyboardKey.gameButtonA;
  }

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    return Focus(
      focusNode: widget.focusNode,
      autofocus: widget.autofocus,
      onFocusChange: (hasFocus) => setState(() => _focused = hasFocus),
      onKeyEvent: (node, event) {
        if (event is KeyDownEvent && _isSelectKey(event.logicalKey)) {
          widget.onPressed();
          return KeyEventResult.handled;
        }
        return KeyEventResult.ignored;
      },
      child: GestureDetector(
        onTap: widget.onPressed,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          padding: EdgeInsets.symmetric(
            horizontal: widget.compact ? 12 : 16,
            vertical: widget.compact ? 7 : 10,
          ),
          decoration: BoxDecoration(
            color: _focused
                ? primary
                : widget.active
                ? primary.withValues(alpha: 0.35)
                : const Color(0x33FFFFFF),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: _focused
                  ? Colors.white
                  : widget.active
                  ? primary
                  : Colors.white24,
              width: _focused ? 2.2 : 1.2,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            spacing: 6,
            children: [
              if (widget.icon != null)
                Icon(
                  widget.icon,
                  size: widget.compact ? 16 : 18,
                  color: Colors.white,
                ),
              Text(
                widget.label,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: widget.compact ? 13 : 14,
                  fontWeight:
                      _focused || widget.active ? FontWeight.w700 : FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Like / Hold-to-Triple-Like pill button for the 10-foot HUD.
class _TvTripleLikePill extends StatefulWidget {
  const _TvTripleLikePill({
    required this.hasLike,
    required this.tripleAnimation,
    required this.onStartTriple,
    required this.onCancelTriple,
  });

  final bool hasLike;
  final Animation<double> tripleAnimation;
  final VoidCallback onStartTriple;
  final ValueChanged<bool> onCancelTriple;

  @override
  State<_TvTripleLikePill> createState() => _TvTripleLikePillState();
}

class _TvTripleLikePillState extends State<_TvTripleLikePill> {
  bool _focused = false;
  bool _selectKeyDown = false;

  bool _isSelectKey(LogicalKeyboardKey key) {
    return key == LogicalKeyboardKey.select ||
        key == LogicalKeyboardKey.enter ||
        key == LogicalKeyboardKey.numpadEnter ||
        key == LogicalKeyboardKey.space ||
        key == LogicalKeyboardKey.gameButtonA;
  }

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    return Focus(
      onFocusChange: (hasFocus) {
        if (!hasFocus && _selectKeyDown) {
          _selectKeyDown = false;
          widget.onCancelTriple(false);
        }
        setState(() => _focused = hasFocus);
      },
      onKeyEvent: (node, event) {
        if (!_isSelectKey(event.logicalKey)) {
          return KeyEventResult.ignored;
        }
        if (event is KeyDownEvent) {
          if (!_selectKeyDown) {
            _selectKeyDown = true;
            widget.onStartTriple();
          }
          return KeyEventResult.handled;
        }
        if (event is KeyRepeatEvent) {
          return KeyEventResult.handled;
        }
        if (event is KeyUpEvent) {
          if (_selectKeyDown) {
            _selectKeyDown = false;
            widget.onCancelTriple(true);
          }
          return KeyEventResult.handled;
        }
        return KeyEventResult.ignored;
      },
      child: AnimatedBuilder(
        animation: widget.tripleAnimation,
        builder: (context, _) {
          final progress = widget.tripleAnimation.value;
          return AnimatedContainer(
            duration: const Duration(milliseconds: 120),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: _focused
                  ? primary
                  : widget.hasLike
                  ? primary.withValues(alpha: 0.35)
                  : const Color(0x33FFFFFF),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: _focused
                    ? Colors.white
                    : widget.hasLike
                    ? primary
                    : Colors.white24,
                width: _focused ? 2.2 : 1.2,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              spacing: 6,
              children: [
                if (progress > 0)
                  SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      value: progress,
                      strokeWidth: 2.2,
                      color: Colors.white,
                    ),
                  )
                else
                  Icon(
                    widget.hasLike
                        ? Icons.thumb_up_alt_rounded
                        : Icons.thumb_up_off_alt_rounded,
                    size: 18,
                    color: Colors.white,
                  ),
                Text(
                  widget.hasLike ? '已赞 (长按三连)' : '点赞 (长按三连)',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: _focused || widget.hasLike
                        ? FontWeight.w700
                        : FontWeight.w500,
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _TvDialogOptionItem {
  const _TvDialogOptionItem({
    required this.title,
    this.subtitle,
    required this.selected,
    required this.onSelect,
  });

  final String title;
  final String? subtitle;
  final bool selected;
  final VoidCallback onSelect;
}

class _TvOptionListDialog extends StatelessWidget {
  const _TvOptionListDialog({
    required this.title,
    required this.items,
  });

  final String title;
  final List<_TvDialogOptionItem> items;

  @override
  Widget build(BuildContext context) {
    final int selectedIndex = items.indexWhere((e) => e.selected);
    final int autofocusIndex = selectedIndex >= 0 ? selectedIndex : 0;

    return AlertDialog(
      backgroundColor: const Color(0xF21A1C1E),
      title: Text(
        title,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 18,
          fontWeight: FontWeight.w600,
        ),
      ),
      content: SizedBox(
        width: 480,
        height: math.min(items.length * 56.0 + 16.0, 420.0),
        child: ListView.separated(
          itemCount: items.length,
          separatorBuilder: (_, _) => const SizedBox(height: 6),
          itemBuilder: (context, index) {
            final item = items[index];
            return _TvHudPillButton(
              autofocus: index == autofocusIndex,
              active: item.selected,
              icon: item.selected
                  ? Icons.radio_button_checked_rounded
                  : Icons.radio_button_off_rounded,
              label: item.subtitle != null && item.subtitle!.isNotEmpty
                  ? '${item.title}  (${item.subtitle})'
                  : item.title,
              onPressed: item.onSelect,
            );
          },
        ),
      ),
      actions: [
        _TvHudPillButton(
          compact: true,
          label: '取消',
          onPressed: () => Navigator.of(context).pop(),
        ),
      ],
    );
  }
}
