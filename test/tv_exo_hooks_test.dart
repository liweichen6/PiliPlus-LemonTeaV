// M17.9's hooks (docs/tv/PLAN.md): each is inert off TV, and on TV every
// player is ExoPlayer, a failure ends on its failure screen, the quality list
// holds only what plays, and the TV defaults and descriptions are ExoPlayer's.
// `M17.11` adds the adapter's own tests beside these.
import 'dart:io';

import 'package:PiliPlus/models/common/audio_normalization.dart';
import 'package:PiliPlus/models/common/video/base_quality.dart';
import 'package:PiliPlus/models/video/play/url.dart';
import 'package:PiliPlus/models_new/live/live_room_play_info/codec.dart';
import 'package:PiliPlus/models_new/live/live_room_play_info/format.dart';
import 'package:PiliPlus/models_new/live/live_room_play_info/stream.dart';
import 'package:PiliPlus/plugin/pl_player/models/video_fit_type.dart';
import 'package:PiliPlus/tv/tv_exo_live_source.dart';
import 'package:PiliPlus/tv/tv_exo_player.dart';
import 'package:PiliPlus/tv/tv_exo_qualities.dart';
import 'package:PiliPlus/tv/tv_exo_settings.dart';
import 'package:PiliPlus/tv/tv_exo_view.dart';
import 'package:PiliPlus/tv/tv_platform.dart';
import 'package:PiliPlus/utils/storage.dart';
import 'package:PiliPlus/utils/storage_key.dart';
import 'package:PiliPlus/utils/video_utils.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive.dart';
import 'package:media_kit/media_kit.dart';

CodecItem _codec(String name, int qn) => CodecItem(
  codecName: name,
  currentQn: LiveQuality(qn, '$qn'),
  acceptQn: const [],
  baseUrl: '/$name',
  urlInfo: const [],
);

/// A room offering FLV (H.264, HEVC) and HLS fMP4 (H.264, HEVC).
List<Stream> _room() => [
  Stream(
    protocolName: 'http_stream',
    format: [
      Format(
        formatName: 'flv',
        codec: [_codec('avc', 10000), _codec('hevc', 10000)],
      ),
    ],
  ),
  Stream(
    protocolName: 'http_hls',
    format: [
      Format(
        formatName: 'fmp4',
        codec: [_codec('avc', 10000), _codec('hevc', 10000)],
      ),
    ],
  ),
];

Map<String, Object?> _video(int id, String codecs, int w, int h) => {
  'id': id,
  'base_url': 'https://cdn/$id-$codecs.m4s',
  'codecs': codecs,
  'width': w,
  'height': h,
  'frame_rate': '60',
};

Map<String, Object?> _format(int q, String desc, List<String> codecs) => {
  'quality': q,
  'format': 'q$q',
  'new_description': desc,
  'display_desc': desc,
  'codecs': codecs,
};

/// 杜比视界 (P8.4 and P5), HDR 真彩, 4K (HEVC, AV1), 1080P60 (AVC), 1080P.
PlayUrlModel _model() => PlayUrlModel.fromJson({
  'quality': 116,
  'last_play_time': 0,
  'accept_quality': [126, 125, 120, 116, 80],
  'support_formats': [
    _format(126, '杜比视界', ['dvh1.08.07', 'dvh1.05.06']),
    _format(125, 'HDR 真彩', ['hev1.2.4.L156.90']),
    _format(120, '4K 超清', ['hev1.1.6.L156.90', 'av01.0.13M.08']),
    _format(116, '1080P 60帧', ['avc1.640032']),
    _format(80, '1080P 高清', ['avc1.640032']),
  ],
  'dash': {
    'video': [
      _video(126, 'dvh1.08.07', 3840, 2160),
      _video(126, 'dvh1.05.06', 3996, 2160),
      _video(125, 'hev1.2.4.L156.90', 3840, 2160),
      _video(120, 'hev1.1.6.L156.90', 3840, 2160),
      _video(120, 'av01.0.13M.08', 3840, 2160),
      _video(116, 'avc1.640032', 1920, 1080),
      _video(80, 'avc1.640032', 1920, 1080),
    ],
    'audio': <Object>[],
  },
});

const _allHdr = {
  TvExoQualities.displayDolbyVision,
  TvExoQualities.displayHdr10,
  TvExoQualities.displayHlg,
  TvExoQualities.displayHdr10Plus,
};

String _desc(PlayUrlModel m, int q) =>
    m.supportFormats!.firstWhere((f) => f.quality == q).newDesc!;

const _channel = TvExoPlayer.channel;

void _mockBridge(Future<Object?> Function(MethodCall call) handler) {
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(_channel, handler);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;

  setUpAll(() async {
    tempDir = await Directory.systemTemp.createTemp('tv_exo_hooks_test_');
    Hive.init(tempDir.path);
    try {
      GStorage.setting = await Hive.openBox('setting', bytes: Uint8List(0));
    } catch (_) {}
  });

  tearDownAll(() async {
    await Hive.close();
    await tempDir.delete(recursive: true);
  });

  tearDown(() {
    TvPlatform.setTvModeForTesting(false);
    _mockBridge((_) async => null);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_channel, null);
  });

  group('off TV, every hook is inert', () {
    setUp(() => TvPlatform.setTvModeForTesting(false));

    test('the live source rule keeps upstream\'s choice', () {
      expect(
        TvExoLiveSource.onTv(_room(), (stream: 0, format: 0, codec: 1)),
        isNull,
      );
    });

    test(
      'the quality list is left as served, with no call to the bridge',
      () async {
        final calls = <String>[];
        _mockBridge((call) async {
          calls.add(call.method);
          return null;
        });
        final model = _model();
        await TvExoQualities.onTv(model);
        expect(calls, isEmpty);
        expect(model.dash!.video, hasLength(7));
        expect(model.acceptQuality, [126, 125, 120, 116, 80]);
        expect(_desc(model, 126), '杜比视界');
      },
    );

    test('the settings keep upstream\'s descriptions', () {
      expect(TvExoSettings.bufferSize, isNull);
      expect(TvExoSettings.bufferSec, isNull);
      expect(TvExoSettings.liveBufferSize, isNull);
      expect(TvExoSettings.liveBufferSec, isNull);
      expect(TvExoSettings.normalizationSubtitle, isNull);
      expect(
        TvExoSettings.normalizationDialog(_NoContext(), () {}),
        isNull,
      );
    });

    test('the view hook builds nothing for a player that isn\'t ExoPlayer', () {
      expect(
        TvExoView.of(null, VideoFitType.contain, Alignment.center),
        isNull,
      );
      expect(TvExoPlayer.videoControllerOf(_NotExo()), isNull);
    });

    test('the defaults are only seeded on TV', () {
      // TvPlatform.initialize seeds only when isTv; off TV the keys stay
      // unset, so upstream's own defaults (4 MB, 16 s, 0) apply.
      expect(TvPlatform.isTv, isFalse);
      expect(GStorage.setting.containsKey(SettingBoxKey.bufferSize), isFalse);
    });

    // The hooks in upstream's files are inserted blocks, each behind
    // `TvPlatform.isTv` or a helper above that answers null off TV, with
    // upstream's own lines after them unchanged (M17.6, decision 6).
    test('each hook in upstream\'s files is an inserted, guarded block', () {
      String read(String path) => File(path).readAsStringSync();

      final ctl = read('lib/plugin/pl_player/controller.dart');
      final initPlayer = ctl.substring(
        ctl.indexOf('Future<Player> _initPlayer() async {'),
      );
      final block = initPlayer.substring(
        initPlayer.indexOf('if (TvPlatform.isTv) {'),
        initPlayer.indexOf('final opt = {'),
      );
      expect(block, contains('TvExoPlayer.create()'));
      expect(block, contains('return player;'));
      expect(block, isNot(contains('await Player.create(')));
      // Upstream's mpv path follows, as it was.
      expect(
        initPlayer.indexOf('await Player.create('),
        greaterThan(initPlayer.indexOf('final opt = {')),
      );
      expect(
        initPlayer.indexOf('await VideoController.create('),
        greaterThan(initPlayer.indexOf('await Player.create(')),
      );

      final view = read('lib/plugin/pl_player/view/view.dart');
      expect(
        view.indexOf('if (TvExoView.of('),
        lessThan(view.indexOf('return Transform.flip(')),
      );
      expect(
        read('lib/pages/live_room/controller.dart'),
        contains('TvExoLiveSource.onTv(stream'),
      );
      expect(
        read('lib/pages/video/controller.dart'),
        contains('await TvExoQualities.onTv(data);'),
      );
      final settings = read('lib/pages/setting/models/video_settings.dart');
      for (final getter in const [
        'bufferSize',
        'bufferSec',
        'liveBufferSize',
        'liveBufferSec',
      ]) {
        expect(settings, contains('TvExoSettings.$getter ??'));
      }
      expect(
        read('lib/pages/setting/models/play_settings.dart'),
        allOf(
          contains(
            'if (TvExoSettings.normalizationSubtitle case final tv?) return tv;',
          ),
          contains('TvExoSettings.normalizationDialog('),
        ),
      );
    });
  });

  group('on TV', () {
    setUp(() => TvPlatform.setTvModeForTesting(true));

    test('FLV with HEVC plays as HLS fMP4 with HEVC', () {
      expect(
        TvExoLiveSource.onTv(_room(), (stream: 0, format: 0, codec: 1)),
        (stream: 1, format: 0, codec: 1),
      );
      expect(
        TvExoLiveSource.onTv(_room(), (stream: 0, format: 0, codec: 0)),
        (stream: 0, format: 0, codec: 0),
      );
    });

    test('the TV defaults are ExoPlayer\'s buffer, as doubles', () {
      const d = TvPlatform.defaultTvSettings;
      expect(d[SettingBoxKey.bufferSize], 100.0);
      expect(d[SettingBoxKey.bufferSec], 180.0);
      expect(d[SettingBoxKey.liveBufferSize], 64.0);
      expect(d.containsKey(SettingBoxKey.liveBufferSec), isFalse);
      for (final k in const [
        SettingBoxKey.bufferSize,
        SettingBoxKey.bufferSec,
        SettingBoxKey.liveBufferSize,
      ]) {
        expect(d[k], isA<double>());
      }
    });

    test('the defaults fill only unset keys', () async {
      final box = await Hive.openBox<dynamic>(
        'defaults_test',
        bytes: Uint8List(0),
      );
      await box.put(SettingBoxKey.bufferSize, 32.0);
      await TvPlatform.seedTvDefaultsToBox(box);
      expect(box.get(SettingBoxKey.bufferSize), 32.0);
      expect(box.get(SettingBoxKey.bufferSec), 180.0);
      expect(box.get(SettingBoxKey.liveBufferSize), 64.0);
      await box.close();
    });

    test('the buffer descriptions show the heap limit', () async {
      _mockBridge(
        (call) async => call.method == 'heapLimit' ? 192 << 20 : null,
      );
      await TvExoSettings.load();
      await GStorage.setting.putAll(<String, Object>{
        SettingBoxKey.bufferSize: 100.0,
        SettingBoxKey.bufferSec: 180.0,
        SettingBoxKey.liveBufferSize: 64.0,
        SettingBoxKey.liveBufferSec: 0.0,
      });
      expect(TvExoSettings.bufferSize, startsWith('当前：100MB。'));
      for (final text in [
        TvExoSettings.bufferSize,
        TvExoSettings.bufferSec,
        TvExoSettings.liveBufferSize,
        TvExoSettings.liveBufferSec,
      ]) {
        expect(text, contains('Java 堆，本机上限 192 MB'));
        expect(text, isNot(contains('mpv')));
      }
      expect(TvExoSettings.liveBufferSize, startsWith('当前：64MB。'));
      expect(TvExoSettings.liveBufferSec, startsWith('当前：不限制。'));
      TvExoSettings.heapLimit = null;
      expect(TvExoSettings.heapNote(null), isNot(contains('MB')));
    });

    group('音量均衡', () {
      // The filter upstream builds for mpv from the stored value and the
      // video's measurement, which the adapter reads.
      String? filter(String config, Map<String, Object>? volume) {
        final param = AudioNormalization.getParamFromConfig(config);
        final f = AudioNormalization.parse(
          volume == null ? null : Volume.fromJson(volume),
          param,
        );
        return f.isEmpty ? null : '"[aid1] $f [ao]"';
      }

      Map<String, Object> measured(num i) => {
        'measured_i': i,
        'measured_lra': 4.5,
        'measured_tp': -2.1,
        'measured_threshold': -29.7,
        'target_offset': 0.9,
        'target_i': -14,
        'target_tp': -1,
      };

      TvExoNormalization resolve(String config, Map<String, Object>? v) =>
          TvExoNormalization.resolve(
            config: config,
            fallback: '1',
            filter: filter(config, v),
          );

      test('标准 and 高动态 are one gain toward -14 and -24 LUFS', () {
        const standard = TvExoNormalization.standard;
        const high = TvExoNormalization.highDynamic;
        expect(
          resolve(standard, measured(-19.4)),
          const TvExoNormalization.loudness(-14 - -19.4, -1),
        );
        expect(
          resolve(high, measured(-16.4)),
          const TvExoNormalization.loudness(-24 - -16.4, -1),
        );
      });

      test('nothing without a usable measurement, and no fallback', () {
        for (final config in const [
          TvExoNormalization.standard,
          TvExoNormalization.highDynamic,
        ]) {
          expect(resolve(config, null).mode, 'off');
          expect(resolve(config, measured(0.001)).mode, 'off');
          expect(resolve(config, measured(-28.5)).mode, 'off');
          expect(resolve(config, measured(-28)).mode, 'loudness');
        }
      });

      test('动态压缩 is upstream\'s dynaudnorm, with or without data', () {
        expect(resolve('1', measured(-19.4)).mode, 'dynamic');
        expect(resolve('1', null).mode, 'dynamic');
        expect(resolve('0', measured(-19.4)).mode, 'off');
      });

      test(
        'a value stored before: 预设 loudnorm as before',
        () async {
          // Upstream builds its fallback into the filter from the stored one.
          await GStorage.setting.put(SettingBoxKey.fallbackNormalization, '1');
          addTearDown(
            () => GStorage.setting.delete(SettingBoxKey.fallbackNormalization),
          );
          expect(
            resolve('2', measured(-22.5)),
            const TvExoNormalization.loudness(-16 - -22.5, -1.5),
          );
          expect(resolve('2', null).mode, 'dynamic');
          expect(resolve('2', measured(0.001)).mode, 'dynamic');
        },
      );

      test('自定义 reads loudnorm\'s I and TP, or dynaudnorm\'s numbers', () {
        expect(
          resolve('loudnorm=I=-18:LRA=7:TP=-0.5', measured(-20)),
          const TvExoNormalization.loudness(2, -0.5),
        );
        // ffmpeg's defaults where the string gives none. A bare `loudnorm`
        // gets no measurement from upstream's builder, so it does nothing.
        expect(resolve('loudnorm', measured(-20)).mode, 'off');
        expect(
          resolve('loudnorm=LRA=7', measured(-20)),
          const TvExoNormalization.loudness(-4, -2),
        );
        expect(resolve('loudnorm=I=-18', null).mode, 'off');
        expect(
          resolve('dynaudnorm=f=100:g=7:p=0.8', null).toArgs(),
          <String, Object>{
            'mode': 'dynamic',
            'frameMs': 100,
            'window': 7,
            'targetRms': 0.0,
            'peak': 0.8,
            'maxGain': 10.0,
          },
        );
        expect(resolve('acompressor=threshold=0.1', measured(-20)).mode, 'off');
        expect(TvExoSettings.isCustom('loudnorm=I=-18'), isTrue);
        expect(TvExoSettings.isCustom(TvExoNormalization.standard), isFalse);
        expect(TvExoSettings.isCustom('1'), isFalse);
        expect(TvExoSettings.isCustom('2'), isFalse);
      });

      test('the setting shows the five options and what each does', () {
        expect(TvExoSettings.normalizationOptions.map((o) => o.$2), [
          '关闭',
          '标准 (-14 LUFS)',
          '高动态 (-24 LUFS)',
          '动态压缩',
          '自定义',
        ]);
        expect(TvExoSettings.normalizationSubtitleFor('0'), '当前:「关闭」');
        final standard = TvExoSettings.normalizationSubtitleFor(
          TvExoNormalization.standard,
        );
        expect(standard, startsWith('当前:「标准 (-14 LUFS)」'));
        expect(standard, contains('-28 LUFS'));
        expect(standard, contains('杜比全景声'));
        expect(
          TvExoSettings.normalizationSubtitleFor('1'),
          startsWith('当前:「动态压缩」'),
        );
        expect(
          TvExoSettings.normalizationSubtitleFor('loudnorm=I=-20'),
          allOf(startsWith('当前:「自定义」：loudnorm=I=-20'), contains('-28 LUFS')),
        );
        expect(
          TvExoSettings.normalizationSubtitleFor('dynaudnorm=f=100'),
          contains('f、g、r、p、m'),
        );
        expect(
          TvExoSettings.normalizationSubtitleFor('acompressor'),
          contains('按关闭处理'),
        );
        expect(TvExoSettings.normalizationSubtitleFor('2'), contains('旧设置'));
      });
    });

    group('the quality list', () {
      test('drops what no decoder declares; upstream falls back', () {
        final model = _model();
        // P5 has no Dolby Vision decoder; AV1 4K isn't declared.
        final removed = TvExoQualities.apply(model, const [
          'dolbyVision',
          'no',
          'yes',
          'yes',
          'no',
          'yes',
          'yes',
        ], _allHdr);
        expect(removed, ['126 dvh1.05.06', '120 av01.0.13M.08']);
        expect(model.dash!.video!.map((v) => v.codecs), [
          'dvh1.08.07',
          'hev1.2.4.L156.90',
          'hev1.1.6.L156.90',
          'avc1.640032',
          'avc1.640032',
        ]);
        final f120 = model.supportFormats!.firstWhere((f) => f.quality == 120);
        expect(f120.codecs, ['hev1.1.6.L156.90']);
        expect(_desc(model, 126), '杜比视界');
        expect(model.acceptQuality, [126, 125, 120, 116, 80]);
      });

      test('a quality with nothing playable is greyed and named, and '
          'upstream picks the next one', () {
        final model = _model();
        TvExoQualities.apply(model, const [
          'no',
          'no',
          'yes',
          'yes',
          'yes',
          'yes',
          'yes',
        ], _allHdr);
        expect(
          model.dash!.video!.availableVideoQualities,
          isNot(contains(126)),
        );
        expect(model.acceptQuality, [125, 120, 116, 80]);
        expect(_desc(model, 126), '杜比视界${TvExoQualities.unsupportedSuffix}');
        final (q, _, _, video) = VideoUtils.findTargetVideo(
          model.dash!.video!,
          126,
          model.acceptQuality,
          model.supportFormats!,
          const [],
        );
        expect(q, 125);
        expect(video.codecs, 'hev1.2.4.L156.90');
      });

      test('Profile 8.4 on its base layer is labelled HLG', () {
        final model = _model();
        TvExoQualities.apply(model, const [
          'baseLayer',
          'no',
          'yes',
          'yes',
          'yes',
          'yes',
          'yes',
        ], _allHdr);
        expect(_desc(model, 126), '杜比视界${TvExoQualities.hlgSuffix}');
      });

      test('HDR needs a display that reports it', () {
        final model = _model();
        TvExoQualities.apply(model, const [
          'dolbyVision',
          'dolbyVision',
          'yes',
          'yes',
          'yes',
          'yes',
          'yes',
        ], const {});
        expect(model.dash!.video!.availableVideoQualities, {120, 116, 80});
        expect(_desc(model, 125), endsWith(TvExoQualities.unsupportedSuffix));
        expect(
          TvExoQualities.playable(126, 'dolbyVision', const {
            TvExoQualities.displayHdr10,
          }),
          isFalse,
        );
        expect(
          TvExoQualities.playable(126, 'baseLayer', const {
            TvExoQualities.displayHlg,
          }),
          isTrue,
        );
        expect(TvExoQualities.playable(80, 'yes', const {}), isTrue);
      });

      test('nothing playable leaves the list as served', () {
        final model = _model();
        expect(
          TvExoQualities.apply(model, List.filled(7, 'no'), _allHdr),
          isEmpty,
        );
        expect(model.dash!.video, hasLength(7));
      });

      test('the hook asks the bridge on TV', () async {
        final calls = <String>[];
        _mockBridge((call) async {
          calls.add(call.method);
          return switch (call.method) {
            'supports' => [
              for (final s in call.arguments as List)
                (s as Map)['codecs'].toString().startsWith('dvh1.05')
                    ? 'no'
                    : 'yes',
            ],
            'displayHdr' => [1, 2, 3, 4],
            _ => null,
          };
        });
        final model = _model();
        await TvExoQualities.onTv(model);
        expect(calls, contains('supports'));
        expect(model.dash!.video, hasLength(6));
      });
    });

    group('fail closed', () {
      test('a bridge that can\'t make its player gives the failure screen, '
          'and Select tries ExoPlayer again', () async {
        var createOk = false;
        final calls = <String>[];
        _mockBridge((call) async {
          calls.add(call.method);
          if (call.method == 'create' && !createOk) {
            throw PlatformException(code: 'exo', message: 'no codec service');
          }
          return null;
        });
        final player = await TvExoPlayer.create(isLive: () => false);
        expect(player, isA<TvExoPlayer>());
        await player.open(const Media('https://cdn/v.m4s'), play: false);
        expect(player.failed.value, contains('ExoPlayer 启动失败'));
        expect(calls, isNot(contains('open')));
        expect(player.state.playing, isFalse);
        expect(player.state.buffering, isFalse);

        createOk = true;
        calls.clear();
        await player.play();
        expect(calls, containsAllInOrder(<String>['create', 'open']));
        expect(player.failed.value, isNull);
        await player.dispose();
      });

      test('dispose releases the bridge\'s player', () async {
        final calls = <String>[];
        _mockBridge((call) async {
          calls.add(call.method);
          return null;
        });
        final player = await TvExoPlayer.create(isLive: () => false);
        await player.dispose();
        expect(calls, ['create', 'dispose']);
      });

      test(
        'a player made over another leaves the new one\'s bridge alone',
        () async {
          final calls = <String>[];
          _mockBridge((call) async {
            calls.add(call.method);
            return null;
          });
          final old = await TvExoPlayer.create(isLive: () => false);
          final now = await TvExoPlayer.create(isLive: () => false);
          calls.clear();
          await old.dispose();
          expect(calls, isEmpty);
          await now.dispose();
          expect(calls, ['dispose']);
        },
      );
    });
  });
}

/// The off-TV dialog hook never reads its context.
class _NoContext extends Fake implements BuildContext {}

/// Any player that isn't ExoPlayer, for the hook's null case.
class _NotExo extends Fake implements Player {}
