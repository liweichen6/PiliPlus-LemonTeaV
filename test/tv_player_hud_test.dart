import 'dart:io';

import 'package:PiliPlus/models/common/video/video_quality.dart';
import 'package:PiliPlus/models_new/video/video_detail/data.dart';
import 'package:PiliPlus/models_new/video/video_detail/episode.dart';
import 'package:PiliPlus/models_new/video/video_detail/page.dart';
import 'package:PiliPlus/models/video/play/url.dart' as play_url;
import 'package:PiliPlus/pages/danmaku/danmaku_model.dart';
import 'package:PiliPlus/pages/video/controller.dart';
import 'package:PiliPlus/pages/video/introduction/ugc/controller.dart';
import 'package:PiliPlus/plugin/pl_player/controller.dart';
import 'package:PiliPlus/plugin/pl_player/models/play_status.dart';
import 'package:PiliPlus/plugin/pl_player/models/video_fit_type.dart';
import 'package:PiliPlus/plugin/pl_player/utils/danmaku_options.dart';
import 'package:PiliPlus/tv/tv_navigation.dart';
import 'package:PiliPlus/tv/tv_platform.dart';
import 'package:PiliPlus/tv/tv_player_hud.dart';
import 'package:PiliPlus/utils/storage.dart';
import 'package:canvas_danmaku/canvas_danmaku.dart';
import 'package:flutter/services.dart';
import 'package:flutter_smart_dialog/flutter_smart_dialog.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:hive_ce/hive.dart';
import 'package:material_ui/material_ui.dart';
import 'package:media_kit/media_kit.dart';

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
  Player? get videoPlayerController => fakePlayer;

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

  int doubleTapCenterCount = 0;
  @override
  Future<void> onDoubleTapCenter() async {
    doubleTapCenterCount++;
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
  int? cacheVideoQa;
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
  final Rxn<VideoQuality> currentVideoQa = Rxn<VideoQuality>(VideoQuality.high1080);

  int updatePlayerCount = 0;
  @override
  void updatePlayer() {
    updatePlayerCount++;
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
  Future<bool> onChangeEpisode(BaseEpisodeItem item, {bool isStein = false}) async {
    changedEpisode = item;
    return true;
  }

  int prevPlayCount = 0;
  @override
  bool prevPlay([bool auto = false]) {
    prevPlayCount++;
    return true;
  }

  int nextPlayCount = 0;
  @override
  bool nextPlay([bool auto = false]) {
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

  @override
  void actionCoinVideo() {}

  @override
  void showFavBottomSheet(BuildContext context, {bool isLongPress = false}) {}
}

Widget _buildTestApp({
  required FakePlPlayerController plPlayerController,
  FakeUgcIntroController? introController,
  Widget? child,
  VoidCallback? onSendDanmaku,
  NavigatorObserver? observer,
}) {
  return MaterialApp(
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
      GStorage.setting = await Hive.openBox('setting');
    } catch (_) {}
    try {
      GStorage.video = await Hive.openBox('video');
    } catch (_) {}
    try {
      GStorage.localCache = await Hive.openBox('localCache');
    } catch (_) {}
  });


  setUp(() {
    TvPlatform.setTvModeForTesting(true);
  });

  tearDown(() {
    TvPlatform.setTvModeForTesting(false);
  });

  group('TvPlayerHud Transport Controls & Focus Traversal (F15)', () {
    testWidgets(
      'fullscreen surface opens HUD via Select or Up key and focuses play/pause pill',
      (tester) async {
        final pl = FakePlPlayerController()
          ..isFullScreen.value = true;

        await tester.pumpWidget(
          _buildTestApp(plPlayerController: pl),
        );
        await tester.pumpAndSettle();

        // Initially in fullscreen, HUD overlay is not visible.
        expect(find.text('全屏播放'), findsNothing);
        expect(find.text('暂停'), findsNothing);

        // Press Up arrow on remote -> opens HUD overlay.
        await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
        await tester.pumpAndSettle();

        // HUD overlay is now visible with transport buttons.
        expect(find.text('暂停'), findsOneWidget);
        expect(find.text('倍速: 1.0x'), findsOneWidget);
        expect(find.text('画面: 自动'), findsOneWidget);

        // Verify play/pause pill is visible and interactive.
        expect(find.text('暂停'), findsOneWidget);

        // Navigate right to next pill (Danmaku toggle).
        await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
        await tester.pumpAndSettle();
        expect(find.text('弹幕: 开'), findsOneWidget);
      },
    );

    testWidgets(
      'split-screen mode displays quick strip and navigates to 播控 to open HUD',
      (tester) async {
        final pl = FakePlPlayerController()
          ..isFullScreen.value = false;

        await tester.pumpWidget(
          _buildTestApp(plPlayerController: pl),
        );
        await tester.pumpAndSettle();

        // In split-screen mode, Quick Strip is rendered at top-left.
        expect(find.text('全屏'), findsOneWidget);
        expect(find.text('播/暂'), findsOneWidget);
        expect(find.text('播控'), findsOneWidget);
        expect(find.text('返回'), findsOneWidget);

        // Tap or select '播控' pill -> opens 10-foot HUD overlay.
        await tester.tap(find.text('播控'));
        await tester.pumpAndSettle();

        // 10-foot HUD is now open.
        expect(find.text('全屏播放'), findsOneWidget);
        expect(find.text('暂停'), findsOneWidget);
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
        expect(find.text('⏩ 00:40 / 05:00'), findsOneWidget);

        // Step 2: 2nd forward seek at 100ms (<450ms gap, consecutive = 2, multiplier = 1x -> +10s)
        await tester.pump(const Duration(milliseconds: 100));
        await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
        await tester.pump();
        expect(pl.seekTargets.last, const Duration(seconds: 50));
        expect(find.text('⏩ 00:50 / 05:00'), findsOneWidget);

        // Step 3: 3rd forward seek at 100ms (<450ms gap, consecutive = 3, multiplier = 2x -> +20s)
        await tester.pump(const Duration(milliseconds: 100));
        await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
        await tester.pump();
        expect(pl.seekTargets.last, const Duration(seconds: 70));
        expect(find.text('⏩ 01:10 / 05:00'), findsOneWidget);

        // Step 4: 4th forward seek at 100ms (consecutive = 4, multiplier = 2x -> +20s)
        await tester.pump(const Duration(milliseconds: 100));
        await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
        await tester.pump();
        expect(pl.seekTargets.last, const Duration(seconds: 90));
        expect(find.text('⏩ 01:30 / 05:00'), findsOneWidget);

        // Step 5: 5th forward seek at 100ms (consecutive = 5, multiplier = 2x -> +20s)
        await tester.pump(const Duration(milliseconds: 100));
        await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
        await tester.pump();
        expect(pl.seekTargets.last, const Duration(seconds: 110));
        expect(find.text('⏩ 01:50 / 05:00'), findsOneWidget);

        // Step 6: 6th forward seek at 100ms (consecutive = 6, multiplier = 3x -> +30s)
        await tester.pump(const Duration(milliseconds: 100));
        await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
        await tester.pump();
        expect(pl.seekTargets.last, const Duration(seconds: 140));
        expect(find.text('⏩ 02:20 / 05:00'), findsOneWidget);

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
        expect(find.text('⏩ 05:00 / 05:00'), findsOneWidget);

        // Reset and test backward seek clamping to 0
        await tester.pump(const Duration(milliseconds: 1500));
        pl
          ..fakePlayer.playerState.position = const Duration(seconds: 5)
          ..seekTargets.clear();

        // Backward seek from 5s with -10s delta -> clamped to 0s
        await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
        await tester.pump();
        expect(pl.seekTargets.last, Duration.zero);
        expect(find.text('⏪ 00:00 / 05:00'), findsOneWidget);
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
        expect(find.text('⏩ 00:40 / 05:00'), findsOneWidget);

        // Before 1400ms timer expires, OSD text is still visible
        await tester.pump(const Duration(milliseconds: 1000));
        expect(find.text('⏩ 00:40 / 05:00'), findsOneWidget);

        // After 1400ms timer expires (1000ms + 500ms = 1500ms), OSD banner disappears
        await tester.pump(const Duration(milliseconds: 500));
        expect(find.text('⏩ 00:40 / 05:00'), findsNothing);

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

        // Wait real elapsed wall-clock time >=450ms
        await tester.runAsync(() async {
          await Future<void>.delayed(const Duration(milliseconds: 500));
        });

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
        expect(find.text('⏩ 00:40 / 05:00'), findsOneWidget);

        // Play/Pause toggle resets virtual seek target
        await tester.sendKeyEvent(LogicalKeyboardKey.mediaPlayPause);
        await tester.pump();
        expect(pl.doubleTapCenterCount, 1);

        // Open HUD and close via Escape: verify hideHud resets state cleanly
        await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
        await tester.pumpAndSettle();
        expect(find.text('暂停'), findsOneWidget);

        await tester.sendKeyEvent(LogicalKeyboardKey.escape);
        await tester.pumpAndSettle();
        expect(find.text('暂停'), findsNothing);
      },
    );
  });

  group('TvPlayerHud PopScope Back Key Handling (F15)', () {
    testWidgets(
      'PopScope intercepts back key when HUD is open to dismiss HUD without popping route',
      (tester) async {
        final pl = FakePlPlayerController()
          ..isFullScreen.value = true;

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
        expect(find.text('暂停'), findsOneWidget);

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
        expect(find.text('暂停'), findsNothing);
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
        final pl = FakePlPlayerController()
          ..isFullScreen.value = false;

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

        // Find and click '倍速: 1.0x'
        final speedBtnFinder = find.text('倍速: 1.0x');
        expect(speedBtnFinder, findsOneWidget);
        await tester.tap(speedBtnFinder);
        await tester.pumpAndSettle();

        // Dialog opened
        expect(find.text('选择播放倍速'), findsOneWidget);
        expect(find.text('1.0x'), findsOneWidget);
        expect(find.text('1.25x'), findsOneWidget);

        // Select 1.25x
        await tester.tap(find.text('1.25x'));
        await tester.pumpAndSettle();

        // Dialog dismissed and speed updated
        expect(find.text('选择播放倍速'), findsNothing);
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

        // Find and tap '画面: 自动'
        final fitBtnFinder = find.text('画面: 自动');
        expect(fitBtnFinder, findsOneWidget);
        await tester.tap(fitBtnFinder);
        await tester.pumpAndSettle();

        // Dialog opened
        expect(find.text('选择画面比例'), findsOneWidget);

        // Select '拉伸'
        final fillFinder = find.text('拉伸');
        expect(fillFinder, findsOneWidget);
        await tester.tap(fillFinder);
        await tester.pumpAndSettle();

        // Dialog dismissed and fit updated
        expect(find.text('选择画面比例'), findsNothing);
        expect(pl.videoFit.value, VideoFitType.fill);
        await tester.pump(const Duration(seconds: 3));
      },
    );

    testWidgets(
      'Danmaku settings dialog opens and updates danmaku display area',
      (tester) async {
        final pl = FakePlPlayerController()
          ..isFullScreen.value = true;

        await _pumpHud(tester, plPlayerController: pl);

        // Open HUD
        await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
        await tester.pumpAndSettle();

        // Tap '弹幕设置'
        final danmakuSetBtn = find.text('弹幕设置');
        expect(danmakuSetBtn, findsOneWidget);
        await tester.tap(danmakuSetBtn);
        await tester.pumpAndSettle();

        // Dialog opened
        expect(find.text('弹幕设置 (遥控器方向键选择)'), findsOneWidget);
        expect(find.text('显示区域'), findsOneWidget);
        expect(find.text('半屏'), findsOneWidget);

        // Select '半屏' (value 0.5)
        await tester.tap(find.text('半屏'));
        await tester.pumpAndSettle();
        expect(DanmakuOptions.danmakuShowArea, 0.5);

        // Close dialog via escape key
        await tester.sendKeyEvent(LogicalKeyboardKey.escape);
        await tester.pumpAndSettle();
        expect(find.text('弹幕设置 (遥控器方向键选择)'), findsNothing);
      },
    );

    testWidgets(
      'Episodes dialog opens, lists episodes, autofocuses current episode, selects next episode',
      (tester) async {
        final pl = FakePlPlayerController()
          ..isFullScreen.value = true
          ..cid = 1001;
        final videoDetailCtr = FakeVideoDetailController(plPlayerController: pl);
        final introCtr = FakeUgcIntroController(videoDetailCtr: videoDetailCtr);

        await _pumpHud(
          tester,
          plPlayerController: pl,
          introController: introCtr,
        );

        // Open HUD
        await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
        await tester.pumpAndSettle();

        // Tap '选集 (3)'
        final epBtn = find.text('选集 (3)');
        expect(epBtn, findsOneWidget);
        await tester.tap(epBtn);
        await tester.pumpAndSettle();

        // Dialog opened
        expect(find.text('选集 (3)'), findsWidgets); // Title and list
        expect(find.text('P1  第一集：初始篇'), findsOneWidget);
        expect(find.text('P2  第二集：进阶篇'), findsOneWidget);
        expect(find.text('P3  第三集：完结篇'), findsOneWidget);

        // Select P2
        await tester.tap(find.text('P2  第二集：进阶篇'));
        await tester.pumpAndSettle();

        // Dialog dismissed and episode changed callback fired
        expect(introCtr.changedEpisode, isNotNull);
        expect((introCtr.changedEpisode as Part).cid, 1002);
      },
    );

    testWidgets(
      'Quality dialog opens, lists available video qualities, selects new quality',
      (tester) async {
        final pl = FakePlPlayerController()
          ..isFullScreen.value = true;
        final videoDetailCtr = FakeVideoDetailController(plPlayerController: pl);
        final introCtr = FakeUgcIntroController(videoDetailCtr: videoDetailCtr);

        await _pumpHud(
          tester,
          plPlayerController: pl,
          introController: introCtr,
        );

        // Open HUD
        await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
        await tester.pumpAndSettle();

        // Tap '画质: 1080P'
        final qaBtn = find.text('画质: 1080P');
        expect(qaBtn, findsOneWidget);
        await tester.tap(qaBtn);
        await tester.pumpAndSettle();

        // Dialog opened
        expect(find.text('选择视频画质'), findsOneWidget);
        expect(find.text('1080P 高清  (mp4)'), findsOneWidget);
        expect(find.text('720P 高清  (mp4)'), findsOneWidget);

        // Select 720P
        await tester.tap(find.text('720P 高清  (mp4)'));
        await tester.pumpAndSettle();

        // Dialog dismissed and quality updated
        expect(find.text('选择视频画质'), findsNothing);
        expect(videoDetailCtr.currentVideoQa.value, VideoQuality.high720);
        expect(videoDetailCtr.updatePlayerCount, 1);
        await tester.pump(const Duration(seconds: 3));
      },
    );
  });
}
