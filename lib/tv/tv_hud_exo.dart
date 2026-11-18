part of 'tv_player_hud.dart';

// The HUD on ExoPlayer (docs/tv/PLAN.md, M17.10): `resolveAction` asks the
// current player what it supports, so mpv's entries (超分辨率, 播放器音量
// above 100 %) hide on this path; 画面比例 offers only the fits a
// `SurfaceView` can show; and 画质, 解码格式, 音质 and 播放信息 open TV lists
// that say what actually plays and why a quality or codec can't. 音量均衡 is
// a new entry that applies at once. None of this runs on mpv.

/// The player's answer for the HUD.
extension _TvHudExo on _TvHudActionTable {
  TvExoPlayer? get _exo => switch (_pl.videoPlayerController) {
    final TvExoPlayer p => p,
    _ => null,
  };

  bool get _onExo => _exo != null;

  /// "原画 · 1080P60": the server's quality name, then the decoded size and
  /// frame rate once the first frame is out (M17.7, decided).
  String _qualityLabel(String name) =>
      TvExoHudText.qualityLabel(name, _exo?.facts);

  // ---- 画质 ----

  /// Upstream's choice of a quality (`showSetVideoQa`'s row), saved as the
  /// default unless [once].
  Future<void> _pickVideoQuality(
    VideoDetailController ctr,
    int quality, {
    bool once = false,
  }) async {
    final newQa = VideoQuality.fromCode(quality);
    ctr
      ..plPlayerController.cacheVideoQa = once
          ? ctr.plPlayerController.cacheVideoQa
          : newQa.code
      ..currentVideoQa.value = newQa
      ..updatePlayer();
    SmartDialog.showToast(
      once ? '本次使用：${newQa.desc}' : '画质已变为：${newQa.desc}',
    );
    if (!once && !_pl.tempPlayerConf) {
      await GStorage.setting.put(
        await ConnectivityUtils.isWiFi
            ? SettingBoxKey.defaultVideoQa
            : SettingBoxKey.defaultVideoQaCellular,
        quality,
      );
    }
  }

  /// 画质 on ExoPlayer: upstream's rows, a greyed row with why it can't play
  /// and a detail line, and a row where only some codecs play saying which.
  Future<void> _showExoQualityDialog(VideoDetailController ctr) async {
    final PlayUrlModel data = ctr.data;
    final List<FormatItem>? formats = data.supportFormats;
    final List<VideoItem>? videos = data.dash?.video;
    final VideoQuality? current = ctr.currentVideoQa.value;
    if (formats == null || videos == null || current == null) return;
    final Set<int> available = videos.availableVideoQualities;
    final TvExoQualityReport? report = TvExoQualities.reportOf(data);
    await _showTvDialog((dialogContext) {
      return _TvOptionListDialog(
        title: '选择画质',
        items: [
          for (final FormatItem f in formats)
            if (f.quality case final int q)
              _exoQualityRow(
                dialogContext,
                ctr,
                f,
                q,
                current: current.code == q,
                available: available.contains(q),
                report: report,
              ),
        ],
      );
    });
  }

  _TvDialogOptionItem _exoQualityRow(
    BuildContext dialogContext,
    VideoDetailController ctr,
    FormatItem f,
    int q, {
    required bool current,
    required bool available,
    required TvExoQualityReport? report,
  }) {
    final List<TvExoStreamReport> refused =
        report?.refusedOf(q, ctr.preferCodecs) ?? const [];
    // A 仍要尝试 puts a refused stream back into the list for its one try;
    // the row stays greyed (M17.11 review).
    final bool playable = available && !(report?.refused(q) ?? false);
    // One detail line per codec that can't play.
    final String? detail = refused.isEmpty
        ? null
        : refused.map((s) => s.refusal!.detail).join('\n');
    return _TvDialogOptionItem(
      title: f.newDesc ?? VideoQuality.fromCode(q).desc,
      subtitle: detail,
      selected: current,
      dimmed: !playable,
      onSelect: () {
        if (current) {
          Navigator.of(dialogContext).pop();
          return;
        }
        if (playable) {
          Navigator.of(dialogContext).pop();
          _pickVideoQuality(ctr, q);
          return;
        }
        if (refused.isEmpty) {
          SmartDialog.showToast('标灰画质需要bilibili会员（已是会员？请关闭无痕模式）');
          return;
        }
        _explainOrTry(dialogContext, ctr, refused.first);
      },
    );
  }

  /// Select on a row that can't play: the reason, or with 仍要尝试 on, a
  /// confirmation and one try (M17.10, item 5).
  void _explainOrTry(
    BuildContext dialogContext,
    VideoDetailController ctr,
    TvExoStreamReport stream,
  ) {
    final TvExoRefusal? refusal = stream.refusal;
    if (refusal == null) return;
    if (!TvExoQualities.tryAnywayEnabled || !refusal.tryable) {
      SmartDialog.showToast('无法播放：${refusal.short}');
      return;
    }
    Navigator.of(dialogContext).pop();
    _confirmTryAnyway(ctr, stream);
  }

  Future<void> _confirmTryAnyway(
    VideoDetailController ctr,
    TvExoStreamReport stream,
  ) async {
    final TvExoRefusal refusal = stream.refusal!;
    await _showTvDialog((dialogContext) {
      return _TvOptionListDialog(
        title: '仍要尝试？${refusal.short}',
        items: [
          _TvDialogOptionItem(
            title: '取消',
            selected: false,
            icon: Icons.close_rounded,
            onSelect: () => Navigator.of(dialogContext).pop(),
          ),
          _TvDialogOptionItem(
            title: '仍要尝试一次',
            subtitle: '${refusal.detail}。只试一次，失败时停在失败画面',
            selected: false,
            icon: Icons.warning_amber_rounded,
            onSelect: () {
              Navigator.of(dialogContext).pop();
              _tryAnyway(ctr, stream.video);
            },
          ),
        ],
      );
    });
  }

  void _tryAnyway(VideoDetailController ctr, VideoItem video) {
    if (!TvExoQualities.restore(ctr.data, video)) return;
    final String? codecs = video.codecs;
    if (codecs != null) {
      try {
        ctr.currentDecodeFormats = VideoDecodeFormatType.fromString(codecs);
      } catch (_) {}
    }
    TvExoPlayer.tryAnywayNext = true;
    final newQa = VideoQuality.fromCode(video.id);
    ctr
      ..currentVideoQa.value = newQa
      ..updatePlayer();
    SmartDialog.showToast('尝试播放：${newQa.desc} ${TvExoCodec.name(codecs)}');
  }

  // ---- 解码格式 ----

  /// Upstream's `firstVideo`, or `null` while the page's first play link
  /// is still being read (it's `late`, M17.11 review).
  static VideoItem? _firstVideoOf(VideoDetailController ctr) {
    try {
      return ctr.firstVideo;
    } catch (_) {
      return null;
    }
  }

  /// The codec being decoded, or the one asked for before the first frame;
  /// `null` before either is known.
  String? _decodingName(VideoDetailController ctr) {
    final String? codecs =
        _exo?.facts.videoCodecs ?? _firstVideoOf(ctr)?.codecs;
    return codecs == null ? null : TvExoCodec.name(codecs);
  }

  /// 解码格式 on ExoPlayer: every codec the server offers for the current
  /// quality, a greyed one with why, and the decoder each plays on.
  Future<void> _showExoDecodeDialog(VideoDetailController ctr) async {
    final VideoItem? first = _firstVideoOf(ctr);
    if (first == null) {
      SmartDialog.showToast('视频加载中');
      return;
    }
    final int quality = first.quality.code;
    final TvExoQualityReport? report = TvExoQualities.reportOf(ctr.data);
    final List<TvExoStreamReport> streams = report?.of(quality) ?? const [];
    final List<({VideoItem video, TvExoStreamReport? report})> rows =
        streams.isNotEmpty
        ? [for (final s in streams) (video: s.video, report: s)]
        : [
            for (final v in ctr.data.dash?.video ?? const <VideoItem>[])
              if (v.id == quality) (video: v, report: null),
          ];
    if (rows.isEmpty) {
      SmartDialog.showToast('当前视频不支持选择解码格式');
      return;
    }
    final String? playing = first.codecs;
    await _showTvDialog((dialogContext) {
      return _TvOptionListDialog(
        title: '选择解码格式',
        items: [
          for (final row in rows)
            _TvDialogOptionItem(
              title: TvExoCodec.describe(row.video.codecs),
              subtitle: _decodeSubtitle(row.report),
              selected: row.video.codecs == playing,
              dimmed: row.report?.playable == false,
              onSelect: () {
                final TvExoStreamReport? r = row.report;
                if (r != null && !r.playable) {
                  _explainOrTry(dialogContext, ctr, r);
                  return;
                }
                Navigator.of(dialogContext).pop();
                if (row.video.codecs == playing) return;
                final VideoDecodeFormatType format;
                try {
                  format = VideoDecodeFormatType.fromString(row.video.codecs!);
                } catch (_) {
                  SmartDialog.showToast('无法切换到 ${row.video.codecs}');
                  return;
                }
                ctr
                  ..currentDecodeFormats = format
                  ..updatePlayer();
                SmartDialog.showToast('解码已变为：${format.name}');
              },
            ),
        ],
      );
    });
  }

  static String? _decodeSubtitle(TvExoStreamReport? r) {
    if (r == null) return null;
    if (r.refusal case final refusal?) return refusal.detail;
    final String? decoder = r.answer.decoder == null
        ? null
        : TvExoCodec.decoder(r.answer.decoder!);
    final String size = r.stream.size;
    final String plays = switch (r.answer.support) {
      'dolbyVision' => '杜比视界解码器 ${decoder ?? ''}'.trim(),
      'baseLayer' => '无杜比视界解码器，按 HLG 基础层由 ${decoder ?? 'HEVC 解码器'} 播放',
      _ => decoder ?? '',
    };
    return [size, plays].where((s) => s.isNotEmpty).join(' · ');
  }

  // ---- 音质 ----

  /// 音质 on ExoPlayer: each row says what happens to it — passed through
  /// to the TV's output undecoded (so not balanced), or decoded here and
  /// balanced — from the bridge's `audioSupport`.
  Future<void> _showExoAudioDialog(VideoDetailController ctr) async {
    final List<AudioItem>? audio = ctr.data.dash?.audio;
    final AudioQuality? current = ctr.currentAudioQa;
    if (audio == null || audio.isEmpty || current == null) return;
    final List<String?> support = await TvExoPlayer.audioSupport([
      for (final a in audio) a.codecs,
    ]);
    if (!mounted) return;
    await _showTvDialog((dialogContext) {
      return _TvOptionListDialog(
        title: '选择音质',
        items: [
          for (final (int i, AudioItem a) in audio.indexed)
            _TvDialogOptionItem(
              title: a.quality,
              subtitle:
                  '${a.codecs ?? ''} · ${TvExoHudText.audioPlays(a.codecs, support[i])}',
              selected: current.code == a.id,
              dimmed: support[i] == 'no',
              onSelect: () async {
                if (support[i] == 'no') {
                  SmartDialog.showToast('此音轨无法在当前音频输出上播放');
                  return;
                }
                Navigator.of(dialogContext).pop();
                if (current.code == a.id) return;
                final newQa = AudioQuality.fromCode(a.id);
                ctr
                  ..plPlayerController.cacheAudioQa = newQa.code
                  ..currentAudioQa = newQa
                  ..updatePlayer();
                SmartDialog.showToast('音质已变为：${newQa.desc}');
                if (!_pl.tempPlayerConf) {
                  await GStorage.setting.put(
                    await ConnectivityUtils.isWiFi
                        ? SettingBoxKey.defaultAudioQa
                        : SettingBoxKey.defaultAudioQaCellular,
                    a.id,
                  );
                }
              },
            ),
        ],
      );
    });
  }

  // ---- 音量均衡 ----

  /// 音量均衡 (the user, 2026-11-16): the TV's options, applied at once
  /// through the bridge's `setNormalization`; greyed on a passthrough track.
  TvHudAction? _audioNormalizationAction() {
    final TvExoPlayer? exo = _exo;
    if (exo == null || !_isVideo || _pl.isPipMode) return null;
    final String title = TvExoSettings.normalizationTitle(
      Pref.audioNormalization,
    );
    if (exo.facts.audioPassthrough) {
      return _single(
        TvHudActionId.audioNormalization,
        icon: Icons.equalizer_rounded,
        label: '音量均衡: 直通不调整',
        dimmed: true,
        onPressed: () => SmartDialog.showToast(
          '当前音轨（${exo.facts.audioCodecs ?? exo.facts.audioMime}）'
          '直通到电视的音频输出，不做音量均衡',
        ),
      );
    }
    return _single(
      TvHudActionId.audioNormalization,
      icon: Icons.equalizer_rounded,
      label: '音量均衡: $title',
      active: Pref.audioNormalization != TvExoSettings.off,
      onPressed: () => _showNormalizationDialog(exo),
    );
  }

  Future<void> _showNormalizationDialog(TvExoPlayer exo) async {
    final String stored = Pref.audioNormalization;
    final String selected = TvExoSettings.isCustom(stored)
        ? TvExoSettings.customRow
        : stored;
    await _showTvDialog((dialogContext) {
      return _TvOptionListDialog(
        title: '音量均衡',
        items: [
          for (final (String value, String title)
              in TvExoSettings.normalizationOptions)
            _TvDialogOptionItem(
              title:
                  value == TvExoSettings.customRow &&
                      TvExoSettings.isCustom(stored)
                  ? '$title：$stored'
                  : title,
              subtitle: TvExoSettings.normalizationHelp(value),
              selected: value == selected,
              onSelect: () async {
                Navigator.of(dialogContext).pop();
                var next = value;
                if (value == TvExoSettings.customRow) {
                  final String? typed = await TvExoSettings.customDialog(
                    context,
                    TvExoSettings.isCustom(stored)
                        ? stored
                        : TvExoNormalization.standard,
                  );
                  if (typed == null || typed.isEmpty) return;
                  next = typed;
                }
                await GStorage.setting.put(
                  SettingBoxKey.audioNormalization,
                  next,
                );
                final TvExoNormalization? now = await exo.applyNormalization();
                SmartDialog.showToast(
                  '音量均衡：${TvExoSettings.normalizationTitle(next)}'
                  '${now == null || now.mode != 'off' || next == TvExoSettings.off ? '' : '（本视频无响度数据，不调整）'}',
                );
              },
            ),
        ],
      );
    });
  }

  // ---- 播放信息 ----

  /// 播放信息 on ExoPlayer: what Media3 reports, as Chrome's media panel
  /// shows it.
  Future<void> _showExoPlayerInfo(TvExoPlayer exo) async {
    final List<(String, String)> rows = TvExoHudText.infoRows(
      exo.facts,
      normalization: exo.facts.audioPassthrough
          ? '直通，不调整'
          : TvExoSettings.normalizationTitle(Pref.audioNormalization),
      origin: _originHost,
    );
    await _showTvDialog((dialogContext) {
      return _TvOptionListDialog(
        title: '播放信息 · ExoPlayer',
        items: [
          for (final (String name, String value) in rows)
            _TvDialogOptionItem(
              title: name,
              subtitle: value,
              selected: false,
              icon: Icons.info_outline_rounded,
              onSelect: () {},
            ),
        ],
      );
    });
  }

  /// The CDN host of the video being played, as the play-URL API gave it.
  String? get _originHost {
    if (!_isVideo) return null;
    try {
      final String? url = _videoDetailCtr?.firstVideo.baseUrl;
      return url == null ? null : Uri.tryParse(url)?.host;
    } catch (_) {
      return null; // `firstVideo` isn't set yet.
    }
  }

  // ---- A fresh play link (M17.11 review) ----

  /// 重载视频's path for the player: a fresh play link for this video,
  /// reopened at the position. `null` in a live room, which the player
  /// reconnects itself, and for a local file.
  Future<void> Function()? _refetchLink() {
    if (!_isVideo) return null;
    final VideoDetailController? ctr = _videoDetailCtr;
    if (ctr == null || ctr.isFileSource) return null;
    return () => ctr.queryVideoUrl(fromReset: true);
  }

  // ---- 降低画质 on the failure screen (M17.10, item 6) ----

  /// The next quality below the current one that can play, and how to play
  /// it once; `null` when there's none or the player hasn't failed.
  ({String label, VoidCallback run})? _lowerQuality() {
    final TvExoPlayer? exo = _exo;
    if (exo == null || exo.failed.value == null) return null;
    if (_isVideo) {
      final VideoDetailController? ctr = _videoDetailCtr;
      final int? current = ctr?.currentVideoQa.value?.code;
      final List<VideoItem>? videos = ctr?.data.dash?.video;
      if (ctr == null || current == null || videos == null) return null;
      final TvExoQualityReport? report = TvExoQualities.reportOf(ctr.data);
      final List<int> lower =
          videos.availableVideoQualities
              .where((q) => q < current && !(report?.refused(q) ?? false))
              .toList()
            ..sort((a, b) => b.compareTo(a));
      if (lower.isEmpty) return null;
      final int q = lower.first;
      return (
        label: report?.nameOf(q) ?? VideoQuality.fromCode(q).desc,
        run: () => _pickVideoQuality(ctr, q, once: true),
      );
    }
    final LiveRoomController? liveCtr = _liveRoomCtr;
    final int? current = liveCtr?.currentQn.value?.code;
    if (liveCtr == null || current == null) return null;
    final List<LiveQuality> lower =
        liveCtr.acceptQnList.where((qn) => qn.code < current).toList()
          ..sort((a, b) => b.code.compareTo(a.code));
    if (lower.isEmpty) return null;
    final LiveQuality qn = lower.first;
    return (
      label: qn.desc,
      run: () {
        liveCtr.changeQn(qn);
        SmartDialog.showToast('本次使用：${qn.desc}');
      },
    );
  }
}
