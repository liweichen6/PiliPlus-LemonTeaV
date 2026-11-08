part of 'tv_player_hud.dart';

// The TV player HUD's action table (M14.2, docs/tv/PLAN.md, Milestone M14).
//
// Every function the HUD offers is one entry here: a fixed id, an icon, a
// label (with the current value where it matters), when it's available and
// what it does. An entry that isn't available resolves to no buttons, so the
// HUD hides it rather than showing it disabled. The `⋮` menu and the editable
// groups (M14.3) are drawn from this table.

/// The `⋮` menu's groups, in menu order (agreed with the user, 2026-11-07).
enum TvHudMenuGroup {
  play('播放'),
  danmaku('弹幕'),
  interact('互动'),
  pictureAndSound('画面与声音'),
  other('其他');

  const TvHudMenuGroup(this.label);

  final String label;
}

/// One entry of the action table.
///
/// The names are the ids saved in the settings box for the editable groups
/// ([TvHudGroups]), so an entry is never renamed; an id that's no longer
/// known is skipped when the saved lists are read. Within a group the order
/// is the `⋮` menu's order.
enum TvHudActionId {
  quality(TvHudMenuGroup.play, '画质', Icons.hd_rounded),
  speed(TvHudMenuGroup.play, '倍速', Icons.speed_rounded),
  videoFit(TvHudMenuGroup.play, '画面比例', Icons.aspect_ratio_rounded),
  subtitle(TvHudMenuGroup.play, '字幕', Icons.closed_caption_rounded),

  /// Upstream's 翻译 bar button: the video in another language, where
  /// Bilibili offers one (likely AI dubbing; it reloads the streams).
  aiTranslate(TvHudMenuGroup.play, '翻译', Icons.translate_rounded),

  /// 上集 / 下集 / 选集 while the video is in a list (an episode list, parts or
  /// a collection), otherwise 下个视频; nothing when there's nothing to play
  /// next.
  episodes(TvHudMenuGroup.play, '选集', Icons.playlist_play_rounded),

  /// 分段信息: the uploader's chapters.
  viewPoints(TvHudMenuGroup.play, '分段信息', Icons.view_list_rounded),

  /// 片段信息: SponsorBlock's segments (and Bilibili's 片头 / 片尾 for PGC),
  /// upstream's `showSBDetail`, where each can be skipped or jumped to.
  segments(TvHudMenuGroup.play, '片段信息', Icons.fast_forward_outlined),
  playOrder(TvHudMenuGroup.play, '播放顺序', Icons.repeat_rounded),
  danmakuToggle(TvHudMenuGroup.danmaku, '弹幕开关', Icons.subtitles_rounded),
  danmakuSettings(TvHudMenuGroup.danmaku, '弹幕设置', Icons.tune_rounded),
  dmChart(TvHudMenuGroup.danmaku, '高能进度条', Icons.show_chart_rounded),
  danmakuPool(
    TvHudMenuGroup.danmaku,
    '弹幕列表',
    Icons.format_list_bulleted_rounded,
  ),
  like(TvHudMenuGroup.interact, '点赞', Icons.thumb_up_off_alt_rounded),
  coin(TvHudMenuGroup.interact, '投币', Icons.monetization_on_rounded),
  favorite(TvHudMenuGroup.interact, '收藏', Icons.star_border_rounded),
  watchLater(TvHudMenuGroup.interact, '稍后再看', Icons.watch_later_outlined),
  audioQuality(TvHudMenuGroup.pictureAndSound, '音质', Icons.album_outlined),
  decodeFormat(TvHudMenuGroup.pictureAndSound, '解码格式', Icons.av_timer_outlined),
  superResolution(
    TvHudMenuGroup.pictureAndSound,
    '超分辨率',
    Icons.auto_awesome_rounded,
  ),
  playerVolume(
    TvHudMenuGroup.pictureAndSound,
    '播放器音量',
    Icons.volume_up_rounded,
  ),
  shutdownTimer(
    TvHudMenuGroup.pictureAndSound,
    '定时关闭',
    Icons.hourglass_top_rounded,
  ),
  reload(TvHudMenuGroup.other, '重载视频', Icons.refresh_rounded),
  playerInfo(TvHudMenuGroup.other, '播放信息', Icons.info_outline_rounded),
  fullSettings(TvHudMenuGroup.other, '完整设置', Icons.settings_rounded),

  /// Opens the button editor (M14.3).
  editButtons(
    TvHudMenuGroup.other,
    '编辑按钮',
    Icons.edit_rounded,
    pinnable: false,
  );

  const TvHudActionId(
    this.group,
    this.title,
    this.icon, {
    this.pinnable = true,
  });

  final TvHudMenuGroup group;

  /// The entry's name in the editor, without the current value that its HUD
  /// button shows.
  final String title;

  /// The entry's icon in the editor.
  final IconData icon;

  /// Whether the entry can be pinned to the top-right or bottom group.
  final bool pinnable;
}

/// A button that an available entry resolves to.
@immutable
class TvHudAction {
  const TvHudAction({
    required this.id,
    required this.buttonId,
    required this.icon,
    required this.label,
    required this.onPressed,
    this.active = false,
    this.onHoldStart,
    this.onHoldEnd,
  });

  /// The entry this button belongs to.
  final TvHudActionId id;

  /// Unique per button: the entry's name, or `episodes.prev`, `episodes.next`,
  /// `episodes.list` and `episodes.nextVideo` for the episode entry.
  final String buttonId;
  final IconData icon;
  final String label;

  /// Drawn highlighted: a switch that's on, a liked or favourited video.
  final bool active;

  /// Select (or a tap) on the button.
  final VoidCallback onPressed;

  /// For 点赞: holding Select starts 三连, releasing ends it; `isTapUp` is
  /// true for a release, false when focus left while held.
  final VoidCallback? onHoldStart;
  final ValueChanged<bool>? onHoldEnd;

  Key get key => keyOf(buttonId);

  /// The widget key of the HUD button for [buttonId].
  static Key keyOf(String buttonId) =>
      ValueKey<String>('tvHudAction:$buttonId');
}

/// Implemented by the HUD's state: resolves an entry of the action table
/// against the current player, video and page.
abstract interface class TvHudActionSource {
  /// The buttons [id] resolves to now; empty when it isn't available.
  List<TvHudAction> resolveAction(TvHudActionId id);
}

/// Upstream's panels on `HeaderControlState`, reached through
/// `VideoDetailController.headerCtrKey`.
abstract interface class TvHudHeaderPanels {
  void showSetVideoQa();
  void showSetAudioQa();
  void showSetDecodeFormats();
  void showSetSubtitle();
  void showDanmakuPool();
  void showSettingSheet();
}

/// Every upstream entry point the action table opens apart from the danmaku
/// panel, which comes from `HeaderMixin` on the HUD itself. Tests replace it
/// with [TvPlayerHud.debugUpstream].
abstract interface class TvHudUpstream {
  /// The mounted `HeaderControlState` of [ctr], or `null` while upstream's
  /// header isn't mounted.
  TvHudHeaderPanels? headerOf(VideoDetailController ctr);

  void showPlayerInfo(BuildContext context, Player player);

  Future<void> showPlayerVolume(BuildContext context, Player player);

  void showShutdownTimer(
    BuildContext context, {
    required bool isFullScreen,
    required bool isLive,
  });

  /// Upstream's chapter panel (`ViewPointsPage`), as its player opens it in
  /// fullscreen.
  void showViewPoints(BuildContext context, VideoDetailController ctr);
}

class _HeaderControlPanels implements TvHudHeaderPanels {
  const _HeaderControlPanels(this._state);

  final HeaderControlState _state;

  @override
  void showSetVideoQa() => _state.showSetVideoQa();

  @override
  void showSetAudioQa() => _state.showSetAudioQa();

  @override
  void showSetDecodeFormats() => _state.showSetDecodeFormats();

  @override
  void showSetSubtitle() => _state.showSetSubtitle();

  @override
  void showDanmakuPool() => _state.showDanmakuPool();

  @override
  void showSettingSheet() => _state.showSettingSheet();
}

class _DefaultTvHudUpstream implements TvHudUpstream {
  const _DefaultTvHudUpstream();

  @override
  TvHudHeaderPanels? headerOf(VideoDetailController ctr) {
    final State? state = ctr.headerCtrKey.currentState;
    if (state is HeaderControlState && state.mounted) {
      return _HeaderControlPanels(state);
    }
    return null;
  }

  @override
  void showPlayerInfo(BuildContext context, Player player) =>
      HeaderControlState.showPlayerInfo(context, player: player);

  @override
  Future<void> showPlayerVolume(BuildContext context, Player player) =>
      showPlayerVolumeDialog(context, () {}, onChanged: player.setVolume);

  @override
  void showShutdownTimer(
    BuildContext context, {
    required bool isFullScreen,
    required bool isLive,
  }) => shutdownTimerService.showScheduleExitDialog(
    context,
    isFullScreen: isFullScreen,
    isLive: isLive,
  );

  @override
  void showViewPoints(BuildContext context, VideoDetailController ctr) {
    final PlPlayerController pl = ctr.plPlayerController;
    final Widget child = ViewPointsPage(
      enableSlide: false,
      videoDetailController: ctr,
      plPlayerController: pl,
    );
    PageUtils.showVideoBottomSheet(
      context,
      child: pl.darkVideoPage
          ? Theme(data: ThemeUtils.darkTheme, child: child)
          : child,
    );
  }
}

/// The action table, mixed into the HUD's state.
mixin _TvHudActionTable on State<TvPlayerHud>, HeaderMixin<TvPlayerHud>
    implements TvHudActionSource {
  PlPlayerController get _pl;
  bool get _hasPlayer;
  bool get _isFullScreen;
  VideoDetailController? get _videoDetailCtr;
  LiveRoomController? get _liveRoomCtr;
  List<({String label, BaseEpisodeItem item, bool isCurrent})>
  _collectEpisodes();
  Future<void> _showTvDialog(Widget Function(BuildContext) builder);
  Future<void> _openEditor();
  void _hideHud({bool restoreFocus = true});
  void _resetAutoHideTimer();
  void _cancelAutoHideTimer();
  void _syncFocusForMode(
    bool isFullScreen, {
    bool forceSplitScreenQuickFocus = false,
  });

  TvHudUpstream get _upstream =>
      widget.debugUpstream ?? const _DefaultTvHudUpstream();

  bool get _isVideo => !_pl.isLive;

  /// Upstream's header panels for the current video, or `null` where they
  /// can't open: no video page, upstream's header not mounted, or
  /// picture-in-picture.
  TvHudHeaderPanels? get _headerPanels {
    if (!_isVideo || _pl.isPipMode) return null;
    final VideoDetailController? ctr = _videoDetailCtr;
    if (ctr == null) return null;
    return _upstream.headerOf(ctr);
  }

  /// The navigator that upstream's panels (`PageUtils.showVideoBottomSheet`,
  /// on `Get.key`) and dialogs (`showDialog`, on the root navigator) open on.
  NavigatorState? get _panelNavigator =>
      Get.key.currentState ?? Navigator.maybeOf(context, rootNavigator: true);

  Route<dynamic>? _topRoute(NavigatorState navigator) {
    Route<dynamic>? top;
    // Doesn't pop anything: the predicate accepts the first route it sees.
    navigator.popUntil((Route<dynamic> route) {
      top = route;
      return true;
    });
    return top;
  }

  /// Hides the HUD, runs [open] (which pushes one of upstream's panels or
  /// dialogs), and puts focus back on the player once that route is popped.
  Future<void> _openUpstreamPanel(VoidCallback open) async {
    _hideHud(restoreFocus: false);
    final NavigatorState? navigator = _panelNavigator;
    final Route<dynamic>? before = navigator == null
        ? null
        : _topRoute(navigator);
    open();
    final Route<dynamic>? after = navigator == null
        ? null
        : _topRoute(navigator);
    if (after != null && !identical(after, before)) {
      await after.popped;
    }
    if (mounted) {
      _syncFocusForMode(_isFullScreen, forceSplitScreenQuickFocus: true);
    }
  }

  Future<void> _openUpstreamDialog(Future<void> Function() open) async {
    _hideHud(restoreFocus: false);
    await open();
    if (mounted) {
      _syncFocusForMode(_isFullScreen, forceSplitScreenQuickFocus: true);
    }
  }

  TvHudAction _single(
    TvHudActionId id, {
    required IconData icon,
    required String label,
    required VoidCallback onPressed,
    bool active = false,
  }) => TvHudAction(
    id: id,
    buttonId: id.name,
    icon: icon,
    label: label,
    active: active,
    onPressed: onPressed,
  );

  @override
  List<TvHudAction> resolveAction(TvHudActionId id) {
    final TvHudAction? single = switch (id) {
      TvHudActionId.episodes => null,
      TvHudActionId.quality => _qualityAction(),
      TvHudActionId.speed => _speedAction(),
      TvHudActionId.videoFit => _videoFitAction(),
      TvHudActionId.subtitle => _subtitleAction(),
      TvHudActionId.aiTranslate => _aiTranslateAction(),
      TvHudActionId.viewPoints => _viewPointsAction(),
      TvHudActionId.segments => _segmentsAction(),
      TvHudActionId.playOrder => _playOrderAction(),
      TvHudActionId.danmakuToggle => _danmakuToggleAction(),
      TvHudActionId.danmakuSettings => _danmakuSettingsAction(),
      TvHudActionId.dmChart => _dmChartAction(),
      TvHudActionId.danmakuPool => _danmakuPoolAction(),
      TvHudActionId.like => _likeAction(),
      TvHudActionId.coin => _coinAction(),
      TvHudActionId.favorite => _favoriteAction(),
      TvHudActionId.watchLater => _watchLaterAction(),
      TvHudActionId.audioQuality => _audioQualityAction(),
      TvHudActionId.decodeFormat => _decodeFormatAction(),
      TvHudActionId.superResolution => _superResolutionAction(),
      TvHudActionId.playerVolume => _playerVolumeAction(),
      TvHudActionId.shutdownTimer => _shutdownTimerAction(),
      TvHudActionId.reload => _reloadAction(),
      TvHudActionId.playerInfo => _playerInfoAction(),
      TvHudActionId.fullSettings => _fullSettingsAction(),
      TvHudActionId.editButtons => _editButtonsAction(),
    };
    if (id == TvHudActionId.episodes) return _episodeActions();
    return [?single];
  }

  // ---------------------------------------------------------------------------
  // 播放

  TvHudAction? _qualityAction() {
    if (!_isVideo) {
      final LiveRoomController? liveCtr = _liveRoomCtr;
      if (liveCtr == null || liveCtr.acceptQnList.isEmpty) return null;
      return _single(
        TvHudActionId.quality,
        icon: Icons.hd_rounded,
        label: '画质: ${liveCtr.currentQn.value?.desc ?? '默认'}',
        onPressed: () => _showLiveQualityDialog(liveCtr),
      );
    }
    final VideoDetailController? ctr = _videoDetailCtr;
    final TvHudHeaderPanels? panels = _headerPanels;
    final VideoQuality? current = ctr?.currentVideoQa.value;
    if (ctr == null ||
        panels == null ||
        ctr.isFileSource ||
        ctr.data.dash == null ||
        current == null) {
      return null;
    }
    return _single(
      TvHudActionId.quality,
      icon: Icons.hd_rounded,
      label: '画质: ${current.shortDesc}',
      onPressed: () => _openUpstreamPanel(panels.showSetVideoQa),
    );
  }

  Future<void> _showLiveQualityDialog(LiveRoomController liveCtr) async {
    final LiveQuality? currentQn = liveCtr.currentQn.value;
    await _showTvDialog((dialogContext) {
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
    });
  }

  TvHudAction? _speedAction() {
    if (!_isVideo) return null;
    return _single(
      TvHudActionId.speed,
      icon: Icons.speed_rounded,
      label: '倍速: ${_pl.playbackSpeed}x',
      onPressed: _showSpeedDialog,
    );
  }

  Future<void> _showSpeedDialog() async {
    final List<double> speeds = _pl.speedList;
    final double currentSpeed = _pl.playbackSpeed;
    await _showTvDialog((dialogContext) {
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
    });
  }

  TvHudAction _videoFitAction() => _single(
    TvHudActionId.videoFit,
    icon: Icons.aspect_ratio_rounded,
    label: '画面: ${_pl.videoFit.value.desc}',
    onPressed: _showVideoFitDialog,
  );

  Future<void> _showVideoFitDialog() async {
    final VideoFitType currentFit = _pl.videoFit.value;
    final List<VideoFitType> fits = _pl.videoPlane == null
        ? VideoFitType.values
        : TvVideoPlane.supportedFits;
    await _showTvDialog((dialogContext) {
      return _TvOptionListDialog(
        title: '选择画面比例',
        items: [
          for (final fit in fits)
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
    });
  }

  /// Shown under upstream's condition for its subtitle button: the video has
  /// subtitle tracks.
  TvHudAction? _subtitleAction() {
    if (!_isVideo) return null;
    final VideoDetailController? ctr = _videoDetailCtr;
    if (ctr == null || ctr.subtitles.isEmpty) return null;
    final int index = ctr.vttSubtitlesIndex.value;
    final String current = index > 0 && index <= ctr.subtitles.length
        ? _subtitleName(ctr.subtitles[index - 1])
        : '关闭';
    return _single(
      TvHudActionId.subtitle,
      icon: index > 0
          ? Icons.closed_caption_rounded
          : Icons.closed_caption_off_outlined,
      label: '字幕: $current',
      active: index > 0,
      onPressed: () => _showSubtitleDialog(ctr),
    );
  }

  static String _subtitleName(Subtitle subtitle) =>
      subtitle.lanDoc ?? subtitle.lan;

  /// The track list, with upstream's `字幕设置` panel at its end.
  Future<void> _showSubtitleDialog(VideoDetailController ctr) async {
    final int current = ctr.vttSubtitlesIndex.value;
    final TvHudHeaderPanels? panels = _headerPanels;
    await _showTvDialog((dialogContext) {
      return _TvOptionListDialog(
        title: '字幕',
        items: [
          _TvDialogOptionItem(
            title: '关闭字幕',
            selected: current <= 0,
            onSelect: () {
              Navigator.of(dialogContext).pop();
              ctr.setSubtitle(0);
            },
          ),
          for (int i = 0; i < ctr.subtitles.length; i++)
            _TvDialogOptionItem(
              title: _subtitleName(ctr.subtitles[i]),
              selected: current == i + 1,
              onSelect: () {
                Navigator.of(dialogContext).pop();
                ctr.setSubtitle(i + 1);
              },
            ),
          if (panels != null)
            _TvDialogOptionItem(
              title: '字幕设置',
              icon: Icons.tune_rounded,
              selected: false,
              onSelect: () {
                Navigator.of(dialogContext).pop();
                _openUpstreamPanel(panels.showSetSubtitle);
              },
            ),
        ],
      );
    });
  }

  /// Shown under upstream's condition: not an offline file, and the video
  /// offers other languages.
  TvHudAction? _aiTranslateAction() {
    if (!_isVideo || _pl.isFileSource) return null;
    final VideoDetailController? ctr = _videoDetailCtr;
    final List<LanguageItem>? languages = ctr?.languages.value;
    if (ctr == null || languages == null || languages.isEmpty) return null;
    final String current = ctr.currLang.value ?? '';
    final String? title = current.isEmpty
        ? null
        : languages.firstWhereOrNull((e) => e.lang == current)?.title;
    return _single(
      TvHudActionId.aiTranslate,
      icon: Icons.translate_rounded,
      label: '翻译: ${title ?? '关闭'}',
      active: title != null,
      onPressed: () => _showAiTranslateDialog(ctr, languages, current),
    );
  }

  Future<void> _showAiTranslateDialog(
    VideoDetailController ctr,
    List<LanguageItem> languages,
    String current,
  ) async {
    await _showTvDialog((dialogContext) {
      return _TvOptionListDialog(
        title: '翻译',
        items: [
          _TvDialogOptionItem(
            title: '关闭翻译',
            selected: current.isEmpty,
            onSelect: () {
              Navigator.of(dialogContext).pop();
              ctr.setLanguage('');
            },
          ),
          for (final LanguageItem item in languages)
            if (item.lang != null)
              _TvDialogOptionItem(
                title: item.title ?? item.lang!,
                selected: item.lang == current,
                onSelect: () {
                  Navigator.of(dialogContext).pop();
                  ctr.setLanguage(item.lang!);
                },
              ),
        ],
      );
    });
  }

  /// Shown under upstream's condition: its `showViewPoints` setting is on and
  /// the video has chapters. Opens upstream's chapter panel, where Select on
  /// a chapter jumps to it and the switch shows or hides the marks on the bar.
  TvHudAction? _viewPointsAction() {
    if (!_isVideo ||
        _pl.isFileSource ||
        _pl.isPipMode ||
        !_pl.showViewPoints ||
        Get.key.currentState == null) {
      return null;
    }
    final VideoDetailController? ctr = _videoDetailCtr;
    if (ctr == null || ctr.viewPointList.isEmpty) return null;
    return _single(
      TvHudActionId.viewPoints,
      icon: Icons.view_list_rounded,
      label: '分段信息',
      active: ctr.showVP.value,
      onPressed: () =>
          _openUpstreamPanel(() => _upstream.showViewPoints(context, ctr)),
    );
  }

  /// Shown under upstream's condition for its header button: blocking on and
  /// the video's segments loaded.
  TvHudAction? _segmentsAction() {
    if (!_isVideo ||
        _pl.isFileSource ||
        _pl.isPipMode ||
        !_pl.enableBlock ||
        Get.key.currentState == null) {
      return null;
    }
    final VideoDetailController? ctr = _videoDetailCtr;
    if (ctr == null || ctr.segmentProgressList.isEmpty) return null;
    return _single(
      TvHudActionId.segments,
      icon: Icons.fast_forward_outlined,
      label: '片段信息',
      onPressed: () => _openUpstreamPanel(ctr.showSBDetail),
    );
  }

  List<TvHudAction> _episodeActions() {
    final CommonIntroController? intro = widget.introController;
    if (intro == null || !_isVideo || _pl.isFileSource) return const [];
    final episodes = _collectEpisodes();
    if (episodes.length > 1) {
      return [
        TvHudAction(
          id: TvHudActionId.episodes,
          buttonId: 'episodes.prev',
          icon: Icons.skip_previous_rounded,
          label: '上集',
          onPressed: () {
            if (!intro.prevPlay()) {
              SmartDialog.showToast('已经是第一集了');
            }
          },
        ),
        TvHudAction(
          id: TvHudActionId.episodes,
          buttonId: 'episodes.next',
          icon: Icons.skip_next_rounded,
          label: '下集',
          onPressed: () {
            if (!intro.nextPlay()) {
              SmartDialog.showToast('已经是最后一集了');
            }
          },
        ),
        TvHudAction(
          id: TvHudActionId.episodes,
          buttonId: 'episodes.list',
          icon: Icons.playlist_play_rounded,
          label: '选集 (${episodes.length})',
          onPressed: _showEpisodeDialog,
        ),
      ];
    }
    // Not in a list: the first related video, like upstream's 自动连播. A PGC
    // without a list has nothing to play next.
    if (intro case final UgcIntroController ugcCtr) {
      return [
        TvHudAction(
          id: TvHudActionId.episodes,
          buttonId: 'episodes.nextVideo',
          icon: Icons.skip_next_rounded,
          label: '下个视频',
          onPressed: ugcCtr.playRelated,
        ),
      ];
    }
    return const [];
  }

  Future<void> _showEpisodeDialog() async {
    final episodes = _collectEpisodes();
    if (episodes.isEmpty) {
      SmartDialog.showToast('当前视频无分P或剧集');
      return;
    }
    await _showTvDialog((dialogContext) {
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
    });
  }

  TvHudAction? _playOrderAction() {
    if (!_isVideo) return null;
    return _single(
      TvHudActionId.playOrder,
      icon: Icons.repeat_rounded,
      label: '播放顺序: ${_pl.playRepeat.label}',
      onPressed: _showPlayOrderDialog,
    );
  }

  Future<void> _showPlayOrderDialog() async {
    final PlayRepeat current = _pl.playRepeat;
    await _showTvDialog((dialogContext) {
      return _TvOptionListDialog(
        title: '播放顺序',
        items: [
          for (final PlayRepeat type in PlayRepeat.values)
            _TvDialogOptionItem(
              title: type.label,
              selected: type == current,
              onSelect: () {
                Navigator.of(dialogContext).pop();
                _pl.setPlayRepeat(type);
                SmartDialog.showToast('播放顺序：${type.label}');
              },
            ),
        ],
      );
    });
  }

  // ---------------------------------------------------------------------------
  // 弹幕

  TvHudAction _danmakuToggleAction() {
    final bool on = _pl.enableShowDanmakuAdaptive.value;
    return _single(
      TvHudActionId.danmakuToggle,
      icon: on ? Icons.subtitles_rounded : Icons.subtitles_off_rounded,
      label: on ? '弹幕: 开' : '弹幕: 关',
      active: on,
      onPressed: _toggleDanmaku,
    );
  }

  void _toggleDanmaku() {
    final bool newVal = !_pl.enableShowDanmakuAdaptive.value;
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
  }

  /// Upstream's own danmaku panel (`HeaderMixin.showSetDanmaku`), for videos
  /// and live rooms alike.
  TvHudAction? _danmakuSettingsAction() {
    if (_pl.isPipMode || Get.key.currentState == null) return null;
    return _single(
      TvHudActionId.danmakuSettings,
      icon: Icons.tune_rounded,
      label: '弹幕设置',
      onPressed: () =>
          _openUpstreamPanel(() => showSetDanmaku(isLive: _pl.isLive)),
    );
  }

  /// Upstream shows its 高能进度条 button once the chart's data has loaded,
  /// which happens only with its `showDmChart` setting on (on by default on
  /// TV). The chart is drawn over the time bar (`_TvDmChart`).
  TvHudAction? _dmChartAction() {
    if (!_isVideo || _pl.isFileSource || !_pl.showDmChart) return null;
    final VideoDetailController? ctr = _videoDetailCtr;
    if (ctr == null) return null;
    final List<double>? data = ctr.dmTrend.value?.dataOrNull;
    if (data == null || data.isEmpty) return null;
    final bool show = ctr.showDmTrendChart.value;
    return _single(
      TvHudActionId.dmChart,
      icon: Icons.show_chart_rounded,
      label: '高能进度条',
      active: show,
      onPressed: () {
        ctr.showDmTrendChart.value = !show;
        SmartDialog.showToast(show ? '已关闭高能进度条' : '已开启高能进度条');
      },
    );
  }

  TvHudAction? _danmakuPoolAction() {
    final TvHudHeaderPanels? panels = _headerPanels;
    if (panels == null || _pl.danmakuController == null) return null;
    return _single(
      TvHudActionId.danmakuPool,
      icon: Icons.format_list_bulleted_rounded,
      label: '弹幕列表',
      onPressed: () => _openUpstreamPanel(panels.showDanmakuPool),
    );
  }

  // ---------------------------------------------------------------------------
  // 互动

  CommonIntroController? get _interactIntro {
    if (!_isVideo || _pl.isFileSource) return null;
    return widget.introController;
  }

  TvHudAction? _likeAction() {
    final CommonIntroController? intro = _interactIntro;
    if (intro == null) return null;
    final bool hasLike = intro.hasLike.value;
    return TvHudAction(
      id: TvHudActionId.like,
      buttonId: TvHudActionId.like.name,
      icon: hasLike
          ? Icons.thumb_up_alt_rounded
          : Icons.thumb_up_off_alt_rounded,
      label: hasLike ? '已赞 (长按三连)' : '点赞 (长按三连)',
      active: hasLike,
      onPressed: intro.actionLikeVideo,
      onHoldStart: () {
        _cancelAutoHideTimer();
        _pl.tripling = true;
        intro.onStartTriple();
      },
      onHoldEnd: (bool isTapUp) {
        _pl.tripling = false;
        intro.onCancelTriple(isTapUp);
        _resetAutoHideTimer();
      },
    );
  }

  TvHudAction? _coinAction() {
    final CommonIntroController? intro = _interactIntro;
    if (intro == null) return null;
    final bool hasCoin = intro.hasCoin;
    return _single(
      TvHudActionId.coin,
      icon: Icons.monetization_on_rounded,
      label: hasCoin ? '已投币' : '投币',
      active: hasCoin,
      onPressed: () {
        _hideHud();
        intro.actionCoinVideo();
      },
    );
  }

  TvHudAction? _favoriteAction() {
    final CommonIntroController? intro = _interactIntro;
    if (intro == null) return null;
    final bool hasFav = intro.hasFav.value;
    return _single(
      TvHudActionId.favorite,
      icon: hasFav ? Icons.star_rounded : Icons.star_border_rounded,
      label: hasFav ? '已收藏' : '收藏',
      active: hasFav,
      onPressed: () {
        _hideHud();
        intro.showFavBottomSheet(context);
      },
    );
  }

  TvHudAction? _watchLaterAction() {
    final CommonIntroController? intro = _interactIntro;
    if (intro == null) return null;
    final bool hasLater = intro.hasLater.value;
    return _single(
      TvHudActionId.watchLater,
      icon: hasLater ? Icons.watch_later_rounded : Icons.watch_later_outlined,
      label: hasLater ? '已在稍后再看' : '稍后再看',
      active: hasLater,
      onPressed: intro.viewLater,
    );
  }

  // ---------------------------------------------------------------------------
  // 画面与声音

  TvHudAction? _audioQualityAction() {
    final TvHudHeaderPanels? panels = _headerPanels;
    final VideoDetailController? ctr = _videoDetailCtr;
    final AudioQuality? current = ctr?.currentAudioQa;
    if (panels == null ||
        ctr == null ||
        ctr.isFileSource ||
        current == null ||
        (ctr.data.dash?.audio?.isEmpty ?? true)) {
      return null;
    }
    return _single(
      TvHudActionId.audioQuality,
      icon: Icons.album_outlined,
      label: '音质: ${current.desc}',
      onPressed: () => _openUpstreamPanel(panels.showSetAudioQa),
    );
  }

  TvHudAction? _decodeFormatAction() {
    final TvHudHeaderPanels? panels = _headerPanels;
    final VideoDetailController? ctr = _videoDetailCtr;
    if (panels == null ||
        ctr == null ||
        ctr.isFileSource ||
        ctr.data.dash == null ||
        ctr.data.supportFormats == null) {
      return null;
    }
    return _single(
      TvHudActionId.decodeFormat,
      icon: Icons.av_timer_outlined,
      label: '解码格式',
      onPressed: () => _openUpstreamPanel(panels.showSetDecodeFormats),
    );
  }

  /// Animation only, as upstream (`PlPlayerController.isAnim`).
  TvHudAction? _superResolutionAction() {
    if (!_isVideo || !_pl.isAnim || !_hasPlayer) return null;
    return _single(
      TvHudActionId.superResolution,
      icon: Icons.auto_awesome_rounded,
      label: '超分辨率: ${_pl.superResolutionType.value.label}',
      onPressed: _showSuperResolutionDialog,
    );
  }

  Future<void> _showSuperResolutionDialog() async {
    final SuperResolutionType current = _pl.superResolutionType.value;
    await _showTvDialog((dialogContext) {
      return _TvOptionListDialog(
        title: '超分辨率',
        items: [
          for (final SuperResolutionType type in SuperResolutionType.values)
            _TvDialogOptionItem(
              title: type.label,
              selected: type == current,
              onSelect: () {
                Navigator.of(dialogContext).pop();
                _pl.setShader(type);
                SmartDialog.showToast('超分辨率：${type.label}');
              },
            ),
        ],
      );
    });
  }

  TvHudAction? _playerVolumeAction() {
    final Player? player = _pl.videoPlayerController;
    if (player == null || _pl.isPipMode) return null;
    return _single(
      TvHudActionId.playerVolume,
      icon: Icons.volume_up_rounded,
      label: '播放器音量: ${Pref.playerVolume.toStringAsFixed(0)}%',
      onPressed: () => _openUpstreamDialog(
        () => _upstream.showPlayerVolume(context, player),
      ),
    );
  }

  TvHudAction? _shutdownTimerAction() {
    if (_pl.isPipMode || Get.key.currentState == null) return null;
    return _single(
      TvHudActionId.shutdownTimer,
      icon: Icons.hourglass_top_rounded,
      label: '定时关闭',
      active: shutdownTimerService.isActive,
      onPressed: () => _openUpstreamPanel(
        () => _upstream.showShutdownTimer(
          context,
          isFullScreen: _isFullScreen,
          isLive: _pl.isLive,
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // 其他

  TvHudAction? _reloadAction() {
    final VoidCallback? reload;
    if (_isVideo) {
      final VideoDetailController? ctr = _videoDetailCtr;
      reload = ctr == null || ctr.isFileSource
          ? null
          : () => ctr.queryVideoUrl(fromReset: true);
    } else {
      reload = widget.onRefresh;
    }
    if (reload == null) return null;
    return _single(
      TvHudActionId.reload,
      icon: Icons.refresh_rounded,
      label: '重载视频',
      onPressed: () {
        _hideHud();
        reload!();
      },
    );
  }

  TvHudAction? _playerInfoAction() {
    final Player? player = _pl.videoPlayerController;
    if (player == null || _pl.isPipMode) return null;
    return _single(
      TvHudActionId.playerInfo,
      icon: Icons.info_outline_rounded,
      label: '播放信息',
      onPressed: () => _openUpstreamPanel(
        () => _upstream.showPlayerInfo(context, player),
      ),
    );
  }

  TvHudAction _editButtonsAction() => _single(
    TvHudActionId.editButtons,
    icon: Icons.edit_rounded,
    label: '编辑按钮',
    onPressed: _openEditor,
  );

  /// Upstream's whole `⋮` sheet, for anything the table leaves out (CDN 设置
  /// and the like).
  TvHudAction? _fullSettingsAction() {
    final TvHudHeaderPanels? panels = _headerPanels;
    if (panels == null) return null;
    return _single(
      TvHudActionId.fullSettings,
      icon: Icons.settings_rounded,
      label: '完整设置',
      onPressed: () => _openUpstreamPanel(panels.showSettingSheet),
    );
  }
}
