// The TV's player on Dart's side (docs/tv/PLAN.md, M17.8): Media3 ExoPlayer
// behind media_kit's player interface, so `PlPlayerController` drives it as
// it drives mpv. The Kotlin side is `TvExoPlayer.kt` (M17.7), on the channel
// `com.example.piliplus/tv_exo`; the view is `tv_exo_view.dart`.
//
// Upstream's files only reach this through `M17.9`'s hooks:
// `TvExoPlayer.create()` in place of `Player.create`, `videoControllerOf` in
// place of `VideoController.create`, and `TvExoView.of` before
// `SimpleVideo`. A failure never falls back to mpv (M17.6, decision 4): it
// ends on this player's failure screen, and Select retries on ExoPlayer.
import 'dart:async';
import 'dart:convert';
import 'dart:ffi' show Pointer, nullptr;
import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:PiliPlus/models/common/audio_normalization.dart';
import 'package:PiliPlus/models/video/play/url.dart' show Volume;
import 'package:PiliPlus/plugin/pl_player/controller.dart';
import 'package:PiliPlus/tv/tv_exo_subtitles.dart';
import 'package:PiliPlus/tv/tv_exo_support.dart';
import 'package:PiliPlus/tv/tv_platform.dart';
import 'package:PiliPlus/utils/storage_pref.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_smart_dialog/flutter_smart_dialog.dart';
import 'package:media_kit/generated/libmpv/bindings.dart' as generated;
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:synchronized/synchronized.dart';

class TvExoPlayer extends PlatformPlayer implements NativePlayer {
  TvExoPlayer._(this._isLive)
    : super(configuration: const PlayerConfiguration()) {
    completer.complete();
  }

  static const MethodChannel channel = MethodChannel(
    'com.example.piliplus/tv_exo',
  );

  /// The player the bridge serves. The bridge holds one Media3 player, so a
  /// player that's no longer the owner leaves the bridge alone on dispose.
  static TvExoPlayer? _owner;

  /// Generations of opens, across players, so a late event from an earlier
  /// open (or an earlier player) never lands on a later one.
  static int _gens = 0;

  /// Pixels a stream may have, sent with each open; 0 for no limit. The
  /// bridge refuses a larger stream during track selection. Device runs set
  /// 1920 × 1080 until the user's go-ahead for more.
  static int maxPixels = 0;

  /// 仍要尝试 (M17.10): the next open tries a stream past what its decoder
  /// declares, once, with no automatic retry; a failure ends on the failure
  /// screen. Cleared by that open.
  static bool tryAnywayNext = false;

  /// Whether [player] is this player, for the HUD's capabilities (M17.10)
  /// and the hooks that hide mpv's entries.
  static bool isExo(Player? player) => player is TvExoPlayer;

  /// mpv's entries (flip, 超分辨率, volume above 100 %) show only off this
  /// player; the hooks in upstream's 完整设置 ask this.
  static bool notExo(Player? player) => player is! TvExoPlayer;

  /// Logs this player's decisions with `[TvExoPlayer]`: opens, retries,
  /// failures, normalization and subtitles. On in debug builds; device runs
  /// turn it on. Stream URLs are cut at their query string.
  static bool log = kDebugMode;

  static void _log(String text) {
    if (log) debugPrint('[TvExoPlayer] $text');
  }

  /// What the HUD of the page on top offers: 降低画质 for the failure screen
  /// and a fresh play link. Pages stack (a live room over a video page), so
  /// the newest HUD's hooks apply, and the one below takes over when it goes.
  static final List<TvExoHudHooks> _hooks = [];

  static TvExoHudHooks? get hooks => _hooks.lastOrNull;

  static void addHooks(TvExoHudHooks h) => _hooks.add(h);

  static void removeHooks(TvExoHudHooks h) => _hooks.remove(h);

  static String _short(String? url) {
    if (url == null) return 'null';
    final q = url.indexOf('?');
    return q == -1 ? url : '${url.substring(0, q)}?…';
  }

  /// Automatic retries of a network failure before the failure screen; a
  /// stream that reaches READY earns a fresh budget.
  @visibleForTesting
  static const int videoAttempts = 3;
  @visibleForTesting
  static const int liveAttempts = 5;

  /// After upstream's own retry (3 s), so that one goes first when it runs.
  @visibleForTesting
  static Duration retryDelay(int attempt, {required bool live}) => live
      ? const Duration(seconds: 4)
      : Duration(seconds: const [4, 6, 10][(attempt - 1).clamp(0, 2)]);

  /// The text upstream's error handler matches for a retry of a network
  /// failure (`Failed to open https://…` or `http://127.0.0.1:…`).
  @visibleForTesting
  static String retryErrorText(String url) => 'Failed to open $url';

  /// Text upstream's error handler ignores silently ("Cannot open"), for a
  /// failure this player shows on its own screen.
  @visibleForTesting
  static String failureErrorText(String text) =>
      'Cannot open (ExoPlayer): $text';

  /// Makes the player. It never throws and never hands back mpv: if the
  /// bridge can't make its Media3 player, each open tries again and ends on
  /// the failure screen until it can (fail closed, M17.9).
  static Future<TvExoPlayer> create({bool Function()? isLive}) async {
    final player = TvExoPlayer._(
      isLive ?? () => PlPlayerController.instance?.isLive ?? false,
    );
    _owner = player;
    channel.setMethodCallHandler(player._onEvent);
    await player._createBridge();
    return player;
  }

  /// Whether the bridge holds a Media3 player for this one.
  bool _bridgeReady = false;

  Future<bool> _createBridge() async {
    try {
      await channel.invokeMethod<void>('create');
      _bridgeReady = true;
    } on PlatformException catch (e) {
      _log('create failed: ${e.message}');
      _bridgeError = e.message;
    }
    return _bridgeReady;
  }

  String? _bridgeError;

  /// `M17.9`'s hook in place of `VideoController.create`.
  static VideoController? videoControllerOf(Player player) =>
      player is TvExoPlayer ? player.videoController : null;

  final bool Function() _isLive;

  late final TvExoVideoController videoController = TvExoVideoController(
    this,
  );

  /// Why playback stopped for good, or `null`. The view shows it.
  final ValueNotifier<String?> failed = ValueNotifier<String?>(null);

  /// The decoded video's size, for the view's fitted rect.
  final ValueNotifier<Size?> videoSize = ValueNotifier<Size?>(null);

  /// What Media3 reports about the playing streams, for 播放信息 and the
  /// quality label (`M17.10`).
  final TvExoFacts facts = TvExoFacts();

  int _gen = 0;
  bool _live = false;
  int _exoState = _idle;
  bool _playWhenReady = false;
  bool _loading = false;
  String _url = '';
  Map<String, String> _headers = const <String, String>{};

  int _attempts = 0;
  Timer? _retryTimer;

  /// Fresh play links fetched since the stream last played, and whether one
  /// is being fetched. A video's signed link expires (after a long pause,
  /// say), and through the thread ripper that reads as a 502 from its
  /// loopback proxy, so retrying the same link can't help (M17.11 review).
  int _refetches = 0;
  bool _refetching = false;

  /// The error that last stopped playback, for Select on the failure screen.
  Map? _lastError;

  /// This open is a 仍要尝试: no automatic retry.
  bool _tryingAnyway = false;
  bool get tryingAnyway => _tryingAnyway;

  TvExoCues _cues = TvExoCues.empty;
  int _subtitleGen = 0;

  bool get isLive => _live;

  // Media3's playback states.
  static const int _idle = 1;
  static const int _buffering = 2;
  static const int _ready = 3;
  static const int _ended = 4;

  // ---- Events from Kotlin ----

  Future<void> _onEvent(MethodCall call) async {
    final args = call.arguments;
    if (disposed || args is! Map || args['gen'] != _gen) return;
    switch (call.method) {
      case 'state':
        _onState(args);
      case 'position':
        _onPosition(args);
      case 'videoSize':
        final int w = args['w'], h = args['h'];
        if (w <= 0 || h <= 0) return;
        state
          ..width = w
          ..height = h
          ..videoParams = _videoParams(w, h);
        videoParamsController.add(state.videoParams);
        sizeController.add((w, h));
        videoSize.value = Size(w.toDouble(), h.toDouble());
        videoController.rect.value = Rect.fromLTWH(
          0,
          0,
          w.toDouble(),
          h.toDouble(),
        );
      case 'videoFormat':
        facts.setVideo(args);
        state
          ..videoParams = _videoParams(state.width, state.height)
          ..track = state.track.copyWith(
            video: VideoTrack(
              'exo',
              null,
              null,
              codec: args['codecs'] ?? args['mime'],
              decoder: args['decoder'],
              w: args['width'],
              h: args['height'],
              fps: _positive(args['frameRate']),
              selected: true,
            ),
          );
        videoParamsController.add(state.videoParams);
        trackController.add(state.track);
      case 'audioFormat':
        facts.setAudio(args);
        state
          ..audioParams = AudioParams(
            format: args['mime'],
            sampleRate: args['sampleRate'],
            channelCount: args['channels'],
          )
          ..track = state.track.copyWith(
            audio: AudioTrack(
              'exo',
              null,
              null,
              codec: args['codecs'] ?? args['mime'],
              decoder: args['decoder'],
              samplerate: args['sampleRate'],
              channelscount: args['channels'],
              selected: true,
            ),
          );
        audioParamsController.add(state.audioParams);
        trackController.add(state.track);
      case 'firstFrame':
        facts.setFirstFrame(args['ms']);
        videoController.markFirstFrame();
      case 'dropped':
        facts.setDropped(args['count']);
      case 'frameRate':
        facts.setMeasuredFps(_positive(args['fps']));
      case 'tracks':
        if ((args['audioTracks'] ?? 0) > 0 && args['audioSelected'] == 0) {
          SmartDialog.showToast('此音轨无法在当前音频输出上播放');
        }
      case 'error':
        _onError(args);
    }
  }

  void _onState(Map args) {
    _exoState = args['state'];
    _playWhenReady = args['playWhenReady'];
    _loading = args['loading'] ?? false;
    if (_exoState == _ready) {
      // Playing again: the next failure gets the whole budget.
      _attempts = 0;
      _refetches = 0;
    } else if (_exoState == _ended && _live && failed.value == null) {
      // A live stream that ends reconnects, as on mpv.
      _retryOrFail(
        const <String, Object?>{'kind': 'ended', 'recoverable': true},
        delay: const Duration(seconds: 1),
      );
      return;
    }
    _emitState();
  }

  void _onPosition(Map args) {
    final position = Duration(milliseconds: args['pos']);
    final buffer = Duration(milliseconds: args['buf']);
    // A live room has no length; HLS's window would only confuse the bar.
    final duration = _live
        ? Duration.zero
        : Duration(milliseconds: args['dur']);
    if (duration != state.duration && (duration > Duration.zero || _live)) {
      state.duration = duration;
      durationController.add(duration);
    }
    if (buffer != state.buffer) {
      state.buffer = buffer;
      bufferController.add(buffer);
    }
    if (position != state.position) {
      state.position = position;
      positionController.add(position);
    }
    _emitSubtitle(position);
  }

  /// mpv's meanings: `playing` is "play was asked for", with `buffering`
  /// beside it; ended and failed are not playing. While a retry waits, the
  /// player reads as buffering, so upstream's spinner shows and its own retry
  /// can run. Once failed, neither, so no spinner draws over the screen.
  void _emitState() {
    final retrying = _retryTimer != null || _refetching;
    final ok = failed.value == null;
    final active = _exoState == _buffering || _exoState == _ready;
    final playing = ok && _playWhenReady && (active || retrying);
    final buffering = ok && (_exoState == _buffering || retrying);
    final completed = ok && !_live && _exoState == _ended;
    if (state.playing != playing ||
        state.buffering != buffering ||
        state.completed != completed) {
      _log('playing=$playing buffering=$buffering completed=$completed');
    }
    if (state.buffering != buffering) {
      state.buffering = buffering;
      bufferingController.add(buffering);
    }
    if (state.playing != playing) {
      state.playing = playing;
      playingController.add(playing);
    }
    if (state.completed != completed) {
      state.completed = completed;
      completedController.add(completed);
    }
  }

  void _onError(Map args) {
    _log(
      'error ${args['kind']} ${args['code'] ?? ''} status=${args['status']}',
    );
    if (failed.value != null || _refetching) return;
    _lastError = args;
    if (args['recoverable'] == true) {
      // A direct 403 is a link the CDN refuses: the same link won't do.
      if (args['status'] == 403 && _canRefetch) {
        unawaited(_refetch(args));
        return;
      }
      _retryOrFail(args);
    } else {
      _fail(failureText(args, live: _live));
    }
  }

  /// Whether a fresh play link may be fetched now: a video (a live room
  /// reconnects), not a 仍要尝试, once until the stream plays again, and only
  /// where the page on top can fetch one.
  bool get _canRefetch =>
      !_live && !_tryingAnyway && _refetches == 0 && hooks?.refetch() != null;

  /// Fetches a fresh play link through the page (重载视频's path, which
  /// reopens at the position). If nothing opens from it, the failure screen.
  Future<void> _refetch(Map args) async {
    final fetch = hooks?.refetch();
    if (fetch == null) {
      _fail(failureText(args, live: _live, exhausted: true));
      return;
    }
    _refetches++;
    _cancelRetry();
    _refetching = true;
    failed.value = null;
    // The failing open's events are dropped from here on.
    _gen = ++_gens;
    final gen = _gen;
    unawaited(_invoke('stop'));
    _log(
      'refetch the play link after ${args['kind']} ${args['code'] ?? ''} '
      'status=${args['status']} at ${state.position.inMilliseconds} ms',
    );
    _emitState();
    try {
      await fetch();
    } catch (e) {
      _log('refetch failed: $e');
    }
    _refetching = false;
    if (disposed) return;
    if (_gen == gen && failed.value == null) {
      _fail(failureText(args, live: _live, exhausted: true));
    } else {
      _emitState();
    }
  }

  /// A bounded retry at the position playback stopped, or the failure
  /// screen once the budget is spent. A video's error also gives upstream
  /// the text it retries on (from position 0 only, at most every 10 s),
  /// which opens the same media on this player and counts as the retry. A
  /// live room's doesn't: upstream retries those every 3 s with no limit, so
  /// the adapter reconnects them alone.
  void _retryOrFail(Map args, {Duration? delay}) {
    final budget = _live ? liveAttempts : videoAttempts;
    if (_attempts >= budget || _tryingAnyway) {
      // A video's link may have expired: one fresh link before giving up.
      if (_canRefetch) {
        unawaited(_refetch(args));
        return;
      }
      _fail(failureText(args, live: _live, exhausted: true));
      return;
    }
    _attempts++;
    _log(
      'retry $_attempts/$budget after ${args['kind']} ${args['code'] ?? ''} '
      'status=${args['status']} at ${state.position.inMilliseconds} ms',
    );
    _retryTimer?.cancel();
    _retryTimer = Timer(
      delay ?? retryDelay(_attempts, live: _live),
      _retry,
    );
    _emitState();
    if (!_live && _url.startsWith('http')) {
      errorController.add(retryErrorText(_url));
    }
  }

  void _retry() {
    _retryTimer = null;
    if (disposed || current.isEmpty) return;
    unawaited(
      _openMedia(current.last, play: _playWhenReady, at: state.position),
    );
  }

  void _cancelRetry() {
    _retryTimer?.cancel();
    _retryTimer = null;
  }

  void _fail(String text) {
    // A 仍要尝试 that failed says so: the decoder was asked past what it
    // declares.
    if (_tryingAnyway) text = '仍要尝试失败：$text';
    _log('failed: $text');
    _cancelRetry();
    failed.value = text;
    _emitState();
    errorController.add(failureErrorText(text));
    // The bridge's player is idle after an error; this also stops one that
    // reported a refusal. Its events are dropped from here on.
    _gen = ++_gens;
    unawaited(_invoke('stop'));
  }

  /// The failure screen's text, by the bridge's error kinds.
  @visibleForTesting
  static String failureText(
    Map args, {
    required bool live,
    bool exhausted = false,
  }) {
    final kind = args['kind'];
    final code = args['code'];
    final status = args['status'];
    final detail = status != null ? 'HTTP $status' : (code ?? kind);
    if (kind == 'unsupported' && args['reason'] is Map) {
      final rate = args['frameRate'];
      final refusal = TvExoRefusal.fromBridge(
        args['reason'] as Map,
        TvExoStream(
          codecs: args['codecs'] as String?,
          width: args['width'] as int?,
          height: args['height'] as int?,
          frameRate: rate is num && rate > 0 ? rate.toDouble() : null,
        ),
      );
      return '无法播放：${refusal.short}\n${refusal.detail}';
    }
    return switch (kind) {
      'unsupported' when args['dolbyVision'] == true =>
        '此设备没有可播放该杜比视界视频（Profile ${args['profile']}）的解码器，已停止播放',
      'unsupported' =>
        '此设备的解码器不支持该视频流（${args['codecs'] ?? '未知编码'} '
            '${args['width']}×${args['height']}），已停止播放',
      'format' => '无法解析该视频流（$detail），已停止播放',
      'decoder' => '解码器出错（$detail），已停止播放',
      'audio' => '音频输出出错（$detail），已停止播放',
      'ended' => '直播已断开，重连失败',
      _ when exhausted && live => '直播连接失败（$detail），已重试 $liveAttempts 次',
      _ when exhausted => '视频链接打开失败（$detail），已重试 $videoAttempts 次',
      _ => 'ExoPlayer 播放失败（$detail），已停止播放',
    };
  }

  // ---- What PlPlayerController calls ----

  @override
  Future<void> open(
    Playable playable, {
    bool play = true,
    bool synchronized = true,
  }) async {
    throwIfDisposed();
    final media = switch (playable) {
      Media() => playable,
      Playlist() => playable.medias[playable.index],
    };
    final same = current.isNotEmpty && current.last.uri == media.uri;
    // Upstream's retry (refreshPlayer) opens the same media during a retry:
    // the budget holds, so retries stay bounded. A new media, or the same one
    // reopened from the failure screen (重载视频; upstream's own retry never
    // runs then, since a failed player isn't buffering), starts afresh.
    if (!same || failed.value != null) _attempts = 0;
    _cancelRetry();
    current
      ..clear()
      ..add(media);
    state.playlist = Playlist([media]);
    playlistController.add(state.playlist);
    if (!same) {
      _cues = TvExoCues.empty;
      _subtitleGen++;
      _emitSubtitle(Duration.zero);
      state.duration = Duration.zero;
      durationController.add(Duration.zero);
      videoSize.value = null;
      facts.clear();
    }
    await _openMedia(media, play: play);
  }

  Future<void> _openMedia(
    Media media, {
    required bool play,
    Duration? at,
  }) async {
    final (video, audio) = splitEdl(media.uri);
    _live = _isLive();
    _url = video;
    _gen = ++_gens;
    _tryingAnyway = tryAnywayNext && !_live;
    tryAnywayNext = false;
    // Media3 buffers once prepared. The earlier open's events are dropped
    // from here on, a pause among them, so the state is set here, as mpv's
    // properties change at once: a page that waits for "playing" (the live
    // room starts its danmaku then) sees not playing, then playing.
    _exoState = _buffering;
    _playWhenReady = play;
    _loading = true;
    failed.value = null;
    final start = _live ? Duration.zero : (at ?? media.start ?? Duration.zero);
    state
      ..position = start
      ..buffer = start;
    positionController.add(start);
    bufferController.add(start);
    _emitState();
    facts.setSource(video, live: _live, hls: _isHls(video));
    final buffer = TvExoBuffer.resolve(
      live: _live,
      bufferSizeMb: Pref.bufferSize,
      bufferSec: Pref.bufferSec,
      liveBufferSizeMb: Pref.liveBufferSize,
      liveBufferSec: Pref.liveBufferSec,
    );
    final normalization = _normalization(media);
    _log(
      'open gen=$_gen live=$_live hls=${_isHls(video)} play=$play '
      'start=${start.inMilliseconds} attempt=$_attempts '
      'buffer=${buffer.bytes}B/${buffer.ms}ms $normalization '
      'video=${_short(video)} audio=${_short(audio)}',
    );
    if (!_bridgeReady && !await _createBridge()) {
      _fail('ExoPlayer 启动失败（$_bridgeError），已停止播放');
      return;
    }
    try {
      await channel.invokeMethod<void>(
        'setNormalization',
        normalization.toArgs(),
      );
      await channel.invokeMethod<void>('open', <String, Object?>{
        'video': video,
        'audio': audio,
        'live': _live,
        'hls': _isHls(video),
        'startMs': start.inMilliseconds,
        'play': play,
        'gen': _gen,
        'headers': _headers,
        'bufferBytes': buffer.bytes,
        'bufferMs': buffer.ms,
        'maxPixels': maxPixels,
        'tryAnyway': _tryingAnyway,
      });
    } on PlatformException catch (e) {
      // Fail closed: nothing else opens this media.
      _fail('ExoPlayer 启动失败（${e.message}），已停止播放');
    }
  }

  TvExoNormalization _normalization(Media media) => TvExoNormalization.resolve(
    config: Pref.audioNormalization,
    fallback: Pref.fallbackNormalization,
    filter: media.extras?['lavfi-complex'],
    measured: double.tryParse(
      media.extras?[TvExoNormalization.loudnessKey] ?? '',
    ),
    live: _live,
  );

  /// 音量均衡 changed during playback (the HUD's entry, M17.10): the bridge's
  /// audio processors take the new setting on their next buffer, without
  /// reopening. Returns what was sent, or `null` with nothing open.
  Future<TvExoNormalization?> applyNormalization() async {
    if (current.isEmpty || disposed) return null;
    final normalization = _normalization(current.last);
    _log('normalization now $normalization');
    await _invoke('setNormalization', normalization.toArgs());
    return normalization;
  }

  static final Map<String, String> _audioSupport = {};

  /// For each audio stream's `codecs` (音质, M17.10): `passthrough`,
  /// `decode` or `no`, from the bridge's `audioSupport`, cached for the run;
  /// `null` for a stream it couldn't answer.
  static Future<List<String?>> audioSupport(List<String?> codecs) async {
    final ask = {
      for (final c in codecs)
        if (c != null && !_audioSupport.containsKey(c)) c,
    }.toList();
    if (ask.isNotEmpty) {
      try {
        final answer =
            await channel.invokeMethod<List>('audioSupport', ask) ?? const [];
        for (final (i, c) in ask.indexed) {
          if (answer.elementAtOrNull(i) case final String a) {
            _audioSupport[c] = a;
          }
        }
      } on PlatformException catch (e) {
        _log('audioSupport failed: ${e.message}');
      } on MissingPluginException {
        // No bridge (tests).
      }
    }
    return [for (final c in codecs) c == null ? null : _audioSupport[c]];
  }

  static bool _isHls(String url) =>
      Uri.tryParse(url)?.path.endsWith('.m3u8') ?? false;

  /// `edl://!no_chapters;%<len>%<video>;!new_stream;!no_chapters;%<len>%<audio>`
  /// back into its two URLs. The lengths are in bytes for files and in
  /// characters for URLs, which are ASCII, so bytes serve for both. The
  /// audio is the first part after `!new_stream`. Anything else is a single
  /// URL (a live room, 听视频, a video with no audio). An old multi-part
  /// video (`durl`, parts in sequence with no `!new_stream`) plays its first
  /// part only (M17.11).
  @visibleForTesting
  static (String, String?) splitEdl(String uri) {
    const prefix = 'edl://';
    if (!uri.startsWith(prefix)) return (uri, null);
    final bytes = utf8.encode(uri.substring(prefix.length));
    final newStream = utf8.encode('!new_stream');
    String? video, audio;
    var streams = 0;
    var i = 0;
    while (i < bytes.length) {
      if (bytes[i] == 0x25) {
        final end = bytes.indexOf(0x25, i + 1);
        final length = int.parse(ascii.decode(bytes.sublist(i + 1, end)));
        final part = utf8.decode(bytes.sublist(end + 1, end + 1 + length));
        if (streams == 0) {
          video ??= part;
        } else if (streams == 1) {
          audio ??= part;
        }
        i = end + 1 + length;
      } else {
        final end = bytes.indexOf(0x3B, i);
        final stop = end == -1 ? bytes.length : end;
        if (listEquals(bytes.sublist(i, stop), newStream)) streams++;
        i = stop + 1;
        continue;
      }
      // Past the part's own options (`,length=…`) to the next entry.
      final end = bytes.indexOf(0x3B, i);
      i = end == -1 ? bytes.length : end + 1;
    }
    if (video == null) return (uri, null);
    return (video, audio);
  }

  /// Plays; after a failure, retries on ExoPlayer (Select on the failure
  /// screen reaches here through upstream's play and pause toggle).
  @override
  Future<void> play({bool synchronized = true}) async {
    if (failed.value != null || _retryTimer != null) {
      final error = failed.value != null ? _lastError : null;
      _attempts = 0;
      _cancelRetry();
      if (current.isEmpty) return;
      // A network failure: try a fresh link, which an expired one needs.
      if (error != null && error['recoverable'] == true) {
        _refetches = 0;
        if (_canRefetch) return _refetch(error);
      }
      return _openMedia(current.last, play: true, at: state.position);
    }
    // Reported at once, as mpv's `pause` property changes at once; the
    // bridge's state event confirms it.
    _playWhenReady = true;
    _emitState();
    await _invoke('play');
  }

  @override
  Future<void> pause({bool synchronized = true}) async {
    _playWhenReady = false;
    _emitState();
    if (_retryTimer != null) return;
    await _invoke('pause');
  }

  @override
  Future<void> playOrPause({bool notify = true, bool synchronized = true}) =>
      state.playing ? pause() : play();

  @override
  Future<void> seek(Duration duration, {bool synchronized = true}) async {
    if (_live) return;
    final to = guardSeek(
      duration,
      length: state.duration,
      audioMime: facts.audioMime,
    );
    if (state.completed) {
      state.completed = false;
      completedController.add(false);
    }
    if (failed.value != null || _retryTimer != null) {
      // The retry opens here.
      state.position = to;
      positionController.add(to);
      return;
    }
    await _invoke('seek', <String, Object>{'ms': to.inMilliseconds});
  }

  /// Media3 1.11.1 fails a seek into the last 2 s of a Hi-Res FLAC track
  /// (`M17.5`: `ERROR_CODE_FAILED_RUNTIME_CHECK` in the audio renderer), so
  /// such a seek lands [flacTailGuard] before the end, which leaves room for
  /// an audio track a little shorter than the video.
  @visibleForTesting
  static Duration guardSeek(
    Duration to, {
    required Duration length,
    required String? audioMime,
  }) {
    if (to < Duration.zero) return Duration.zero;
    if (audioMime != 'audio/flac' || length <= Duration.zero) return to;
    final latest = length - flacTailGuard;
    if (to <= latest) return to;
    return latest < Duration.zero ? Duration.zero : latest;
  }

  @visibleForTesting
  static const Duration flacTailGuard = Duration(seconds: 3);

  @override
  Future<void> setRate(double rate, {bool synchronized = true}) async {
    state.rate = rate;
    await _invoke('setRate', <String, Object>{'rate': rate});
  }

  @override
  Future<void> setVolume(double volume, {bool synchronized = true}) async {
    state.volume = volume;
    await _invoke('setVolume', <String, Object>{
      'volume': linearVolume(volume),
    });
  }

  /// mpv's volume, 0–100 on its cubic curve, as Media3's linear gain. Above
  /// 100 % isn't on this path (M17.6, decision 12).
  @visibleForTesting
  static double linearVolume(double volume) =>
      math.pow((volume / 100).clamp(0.0, 1.0), 3).toDouble();

  @override
  Future<void> stop({bool open = false, bool synchronized = true}) async {
    _cancelRetry();
    _gen = ++_gens;
    await _invoke('stop');
  }

  @override
  Future<void> dispose() async {
    throwIfDisposed();
    disposed = true;
    _cancelRetry();
    if (identical(_owner, this)) {
      channel.setMethodCallHandler(null);
      // While still the owner, so `_invoke` sends it: the bridge releases
      // Media3, which otherwise keeps loading (from a closed ripper proxy,
      // after a video page) until the next player is made.
      await _invoke('dispose');
      // A player made meanwhile is the owner now; leave it.
      if (identical(_owner, this)) _owner = null;
    }
    failed.dispose();
    videoSize.dispose();
    facts.dispose();
    await super.dispose();
  }

  /// A call to the bridge for this player only, and only while it's the
  /// bridge's. Errors are logged; the bridge's error events carry failures.
  Future<void> _invoke(String method, [Object? arguments]) async {
    if (!identical(_owner, this)) return;
    try {
      await channel.invokeMethod<void>(method, arguments);
    } on PlatformException catch (e) {
      _log('$method failed: ${e.message}');
    }
  }

  @override
  void setMediaHeader({
    String? userAgent,
    String? referer,
    Map<String, String>? headers,
  }) {
    _headers = <String, String>{
      ...?headers,
      'User-Agent': ?userAgent,
      'Referer': ?referer,
    };
  }

  /// The mpv properties `lib/` reads (M17.3's inventory).
  @override
  String getProperty(String property) => switch (property) {
    // The thread ripper's "caught up" signal (M17.2, decision 9).
    'demuxer-cache-idle' => _loading ? 'no' : 'yes',
    'hwdec-current' => facts.videoDecoder ?? '',
    'volume' => state.volume.toStringAsFixed(6),
    _ => '',
  };

  /// Only 听视频's video switch means anything here; the rest (`af`,
  /// `force-window`, `video-rotate`) are mpv's and have no ExoPlayer side.
  @override
  void setProperty(String property, String value) {
    if (property == 'file-local-options/vid') {
      unawaited(_invoke('setVideoEnabled', value != 'no'));
    }
  }

  @override
  void setOption(String opt, String value) {}

  /// mpv commands (the super-resolution shaders) aren't on this path.
  @override
  Future<void> command(List<String> args) async {}

  /// No screenshots on the video plane; both callers accept null.
  @override
  Future<ui.Image?> screenshot({bool synchronized = true}) async => null;

  // ---- Subtitles: cues from the VTT text the app already has ----

  /// `no`, `auto`, `memory://` and the VTT text, a file path, or a URL.
  @override
  Future<void> setSubtitleTrack(
    SubtitleTrack track, {
    bool synchronized = true,
  }) async {
    final gen = ++_subtitleGen;
    final text = await loadSubtitle(track.id);
    if (gen != _subtitleGen || disposed) return;
    _cues = text == null ? TvExoCues.empty : TvExoCues.parse(text);
    _log(
      'subtitle ${_short(track.id.split('\n').first)}: ${_cues.cues.length} cues',
    );
    state.track = state.track.copyWith(subtitle: track);
    trackController.add(state.track);
    _emitSubtitle(state.position, force: true);
  }

  @visibleForTesting
  static Future<String?> loadSubtitle(String id) async {
    const memory = 'memory://';
    if (id == 'no' || id == 'auto' || id.isEmpty) return null;
    if (id.startsWith(memory)) return id.substring(memory.length);
    try {
      if (id.startsWith('http://') || id.startsWith('https://')) {
        final client = HttpClient()
          ..connectionTimeout = const Duration(seconds: 10);
        try {
          final request = await client.getUrl(Uri.parse(id));
          final response = await request.close().timeout(
            const Duration(seconds: 15),
          );
          if (response.statusCode != HttpStatus.ok) return null;
          return await response.transform(utf8.decoder).join();
        } finally {
          client.close();
        }
      }
      final file = File(
        id.startsWith('file://') ? Uri.parse(id).toFilePath() : id,
      );
      return file.existsSync() ? await file.readAsString() : null;
    } catch (e) {
      _log('subtitle failed: $e');
      return null;
    }
  }

  void _emitSubtitle(Duration position, {bool force = false}) {
    if (!force && _cues.isEmpty && state.subtitle.first.isEmpty) return;
    final subtitle = Subtitle(_cues.textAt(position), '');
    if (subtitle == state.subtitle) return;
    state.subtitle = subtitle;
    subtitleController.add(subtitle);
  }

  // ---- Helpers ----

  VideoParams _videoParams(int w, int h) {
    final hdr = facts.hdr;
    return VideoParams(
      w: w,
      h: h,
      dw: w,
      dh: h,
      aspect: h > 0 ? w / h : null,
      primaries: hdr == null || hdr == 'sdr' ? null : 'bt.2020',
      gamma: switch (hdr) {
        'hdr10' => 'pq',
        'hlg' => 'hlg',
        'dolbyVision' => 'dolbyvision',
        _ => null,
      },
    );
  }

  static double? _positive(Object? value) =>
      value is num && value > 0 ? value.toDouble() : null;

  // ---- The rest of NativePlayer's interface ----

  @override
  Pointer<generated.mpv_handle> ctx = nullptr;

  @override
  bool disposed = false;

  @override
  bool isShuffleEnabled = false;

  @override
  bool isPlayingStateChangeAllowed = false;

  @override
  bool isBufferingStateChangeAllowed = true;

  @override
  final List<Media> current = <Media>[];

  @override
  final List<FutureOr<void> Function()> onLoadHooks = [];

  @override
  final List<FutureOr<void> Function()> onUnloadHooks = [];

  @override
  final Lock lock = Lock();

  @override
  void throwIfDisposed() {
    if (disposed) throw AssertionError('[Player] has been disposed');
  }

  @override
  int get handle => 0;

  @override
  List<AudioDevice> getAudioDevices() => const <AudioDevice>[];

  @override
  Future<void> replaceSingle(Media media, {bool synchronized = true}) =>
      open(media, play: state.playing);

  @override
  Future<void> add(Media media, {bool synchronized = true}) async {}

  @override
  Future<void> remove(int index, {bool synchronized = true}) async {}

  @override
  Future<void> next({bool synchronized = true}) async {}

  @override
  Future<void> previous({bool synchronized = true}) async {}

  @override
  Future<void> jump(int index, {bool synchronized = true}) async {}

  @override
  Future<void> move(int from, int to, {bool synchronized = true}) async {}

  @override
  Future<void> setPlaylistMode(
    PlaylistMode playlistMode, {
    bool synchronized = true,
  }) async {}

  @override
  Future<void> setPitch(double pitch, {bool synchronized = true}) async {}

  @override
  Future<void> setShuffle(bool shuffle, {bool synchronized = true}) async {}

  @override
  Future<void> setAudioDevice(
    AudioDevice audioDevice, {
    bool synchronized = true,
  }) async {}

  @override
  Future<void> setVideoTrack(
    VideoTrack track, {
    bool synchronized = true,
  }) async {}

  @override
  Future<void> setAudioTrack(
    AudioTrack track, {
    bool synchronized = true,
  }) async {}
}

/// The adapter's own video controller: upstream's `SubtitleView` only reads
/// the player's subtitle state through it, and `videoController!` is never
/// null. Nothing hands it to media_kit.
class TvExoVideoController extends PlatformVideoController {
  TvExoVideoController(Player player)
    : super(player, const VideoControllerConfiguration());

  @override
  Future<void>? setSize({int? width, int? height}) => null;

  void markFirstFrame() {
    if (!waitUntilFirstFrameRenderedCompleter.isCompleted) {
      waitUntilFirstFrameRenderedCompleter.complete();
    }
  }
}

/// What Media3 reports about the open streams.
class TvExoFacts extends ChangeNotifier {
  String? videoMime;
  String? videoCodecs;
  String? videoDecoder;
  int? width;
  int? height;

  /// The container's frame rate; live FLV and fMP4 carry none.
  double? frameRate;

  /// Measured from the decoder's output every 2 s while playing.
  double? measuredFps;

  /// `sdr`, `hdr10`, `hlg` or `dolbyVision`.
  String? hdr;
  int? dolbyVisionProfile;
  String? audioMime;
  String? audioCodecs;
  String? audioDecoder;
  int? sampleRate;
  int? channels;
  int dropped = 0;
  int? firstFrameMs;
  String? host;
  bool live = false;
  bool hls = false;

  void clear() {
    videoMime = videoCodecs = videoDecoder = hdr = null;
    audioMime = audioCodecs = audioDecoder = null;
    width = height = dolbyVisionProfile = sampleRate = channels = null;
    frameRate = measuredFps = null;
    firstFrameMs = null;
    dropped = 0;
    notifyListeners();
  }

  void setSource(String url, {required bool live, required bool hls}) {
    final uri = Uri.tryParse(url);
    host = uri?.host;
    this.live = live;
    this.hls = hls;
    notifyListeners();
  }

  void setVideo(Map args) {
    videoMime = args['mime'];
    videoCodecs = args['codecs'];
    videoDecoder = args['decoder'] ?? videoDecoder;
    width = args['width'];
    height = args['height'];
    final rate = args['frameRate'];
    frameRate = rate is num && rate > 0 ? rate.toDouble() : null;
    hdr = args['hdr'];
    dolbyVisionProfile = args['profile'];
    notifyListeners();
  }

  void setAudio(Map args) {
    audioMime = args['mime'];
    audioCodecs = args['codecs'];
    audioDecoder = args['decoder'] ?? audioDecoder;
    sampleRate = args['sampleRate'];
    channels = args['channels'];
    notifyListeners();
  }

  /// The audio track goes to the TV's output undecoded (杜比全景声, E-AC-3
  /// over eARC), so it isn't normalized: an encoded format with no decoder
  /// started for it.
  bool get audioPassthrough => audioDecoder == null && encodedAudio(audioMime);

  /// The audio formats a TV's output may take undecoded.
  static bool encodedAudio(String? mime) => const {
    'audio/eac3',
    'audio/eac3-joc',
    'audio/ac3',
    'audio/ac4',
    'audio/true-hd',
    'audio/vnd.dts',
    'audio/vnd.dts.hd',
  }.contains(mime);

  /// The first frame after the open; Media3 also reports one after each
  /// seek, which isn't kept.
  void setFirstFrame(Object? ms) {
    if (ms is int && firstFrameMs == null) firstFrameMs = ms;
    notifyListeners();
  }

  void setDropped(Object? count) {
    if (count is int) dropped = count;
    notifyListeners();
  }

  void setMeasuredFps(double? fps) {
    if (fps == null) return;
    measuredFps = fps;
    notifyListeners();
  }
}

/// Media3's buffer from the app's own settings (M17.6, decision 10): bytes
/// before time, forward only, zero or less meaning no cap, and no clamp.
abstract final class TvExoBuffer {
  /// 缓冲大小 and 缓冲时长 for a video; 直播缓冲大小 (0 means twice 缓冲大小,
  /// as upstream reads it) and 直播缓冲时长 (0 means no limit) for a live room.
  static ({int bytes, int ms}) resolve({
    required bool live,
    required double bufferSizeMb,
    required double bufferSec,
    required double liveBufferSizeMb,
    required double liveBufferSec,
  }) {
    final mb = live
        ? (liveBufferSizeMb > 0 ? liveBufferSizeMb : bufferSizeMb * 2)
        : bufferSizeMb;
    final sec = live ? liveBufferSec : bufferSec;
    return (
      bytes: mb > 0 ? (mb * 0x100000).round() : 0,
      ms: sec > 0 ? (sec * 1000).round() : 0,
    );
  }
}

/// Audio normalization on ExoPlayer (M17.6, decision 13), from
/// `Pref.audioNormalization` and the filter upstream builds for mpv, which
/// carries the video's measured `Volume`:
///  - 标准 and 高动态 (the TV's 音量均衡, M17.9; stored as [standard] and
///    [highDynamic]): as Bilibili's web player, one gain, the target minus
///    the measured loudness, here under a limiter at the true-peak target;
///    nothing when the video has no measurement or measures below
///    [undersizedLufs], and no fallback;
///  - 动态压缩 (预设 dynaudnorm): the dynamic normalizer with the preset's
///    numbers;
///  - 预设 loudnorm (stored before M17.9): one gain toward the preset's
///    −16 LUFS; with no measurement, upstream's fallback;
///  - 自定义: see [custom];
///  - 关闭: off;
///  - no filter (a live room, which mpv doesn't normalize either): off.
class TvExoNormalization {
  const TvExoNormalization.off()
    : mode = 'off',
      gainDb = null,
      ceilingDb = null,
      normalizer = null;

  const TvExoNormalization.loudness(double this.gainDb, double this.ceilingDb)
    : mode = 'loudness',
      normalizer = null;

  const TvExoNormalization.dynamicNormalizer(
    ({int frameMs, int window, double targetRms, double peak, double maxGain})
    this.normalizer,
  ) : mode = 'dynamic',
      gainDb = null,
      ceilingDb = null;

  final String mode;
  final double? gainDb;
  final double? ceilingDb;
  final ({
    int frameMs,
    int window,
    double targetRms,
    double peak,
    double maxGain,
  })?
  normalizer;

  Map<String, Object> toArgs() => <String, Object>{
    'mode': mode,
    'gainDb': ?gainDb,
    'ceilingDb': ?ceilingDb,
    if (normalizer case final d?) ...<String, Object>{
      'frameMs': d.frameMs,
      'window': d.window,
      'targetRms': d.targetRms,
      'peak': d.peak,
      'maxGain': d.maxGain,
    },
  };

  @override
  bool operator ==(Object other) =>
      other is TvExoNormalization &&
      other.mode == mode &&
      other.gainDb == gainDb &&
      other.ceilingDb == ceilingDb &&
      other.normalizer == normalizer;

  @override
  int get hashCode => Object.hash(mode, gainDb, ceilingDb, normalizer);

  @override
  String toString() => 'TvExoNormalization($mode, ${toArgs()})';

  /// 标准: Bilibili's `normal_target_i`, and its `target_tp` as the ceiling.
  /// As a loudnorm filter, so mpv would read it as 自定义参数 the same way.
  static const String standard = 'loudnorm=I=-14:LRA=11:TP=-1';

  /// 高动态: Bilibili's `high_dynamic_target_i`.
  static const String highDynamic = 'loudnorm=I=-24:LRA=11:TP=-1';

  /// Bilibili's `undersized_target_i`: its web player doesn't balance a
  /// video measured below this.
  static const double undersizedLufs = -28;

  /// Real loudness is negative. Bilibili sends 0.001 for a video it never
  /// measured, which upstream's `Volume.format` turns into 0, and a gain
  /// from it would cut the sound by the whole target.
  static double? _measured(String? filter, [double? measured]) {
    final m = measured ?? _args(filter ?? '', 'loudnorm')['measured_i'];
    return m != null && m < 0 ? m : null;
  }

  /// The key of [loudnessExtras] in a media's extras.
  static const String loudnessKey = 'tv-loudness';

  /// The hook beside upstream's `audioFilterExtras` in `setDataSource`: on
  /// TV, the video's measured loudness (Bilibili's `measured_i`), also while
  /// 音量均衡 is off, so the HUD can switch it on during playback (M17.10).
  /// Nothing off TV, or without a measurement.
  static Map<String, String> loudnessExtras(Volume? volume) =>
      TvPlatform.isTv && volume != null
      ? {loudnessKey: '${volume.measuredI}'}
      : const {};

  /// [filter] is upstream's mpv filter (it carries the measurement while
  /// 音量均衡 was on when the player was made); [measured] is the loudness
  /// from [loudnessExtras]. With [live] given, a live room is off and a
  /// video needs neither for 动态压缩; without it, no filter means off.
  static TvExoNormalization resolve({
    required String config,
    required String fallback,
    required String? filter,
    double? measured,
    bool? live,
  }) {
    if (live == true) return const .off();
    if (live == null && (filter == null || filter.isEmpty)) {
      return const .off();
    }
    switch (config) {
      case '1':
        return _dynamic(AudioNormalization.dynaudnorm.param);
      case '2':
        final measuredI = _measured(filter, measured);
        final preset = _args(AudioNormalization.loudnorm.param, 'loudnorm');
        final target = _args(filter ?? '', 'loudnorm')['i'] ?? preset['i'];
        if (measuredI != null && target != null) {
          return .loudness(target - measuredI, preset['tp'] ?? -1.5);
        }
        return fallback == '1'
            ? _dynamic(AudioNormalization.dynaudnorm.param)
            : const .off();
      case '0':
        return const .off();
      default:
        return custom(config, filter ?? '', measured);
    }
  }

  /// 标准, 高动态 and 自定义 (a filter string, as mpv takes it): a loudnorm
  /// filter is one gain toward its `I` with `TP` as the limiter's ceiling
  /// (ffmpeg's defaults, -24 and -2, where it gives none), and nothing when
  /// the video has no usable measurement or measures below
  /// [undersizedLufs]. A dynaudnorm filter is the dynamic normalizer with
  /// its `f`, `g`, `r`, `p` and `m`. Anything else Media3 can't run: off.
  static TvExoNormalization custom(
    String config,
    String filter, [
    double? measuredI,
  ]) {
    if (_has(config, 'loudnorm')) {
      final target = _args(config, 'loudnorm');
      final measured = _measured(filter, measuredI);
      if (measured == null || measured < undersizedLufs) return const .off();
      return .loudness((target['i'] ?? -24) - measured, target['tp'] ?? -2);
    }
    if (_has(config, 'dynaudnorm')) return _dynamic(config);
    return const .off();
  }

  static bool _has(String filter, String name) =>
      RegExp('(?:^|[^a-z])$name(?:[^a-z]|\$)').hasMatch(filter);

  static TvExoNormalization _dynamic(String param) {
    final a = _args(param, 'dynaudnorm');
    return .dynamicNormalizer((
      frameMs: (a['f'] ?? 500).round(),
      window: (a['g'] ?? 31).round(),
      targetRms: a['r'] ?? 0,
      peak: a['p'] ?? 0.95,
      maxGain: a['m'] ?? 10,
    ));
  }

  /// `name=k=v:k=v` in [filter], as numbers by lower-case key.
  static Map<String, double> _args(String filter, String name) {
    final match = RegExp(
      '(?:^|[^a-z])$name=([^\\s,"\\]\\[]+)',
    ).firstMatch(filter);
    if (match == null) return const <String, double>{};
    return <String, double>{
      for (final part in match.group(1)!.split(':'))
        if (part.split('=') case [final k, final v]
            when double.tryParse(v) != null)
          k.toLowerCase(): double.parse(v),
    };
  }
}

/// What a page's TV HUD offers the player (`TvExoPlayer.addHooks`).
class TvExoHudHooks {
  const TvExoHudHooks({required this.lowerQuality, required this.refetch});

  /// 降低画质 on the failure screen: the next quality that can play, or
  /// `null`.
  final ({String label, VoidCallback run})? Function() lowerQuality;

  /// How to fetch a fresh play link and reopen at the position, or `null`
  /// where the page can't (a live room, which reconnects; a local file).
  final Future<void> Function()? Function() refetch;
}
