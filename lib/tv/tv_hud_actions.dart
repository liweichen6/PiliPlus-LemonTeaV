part of 'tv_player_hud.dart';

// The TV player HUD's action table (M14.2, docs/tv/PLAN.md, Milestone M14).
//
// Every function the HUD offers is one entry here: a fixed id, an icon, a
// label (with the current value where it matters), when it's available and
// what it does. An entry that isn't available resolves to no buttons, so the
// HUD hides it rather than showing it disabled. M14.3 builds the `⋮` menu and
// the editable groups from this table; until then the HUD's existing bottom
// row draws its buttons from it.

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
/// The names are the ids that M14.3 saves in the settings box for the
/// editable groups, so an entry is never renamed; an id that's no longer
/// known is skipped when the saved lists are read. Within a group the order
/// is the `⋮` menu's order.
enum TvHudActionId {
  quality(TvHudMenuGroup.play),
  speed(TvHudMenuGroup.play),
  videoFit(TvHudMenuGroup.play),
  subtitle(TvHudMenuGroup.play),

  /// 上集 / 下集 / 选集 while the video is in a list (an episode list, parts or
  /// a collection), otherwise 下个视频; nothing when there's nothing to play
  /// next.
  episodes(TvHudMenuGroup.play),
  playOrder(TvHudMenuGroup.play),
  danmakuToggle(TvHudMenuGroup.danmaku),
  danmakuSettings(TvHudMenuGroup.danmaku),
  dmChart(TvHudMenuGroup.danmaku),
  danmakuPool(TvHudMenuGroup.danmaku),
  like(TvHudMenuGroup.interact),
  coin(TvHudMenuGroup.interact),
  favorite(TvHudMenuGroup.interact),
  watchLater(TvHudMenuGroup.interact),
  audioQuality(TvHudMenuGroup.pictureAndSound),
  decodeFormat(TvHudMenuGroup.pictureAndSound),
  superResolution(TvHudMenuGroup.pictureAndSound),
  playerVolume(TvHudMenuGroup.pictureAndSound),
  shutdownTimer(TvHudMenuGroup.pictureAndSound),
  reload(TvHudMenuGroup.other),
  playerInfo(TvHudMenuGroup.other),
  fullSettings(TvHudMenuGroup.other),

  /// Opens the button editor. The editor comes with M14.3, so until then this
  /// entry is never available.
  editButtons(TvHudMenuGroup.other, pinnable: false);

  const TvHudActionId(this.group, {this.pinnable = true});

  final TvHudMenuGroup group;

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
      TvHudActionId.editButtons => null,
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
    await _showTvDialog((dialogContext) {
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
  /// TV). M14.3 draws the chart on the time bar.
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
