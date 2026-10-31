import 'dart:io';

import 'package:PiliPlus/plugin/pl_player/models/video_fit_type.dart';
import 'package:PiliPlus/tv/tv_platform.dart';
import 'package:PiliPlus/tv/tv_video_plane.dart';
import 'package:PiliPlus/utils/storage.dart';
import 'package:PiliPlus/utils/storage_key.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive.dart';

/// mpv's options as the plane leaves them. `calls` keeps the order, because
/// the order is part of the contract (`wid` before `vo`).
class FakeMpv implements TvPlaneMpv {
  FakeMpv({this.ignoreSets = const {}, this.throwOn});

  /// Names whose set is silently lost, like a failed `setOption`.
  final Set<String> ignoreSets;
  final String? throwOn;

  final List<String> calls = <String>[];
  final Map<String, String> values = <String, String>{
    'vo': 'null',
    'wid': '0',
    'path': 'video.mp4',
  };
  int stopCount = 0;

  void _set(String name, String value) {
    if (name == throwOn) throw StateError('mpv refused $name');
    calls.add('$name=$value');
    if (!ignoreSets.contains(name)) values[name] = value;
  }

  @override
  void setOption(String name, String value) => _set(name, value);

  @override
  void setProperty(String name, String value) => _set(name, value);

  @override
  String getProperty(String name) => values[name] ?? '';

  @override
  Future<void> stop() async => stopCount += 1;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;
  late Box<dynamic> box;
  late List<String> toasts;
  late int failCount;
  late ValueNotifier<Rect?> videoRect;

  setUpAll(() async {
    tempDir = await Directory.systemTemp.createTemp('tv_plane_test_');
    Hive.init(tempDir.path);
    box = GStorage.setting = await Hive.openBox<dynamic>('setting');
  });

  tearDownAll(() async {
    await Hive.close();
    await tempDir.delete(recursive: true);
  });

  setUp(() async {
    await box.clear();
    TvPlatform.setTvModeForTesting(true);
    toasts = <String>[];
    failCount = 0;
    videoRect = ValueNotifier<Rect?>(null);
    TvVideoPlane.showToast = toasts.add;
  });

  tearDown(() {
    TvPlatform.setTvModeForTesting(false);
  });

  // Hive's real I/O never finishes inside testWidgets' fake clock, so the groups
  // that need a plane turn the setting on in their own setUp.
  Future<void> settingOn() => box.put(TvVideoPlane.settingKey, true);

  TvVideoPlane newPlane(FakeMpv mpv) {
    return TvVideoPlane.forNewPlayer(isLive: false)!
      ..bind(mpv, videoRect, onFail: () => failCount += 1);
  }

  void expectStopped(FakeMpv mpv, TvVideoPlane plane) {
    expect(mpv.values['vo'], 'null');
    expect(mpv.values['wid'], '0');
    expect(mpv.values['vid'], 'no');
    expect(mpv.values['pause'], 'yes');
    expect(plane.failed.value, isTrue);
    expect(toasts, contains(TvVideoPlane.failedText));
  }

  group('the setting', () {
    test('is off by default, also on a TV', () {
      expect(TvVideoPlane.enabled, isFalse);
      expect(TvVideoPlane.forNewPlayer(isLive: false), isNull);
    });

    test('does nothing off a TV', () async {
      await box.put(TvVideoPlane.settingKey, true);
      TvPlatform.setTvModeForTesting(false);
      expect(TvVideoPlane.enabled, isFalse);
      expect(TvVideoPlane.forNewPlayer(isLive: false), isNull);
    });

    test(
      'gives a video a plane and leaves a live room on the texture',
      () async {
        await box.put(TvVideoPlane.settingKey, true);
        expect(TvVideoPlane.forNewPlayer(isLive: false), isNotNull);
        expect(TvVideoPlane.forNewPlayer(isLive: true), isNull);
      },
    );

    test('stored quality above 1080P60 comes down, and only that', () async {
      await box.put(SettingBoxKey.defaultVideoQa, 120);
      await box.put(SettingBoxKey.defaultVideoQaCellular, 127);
      TvVideoPlane.capStoredQuality(box);
      expect(box.get(SettingBoxKey.defaultVideoQa), 116);
      expect(box.get(SettingBoxKey.defaultVideoQaCellular), 116);

      await box.put(SettingBoxKey.defaultVideoQa, 80);
      await box.delete(SettingBoxKey.defaultVideoQaCellular);
      TvVideoPlane.capStoredQuality(box);
      expect(box.get(SettingBoxKey.defaultVideoQa), 80);
      expect(box.containsKey(SettingBoxKey.defaultVideoQaCellular), isFalse);
    });
  });

  group('the texture', () {
    test('media_kit gets no way to attach it', () async {
      await settingOn();
      final plane = newPlane(FakeMpv());
      final configuration = plane.configuration;
      expect(configuration.vo, 'mediacodec_embed');
      expect(configuration.androidAttachSurfaceAfterVideoParameters, isTrue);
      // The default can fall back to software, which this output can't show.
      expect(configuration.hwdec, 'mediacodec');
    });

    test('refuses a video above 1080P60 while the setting is on', () async {
      await box.put(TvVideoPlane.settingKey, true);
      expect(TvVideoPlane.refusesTexture(null, false, 3840, 2160), isTrue);
      expect(TvVideoPlane.refusesTexture(null, false, 2160, 3840), isTrue);
      // A tall video's width alone would pass.
      expect(TvVideoPlane.refusesTexture(null, false, 1080, 2400), isTrue);
      expect(toasts, hasLength(3));
    });

    test('allows everything it allowed before the plane existed', () async {
      await box.put(TvVideoPlane.settingKey, true);
      expect(TvVideoPlane.refusesTexture(null, false, 1920, 1080), isFalse);
      expect(TvVideoPlane.refusesTexture(null, false, 1080, 1920), isFalse);
      expect(TvVideoPlane.refusesTexture(null, false, null, null), isFalse);
      expect(TvVideoPlane.refusesTexture(null, true, 3840, 2160), isFalse);
      expect(toasts, isEmpty);
    });

    test('with the setting off, playback is unchanged', () {
      expect(TvVideoPlane.refusesTexture(null, false, 3840, 2160), isFalse);
      expect(toasts, isEmpty);
    });

    test('a player on the plane may play 4K', () async {
      await settingOn();
      final plane = newPlane(FakeMpv());
      expect(TvVideoPlane.refusesTexture(plane, false, 3840, 2160), isFalse);
    });
  });

  group('load', () {
    setUp(settingOn);

    test('with a surface attaches, wid before vo, and hwdec pinned', () {
      final mpv = FakeMpv();
      mpv.values['path'] = '';
      final plane = newPlane(mpv)..onSurfaceReady(7);
      mpv.values['path'] = 'video.mp4';
      plane.onLoad();
      expect(mpv.calls, <String>[
        'vid=auto',
        'hwdec=mediacodec',
        'wid=7',
        'vo=mediacodec_embed',
      ]);
      expect(plane.failed.value, isFalse);
    });

    testWidgets('with no surface loads without video and attaches later', (
      tester,
    ) async {
      final mpv = FakeMpv();
      final plane = newPlane(mpv)..onLoad();
      expect(mpv.calls, <String>['vid=no']);

      plane.onSurfaceReady(7);
      expect(mpv.calls.skip(1), <String>[
        'wid=7',
        'vo=mediacodec_embed',
        'vid=auto',
      ]);

      // The timer is gone: a late failure would stop a playing video.
      await tester.pump(TvVideoPlane.surfaceTimeout * 2);
      expect(plane.failed.value, isFalse);
      expect(mpv.stopCount, 0);
    });

    testWidgets('fails closed when no surface comes in time', (tester) async {
      final mpv = FakeMpv();
      final plane = newPlane(mpv)..onLoad();
      await tester.pump(TvVideoPlane.surfaceTimeout);
      await tester.pump();

      expectStopped(mpv, plane);
      expect(mpv.calls, isNot(contains('vo=mediacodec_embed')));
      expect(mpv.stopCount, 1);
      expect(failCount, 1);
    });

    testWidgets('unload cancels the wait for a surface', (tester) async {
      final mpv = FakeMpv();
      final plane = newPlane(mpv)
        ..onLoad()
        ..onUnload();
      await tester.pump(TvVideoPlane.surfaceTimeout * 2);
      expect(plane.failed.value, isFalse);
    });

    testWidgets('fails closed when mpv refuses an option', (tester) async {
      final mpv = FakeMpv(throwOn: 'hwdec');
      final plane = newPlane(mpv)
        ..onSurfaceReady(7)
        ..onLoad();
      await tester.pump();

      expectStopped(mpv, plane);
      expect(failCount, 1);
    });

    testWidgets('fails closed when mpv quietly keeps another output', (
      tester,
    ) async {
      final mpv = FakeMpv(ignoreSets: const {'vo'});
      final plane = newPlane(mpv)
        ..onLoad()
        ..onSurfaceReady(7);
      await tester.pump();

      expect(plane.failed.value, isTrue);
      expect(mpv.calls, isNot(contains('vid=auto')));
      expect(mpv.stopCount, 1);
    });

    testWidgets('fails closed when mpv quietly keeps another surface', (
      tester,
    ) async {
      final mpv = FakeMpv(ignoreSets: const {'wid'});
      final plane = newPlane(mpv)
        ..onLoad()
        ..onSurfaceReady(7);
      await tester.pump();

      expect(plane.failed.value, isTrue);
      expect(mpv.calls, isNot(contains('vid=auto')));
    });

    testWidgets('a new load clears a failure and can attach again', (
      tester,
    ) async {
      final mpv = FakeMpv();
      final plane = newPlane(mpv)..onLoad();
      await tester.pump(TvVideoPlane.surfaceTimeout);
      await tester.pump();
      expect(plane.failed.value, isTrue);

      plane
        ..onSurfaceReady(7)
        ..onLoad();
      expect(plane.failed.value, isFalse);
      expect(mpv.values['vid'], 'auto');
      expect(mpv.values['vo'], 'mediacodec_embed');
      expect(mpv.values['wid'], '7');
    });

    test('after the player is gone does nothing', () {
      final mpv = FakeMpv();
      final plane = newPlane(mpv)
        ..release()
        ..onLoad()
        ..onSurfaceReady(7)
        ..onSurfaceLost(7);
      expect(mpv.calls, isEmpty);
      expect(plane.failed.value, isFalse);
    });

    testWidgets('a failure after the player is gone does nothing', (
      tester,
    ) async {
      final mpv = FakeMpv();
      final plane = newPlane(mpv)
        ..onLoad()
        ..release();
      await tester.pump(TvVideoPlane.surfaceTimeout * 2);
      expect(mpv.calls, <String>['vid=no']);
      expect(plane.failed.value, isFalse);
    });
  });

  group('surface', () {
    setUp(settingOn);

    test('lost under a decoder takes the video off first', () {
      final mpv = FakeMpv();
      final plane = newPlane(mpv)
        ..onSurfaceReady(7)
        ..onLoad();
      mpv.calls.clear();
      plane.onSurfaceLost(7);
      expect(mpv.calls, <String>['vid=no', 'vo=null', 'wid=0']);
    });

    test('back again attaches the running file', () {
      final mpv = FakeMpv();
      final plane = newPlane(mpv)
        ..onSurfaceReady(7)
        ..onLoad()
        ..onSurfaceLost(7);
      mpv.calls.clear();
      plane.onSurfaceReady(8);
      expect(mpv.calls, <String>['wid=8', 'vo=mediacodec_embed', 'vid=auto']);
    });

    test('the new one coming first keeps mpv on the old one until it goes', () {
      final mpv = FakeMpv();
      final plane = newPlane(mpv)
        ..onSurfaceReady(7)
        ..onLoad();
      mpv.calls.clear();
      plane.onSurfaceReady(8);
      expect(mpv.calls, isEmpty);

      plane.onSurfaceLost(7);
      expect(mpv.calls, <String>[
        'vid=no',
        'vo=null',
        'wid=0',
        'wid=8',
        'vo=mediacodec_embed',
        'vid=auto',
      ]);
    });

    test('a surface mpv was never on can go without touching mpv', () {
      final mpv = FakeMpv();
      final plane = newPlane(mpv)
        ..onSurfaceReady(7)
        ..onLoad();
      mpv.calls.clear();
      plane.onSurfaceLost(99);
      expect(mpv.calls, isEmpty);
    });

    testWidgets('a late surface does not undo a failure', (tester) async {
      final mpv = FakeMpv();
      final plane = newPlane(mpv)..onLoad();
      await tester.pump(TvVideoPlane.surfaceTimeout);
      await tester.pump();
      mpv.calls.clear();

      plane.onSurfaceReady(7);
      expect(mpv.calls, isEmpty);
      expectStopped(mpv, plane);
    });

    test('with nothing loaded just waits for the next load', () {
      final mpv = FakeMpv();
      mpv.values['path'] = '';
      newPlane(mpv).onSurfaceReady(7);
      expect(mpv.calls, isEmpty);
    });
  });

  group('fit', () {
    const box = Size(1920, 1080);
    Rect fit(VideoFitType videoFit, {Size? video, Size size = box}) =>
        TvVideoPlane.fitRect(
          box: size,
          video: video,
          videoFit: videoFit,
          alignment: Alignment.center,
        );

    test('16:9 in 16:9 fills the box', () {
      expect(
        fit(VideoFitType.contain, video: const Size(3840, 2160)),
        Offset.zero & box,
      );
    });

    test('4:3 is centred inside the box', () {
      expect(
        fit(VideoFitType.ratio_4x3, video: const Size(3840, 2160)),
        const Rect.fromLTWH(240, 0, 1440, 1080),
      );
    });

    test('a video narrower than the box keeps its aspect', () {
      expect(
        fit(VideoFitType.contain, video: const Size(1000, 1000)),
        const Rect.fromLTWH(420, 0, 1080, 1080),
      );
    });

    test('alignment moves the rect, as FittedBox would', () {
      expect(
        TvVideoPlane.fitRect(
          box: box,
          video: const Size(1000, 1000),
          videoFit: VideoFitType.contain,
          alignment: Alignment.topCenter,
        ).top,
        0,
      );
      expect(
        TvVideoPlane.fitRect(
          box: const Size(1000, 1000),
          video: const Size(1920, 1080),
          videoFit: VideoFitType.contain,
          alignment: Alignment.topCenter,
        ).top,
        0,
      );
    });

    test('before the first frame the view fills the box', () {
      expect(fit(VideoFitType.contain), Offset.zero & box);
    });

    test('no mode leaves the box, so nothing spills over the page', () {
      const split = Size(1166, 656);
      for (final videoFit in VideoFitType.values) {
        for (final video in const <Size>[
          Size(3840, 2160),
          Size(1080, 1920),
          Size(640, 360),
        ]) {
          final rect = fit(videoFit, video: video, size: split);
          expect(
            (Offset.zero & split).expandToInclude(rect),
            Offset.zero & split,
            reason: '$videoFit on $video gave $rect',
          );
        }
      }
    });

    test('a stored mode that crops falls back to 自动', () {
      const video = Size(1000, 1000);
      final contain = fit(VideoFitType.contain, video: video);
      for (final videoFit in const <VideoFitType>[
        VideoFitType.cover,
        VideoFitType.fitWidth,
        VideoFitType.fitHeight,
        VideoFitType.none,
      ]) {
        expect(TvVideoPlane.supportedFits, isNot(contains(videoFit)));
        expect(fit(videoFit, video: video), contain);
      }
    });
  });

  group('view', () {
    setUp(settingOn);

    Future<void> pumpView(WidgetTester tester, TvVideoPlane plane) async {
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform_views,
        (call) async => 0,
      );
      addTearDown(
        () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform_views,
          null,
        ),
      );
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: plane.view(VideoFitType.contain, Alignment.center),
          ),
        ),
      );
    }

    testWidgets('keeps the D-pad out of the platform view', (tester) async {
      final plane = newPlane(FakeMpv());
      await pumpView(tester, plane);

      expect(
        find.descendant(
          of: find.byType(ExcludeFocus),
          matching: find.byType(PlatformViewLink),
        ),
        findsOneWidget,
      );
    });

    testWidgets('sizes the surface from the video, and keeps the size while '
        'media_kit zeroes it', (tester) async {
      final plane = newPlane(FakeMpv());
      await pumpView(tester, plane);
      final link = find.byType(ExcludeFocus);

      videoRect.value = const Rect.fromLTWH(0, 0, 3840, 2160 / 2);
      await tester.pump();
      final fitted = tester.getRect(link);
      expect(fitted.width / fitted.height, closeTo(32 / 9, .01));

      videoRect.value = Rect.zero;
      await tester.pump();
      expect(tester.getRect(link), fitted);
    });

    testWidgets('shows the failure with what to do next', (tester) async {
      final plane = newPlane(FakeMpv());
      await pumpView(tester, plane);
      expect(find.textContaining('按确认键重试'), findsNothing);

      plane.failed.value = true;
      await tester.pump();
      expect(find.textContaining(TvVideoPlane.failedText), findsOneWidget);
      expect(find.textContaining('按确认键重试，按返回键退出'), findsOneWidget);
    });
  });

  group('upstream hooks', () {
    test('the plane sits above FittedBox and Transform.flip', () {
      final source = File(
        'lib/plugin/pl_player/view/view.dart',
      ).readAsStringSync();
      final hook = source.indexOf('plPlayerController.videoPlane case');
      expect(hook, greaterThan(0));
      expect(source.indexOf('return Transform.flip('), greaterThan(hook));
    });

    test('a player the plane is meant for never gets the texture config', () {
      final source = File(
        'lib/plugin/pl_player/controller.dart',
      ).readAsStringSync();
      final create = source.substring(
        source.indexOf('TvVideoPlane.forNewPlayer'),
        source.indexOf('videoPlane?.attach('),
      );
      expect(
        create.indexOf('videoPlane?.configuration'),
        lessThan(create.indexOf('VideoControllerConfiguration(')),
      );
    });

    test('the refusal runs before anything opens the stream', () {
      final source = File(
        'lib/plugin/pl_player/controller.dart',
      ).readAsStringSync();
      expect(
        source.indexOf('TvVideoPlane.refusesTexture('),
        lessThan(source.indexOf('await _createVideoController(')),
      );
    });

    test('the setting is reachable on a TV', () {
      final source = File(
        'lib/pages/setting/models/video_settings.dart',
      ).readAsStringSync();
      expect(
        source,
        contains('if (TvPlatform.isTv) TvVideoPlane.settingsModel,'),
      );
    });
  });
}
