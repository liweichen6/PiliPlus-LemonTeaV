part of 'tv_player_hud.dart';

// The HUD's editable groups (M14.3, docs/tv/PLAN.md, Milestone M14): the
// top-right group, the bottom group, `显示按钮文字` and whether the buttons
// sit above the time bar, saved in the settings box and read once each time
// the HUD opens.

/// The two editable groups, whether the bottom row shows its labels, and
/// whether it sits above the time bar.
@immutable
class TvHudGroups {
  const TvHudGroups({
    required this.topRight,
    required this.bottom,
    required this.showLabels,
    this.buttonsAboveBar = false,
  });

  /// Builds the groups from saved values: ids that aren't known, can't be
  /// pinned or are already in a group are skipped, and the top-right group
  /// keeps its first [maxTopRight]. A missing list or option falls back to its
  /// default; a saved empty list stays empty.
  factory TvHudGroups.fromSaved({
    Object? topRight,
    Object? bottom,
    Object? showLabels,
    Object? buttonsAboveBar,
  }) {
    final Set<TvHudActionId> seen = {};
    List<TvHudActionId> parse(Object? saved, List<TvHudActionId> fallback) {
      if (saved is! Iterable) return [...fallback.where(seen.add)];
      final List<TvHudActionId> ids = [];
      for (final Object? name in saved) {
        final TvHudActionId? id = TvHudActionId.values.asNameMap()[name];
        if (id != null && id.pinnable && seen.add(id)) ids.add(id);
      }
      return ids;
    }

    final List<TvHudActionId> top = parse(topRight, defaults.topRight);
    if (top.length > maxTopRight) {
      seen.removeAll(top.sublist(maxTopRight));
      top.removeRange(maxTopRight, top.length);
    }
    return TvHudGroups(
      topRight: List.unmodifiable(top),
      bottom: List.unmodifiable(parse(bottom, defaults.bottom)),
      showLabels: showLabels is bool ? showLabels : defaults.showLabels,
      buttonsAboveBar: buttonsAboveBar is bool
          ? buttonsAboveBar
          : defaults.buttonsAboveBar,
    );
  }

  /// The groups saved in [box], or the defaults where nothing is saved.
  factory TvHudGroups.read(Box<dynamic> box) => TvHudGroups.fromSaved(
    topRight: box.get(topRightKey),
    bottom: box.get(bottomKey),
    showLabels: box.get(showLabelsKey),
    buttonsAboveBar: box.get(buttonsAboveBarKey),
  );

  /// The saved groups; the defaults where the settings box isn't open (some
  /// widget tests).
  static TvHudGroups load() {
    try {
      return TvHudGroups.read(GStorage.setting);
    } catch (_) {
      return defaults;
    }
  }

  /// Settings-box keys. TV-only, so they live here and not in upstream's
  /// `SettingBoxKey`.
  static const String topRightKey = 'tvHudTopRight';
  static const String bottomKey = 'tvHudBottom';
  static const String showLabelsKey = 'tvHudShowLabels';
  static const String buttonsAboveBarKey = 'tvHudButtonsAboveBar';

  /// The top-right group is laid out in rows of this many buttons, aligned
  /// right; the first row's last place is the `⋮` button's.
  static const int topRightRowSize = 6;
  static const int topRightRows = 3;

  /// The top-right group's cap: 3 rows of 6, less the `⋮` button
  /// (the user, 2026-11-07).
  static const int maxTopRight = topRightRows * topRightRowSize - 1;

  /// Agreed with the user, 2026-11-07.
  static const TvHudGroups defaults = TvHudGroups(
    topRight: [
      TvHudActionId.danmakuToggle,
      TvHudActionId.danmakuSettings,
      TvHudActionId.dmChart,
    ],
    bottom: [
      TvHudActionId.episodes,
      TvHudActionId.quality,
      TvHudActionId.subtitle,
      TvHudActionId.speed,
      TvHudActionId.videoFit,
    ],
    showLabels: true,
  );

  final List<TvHudActionId> topRight;
  final List<TvHudActionId> bottom;

  /// `显示按钮文字`: the bottom row's buttons show their labels. The top-right
  /// group is always icon-only.
  final bool showLabels;

  /// `按钮在时间条上方`: the bottom row sits above the time bar instead of
  /// under it.
  final bool buttonsAboveBar;

  /// Every pinnable entry that's in neither group, in menu order.
  List<TvHudActionId> get unpinned => [
    for (final TvHudActionId id in TvHudActionId.values)
      if (id.pinnable && !topRight.contains(id) && !bottom.contains(id)) id,
  ];

  TvHudGroups copyWith({
    List<TvHudActionId>? topRight,
    List<TvHudActionId>? bottom,
    bool? showLabels,
    bool? buttonsAboveBar,
  }) => TvHudGroups(
    topRight: List.unmodifiable(topRight ?? this.topRight),
    bottom: List.unmodifiable(bottom ?? this.bottom),
    showLabels: showLabels ?? this.showLabels,
    buttonsAboveBar: buttonsAboveBar ?? this.buttonsAboveBar,
  );

  Future<void> save(Box<dynamic> box) => box.putAll(<String, Object>{
    topRightKey: [for (final TvHudActionId id in topRight) id.name],
    bottomKey: [for (final TvHudActionId id in bottom) id.name],
    showLabelsKey: showLabels,
    buttonsAboveBarKey: buttonsAboveBar,
  });

  /// Saves to the settings box; does nothing where it isn't open.
  void store() {
    try {
      unawaited(save(GStorage.setting));
    } catch (_) {}
  }

  @override
  bool operator ==(Object other) =>
      other is TvHudGroups &&
      const ListEquality<TvHudActionId>().equals(other.topRight, topRight) &&
      const ListEquality<TvHudActionId>().equals(other.bottom, bottom) &&
      other.showLabels == showLabels &&
      other.buttonsAboveBar == buttonsAboveBar;

  @override
  int get hashCode => Object.hash(
    Object.hashAll(topRight),
    Object.hashAll(bottom),
    showLabels,
    buttonsAboveBar,
  );

  @override
  String toString() =>
      'TvHudGroups(topRight: ${topRight.map((e) => e.name)}, '
      'bottom: ${bottom.map((e) => e.name)}, showLabels: $showLabels, '
      'buttonsAboveBar: $buttonsAboveBar)';
}
