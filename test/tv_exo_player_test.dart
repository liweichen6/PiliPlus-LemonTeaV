// The TV's ExoPlayer adapter over a fake bridge (docs/tv/PLAN.md, M17.11):
// what it sends the Kotlin side, how it turns the bridge's events into
// media_kit's state and streams, the `edl://` split, live reconnects, the
// bounded retry and its wording, subtitle cues, the player rule, and the
// buffer and normalization mappings.
//
// `tv_exo_hooks_test.dart` has the hooks (each inert off TV, and their shape
// in upstream's files), the TV defaults and descriptions, the quality list,
// the refusal reasons and fail-closed creation; this file doesn't repeat
// them.
import 'dart:convert';
import 'dart:io';

import 'package:PiliPlus/models/common/audio_normalization.dart';
import 'package:PiliPlus/tv/tv_exo_player.dart';
import 'package:PiliPlus/plugin/pl_player/models/video_fit_type.dart';
import 'package:PiliPlus/tv/tv_exo_subtitles.dart';
import 'package:PiliPlus/tv/tv_exo_view.dart';
import 'package:PiliPlus/tv/tv_platform.dart';
import 'package:PiliPlus/utils/storage.dart';
import 'package:PiliPlus/utils/storage_key.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive.dart';
import 'package:media_kit/media_kit.dart';

const MethodChannel _channel = TvExoPlayer.channel;

// Media3's playback states, as the bridge sends them.
const int _idle = 1;
const int _buffering = 2;
const int _ready = 3;
const int _ended = 4;

/// The Kotlin side: answers every call, records what it was sent, and sends
/// events back as the bridge does, tagged with the latest open's `gen`.
class _Bridge {
  _Bridge({this.failOpen = false}) {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_channel, (call) async {
          calls.add(call);
          if (call.method == 'open' && failOpen) {
            throw PlatformException(code: 'exo', message: 'no surface');
          }
          return null;
        });
    addTearDown(
      () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(_channel, null),
    );
  }

  bool failOpen;
  final List<MethodCall> calls = [];

  List<String> get methods => [for (final c in calls) c.method];

  List<Map> get opens => [
    for (final c in calls)
      if (c.method == 'open') c.arguments as Map,
  ];

  Map get lastOpen => opens.last;

  Map? argsOf(String method) =>
      calls.lastWhere((c) => c.method == method).arguments as Map?;

  /// An event from Kotlin for the latest open, or for [gen].
  Future<void> send(String method, Map<String, Object?> args, {int? gen}) =>
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .handlePlatformMessage(
            _channel.name,
            _channel.codec.encodeMethodCall(
              MethodCall(method, {...args, 'gen': gen ?? lastOpen['gen']}),
            ),
            (_) {},
          );

  Future<void> state(int state, {bool play = true, bool loading = false}) =>
      send('state', {
        'state': state,
        'playWhenReady': play,
        'loading': loading,
      });

  Future<void> error(
    String kind, {
    bool recoverable = false,
    int? status,
    String? code,
    Map<String, Object?> extra = const {},
  }) => send('error', {
    'kind': kind,
    'recoverable': recoverable,
    'status': ?status,
    'code': ?code,
    ...extra,
  });
}

const String _videoUrl = 'https://upos-sz-mirrorcos.bilivideo.com/v.m4s?e=1';
const String _audioUrl = 'https://upos-sz-mirrorcos.bilivideo.com/a.m4s?e=1';

/// The `edl://` string upstream's `setDataSource` builds for a DASH video.
String _edl(String video, String audio) =>
    'edl://!no_chapters;%${video.length}%$video;'
    '!new_stream;!no_chapters;%${audio.length}%$audio';

/// The player's error stream, collected.
List<String> _errors(TvExoPlayer player) {
  final List<String> errors = [];
  final sub = player.stream.error.listen(errors.add);
  addTearDown(sub.cancel);
  return errors;
}

/// Upstream's error handler (`PlPlayerController`): a video's
/// "Failed to open https://…" or loopback text is retried; "Cannot open" is
/// ignored.
bool _upstreamRetries(String event) =>
    event.startsWith('Failed to open https://') ||
    event.startsWith('Failed to open http://127.0.0.1:');

bool _upstreamIgnores(String event) => event.startsWith('Cannot open');

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;

  setUpAll(() async {
    tempDir = await Directory.systemTemp.createTemp('tv_exo_player_test_');
    Hive.init(tempDir.path);
    try {
      GStorage.setting = await Hive.openBox('setting', bytes: Uint8List(0));
    } catch (_) {}
  });

  tearDownAll(() async {
    await Hive.close();
    await tempDir.delete(recursive: true);
  });

  setUp(() async {
    TvExoPlayer.maxPixels = 0;
    TvExoPlayer.tryAnywayNext = false;
    await GStorage.setting.putAll({
      SettingBoxKey.bufferSize: 100.0,
      SettingBoxKey.bufferSec: 180.0,
      SettingBoxKey.liveBufferSize: 64.0,
      SettingBoxKey.liveBufferSec: 0.0,
      SettingBoxKey.audioNormalization: '0',
      SettingBoxKey.fallbackNormalization: '0',
    });
  });

  tearDown(() => TvPlatform.setTvModeForTesting(false));

  group('the player rule', () {
    test('ExoPlayer is the only player that reads as ExoPlayer, and hands '
        'upstream its own video controller', () async {
      _Bridge();
      final player = await TvExoPlayer.create(isLive: () => false);
      expect(TvExoPlayer.isExo(player), isTrue);
      expect(TvExoPlayer.notExo(player), isFalse);
      expect(TvExoPlayer.isExo(null), isFalse);
      expect(TvExoPlayer.notExo(null), isTrue);
      expect(TvExoPlayer.videoControllerOf(player), player.videoController);
      expect(TvExoPlayer.videoControllerOf(_NotExo()), isNull);
      await player.dispose();
    });

    test('the player asks whether it is live at each open, so one player '
        'serves a video and then a live room', () async {
      final bridge = _Bridge();
      var live = false;
      final player = await TvExoPlayer.create(isLive: () => live);
      await player.open(const Media(_videoUrl));
      expect(bridge.lastOpen['live'], isFalse);
      expect(player.isLive, isFalse);
      live = true;
      await player.open(const Media('https://live/room.m3u8?k=1'));
      expect(bridge.lastOpen['live'], isTrue);
      expect(bridge.lastOpen['hls'], isTrue);
      expect(player.isLive, isTrue);
      await player.dispose();
    });
  });

  group('the edl:// split', () {
    test('a DASH video\'s edl string is its video and audio URLs', () {
      expect(TvExoPlayer.splitEdl(_edl(_videoUrl, _audioUrl)), (
        _videoUrl,
        _audioUrl,
      ));
    });

    test('lengths are in bytes, so a local file with a non-ASCII path '
        'splits right', () {
      const video = '/storage/emulated/0/下载/视频.m4s';
      const audio = '/storage/emulated/0/下载/音频.m4s';
      final uri =
          'edl://!no_chapters;%${utf8Length(video)}%$video;'
          '!new_stream;!no_chapters;%${utf8Length(audio)}%$audio';
      expect(TvExoPlayer.splitEdl(uri), (video, audio));
    });

    test('a URL with ; and % in its query survives', () {
      const video = 'https://cdn/v.m4s?a=1;b=%25;c=2';
      const audio = 'https://cdn/a.m4s?x=%3B';
      expect(TvExoPlayer.splitEdl(_edl(video, audio)), (video, audio));
    });

    test('anything else is one URL with no audio', () {
      expect(TvExoPlayer.splitEdl(_videoUrl), (_videoUrl, null));
      expect(TvExoPlayer.splitEdl('https://live/room.flv'), (
        'https://live/room.flv',
        null,
      ));
      expect(TvExoPlayer.splitEdl('edl://!no_chapters;'), (
        'edl://!no_chapters;',
        null,
      ));
    });

    test('an old multi-part video (durl) plays its first part, never a '
        'second part as audio', () {
      const parts = ['https://cdn/1.flv?e=1', 'https://cdn/2.flv?e=1'];
      final uri = StringBuffer('edl://!no_chapters;');
      for (final p in parts) {
        uri.write('%${p.length}%$p,length=360.5;');
      }
      expect(TvExoPlayer.splitEdl(uri.toString()), (parts.first, null));
    });

    test(
      'the open sends the two URLs, and HLS only for an .m3u8 path',
      () async {
        final bridge = _Bridge();
        final player = await TvExoPlayer.create(isLive: () => false);
        await player.open(Media(_edl(_videoUrl, _audioUrl)));
        expect(bridge.lastOpen['video'], _videoUrl);
        expect(bridge.lastOpen['audio'], _audioUrl);
        expect(bridge.lastOpen['hls'], isFalse);
        await player.dispose();
      },
    );
  });

  group('states and streams', () {
    test('an open sends 音量均衡 first, then the open with the buffer, '
        'headers, start and gen', () async {
      final bridge = _Bridge();
      final player = await TvExoPlayer.create(isLive: () => false);
      player.setMediaHeader(
        userAgent: 'UA',
        referer: 'https://www.bilibili.com',
        headers: {'Cookie': 'x'},
      );
      bridge.calls.clear();
      await player.open(
        Media(_edl(_videoUrl, _audioUrl), start: const Duration(seconds: 42)),
        play: false,
      );
      expect(bridge.methods, ['setNormalization', 'open']);
      expect(bridge.argsOf('setNormalization'), {'mode': 'off'});
      final open = bridge.lastOpen;
      expect(open['startMs'], 42000);
      expect(open['play'], isFalse);
      expect(open['live'], isFalse);
      expect(open['gen'], isA<int>());
      expect(open['headers'], {
        'Cookie': 'x',
        'User-Agent': 'UA',
        'Referer': 'https://www.bilibili.com',
      });
      // 缓冲大小 100 MB and 缓冲时长 180 s, the TV's defaults.
      expect(open['bufferBytes'], 100 * 1024 * 1024);
      expect(open['bufferMs'], 180000);
      expect(open['maxPixels'], 0);
      expect(open['tryAnyway'], isFalse);
      expect(player.state.position, const Duration(seconds: 42));
      await player.dispose();
    });

    test('an open reads as buffering at once, and playing once asked to '
        'play, as mpv\'s properties do', () async {
      _Bridge();
      final player = await TvExoPlayer.create(isLive: () => false);
      await player.open(const Media(_videoUrl));
      expect(player.state.buffering, isTrue);
      expect(player.state.playing, isTrue);
      expect(player.getProperty('demuxer-cache-idle'), 'no');
      await player.open(const Media('https://cdn/other.m4s'), play: false);
      expect(player.state.playing, isFalse);
      await player.dispose();
    });

    test(
      'the bridge\'s states become playing, buffering and completed',
      () async {
        final bridge = _Bridge();
        final player = await TvExoPlayer.create(isLive: () => false);
        final playing = <bool>[];
        final completed = <bool>[];
        final subs = [
          player.stream.playing.listen(playing.add),
          player.stream.completed.listen(completed.add),
        ];
        await player.open(const Media(_videoUrl));
        await bridge.state(_ready);
        expect(player.state.playing, isTrue);
        expect(player.state.buffering, isFalse);
        await bridge.state(_buffering, loading: true);
        expect(player.state.buffering, isTrue);
        expect(player.getProperty('demuxer-cache-idle'), 'no');
        await bridge.state(_ready);
        expect(player.getProperty('demuxer-cache-idle'), 'yes');
        await bridge.state(_ended);
        expect(player.state.completed, isTrue);
        expect(player.state.playing, isFalse);
        await bridge.state(_idle, play: false);
        expect(player.state.playing, isFalse);
        expect(player.state.buffering, isFalse);
        await pumpEventQueue();
        expect(playing, [true, false]);
        expect(completed, [true, false]);
        for (final s in subs) {
          await s.cancel();
        }
        await player.dispose();
      },
    );

    test('pause and play report at once and then tell the bridge', () async {
      final bridge = _Bridge();
      final player = await TvExoPlayer.create(isLive: () => false);
      await player.open(const Media(_videoUrl));
      await bridge.state(_ready);
      bridge.calls.clear();
      await player.playOrPause();
      expect(player.state.playing, isFalse);
      await player.playOrPause();
      expect(player.state.playing, isTrue);
      expect(bridge.methods, ['pause', 'play']);
      await player.dispose();
    });

    test(
      'an event from an earlier open or an earlier player is dropped',
      () async {
        final bridge = _Bridge();
        final player = await TvExoPlayer.create(isLive: () => false);
        await player.open(const Media(_videoUrl));
        final first = bridge.lastOpen['gen'] as int;
        await player.open(const Media('https://cdn/next.m4s'));
        await bridge.send('position', {
          'pos': 99000,
          'buf': 99000,
          'dur': 100000,
        }, gen: first);
        await bridge.send('error', {'kind': 'decoder'}, gen: first);
        expect(player.state.position, Duration.zero);
        expect(player.failed.value, isNull);
        await player.dispose();
      },
    );

    test('positions give the position, buffer and length; a live room has '
        'no length', () async {
      final bridge = _Bridge();
      var live = false;
      final player = await TvExoPlayer.create(isLive: () => live);
      await player.open(const Media(_videoUrl));
      await bridge.send('position', {'pos': 1500, 'buf': 9000, 'dur': 300000});
      expect(player.state.position, const Duration(milliseconds: 1500));
      expect(player.state.buffer, const Duration(seconds: 9));
      expect(player.state.duration, const Duration(minutes: 5));
      // Media3 reports no length until it knows one; the last one stays.
      await bridge.send('position', {'pos': 1600, 'buf': 9000, 'dur': 0});
      expect(player.state.duration, const Duration(minutes: 5));

      live = true;
      await player.open(const Media('https://live/room.m3u8'));
      await bridge.send('position', {'pos': 8000, 'buf': 12000, 'dur': 30000});
      expect(player.state.duration, Duration.zero);
      expect(player.state.position, const Duration(seconds: 8));
      await player.dispose();
    });

    test('formats fill the size, tracks, HDR and 播放信息\'s facts', () async {
      final bridge = _Bridge();
      final player = await TvExoPlayer.create(isLive: () => false);
      await player.open(const Media(_videoUrl));
      await bridge.send('videoSize', {'w': 3840, 'h': 2160});
      await bridge.send('videoFormat', {
        'mime': 'video/hevc',
        'codecs': 'hvc1.2.4.L153.90',
        'decoder': 'c2.mtk.hevc.decoder',
        'width': 3840,
        'height': 2160,
        'frameRate': 59.94,
        'hdr': 'hdr10',
      });
      await bridge.send('audioFormat', {
        'mime': 'audio/mp4a-latm',
        'codecs': 'mp4a.40.2',
        'decoder': 'c2.android.aac.decoder',
        'sampleRate': 48000,
        'channels': 2,
      });
      await bridge.send('firstFrame', {'ms': 640});
      await bridge.send('dropped', {'count': 3});
      await bridge.send('frameRate', {'fps': 59.9});

      expect(player.state.width, 3840);
      expect(player.state.height, 2160);
      expect(player.videoSize.value, const Size(3840, 2160));
      expect(player.state.videoParams.primaries, 'bt.2020');
      expect(player.state.videoParams.gamma, 'pq');
      expect(player.state.track.video.codec, 'hvc1.2.4.L153.90');
      expect(player.state.track.video.decoder, 'c2.mtk.hevc.decoder');
      expect(player.state.track.audio.channelscount, 2);
      expect(player.state.audioParams.sampleRate, 48000);
      expect(player.getProperty('hwdec-current'), 'c2.mtk.hevc.decoder');

      final facts = player.facts;
      expect(facts.hdr, 'hdr10');
      expect(facts.frameRate, 59.94);
      expect(facts.measuredFps, 59.9);
      expect(facts.firstFrameMs, 640);
      expect(facts.dropped, 3);
      expect(facts.host, 'upos-sz-mirrorcos.bilivideo.com');
      expect(facts.audioPassthrough, isFalse);
      await expectLater(
        player.videoController.waitUntilFirstFrameRendered,
        completes,
      );

      // A later first frame (after a seek) doesn't replace the open's.
      await bridge.send('firstFrame', {'ms': 90});
      expect(facts.firstFrameMs, 640);
      // A new media clears them.
      await player.open(const Media('https://cdn/next.m4s'));
      expect(facts.videoDecoder, isNull);
      expect(facts.firstFrameMs, isNull);
      expect(player.videoSize.value, isNull);
      await player.dispose();
    });

    test('an encoded track with no decoder passes through', () {
      final facts = TvExoFacts()
        ..setAudio({'mime': 'audio/eac3-joc', 'channels': 6});
      expect(facts.audioPassthrough, isTrue);
      facts.setAudio({'mime': 'audio/flac', 'channels': 2});
      expect(facts.audioPassthrough, isFalse);
      facts.dispose();
    });

    test('Dolby Vision and HLG read as mpv would name them', () async {
      final bridge = _Bridge();
      final player = await TvExoPlayer.create(isLive: () => false);
      await player.open(const Media(_videoUrl));
      await bridge.send('videoSize', {'w': 3840, 'h': 2160});
      await bridge.send('videoFormat', {'hdr': 'dolbyVision', 'profile': 8});
      expect(player.state.videoParams.gamma, 'dolbyvision');
      expect(player.facts.dolbyVisionProfile, 8);
      await bridge.send('videoFormat', {'hdr': 'hlg'});
      expect(player.state.videoParams.gamma, 'hlg');
      await bridge.send('videoFormat', {'hdr': 'sdr'});
      expect(player.state.videoParams.primaries, isNull);
      expect(player.state.videoParams.gamma, isNull);
      await player.dispose();
    });

    test(
      'volume is mpv\'s cubic curve as a linear gain, capped at 100 %',
      () async {
        expect(TvExoPlayer.linearVolume(100), 1.0);
        expect(TvExoPlayer.linearVolume(50), closeTo(0.125, 1e-9));
        expect(TvExoPlayer.linearVolume(0), 0.0);
        expect(TvExoPlayer.linearVolume(300), 1.0);

        final bridge = _Bridge();
        final player = await TvExoPlayer.create(isLive: () => false);
        await player.setVolume(50);
        expect(bridge.argsOf('setVolume'), {'volume': 0.125});
        expect(player.getProperty('volume'), '50.000000');
        await player.setRate(1.5);
        expect(bridge.argsOf('setRate'), {'rate': 1.5});
        await player.dispose();
      },
    );

    test('听视频 turns the video track off and on; mpv\'s other properties '
        'and commands do nothing', () async {
      final bridge = _Bridge();
      final player = await TvExoPlayer.create(isLive: () => false);
      bridge.calls.clear();
      player
        ..setProperty('file-local-options/vid', 'no')
        ..setProperty('file-local-options/vid', 'auto')
        ..setProperty('af', 'lavfi=[loudnorm]')
        ..setOption('cache', 'yes');
      await player.command(['change-list', 'glsl-shaders', 'clr', '']);
      await pumpEventQueue();
      expect(bridge.methods, ['setVideoEnabled', 'setVideoEnabled']);
      expect([for (final c in bridge.calls) c.arguments], [false, true]);
      expect(await player.screenshot(), isNull);
      await player.dispose();
    });

    test('seeking: none in a live room, and a Hi-Res FLAC seek stops short '
        'of the end', () async {
      expect(
        TvExoPlayer.guardSeek(
          const Duration(seconds: 299),
          length: const Duration(seconds: 300),
          audioMime: 'audio/flac',
        ),
        const Duration(seconds: 297),
      );
      expect(
        TvExoPlayer.guardSeek(
          const Duration(seconds: 299),
          length: const Duration(seconds: 300),
          audioMime: 'audio/mp4a-latm',
        ),
        const Duration(seconds: 299),
      );
      expect(
        TvExoPlayer.guardSeek(
          const Duration(seconds: 2),
          length: const Duration(seconds: 1),
          audioMime: 'audio/flac',
        ),
        Duration.zero,
      );
      expect(
        TvExoPlayer.guardSeek(
          const Duration(seconds: -1),
          length: Duration.zero,
          audioMime: null,
        ),
        Duration.zero,
      );

      final bridge = _Bridge();
      var live = true;
      final player = await TvExoPlayer.create(isLive: () => live);
      await player.open(const Media('https://live/room.m3u8'));
      bridge.calls.clear();
      await player.seek(const Duration(seconds: 10));
      expect(bridge.methods, isEmpty);
      live = false;
      await player.open(const Media(_videoUrl));
      await bridge.state(_ended);
      expect(player.state.completed, isTrue);
      bridge.calls.clear();
      await player.seek(const Duration(seconds: 10));
      expect(bridge.argsOf('seek'), {'ms': 10000});
      expect(player.state.completed, isFalse);
      await player.dispose();
    });
  });

  group('retries and the failure screen', () {
    testWidgets('a video\'s network error retries 3 times, at 4, 6 and 10 s, '
        'from where it stopped, then shows the failure screen', (tester) async {
      final bridge = _Bridge();
      final player = await TvExoPlayer.create(isLive: () => false);
      final errors = _errors(player);
      await player.open(Media(_edl(_videoUrl, _audioUrl)));
      await bridge.state(_ready);
      await bridge.send('position', {
        'pos': 61000,
        'buf': 70000,
        'dur': 300000,
      });

      for (final (i, wait) in const [4, 6, 10].indexed) {
        await bridge.error('network', recoverable: true, code: 'IO_NETWORK');
        // While a retry waits the player reads as buffering, so upstream's
        // spinner shows.
        expect(player.state.buffering, isTrue, reason: 'retry ${i + 1}');
        expect(player.state.playing, isTrue);
        expect(player.failed.value, isNull);
        final opens = bridge.opens.length;
        await tester.pump(
          Duration(seconds: wait) - const Duration(milliseconds: 1),
        );
        expect(bridge.opens.length, opens, reason: 'too early ${i + 1}');
        await tester.pump(const Duration(milliseconds: 1));
        expect(bridge.opens.length, opens + 1, reason: 'retry ${i + 1}');
        expect(bridge.lastOpen['startMs'], 61000);
        expect(bridge.lastOpen['video'], _videoUrl);
      }
      await bridge.error('network', recoverable: true, code: 'IO_NETWORK');
      expect(player.failed.value, '视频链接打开失败（IO_NETWORK），已重试 3 次');
      expect(player.state.buffering, isFalse);
      expect(player.state.playing, isFalse);
      expect(bridge.methods.last, 'stop');
      await tester.pump(const Duration(seconds: 30));
      expect(bridge.opens.length, 4);

      // Each retry hands upstream the text it retries on; the end, text it
      // ignores, so only this player's screen shows.
      await tester.pump();
      expect(errors.where(_upstreamRetries), hasLength(3));
      expect(errors.last, startsWith('Cannot open (ExoPlayer): 视频链接打开失败'));
      expect(_upstreamIgnores(errors.last), isTrue);
      await player.dispose();
    });

    testWidgets('a stream that plays again earns a fresh budget', (
      tester,
    ) async {
      final bridge = _Bridge();
      final player = await TvExoPlayer.create(isLive: () => false);
      await player.open(const Media(_videoUrl));
      for (var round = 0; round < 3; round++) {
        for (var i = 0; i < TvExoPlayer.videoAttempts; i++) {
          await bridge.error('http', recoverable: true, status: 503);
          await tester.pump(const Duration(seconds: 10));
        }
        await bridge.state(_ready);
      }
      expect(player.failed.value, isNull);
      expect(bridge.opens.length, 1 + 3 * TvExoPlayer.videoAttempts);
      await player.dispose();
    });

    testWidgets('upstream\'s retry, the same media opened during a retry, '
        'counts against the budget; a new media starts afresh', (tester) async {
      final bridge = _Bridge();
      final player = await TvExoPlayer.create(isLive: () => false);
      const media = Media(_videoUrl);
      await player.open(media);
      for (var i = 0; i < TvExoPlayer.videoAttempts; i++) {
        await bridge.error('network', recoverable: true);
        // Upstream's refreshPlayer, 3 s in, before this player's own retry.
        await tester.pump(const Duration(seconds: 3));
        await player.open(media);
      }
      await bridge.error('network', recoverable: true);
      expect(player.failed.value, contains('已重试 3 次'));
      await tester.pump(const Duration(seconds: 30));

      await player.open(const Media('https://cdn/next.m4s'));
      expect(player.failed.value, isNull);
      await bridge.error('network', recoverable: true);
      expect(player.failed.value, isNull);
      await tester.pump(const Duration(seconds: 4));
      await player.dispose();
    });

    testWidgets('a seek while a retry waits moves where the retry opens', (
      tester,
    ) async {
      final bridge = _Bridge();
      final player = await TvExoPlayer.create(isLive: () => false);
      await player.open(const Media(_videoUrl));
      await bridge.send('position', {'pos': 5000, 'buf': 5000, 'dur': 300000});
      await bridge.error('network', recoverable: true);
      bridge.calls.clear();
      await player.seek(const Duration(seconds: 120));
      expect(bridge.methods, isEmpty);
      expect(player.state.position, const Duration(seconds: 120));
      await tester.pump(const Duration(seconds: 4));
      expect(bridge.lastOpen['startMs'], 120000);
      await player.dispose();
    });

    testWidgets('pause while a retry waits keeps it waiting, paused', (
      tester,
    ) async {
      final bridge = _Bridge();
      final player = await TvExoPlayer.create(isLive: () => false);
      await player.open(const Media(_videoUrl));
      await bridge.error('network', recoverable: true);
      bridge.calls.clear();
      await player.pause();
      expect(bridge.methods, isEmpty);
      expect(player.state.playing, isFalse);
      await tester.pump(const Duration(seconds: 4));
      expect(bridge.lastOpen['play'], isFalse);
      await player.dispose();
    });

    testWidgets('Select on the failure screen reopens on ExoPlayer where it '
        'stopped, with a fresh budget', (tester) async {
      final bridge = _Bridge();
      final player = await TvExoPlayer.create(isLive: () => false);
      await player.open(const Media(_videoUrl));
      await bridge.send('position', {
        'pos': 30000,
        'buf': 30000,
        'dur': 300000,
      });
      await bridge.error('decoder', code: 'DECODING_FAILED');
      expect(player.failed.value, '解码器出错（DECODING_FAILED），已停止播放');
      expect(player.state.playing, isFalse);
      final failedGen = bridge.lastOpen['gen'];

      // Upstream's play and pause toggle.
      await player.playOrPause();
      expect(player.failed.value, isNull);
      expect(bridge.lastOpen['gen'], isNot(failedGen));
      expect(bridge.lastOpen['startMs'], 30000);
      expect(bridge.lastOpen['play'], isTrue);
      for (var i = 0; i < TvExoPlayer.videoAttempts; i++) {
        await bridge.error('network', recoverable: true);
        await tester.pump(const Duration(seconds: 10));
      }
      expect(player.failed.value, isNull);
      await player.dispose();
    });

    testWidgets('a refusal or a decoder error ends at once, with no retry', (
      tester,
    ) async {
      final bridge = _Bridge();
      final player = await TvExoPlayer.create(isLive: () => false);
      await player.open(const Media(_videoUrl));
      await bridge.error(
        'unsupported',
        extra: {'codecs': 'av01.0.16M.08', 'width': 8192, 'height': 4320},
      );
      expect(
        player.failed.value,
        '此设备的解码器不支持该视频流（av01.0.16M.08 8192×4320），已停止播放',
      );
      await tester.pump(const Duration(seconds: 30));
      expect(bridge.opens, hasLength(1));
      // Late events from the failed open are dropped.
      await bridge.send('state', {
        'state': _ready,
        'playWhenReady': true,
      }, gen: bridge.lastOpen['gen']);
      expect(player.state.playing, isFalse);
      await player.dispose();
    });

    testWidgets('a 仍要尝试 open fails at once on a network error, and says '
        'it was a 仍要尝试', (tester) async {
      final bridge = _Bridge();
      final player = await TvExoPlayer.create(isLive: () => false);
      TvExoPlayer.tryAnywayNext = true;
      await player.open(const Media(_videoUrl));
      expect(bridge.lastOpen['tryAnyway'], isTrue);
      expect(TvExoPlayer.tryAnywayNext, isFalse);
      await bridge.error('network', recoverable: true, status: 404);
      expect(player.failed.value, '仍要尝试失败：视频链接打开失败（HTTP 404），已重试 3 次');
      await tester.pump(const Duration(seconds: 30));
      expect(bridge.opens, hasLength(1));
      // The retry from the failure screen isn't a 仍要尝试.
      await player.play();
      expect(bridge.lastOpen['tryAnyway'], isFalse);
      await player.dispose();
    });

    test('an open the bridge rejects ends on the failure screen, with '
        'nothing else opened', () async {
      final bridge = _Bridge(failOpen: true);
      final player = await TvExoPlayer.create(isLive: () => false);
      final errors = _errors(player);
      await player.open(const Media(_videoUrl));
      expect(player.failed.value, 'ExoPlayer 启动失败（no surface），已停止播放');
      expect(player.state.buffering, isFalse);
      expect(bridge.methods.last, 'stop');
      await pumpEventQueue();
      expect(errors.single, startsWith('Cannot open'));
      await player.dispose();
    });
  });

  group('a fresh play link (M17.11 review)', () {
    /// Hooks as a video page's HUD gives them; [fetch] stands in for
    /// 重载视频's re-query, which opens the new link.
    TvExoHudHooks hooks(Future<void> Function()? fetch) {
      final h = TvExoHudHooks(lowerQuality: () => null, refetch: () => fetch);
      TvExoPlayer.addHooks(h);
      addTearDown(() => TvExoPlayer.removeHooks(h));
      return h;
    }

    const fresh = Media('https://upos-sz-mirrorcos.bilivideo.com/v.m4s?e=2');

    testWidgets('after a video\'s retries, one fresh link instead of the '
        'failure screen', (tester) async {
      final bridge = _Bridge();
      final player = await TvExoPlayer.create(isLive: () => false);
      var fetched = 0;
      hooks(() async {
        fetched++;
        await player.open(fresh);
      });
      await player.open(const Media(_videoUrl));
      for (var i = 0; i < TvExoPlayer.videoAttempts; i++) {
        await bridge.error('http', recoverable: true, status: 502);
        await tester.pump(const Duration(seconds: 10));
      }
      // Through the ripper an expired link is the proxy's 502.
      await bridge.error('http', recoverable: true, status: 502);
      await tester.pump();
      expect(fetched, 1);
      expect(player.failed.value, isNull);
      expect(bridge.lastOpen['video'], fresh.uri);
      expect(player.state.buffering, isTrue);

      // The fresh link fails too: no second fetch before it has played.
      for (var i = 0; i < TvExoPlayer.videoAttempts; i++) {
        await bridge.error('http', recoverable: true, status: 502);
        await tester.pump(const Duration(seconds: 10));
      }
      await bridge.error('http', recoverable: true, status: 502);
      await tester.pump();
      expect(fetched, 1);
      expect(player.failed.value, contains('已重试 3 次'));
      await player.dispose();
    });

    testWidgets('a direct 403 fetches a fresh link at once', (tester) async {
      final bridge = _Bridge();
      final player = await TvExoPlayer.create(isLive: () => false);
      var fetched = 0;
      hooks(() async {
        fetched++;
        await player.open(fresh);
      });
      await player.open(const Media(_videoUrl));
      await bridge.error('http', recoverable: true, status: 403);
      await tester.pump();
      expect(fetched, 1);
      expect(bridge.opens, hasLength(2));
      expect(bridge.lastOpen['video'], fresh.uri);
      // It played: the next expiry may fetch again.
      await bridge.state(_ready);
      await bridge.error('http', recoverable: true, status: 403);
      await tester.pump();
      expect(fetched, 2);
      await player.dispose();
    });

    testWidgets('a fetch that opens nothing ends on the failure screen', (
      tester,
    ) async {
      final bridge = _Bridge();
      final player = await TvExoPlayer.create(isLive: () => false);
      hooks(() async => throw Exception('no network'));
      await player.open(const Media(_videoUrl));
      await bridge.error('http', recoverable: true, status: 403);
      await tester.pump();
      expect(player.failed.value, '视频链接打开失败（HTTP 403），已重试 3 次');
      expect(player.state.buffering, isFalse);
      await player.dispose();
    });

    testWidgets('Select after a network failure fetches a fresh link; after '
        'a decoder failure it reopens', (tester) async {
      final bridge = _Bridge();
      final player = await TvExoPlayer.create(isLive: () => false);
      var fetched = 0;
      hooks(() async {
        fetched++;
        await player.open(fresh);
      });
      await player.open(const Media(_videoUrl));
      await bridge.state(_ready);
      await bridge.error('decoder', code: 'DECODING_FAILED');
      await player.play();
      expect(fetched, 0);
      expect(bridge.lastOpen['video'], _videoUrl);

      // A fetch already spent on this open, then the failure screen.
      await bridge.error('http', recoverable: true, status: 403);
      await tester.pump();
      expect(fetched, 1);
      for (var i = 0; i <= TvExoPlayer.videoAttempts; i++) {
        await bridge.error('network', recoverable: true);
        await tester.pump(const Duration(seconds: 10));
      }
      expect(player.failed.value, isNotNull);
      await player.play();
      await tester.pump();
      expect(fetched, 2);
      expect(player.failed.value, isNull);
      await player.dispose();
    });

    testWidgets('no fetch in a live room, for a 仍要尝试, or without a page '
        'that can fetch', (tester) async {
      final bridge = _Bridge();
      var live = true;
      final player = await TvExoPlayer.create(isLive: () => live);
      var fetched = 0;
      hooks(() async => fetched++);
      await player.open(const Media('https://live/room.m3u8'));
      await bridge.error('http', recoverable: true, status: 403);
      await tester.pump(const Duration(seconds: 4));
      expect(fetched, 0);

      live = false;
      TvExoPlayer.tryAnywayNext = true;
      await player.open(const Media(_videoUrl));
      await bridge.error('http', recoverable: true, status: 403);
      await tester.pump();
      expect(fetched, 0);
      expect(player.failed.value, startsWith('仍要尝试失败'));

      hooks(null);
      await player.open(const Media('https://cdn/next.m4s'));
      await bridge.error('http', recoverable: true, status: 403);
      await tester.pump(const Duration(seconds: 4));
      expect(fetched, 0);
      expect(bridge.opens.last['video'], 'https://cdn/next.m4s');
      await player.dispose();
    });

    test('the newest page\'s hooks apply, and the one below takes over', () {
      ({String label, VoidCallback run}) option(String label) =>
          (label: label, run: () {});
      final video = TvExoHudHooks(
        lowerQuality: () => option('1080P'),
        refetch: () => null,
      );
      final live = TvExoHudHooks(
        lowerQuality: () => option('高清'),
        refetch: () => null,
      );
      TvExoPlayer.addHooks(video);
      TvExoPlayer.addHooks(live);
      expect(TvExoView.lowerQuality?.call()?.label, '高清');
      TvExoPlayer.removeHooks(live);
      expect(TvExoView.lowerQuality?.call()?.label, '1080P');
      TvExoPlayer.removeHooks(video);
      expect(TvExoView.lowerQuality, isNull);
    });
  });

  group('the video layer (M17.11 review)', () {
    testWidgets('a live room over a video page places the layer, and Back '
        'puts it back at the video page\'s box', (tester) async {
      final rects = <Object?>[];
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(_channel, (call) async {
            if (call.method == 'layerRect') rects.add(call.arguments);
            return null;
          });
      addTearDown(
        () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(_channel, null),
      );
      final player = await TvExoPlayer.create(isLive: () => false);
      final liveOn = ValueNotifier(false);
      addTearDown(liveOn.dispose);
      Widget box(double w) => SizedBox(
        width: w,
        height: w * 9 / 16,
        child: TvExoView(
          player: player,
          videoFit: VideoFitType.contain,
          alignment: Alignment.center,
        ),
      );
      tester.view
        ..physicalSize = const Size(1920, 1080)
        ..devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: ValueListenableBuilder<bool>(
            valueListenable: liveOn,
            builder: (_, on, _) => Stack(
              children: [
                // The video page stays mounted under the live room.
                Positioned(left: 0, top: 0, child: box(1166)),
                if (on) Positioned(left: 0, top: 0, child: box(1920)),
              ],
            ),
          ),
        ),
      );
      await tester.pump();
      const video = {'l': 0, 't': 0, 'w': 1166, 'h': 656};
      const room = {'l': 0, 't': 0, 'w': 1920, 'h': 1080};
      expect(rects.last, video);
      liveOn.value = true;
      await tester.pump();
      await tester.pump();
      expect(rects.last, room);
      // The video page's box, off screen, doesn't move the layer back.
      await tester.pump(const Duration(seconds: 2));
      expect(rects.last, room);
      liveOn.value = false;
      await tester.pump();
      await tester.pump();
      expect(rects.last, video);
      await tester.pumpWidget(const SizedBox());
      expect(rects.last, isNull);
      await player.dispose();
    });
  });

  group('live rooms', () {
    testWidgets('a live room reconnects 5 times, every 4 s, from the live '
        'edge, without upstream\'s endless retry, then fails', (tester) async {
      final bridge = _Bridge();
      final player = await TvExoPlayer.create(isLive: () => true);
      final errors = _errors(player);
      await player.open(const Media('https://live/room.m3u8?k=1'));
      await bridge.state(_ready);
      await bridge.send('position', {'pos': 50000, 'buf': 52000, 'dur': 0});
      for (var i = 0; i < TvExoPlayer.liveAttempts; i++) {
        await bridge.error('http', recoverable: true, status: 404);
        expect(player.state.buffering, isTrue);
        await tester.pump(const Duration(seconds: 4));
        expect(bridge.opens, hasLength(i + 2));
        expect(bridge.lastOpen['startMs'], 0);
        expect(bridge.lastOpen['live'], isTrue);
      }
      await bridge.error('http', recoverable: true, status: 404);
      expect(player.failed.value, '直播连接失败（HTTP 404），已重试 5 次');
      await tester.pump();
      expect(errors.where(_upstreamRetries), isEmpty);
      expect(errors.where((e) => e.startsWith('Failed to open')), isEmpty);
      await player.dispose();
    });

    testWidgets('a live stream that ends reconnects after 1 s, and not '
        'completed', (tester) async {
      final bridge = _Bridge();
      final player = await TvExoPlayer.create(isLive: () => true);
      await player.open(const Media('https://live/room.m3u8'));
      await bridge.state(_ready);
      await bridge.state(_ended);
      expect(player.state.completed, isFalse);
      expect(player.state.buffering, isTrue);
      await tester.pump(const Duration(seconds: 1));
      expect(bridge.opens, hasLength(2));
      // Each end that never plays again spends one try.
      for (var i = 1; i < TvExoPlayer.liveAttempts; i++) {
        await bridge.state(_ended);
        await tester.pump(const Duration(seconds: 1));
      }
      await bridge.state(_ended);
      expect(player.failed.value, '直播已断开，重连失败');
      await player.dispose();
    });

    test('a live room\'s buffer is 直播缓冲大小, or twice 缓冲大小 when it\'s 0, '
        'and 直播缓冲时长 with 0 for no limit', () async {
      final bridge = _Bridge();
      final player = await TvExoPlayer.create(isLive: () => true);
      await player.open(const Media('https://live/room.flv'));
      expect(bridge.lastOpen['bufferBytes'], 64 * 1024 * 1024);
      expect(bridge.lastOpen['bufferMs'], 0);
      expect(bridge.argsOf('setNormalization'), {'mode': 'off'});
      await GStorage.setting.putAll({
        SettingBoxKey.liveBufferSize: 0.0,
        SettingBoxKey.liveBufferSec: 20.0,
      });
      await player.open(const Media('https://live/room2.flv'));
      expect(bridge.lastOpen['bufferBytes'], 200 * 1024 * 1024);
      expect(bridge.lastOpen['bufferMs'], 20000);
      expect(bridge.lastOpen['hls'], isFalse);
      await player.dispose();
    });
  });

  group('error wording', () {
    String text(Map args, {bool live = false, bool exhausted = false}) =>
        TvExoPlayer.failureText(args, live: live, exhausted: exhausted);

    test('each kind the bridge sends has its own words', () {
      expect(
        text({'kind': 'unsupported', 'dolbyVision': true, 'profile': 7}),
        '此设备没有可播放该杜比视界视频（Profile 7）的解码器，已停止播放',
      );
      expect(
        text({'kind': 'unsupported', 'width': 7680, 'height': 4320}),
        '此设备的解码器不支持该视频流（未知编码 7680×4320），已停止播放',
      );
      expect(
        text({'kind': 'format', 'code': 'PARSING_CONTAINER_MALFORMED'}),
        '无法解析该视频流（PARSING_CONTAINER_MALFORMED），已停止播放',
      );
      expect(text({'kind': 'decoder'}), '解码器出错（decoder），已停止播放');
      expect(
        text({'kind': 'audio', 'code': 'AUDIO_TRACK_INIT_FAILED'}),
        '音频输出出错（AUDIO_TRACK_INIT_FAILED），已停止播放',
      );
      expect(text({'kind': 'ended'}, live: true), '直播已断开，重连失败');
      expect(text({'kind': 'other'}), 'ExoPlayer 播放失败（other），已停止播放');
    });

    test('an HTTP status is named before the code, and a spent budget says '
        'how many tries', () {
      expect(
        text({'kind': 'http', 'status': 403, 'code': 'IO_BAD_HTTP_STATUS'}),
        'ExoPlayer 播放失败（HTTP 403），已停止播放',
      );
      expect(
        text({'kind': 'http', 'status': 403}, exhausted: true),
        '视频链接打开失败（HTTP 403），已重试 ${TvExoPlayer.videoAttempts} 次',
      );
      expect(
        text({'kind': 'behindLiveWindow'}, live: true, exhausted: true),
        '直播连接失败（behindLiveWindow），已重试 ${TvExoPlayer.liveAttempts} 次',
      );
    });

    test('retries wait 4, 6 and 10 s for a video and 4 s for a live room, '
        'after upstream\'s own 3 s retry', () {
      expect(
        [for (var a = 1; a <= 4; a++) TvExoPlayer.retryDelay(a, live: false)],
        const [
          Duration(seconds: 4),
          Duration(seconds: 6),
          Duration(seconds: 10),
          Duration(seconds: 10),
        ],
      );
      expect(TvExoPlayer.retryDelay(5, live: true), const Duration(seconds: 4));
      expect(
        _upstreamRetries(TvExoPlayer.retryErrorText(_videoUrl)),
        isTrue,
      );
      expect(
        _upstreamRetries(
          TvExoPlayer.retryErrorText('http://127.0.0.1:41234/v.m4s'),
        ),
        isTrue,
      );
      expect(_upstreamIgnores(TvExoPlayer.failureErrorText('x')), isTrue);
    });
  });

  group('subtitles', () {
    test('WebVTT cues, with ids, settings, notes, tags and entities', () {
      final cues = TvExoCues.parse(
        '﻿WEBVTT - 中文\n'
        'Kind: captions\n'
        '\n'
        'NOTE a comment\n'
        'that runs on\n'
        '\n'
        'STYLE\n'
        '::cue { color: yellow }\n'
        '\n'
        '1\n'
        '00:00:01.000 --> 00:00:03.500 line:90% align:center\n'
        '<v 主播>你好</v> &amp; <b>欢迎</b>\n'
        '\n'
        '00:02.000 --> 00:04.000\n'
        '第二行\n'
        '有两行\n'
        '\n'
        '00:00:05,250 --> 00:00:06,000\n'
        'SRT 风格 &lt;逗号&gt;\n'
        '00:00:07.000 --> 00:00:08.000\n'
        '没有空行也是新的一条\n'
        '\n'
        '00:00:09.000 --> 00:00:09.000\n'
        '零长度，丢弃\n'
        '\n'
        '00:00:10.000 --> 00:00:11.000\n'
        '<c.x></c>\n',
      );
      expect(cues.cues, hasLength(4));
      String at(int ms) => cues.textAt(Duration(milliseconds: ms));
      expect(at(500), '');
      expect(at(1000), '你好 & 欢迎');
      expect(at(2500), '你好 & 欢迎\n第二行\n有两行');
      expect(at(3500), '第二行\n有两行');
      expect(at(4000), '');
      expect(at(5300), 'SRT 风格 <逗号>');
      expect(at(7500), '没有空行也是新的一条');
      expect(at(9000), '');
      expect(at(10500), '');
    });

    test('a long cue still shows beside many short ones after it', () {
      final buffer = StringBuffer(
        'WEBVTT\n\n00:00:00.000 --> 00:10:00.000\n长\n\n',
      );
      for (var i = 1; i < 200; i++) {
        buffer
          ..write('00:00:${(i ~/ 4).toString().padLeft(2, '0')}.')
          ..write('${(i % 4) * 250}'.padLeft(3, '0'))
          ..write(' --> 00:00:59.999\n短 $i\n\n');
      }
      final cues = TvExoCues.parse(buffer.toString());
      expect(cues.textAt(const Duration(minutes: 5)), '长');
      expect(
        cues.textAt(const Duration(milliseconds: 500)).split('\n'),
        ['长', '短 1', '短 2'],
      );
    });

    test(
      'a subtitle track\'s text follows the position, and 关闭 clears it',
      () async {
        final bridge = _Bridge();
        final player = await TvExoPlayer.create(isLive: () => false);
        await player.open(const Media(_videoUrl));
        final shown = <String>[];
        final sub = player.stream.subtitle.listen((s) => shown.add(s.first));
        await player.setSubtitleTrack(
          const SubtitleTrack(
            'memory://WEBVTT\n\n00:00:01.000 --> 00:00:02.000\n第一句\n\n'
                '00:00:03.000 --> 00:00:04.000\n第二句\n',
            '中文',
            'zh-Hans',
            uri: true,
          ),
        );
        expect(player.state.track.subtitle.language, 'zh-Hans');
        for (final ms in [500, 1200, 1800, 2500, 3100]) {
          await bridge.send('position', {'pos': ms, 'buf': ms, 'dur': 300000});
        }
        expect(player.state.subtitle.first, '第二句');
        await player.setSubtitleTrack(SubtitleTrack.no());
        expect(player.state.subtitle.first, '');
        await pumpEventQueue();
        expect(shown, ['第一句', '', '第二句', '']);
        await sub.cancel();
        await player.dispose();
      },
    );

    test('a new media drops the old cues', () async {
      final bridge = _Bridge();
      final player = await TvExoPlayer.create(isLive: () => false);
      await player.open(const Media(_videoUrl));
      await player.setSubtitleTrack(
        const SubtitleTrack(
          'memory://WEBVTT\n\n00:00:00.000 --> 00:01:00.000\n旧的\n',
          null,
          null,
          uri: true,
        ),
      );
      expect(player.state.subtitle.first, '旧的');
      await player.open(const Media('https://cdn/next.m4s'));
      await bridge.send('position', {'pos': 1000, 'buf': 1000, 'dur': 300000});
      expect(player.state.subtitle.first, '');
      await player.dispose();
    });

    test('subtitle sources: memory, a file, and none', () async {
      expect(await TvExoPlayer.loadSubtitle('no'), isNull);
      expect(await TvExoPlayer.loadSubtitle('auto'), isNull);
      expect(await TvExoPlayer.loadSubtitle('memory://WEBVTT'), 'WEBVTT');
      final file = File('${tempDir.path}/字幕.vtt')
        ..writeAsStringSync('WEBVTT\n');
      expect(await TvExoPlayer.loadSubtitle(file.path), 'WEBVTT\n');
      expect(await TvExoPlayer.loadSubtitle(file.uri.toString()), 'WEBVTT\n');
      expect(
        await TvExoPlayer.loadSubtitle('${tempDir.path}/none.vtt'),
        isNull,
      );
    });
  });

  group('the buffer mapping', () {
    test('MB to bytes and seconds to ms, with 0 or less for no cap and no '
        'clamp', () {
      expect(
        TvExoBuffer.resolve(
          live: false,
          bufferSizeMb: 100,
          bufferSec: 180,
          liveBufferSizeMb: 64,
          liveBufferSec: 0,
        ),
        (bytes: 100 * 1024 * 1024, ms: 180000),
      );
      expect(
        TvExoBuffer.resolve(
          live: false,
          bufferSizeMb: 0.5,
          bufferSec: 2.5,
          liveBufferSizeMb: 0,
          liveBufferSec: 0,
        ),
        (bytes: 524288, ms: 2500),
      );
      expect(
        TvExoBuffer.resolve(
          live: false,
          bufferSizeMb: 0,
          bufferSec: -1,
          liveBufferSizeMb: 0,
          liveBufferSec: 0,
        ),
        (bytes: 0, ms: 0),
      );
      expect(
        TvExoBuffer.resolve(
          live: false,
          bufferSizeMb: 4096,
          bufferSec: 3600,
          liveBufferSizeMb: 0,
          liveBufferSec: 0,
        ),
        (bytes: 4096 * 1024 * 1024, ms: 3600000),
      );
      expect(
        TvExoBuffer.resolve(
          live: true,
          bufferSizeMb: 100,
          bufferSec: 180,
          liveBufferSizeMb: 64,
          liveBufferSec: 30,
        ),
        (bytes: 64 * 1024 * 1024, ms: 30000),
      );
      expect(
        TvExoBuffer.resolve(
          live: true,
          bufferSizeMb: 4,
          bufferSec: 16,
          liveBufferSizeMb: 0,
          liveBufferSec: 0,
        ),
        (bytes: 8 * 1024 * 1024, ms: 0),
      );
    });
  });

  group('the normalization mapping', () {
    // Upstream's mpv filter for a video measured at -20 LUFS.
    const filter =
        'lavfi=[loudnorm=I=-16:LRA=11:TP=-1.5:measured_I=-20:measured_LRA=7:'
        'measured_TP=-3:measured_thresh=-30:offset=0.5:linear=true]';

    test('what each setting sends the bridge', () {
      Map<String, Object> send(String config, {String fallback = '0'}) =>
          TvExoNormalization.resolve(
            config: config,
            fallback: fallback,
            filter: filter,
          ).toArgs();

      expect(send('0'), {'mode': 'off'});
      expect(send(TvExoNormalization.standard), {
        'mode': 'loudness',
        'gainDb': 6.0,
        'ceilingDb': -1.0,
      });
      expect(send(TvExoNormalization.highDynamic), {
        'mode': 'loudness',
        'gainDb': -4.0,
        'ceilingDb': -1.0,
      });
      // 预设 loudnorm, stored before M17.9: toward its -16 LUFS.
      expect(send('2'), {'mode': 'loudness', 'gainDb': 4.0, 'ceilingDb': -1.5});
      expect(send('1'), {
        'mode': 'dynamic',
        'frameMs': 250,
        'window': 5,
        'targetRms': 0.9,
        'peak': 0.5,
        'maxGain': 10.0,
      });
      expect(AudioNormalization.dynaudnorm.param, contains('g=5:f=250'));
      expect(send('volume=2'), {'mode': 'off'});
    });

    test('预设 loudnorm with no measurement takes upstream\'s fallback', () {
      TvExoNormalization resolve(String fallback) => TvExoNormalization.resolve(
        config: '2',
        fallback: fallback,
        filter: 'lavfi=[loudnorm=I=-16:LRA=11:TP=-1.5]',
      );
      expect(resolve('0'), const TvExoNormalization.off());
      expect(resolve('1').mode, 'dynamic');
    });

    test('a live room is never balanced; a video needs no filter for '
        '动态压缩, and its measured loudness alone for 标准', () {
      expect(
        TvExoNormalization.resolve(
          config: '1',
          fallback: '0',
          filter: filter,
          live: true,
        ),
        const TvExoNormalization.off(),
      );
      expect(
        TvExoNormalization.resolve(
          config: '1',
          fallback: '0',
          filter: null,
          live: false,
        ).mode,
        'dynamic',
      );
      expect(
        TvExoNormalization.resolve(
          config: TvExoNormalization.standard,
          fallback: '0',
          filter: null,
          measured: -18,
          live: false,
        ),
        const TvExoNormalization.loudness(4, -1),
      );
      // Without `live`, no filter means off (the setting's own preview).
      expect(
        TvExoNormalization.resolve(config: '1', fallback: '0', filter: null),
        const TvExoNormalization.off(),
      );
    });

    test('the open sends the measured loudness from the media\'s extras, '
        'and the HUD\'s change goes out without reopening', () async {
      final bridge = _Bridge();
      final player = await TvExoPlayer.create(isLive: () => false);
      await GStorage.setting.put(
        SettingBoxKey.audioNormalization,
        TvExoNormalization.standard,
      );
      await player.open(
        Media(
          _edl(_videoUrl, _audioUrl),
          extras: const {TvExoNormalization.loudnessKey: '-17.5'},
        ),
      );
      expect(bridge.argsOf('setNormalization'), {
        'mode': 'loudness',
        'gainDb': 3.5,
        'ceilingDb': -1.0,
      });
      await GStorage.setting.put(SettingBoxKey.audioNormalization, '1');
      bridge.calls.clear();
      final sent = await player.applyNormalization();
      expect(sent?.mode, 'dynamic');
      expect(bridge.methods, ['setNormalization']);
      await player.dispose();
      expect(await player.applyNormalization(), isNull);
    });

    test('the loudness extra is only added on TV', () {
      TvPlatform.setTvModeForTesting(false);
      expect(TvExoNormalization.loudnessExtras(null), isEmpty);
    });
  });

  group('audio support', () {
    test('asks the bridge once per codec and caches the answer', () async {
      final asked = <List>[];
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(_channel, (call) async {
            if (call.method != 'audioSupport') return null;
            final codecs = call.arguments as List;
            asked.add(codecs);
            return [
              for (final c in codecs) c == 'ec-3' ? 'passthrough' : 'decode',
            ];
          });
      addTearDown(
        () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(_channel, null),
      );
      expect(
        await TvExoPlayer.audioSupport(['ec-3', 'mp4a.40.2', null]),
        ['passthrough', 'decode', null],
      );
      expect(await TvExoPlayer.audioSupport(['mp4a.40.2', 'ec-3']), [
        'decode',
        'passthrough',
      ]);
      expect(asked, [
        ['ec-3', 'mp4a.40.2'],
      ]);
    });
  });

  group('dispose', () {
    test('a disposed player answers nothing and sends nothing', () async {
      final bridge = _Bridge();
      final player = await TvExoPlayer.create(isLive: () => false);
      await player.open(const Media(_videoUrl));
      final gen = bridge.lastOpen['gen'] as int;
      await player.dispose();
      expect(bridge.methods.last, 'dispose');
      bridge.calls.clear();
      await bridge.send('position', {
        'pos': 9000,
        'buf': 9000,
        'dur': 300000,
      }, gen: gen);
      expect(player.state.position, Duration.zero);
      expect(bridge.methods, isEmpty);
      expect(
        () => player.open(const Media(_videoUrl)),
        throwsA(isA<AssertionError>()),
      );
    });
  });
}

int utf8Length(String s) => const Utf8Encoder().convert(s).length;

/// Any player that isn't ExoPlayer.
class _NotExo extends Fake implements Player {}
