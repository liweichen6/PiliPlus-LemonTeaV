import 'dart:async';
import 'dart:math' as math;

import 'package:PiliPlus/models/common/super_resolution_type.dart';
import 'package:PiliPlus/models/common/video/base_quality.dart';
import 'package:PiliPlus/models/video/play/url.dart' show LanguageItem;
import 'package:PiliPlus/models_new/live/live_room_play_info/codec.dart';
import 'package:PiliPlus/models_new/live/live_room_play_info/format.dart'
    as live_format;
import 'package:PiliPlus/models_new/live/live_room_play_info/stream.dart'
    as live_stream;
import 'package:PiliPlus/models_new/live/live_room_play_info/url_info.dart';
import 'package:PiliPlus/models_new/pgc/pgc_info_model/episode.dart' as pgc_ep;
import 'package:PiliPlus/common/widgets/progress_bar/segment_progress_bar.dart';
import 'package:PiliPlus/models_new/video/video_detail/episode.dart';
import 'package:PiliPlus/models_new/video/video_detail/page.dart';
import 'package:PiliPlus/models_new/video/video_play_info/subtitle.dart';
import 'package:PiliPlus/pages/common/common_intro_controller.dart';
import 'package:PiliPlus/pages/live_room/controller.dart';
import 'package:PiliPlus/pages/setting/models/play_settings.dart'
    show showPlayerVolumeDialog;
import 'package:PiliPlus/pages/video/controller.dart';
import 'package:PiliPlus/pages/video/introduction/pgc/controller.dart';
import 'package:PiliPlus/pages/video/introduction/ugc/controller.dart';
import 'package:PiliPlus/pages/video/view_point/view.dart';
import 'package:PiliPlus/pages/video/widgets/header_control.dart'
    show HeaderControlState;
import 'package:PiliPlus/pages/video/widgets/header_mixin.dart';
import 'package:PiliPlus/plugin/pl_player/controller.dart';
import 'package:PiliPlus/plugin/pl_player/models/play_repeat.dart';
import 'package:PiliPlus/plugin/pl_player/models/play_status.dart';
import 'package:PiliPlus/plugin/pl_player/models/video_fit_type.dart';
import 'package:PiliPlus/plugin/pl_player/view/view.dart' show buildDmChart;
import 'package:PiliPlus/services/shutdown_timer_service.dart'
    show shutdownTimerService;
import 'package:PiliPlus/utils/duration_utils.dart';
import 'package:PiliPlus/utils/page_utils.dart';
import 'package:PiliPlus/utils/storage.dart';
import 'package:PiliPlus/utils/storage_key.dart';
import 'package:PiliPlus/utils/storage_pref.dart';
import 'package:PiliPlus/utils/theme_utils.dart';
import 'package:collection/collection.dart';
import 'package:flutter/services.dart';
import 'package:flutter_smart_dialog/flutter_smart_dialog.dart';
import 'package:get/get.dart';
import 'package:hive_ce/hive.dart' show Box;
import 'package:material_ui/material_ui.dart';
import 'package:media_kit/media_kit.dart' show Player;

part 'tv_hud_actions.dart';
part 'tv_hud_groups.dart';
part 'tv_hud_menu.dart';

/// Self-contained 10-foot Android TV player HUD & D-pad controller.
///
/// Wraps [child] inside `PlayerFocus` when `TvPlatform.isTv` is true:
/// - In split-screen mode (`!isFullScreen` and `!_hudVisible`), renders a
///   compact top-left **Quick Strip** of two icon-only buttons (全屏, and
///   播放/暂停 showing the current state) and lets D-pad arrow keys pass
///   through to `TvFocusTraversalPolicy` so the user can freely navigate the
///   page. The remote's menu key opens the full HUD.
/// - In fullscreen mode with the HUD hidden, Select plays and pauses (holding
///   it gives 3x speed) and Left / Right seek, with hold acceleration and a
///   centered time preview.
/// - The full HUD (M14.3): the title and viewer count, the editable top-right
///   group (icon-only, at most 4) and its fixed `⋮` menu, the time bar
///   (focused first; Select, Hold-Select and Left / Right as with the HUD
///   hidden) with the 高能进度条 chart, and the editable bottom row. The
///   groups come from [TvHudGroups], the buttons from the action table in
///   `tv_hud_actions.dart`; settings panels are upstream's own (M14.2).
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
    @visibleForTesting this.debugUpstream,
    @visibleForTesting this.debugLiveRoom,
  });

  final Widget child;
  final PlPlayerController plPlayerController;
  final CommonIntroController? introController;
  final VoidCallback onSendDanmaku;
  final ValueGetter<bool>? canPlay;
  final ValueGetter<bool>? onSkipSegment;
  final VoidCallback? onRefresh;

  /// Replaces upstream's panels and dialogs in tests.
  @visibleForTesting
  final TvHudUpstream? debugUpstream;

  /// Replaces the live room's controller in tests.
  @visibleForTesting
  final LiveRoomController? debugLiveRoom;

  // Widget keys, for tests.
  static const Key timeBarKey = ValueKey<String>('tvHud:timeBar');
  static const Key dmChartKey = ValueKey<String>('tvHud:dmChart');
  static const Key segmentMarksKey = ValueKey<String>('tvHud:segmentMarks');
  static const Key chapterMarksKey = ValueKey<String>('tvHud:chapterMarks');
  static const Key titleKey = ValueKey<String>('tvHud:title');
  static const Key viewersKey = ValueKey<String>('tvHud:viewers');
  static const Key topRightGroupKey = ValueKey<String>('tvHud:topRight');
  static const Key bottomGroupKey = ValueKey<String>('tvHud:bottom');
  static const Key menuButtonKey = ValueKey<String>('tvHud:menuButton');
  static const Key menuPanelKey = ValueKey<String>('tvHud:menuPanel');
  static const Key quickFullscreenKey = ValueKey<String>('tvHud:quickFull');
  static const Key quickPlayPauseKey = ValueKey<String>('tvHud:quickPlay');
  static const Key seekPreviewKey = ValueKey<String>('tvHud:seekPreview');
  static const Key focusLabelKey = ValueKey<String>('tvHud:focusLabel');
  static const Key editorKey = ValueKey<String>('tvHud:editor');
  static const Key editorShowLabelsKey = ValueKey<String>('tvHud:editLabels');
  static const Key editorButtonsAboveBarKey = ValueKey<String>(
    'tvHud:editButtonsAboveBar',
  );
  static const Key editorResetKey = ValueKey<String>('tvHud:editReset');
  static const Key editorResetConfirmKey = ValueKey<String>(
    'tvHud:editResetConfirm',
  );
  static const Key editorDoneKey = ValueKey<String>('tvHud:editDone');
  static const Key editorHintKey = ValueKey<String>('tvHud:editHint');

  /// A TV option list (倍速, 画面比例, 选集, 字幕 and the other HUD lists).
  static const Key optionListKey = ValueKey<String>('tvHud:optionList');

  /// The row at [index] in the open option list.
  static Key optionItemKey(int index) => ValueKey<String>('tvHudOption:$index');

  /// The `⋮` menu's entry for a button ([TvHudAction.buttonId]).
  static Key menuEntryKey(String buttonId) =>
      ValueKey<String>('tvHudMenu:$buttonId');

  /// The editor's button for [id].
  static Key editorItemKey(TvHudActionId id) =>
      ValueKey<String>('tvHudEditor:${id.name}');

  @override
  State<TvPlayerHud> createState() => _TvPlayerHudState();
}

bool _isSelectKey(LogicalKeyboardKey key) {
  return key == LogicalKeyboardKey.select ||
      key == LogicalKeyboardKey.enter ||
      key == LogicalKeyboardKey.numpadEnter ||
      key == LogicalKeyboardKey.space ||
      key == LogicalKeyboardKey.gameButtonA;
}

class _TvPlayerHudState extends State<TvPlayerHud>
    with HeaderMixin<TvPlayerHud>, _TvHudActionTable {
  final FocusNode _surfaceFocusNode = FocusNode(
    debugLabel: 'TvPlayerHudSurface',
  );
  final FocusNode _timeBarFocusNode = FocusNode(debugLabel: 'TvHudTimeBar');
  final FocusNode _menuButtonFocusNode = FocusNode(debugLabel: 'TvHudMenu');

  /// The bottom row's first button, focused first where there's no time bar
  /// (live rooms).
  final FocusNode _firstBottomFocusNode = FocusNode(
    debugLabel: 'TvHudFirstBottom',
  );
  final FocusNode _quickFullscreenFocusNode = FocusNode(
    debugLabel: 'TvQuickFullscreen',
  );

  static const Duration _kLongPressSpeedDelay = Duration(milliseconds: 250);

  StreamSubscription<bool>? _fullScreenSub;
  bool _hudVisible = false;

  /// The editable groups, read when the HUD opens and when the editor closes.
  /// Observable, so each group's `Obx` always has a value to listen to, even
  /// when none of its buttons reads one (a bottom row of 倍速 alone).
  final Rx<TvHudGroups> _groups = Rx<TvHudGroups>(TvHudGroups.defaults);

  /// The `⋮` menu and the editor open over the HUD; while either is, the
  /// HUD's auto-hide is paused.
  int _openOverHud = 0;
  Timer? _autoHideTimer;
  Timer? _seekPreviewTimer;
  Timer? _longPressSpeedTimer;
  bool _selectKeyDown = false;
  bool _longPressSpeedActive = false;
  ({bool forward, String text})? _seekPreview;
  Duration? _virtualSeekTarget;
  int _consecutiveSeekSteps = 0;
  DateTime? _lastSeekKeyTime;
  bool? _lastSeekForward;

  @override
  PlPlayerController get _pl => widget.plPlayerController;

  /// For upstream's `HeaderMixin` (its danmaku panel).
  @override
  PlPlayerController get plPlayerController => widget.plPlayerController;

  @override
  bool get _hasPlayer => _pl.videoPlayerController != null;

  @override
  bool get _isFullScreen => _pl.isFullScreen.value;

  bool get _canTriggerLongPressSpeed =>
      !_pl.isLive && _hasPlayer && _pl.playerStatus.isPlaying;

  void _startLongPressSpeed() {
    _longPressSpeedTimer?.cancel();
    _longPressSpeedTimer = null;
    if (_longPressSpeedActive || !_canTriggerLongPressSpeed) return;
    _longPressSpeedActive = true;
    _pl.setLongPressStatus(true);
  }

  void _cancelSelectHold() {
    _longPressSpeedTimer?.cancel();
    _longPressSpeedTimer = null;
    _selectKeyDown = false;
    if (_longPressSpeedActive) {
      _longPressSpeedActive = false;
      _pl.setLongPressStatus(false);
    }
  }

  KeyEventResult _handleSelectKeyWithLongPressSpeed(
    KeyEvent event, {
    required VoidCallback onShortPress,
  }) {
    if (!_isSelectKey(event.logicalKey)) {
      return KeyEventResult.ignored;
    }
    if (event is KeyDownEvent) {
      if (!_selectKeyDown) {
        _selectKeyDown = true;
        _longPressSpeedActive = false;
        _longPressSpeedTimer?.cancel();
        if (_canTriggerLongPressSpeed) {
          _longPressSpeedTimer = Timer(_kLongPressSpeedDelay, () {
            if (mounted && _selectKeyDown) {
              _startLongPressSpeed();
            }
          });
        }
      }
      return KeyEventResult.handled;
    }
    if (event is KeyRepeatEvent) {
      if (_selectKeyDown) {
        _startLongPressSpeed();
      }
      return KeyEventResult.handled;
    }
    if (event is KeyUpEvent) {
      if (!_selectKeyDown) {
        return KeyEventResult.ignored;
      }
      final bool wasLongPress = _longPressSpeedActive;
      _cancelSelectHold();
      if (!wasLongPress) {
        onShortPress();
      }
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  @override
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

  @override
  LiveRoomController? get _liveRoomCtr {
    if (!_pl.isLive) return null;
    if (widget.debugLiveRoom case final LiveRoomController ctr?) return ctr;
    final tag = PlPlayerController.playOwner?.tag;
    if (tag != null && Get.isRegistered<LiveRoomController>(tag: tag)) {
      return Get.find<LiveRoomController>(tag: tag);
    }
    return null;
  }

  /// `PlPlayerController.playerStatus` is a plain field that media_kit's
  /// `playing` stream updates after a toggle was requested, so the Play/Pause
  /// label can only be refreshed from this callback.
  void _onPlayerStatusChanged(PlayerStatus status) {
    if (mounted) setState(() {});
  }

  @override
  void initState() {
    super.initState();
    _bindFullScreenListener();
    _pl.addStatusLister(_onPlayerStatusChanged);
    // Suppress upstream touch controls when fullscreen or TV HUD is active
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _pl.showControls.value = false;
      _syncFocusForMode(_isFullScreen);
    });
  }

  @override
  void didUpdateWidget(TvPlayerHud oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.plPlayerController != widget.plPlayerController) {
      _cancelSelectHold();
      _fullScreenSub?.cancel();
      _bindFullScreenListener();
      oldWidget.plPlayerController.removeStatusLister(_onPlayerStatusChanged);
      _pl.addStatusLister(_onPlayerStatusChanged);
    }
  }

  @override
  void dispose() {
    _cancelSelectHold();
    _pl.removeStatusLister(_onPlayerStatusChanged);
    _fullScreenSub?.cancel();
    _autoHideTimer?.cancel();
    _seekPreviewTimer?.cancel();
    _virtualSeekTarget = null;
    _surfaceFocusNode.dispose();
    _timeBarFocusNode.dispose();
    _menuButtonFocusNode.dispose();
    _firstBottomFocusNode.dispose();
    _quickFullscreenFocusNode.dispose();
    super.dispose();
  }

  void _bindFullScreenListener() {
    _fullScreenSub = _pl.isFullScreen.listen((bool isFullScreen) {
      if (!mounted) return;
      if (isFullScreen) {
        _pl.showControls.value = false;
      }
      setState(() {});
      if (!_hudVisible) {
        _syncFocusForMode(
          isFullScreen,
          forceSplitScreenQuickFocus: !isFullScreen,
        );
      }
    });
  }

  @override
  void _syncFocusForMode(
    bool isFullScreen, {
    bool forceSplitScreenQuickFocus = false,
  }) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _hudVisible) return;
      final ModalRoute<dynamic>? route = ModalRoute.of(context);
      if (route != null && !route.isCurrent) return;
      if (isFullScreen) {
        if (_surfaceFocusNode.canRequestFocus) {
          _surfaceFocusNode.requestFocus();
        }
      } else {
        final FocusNode? primary = FocusManager.instance.primaryFocus;
        final bool shouldFocusQuickStrip =
            forceSplitScreenQuickFocus ||
            primary == null ||
            primary == _surfaceFocusNode ||
            primary is FocusScopeNode ||
            !(primary.context?.mounted ?? false);
        if (shouldFocusQuickStrip &&
            _quickFullscreenFocusNode.canRequestFocus) {
          _quickFullscreenFocusNode.requestFocus();
        }
      }
    });
  }

  void _showHud() {
    _pl.showControls.value = false;
    if (!_hudVisible) {
      setState(() {
        _hudVisible = true;
        _groups.value = TvHudGroups.load(live: _pl.isLive);
      });
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || !_hudVisible) return;
        for (final FocusNode node in [
          _timeBarFocusNode,
          _firstBottomFocusNode,
          _menuButtonFocusNode,
        ]) {
          if (node.context != null && node.canRequestFocus) {
            node.requestFocus();
            return;
          }
        }
      });
    }
    _resetAutoHideTimer();
  }

  /// Puts focus back on the `⋮` button once the menu or the editor has closed
  /// over a HUD that's still open.
  void _returnToMenuButton() {
    if (!mounted || !_hudVisible || _openOverHud > 0) return;
    _resetAutoHideTimer();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _hudVisible && _menuButtonFocusNode.canRequestFocus) {
        _menuButtonFocusNode.requestFocus();
      }
    });
  }

  /// Opens a dialog over the HUD (the `⋮` menu or the editor) and pauses the
  /// HUD's auto-hide while it's open. [onResult] runs as soon as the dialog
  /// is popped; focus goes back to `⋮` once its route has finished closing,
  /// since the route below restores its own last focus at that point.
  Future<void> _showOverHud<T>(
    WidgetBuilder builder, {
    ValueChanged<T?>? onResult,
  }) async {
    _openOverHud++;
    _autoHideTimer?.cancel();
    final NavigatorState navigator = Navigator.of(context, rootNavigator: true);
    final DialogRoute<T> route = DialogRoute<T>(
      context: context,
      builder: builder,
      barrierColor: const Color(0x55000000),
      themes: InheritedTheme.capture(from: context, to: navigator.context),
    );
    final T? result = await navigator.push(route);
    _openOverHud--;
    if (!mounted) return;
    onResult?.call(result);
    await route.completed;
    _returnToMenuButton();
  }

  Future<void> _openMenu() => _showOverHud<TvHudAction>(
    (_) => _TvHudMenuPanel(
      source: this,
      tripleAnimation:
          widget.introController?.tripleAnimation ?? kAlwaysDismissedAnimation,
    ),
    onResult: (TvHudAction? chosen) {
      if (chosen == null) return;
      _resetAutoHideTimer();
      chosen.onPressed();
    },
  );

  @override
  Future<void> _openEditor() => _showOverHud<void>(
    (_) => _TvHudEditor(
      initial: TvHudGroups.load(live: _pl.isLive),
      onChanged: (TvHudGroups groups) => groups.store(),
    ),
    onResult: (_) =>
        setState(() => _groups.value = TvHudGroups.load(live: _pl.isLive)),
  );

  @override
  void _hideHud({bool restoreFocus = true}) {
    _autoHideTimer?.cancel();
    _cancelSelectHold();
    _virtualSeekTarget = null;
    if (_hudVisible && mounted) {
      setState(() {
        _hudVisible = false;
      });
      if (restoreFocus) {
        _syncFocusForMode(_isFullScreen, forceSplitScreenQuickFocus: true);
      }
    }
  }

  @override
  void _cancelAutoHideTimer() => _autoHideTimer?.cancel();

  @override
  void _resetAutoHideTimer() {
    _autoHideTimer?.cancel();
    if (_openOverHud > 0) return;
    _autoHideTimer = Timer(const Duration(seconds: 5), () {
      if (mounted &&
          _openOverHud == 0 &&
          !(widget.introController?.isTripling ?? false) &&
          !_longPressSpeedActive) {
        _hideHud();
      }
    });
  }

  bool _isMenuKey(LogicalKeyboardKey key) {
    return key == LogicalKeyboardKey.contextMenu ||
        key == LogicalKeyboardKey.info ||
        key == LogicalKeyboardKey.settings ||
        key == LogicalKeyboardKey.keyM;
  }

  void _togglePlayPause() {
    _virtualSeekTarget = null;
    if (_pl.isLive || (widget.canPlay?.call() ?? true)) {
      if (_hasPlayer) {
        // No setState here: the player reports its new state later and
        // _onPlayerStatusChanged rebuilds the label then.
        _pl.onDoubleTapCenter();
      }
    }
  }

  // `playerStatus` only changes once media_kit reports the new state, so a
  // toggle chosen from it is not idempotent: a second Pause inside that gap (or
  // a duplicate HDMI-CEC event) would resume. play() and pause() are.
  void _play() {
    _virtualSeekTarget = null;
    if (!_hasPlayer || !(_pl.isLive || (widget.canPlay?.call() ?? true))) {
      return;
    }
    if (_pl.playerStatus.isCompleted) {
      // Restarts from the beginning, like the Play/Pause pill does.
      _pl.onDoubleTapCenter();
    } else {
      _pl.play();
    }
  }

  void _pause() {
    _virtualSeekTarget = null;
    if (_hasPlayer) _pl.pause();
  }

  void _seekRelative({required bool forward}) {
    if (_pl.isLive || !_hasPlayer) return;
    // The binding's sampling clock is the real clock in release builds and the
    // fake clock in tests, so key cadence can be driven with pump().
    final now = WidgetsBinding.instance.samplingClock.now();
    if (_lastSeekKeyTime != null &&
        now.difference(_lastSeekKeyTime!) < const Duration(milliseconds: 450)) {
      // Reversing direction restarts the acceleration but keeps the virtual
      // target: the next step goes back from where the last one pointed, not
      // from the decoder position, which still lags behind it.
      _consecutiveSeekSteps = _lastSeekForward == forward
          ? math.min(_consecutiveSeekSteps + 1, 12)
          : 1;
    } else {
      _consecutiveSeekSteps = 1;
      _virtualSeekTarget = null;
    }
    _lastSeekKeyTime = now;
    _lastSeekForward = forward;

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
    final startPos = _virtualSeekTarget ?? state.position;
    final targetMs = (startPos + delta).inMilliseconds
        .clamp(0, math.max<int>(0, totalDuration.inMilliseconds))
        .toInt();
    final target = Duration(milliseconds: targetMs);
    _virtualSeekTarget = target;

    _pl.onForwardBackward(target);

    final posStr = DurationUtils.formatDuration(target.inSeconds);
    final durStr = DurationUtils.formatDuration(totalDuration.inSeconds);
    setState(() {
      _seekPreview = (forward: forward, text: '$posStr / $durStr');
    });
    _seekPreviewTimer?.cancel();
    _seekPreviewTimer = Timer(const Duration(milliseconds: 1400), () {
      if (mounted) {
        setState(() {
          _seekPreview = null;
          _virtualSeekTarget = null;
        });
      }
    });
  }

  KeyEventResult _handleRootKeyEvent(FocusNode node, KeyEvent event) {
    final key = event.logicalKey;

    // Media transport keys work anywhere on the player page
    if (event is KeyDownEvent) {
      // Remotes and HDMI-CEC may send dedicated Play / Pause keys: those must
      // be idempotent, only PlayPause toggles.
      if (key == LogicalKeyboardKey.mediaPlayPause) {
        _togglePlayPause();
        return KeyEventResult.handled;
      }
      if (key == LogicalKeyboardKey.mediaPlay) {
        _play();
        return KeyEventResult.handled;
      }
      if (key == LogicalKeyboardKey.mediaPause) {
        _pause();
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

    // Android dispatches Navigator.maybePop() after KEYCODE_BACK; let PopScope
    // handle LogicalKeyboardKey.goBack once so one Back press never both closes
    // the HUD/fullscreen and pops the route.
    if (key == LogicalKeyboardKey.goBack ||
        key == LogicalKeyboardKey.browserBack) {
      if (_hudVisible) {
        _resetAutoHideTimer();
      }
      return KeyEventResult.ignored;
    }

    // When the 10-foot HUD is open, reset inactivity timer on any key event
    // and let Escape close the HUD.
    if (_hudVisible) {
      _resetAutoHideTimer();
      if (event is KeyDownEvent && key == LogicalKeyboardKey.escape) {
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
    if (_isSelectKey(key)) {
      return _handleSelectKeyWithLongPressSpeed(
        event,
        onShortPress: () {
          if (_answerPrompt()) return;
          _togglePlayPause();
          _showHud();
        },
      );
    }

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
      if (key == LogicalKeyboardKey.escape) {
        _pl.triggerFullScreen(status: false);
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

  /// Select with the HUD hidden answers the oldest of upstream's prompts at
  /// the player's bottom left, as Enter does on a keyboard: a 手动跳过 segment
  /// (upstream's `onSkipSegment`), or `上次看到第XP，点击跳转`, which upstream
  /// only opens by touch and `onSkipSegment` leaves alone. Returns whether
  /// there was one.
  bool _answerPrompt() {
    if (widget.onSkipSegment?.call() ?? false) return true;
    final VideoDetailController? ctr = _videoDetailCtr;
    if (ctr == null) return false;
    try {
      if (ctr.listData.lastOrNull case final int index) {
        if (widget.introController case final UgcIntroController intro) {
          final List<Part>? pages = intro.videoDetail.value.pages;
          if (pages != null && index >= 0 && index < pages.length) {
            intro.onChangeEpisode(pages[index]);
            SmartDialog.showToast('已跳至第${index + 1}P');
          }
        }
        ctr.onRemoveItem(ctr.listData.indexOf(index), index);
        return true;
      }
    } catch (_) {}
    return false;
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

  @override
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

  @override
  Future<void> _showTvDialog(Widget Function(BuildContext) builder) async {
    _hideHud(restoreFocus: false);
    await showDialog<void>(
      context: context,
      builder: builder,
    );
    if (mounted) {
      _syncFocusForMode(_isFullScreen, forceSplitScreenQuickFocus: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isFullScreen = _isFullScreen;
    final seekPreview = _seekPreview;
    return PopScope(
      canPop: !_hudVisible,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && _hudVisible) {
          _hideHud();
        }
      },
      child: Focus(
        focusNode: _surfaceFocusNode,
        autofocus: isFullScreen,
        skipTraversal: !isFullScreen || _hudVisible,
        onFocusChange: (hasFocus) {
          if (!hasFocus) {
            _cancelSelectHold();
          }
        },
        onKeyEvent: _handleRootKeyEvent,
        child: Stack(
          fit: StackFit.passthrough,
          children: [
            ExcludeFocus(
              excluding: isFullScreen || _hudVisible,
              child: widget.child,
            ),
            // Split-screen quick control strip so D-pad users can enter
            // fullscreen, play/pause, or navigate down the page.
            if (!isFullScreen && !_hudVisible) _buildSplitScreenQuickStrip(),
            // Centered OSD seek preview banner
            if (seekPreview != null)
              IgnorePointer(
                child: Center(
                  child: Container(
                    key: TvPlayerHud.seekPreviewKey,
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
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      spacing: 10,
                      children: [
                        Icon(
                          seekPreview.forward
                              ? Icons.fast_forward_rounded
                              : Icons.fast_rewind_rounded,
                          color: Colors.white,
                          size: 28,
                        ),
                        Text(
                          seekPreview.text,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            decoration: TextDecoration.none,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            // Full 10-foot TV HUD overlay
            if (_hudVisible) _buildFullHudOverlay(),
          ],
        ),
      ),
    );
  }

  bool get _isPlaying => _pl.playerStatus.isPlaying;

  void _enterFullScreen() {
    if (!_pl.isLive && !(widget.canPlay?.call() ?? true)) {
      return;
    }
    _pl.triggerFullScreen(status: true);
  }

  Widget _buildSplitScreenQuickStrip() {
    final topPadding = MediaQuery.paddingOf(context).top;
    final bool playing = _isPlaying;
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
                key: TvPlayerHud.quickFullscreenKey,
                focusNode: _quickFullscreenFocusNode,
                autofocus: true,
                compact: true,
                iconOnly: true,
                icon: Icons.fullscreen_rounded,
                label: '全屏',
                onKeyEvent: (_, event) => _handleSelectKeyWithLongPressSpeed(
                  event,
                  onShortPress: _enterFullScreen,
                ),
                onFocusLost: _cancelSelectHold,
                onPressed: _enterFullScreen,
              ),
              _TvHudPillButton(
                key: TvPlayerHud.quickPlayPauseKey,
                compact: true,
                iconOnly: true,
                icon: playing ? Icons.pause_rounded : Icons.play_arrow_rounded,
                label: playing ? '暂停' : '播放',
                onKeyEvent: (_, event) => _handleSelectKeyWithLongPressSpeed(
                  event,
                  onShortPress: _togglePlayPause,
                ),
                onFocusLost: _cancelSelectHold,
                onPressed: _togglePlayPause,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildActionButton(
    TvHudAction action, {
    required bool iconOnly,
    bool compact = false,
    bool labelAbove = false,
    FocusNode? focusNode,
  }) {
    if (action.onHoldStart != null && action.onHoldEnd != null) {
      final Animation<double>? tripleAnimation =
          widget.introController?.tripleAnimation;
      return _TvTripleLikePill(
        key: action.key,
        focusNode: focusNode,
        compact: compact,
        iconOnly: iconOnly,
        labelAbove: labelAbove,
        icon: action.icon,
        label: action.label,
        active: action.active,
        tripleAnimation: tripleAnimation ?? kAlwaysDismissedAnimation,
        onStartTriple: action.onHoldStart!,
        onCancelTriple: action.onHoldEnd!,
      );
    }
    return _TvHudPillButton(
      key: action.key,
      focusNode: focusNode,
      compact: compact,
      iconOnly: iconOnly,
      labelAbove: labelAbove,
      icon: action.icon,
      label: action.label,
      active: action.active,
      onPressed: () {
        _resetAutoHideTimer();
        action.onPressed();
      },
    );
  }

  /// The time bar's keys, as with the HUD hidden: Select plays and pauses,
  /// holding it gives 3x speed, Left and Right seek. Up and Down navigate.
  KeyEventResult _handleTimeBarKey(FocusNode node, KeyEvent event) {
    final key = event.logicalKey;
    if (_isSelectKey(key)) {
      return _handleSelectKeyWithLongPressSpeed(
        event,
        onShortPress: () {
          _resetAutoHideTimer();
          _togglePlayPause();
        },
      );
    }
    if (event is KeyDownEvent || event is KeyRepeatEvent) {
      if (key == LogicalKeyboardKey.arrowLeft ||
          key == LogicalKeyboardKey.arrowRight) {
        _resetAutoHideTimer();
        _seekRelative(forward: key == LogicalKeyboardKey.arrowRight);
        return KeyEventResult.handled;
      }
    }
    return KeyEventResult.ignored;
  }

  /// The line under a live room's title: the streamer, the viewer count and
  /// the 高能观众 count, as upstream's fullscreen header shows them; `null`
  /// until any of them has loaded.
  static String? _liveInfoLine(LiveRoomController liveCtr) {
    final String? upName =
        liveCtr.roomInfoH5.value?.anchorInfo?.baseInfo?.uname;
    final String? watched = liveCtr.watchedShow.value;
    final String? online = liveCtr.onlineCount.value;
    final List<String> parts = [
      if (upName != null && upName.isNotEmpty) upName,
      if (watched != null && watched.isNotEmpty) watched,
      if (online != null && online.isNotEmpty) '高能观众($online)',
    ];
    return parts.isEmpty ? null : parts.join(' · ');
  }

  Widget _buildTopBar() {
    final title = _resolveTitle();
    final intro = widget.introController;
    final bool hasViewers = intro != null && intro.isShowOnlineTotal;
    final LiveRoomController? liveCtr = _liveRoomCtr;
    return Container(
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
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: 16,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              spacing: 2,
              children: [
                // Up to three lines; `…` only when three can't hold it.
                Text(
                  title,
                  key: TvPlayerHud.titleKey,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (liveCtr != null)
                  Obx(() {
                    final String? line = _liveInfoLine(liveCtr);
                    if (line == null) return const SizedBox.shrink();
                    return Text(
                      line,
                      key: TvPlayerHud.viewersKey,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 13,
                      ),
                    );
                  })
                else if (hasViewers)
                  Obx(
                    () => Text(
                      '${intro.total.value}人正在看',
                      key: TvPlayerHud.viewersKey,
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 13,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          // One Obx for the group: the actions' labels and availability read
          // the controllers' Rx values.
          Obx(_buildTopRightGroup),
        ],
      ),
    );
  }

  /// The top-right group: rows of [TvHudGroups.topRightRowSize] buttons,
  /// aligned right, with `⋮` taking the first row's last place (the user,
  /// 2026-11-07). The episode entry stands for up to three buttons, so a
  /// full group can spill into a fourth row.
  Widget _buildTopRightGroup() {
    final List<Widget> buttons = [
      for (final TvHudActionId id in _groups.value.topRight)
        for (final TvHudAction action in resolveAction(id))
          _buildActionButton(action, iconOnly: true, compact: true),
    ];
    const int rowSize = TvHudGroups.topRightRowSize;
    final List<List<Widget>> rows = [
      [
        ...buttons.take(rowSize - 1),
        _TvHudPillButton(
          key: TvPlayerHud.menuButtonKey,
          focusNode: _menuButtonFocusNode,
          compact: true,
          iconOnly: true,
          icon: Icons.more_vert_rounded,
          label: '更多',
          onPressed: _openMenu,
        ),
      ],
      for (int i = rowSize - 1; i < buttons.length; i += rowSize)
        buttons.sublist(i, math.min(i + rowSize, buttons.length)),
    ];
    return Column(
      key: TvPlayerHud.topRightGroupKey,
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      spacing: 8,
      children: [
        for (final List<Widget> row in rows)
          Row(mainAxisSize: MainAxisSize.min, spacing: 8, children: row),
      ],
    );
  }

  Widget _buildBottomRow() {
    final bool iconOnly = !_groups.value.showLabels;
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      // One Obx for the row: the actions' labels and availability read the
      // controllers' Rx values.
      child: Obx(() {
        final List<TvHudAction> actions = [
          for (final TvHudActionId id in _groups.value.bottom)
            ...resolveAction(id),
        ];
        return Row(
          key: TvPlayerHud.bottomGroupKey,
          spacing: 10,
          children: [
            for (int i = 0; i < actions.length; i++)
              _buildActionButton(
                actions[i],
                iconOnly: iconOnly,
                // Above the time bar, a label under the button would cover
                // the bar's position.
                labelAbove: _groups.value.buttonsAboveBar,
                focusNode: i == 0 ? _firstBottomFocusNode : null,
              ),
          ],
        );
      }),
    );
  }

  Widget _buildFullHudOverlay() {
    final VideoDetailController? videoDetailCtr = _isVideo
        ? _videoDetailCtr
        : null;
    return Positioned.fill(
      child: FocusScope(
        autofocus: true,
        child: Material(
          color: Colors.transparent,
          child: Stack(
            children: [
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: _buildTopBar(),
              ),
              // Bottom gradient, time bar & bottom row
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: Container(
                  // Icon-only buttons draw their label under them, so a
                  // bottom row at the very bottom needs the room.
                  padding: EdgeInsets.fromLTRB(
                    28,
                    36,
                    28,
                    _groups.value.showLabels || _groups.value.buttonsAboveBar
                        ? 24
                        : 34,
                  ),
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
                    // `按钮在时间条上方` puts the bottom row first.
                    verticalDirection: _groups.value.buttonsAboveBar
                        ? VerticalDirection.up
                        : VerticalDirection.down,
                    children: [
                      if (!_pl.isLive)
                        _TvTimeBar(
                          key: TvPlayerHud.timeBarKey,
                          focusNode: _timeBarFocusNode,
                          plPlayerController: _pl,
                          isPlaying: _isPlaying,
                          onKeyEvent: _handleTimeBarKey,
                          onFocusLost: _cancelSelectHold,
                          chart: videoDetailCtr == null
                              ? null
                              : _TvDmChart(
                                  key: TvPlayerHud.dmChartKey,
                                  plPlayerController: _pl,
                                  videoDetailController: videoDetailCtr,
                                ),
                          segments: videoDetailCtr == null
                              ? null
                              : _TvSegmentMarks(
                                  key: TvPlayerHud.segmentMarksKey,
                                  plPlayerController: _pl,
                                  videoDetailController: videoDetailCtr,
                                ),
                          chapters: videoDetailCtr == null
                              ? null
                              : _TvChapterMarks(
                                  key: TvPlayerHud.chapterMarksKey,
                                  plPlayerController: _pl,
                                  videoDetailController: videoDetailCtr,
                                ),
                        ),
                      _buildBottomRow(),
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

/// Upstream's 高能进度条 (`buildDmChart`), shown while its setting and the
/// HUD's switch are on and the data has loaded. Its own widget behind a
/// [RepaintBoundary], outside the bar's position `Obx`, so the position
/// updates neither rebuild nor repaint it.
class _TvDmChart extends StatelessWidget {
  const _TvDmChart({
    super.key,
    required this.plPlayerController,
    required this.videoDetailController,
  });

  final PlPlayerController plPlayerController;
  final VideoDetailController videoDetailController;

  @override
  Widget build(BuildContext context) {
    final Color primary = Theme.of(context).colorScheme.primary;
    return RepaintBoundary(
      child: Obx(() {
        final bool show =
            videoDetailController.showDmTrendChart.value &&
            plPlayerController.showDmChart;
        final List<double>? data =
            videoDetailController.dmTrend.value?.dataOrNull;
        if (!show || data == null || data.isEmpty) {
          return const SizedBox.shrink();
        }
        return buildDmChart(primary, data, videoDetailController);
      }),
    );
  }
}

/// SponsorBlock's segments (and Bilibili's own 片头 / 片尾 for PGC), under the
/// bar in their category colors, shown under upstream's conditions (its
/// bottom bar's `SegmentProgressBar`). Behind a [RepaintBoundary] like the
/// chart, so the bar's position updates don't repaint it.
class _TvSegmentMarks extends StatelessWidget {
  const _TvSegmentMarks({
    super.key,
    required this.plPlayerController,
    required this.videoDetailController,
  });

  final PlPlayerController plPlayerController;
  final VideoDetailController videoDetailController;

  @override
  Widget build(BuildContext context) {
    if (!plPlayerController.enableBlock) return const SizedBox.shrink();
    return RepaintBoundary(
      child: Obx(() {
        final List<Segment> segments = videoDetailController.segmentProgressList
            .toList();
        if (segments.isEmpty) return const SizedBox.shrink();
        return SegmentProgressBar(height: 4, segments: segments);
      }),
    );
  }
}

/// The uploader's chapters (分段信息) over the bar, with their titles, as
/// upstream's bar draws them (`ViewPointSegmentProgressBar`), while its
/// `showViewPoints` setting and the chapter switch are on.
class _TvChapterMarks extends StatelessWidget {
  const _TvChapterMarks({
    super.key,
    required this.plPlayerController,
    required this.videoDetailController,
  });

  final PlPlayerController plPlayerController;
  final VideoDetailController videoDetailController;

  @override
  Widget build(BuildContext context) {
    if (!plPlayerController.showViewPoints) return const SizedBox.shrink();
    return RepaintBoundary(
      child: Obx(() {
        final List<ViewPointSegment> chapters = videoDetailController
            .viewPointList
            .toList();
        if (chapters.isEmpty || !videoDetailController.showVP.value) {
          return const SizedBox.shrink();
        }
        // The dividers reach down across the bar (see the time bar's stack).
        return ViewPointSegmentProgressBar(height: 13, segments: chapters);
      }),
    );
  }
}

/// The time bar: the play/pause status icon, the position, the bar and the
/// duration. It's the HUD's first focus; [onKeyEvent] gives it the keys.
class _TvTimeBar extends StatefulWidget {
  const _TvTimeBar({
    super.key,
    required this.focusNode,
    required this.plPlayerController,
    required this.isPlaying,
    required this.onKeyEvent,
    required this.onFocusLost,
    this.chart,
    this.segments,
    this.chapters,
  });

  final FocusNode focusNode;
  final PlPlayerController plPlayerController;
  final bool isPlaying;
  final FocusOnKeyEventCallback onKeyEvent;
  final VoidCallback onFocusLost;

  /// Drawn over the bar.
  final Widget? chart;

  /// Drawn just under the bar.
  final Widget? segments;

  /// A strip just over the bar, with dividers down across it.
  final Widget? chapters;

  @override
  State<_TvTimeBar> createState() => _TvTimeBarState();
}

class _TvTimeBarState extends State<_TvTimeBar> {
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final Widget? chart = widget.chart;
    final Widget? segments = widget.segments;
    final Widget? chapters = widget.chapters;
    final double barHeight = _focused ? 10 : 6;
    return Focus(
      focusNode: widget.focusNode,
      autofocus: true,
      onFocusChange: (hasFocus) {
        setState(() => _focused = hasFocus);
        if (!hasFocus) widget.onFocusLost();
      },
      onKeyEvent: widget.onKeyEvent,
      child: AnimatedContainer(
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
            Icon(
              widget.isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
              color: Colors.white,
              size: 22,
            ),
            const SizedBox(width: 10),
            Obx(
              () => Text(
                DurationUtils.formatDuration(
                  widget.plPlayerController.position.value,
                ),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: SizedBox(
                height: 10,
                child: Stack(
                  clipBehavior: Clip.none,
                  alignment: Alignment.center,
                  children: [
                    if (chart != null)
                      Positioned(
                        left: 0,
                        right: 0,
                        bottom: 5,
                        child: chart,
                      ),
                    SizedBox(
                      height: barHeight,
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(5),
                        child: Obx(() {
                          final pl = widget.plPlayerController;
                          final posSec = pl.position.value;
                          final durSec = pl.duration.value;
                          final bufSec = pl.buffered.value;
                          final ratio = durSec > 0
                              ? (posSec / durSec).clamp(0.0, 1.0)
                              : 0.0;
                          final bufRatio = durSec > 0
                              ? (bufSec / durSec).clamp(0.0, 1.0)
                              : 0.0;
                          return Stack(
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
                          );
                        }),
                      ),
                    ),
                    // In the box's padding, 2 px under the 10 px bar.
                    if (segments != null)
                      Positioned(
                        left: 0,
                        right: 0,
                        top: 12,
                        child: segments,
                      ),
                    // A 15 px strip ending 3 px over the bar; its dividers
                    // (13 px) reach down to the bar's bottom.
                    if (chapters != null)
                      Positioned(
                        left: 0,
                        right: 0,
                        bottom: 13,
                        child: chapters,
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 14),
            Obx(
              () => Text(
                DurationUtils.formatDuration(
                  widget.plPlayerController.duration.value,
                ),
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 15,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The name of a focused icon-only button, drawn under it in the overlay so
/// the row around it doesn't re-lay out on each step (agreed with the user,
/// 2026-11-07).
mixin _TvFocusLabelHost<T extends StatefulWidget> on State<T> {
  final OverlayPortalController _labelPortal = OverlayPortalController();
  final LayerLink _labelLink = LayerLink();

  @override
  void initState() {
    super.initState();
    // Always attached; the overlay child is empty unless focused.
    _labelPortal.show();
  }

  Widget _withFocusLabel({
    required bool iconOnly,
    required bool focused,
    required String label,
    required Widget child,
    bool above = false,
  }) {
    if (!iconOnly) return child;
    return CompositedTransformTarget(
      link: _labelLink,
      child: OverlayPortal(
        controller: _labelPortal,
        overlayChildBuilder: (_) => !focused
            ? const SizedBox.shrink()
            : Align(
                alignment: Alignment.topLeft,
                child: CompositedTransformFollower(
                  link: _labelLink,
                  showWhenUnlinked: false,
                  targetAnchor: above
                      ? Alignment.topCenter
                      : Alignment.bottomCenter,
                  followerAnchor: above
                      ? Alignment.bottomCenter
                      : Alignment.topCenter,
                  offset: Offset(0, above ? -6 : 6),
                  child: IgnorePointer(
                    child: Container(
                      key: TvPlayerHud.focusLabelKey,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xE6000000),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        label,
                        maxLines: 1,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          decoration: TextDecoration.none,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
        child: child,
      ),
    );
  }
}

BoxDecoration _pillDecoration({
  required Color primary,
  required bool focused,
  required bool active,
}) => BoxDecoration(
  color: focused
      ? primary
      : active
      ? primary.withValues(alpha: 0.35)
      : const Color(0x33FFFFFF),
  borderRadius: BorderRadius.circular(24),
  border: Border.all(
    color: focused
        ? Colors.white
        : active
        ? primary
        : Colors.white24,
    width: focused ? 2.2 : 1.2,
  ),
);

/// The pill's padding. The focused border is 1 px wider on each side, so the
/// padding gives that pixel back: a pill keeps its size when focused, and the
/// row around it doesn't move.
EdgeInsets _pillPadding({
  required bool compact,
  required bool iconOnly,
  required bool focused,
}) {
  final double extra = focused ? 0 : 1;
  return iconOnly
      ? EdgeInsets.all((compact ? 7 : 10) + extra)
      : EdgeInsets.symmetric(
          horizontal: (compact ? 12 : 16) + extra,
          vertical: (compact ? 7 : 10) + extra,
        );
}

/// 10-foot pill button used across the TV player HUD and option dialogs.
class _TvHudPillButton extends StatefulWidget {
  const _TvHudPillButton({
    super.key,
    this.focusNode,
    this.autofocus = false,
    this.compact = false,
    this.iconOnly = false,
    this.labelAbove = false,
    this.active = false,
    this.alignment,
    this.icon,
    this.onKeyEvent,
    this.onFocusLost,
    required this.label,
    required this.onPressed,
  });

  final FocusNode? focusNode;
  final bool autofocus;
  final bool compact;

  /// Draws the icon alone, with [label] under it while focused.
  final bool iconOnly;

  /// Draws the focus label above the button instead of under it.
  final bool labelAbove;
  final bool active;

  /// Aligns the label inside a pill that is laid out with tight constraints,
  /// such as the fixed-height rows of the option list dialog.
  final AlignmentGeometry? alignment;
  final IconData? icon;
  final FocusOnKeyEventCallback? onKeyEvent;
  final VoidCallback? onFocusLost;
  final String label;
  final VoidCallback onPressed;

  @override
  State<_TvHudPillButton> createState() => _TvHudPillButtonState();
}

class _TvHudPillButtonState extends State<_TvHudPillButton>
    with _TvFocusLabelHost {
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    final bool iconOnly = widget.iconOnly && widget.icon != null;
    return Focus(
      focusNode: widget.focusNode,
      autofocus: widget.autofocus,
      onFocusChange: (hasFocus) {
        setState(() => _focused = hasFocus);
        if (!hasFocus) {
          widget.onFocusLost?.call();
        }
      },
      onKeyEvent: (node, event) {
        if (widget.onKeyEvent != null) {
          return widget.onKeyEvent!(node, event);
        }
        if (event is KeyDownEvent && _isSelectKey(event.logicalKey)) {
          widget.onPressed();
          return KeyEventResult.handled;
        }
        return KeyEventResult.ignored;
      },
      // Pointer taps only. In directional mode the patched GestureDetector adds
      // a Focus of its own that D-pad traversal prefers over the Focus above
      // and whose key-down handler runs first, which would fire onTap on key
      // down and starve the Hold-Select handler (R8).
      child: _withFocusLabel(
        iconOnly: iconOnly,
        focused: _focused,
        label: widget.label,
        above: widget.labelAbove,
        child: ExcludeFocus(
          child: GestureDetector(
            onTap: widget.onPressed,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 120),
              alignment: widget.alignment,
              padding: _pillPadding(
                compact: widget.compact,
                iconOnly: iconOnly,
                focused: _focused,
              ),
              decoration: _pillDecoration(
                primary: primary,
                focused: _focused,
                active: widget.active,
              ),
              child: iconOnly
                  ? Icon(
                      widget.icon,
                      size: widget.compact ? 20 : 22,
                      color: Colors.white,
                    )
                  : Row(
                      mainAxisSize: MainAxisSize.min,
                      spacing: 6,
                      children: [
                        if (widget.icon != null)
                          Icon(
                            widget.icon,
                            size: widget.compact ? 16 : 18,
                            color: Colors.white,
                          ),
                        _pillLabel(
                          widget.label,
                          compact: widget.compact,
                          bold: _focused || widget.active,
                          bounded: widget.alignment != null,
                        ),
                      ],
                    ),
            ),
          ),
        ),
      ),
    );
  }
}

/// A pill's label. A [bounded] pill (one with an alignment: an option list
/// or menu row) has a bounded width, so a long label (切换路线's hosts, a
/// large text scale) ends in `…` there instead of overflowing.
Widget _pillLabel(
  String label, {
  required bool compact,
  required bool bold,
  required bool bounded,
}) {
  final Text text = Text(
    label,
    maxLines: bounded ? 1 : null,
    overflow: bounded ? TextOverflow.ellipsis : null,
    style: TextStyle(
      color: Colors.white,
      fontSize: compact ? 13 : 14,
      fontWeight: bold ? FontWeight.w700 : FontWeight.w500,
    ),
  );
  return bounded ? Flexible(child: text) : text;
}

/// Like / Hold-to-Triple-Like pill button for the 10-foot HUD.
class _TvTripleLikePill extends StatefulWidget {
  const _TvTripleLikePill({
    super.key,
    this.focusNode,
    this.autofocus = false,
    this.compact = false,
    this.iconOnly = false,
    this.labelAbove = false,
    this.alignment,
    required this.icon,
    required this.label,
    required this.active,
    required this.tripleAnimation,
    required this.onStartTriple,
    required this.onCancelTriple,
  });

  final FocusNode? focusNode;
  final bool autofocus;
  final bool compact;
  final bool iconOnly;
  final bool labelAbove;
  final AlignmentGeometry? alignment;
  final IconData icon;
  final String label;
  final bool active;
  final Animation<double> tripleAnimation;
  final VoidCallback onStartTriple;
  final ValueChanged<bool> onCancelTriple;

  @override
  State<_TvTripleLikePill> createState() => _TvTripleLikePillState();
}

class _TvTripleLikePillState extends State<_TvTripleLikePill>
    with _TvFocusLabelHost {
  bool _focused = false;
  bool _selectKeyDown = false;

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    final bool iconOnly = widget.iconOnly;
    final double iconSize = iconOnly
        ? (widget.compact ? 20 : 22)
        : (widget.compact ? 16 : 18);
    return Focus(
      focusNode: widget.focusNode,
      autofocus: widget.autofocus,
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
      child: _withFocusLabel(
        iconOnly: iconOnly,
        focused: _focused,
        label: widget.label,
        above: widget.labelAbove,
        child: AnimatedBuilder(
          animation: widget.tripleAnimation,
          builder: (context, _) {
            final progress = widget.tripleAnimation.value;
            final Widget icon = progress > 0
                ? SizedBox(
                    width: iconSize,
                    height: iconSize,
                    child: CircularProgressIndicator(
                      value: progress,
                      strokeWidth: 2.2,
                      color: Colors.white,
                    ),
                  )
                : Icon(widget.icon, size: iconSize, color: Colors.white);
            return AnimatedContainer(
              duration: const Duration(milliseconds: 120),
              alignment: widget.alignment,
              padding: _pillPadding(
                compact: widget.compact,
                iconOnly: iconOnly,
                focused: _focused,
              ),
              decoration: _pillDecoration(
                primary: primary,
                focused: _focused,
                active: widget.active,
              ),
              child: iconOnly
                  ? icon
                  : Row(
                      mainAxisSize: MainAxisSize.min,
                      spacing: 6,
                      children: [
                        icon,
                        _pillLabel(
                          widget.label,
                          compact: widget.compact,
                          bold: _focused || widget.active,
                          bounded: widget.alignment != null,
                        ),
                      ],
                    ),
            );
          },
        ),
      ),
    );
  }
}

class _TvDialogOptionItem {
  const _TvDialogOptionItem({
    required this.title,
    this.icon,
    required this.selected,
    required this.onSelect,
  }) : isHeader = false;

  /// A group title between rows (切换路线's `协议 · 格式`); not focusable.
  const _TvDialogOptionItem.header(this.title)
    : icon = null,
      selected = false,
      onSelect = _noop,
      isHeader = true;

  static void _noop() {}

  final bool isHeader;

  final String title;

  /// Replaces the radio icon, for a row that opens something instead of
  /// choosing an option (such as `字幕设置` at the end of the track list).
  final IconData? icon;
  final bool selected;
  final VoidCallback onSelect;
}

class _TvOptionListDialog extends StatefulWidget {
  const _TvOptionListDialog({
    required this.title,
    required this.items,
  });

  final String title;
  final List<_TvDialogOptionItem> items;

  @override
  State<_TvOptionListDialog> createState() => _TvOptionListDialogState();
}

class _TvOptionListDialogState extends State<_TvOptionListDialog> {
  /// Smallest row height (pill plus a 6 px gap), used at normal text sizes.
  static const double _kMinItemExtent = 52.0;
  static const double _kMaxListHeight = 420.0;

  /// The pill's vertical padding, its focused border on both sides, and the
  /// gap between rows. The label row is added on top, measured.
  static const double _kRowChrome = 2 * 10.0 + 2 * 2.2 + 6.0;

  /// Rows have a fixed height: a lazy list only builds the rows near its
  /// viewport, so the current option's `autofocus` can only fire if the list
  /// starts scrolled to it, which needs known row positions. The height is
  /// measured from the label's real text style and text scale (the font size
  /// setting goes up to 1.6x), so a large label is never clipped.
  late double _itemExtent;
  late double _listHeight;
  ScrollController? _scrollController;

  int get _autofocusIndex {
    final int selectedIndex = widget.items.indexWhere((e) => e.selected);
    if (selectedIndex >= 0) return selectedIndex;
    return math.max(0, widget.items.indexWhere((e) => !e.isHeader));
  }

  /// Measures the row height once, with the text style the pill labels inherit
  /// inside the dialog ([contentContext]), and starts the list scrolled so
  /// the autofocus row is in the middle of the viewport.
  ScrollController _ensureLayout(BuildContext contentContext) {
    final ScrollController? existing = _scrollController;
    if (existing != null) return existing;

    final TextPainter painter = TextPainter(
      text: TextSpan(
        text: '国Ag',
        style: DefaultTextStyle.of(contentContext).style.merge(
          const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
        ),
      ),
      textDirection: TextDirection.ltr,
      textScaler: MediaQuery.textScalerOf(contentContext),
      maxLines: 1,
    )..layout();
    final double labelHeight = math.max(18.0, painter.height);
    painter.dispose();

    _itemExtent = math.max(
      _kMinItemExtent,
      (_kRowChrome + labelHeight).ceilToDouble(),
    );
    _listHeight = math.min(widget.items.length * _itemExtent, _kMaxListHeight);
    final double maxOffset = math.max(
      0.0,
      widget.items.length * _itemExtent - _listHeight,
    );
    final double centered =
        _autofocusIndex * _itemExtent - (_listHeight - _itemExtent) / 2;
    return _scrollController = ScrollController(
      initialScrollOffset: centered.clamp(0.0, maxOffset),
    );
  }

  @override
  void dispose() {
    _scrollController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final items = widget.items;
    final int autofocusIndex = _autofocusIndex;

    return AlertDialog(
      key: TvPlayerHud.optionListKey,
      backgroundColor: const Color(0xF21A1C1E),
      title: Text(
        widget.title,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 18,
          fontWeight: FontWeight.w600,
        ),
      ),
      content: Builder(
        builder: (BuildContext contentContext) {
          final ScrollController controller = _ensureLayout(contentContext);
          return SizedBox(
            width: 480,
            height: _listHeight,
            child: ListView.builder(
              controller: controller,
              itemExtent: _itemExtent,
              itemCount: items.length,
              itemBuilder: (context, index) {
                final item = items[index];
                if (item.isHeader) {
                  return Align(
                    key: TvPlayerHud.optionItemKey(index),
                    alignment: Alignment.bottomLeft,
                    child: Padding(
                      padding: const EdgeInsets.only(left: 4, bottom: 6),
                      child: Text(
                        item.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  );
                }
                return Padding(
                  key: TvPlayerHud.optionItemKey(index),
                  padding: const EdgeInsets.symmetric(vertical: 3),
                  child: _TvHudPillButton(
                    autofocus: index == autofocusIndex,
                    active: item.selected,
                    alignment: Alignment.centerLeft,
                    icon:
                        item.icon ??
                        (item.selected
                            ? Icons.radio_button_checked_rounded
                            : Icons.radio_button_off_rounded),
                    label: item.title,
                    onPressed: item.onSelect,
                  ),
                );
              },
            ),
          );
        },
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
