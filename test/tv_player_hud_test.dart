import 'dart:async';
import 'dart:io';

import 'package:PiliPlus/common/widgets/progress_bar/segment_progress_bar.dart'
    show
        Segment,
        SegmentProgressBar,
        ViewPointSegment,
        ViewPointSegmentProgressBar;
import 'package:PiliPlus/common/widgets/scaffold/mini_scaffold.dart';
import 'package:PiliPlus/common/widgets/scaffold/simple_scaffold.dart';
import 'package:PiliPlus/http/loading_state.dart';
import 'package:PiliPlus/models/common/super_resolution_type.dart';
import 'package:PiliPlus/models/common/video/base_quality.dart';
import 'package:PiliPlus/models/user/danmaku_rule.dart';
import 'package:PiliPlus/models_new/video/video_detail/data.dart';
import 'package:PiliPlus/models_new/video/video_detail/episode.dart';
import 'package:PiliPlus/models_new/video/video_detail/page.dart';
import 'package:PiliPlus/models/video/play/url.dart' as play_url;
import 'package:PiliPlus/models_new/video/video_play_info/subtitle.dart';
import 'package:PiliPlus/pages/danmaku/danmaku_model.dart';
import 'package:PiliPlus/pages/video/controller.dart';
import 'package:PiliPlus/pages/video/introduction/ugc/controller.dart';
import 'package:PiliPlus/pages/video/widgets/header_control.dart'
    show TimeBatteryMixin;
import 'package:PiliPlus/plugin/pl_player/controller.dart';
import 'package:PiliPlus/plugin/pl_player/models/play_repeat.dart';
import 'package:PiliPlus/plugin/pl_player/models/play_status.dart';
import 'package:PiliPlus/plugin/pl_player/models/video_fit_type.dart';
import 'package:PiliPlus/tv/tv_navigation.dart';
import 'package:PiliPlus/tv/tv_platform.dart';
import 'package:PiliPlus/tv/tv_player_hud.dart';
import 'package:PiliPlus/utils/page_utils.dart';
import 'package:PiliPlus/utils/storage.dart';
import 'package:PiliPlus/utils/storage_key.dart';
import 'package:canvas_danmaku/canvas_danmaku.dart';
import 'package:fl_chart/fl_chart.dart' show LineChart;
import 'package:flutter/rendering.dart' show RenderParagraph;
import 'package:flutter/services.dart';
import 'package:flutter_smart_dialog/flutter_smart_dialog.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:hive_ce/hive.dart';
import 'package:material_ui/material_ui.dart';
import 'package:media_kit/media_kit.dart' hide Subtitle;

import 'tv_path_harness.dart';

class FakePlayerState extends Fake implements PlayerState {
  @override
  Duration position = const Duration(seconds: 30);

  @override
  Duration duration = const Duration(seconds: 300);
}

class FakePlayer extends Fake implements Player {
  final FakePlayerState playerState = FakePlayerState();

  @override
  PlayerState get state => playerState;
}

class FakePlPlayerController extends Fake implements PlPlayerController {
  final FakePlayer fakePlayer = FakePlayer();

  @override
  bool enableBlock = false;

  @override
  Player? get videoPlayerController => noPlayer ? null : fakePlayer;

  @override
  final RxBool isFullScreen = false.obs;

  @override
  final RxBool showControls = false.obs;

  @override
  bool isLive = false;

  @override
  Duration fastForBackwardDuration = const Duration(seconds: 10);

  @override
  final RxInt duration = 300.obs;

  @override
  final RxInt position = 30.obs;

  @override
  final RxInt buffered = 100.obs;

  @override
  PlayerStatus playerStatus = PlayerStatus.playing;

  @override
  List<double> speedList = const [0.5, 0.75, 1.0, 1.25, 1.5, 2.0];

  @override
  double playbackSpeed = 1.0;

  @override
  Future<void> setPlaybackSpeed(double speed) async {
    playbackSpeed = speed;
  }

  @override
  final Rx<VideoFitType> videoFit = Rx<VideoFitType>(VideoFitType.contain);

  @override
  void toggleVideoFit(VideoFitType fit) {
    videoFit.value = fit;
  }

  @override
  final RxBool enableShowDanmakuAdaptive = true.obs;

  @override
  final RxDouble danmakuOpacity = 1.0.obs;

  @override
  DanmakuController<DanmakuExtra>? danmakuController;

  @override
  bool tempPlayerConf = false;

  @override
  int? cid = 1001;

  final Set<ValueChanged<PlayerStatus>> statusListeners = {};

  @override
  void addStatusLister(ValueChanged<PlayerStatus> listener) {
    statusListeners.add(listener);
  }

  @override
  void removeStatusLister(ValueChanged<PlayerStatus> listener) {
    statusListeners.remove(listener);
  }

  /// Same order as `PlPlayerController`'s `playing` stream handler: the
  /// `playerStatus` field changes first, then the status listeners run.
  void emitPlayerStatus(PlayerStatus status) {
    playerStatus = status;
    for (final listener in statusListeners.toList()) {
      listener(status);
    }
  }

  /// When set, [onDoubleTapCenter] flips [playerStatus] after this delay, like
  /// media_kit reporting the new `playing` state asynchronously. The default
  /// (`null`) keeps the status untouched so counters stay the only side effect.
  Duration? statusFlipDelay;

  int doubleTapCenterCount = 0;
  @override
  Future<void> onDoubleTapCenter() async {
    doubleTapCenterCount++;
    if (statusFlipDelay case final delay?) {
      final next = playerStatus.isPlaying
          ? PlayerStatus.paused
          : PlayerStatus.playing;
      Timer(delay, () => emitPlayerStatus(next));
    }
  }

  /// [play] and [pause] are idempotent in the real controller (media_kit
  /// ignores a play while playing). Like [onDoubleTapCenter], they report the
  /// new status after [statusFlipDelay] when it is set.
  int playCount = 0;
  @override
  Future<void> play({bool repeat = false, bool hideControls = true}) async {
    playCount++;
    if (statusFlipDelay case final delay?) {
      Timer(delay, () => emitPlayerStatus(PlayerStatus.playing));
    }
  }

  int pauseCount = 0;
  @override
  Future<void> pause({bool notify = true, bool isInterrupt = false}) async {
    pauseCount++;
    if (statusFlipDelay case final delay?) {
      Timer(delay, () => emitPlayerStatus(PlayerStatus.paused));
    }
  }

  final List<Duration> seekTargets = [];
  @override
  void onForwardBackward(Duration target) {
    seekTargets.add(target);
  }

  bool? fullScreenTriggerStatus;
  @override
  Future<void> triggerFullScreen({
    bool status = false,
    bool isManualFS = false,
    bool inAppFullScreen = false,
    DeviceOrientation? orientation,
  }) async {
    fullScreenTriggerStatus = status;
    isFullScreen.value = status;
  }

  bool popInvoked = false;
  @override
  void onPopInvokedWithResult(bool didPop, dynamic result) {
    popInvoked = true;
  }

  @override
  bool tripling = false;

  @override
  final RxBool longPressStatus = false.obs;

  @override
  Future<void> setLongPressStatus(bool status) async {
    longPressStatus.value = status;
  }

  @override
  int? cacheVideoQa;

  @override
  bool isPipMode = false;

  @override
  bool isFileSource = false;

  @override
  bool showDmChart = true;

  @override
  bool showViewPoints = true;

  @override
  bool darkVideoPage = false;

  @override
  RuleFilter filters = RuleFilter.empty();

  @override
  PlayRepeat playRepeat = PlayRepeat.pause;

  @override
  void setPlayRepeat(PlayRepeat type) {
    playRepeat = type;
  }

  @override
  bool isAnim = false;

  @override
  final Rx<SuperResolutionType> superResolutionType =
      SuperResolutionType.disable.obs;

  @override
  Future<void> setShader([SuperResolutionType? type, Player? pp]) async {
    if (type != null) superResolutionType.value = type;
  }

  /// [videoPlayerController] returns `null` while this is set.
  bool noPlayer = false;
}

class FakeVideoDetailController extends Fake implements VideoDetailController {
  FakeVideoDetailController({required this.plPlayerController});

  @override
  final PlPlayerController plPlayerController;

  @override
  final RxInt cid = 1001.obs;

  @override
  bool isFileSource = false;

  @override
  final Rxn<VideoQuality> currentVideoQa = Rxn<VideoQuality>(
    VideoQuality.high1080,
  );

  int updatePlayerCount = 0;
  @override
  void updatePlayer() {
    updatePlayerCount++;
  }

  @override
  final GlobalKey<TimeBatteryMixin> headerCtrKey =
      GlobalKey<TimeBatteryMixin>();

  @override
  RxList<Subtitle> subtitles = RxList<Subtitle>();

  @override
  final RxInt vttSubtitlesIndex = 0.obs;

  @override
  Future<void> setSubtitle(int index) async {
    vttSubtitlesIndex.value = index;
  }

  @override
  final Rx<LoadingState<List<double>>?> dmTrend =
      Rx<LoadingState<List<double>>?>(null);

  @override
  final RxBool showDmTrendChart = true.obs;

  @override
  AudioQuality? currentAudioQa;

  @override
  final Rxn<List<play_url.LanguageItem>> languages =
      Rxn<List<play_url.LanguageItem>>();

  @override
  final Rxn<String> currLang = Rxn<String>();

  @override
  void setLanguage(String language) {
    currLang.value = language;
  }

  @override
  final RxList<ViewPointSegment> viewPointList = <ViewPointSegment>[].obs;

  @override
  final RxList<Segment> segmentProgressList = <Segment>[].obs;

  @override
  final List<Object> listData = [];

  @override
  void onRemoveItem(int index, Object item) => listData.removeAt(index);

  int showSBDetailCount = 0;
  @override
  void showSBDetail() {
    showSBDetailCount++;
    // As upstream: a dialog on Get's navigator.
    showDialog<void>(
      context: Get.context!,
      builder: (_) => const SimpleDialog(children: [Text('showSBDetail')]),
    );
  }

  @override
  final RxBool showVP = true.obs;

  int reloadCount = 0;
  @override
  Future<void> queryVideoUrl({
    bool fromReset = false,
    bool autoFullScreenFlag = false,
  }) async {
    if (fromReset) reloadCount++;
  }

  @override
  play_url.PlayUrlModel data = play_url.PlayUrlModel.fromJson({
    'dash': {
      'duration': 300,
      'video': [
        {'id': VideoQuality.high1080.code},
        {'id': VideoQuality.high720.code},
      ],
    },
    'support_formats': [
      {
        'quality': VideoQuality.high1080.code,
        'new_description': '1080P 高清',
        'format': 'mp4',
      },
      {
        'quality': VideoQuality.high720.code,
        'new_description': '720P 高清',
        'format': 'mp4',
      },
    ],
  });
}

class FakeUgcIntroController extends Fake implements UgcIntroController {
  FakeUgcIntroController({required this.videoDetailCtr});

  @override
  final VideoDetailController videoDetailCtr;

  @override
  bool isShowOnlineTotal = false;

  @override
  final RxString total = '1'.obs;

  @override
  final Rx<VideoDetailData> videoDetail = Rx<VideoDetailData>(
    VideoDetailData(
      title: '测试视频标题',
      pages: [
        Part(cid: 1001, page: 1, part: '第一集：初始篇'),
        Part(cid: 1002, page: 2, part: '第二集：进阶篇'),
        Part(cid: 1003, page: 3, part: '第三集：完结篇'),
      ],
    ),
  );

  BaseEpisodeItem? changedEpisode;
  @override
  Future<bool> onChangeEpisode(
    BaseEpisodeItem item, {
    bool isStein = false,
  }) async {
    changedEpisode = item;
    return true;
  }

  int prevPlayCount = 0;
  @override
  bool prevPlay({bool skipPart = false}) {
    prevPlayCount++;
    return true;
  }

  int nextPlayCount = 0;
  @override
  bool nextPlay({bool skipPart = false}) {
    nextPlayCount++;
    return true;
  }

  @override
  final RxBool hasLike = false.obs;

  @override
  final RxNum coinNum = RxNum(0);
  @override
  bool get hasCoin => coinNum.value != 0;

  @override
  final RxBool hasFav = false.obs;

  @override
  final Animation<double> tripleAnimation = const AlwaysStoppedAnimation(0.0);

  @override
  bool isTripling = false;

  @override
  void onStartTriple() {}

  @override
  void onCancelTriple([bool isTapUp = false]) {}

  int coinCount = 0;
  @override
  void actionCoinVideo() {
    coinCount++;
  }

  int favSheetCount = 0;
  @override
  void showFavBottomSheet(BuildContext context, {bool isLongPress = false}) {
    favSheetCount++;
  }

  int likeCount = 0;
  @override
  Future<void> actionLikeVideo() async {
    likeCount++;
  }

  @override
  final RxBool hasLater = false.obs;

  @override
  Future<void> viewLater() async {
    hasLater.toggle();
  }

  int playRelatedCount = 0;
  @override
  bool playRelated() {
    playRelatedCount++;
    return true;
  }
}

Widget _buildTestApp({
  required FakePlPlayerController plPlayerController,
  FakeUgcIntroController? introController,
  Widget? child,
  VoidCallback? onSendDanmaku,
  NavigatorObserver? observer,
  TvHudUpstream? upstream,
  VoidCallback? onRefresh,
  ValueGetter<bool>? onSkipSegment,
}) {
  return MaterialApp(
    // Upstream's panels open on `Get.key` (PageUtils.showVideoBottomSheet).
    navigatorKey: Get.key,
    navigatorObservers: [
      ?observer,
      FlutterSmartDialog.observer,
    ],
    builder: FlutterSmartDialog.init(),
    theme: ThemeData(
      colorScheme: ColorScheme.fromSeed(
        seedColor: Colors.deepPurple,
        brightness: Brightness.dark,
      ),
    ),
    home: Scaffold(
      body: TvNavigation(
        child: TvPlayerHud(
          plPlayerController: plPlayerController,
          introController: introController,
          onSendDanmaku: onSendDanmaku ?? () {},
          onRefresh: onRefresh,
          onSkipSegment: onSkipSegment,
          debugUpstream: upstream,
          child: child ?? Container(color: Colors.black),
        ),
      ),
    ),
  );
}

Future<void> _pumpHud(
  WidgetTester tester, {
  required FakePlPlayerController plPlayerController,
  FakeUgcIntroController? introController,
  Widget? child,
  VoidCallback? onSendDanmaku,
  NavigatorObserver? observer,
  TvHudUpstream? upstream,
  VoidCallback? onRefresh,
  ValueGetter<bool>? onSkipSegment,
}) async {
  tester.view.physicalSize = const Size(1920, 1080);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    _buildTestApp(
      plPlayerController: plPlayerController,
      introController: introController,
      child: child,
      onSendDanmaku: onSendDanmaku,
      observer: observer,
      upstream: upstream,
      onRefresh: onRefresh,
      onSkipSegment: onSkipSegment,
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;

  setUpAll(() async {
    tempDir = await Directory.systemTemp.createTemp('tv_hud_test_');
    Hive.init(tempDir.path);
    try {
      // In memory: the HUD saves its groups from inside widget tests, whose
      // fake clock would never let a file write finish.
      GStorage.setting = await Hive.openBox('setting', bytes: Uint8List(0));
    } catch (_) {}
    try {
      GStorage.video = await Hive.openBox('video');
    } catch (_) {}
    try {
      GStorage.localCache = await Hive.openBox('localCache');
    } catch (_) {}
  });

  setUp(() async {
    TvPlatform.setTvModeForTesting(true);
    await GStorage.setting.deleteAll(const [
      TvHudGroups.topRightKey,
      TvHudGroups.bottomKey,
      TvHudGroups.showLabelsKey,
    ]);
  });

  tearDown(() {
    TvPlatform.setTvModeForTesting(false);
  });

  group('TvPlayerHud Transport Controls & Focus Traversal (F15)', () {
    testWidgets(
      'fullscreen surface opens HUD via the Up key and focuses the time bar',
      (tester) async {
        final pl = FakePlPlayerController()..isFullScreen.value = true;

        await tester.pumpWidget(
          _buildTestApp(plPlayerController: pl),
        );
        await tester.pumpAndSettle();

        // Initially in fullscreen, HUD overlay is not visible.
        expect(_timeBar, findsNothing);

        // Press Up arrow on remote -> opens HUD overlay.
        await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
        await tester.pumpAndSettle();

        // The time bar has focus; the default bottom row is drawn (画质,
        // 字幕 and the episodes hide without a video page).
        expect(_focusOn(TvPlayerHud.timeBarKey), isTrue);
        expect(find.byKey(TvHudAction.keyOf('speed')), findsOneWidget);
        expect(find.byKey(TvHudAction.keyOf('videoFit')), findsOneWidget);
        expect(
          _textIn(TvHudAction.keyOf('speed'), '倍速: 1.0x'),
          findsOneWidget,
        );

        // Down: the bottom row's first button.
        await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
        await tester.pumpAndSettle();
        expect(_focusOn(TvHudAction.keyOf('speed')), isTrue);

        // Up: back to the time bar.
        await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
        await tester.pumpAndSettle();
        expect(_focusOn(TvPlayerHud.timeBarKey), isTrue);
      },
    );

    testWidgets(
      'split-screen mode shows the two-button quick strip; the menu key '
      'opens the HUD',
      (tester) async {
        final pl = FakePlPlayerController()..isFullScreen.value = false;

        await tester.pumpWidget(
          _buildTestApp(plPlayerController: pl),
        );
        await tester.pumpAndSettle();

        // 全屏 and 播放/暂停, icon-only; 播控 and 返回 are gone.
        expect(find.byKey(TvPlayerHud.quickFullscreenKey), findsOneWidget);
        expect(find.byKey(TvPlayerHud.quickPlayPauseKey), findsOneWidget);
        expect(find.text('播控'), findsNothing);
        expect(find.text('返回'), findsNothing);
        expect(_focusOn(TvPlayerHud.quickFullscreenKey), isTrue);
        // 播放/暂停 shows the current state.
        expect(
          find.descendant(
            of: find.byKey(TvPlayerHud.quickPlayPauseKey),
            matching: find.byIcon(Icons.pause_rounded),
          ),
          findsOneWidget,
        );
        pl.emitPlayerStatus(PlayerStatus.paused);
        await tester.pump();
        expect(
          find.descendant(
            of: find.byKey(TvPlayerHud.quickPlayPauseKey),
            matching: find.byIcon(Icons.play_arrow_rounded),
          ),
          findsOneWidget,
        );

        await tester.sendKeyEvent(LogicalKeyboardKey.contextMenu);
        await tester.pumpAndSettle();
        expect(_timeBar, findsOneWidget);
        expect(find.byKey(TvPlayerHud.quickFullscreenKey), findsNothing);
        expect(_focusOn(TvPlayerHud.timeBarKey), isTrue);
      },
    );
  });

  group('TvPlayerHud Virtual Seek Target Acceleration & Clamping (F15)', () {
    testWidgets(
      'virtual seek target accelerates across repeat events (<450ms) with 1x -> 2x -> 3x multipliers',
      (tester) async {
        final pl = FakePlPlayerController()
          ..isFullScreen.value = true
          ..fakePlayer.playerState.position = const Duration(seconds: 30)
          ..fakePlayer.playerState.duration = const Duration(seconds: 300)
          ..duration.value = 300
          ..fastForBackwardDuration = const Duration(seconds: 10);

        await tester.pumpWidget(
          _buildTestApp(plPlayerController: pl),
        );
        await tester.pumpAndSettle();

        // Step 1: 1st forward seek (consecutive = 1, multiplier = 1x -> +10s)
        await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
        await tester.pump();
        expect(pl.seekTargets.last, const Duration(seconds: 40));
        expect(_seekText('00:40 / 05:00'), findsOneWidget);
        // White Material icons, not the emoji Android draws as orange squares.
        expect(_seekIcon(Icons.fast_forward_rounded), findsOneWidget);
        expect(find.textContaining('⏩'), findsNothing);

        // Step 2: 2nd forward seek at 100ms (<450ms gap, consecutive = 2, multiplier = 1x -> +10s)
        await tester.pump(const Duration(milliseconds: 100));
        await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
        await tester.pump();
        expect(pl.seekTargets.last, const Duration(seconds: 50));
        expect(_seekText('00:50 / 05:00'), findsOneWidget);

        // Step 3: 3rd forward seek at 100ms (<450ms gap, consecutive = 3, multiplier = 2x -> +20s)
        await tester.pump(const Duration(milliseconds: 100));
        await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
        await tester.pump();
        expect(pl.seekTargets.last, const Duration(seconds: 70));
        expect(_seekText('01:10 / 05:00'), findsOneWidget);

        // Step 4: 4th forward seek at 100ms (consecutive = 4, multiplier = 2x -> +20s)
        await tester.pump(const Duration(milliseconds: 100));
        await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
        await tester.pump();
        expect(pl.seekTargets.last, const Duration(seconds: 90));
        expect(_seekText('01:30 / 05:00'), findsOneWidget);

        // Step 5: 5th forward seek at 100ms (consecutive = 5, multiplier = 2x -> +20s)
        await tester.pump(const Duration(milliseconds: 100));
        await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
        await tester.pump();
        expect(pl.seekTargets.last, const Duration(seconds: 110));
        expect(_seekText('01:50 / 05:00'), findsOneWidget);

        // Step 6: 6th forward seek at 100ms (consecutive = 6, multiplier = 3x -> +30s)
        await tester.pump(const Duration(milliseconds: 100));
        await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
        await tester.pump();
        expect(pl.seekTargets.last, const Duration(seconds: 140));
        expect(_seekText('02:20 / 05:00'), findsOneWidget);

        // Verify all 6 targets recorded properly with progressive scaling
        expect(pl.seekTargets, [
          const Duration(seconds: 40),
          const Duration(seconds: 50),
          const Duration(seconds: 70),
          const Duration(seconds: 90),
          const Duration(seconds: 110),
          const Duration(seconds: 140),
        ]);
      },
    );

    testWidgets(
      'virtual seek target clamps to [0, totalDuration]',
      (tester) async {
        final pl = FakePlPlayerController()
          ..isFullScreen.value = true
          ..fakePlayer.playerState.position = const Duration(seconds: 295)
          ..fakePlayer.playerState.duration = const Duration(seconds: 300)
          ..duration.value = 300
          ..fastForBackwardDuration = const Duration(seconds: 10);

        await tester.pumpWidget(
          _buildTestApp(plPlayerController: pl),
        );
        await tester.pumpAndSettle();

        // Forward seek from 295s with +10s delta -> clamped to 300s (totalDuration)
        await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
        await tester.pump();
        expect(pl.seekTargets.last, const Duration(seconds: 300));
        expect(_seekText('05:00 / 05:00'), findsOneWidget);

        // Reset and test backward seek clamping to 0
        await tester.pump(const Duration(milliseconds: 1500));
        pl
          ..fakePlayer.playerState.position = const Duration(seconds: 5)
          ..seekTargets.clear();

        // Backward seek from 5s with -10s delta -> clamped to 0s
        await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
        await tester.pump();
        expect(pl.seekTargets.last, Duration.zero);
        expect(_seekText('00:00 / 05:00'), findsOneWidget);
        expect(_seekIcon(Icons.fast_rewind_rounded), findsOneWidget);
        expect(_seekIcon(Icons.fast_forward_rounded), findsNothing);
      },
    );
  });

  group('TvPlayerHud Virtual Seek Target Resets (F15)', () {
    testWidgets(
      'virtual seek target and OSD banner reset after 1400ms idle timeout',
      (tester) async {
        final pl = FakePlPlayerController()
          ..isFullScreen.value = true
          ..fakePlayer.playerState.position = const Duration(seconds: 30)
          ..fakePlayer.playerState.duration = const Duration(seconds: 300)
          ..duration.value = 300;

        await tester.pumpWidget(
          _buildTestApp(plPlayerController: pl),
        );
        await tester.pumpAndSettle();

        await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
        await tester.pump();
        expect(_seekText('00:40 / 05:00'), findsOneWidget);

        // Before 1400ms timer expires, OSD text is still visible
        await tester.pump(const Duration(milliseconds: 1000));
        expect(_seekText('00:40 / 05:00'), findsOneWidget);

        // After 1400ms timer expires (1000ms + 500ms = 1500ms), OSD banner disappears
        await tester.pump(const Duration(milliseconds: 500));
        expect(_seekText('00:40 / 05:00'), findsNothing);

        // Subsequent seek starts fresh from state.position (30s) + 10s = 40s (1x)
        await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
        await tester.pump();
        expect(pl.seekTargets.last, const Duration(seconds: 40));
      },
    );

    testWidgets(
      'virtual seek target resets when key cadence gap is >=450ms',
      (tester) async {
        final pl = FakePlPlayerController()
          ..isFullScreen.value = true
          ..fakePlayer.playerState.position = const Duration(seconds: 30)
          ..fakePlayer.playerState.duration = const Duration(seconds: 300)
          ..duration.value = 300;

        await tester.pumpWidget(
          _buildTestApp(plPlayerController: pl),
        );
        await tester.pumpAndSettle();

        // Step 1
        await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
        await tester.pump();
        expect(pl.seekTargets.last, const Duration(seconds: 40));

        // Let the cadence window (450 ms) pass on the binding's sampling clock.
        await tester.pump(const Duration(milliseconds: 500));

        // Step 2: cadence exceeded -> consecutive steps reset to 1 and virtual target reset
        await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
        await tester.pump();
        // Since virtual seek target was cleared, it recalculates from state.position (30s) + 10s = 40s
        expect(pl.seekTargets.last, const Duration(seconds: 40));
      },
    );

    testWidgets(
      'virtual seek target resets on play/pause toggle and hideHud',
      (tester) async {
        final pl = FakePlPlayerController()
          ..isFullScreen.value = true
          ..fakePlayer.playerState.position = const Duration(seconds: 30)
          ..fakePlayer.playerState.duration = const Duration(seconds: 300)
          ..duration.value = 300;

        await tester.pumpWidget(
          _buildTestApp(plPlayerController: pl),
        );
        await tester.pumpAndSettle();

        // Seek forward
        await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
        await tester.pump();
        expect(_seekText('00:40 / 05:00'), findsOneWidget);

        // Play/Pause toggle resets virtual seek target
        await tester.sendKeyEvent(LogicalKeyboardKey.mediaPlayPause);
        await tester.pump();
        expect(pl.doubleTapCenterCount, 1);

        // Open HUD and close via Escape: verify hideHud resets state cleanly
        await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
        await tester.pumpAndSettle();
        expect(_timeBar, findsOneWidget);

        await tester.sendKeyEvent(LogicalKeyboardKey.escape);
        await tester.pumpAndSettle();
        expect(_timeBar, findsNothing);
      },
    );
  });

  group('TvPlayerHud PopScope Back Key Handling (F15)', () {
    testWidgets(
      'PopScope intercepts back key when HUD is open to dismiss HUD without popping route',
      (tester) async {
        final pl = FakePlPlayerController()..isFullScreen.value = true;

        late BuildContext playerContext;

        await tester.pumpWidget(
          MaterialApp(
            navigatorObservers: [FlutterSmartDialog.observer],
            builder: FlutterSmartDialog.init(),
            home: Scaffold(
              body: Builder(
                builder: (context) {
                  playerContext = context;
                  return TvNavigation(
                    child: TvPlayerHud(
                      plPlayerController: pl,
                      onSendDanmaku: () {},
                      child: Container(color: Colors.black),
                    ),
                  );
                },
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // PopScope canPop is true when HUD is closed
        PopScope popScope = tester.widget<PopScope>(
          find.byWidgetPredicate((w) => w is PopScope),
        );
        expect(popScope.canPop, isTrue);

        // Open HUD
        await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
        await tester.pumpAndSettle();
        expect(_timeBar, findsOneWidget);

        // PopScope canPop is now false when HUD is open
        popScope = tester.widget<PopScope>(
          find.byWidgetPredicate((w) => w is PopScope),
        );
        expect(popScope.canPop, isFalse);

        // Invoke maybePop() while HUD is open
        final navigator = Navigator.of(playerContext);
        final popResult = await navigator.maybePop();

        // Pop was handled/intercepted by PopScope (canPop was false)
        expect(popResult, isTrue);
        await tester.pumpAndSettle();

        // HUD is now dismissed and canPop is restored to true
        expect(_timeBar, findsNothing);
        popScope = tester.widget<PopScope>(
          find.byWidgetPredicate((w) => w is PopScope),
        );
        expect(popScope.canPop, isTrue);

        // Verify player route is STILL mounted (route was not popped)
        expect(find.byType(TvPlayerHud), findsOneWidget);
      },
    );

    testWidgets(
      'PopScope allows back key to pop route when HUD is closed',
      (tester) async {
        final pl = FakePlPlayerController()..isFullScreen.value = false;

        late BuildContext playerContext;

        await tester.pumpWidget(
          MaterialApp(
            navigatorObservers: [FlutterSmartDialog.observer],
            builder: FlutterSmartDialog.init(),
            home: Builder(
              builder: (ctx) => Scaffold(
                body: Center(
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.of(ctx).push(
                        MaterialPageRoute<void>(
                          builder: (pCtx) {
                            playerContext = pCtx;
                            return Scaffold(
                              body: TvPlayerHud(
                                plPlayerController: pl,
                                onSendDanmaku: () {},
                                child: Container(color: Colors.black),
                              ),
                            );
                          },
                        ),
                      );
                    },
                    child: const Text('GoToPlayer'),
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.text('GoToPlayer'));
        await tester.pumpAndSettle();
        expect(find.byType(TvPlayerHud), findsOneWidget);

        // With HUD closed (_hudVisible == false), canPop is true, maybePop() pops the route
        final navigator = Navigator.of(playerContext);
        final popResult = await navigator.maybePop();
        expect(popResult, isTrue);
        await tester.pumpAndSettle();

        // Player route is now popped, returning to home screen
        expect(find.byType(TvPlayerHud), findsNothing);
        expect(find.text('GoToPlayer'), findsOneWidget);
      },
    );
  });

  group('TvPlayerHud Modal Dialog Lifecycles & Focus Traps (F15)', () {
    testWidgets(
      'Speed dialog opens, autofocuses current speed, updates speed, dismisses cleanly',
      (tester) async {
        final pl = FakePlPlayerController()
          ..isFullScreen.value = true
          ..playbackSpeed = 1.0
          ..speedList = const [0.75, 1.0, 1.25, 1.5, 2.0];

        await _pumpHud(tester, plPlayerController: pl);

        // Open HUD
        await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
        await tester.pumpAndSettle();

        final speedBtnFinder = find.byKey(TvHudAction.keyOf('speed'));
        expect(speedBtnFinder, findsOneWidget);
        expect(
          find.descendant(of: speedBtnFinder, matching: find.text('倍速: 1.0x')),
          findsOneWidget,
        );
        await tester.tap(speedBtnFinder);
        await tester.pumpAndSettle();

        // Dialog opened, focus on the current speed.
        expect(_textIn(TvPlayerHud.optionListKey, '选择播放倍速'), findsOneWidget);
        _expectOption(1, '1.0x');
        _expectOption(2, '1.25x');
        expect(_focusOn(TvPlayerHud.optionItemKey(1)), isTrue);

        // Select 1.25x
        await tester.tap(_optionRow(2));
        await tester.pumpAndSettle();

        // Dialog dismissed and speed updated
        expect(_optionList, findsNothing);
        expect(pl.playbackSpeed, 1.25);
        await tester.pump(const Duration(seconds: 3));
      },
    );

    testWidgets(
      'Video fit dialog opens, autofocuses current fit, updates fit, dismisses cleanly',
      (tester) async {
        final pl = FakePlPlayerController()
          ..isFullScreen.value = true
          ..videoFit.value = VideoFitType.contain;

        await _pumpHud(tester, plPlayerController: pl);

        // Open HUD
        await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
        await tester.pumpAndSettle();

        final fitBtnFinder = find.byKey(TvHudAction.keyOf('videoFit'));
        expect(fitBtnFinder, findsOneWidget);
        expect(
          find.descendant(of: fitBtnFinder, matching: find.text('画面: 自动')),
          findsOneWidget,
        );
        await tester.tap(fitBtnFinder);
        await tester.pumpAndSettle();

        // Dialog opened, focus on the current fit.
        expect(_textIn(TvPlayerHud.optionListKey, '选择画面比例'), findsOneWidget);
        final int containRow = VideoFitType.values.indexOf(
          VideoFitType.contain,
        );
        expect(_focusOn(TvPlayerHud.optionItemKey(containRow)), isTrue);

        // Select '拉伸'
        final int fillRow = VideoFitType.values.indexOf(VideoFitType.fill);
        _expectOption(fillRow, '拉伸');
        await tester.tap(_optionRow(fillRow));
        await tester.pumpAndSettle();

        // Dialog dismissed and fit updated
        expect(_optionList, findsNothing);
        expect(pl.videoFit.value, VideoFitType.fill);
        await tester.pump(const Duration(seconds: 3));
      },
    );

    testWidgets(
      'Episodes dialog opens, lists episodes, autofocuses current episode, selects next episode',
      (tester) async {
        final pl = FakePlPlayerController()
          ..isFullScreen.value = true
          ..cid = 1001;
        final videoDetailCtr = FakeVideoDetailController(
          plPlayerController: pl,
        );
        final introCtr = FakeUgcIntroController(videoDetailCtr: videoDetailCtr);

        await _pumpHud(
          tester,
          plPlayerController: pl,
          introController: introCtr,
        );

        // Open HUD
        await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
        await tester.pumpAndSettle();

        final epBtn = find.byKey(TvHudAction.keyOf('episodes.list'));
        expect(
          find.descendant(of: epBtn, matching: find.text('选集 (3)')),
          findsOneWidget,
        );
        await tester.tap(epBtn);
        await tester.pumpAndSettle();

        // Dialog opened, focus on the current episode.
        expect(_textIn(TvPlayerHud.optionListKey, '选集 (3)'), findsOneWidget);
        _expectOption(0, 'P1  第一集：初始篇');
        _expectOption(1, 'P2  第二集：进阶篇');
        _expectOption(2, 'P3  第三集：完结篇');
        expect(_optionRow(3), findsNothing);
        expect(_focusOn(TvPlayerHud.optionItemKey(0)), isTrue);

        // Select P2
        await tester.tap(_optionRow(1));
        await tester.pumpAndSettle();
        expect(_optionList, findsNothing);

        // Dialog dismissed and episode changed callback fired
        expect(introCtr.changedEpisode, isNotNull);
        expect((introCtr.changedEpisode as Part).cid, 1002);
      },
    );
  });

  group('TvPlayerHud Long-Press D-pad Select for 3x Playback Speed (M7)', () {
    testWidgets(
      'fullscreen with HUD closed: holding Select activates 3x speed and releasing restores normal speed; short press toggles play/pause',
      (tester) async {
        final pl = FakePlPlayerController()
          ..isFullScreen.value = true
          ..playerStatus = PlayerStatus.playing;

        await _pumpHud(tester, plPlayerController: pl);

        // 1. Short-press Select (< 250ms) -> toggles play/pause without activating 3x speed.
        await tester.sendKeyDownEvent(LogicalKeyboardKey.select);
        await tester.pump(const Duration(milliseconds: 100));
        expect(pl.longPressStatus.value, isFalse);
        await tester.sendKeyUpEvent(LogicalKeyboardKey.select);
        await tester.pump();
        expect(pl.longPressStatus.value, isFalse);
        expect(pl.doubleTapCenterCount, 1);

        // 2. Hold Select (>= 250ms) -> activates 3x speed (setLongPressStatus(true))
        //    and does not toggle play/pause.
        await tester.sendKeyDownEvent(LogicalKeyboardKey.select);
        await tester.pump(const Duration(milliseconds: 300));
        expect(pl.longPressStatus.value, isTrue);
        expect(pl.doubleTapCenterCount, 1);

        // Repeat events while held keep 3x speed active without toggling play/pause.
        await tester.sendKeyRepeatEvent(LogicalKeyboardKey.select);
        await tester.pump(const Duration(milliseconds: 200));
        expect(pl.longPressStatus.value, isTrue);
        expect(pl.doubleTapCenterCount, 1);

        // 3. Release Select -> restores normal speed (setLongPressStatus(false))
        //    without toggling play/pause.
        await tester.sendKeyUpEvent(LogicalKeyboardKey.select);
        await tester.pump();
        expect(pl.longPressStatus.value, isFalse);
        expect(pl.doubleTapCenterCount, 1);
      },
    );

    testWidgets(
      'fullscreen with HUD open on the time bar: holding Select activates 3x speed and pauses HUD auto-hide timer',
      (tester) async {
        final pl = FakePlPlayerController()
          ..isFullScreen.value = true
          ..playerStatus = PlayerStatus.playing;

        await _pumpHud(tester, plPlayerController: pl);

        // Open HUD via Up arrow -> the time bar is focused.
        await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
        await tester.pumpAndSettle();
        expect(_focusOn(TvPlayerHud.timeBarKey), isTrue);

        // Hold Select on the time bar -> activates 3x speed and keeps HUD
        // alive past the 5-second auto-hide timeout while held.
        await tester.sendKeyDownEvent(LogicalKeyboardKey.select);
        await tester.pump(const Duration(milliseconds: 300));
        expect(pl.longPressStatus.value, isTrue);
        expect(pl.doubleTapCenterCount, 0);

        await tester.pump(const Duration(seconds: 6));
        expect(pl.longPressStatus.value, isTrue);
        expect(_timeBar, findsOneWidget);

        // Release Select -> restores normal speed without pausing video.
        await tester.sendKeyUpEvent(LogicalKeyboardKey.select);
        await tester.pump();
        expect(pl.longPressStatus.value, isFalse);
        expect(pl.doubleTapCenterCount, 0);

        // Short-press Select on the time bar -> toggles play/pause.
        await tester.sendKeyEvent(LogicalKeyboardKey.select);
        await tester.pump();
        expect(pl.doubleTapCenterCount, 1);
        expect(pl.longPressStatus.value, isFalse);
      },
    );

    testWidgets(
      'split-screen Quick Strip: holding Select on 全屏 or 播放/暂停 activates 3x speed; short press triggers pill action',
      (tester) async {
        final pl = FakePlPlayerController()
          ..isFullScreen.value = false
          ..playerStatus = PlayerStatus.playing;

        await _pumpHud(tester, plPlayerController: pl);
        expect(_focusOn(TvPlayerHud.quickFullscreenKey), isTrue);

        // Hold Select on autofocused '全屏' pill -> activates 3x speed without entering fullscreen.
        await tester.sendKeyDownEvent(LogicalKeyboardKey.select);
        await tester.pump(const Duration(milliseconds: 300));
        expect(pl.longPressStatus.value, isTrue);
        expect(pl.isFullScreen.value, isFalse);

        // Release Select -> restores normal speed.
        await tester.sendKeyUpEvent(LogicalKeyboardKey.select);
        await tester.pump();
        expect(pl.longPressStatus.value, isFalse);
        expect(pl.isFullScreen.value, isFalse);

        // Short-press Select on '全屏' pill -> enters fullscreen.
        await tester.sendKeyEvent(LogicalKeyboardKey.select);
        await tester.pumpAndSettle();
        expect(pl.isFullScreen.value, isTrue);
      },
    );
  });

  group('TvPlayerHud code review fixes (M10: R8, R10, R11, R12)', () {
    testWidgets(
      'R8: the time bar keeps Hold-Select 3x speed after D-pad moves away and back',
      (tester) async {
        final pl = FakePlPlayerController()
          ..isFullScreen.value = true
          ..playerStatus = PlayerStatus.playing;

        await _pumpHud(tester, plPlayerController: pl);

        await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
        await tester.pumpAndSettle();
        expect(_focusOn(TvPlayerHud.timeBarKey), isTrue);

        // Leave the bar and come back by D-pad: traversal, not autofocus,
        // now decides which node owns primary focus.
        await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
        await tester.pumpAndSettle();
        expect(_focusOn(TvHudAction.keyOf('speed')), isTrue);
        await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
        await tester.pumpAndSettle();
        expect(_focusOn(TvPlayerHud.timeBarKey), isTrue);

        await tester.sendKeyDownEvent(LogicalKeyboardKey.select);
        await tester.pump(const Duration(milliseconds: 300));
        expect(pl.longPressStatus.value, isTrue);
        expect(pl.doubleTapCenterCount, 0);

        await tester.sendKeyUpEvent(LogicalKeyboardKey.select);
        await tester.pump();
        expect(pl.longPressStatus.value, isFalse);
        expect(pl.doubleTapCenterCount, 0);

        // A short press still toggles play/pause, once, on key up.
        await tester.sendKeyEvent(LogicalKeyboardKey.select);
        await tester.pump();
        expect(pl.doubleTapCenterCount, 1);
      },
    );

    testWidgets(
      'R8: Quick Strip 全屏 and 播放/暂停 keep Hold-Select 3x speed after D-pad moves away and back',
      (tester) async {
        final pl = FakePlPlayerController()
          ..isFullScreen.value = false
          ..playerStatus = PlayerStatus.playing;

        await _pumpHud(tester, plPlayerController: pl);
        expect(_focusOn(TvPlayerHud.quickFullscreenKey), isTrue);

        // 全屏 -> 播放/暂停: hold Select on 播放/暂停.
        await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
        await tester.pumpAndSettle();
        expect(_focusOn(TvPlayerHud.quickPlayPauseKey), isTrue);

        await tester.sendKeyDownEvent(LogicalKeyboardKey.select);
        await tester.pump(const Duration(milliseconds: 300));
        expect(pl.longPressStatus.value, isTrue);
        expect(pl.doubleTapCenterCount, 0);
        await tester.sendKeyUpEvent(LogicalKeyboardKey.select);
        await tester.pump();
        expect(pl.longPressStatus.value, isFalse);
        expect(pl.doubleTapCenterCount, 0);

        // 播放/暂停 -> 全屏: hold Select on 全屏 without entering fullscreen.
        await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
        await tester.pumpAndSettle();
        expect(_focusOn(TvPlayerHud.quickFullscreenKey), isTrue);

        await tester.sendKeyDownEvent(LogicalKeyboardKey.select);
        await tester.pump(const Duration(milliseconds: 300));
        expect(pl.longPressStatus.value, isTrue);
        expect(pl.isFullScreen.value, isFalse);
        await tester.sendKeyUpEvent(LogicalKeyboardKey.select);
        await tester.pump();
        expect(pl.longPressStatus.value, isFalse);
        expect(pl.isFullScreen.value, isFalse);

        // A short press on 全屏 still enters fullscreen.
        await tester.sendKeyEvent(LogicalKeyboardKey.select);
        await tester.pumpAndSettle();
        expect(pl.isFullScreen.value, isTrue);
      },
    );

    testWidgets(
      'R8: touch taps on a pill still run its action',
      (tester) async {
        final pl = FakePlPlayerController()..isFullScreen.value = false;

        await _pumpHud(tester, plPlayerController: pl);

        await tester.tap(find.byKey(TvPlayerHud.quickPlayPauseKey));
        await tester.pump();
        expect(pl.doubleTapCenterCount, 1);
      },
    );

    testWidgets(
      'R10: episode dialog opens on the current episode even deep in a long list',
      (tester) async {
        final pl = FakePlPlayerController()
          ..isFullScreen.value = true
          ..cid = 1045;
        final videoDetailCtr = FakeVideoDetailController(
          plPlayerController: pl,
        )..cid.value = 1045;
        final introCtr = FakeUgcIntroController(videoDetailCtr: videoDetailCtr)
          ..videoDetail.value = VideoDetailData(
            title: '长剧集',
            pages: [
              for (var i = 1; i <= 60; i++)
                Part(cid: 1000 + i, page: i, part: '第$i集'),
            ],
          );

        await _pumpHud(
          tester,
          plPlayerController: pl,
          introController: introCtr,
        );
        await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(TvHudAction.keyOf('episodes.list')));
        await tester.pumpAndSettle();

        // The list is lazy: item 0 is far outside the viewport, so the current
        // episode is only built (and its autofocus only fires) if the list
        // starts scrolled to it.
        expect(_optionRow(0), findsNothing);
        _expectOption(44, 'P45  第45集');
        expect(_focusOn(TvPlayerHud.optionItemKey(44)), isTrue);
        final Rect viewport = tester.getRect(find.byType(ListView));
        expect(
          viewport.contains(tester.getRect(_optionRow(44)).center),
          isTrue,
        );

        // D-pad stepping continues from the current episode, not from item 0.
        await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
        await tester.pumpAndSettle();
        expect(_focusOn(TvPlayerHud.optionItemKey(45)), isTrue);
      },
    );

    testWidgets(
      'R10: at the largest font size, option rows grow so no label is clipped',
      (tester) async {
        // The font size setting goes up to 1.6x. A fixed 52 px row left about
        // 21.6 px inside a focused pill, less than a 14 px label at 1.6x.
        tester.platformDispatcher.textScaleFactorTestValue = 1.6;
        addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

        final pl = FakePlPlayerController()
          ..isFullScreen.value = true
          ..cid = 1030;
        final videoDetailCtr = FakeVideoDetailController(
          plPlayerController: pl,
        )..cid.value = 1030;
        final introCtr = FakeUgcIntroController(videoDetailCtr: videoDetailCtr)
          ..videoDetail.value = VideoDetailData(
            title: '长剧集',
            pages: [
              for (var i = 1; i <= 40; i++)
                Part(cid: 1000 + i, page: i, part: '第$i集'),
            ],
          );

        await _pumpHud(
          tester,
          plPlayerController: pl,
          introController: introCtr,
        );
        await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(TvHudAction.keyOf('episodes.list')));
        await tester.pumpAndSettle();

        // Still opens on the current episode, focused (the thicker border).
        _expectOption(29, 'P30  第30集');
        expect(_focusOn(TvPlayerHud.optionItemKey(29)), isTrue);

        final Iterable<RenderParagraph> labels = tester
            .renderObjectList<RenderParagraph>(
              find.descendant(
                of: find.byType(ListView),
                matching: find.byType(RichText),
              ),
            );
        expect(labels, isNotEmpty);
        for (final RenderParagraph label in labels) {
          expect(
            label.size.height,
            greaterThanOrEqualTo(label.textSize.height - 0.01),
            reason: 'label "${label.text.toPlainText()}" is clipped',
          );
        }

        // D-pad stepping still lands on the next episode.
        await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
        await tester.pumpAndSettle();
        expect(_focusOn(TvPlayerHud.optionItemKey(30)), isTrue);
      },
    );

    testWidgets(
      'R10: short option lists and a first-item selection still start at the top',
      (tester) async {
        final pl = FakePlPlayerController()
          ..isFullScreen.value = true
          ..playbackSpeed = 0.5
          ..speedList = const [0.5, 0.75, 1.0, 1.25, 1.5, 2.0];

        await _pumpHud(tester, plPlayerController: pl);
        await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
        await tester.pumpAndSettle();
        expect(
          _textIn(TvHudAction.keyOf('speed'), '倍速: 0.5x'),
          findsOneWidget,
        );
        await tester.tap(find.byKey(TvHudAction.keyOf('speed')));
        await tester.pumpAndSettle();

        expect(_textIn(TvPlayerHud.optionListKey, '选择播放倍速'), findsOneWidget);
        _expectOption(0, '0.5x');
        expect(_focusOn(TvPlayerHud.optionItemKey(0)), isTrue);
        // Six rows fit, so the last is built too: the list starts at the top.
        _expectOption(5, '2.0x');
      },
    );

    testWidgets(
      'R11: the time bar\'s play/pause icon follows the player status event, not the key press',
      (tester) async {
        final pl = FakePlPlayerController()
          ..isFullScreen.value = true
          ..playerStatus = PlayerStatus.playing
          ..statusFlipDelay = const Duration(milliseconds: 80);

        await _pumpHud(tester, plPlayerController: pl);
        await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
        await tester.pumpAndSettle();
        expect(_timeBarIcon(Icons.pause_rounded), findsOneWidget);

        await tester.sendKeyEvent(LogicalKeyboardKey.select);
        await tester.pump();
        expect(pl.doubleTapCenterCount, 1);
        // The player has not reported the new state yet, so the icon must not
        // claim it has.
        expect(_timeBarIcon(Icons.pause_rounded), findsOneWidget);

        await tester.pump(const Duration(milliseconds: 100));
        expect(_timeBarIcon(Icons.play_arrow_rounded), findsOneWidget);
        expect(_timeBarIcon(Icons.pause_rounded), findsNothing);

        await tester.sendKeyEvent(LogicalKeyboardKey.select);
        await tester.pump(const Duration(milliseconds: 100));
        expect(pl.doubleTapCenterCount, 2);
        expect(_timeBarIcon(Icons.pause_rounded), findsOneWidget);
        expect(_timeBarIcon(Icons.play_arrow_rounded), findsNothing);
      },
    );

    testWidgets(
      'R11: status changes that do not come from the HUD also update the icon',
      (tester) async {
        final pl = FakePlPlayerController()
          ..isFullScreen.value = true
          ..playerStatus = PlayerStatus.playing;

        await _pumpHud(tester, plPlayerController: pl);
        await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
        await tester.pumpAndSettle();
        expect(_timeBarIcon(Icons.pause_rounded), findsOneWidget);

        pl.emitPlayerStatus(PlayerStatus.paused);
        await tester.pump();
        expect(_timeBarIcon(Icons.play_arrow_rounded), findsOneWidget);

        pl.emitPlayerStatus(PlayerStatus.completed);
        await tester.pump();
        expect(_timeBarIcon(Icons.play_arrow_rounded), findsOneWidget);

        pl.emitPlayerStatus(PlayerStatus.playing);
        await tester.pump();
        expect(_timeBarIcon(Icons.pause_rounded), findsOneWidget);
      },
    );

    testWidgets(
      'R11: status listener is registered once, moves with the controller, and is removed on dispose',
      (tester) async {
        final first = FakePlPlayerController()..isFullScreen.value = true;
        final second = FakePlPlayerController()..isFullScreen.value = true;

        Widget app(FakePlPlayerController pl) => MaterialApp(
          builder: FlutterSmartDialog.init(),
          home: Scaffold(
            body: TvNavigation(
              child: TvPlayerHud(
                plPlayerController: pl,
                onSendDanmaku: () {},
                child: Container(color: Colors.black),
              ),
            ),
          ),
        );

        await tester.pumpWidget(app(first));
        await tester.pumpAndSettle();
        expect(first.statusListeners, hasLength(1));

        await tester.pumpWidget(app(second));
        await tester.pumpAndSettle();
        expect(first.statusListeners, isEmpty);
        expect(second.statusListeners, hasLength(1));

        await tester.pumpWidget(const SizedBox.shrink());
        expect(second.statusListeners, isEmpty);
      },
    );

    testWidgets(
      'R18: reversing direction restarts the acceleration but keeps the virtual target',
      (tester) async {
        final pl = FakePlPlayerController()
          ..isFullScreen.value = true
          ..fakePlayer.playerState.position = const Duration(seconds: 30)
          ..fakePlayer.playerState.duration = const Duration(seconds: 300)
          ..duration.value = 300
          ..fastForBackwardDuration = const Duration(seconds: 10);

        await tester.pumpWidget(_buildTestApp(plPlayerController: pl));
        await tester.pumpAndSettle();

        // Three quick steps forward: +10, +10, then the 2x step (+20) -> 70 s.
        for (int i = 0; i < 3; i++) {
          await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
          await tester.pump(const Duration(milliseconds: 100));
        }
        expect(pl.seekTargets.last, const Duration(seconds: 70));

        // Reversing inside the burst is a 1x step from the virtual target
        // (70 - 10), not a 2x step (50) and not a jump from the decoder (20).
        await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
        await tester.pump(const Duration(milliseconds: 100));
        expect(pl.seekTargets.last, const Duration(seconds: 60));

        // The backward burst accelerates on its own: 1x, 1x, then 2x.
        await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
        await tester.pump(const Duration(milliseconds: 100));
        expect(pl.seekTargets.last, const Duration(seconds: 50));
        await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
        await tester.pump(const Duration(milliseconds: 100));
        expect(pl.seekTargets.last, const Duration(seconds: 30));

        await tester.pump(const Duration(seconds: 2));
      },
    );

    testWidgets(
      'M14.3: the top bar has the title with the viewer count under it, and '
      'no clock or 退出全屏 button',
      (tester) async {
        final pl = FakePlPlayerController()..isFullScreen.value = true;
        final vdc = FakeVideoDetailController(plPlayerController: pl);
        final intro = FakeUgcIntroController(videoDetailCtr: vdc)
          ..isShowOnlineTotal = true
          ..total.value = '123';

        await _pumpHud(tester, plPlayerController: pl, introController: intro);
        await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
        await tester.pumpAndSettle();

        final Rect title = tester.getRect(find.byKey(TvPlayerHud.titleKey));
        final Rect viewers = tester.getRect(find.byKey(TvPlayerHud.viewersKey));
        expect(
          tester.widget<Text>(find.byKey(TvPlayerHud.viewersKey)).data,
          '123人正在看',
        );
        expect(viewers.top, greaterThanOrEqualTo(title.bottom));
        expect(
          tester
              .widget<Text>(find.byKey(TvPlayerHud.viewersKey))
              .style!
              .fontSize,
          lessThan(
            tester
                .widget<Text>(find.byKey(TvPlayerHud.titleKey))
                .style!
                .fontSize!,
          ),
        );
        expect(
          find.byWidgetPredicate(
            (Widget w) => w.runtimeType.toString() == '_TvHudClock',
          ),
          findsNothing,
        );
        expect(find.text('退出全屏'), findsNothing);
        expect(find.text('关闭面板'), findsNothing);
        expect(find.textContaining('快退'), findsNothing);
      },
    );

    testWidgets(
      'R12: Play and Pause media keys are idempotent while PlayPause toggles',
      (tester) async {
        final pl = FakePlPlayerController()
          ..isFullScreen.value = true
          ..playerStatus = PlayerStatus.playing;

        await _pumpHud(tester, plPlayerController: pl);

        // Play and Pause go to the idempotent play() / pause(), never to the
        // toggle, whatever the reported status.
        await tester.sendKeyEvent(LogicalKeyboardKey.mediaPlay);
        await tester.pump();
        await tester.sendKeyEvent(LogicalKeyboardKey.mediaPause);
        await tester.pump();
        pl.emitPlayerStatus(PlayerStatus.paused);
        await tester.sendKeyEvent(LogicalKeyboardKey.mediaPause);
        await tester.pump();
        await tester.sendKeyEvent(LogicalKeyboardKey.mediaPlay);
        await tester.pump();
        expect(pl.playCount, 2);
        expect(pl.pauseCount, 2);
        expect(pl.doubleTapCenterCount, 0);

        // Completed: Play restarts playback through the toggle (which seeks to
        // the start), Pause is still a plain pause.
        pl.emitPlayerStatus(PlayerStatus.completed);
        await tester.sendKeyEvent(LogicalKeyboardKey.mediaPlay);
        await tester.pump();
        expect(pl.doubleTapCenterCount, 1);
        expect(pl.playCount, 2);

        // PlayPause always toggles.
        await tester.sendKeyEvent(LogicalKeyboardKey.mediaPlayPause);
        await tester.pump();
        expect(pl.doubleTapCenterCount, 2);
      },
    );

    testWidgets(
      'R12: a second Pause before the player reports its state does not resume',
      (tester) async {
        // media_kit reports the new state after the command; until then
        // playerStatus still says playing.
        final pl = FakePlPlayerController()
          ..isFullScreen.value = true
          ..playerStatus = PlayerStatus.playing
          ..statusFlipDelay = const Duration(milliseconds: 80);

        await _pumpHud(tester, plPlayerController: pl);

        await tester.sendKeyEvent(LogicalKeyboardKey.mediaPause);
        await tester.pump(const Duration(milliseconds: 20));
        await tester.sendKeyEvent(LogicalKeyboardKey.mediaPause);
        await tester.pump(const Duration(milliseconds: 200));

        expect(pl.playerStatus, PlayerStatus.paused);
        expect(pl.playCount, 0);
        expect(pl.doubleTapCenterCount, 0);

        // Same for a duplicate Play while paused.
        await tester.sendKeyEvent(LogicalKeyboardKey.mediaPlay);
        await tester.pump(const Duration(milliseconds: 20));
        await tester.sendKeyEvent(LogicalKeyboardKey.mediaPlay);
        await tester.pump(const Duration(milliseconds: 200));

        expect(pl.playerStatus, PlayerStatus.playing);
        expect(pl.pauseCount, 2);
        expect(pl.doubleTapCenterCount, 0);
      },
    );
  });

  group('action table (M14.2)', _actionTableTests);

  group('recorded D-pad paths (M13.3)', _recordedPaths);

  group('layout, groups and editor (M14.3)', _layoutTests);
}

/// The remote's menu key, which opens and closes the HUD.
const LogicalKeyboardKey menuKey = LogicalKeyboardKey.contextMenu;

/// The HUD's time bar; present while the full HUD is open over a video.
final Finder _timeBar = find.byKey(TvPlayerHud.timeBarKey);

/// The time bar's play/pause status icon.
Finder _timeBarIcon(IconData icon) =>
    find.descendant(of: _timeBar, matching: find.byIcon(icon));

/// The seek preview's time text.
Finder _seekText(String text) => find.descendant(
  of: find.byKey(TvPlayerHud.seekPreviewKey),
  matching: find.text(text),
);

Finder _seekIcon(IconData icon) => find.descendant(
  of: find.byKey(TvPlayerHud.seekPreviewKey),
  matching: find.byIcon(icon),
);

/// Whether the primary focus node lives inside the widget with [key].
bool _focusOn(Key key) {
  final BuildContext? focusContext =
      FocusManager.instance.primaryFocus?.context;
  if (focusContext == null) return false;
  return find
      .descendant(
        of: find.byKey(key),
        matching: find.byElementPredicate((e) => identical(e, focusContext)),
        matchRoot: true,
      )
      .evaluate()
      .isNotEmpty;
}

/// [text] inside the widget with [key].
Finder _textIn(Key key, String text) =>
    find.descendant(of: find.byKey(key), matching: find.text(text));

/// The open TV option list (倍速, 画面比例, 选集, 字幕 and the rest).
final Finder _optionList = find.byKey(TvPlayerHud.optionListKey);

/// The option list's row at [index].
Finder _optionRow(int index) => find.byKey(TvPlayerHud.optionItemKey(index));

/// Expects the option list's row at [index] to be labelled [label].
void _expectOption(int index, String label) => expect(
  find.descendant(of: _optionRow(index), matching: find.text(label)),
  findsOneWidget,
  reason: 'option row $index',
);

// ---------------------------------------------------------------------------
// Recorded D-pad paths (M13.3) for the video page in split view, its
// comments in three layers, and the player HUD. The harness and what a known
// failure is are in `tv_path_harness.dart`; the other screens' paths are in
// `tv_paths_test.dart`.
//
// The scene copies `VideoDetailPage`'s landscape layout at the TV's logical
// size: the real `TvPlayerHud` over the player, the introduction under it,
// and a `MiniScaffold` on the right with the tab bar over the related list
// and the comments. Related cards are `VideoCardH`, with the `⋮` laid beside
// the card's `InkWell` in a `Stack`. Comments are `ReplyItemGrpc`, with their
// actions inside the card's `InkWell`, under a floating reply button. The
// second layer (`评论详情`) and the third (`对话列表`) open as inline sheets.

class _VideoPageScene {
  _VideoPageScene()
    : outer = GlobalKey<MiniScaffoldState>(),
      inner = GlobalKey<MiniScaffoldState>(),
      title = pathNode('title'),
      actions = [
        for (final String a in ['点赞', '投币', '收藏', '稍后', '分享']) pathNode(a),
      ],
      related = List<FocusNode>.generate(8, (i) => pathNode('related $i')),
      relatedMenus = List<FocusNode>.generate(8, (i) => pathNode('⋮ $i')),
      sort = pathNode('sort'),
      comments = List<FocusNode>.generate(8, (i) => pathNode('comment $i')),
      commentReplies = List<FocusNode>.generate(
        8,
        (i) => pathNode('回复 $i'),
      ),
      commentLikes = List<FocusNode>.generate(8, (i) => pathNode('点赞 $i')),
      replyFab = pathNode('发表评论'),
      secondClose = pathNode('close 评论详情'),
      replies = List<FocusNode>.generate(6, (i) => pathNode('reply $i')),
      dialogue = pathNode('查看对话'),
      thirdClose = pathNode('close 对话列表'),
      thirdItems = List<FocusNode>.generate(4, (i) => pathNode('dialogue $i'));

  final GlobalKey<MiniScaffoldState> outer;
  final GlobalKey<MiniScaffoldState> inner;
  final FocusNode title;
  final List<FocusNode> actions;
  final List<FocusNode> related;
  final List<FocusNode> relatedMenus;
  final FocusNode sort;
  final List<FocusNode> comments;
  final List<FocusNode> commentReplies;
  final List<FocusNode> commentLikes;
  final FocusNode replyFab;
  final FocusNode secondClose;
  final List<FocusNode> replies;
  final FocusNode dialogue;
  final FocusNode thirdClose;
  final List<FocusNode> thirdItems;

  Widget _sheetHeader(String text, FocusNode close) => SizedBox(
    height: 45,
    child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(text),
        IconButton(
          focusNode: close,
          tooltip: '关闭',
          icon: const Icon(Icons.close, size: 20),
          onPressed: Get.back,
        ),
      ],
    ),
  );

  void _openThird() {
    inner.currentState!.showBottomSheet(
      constraints: const BoxConstraints(),
      (context) => ColoredBox(
        color: Colors.black,
        child: Column(
          children: [
            _sheetHeader('对话列表', thirdClose),
            Expanded(
              child: ListView(
                children: [
                  for (final FocusNode n in thirdItems)
                    SizedBox(
                      height: 90,
                      child: InkWell(
                        focusNode: n,
                        onTap: () {},
                        child: Text(n.debugLabel!),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _openSecond() {
    outer.currentState!.showBottomSheet(
      constraints: const BoxConstraints(),
      (context) => ColoredBox(
        color: Colors.black,
        child: MiniScaffold(
          key: inner,
          body: Column(
            children: [
              _sheetHeader('评论详情', secondClose),
              Expanded(
                child: ListView(
                  children: [
                    for (int i = 0; i < replies.length; i++)
                      InkWell(
                        focusNode: replies[i],
                        onTap: () {},
                        child: SizedBox(
                          height: 110,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('reply $i'),
                              const Spacer(),
                              if (i == 1)
                                SizedBox(
                                  height: 32,
                                  child: TextButton(
                                    focusNode: dialogue,
                                    onPressed: _openThird,
                                    child: const Text('查看对话'),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _related() => CustomScrollView(
    slivers: [
      SliverList.builder(
        itemCount: related.length,
        itemBuilder: (context, i) => SizedBox(
          height: 100,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              InkWell(
                focusNode: related[i],
                onTap: () {},
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 5,
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const AspectRatio(
                        aspectRatio: 16 / 10,
                        child: Placeholder(),
                      ),
                      const SizedBox(width: 10),
                      Expanded(child: Text('related $i')),
                    ],
                  ),
                ),
              ),
              Positioned(
                bottom: 0,
                right: 12,
                width: 29,
                height: 29,
                child: IconButton(
                  focusNode: relatedMenus[i],
                  padding: EdgeInsets.zero,
                  iconSize: 17,
                  onPressed: () {},
                  icon: const Icon(Icons.more_vert_outlined),
                ),
              ),
            ],
          ),
        ),
      ),
    ],
  );

  Widget _comments() => SimpleScaffold(
    fab: Padding(
      padding: const EdgeInsets.only(
        right: kFloatingActionButtonMargin,
        bottom: kFloatingActionButtonMargin,
      ),
      child: FloatingActionButton(
        focusNode: replyFab,
        heroTag: null,
        onPressed: () {},
        tooltip: '发表评论',
        child: const Icon(Icons.reply),
      ),
    ),
    body: CustomScrollView(
      slivers: [
        SliverToBoxAdapter(
          child: Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              focusNode: sort,
              onPressed: () {},
              child: const Text('按热度'),
            ),
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.only(bottom: 100),
          sliver: SliverList.builder(
            itemCount: comments.length,
            itemBuilder: (context, i) => InkWell(
              focusNode: comments[i],
              onTap: _openSecond,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 12, 8, 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 34, child: Text('user  10-09')),
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Text('comment $i'),
                    ),
                    Row(
                      children: [
                        const SizedBox(width: 36),
                        SizedBox(
                          height: 32,
                          child: TextButton(
                            focusNode: commentReplies[i],
                            onPressed: _openSecond,
                            child: const Text('回复'),
                          ),
                        ),
                        const Spacer(),
                        SizedBox(
                          height: 32,
                          child: TextButton(
                            focusNode: commentLikes[i],
                            onPressed: () {},
                            child: const Text('点赞'),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    ),
  );

  Widget build(
    FakePlPlayerController pl, {
    int tab = 0,
    FakeUgcIntroController? intro,
    TvHudUpstream? upstream,
  }) => GetMaterialApp(
    navigatorObservers: [FlutterSmartDialog.observer],
    builder: FlutterSmartDialog.init(
      builder: (context, child) => TvNavigation(child: child!),
    ),
    theme: ThemeData(
      colorScheme: ColorScheme.fromSeed(
        seedColor: Colors.deepPurple,
        brightness: Brightness.dark,
      ),
    ),
    home: Scaffold(
      body: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 560,
            child: Column(
              children: [
                SizedBox(
                  width: 560,
                  height: 315,
                  child: TvPlayerHud(
                    plPlayerController: pl,
                    introController: intro,
                    debugUpstream: upstream,
                    onSendDanmaku: () {},
                    child: Container(color: Colors.black),
                  ),
                ),
                SizedBox(
                  width: 560,
                  height: 225,
                  child: CustomScrollView(
                    slivers: [
                      SliverToBoxAdapter(
                        child: InkWell(
                          focusNode: title,
                          onTap: () {},
                          child: const SizedBox(
                            height: 60,
                            child: Text('title'),
                          ),
                        ),
                      ),
                      SliverToBoxAdapter(
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [
                            for (final FocusNode a in actions)
                              InkWell(
                                focusNode: a,
                                onTap: () {},
                                child: SizedBox(
                                  width: 80,
                                  height: 60,
                                  child: Text(a.debugLabel!),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          SizedBox(
            width: 400,
            height: 540,
            child: DefaultTabController(
              length: 2,
              initialIndex: tab,
              child: MiniScaffold(
                key: outer,
                body: Column(
                  children: [
                    const SizedBox(
                      height: 46,
                      child: TabBar(
                        tabs: [
                          Tab(text: '相关视频'),
                          Tab(text: '评论'),
                        ],
                      ),
                    ),
                    Expanded(
                      child: TabBarView(children: [_related(), _comments()]),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

Future<_VideoPageScene> _pumpVideoPage(
  WidgetTester tester, {
  bool fullScreen = false,
  int tab = 0,
  FakePlPlayerController? player,
  FakeUgcIntroController? intro,
  TvHudUpstream? upstream,
}) async {
  useTvScreen(tester);
  final _VideoPageScene scene = _VideoPageScene();
  final FakePlPlayerController pl = (player ?? FakePlPlayerController())
    ..isFullScreen.value = fullScreen;
  await tester.pumpWidget(
    scene.build(pl, tab: tab, intro: intro, upstream: upstream),
  );
  await tester.pumpAndSettle();
  return scene;
}

void _recordedPaths() {
  testWidgets('split view: the quick strip, the introduction and the related '
      'list beside them', (tester) async {
    await _pumpVideoPage(tester);
    await walkPath(tester, '全屏', [
      (dpadRight, '暂停'),
      (dpadLeft, '全屏'),
      (dpadDown, 'title'),
      (dpadDown, '点赞'),
      (dpadRight, '投币'),
      (dpadRight, '收藏'),
      (dpadRight, '稍后'),
      (dpadRight, '分享'),
      (dpadRight, 'related 3'),
      (dpadUp, 'related 2'),
      (dpadUp, 'related 1'),
      (dpadUp, 'related 0'),
      (dpadUp, '相关视频'),
      (dpadRight, '评论'),
    ]);
  });

  testWidgets(
    '[bug 3] Right from a related card reaches its ⋮',
    (tester) async {
      final _VideoPageScene s = await _pumpVideoPage(tester);
      await focusForPath(tester, s.related[1]);
      await walkPath(tester, 'related 1', [
        (dpadRight, '⋮ 1'),
        (dpadLeft, 'related 1'),
      ]);
    },
  );

  testWidgets('comments: the first layer, its actions, the second layer '
      '(评论详情) and the third (对话列表), and Back to each trigger', (
    tester,
  ) async {
    final _VideoPageScene s = await _pumpVideoPage(tester, tab: 1);
    await focusForPath(tester, s.comments[0]);
    await walkPath(tester, 'comment 0', [
      (dpadDown, 'comment 1'),
      (dpadUp, 'comment 0'),
      (dpadUp, 'sort'),
      (dpadDown, 'comment 0'),
      (dpadRight, '回复 0'),
      (dpadRight, '点赞 0'),
      (dpadRight, '点赞 0'),
      (dpadLeft, '回复 0'),
      (dpadLeft, 'comment 0'),
      (dpadDown, 'comment 1'),
      (dpadSelect, 'close 评论详情'),
      (dpadDown, 'reply 0'),
      (dpadDown, 'reply 1'),
      (dpadRight, '查看对话'),
      (dpadSelect, 'close 对话列表'),
      (dpadDown, 'dialogue 0'),
      (dpadDown, 'dialogue 1'),
      (dpadBack, '查看对话'),
      (dpadUp, 'reply 0'),
      (dpadBack, 'comment 1'),
      (dpadDown, 'comment 2'),
    ]);
  });

  testWidgets('[bug 2] Down from the last comment reaches the '
      'reply button', (tester) async {
    final _VideoPageScene s = await _pumpVideoPage(tester, tab: 1);
    await focusForPath(tester, s.comments[5]);
    await walkPath(tester, 'comment 5', [
      (dpadDown, 'comment 6'),
      (dpadDown, 'comment 7'),
      (dpadDown, '发表评论'),
    ]);
  });

  testWidgets('player HUD: the menu key opens it on the time bar, the D-pad '
      'moves through the default layout and the ⋮ menu, and Back closes it', (
    tester,
  ) async {
    await _pumpVideoPage(tester);
    await walkPath(tester, '全屏', [
      (menuKey, '00:30'),
      (dpadDown, '倍速: 1.0x'),
      (dpadRight, '画面: 自动'),
      (dpadLeft, '倍速: 1.0x'),
      (dpadUp, '00:30'),
      (dpadUp, '弹幕: 开'),
      (dpadRight, '弹幕设置'),
      (dpadRight, '更多'),
      (dpadSelect, '倍速: 1.0x'),
      (dpadDown, '画面: 自动'),
      (dpadBack, '更多'),
      (dpadDown, '00:30'),
      (dpadBack, '全屏'),
    ]);
  });

  testWidgets('player HUD: a custom layout, with labels off and 点赞 and '
      '收藏 pinned top right', (tester) async {
    _saveGroups(
      const TvHudGroups(
        topRight: [TvHudActionId.like, TvHudActionId.favorite],
        bottom: [TvHudActionId.speed, TvHudActionId.danmakuToggle],
        showLabels: false,
      ),
    );
    final FakePlPlayerController pl = FakePlPlayerController();
    final FakeVideoDetailController vdc = FakeVideoDetailController(
      plPlayerController: pl,
    );
    await _pumpVideoPage(
      tester,
      player: pl,
      intro: FakeUgcIntroController(videoDetailCtr: vdc),
    );
    await walkPath(tester, '全屏', [
      (menuKey, '00:30'),
      // Icon-only: the name is the focus label drawn under the button.
      (dpadDown, '倍速: 1.0x'),
      (dpadRight, '弹幕: 开'),
      (dpadUp, '00:30'),
      (dpadUp, '点赞 (长按三连)'),
      (dpadRight, '收藏'),
      (dpadRight, '更多'),
      (dpadLeft, '收藏'),
      (dpadDown, '00:30'),
      (dpadBack, '全屏'),
    ]);
  });
}

// ---------------------------------------------------------------------------
// The action table (M14.2): one test per entry, for when it's available and
// what it does, plus upstream's own panels opened with the D-pad.

/// Upstream's header panels, recorded. Each opens a small `PublishRoute`
/// through upstream's `PageUtils.showVideoBottomSheet`, as the real ones do,
/// so the HUD's focus hand-off around a panel is exercised.
class _FakeHeaderPanels implements TvHudHeaderPanels {
  final List<String> calls = [];

  void _open(String name) {
    calls.add(name);
    PageUtils.showVideoBottomSheet(
      Get.key.currentContext!,
      child: Material(
        child: ListView(
          children: [
            for (int i = 0; i < 3; i++)
              ListTile(title: Text('$name $i'), onTap: () {}),
          ],
        ),
      ),
    );
  }

  @override
  void showSetVideoQa() => _open('showSetVideoQa');

  @override
  void showSetAudioQa() => _open('showSetAudioQa');

  @override
  void showSetDecodeFormats() => _open('showSetDecodeFormats');

  @override
  void showSetSubtitle() => _open('showSetSubtitle');

  @override
  void showDanmakuPool() => _open('showDanmakuPool');

  @override
  void showSettingSheet() => _open('showSettingSheet');
}

class _FakeUpstream implements TvHudUpstream {
  _FakeUpstream({this.header});

  /// `null`: upstream's header isn't mounted.
  _FakeHeaderPanels? header;

  @override
  TvHudHeaderPanels? headerOf(VideoDetailController ctr) => header;

  int playerInfoCount = 0;
  @override
  void showPlayerInfo(BuildContext context, Player player) {
    playerInfoCount++;
  }

  int volumeCount = 0;
  @override
  Future<void> showPlayerVolume(BuildContext context, Player player) async {
    volumeCount++;
  }

  int viewPointsCount = 0;
  @override
  void showViewPoints(BuildContext context, VideoDetailController ctr) {
    viewPointsCount++;
    PageUtils.showVideoBottomSheet(
      context,
      child: Material(
        child: ListView(
          children: [
            for (final ViewPointSegment s in ctr.viewPointList)
              ListTile(title: Text(s.title ?? ''), onTap: () {}),
          ],
        ),
      ),
    );
  }

  int shutdownCount = 0;
  bool? shutdownIsLive;
  @override
  void showShutdownTimer(
    BuildContext context, {
    required bool isFullScreen,
    required bool isLive,
  }) {
    shutdownCount++;
    shutdownIsLive = isLive;
  }
}

class _FakeDanmakuController extends Fake
    implements DanmakuController<DanmakuExtra> {}

/// A fullscreen HUD over a UGC video in a three-part list, with upstream's
/// header mounted unless [header] is false.
class _ActionScene {
  _ActionScene({bool header = true}) {
    vdc = FakeVideoDetailController(plPlayerController: pl);
    intro = FakeUgcIntroController(videoDetailCtr: vdc);
    upstream = _FakeUpstream(header: header ? _FakeHeaderPanels() : null);
  }

  final FakePlPlayerController pl = FakePlPlayerController()
    ..isFullScreen.value = true;
  late final FakeVideoDetailController vdc;
  late final FakeUgcIntroController intro;
  late final _FakeUpstream upstream;
  bool withIntro = true;
  VoidCallback? onRefresh;
  ValueGetter<bool>? onSkipSegment;

  _FakeHeaderPanels get header => upstream.header!;

  Future<TvHudActionSource> pump(WidgetTester tester) async {
    await _pumpHud(
      tester,
      plPlayerController: pl,
      introController: withIntro ? intro : null,
      upstream: upstream,
      onRefresh: onRefresh,
      onSkipSegment: onSkipSegment,
    );
    return tester.state(find.byType(TvPlayerHud)) as TvHudActionSource;
  }
}

List<String> _ids(TvHudActionSource source, TvHudActionId id) => [
  for (final TvHudAction a in source.resolveAction(id)) a.buttonId,
];

TvHudAction _one(TvHudActionSource source, TvHudActionId id) {
  final List<TvHudAction> actions = source.resolveAction(id);
  expect(actions, hasLength(1), reason: '$id resolves to one button');
  return actions.single;
}

/// Whether primary focus is on a control (not just a scope) inside the route
/// that shows [text].
bool _focusInsideRouteOf(String text) {
  final FocusNode? node = FocusManager.instance.primaryFocus;
  if (node == null || node is FocusScopeNode) return false;
  final BuildContext? focus = node.context;
  if (focus == null) return false;
  final Element textElement = find.text(text).evaluate().first;
  return ModalRoute.of(focus) == ModalRoute.of(textElement);
}

void _actionTableTests() {
  test('every entry has a menu group, in menu order; only 编辑按钮 is '
      'not pinnable', () {
    final List<int> groups = [
      for (final TvHudActionId id in TvHudActionId.values) id.group.index,
    ];
    expect(groups, orderedEquals([...groups]..sort()));
    expect(TvHudMenuGroup.values.map((g) => g.label), [
      '播放',
      '弹幕',
      '互动',
      '画面与声音',
      '其他',
    ]);
    expect(
      TvHudActionId.values.where((id) => !id.pinnable),
      [TvHudActionId.editButtons],
    );
  });

  test('TV defaults turn on the danmaku trend that 高能进度条 needs', () {
    expect(TvPlatform.defaultTvSettings[SettingBoxKey.showDmChart], isTrue);
  });

  testWidgets('画质 opens upstream\'s quality panel; hidden without the '
      'header, for offline files and in picture-in-picture', (tester) async {
    final _ActionScene scene = _ActionScene();
    final TvHudActionSource source = await scene.pump(tester);

    final TvHudAction quality = _one(source, TvHudActionId.quality);
    expect(quality.label, '画质: 1080P');
    quality.onPressed();
    await tester.pumpAndSettle();
    expect(scene.header.calls, ['showSetVideoQa']);
    expect(find.text('showSetVideoQa 0'), findsOneWidget);

    Navigator.of(tester.element(find.text('showSetVideoQa 0'))).pop();
    await tester.pumpAndSettle();

    scene.pl.isPipMode = true;
    expect(_ids(source, TvHudActionId.quality), isEmpty);
    scene.pl.isPipMode = false;
    scene.vdc.isFileSource = true;
    expect(_ids(source, TvHudActionId.quality), isEmpty);
    scene.vdc.isFileSource = false;
    scene.upstream.header = null;
    expect(_ids(source, TvHudActionId.quality), isEmpty);
  });

  testWidgets('the HUD drops its 画质 button while upstream\'s header '
      'isn\'t mounted', (tester) async {
    final _ActionScene scene = _ActionScene(header: false);
    await scene.pump(tester);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
    await tester.pumpAndSettle();
    expect(find.byKey(TvHudAction.keyOf('quality')), findsNothing);
    expect(find.byKey(TvHudAction.keyOf('speed')), findsOneWidget);
  });

  testWidgets('倍速 shows the speed and opens the speed list; not in live '
      'rooms', (tester) async {
    final _ActionScene scene = _ActionScene();
    scene.pl.playbackSpeed = 1.25;
    final TvHudActionSource source = await scene.pump(tester);
    final TvHudAction speed = _one(source, TvHudActionId.speed);
    expect(speed.label, '倍速: 1.25x');
    speed.onPressed();
    await tester.pumpAndSettle();
    _expectOption(4, '1.5x');
    await tester.tap(_optionRow(4));
    await tester.pumpAndSettle();
    expect(scene.pl.playbackSpeed, 1.5);

    scene.pl.isLive = true;
    expect(_ids(source, TvHudActionId.speed), isEmpty);
    await tester.pump(const Duration(seconds: 3));
  });

  testWidgets('画面比例 is always there and sets the fit', (tester) async {
    final _ActionScene scene = _ActionScene();
    final TvHudActionSource source = await scene.pump(tester);
    final TvHudAction fit = _one(source, TvHudActionId.videoFit);
    expect(fit.label, '画面: ${VideoFitType.contain.desc}');
    fit.onPressed();
    await tester.pumpAndSettle();
    final int fillRow = VideoFitType.values.indexOf(VideoFitType.fill);
    _expectOption(fillRow, VideoFitType.fill.desc);
    await tester.tap(_optionRow(fillRow));
    await tester.pumpAndSettle();
    expect(scene.pl.videoFit.value, VideoFitType.fill);
    scene.pl.isLive = true;
    expect(_ids(source, TvHudActionId.videoFit), ['videoFit']);
    await tester.pump(const Duration(seconds: 3));
  });

  testWidgets('字幕 lists the tracks with upstream\'s 字幕设置 at the end; '
      'hidden without tracks', (tester) async {
    final _ActionScene scene = _ActionScene();
    final TvHudActionSource source = await scene.pump(tester);
    expect(_ids(source, TvHudActionId.subtitle), isEmpty);

    scene.vdc.subtitles.addAll([
      Subtitle(id: 1, lan: 'zh', lanDoc: '中文'),
      Subtitle(id: 2, lan: 'en', lanDoc: 'English'),
    ]);
    TvHudAction subtitle = _one(source, TvHudActionId.subtitle);
    expect(subtitle.label, '字幕: 关闭');
    expect(subtitle.active, isFalse);

    subtitle.onPressed();
    await tester.pumpAndSettle();
    _expectOption(0, '关闭字幕');
    _expectOption(1, '中文');
    _expectOption(2, 'English');
    _expectOption(3, '字幕设置');
    await tester.tap(_optionRow(2));
    await tester.pumpAndSettle();
    expect(scene.vdc.vttSubtitlesIndex.value, 2);

    subtitle = _one(source, TvHudActionId.subtitle);
    expect(subtitle.label, '字幕: English');
    expect(subtitle.active, isTrue);
    subtitle.onPressed();
    await tester.pumpAndSettle();
    _expectOption(3, '字幕设置');
    await tester.tap(_optionRow(3));
    await tester.pumpAndSettle();
    expect(scene.header.calls, ['showSetSubtitle']);
    Navigator.of(tester.element(find.text('showSetSubtitle 0'))).pop();
    await tester.pumpAndSettle();

    // Without upstream's header the list has no 字幕设置 row.
    scene.upstream.header = null;
    _one(source, TvHudActionId.subtitle).onPressed();
    await tester.pumpAndSettle();
    _expectOption(0, '关闭字幕');
    _expectOption(2, 'English');
    expect(_optionRow(3), findsNothing);
    expect(_textIn(TvPlayerHud.optionListKey, '字幕设置'), findsNothing);
  });

  testWidgets('翻译 lists the video\'s languages and switches them; hidden '
      'without languages and for offline files', (tester) async {
    final _ActionScene scene = _ActionScene();
    final TvHudActionSource source = await scene.pump(tester);
    expect(_ids(source, TvHudActionId.aiTranslate), isEmpty);

    scene.vdc.languages.value = [
      play_url.LanguageItem(lang: 'en', title: '英语'),
      play_url.LanguageItem(lang: 'ja', title: '日语'),
    ];
    TvHudAction translate = _one(source, TvHudActionId.aiTranslate);
    expect((translate.label, translate.active), ('翻译: 关闭', false));
    translate.onPressed();
    await tester.pumpAndSettle();
    _expectOption(0, '关闭翻译');
    _expectOption(1, '英语');
    _expectOption(2, '日语');
    await tester.tap(_optionRow(2));
    await tester.pumpAndSettle();
    expect(scene.vdc.currLang.value, 'ja');

    translate = _one(source, TvHudActionId.aiTranslate);
    expect((translate.label, translate.active), ('翻译: 日语', true));
    translate.onPressed();
    await tester.pumpAndSettle();
    _expectOption(0, '关闭翻译');
    await tester.tap(_optionRow(0));
    await tester.pumpAndSettle();
    expect(scene.vdc.currLang.value, '');

    scene.pl.isFileSource = true;
    expect(_ids(source, TvHudActionId.aiTranslate), isEmpty);
  });

  testWidgets('分段信息 opens upstream\'s chapter panel; hidden without '
      'chapters, with the setting off, offline and in picture-in-picture', (
    tester,
  ) async {
    final _ActionScene scene = _ActionScene();
    final TvHudActionSource source = await scene.pump(tester);
    expect(_ids(source, TvHudActionId.viewPoints), isEmpty);

    scene.vdc.viewPointList.addAll(const [
      ViewPointSegment(end: 0.4, title: '开场', from: 0, to: 120),
      ViewPointSegment(end: 1.0, title: '正片', from: 120, to: 300),
    ]);
    final TvHudAction chapters = _one(source, TvHudActionId.viewPoints);
    expect((chapters.label, chapters.active), ('分段信息', true));
    chapters.onPressed();
    await tester.pumpAndSettle();
    expect(scene.upstream.viewPointsCount, 1);
    expect(find.text('正片'), findsOneWidget);
    Navigator.of(tester.element(find.text('正片'))).pop();
    await tester.pumpAndSettle();

    scene.vdc.showVP.value = false;
    expect(_one(source, TvHudActionId.viewPoints).active, isFalse);
    scene.pl.showViewPoints = false;
    expect(_ids(source, TvHudActionId.viewPoints), isEmpty);
    scene.pl
      ..showViewPoints = true
      ..isFileSource = true;
    expect(_ids(source, TvHudActionId.viewPoints), isEmpty);
    scene.pl
      ..isFileSource = false
      ..isPipMode = true;
    expect(_ids(source, TvHudActionId.viewPoints), isEmpty);
  });

  testWidgets('片段信息 opens upstream\'s segment list; hidden with blocking '
      'off, without segments, offline and in picture-in-picture', (
    tester,
  ) async {
    final _ActionScene scene = _ActionScene();
    final TvHudActionSource source = await scene.pump(tester);
    expect(_ids(source, TvHudActionId.segments), isEmpty);
    scene.vdc.segmentProgressList.add(
      const Segment(start: 0.1, end: 0.2, color: Colors.green),
    );
    expect(_ids(source, TvHudActionId.segments), isEmpty);

    scene.pl.enableBlock = true;
    final TvHudAction segments = _one(source, TvHudActionId.segments);
    expect(segments.label, '片段信息');
    await _press(tester, dpadUp);
    segments.onPressed();
    await tester.pumpAndSettle();
    expect(scene.vdc.showSBDetailCount, 1);
    expect(find.text('showSBDetail'), findsOneWidget);
    expect(_timeBar, findsNothing);
    Navigator.of(tester.element(find.text('showSBDetail'))).pop();
    await tester.pumpAndSettle();

    scene.pl.isFileSource = true;
    expect(_ids(source, TvHudActionId.segments), isEmpty);
    scene.pl
      ..isFileSource = false
      ..isPipMode = true;
    expect(_ids(source, TvHudActionId.segments), isEmpty);
    scene.pl.isPipMode = false;
    scene.vdc.segmentProgressList.clear();
    expect(_ids(source, TvHudActionId.segments), isEmpty);
  });

  testWidgets('片段信息 sits in the ⋮ menu under 播放, after 分段信息', (
    tester,
  ) async {
    final _ActionScene scene = _ActionScene();
    scene.pl.enableBlock = true;
    scene.vdc.segmentProgressList.add(
      const Segment(start: 0.1, end: 0.2, color: Colors.green),
    );
    scene.vdc.viewPointList.add(
      const ViewPointSegment(end: 1.0, title: '正片', from: 0, to: 300),
    );
    await scene.pump(tester);
    await _press(tester, dpadUp);
    await _press(tester, dpadUp);
    await _focusKey(tester, TvPlayerHud.menuButtonKey);
    await _press(tester, dpadSelect);
    final Finder entry = find.byKey(TvPlayerHud.menuEntryKey('segments'));
    expect(entry, findsOneWidget);
    expect(
      tester.getRect(entry).top,
      greaterThan(
        tester.getRect(find.byKey(TvPlayerHud.menuEntryKey('viewPoints'))).top,
      ),
    );
    await _focusKey(tester, TvPlayerHud.menuEntryKey('segments'));
    await _press(tester, dpadSelect);
    expect(scene.vdc.showSBDetailCount, 1);
    Navigator.of(tester.element(find.text('showSBDetail'))).pop();
    await tester.pumpAndSettle();
  });

  testWidgets('Select with the HUD hidden answers a 手动跳过 prompt first', (
    tester,
  ) async {
    final _ActionScene scene = _ActionScene();
    int skips = 0;
    scene.onSkipSegment = () {
      skips++;
      return true;
    };
    await scene.pump(tester);
    await _press(tester, dpadSelect);
    expect(skips, 1);
    expect(scene.pl.doubleTapCenterCount, 0);
    expect(_timeBar, findsNothing);
  });

  testWidgets('Select with the HUD hidden opens 上次看到第XP, which upstream '
      'only opens by touch; with no prompt it plays and pauses', (
    tester,
  ) async {
    // Upstream's onSkipSegment finds no segment prompt.
    final _ActionScene scene = _ActionScene()..onSkipSegment = () => false;
    scene.vdc.listData.add(2); // 上次看到第3P
    await scene.pump(tester);
    await _press(tester, dpadSelect);
    expect((scene.intro.changedEpisode as Part?)?.cid, 1003);
    expect(scene.vdc.listData, isEmpty);
    expect(scene.pl.doubleTapCenterCount, 0);

    await _press(tester, dpadSelect);
    expect(scene.pl.doubleTapCenterCount, 1);
    await tester.pump(const Duration(seconds: 6));
  });

  testWidgets('the time bar shows the segments under it and the chapters '
      'over it, under upstream\'s conditions', (tester) async {
    final _ActionScene scene = _ActionScene();
    scene.vdc.segmentProgressList.add(
      const Segment(start: 0.1, end: 0.2, color: Colors.green),
    );
    scene.vdc.viewPointList.addAll(const [
      ViewPointSegment(end: 0.4, title: '开场', from: 0, to: 120),
      ViewPointSegment(end: 1.0, title: '正片', from: 120, to: 300),
    ]);
    await scene.pump(tester);
    await _press(tester, dpadUp);

    Finder inKey(Key key, Type type) =>
        find.descendant(of: find.byKey(key), matching: find.byType(type));
    // Blocking off: no segments, even with data.
    expect(
      inKey(TvPlayerHud.segmentMarksKey, SegmentProgressBar),
      findsNothing,
    );
    final Finder chapters = inKey(
      TvPlayerHud.chapterMarksKey,
      ViewPointSegmentProgressBar,
    );
    expect(chapters, findsOneWidget);

    // The chapter switch hides them.
    scene.vdc.showVP.value = false;
    await tester.pump();
    expect(chapters, findsNothing);
    scene.vdc.showVP.value = true;
    await tester.pump();

    // Blocking on (read when the HUD opens).
    await _press(tester, dpadBack);
    scene.pl.enableBlock = true;
    await _press(tester, dpadUp);
    final Finder segments = inKey(
      TvPlayerHud.segmentMarksKey,
      SegmentProgressBar,
    );
    expect(segments, findsOneWidget);

    final Rect bar = tester.getRect(_timeBar);
    final Rect segRect = tester.getRect(segments);
    final Rect chapterRect = tester.getRect(chapters);
    expect(segRect.top, greaterThan(chapterRect.bottom));
    // Both inside the time bar's box.
    expect(bar.contains(segRect.center), isTrue);
    expect(bar.contains(chapterRect.center), isTrue);
    await tester.pump(const Duration(seconds: 6));
  });

  testWidgets('选集: 上集 / 下集 / 选集 in a list, 下个视频 outside one, '
      'nothing for offline files or live rooms', (tester) async {
    final _ActionScene scene = _ActionScene();
    final TvHudActionSource source = await scene.pump(tester);

    final List<TvHudAction> inList = source.resolveAction(
      TvHudActionId.episodes,
    );
    expect(inList.map((a) => a.buttonId), [
      'episodes.prev',
      'episodes.next',
      'episodes.list',
    ]);
    expect(inList.map((a) => a.label), ['上集', '下集', '选集 (3)']);
    inList[0].onPressed();
    inList[1].onPressed();
    expect(scene.intro.prevPlayCount, 1);
    expect(scene.intro.nextPlayCount, 1);

    scene.intro.videoDetail.value = VideoDetailData(
      title: '单个视频',
      pages: [Part(cid: 1001, page: 1, part: '单P')],
    );
    final TvHudAction next = _one(source, TvHudActionId.episodes);
    expect(next.buttonId, 'episodes.nextVideo');
    expect(next.label, '下个视频');
    next.onPressed();
    expect(scene.intro.playRelatedCount, 1);

    scene.pl.isFileSource = true;
    expect(_ids(source, TvHudActionId.episodes), isEmpty);
    scene.pl
      ..isFileSource = false
      ..isLive = true;
    expect(_ids(source, TvHudActionId.episodes), isEmpty);
  });

  testWidgets('选集 is hidden without an introduction', (tester) async {
    final _ActionScene scene = _ActionScene()..withIntro = false;
    final TvHudActionSource source = await scene.pump(tester);
    expect(_ids(source, TvHudActionId.episodes), isEmpty);
  });

  testWidgets('播放顺序 shows the order and sets it; not in live rooms', (
    tester,
  ) async {
    final _ActionScene scene = _ActionScene();
    final TvHudActionSource source = await scene.pump(tester);
    final TvHudAction order = _one(source, TvHudActionId.playOrder);
    expect(order.label, '播放顺序: ${PlayRepeat.pause.label}');
    order.onPressed();
    await tester.pumpAndSettle();
    final int cycleRow = PlayRepeat.values.indexOf(PlayRepeat.listCycle);
    _expectOption(cycleRow, PlayRepeat.listCycle.label);
    await tester.tap(_optionRow(cycleRow));
    await tester.pumpAndSettle();
    expect(scene.pl.playRepeat, PlayRepeat.listCycle);
    scene.pl.isLive = true;
    expect(_ids(source, TvHudActionId.playOrder), isEmpty);
    await tester.pump(const Duration(seconds: 3));
  });

  testWidgets('弹幕开关 switches danmaku and shows its state', (tester) async {
    final _ActionScene scene = _ActionScene();
    final TvHudActionSource source = await scene.pump(tester);
    TvHudAction toggle = _one(source, TvHudActionId.danmakuToggle);
    expect((toggle.label, toggle.active), ('弹幕: 开', true));
    toggle.onPressed();
    expect(scene.pl.enableShowDanmakuAdaptive.value, isFalse);
    toggle = _one(source, TvHudActionId.danmakuToggle);
    expect((toggle.label, toggle.active), ('弹幕: 关', false));
    await tester.pump(const Duration(seconds: 3));
  });

  testWidgets('弹幕设置 opens upstream\'s danmaku panel, not the old TV '
      'dialog; hidden in picture-in-picture', (tester) async {
    final _ActionScene scene = _ActionScene();
    final TvHudActionSource source = await scene.pump(tester);
    _one(source, TvHudActionId.danmakuSettings).onPressed();
    await tester.pumpAndSettle();
    // Upstream's panel: smart blocking, its block types and sliders.
    expect(find.textContaining('智能云屏蔽'), findsOneWidget);
    expect(find.text('高级'), findsOneWidget);
    expect(find.textContaining('遥控器方向键选择'), findsNothing);
    Navigator.of(tester.element(find.textContaining('智能云屏蔽'))).pop();
    await tester.pumpAndSettle();

    scene.pl.isPipMode = true;
    expect(_ids(source, TvHudActionId.danmakuSettings), isEmpty);
  });

  testWidgets('高能进度条 shows once the trend has loaded and switches the '
      'chart; hidden with the setting off and for offline files', (
    tester,
  ) async {
    final _ActionScene scene = _ActionScene();
    final TvHudActionSource source = await scene.pump(tester);
    expect(_ids(source, TvHudActionId.dmChart), isEmpty);

    scene.vdc.dmTrend.value = const Success<List<double>>([0.1, 0.8, 0.3]);
    final TvHudAction chart = _one(source, TvHudActionId.dmChart);
    expect((chart.label, chart.active), ('高能进度条', true));
    chart.onPressed();
    expect(scene.vdc.showDmTrendChart.value, isFalse);
    expect(_one(source, TvHudActionId.dmChart).active, isFalse);

    scene.pl.showDmChart = false;
    expect(_ids(source, TvHudActionId.dmChart), isEmpty);
    scene.pl
      ..showDmChart = true
      ..isFileSource = true;
    expect(_ids(source, TvHudActionId.dmChart), isEmpty);
    await tester.pump(const Duration(seconds: 3));
  });

  testWidgets('弹幕列表 opens upstream\'s danmaku pool; hidden without '
      'danmaku or the header', (tester) async {
    final _ActionScene scene = _ActionScene();
    final TvHudActionSource source = await scene.pump(tester);
    expect(_ids(source, TvHudActionId.danmakuPool), isEmpty);
    scene.pl.danmakuController = _FakeDanmakuController();
    _one(source, TvHudActionId.danmakuPool).onPressed();
    await tester.pumpAndSettle();
    expect(scene.header.calls, ['showDanmakuPool']);
    Navigator.of(tester.element(find.text('showDanmakuPool 0'))).pop();
    await tester.pumpAndSettle();
    scene.upstream.header = null;
    expect(_ids(source, TvHudActionId.danmakuPool), isEmpty);
  });

  testWidgets('点赞 likes on a press and starts 三连 on a hold; hidden for '
      'offline files and live rooms', (tester) async {
    final _ActionScene scene = _ActionScene();
    final TvHudActionSource source = await scene.pump(tester);
    final TvHudAction like = _one(source, TvHudActionId.like);
    expect(like.label, '点赞 (长按三连)');
    like.onPressed();
    expect(scene.intro.likeCount, 1);
    like.onHoldStart!();
    expect(scene.pl.tripling, isTrue);
    like.onHoldEnd!(true);
    expect(scene.pl.tripling, isFalse);

    scene.intro.hasLike.value = true;
    expect(_one(source, TvHudActionId.like).label, '已赞 (长按三连)');
    scene.pl.isFileSource = true;
    expect(_ids(source, TvHudActionId.like), isEmpty);
    scene.pl
      ..isFileSource = false
      ..isLive = true;
    expect(_ids(source, TvHudActionId.like), isEmpty);
  });

  testWidgets('投币 closes the HUD and opens upstream\'s coin flow', (
    tester,
  ) async {
    _saveGroups(
      TvHudGroups.defaults.copyWith(bottom: const [TvHudActionId.coin]),
    );
    final _ActionScene scene = _ActionScene();
    final TvHudActionSource source = await scene.pump(tester);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
    await tester.pumpAndSettle();
    expect(find.byKey(TvHudAction.keyOf('coin')), findsOneWidget);
    _one(source, TvHudActionId.coin).onPressed();
    await tester.pumpAndSettle();
    expect(scene.intro.coinCount, 1);
    expect(find.byKey(TvHudAction.keyOf('coin')), findsNothing);
    scene.intro.coinNum.value = 1;
    expect(_one(source, TvHudActionId.coin).label, '已投币');
  });

  testWidgets('收藏 closes the HUD and opens upstream\'s favourites sheet', (
    tester,
  ) async {
    final _ActionScene scene = _ActionScene();
    final TvHudActionSource source = await scene.pump(tester);
    _one(source, TvHudActionId.favorite).onPressed();
    await tester.pumpAndSettle();
    expect(scene.intro.favSheetCount, 1);
    scene.intro.hasFav.value = true;
    final TvHudAction fav = _one(source, TvHudActionId.favorite);
    expect((fav.label, fav.active), ('已收藏', true));
  });

  testWidgets('稍后再看 adds to and removes from the watch-later list', (
    tester,
  ) async {
    final _ActionScene scene = _ActionScene();
    final TvHudActionSource source = await scene.pump(tester);
    expect(_one(source, TvHudActionId.watchLater).label, '稍后再看');
    _one(source, TvHudActionId.watchLater).onPressed();
    await tester.pump();
    final TvHudAction later = _one(source, TvHudActionId.watchLater);
    expect((later.label, later.active), ('已在稍后再看', true));
    scene.withIntro = false;
    scene.pl.isLive = true;
    expect(_ids(source, TvHudActionId.watchLater), isEmpty);
  });

  testWidgets('音质 opens upstream\'s audio panel once the video has audio '
      'streams', (tester) async {
    final _ActionScene scene = _ActionScene();
    final TvHudActionSource source = await scene.pump(tester);
    expect(_ids(source, TvHudActionId.audioQuality), isEmpty);

    scene.vdc
      ..currentAudioQa = AudioQuality.k192
      ..data = play_url.PlayUrlModel.fromJson({
        'dash': {
          'duration': 300,
          'video': [
            {'id': VideoQuality.high1080.code},
          ],
          'audio': [
            {'id': AudioQuality.k192.code},
          ],
        },
        'support_formats': [
          {'quality': VideoQuality.high1080.code, 'new_description': '1080P'},
        ],
      });
    final TvHudAction audio = _one(source, TvHudActionId.audioQuality);
    expect(audio.label, '音质: ${AudioQuality.k192.desc}');
    audio.onPressed();
    await tester.pumpAndSettle();
    expect(scene.header.calls, ['showSetAudioQa']);
    Navigator.of(tester.element(find.text('showSetAudioQa 0'))).pop();
    await tester.pumpAndSettle();
    scene.vdc.isFileSource = true;
    expect(_ids(source, TvHudActionId.audioQuality), isEmpty);
  });

  testWidgets('解码格式 opens upstream\'s codec panel; hidden without the '
      'header', (tester) async {
    final _ActionScene scene = _ActionScene();
    final TvHudActionSource source = await scene.pump(tester);
    _one(source, TvHudActionId.decodeFormat).onPressed();
    await tester.pumpAndSettle();
    expect(scene.header.calls, ['showSetDecodeFormats']);
    Navigator.of(tester.element(find.text('showSetDecodeFormats 0'))).pop();
    await tester.pumpAndSettle();
    scene.upstream.header = null;
    expect(_ids(source, TvHudActionId.decodeFormat), isEmpty);
  });

  testWidgets('超分辨率 is for animation only and sets the shader', (
    tester,
  ) async {
    final _ActionScene scene = _ActionScene();
    final TvHudActionSource source = await scene.pump(tester);
    expect(_ids(source, TvHudActionId.superResolution), isEmpty);
    scene.pl.isAnim = true;
    final TvHudAction sr = _one(source, TvHudActionId.superResolution);
    expect(sr.label, '超分辨率: ${SuperResolutionType.disable.label}');
    sr.onPressed();
    await tester.pumpAndSettle();
    final int qualityRow = SuperResolutionType.values.indexOf(
      SuperResolutionType.quality,
    );
    _expectOption(qualityRow, SuperResolutionType.quality.label);
    await tester.tap(_optionRow(qualityRow));
    await tester.pumpAndSettle();
    expect(scene.pl.superResolutionType.value, SuperResolutionType.quality);
    await tester.pump(const Duration(seconds: 3));
  });

  testWidgets('播放器音量 opens upstream\'s volume dialog; hidden without a '
      'player', (tester) async {
    final _ActionScene scene = _ActionScene();
    final TvHudActionSource source = await scene.pump(tester);
    expect(
      _one(source, TvHudActionId.playerVolume).label,
      startsWith('播放器音量: '),
    );
    _one(source, TvHudActionId.playerVolume).onPressed();
    await tester.pumpAndSettle();
    expect(scene.upstream.volumeCount, 1);
    scene.pl.noPlayer = true;
    expect(_ids(source, TvHudActionId.playerVolume), isEmpty);
  });

  testWidgets('定时关闭 opens upstream\'s timer panel, for live rooms too', (
    tester,
  ) async {
    final _ActionScene scene = _ActionScene();
    final TvHudActionSource source = await scene.pump(tester);
    _one(source, TvHudActionId.shutdownTimer).onPressed();
    await tester.pumpAndSettle();
    expect(scene.upstream.shutdownCount, 1);
    expect(scene.upstream.shutdownIsLive, isFalse);
    scene.pl.isLive = true;
    _one(source, TvHudActionId.shutdownTimer).onPressed();
    expect(scene.upstream.shutdownIsLive, isTrue);
    scene.pl.isPipMode = true;
    expect(_ids(source, TvHudActionId.shutdownTimer), isEmpty);
  });

  testWidgets('重载视频 reloads the video, or refreshes a live room', (
    tester,
  ) async {
    int refreshed = 0;
    final _ActionScene scene = _ActionScene()..onRefresh = () => refreshed++;
    final TvHudActionSource source = await scene.pump(tester);
    _one(source, TvHudActionId.reload).onPressed();
    expect(scene.vdc.reloadCount, 1);

    scene.vdc.isFileSource = true;
    expect(_ids(source, TvHudActionId.reload), isEmpty);
    scene.pl.isLive = true;
    _one(source, TvHudActionId.reload).onPressed();
    expect(refreshed, 1);
  });

  testWidgets('重载视频 is hidden in a live room with nothing to refresh', (
    tester,
  ) async {
    final _ActionScene scene = _ActionScene();
    scene.pl.isLive = true;
    final TvHudActionSource source = await scene.pump(tester);
    expect(_ids(source, TvHudActionId.reload), isEmpty);
  });

  testWidgets('播放信息 opens upstream\'s player info; hidden without a '
      'player', (tester) async {
    final _ActionScene scene = _ActionScene();
    final TvHudActionSource source = await scene.pump(tester);
    _one(source, TvHudActionId.playerInfo).onPressed();
    await tester.pumpAndSettle();
    expect(scene.upstream.playerInfoCount, 1);
    scene.pl.noPlayer = true;
    expect(_ids(source, TvHudActionId.playerInfo), isEmpty);
  });

  testWidgets('完整设置 opens upstream\'s whole settings sheet; hidden '
      'without the header', (tester) async {
    final _ActionScene scene = _ActionScene();
    final TvHudActionSource source = await scene.pump(tester);
    _one(source, TvHudActionId.fullSettings).onPressed();
    await tester.pumpAndSettle();
    expect(scene.header.calls, ['showSettingSheet']);
    Navigator.of(tester.element(find.text('showSettingSheet 0'))).pop();
    await tester.pumpAndSettle();
    scene.upstream.header = null;
    expect(_ids(source, TvHudActionId.fullSettings), isEmpty);
  });

  testWidgets('编辑按钮 is always there and opens the editor', (tester) async {
    final _ActionScene scene = _ActionScene();
    final TvHudActionSource source = await scene.pump(tester);
    _one(source, TvHudActionId.editButtons).onPressed();
    await tester.pumpAndSettle();
    expect(find.byKey(TvPlayerHud.editorKey), findsOneWidget);
  });

  testWidgets('D-pad: 弹幕设置 opens upstream\'s danmaku panel with focus '
      'inside it, and Back returns to the player', (tester) async {
    await _pumpVideoPage(tester);
    await walkPath(tester, '全屏', [
      (menuKey, '00:30'),
      (dpadUp, '弹幕: 开'),
      (dpadRight, '弹幕设置'),
    ]);
    await tester.sendKeyEvent(dpadSelect);
    await tester.pumpAndSettle();
    expect(find.textContaining('智能云屏蔽'), findsOneWidget);
    expect(_focusInsideRouteOf('弹幕设置'), isTrue);
    for (int i = 0; i < 3; i++) {
      await tester.sendKeyEvent(dpadDown);
      await tester.pumpAndSettle();
      expect(_focusInsideRouteOf('弹幕设置'), isTrue);
    }
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.textContaining('智能云屏蔽'), findsNothing);
    expect(focusedLabel(), '全屏');
  });

  testWidgets('D-pad: 画质 opens upstream\'s quality panel with focus inside '
      'it, and Back returns to the player', (tester) async {
    final FakePlPlayerController pl = FakePlPlayerController();
    final FakeVideoDetailController vdc = FakeVideoDetailController(
      plPlayerController: pl,
    );
    final _FakeUpstream upstream = _FakeUpstream(header: _FakeHeaderPanels());
    await _pumpVideoPage(
      tester,
      player: pl,
      intro: FakeUgcIntroController(videoDetailCtr: vdc),
      upstream: upstream,
    );
    await walkPath(tester, '全屏', [
      (menuKey, '00:30'),
      (dpadDown, '上集'),
    ]);
    // Right along the row until 画质.
    for (int i = 0; i < 12 && focusedLabel() != '画质: 1080P'; i++) {
      await tester.sendKeyEvent(dpadRight);
      await tester.pumpAndSettle();
    }
    expect(focusedLabel(), '画质: 1080P');
    await tester.sendKeyEvent(dpadSelect);
    await tester.pumpAndSettle();
    expect(upstream.header!.calls, ['showSetVideoQa']);
    expect(_focusInsideRouteOf('showSetVideoQa 0'), isTrue);
    await tester.sendKeyEvent(dpadDown);
    await tester.pumpAndSettle();
    expect(_focusInsideRouteOf('showSetVideoQa 0'), isTrue);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.text('showSetVideoQa 0'), findsNothing);
    expect(focusedLabel(), '全屏');
  });
}

// ---------------------------------------------------------------------------
// M14.3: the layout, the editable groups, the ⋮ menu and the editor.

/// Saves [groups] as the editor does. The test box is in memory, and Hive
/// updates it at once, so the write needn't be awaited inside the fake clock.
void _saveGroups(TvHudGroups groups) =>
    unawaited(groups.save(GStorage.setting));

/// The saved lists, read straight from the settings box.
List<Object?> _savedIds(String key) =>
    (GStorage.setting.get(key) as List?)?.toList() ?? const ['(nothing)'];

/// Focuses the HUD control with [key] (a pill, or an editor button).
Future<void> _focusKey(WidgetTester tester, Key key) async {
  // The control's own Focus is the outermost one under the key; the pills'
  // `ExcludeFocus` adds another further down.
  final Element focus = find
      .descendant(
        of: find.byKey(key),
        matching: find.byType(Focus),
        matchRoot: true,
      )
      .evaluate()
      .first;
  Element? child;
  focus.visitChildElements((Element e) => child = e);
  Focus.of(child!, createDependency: false).requestFocus();
  await tester.pumpAndSettle();
}

Future<void> _press(WidgetTester tester, LogicalKeyboardKey key) async {
  if (key == dpadBack) {
    await tester.binding.handlePopRoute();
  } else {
    await tester.sendKeyEvent(key);
  }
  await tester.pumpAndSettle();
}

/// The ids of the buttons drawn inside [group], left to right.
List<String> _drawn(WidgetTester tester, Key group) {
  final List<(Offset, String)> found = [];
  for (final Element e
      in find
          .descendant(
            of: find.byKey(group),
            matching: find.byWidgetPredicate(
              (Widget w) =>
                  w.key is ValueKey<String> &&
                  (w.key! as ValueKey<String>).value.startsWith('tvHudAction:'),
            ),
          )
          .evaluate()) {
    final String id = (e.widget.key! as ValueKey<String>).value.substring(
      'tvHudAction:'.length,
    );
    found.add((tester.getRect(find.byKey(e.widget.key!)).topLeft, id));
  }
  // Reading order: by row, then left to right.
  found.sort(
    (a, b) => a.$1.dy != b.$1.dy
        ? a.$1.dy.compareTo(b.$1.dy)
        : a.$1.dx.compareTo(b.$1.dx),
  );
  return [for (final (_, String id) in found) id];
}

void _layoutTests() {
  test('saved lists: unknown, unpinnable and repeated ids are skipped, the '
      'top right keeps its first 17, and an empty list stays empty', () {
    // The 25 pinnable entries, in menu order, with noise mixed in.
    final List<String> all = [
      for (final TvHudActionId id in TvHudActionId.values)
        if (id.pinnable) id.name,
    ];
    expect(all, hasLength(25));
    final TvHudGroups groups = TvHudGroups.fromSaved(
      topRight: ['gone', 'editButtons', all[0], all[0], ...all.skip(1)],
      bottom: [all[0], all[17], 42, all[23]],
      showLabels: false,
      buttonsAboveBar: true,
    );
    // 3 rows of 6, less ⋮.
    expect(TvHudGroups.maxTopRight, 17);
    expect(groups.topRight.map((e) => e.name), all.take(17));
    // all[17] fell off the top right, so the bottom can have it; all[0] is
    // already pinned.
    expect(groups.bottom.map((e) => e.name), [all[17], all[23]]);
    expect(groups.showLabels, isFalse);
    expect(groups.buttonsAboveBar, isTrue);

    expect(TvHudGroups.fromSaved(), TvHudGroups.defaults);
    expect(TvHudGroups.defaults.buttonsAboveBar, isFalse);
    expect(
      TvHudGroups.fromSaved(buttonsAboveBar: 'yes').buttonsAboveBar,
      isFalse,
    );
    expect(
      TvHudGroups.fromSaved(topRight: const [], bottom: 'not a list'),
      TvHudGroups.defaults.copyWith(topRight: const []),
    );
    expect(TvHudGroups.defaults.topRight, [
      TvHudActionId.danmakuToggle,
      TvHudActionId.danmakuSettings,
      TvHudActionId.dmChart,
    ]);
    expect(TvHudGroups.defaults.bottom, [
      TvHudActionId.episodes,
      TvHudActionId.quality,
      TvHudActionId.subtitle,
      TvHudActionId.speed,
      TvHudActionId.videoFit,
    ]);
    expect(
      TvHudGroups.defaults.unpinned,
      isNot(contains(TvHudActionId.editButtons)),
    );
  });

  testWidgets('the HUD draws both groups from the saved lists and skips '
      'unknown ids; the top right is rows of 6, aligned right, with ⋮ last '
      'in the first row', (tester) async {
    unawaited(
      GStorage.setting.putAll(<String, Object>{
        TvHudGroups.topRightKey: [
          'speed',
          'noSuchButton',
          'videoFit',
          'danmakuToggle',
          'playOrder',
          'danmakuSettings',
          'like',
          'coin',
          'favorite',
        ],
        TvHudGroups.bottomKey: ['quality', 'removedLongAgo', 'watchLater'],
      }),
    );
    final _ActionScene scene = _ActionScene();
    await scene.pump(tester);
    await _press(tester, dpadUp);

    expect(_drawn(tester, TvPlayerHud.topRightGroupKey), [
      'speed',
      'videoFit',
      'danmakuToggle',
      'playOrder',
      'danmakuSettings',
      'like',
      'coin',
      'favorite',
    ]);
    expect(_drawn(tester, TvPlayerHud.bottomGroupKey), [
      'quality',
      'watchLater',
    ]);
    Rect rect(Key key) => tester.getRect(find.byKey(key));
    Rect button(String id) => rect(TvHudAction.keyOf(id));
    // First row: five buttons, then ⋮; the second row holds the rest.
    final Rect menu = rect(TvPlayerHud.menuButtonKey);
    for (final String id in [
      'speed',
      'videoFit',
      'danmakuToggle',
      'playOrder',
      'danmakuSettings',
    ]) {
      expect(button(id).center.dy, moreOrLessEquals(menu.center.dy));
      expect(button(id).right, lessThan(menu.left));
    }
    expect(button('like').top, greaterThan(menu.bottom));
    expect(button('favorite').center.dy, button('like').center.dy);
    // Aligned right: both rows end at the same edge.
    expect(button('favorite').right, moreOrLessEquals(menu.right));
    // Icon-only.
    expect(
      find.descendant(
        of: find.byKey(TvPlayerHud.topRightGroupKey),
        matching: find.byType(Text),
      ),
      findsNothing,
    );
    // The bottom row shows its labels by default, under the time bar.
    expect(
      find.descendant(
        of: find.byKey(TvPlayerHud.bottomGroupKey),
        matching: find.text('画质: 1080P'),
      ),
      findsOneWidget,
    );
    expect(
      rect(TvPlayerHud.bottomGroupKey).top,
      greaterThan(rect(TvPlayerHud.timeBarKey).bottom),
    );
  });

  testWidgets('按钮在时间条上方: the bottom row moves above the time bar, '
      'and the D-pad follows', (tester) async {
    _saveGroups(TvHudGroups.defaults.copyWith(buttonsAboveBar: true));
    final _ActionScene scene = _ActionScene();
    await scene.pump(tester);
    await _press(tester, dpadUp);
    Rect rect(Key key) => tester.getRect(find.byKey(key));
    expect(
      rect(TvPlayerHud.bottomGroupKey).bottom,
      lessThan(rect(TvPlayerHud.timeBarKey).top),
    );
    // Still the first focus, with the buttons above it.
    expect(_focusOn(TvPlayerHud.timeBarKey), isTrue);
    await _press(tester, dpadUp);
    expect(_focusOn(TvHudAction.keyOf('episodes.prev')), isTrue);
    await _press(tester, dpadDown);
    expect(_focusOn(TvPlayerHud.timeBarKey), isTrue);
  });

  testWidgets('按钮在时间条上方 with 显示按钮文字 off: the focus label is '
      'drawn above the button, clear of the time bar', (tester) async {
    _saveGroups(
      TvHudGroups.defaults.copyWith(buttonsAboveBar: true, showLabels: false),
    );
    final _ActionScene scene = _ActionScene();
    await scene.pump(tester);
    await _press(tester, dpadUp);
    await _press(tester, dpadUp);
    final Key prev = TvHudAction.keyOf('episodes.prev');
    expect(_focusOn(prev), isTrue);
    final Rect label = tester.getRect(find.byKey(TvPlayerHud.focusLabelKey));
    expect(
      label.bottom,
      lessThanOrEqualTo(tester.getRect(find.byKey(prev)).top),
    );
    expect(
      label.overlaps(tester.getRect(find.byKey(TvPlayerHud.timeBarKey))),
      isFalse,
    );
  });

  testWidgets('a long title wraps to three lines and ends in … only past '
      'them', (tester) async {
    final _ActionScene scene = _ActionScene();
    scene.intro.videoDetail.value = VideoDetailData(
      title: List<String>.filled(40, '很长的视频标题').join(),
    );
    await scene.pump(tester);
    await _press(tester, dpadUp);
    final Text title = tester.widget<Text>(find.byKey(TvPlayerHud.titleKey));
    expect((title.maxLines, title.overflow), (3, TextOverflow.ellipsis));
    final RenderParagraph paragraph = tester.renderObject<RenderParagraph>(
      find.descendant(
        of: find.byKey(TvPlayerHud.titleKey),
        matching: find.byType(RichText),
      ),
    );
    expect(paragraph.didExceedMaxLines, isTrue);
    final double line = paragraph.getFullHeightForCaret(
      const TextPosition(offset: 0),
    );
    expect(paragraph.size.height, moreOrLessEquals(3 * line, epsilon: 2));

    // A short one stays on one line.
    await tester.pumpWidget(const SizedBox.shrink());
    final _ActionScene other = _ActionScene();
    other.intro.videoDetail.value = VideoDetailData(title: '短标题');
    await other.pump(tester);
    await _press(tester, dpadUp);
    expect(tester.widget<Text>(find.byKey(TvPlayerHud.titleKey)).data, '短标题');
    final RenderParagraph short = tester.renderObject<RenderParagraph>(
      find.descendant(
        of: find.byKey(TvPlayerHud.titleKey),
        matching: find.byType(RichText),
      ),
    );
    expect(short.didExceedMaxLines, isFalse);
    expect(short.size.height, moreOrLessEquals(line, epsilon: 2));
  });

  testWidgets('显示按钮文字 off: the bottom row is icon-only, and the focused '
      'button\'s name is drawn under it without moving the row', (
    tester,
  ) async {
    _saveGroups(TvHudGroups.defaults.copyWith(showLabels: false));
    final _ActionScene scene = _ActionScene();
    await scene.pump(tester);
    await _press(tester, dpadUp);

    expect(
      find.descendant(
        of: find.byKey(TvPlayerHud.bottomGroupKey),
        matching: find.text('画质: 1080P'),
      ),
      findsNothing,
    );
    expect(find.byKey(TvPlayerHud.focusLabelKey), findsNothing);

    final Key next = TvHudAction.keyOf('episodes.next');
    final Rect row = tester.getRect(find.byKey(TvPlayerHud.bottomGroupKey));
    final Rect nextBefore = tester.getRect(find.byKey(next));

    await _press(tester, dpadDown);
    expect(_focusOn(TvHudAction.keyOf('episodes.prev')), isTrue);
    expect(find.byKey(TvPlayerHud.focusLabelKey), findsOneWidget);
    expect(
      find.descendant(
        of: find.byKey(TvPlayerHud.focusLabelKey),
        matching: find.text('上集'),
      ),
      findsOneWidget,
    );

    await _press(tester, dpadRight);
    expect(_focusOn(next), isTrue);
    final Rect label = tester.getRect(find.byKey(TvPlayerHud.focusLabelKey));
    expect(_textIn(TvPlayerHud.focusLabelKey, '下集'), findsOneWidget);
    expect(
      label.top,
      greaterThanOrEqualTo(tester.getRect(find.byKey(next)).bottom),
    );
    expect(label.center.dx, moreOrLessEquals(nextBefore.center.dx, epsilon: 1));
    // Neither the label nor the focused border moves anything.
    expect(tester.getRect(find.byKey(next)), nextBefore);
    expect(tester.getRect(find.byKey(TvPlayerHud.bottomGroupKey)), row);
  });

  testWidgets('the time bar with the HUD open: Left / Right seek, Select '
      'plays and pauses; the 高能进度条 chart is drawn over the bar', (
    tester,
  ) async {
    final _ActionScene scene = _ActionScene();
    scene.vdc.dmTrend.value = const Success<List<double>>([0.1, 0.8, 0.3]);
    await scene.pump(tester);
    await _press(tester, dpadUp);
    expect(_focusOn(TvPlayerHud.timeBarKey), isTrue);

    await tester.sendKeyEvent(dpadRight);
    await tester.pump();
    expect(scene.pl.seekTargets.last, const Duration(seconds: 40));
    expect(_focusOn(TvPlayerHud.timeBarKey), isTrue);
    await tester.pump(const Duration(seconds: 2));
    await tester.sendKeyEvent(dpadLeft);
    await tester.pump();
    expect(scene.pl.seekTargets.last, const Duration(seconds: 20));
    await tester.sendKeyEvent(dpadSelect);
    await tester.pump();
    expect(scene.pl.doubleTapCenterCount, 1);
    expect(_timeBar, findsOneWidget);

    final Finder chart = find.descendant(
      of: find.byKey(TvPlayerHud.dmChartKey),
      matching: find.byType(LineChart),
    );
    expect(chart, findsOneWidget);
    final Rect bar = tester.getRect(_timeBar);
    final Rect chartRect = tester.getRect(chart);
    expect(chartRect.bottom, lessThanOrEqualTo(bar.bottom));
    expect(chartRect.top, greaterThanOrEqualTo(bar.top - 4));
    expect(
      find.ancestor(of: chart, matching: find.byType(RepaintBoundary)),
      findsWidgets,
    );

    scene.vdc.showDmTrendChart.value = false;
    await tester.pumpAndSettle();
    expect(chart, findsNothing);
  });

  testWidgets('the ⋮ menu lists every available entry by group, with 翻译 and '
      '分段信息 in 播放; the HUD waits while it is open; a choice runs and '
      'focus returns to ⋮', (tester) async {
    final _ActionScene scene = _ActionScene();
    scene.vdc
      ..languages.value = [play_url.LanguageItem(lang: 'en', title: '英语')]
      ..viewPointList.addAll(const [
        ViewPointSegment(end: 0.4, title: '开场', from: 0, to: 120),
        ViewPointSegment(end: 1.0, title: '正片', from: 120, to: 300),
      ]);
    await scene.pump(tester);
    await _press(tester, dpadUp);
    await _focusKey(tester, TvPlayerHud.menuButtonKey);
    await _press(tester, dpadSelect);

    expect(find.byKey(TvPlayerHud.menuPanelKey), findsOneWidget);
    double top(String text) => tester
        .getRect(
          find.descendant(
            of: find.byKey(TvPlayerHud.menuPanelKey),
            matching: find.text(text),
          ),
        )
        .top;
    final List<double> headers = [
      for (final TvHudMenuGroup g in TvHudMenuGroup.values) top(g.label),
    ];
    expect(headers, orderedEquals([...headers]..sort()));
    double entry(String buttonId) =>
        tester.getRect(find.byKey(TvPlayerHud.menuEntryKey(buttonId))).top;
    expect(entry('aiTranslate'), greaterThan(top('播放')));
    expect(entry('viewPoints'), lessThan(top('弹幕')));
    expect(entry('coin'), greaterThan(top('互动')));
    expect(entry('editButtons'), greaterThan(top('其他')));
    // Focus starts on the first entry.
    expect(_focusOn(TvPlayerHud.menuEntryKey('quality')), isTrue);

    // The HUD stays while the menu is open.
    await tester.pump(const Duration(seconds: 6));
    expect(_timeBar, findsOneWidget);

    await _focusKey(tester, TvPlayerHud.menuEntryKey('danmakuToggle'));
    await _press(tester, dpadSelect);
    expect(find.byKey(TvPlayerHud.menuPanelKey), findsNothing);
    expect(scene.pl.enableShowDanmakuAdaptive.value, isFalse);
    expect(_timeBar, findsOneWidget);
    expect(_focusOn(TvPlayerHud.menuButtonKey), isTrue);

    // Auto-hide runs again once the menu is closed.
    await tester.pump(const Duration(seconds: 6));
    expect(_timeBar, findsNothing);
  });

  testWidgets('editor: Select picks a button up, Left / Right reorder, Up / '
      'Down move between the rows, Back puts it down, and the result '
      'survives a restart', (tester) async {
    final _ActionScene scene = _ActionScene();
    scene.vdc.dmTrend.value = const Success<List<double>>([0.1, 0.8, 0.3]);
    final TvHudActionSource source = await scene.pump(tester);
    await _press(tester, dpadUp);
    _one(source, TvHudActionId.editButtons).onPressed();
    await tester.pumpAndSettle();
    expect(find.byKey(TvPlayerHud.editorKey), findsOneWidget);
    // The first pinned button has focus.
    expect(
      _focusOn(TvPlayerHud.editorItemKey(TvHudActionId.danmakuToggle)),
      isTrue,
    );

    // Auto-hide is paused while the editor is open.
    await tester.pump(const Duration(seconds: 6));
    expect(_timeBar, findsOneWidget);

    String hint() =>
        tester.widget<Text>(find.byKey(TvPlayerHud.editorHintKey)).data!;

    await _press(tester, dpadSelect);
    expect(hint(), contains('正在移动「弹幕开关」'));
    await _press(tester, dpadRight);
    expect(_savedIds(TvHudGroups.topRightKey), [
      'danmakuSettings',
      'danmakuToggle',
      'dmChart',
    ]);
    expect(
      _focusOn(TvPlayerHud.editorItemKey(TvHudActionId.danmakuToggle)),
      isTrue,
    );
    await _press(tester, dpadDown);
    expect(_savedIds(TvHudGroups.topRightKey), ['danmakuSettings', 'dmChart']);
    expect(_savedIds(TvHudGroups.bottomKey), [
      'episodes',
      'quality',
      'subtitle',
      'speed',
      'videoFit',
      'danmakuToggle',
    ]);
    await _press(tester, dpadLeft);
    expect(_savedIds(TvHudGroups.bottomKey).last, 'videoFit');
    // Down from the bottom row unpins it.
    await _press(tester, dpadDown);
    expect(_savedIds(TvHudGroups.bottomKey), isNot(contains('danmakuToggle')));
    expect(
      _focusOn(TvPlayerHud.editorItemKey(TvHudActionId.danmakuToggle)),
      isTrue,
    );

    // Back puts it down; the editor stays.
    await _press(tester, dpadBack);
    expect(find.byKey(TvPlayerHud.editorKey), findsOneWidget);
    expect(hint(), isNot(contains('正在移动')));
    // Now Left / Right move focus, not the button.
    await _press(tester, dpadRight);
    expect(
      _focusOn(TvPlayerHud.editorItemKey(TvHudActionId.danmakuToggle)),
      isFalse,
    );

    // Pin 弹幕列表 and 点赞 top right.
    for (final TvHudActionId id in [
      TvHudActionId.danmakuPool,
      TvHudActionId.like,
    ]) {
      await _focusKey(tester, TvPlayerHud.editorItemKey(id));
      await _press(tester, dpadSelect);
      await _press(tester, dpadUp);
      await _press(tester, dpadUp);
      await _press(tester, dpadSelect);
    }
    expect(_savedIds(TvHudGroups.topRightKey), [
      'danmakuSettings',
      'dmChart',
      'danmakuPool',
      'like',
    ]);

    // Back closes the editor; the HUD redraws its groups and focus returns
    // to ⋮.
    await _press(tester, dpadBack);
    expect(find.byKey(TvPlayerHud.editorKey), findsNothing);
    expect(_timeBar, findsOneWidget);
    expect(_focusOn(TvPlayerHud.menuButtonKey), isTrue);
    expect(_drawn(tester, TvPlayerHud.topRightGroupKey), [
      'danmakuSettings',
      'dmChart',
      'like',
    ]);
    expect(
      find.byKey(TvHudAction.keyOf('danmakuToggle')),
      findsNothing,
    );

    // A restart reads the same lists.
    await tester.pumpWidget(const SizedBox.shrink());
    final _ActionScene again = _ActionScene();
    again.vdc.dmTrend.value = const Success<List<double>>([0.1, 0.8, 0.3]);
    await again.pump(tester);
    await _press(tester, dpadUp);
    expect(_drawn(tester, TvPlayerHud.topRightGroupKey), [
      'danmakuSettings',
      'dmChart',
      'like',
    ]);
    expect(_drawn(tester, TvPlayerHud.bottomGroupKey), [
      'episodes.prev',
      'episodes.next',
      'episodes.list',
      'quality',
      'speed',
      'videoFit',
    ]);
    await tester.pump(const Duration(seconds: 6));
  });

  testWidgets('editor: 显示按钮文字 saves at once and survives a restart; '
      '恢复默认 asks first, and 取消 changes nothing', (tester) async {
    _saveGroups(
      const TvHudGroups(
        topRight: [TvHudActionId.coin],
        bottom: [TvHudActionId.speed],
        showLabels: true,
      ),
    );
    final _ActionScene scene = _ActionScene();
    final TvHudActionSource source = await scene.pump(tester);
    await _press(tester, dpadUp);
    _one(source, TvHudActionId.editButtons).onPressed();
    await tester.pumpAndSettle();

    await _focusKey(tester, TvPlayerHud.editorShowLabelsKey);
    await _press(tester, dpadSelect);
    expect(GStorage.setting.get(TvHudGroups.showLabelsKey), isFalse);
    expect(
      _textIn(TvPlayerHud.editorShowLabelsKey, '显示按钮文字: 关'),
      findsOneWidget,
    );

    await _focusKey(tester, TvPlayerHud.editorResetKey);
    await _press(tester, dpadSelect);
    expect(find.byKey(TvPlayerHud.editorResetConfirmKey), findsOneWidget);
    // Focus starts on 取消.
    expect(focusedLabel(), '取消');
    await _press(tester, dpadSelect);
    expect(find.byKey(TvPlayerHud.editorResetConfirmKey), findsNothing);
    expect(_savedIds(TvHudGroups.topRightKey), ['coin']);
    expect(GStorage.setting.get(TvHudGroups.showLabelsKey), isFalse);

    // Back closes the editor; the bottom row is icon-only now.
    await _press(tester, dpadBack);
    expect(
      find.descendant(
        of: find.byKey(TvPlayerHud.bottomGroupKey),
        matching: find.text('倍速: 1.0x'),
      ),
      findsNothing,
    );

    // After a restart, the option still holds; 恢复默认 then resets it all.
    await tester.pumpWidget(const SizedBox.shrink());
    final _ActionScene again = _ActionScene();
    final TvHudActionSource source2 = await again.pump(tester);
    await _press(tester, dpadUp);
    expect(find.byKey(TvHudAction.keyOf('speed')), findsOneWidget);
    expect(_textIn(TvHudAction.keyOf('speed'), '倍速: 1.0x'), findsNothing);
    _one(source2, TvHudActionId.editButtons).onPressed();
    await tester.pumpAndSettle();
    expect(
      _textIn(TvPlayerHud.editorShowLabelsKey, '显示按钮文字: 关'),
      findsOneWidget,
    );
    await _focusKey(tester, TvPlayerHud.editorResetKey);
    await _press(tester, dpadSelect);
    await _focusKey(tester, TvPlayerHud.editorResetConfirmKey);
    await _press(tester, dpadSelect);
    expect(find.byKey(TvPlayerHud.editorResetConfirmKey), findsNothing);
    expect(TvHudGroups.read(GStorage.setting), TvHudGroups.defaults);
    expect(
      _textIn(TvPlayerHud.editorShowLabelsKey, '显示按钮文字: 开'),
      findsOneWidget,
    );
    await _focusKey(tester, TvPlayerHud.editorDoneKey);
    await _press(tester, dpadSelect);
    expect(find.byKey(TvPlayerHud.editorKey), findsNothing);
    expect(_textIn(TvHudAction.keyOf('speed'), '倍速: 1.0x'), findsOneWidget);
    await tester.pump(const Duration(seconds: 6));
  });

  testWidgets('editor: a top right of 17 refuses an 18th; 按钮在时间条上方 '
      'saves at once and flips the HUD when the editor closes', (
    tester,
  ) async {
    const List<TvHudActionId> bottom = [
      TvHudActionId.quality,
      TvHudActionId.speed,
      TvHudActionId.videoFit,
      TvHudActionId.subtitle,
      TvHudActionId.episodes,
      TvHudActionId.playOrder,
      TvHudActionId.fullSettings,
    ];
    // A full top right: the first 17 pinnable entries not in the bottom row.
    final List<TvHudActionId> top = [
      for (final TvHudActionId id in TvHudActionId.values)
        if (id.pinnable && !bottom.contains(id)) id,
    ].take(TvHudGroups.maxTopRight).toList();
    expect(top, hasLength(TvHudGroups.maxTopRight));
    _saveGroups(TvHudGroups(topRight: top, bottom: bottom, showLabels: true));
    final _ActionScene scene = _ActionScene();
    final TvHudActionSource source = await scene.pump(tester);
    await _press(tester, dpadUp);
    _one(source, TvHudActionId.editButtons).onPressed();
    await tester.pumpAndSettle();
    expect(_textIn(TvPlayerHud.editorKey, '右上角 17/17'), findsOneWidget);

    await _focusKey(tester, TvPlayerHud.editorItemKey(TvHudActionId.speed));
    await _press(tester, dpadSelect);
    await _press(tester, dpadUp);
    expect(_savedIds(TvHudGroups.topRightKey), hasLength(17));
    expect(_savedIds(TvHudGroups.bottomKey), contains('speed'));
    expect(find.textContaining('右上角最多 17 个'), findsOneWidget);
    await _press(tester, dpadSelect);

    await _focusKey(tester, TvPlayerHud.editorButtonsAboveBarKey);
    await _press(tester, dpadSelect);
    expect(GStorage.setting.get(TvHudGroups.buttonsAboveBarKey), isTrue);
    expect(
      _textIn(TvPlayerHud.editorButtonsAboveBarKey, '按钮在时间条上方: 开'),
      findsOneWidget,
    );

    await _press(tester, dpadBack);
    expect(find.byKey(TvPlayerHud.editorKey), findsNothing);
    expect(
      tester.getRect(find.byKey(TvPlayerHud.bottomGroupKey)).bottom,
      lessThan(tester.getRect(_timeBar).top),
    );
    await tester.pump(const Duration(seconds: 6));
  });
}
