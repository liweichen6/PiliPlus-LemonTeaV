part of 'tv_navigation.dart';

// The scorer (M13.4): one scoring function over a snapshot of the candidates,
// with column memory, picks the target of every D-pad move. It became the
// default in M13.5, and M13.6 removed the rule chain it replaced; see
// `docs/tv/PLAN.md`.

/// One candidate of a decision, for the debug overlay and its tests.
@immutable
class TvFocusScore {
  const TvFocusScore({
    required this.node,
    required this.rect,
    this.score,
    this.dropped,
  });

  final FocusNode node;

  /// The rect the candidate was scored at: its visible part, or its whole
  /// rect when it's in a list the focused node is in.
  final Rect rect;

  /// Lower is better; null when the candidate was dropped.
  final double? score;

  /// Why it was dropped: `off` (off screen, in another list), `dir` (not in
  /// the direction), `sec` (an action of another card). Null when scored.
  final String? dropped;
}

/// The last decision the scorer made, for the debug overlay.
@immutable
class TvFocusDecision {
  const TvFocusDecision({
    required this.focusedRect,
    required this.direction,
    required this.scores,
    required this.chosen,
    required this.fromMemory,
  });

  final Rect focusedRect;
  final TraversalDirection direction;
  final List<TvFocusScore> scores;
  final FocusNode? chosen;

  /// Whether column memory chose [chosen] over the best score.
  final bool fromMemory;
}

/// A candidate in the snapshot of one decision.
class _TvCandidate {
  _TvCandidate({
    required this.node,
    required this.raw,
    required this.rect,
    required this.vertical,
    required this.horizontal,
  });

  final FocusNode node;

  /// Its whole rect.
  final Rect raw;

  /// The rect it's scored at.
  final Rect rect;
  final ScrollableState? vertical;
  final ScrollableState? horizontal;

  /// The card or tile it's an action of, if any.
  FocusNode? owner;

  /// Whether it's one of [owner]'s own actions: inside it in the focus tree,
  /// or laid wholly over it.
  bool ownedWholly = false;

  /// Whether it was scored in this decision.
  bool considered = false;
}

/// The scoring weights, in logical pixels.
abstract final class _TvScoreWeights {
  /// Per pixel of gap across the move.
  static const double across = 1.0;

  /// For a candidate with no overlap across the move at all, on Up and Down.
  static const double missingOverlap = 100.0;

  /// The same on Left and Right, where a node level with the focused one
  /// comes first, as it did in the old rule chain.
  static const double missingOverlapAcross = 600.0;

  /// For each list around the focused node that the candidate isn't in.
  static const double leaveGroup = 1000.0;

  /// Per pixel of the tie-break offset.
  static const double tie = 0.05;
}

/// Column memory: the node focus last left each list or tab bar from. A
/// navigation rail or a focus traversal group has none: the rail is a menu,
/// and on `<vm-tv>` it kept the avatar focused at start-up, so every Left
/// from the grid went there instead of the item level with the card.
class _TvColumnMemory {
  final Expando<FocusNode> _last = Expando<FocusNode>('TvColumnMemory');

  static bool _remembers(Object group) =>
      group is ScrollableState || (group as Element).widget is TabBar;

  FocusNode? operator [](Object group) =>
      _remembers(group) ? _last[group] : null;

  void remember(List<Object> groups, FocusNode node) {
    for (final Object group in groups) {
      if (_remembers(group)) _last[group] = node;
    }
  }
}

/// The groups around [node], nearest first: each list the user can scroll
/// (its [ScrollableState]), and each tab bar, navigation rail and focus
/// traversal group (its [Element]).
///
/// With [until], the walk stops at the first of those groups it meets, and
/// leaves it out. Every group further out is around that one too, so the
/// result is the groups around [node] that aren't in [until], at the cost of
/// a short walk when [node] shares a list with the node [until] came from.
List<Object> _tvGroupsOf(FocusNode node, {List<Object>? until}) {
  final BuildContext? context = node.context;
  if (context == null || !context.mounted) return const <Object>[];
  final List<Object> groups = <Object>[];
  context.visitAncestorElements((Element element) {
    final Object group;
    if (element is StatefulElement && element.state is ScrollableState) {
      final ScrollableState scrollable = element.state as ScrollableState;
      if (!TvFocusTraversalPolicy._canUserScroll(scrollable)) return true;
      group = scrollable;
    } else {
      final Widget widget = element.widget;
      if (widget is! TabBar &&
          widget is! NavigationRail &&
          widget is! FocusTraversalGroup) {
        return true;
      }
      group = element;
    }
    if (until != null && until.contains(group)) return false;
    groups.add(group);
    return true;
  });
  return groups;
}


extension _TvScorerPolicy on TvFocusTraversalPolicy {
  /// [rect] clipped to the lists around it and the screen.
  Rect _visibleRect(
    Rect rect,
    ScrollableState? vertical,
    ScrollableState? horizontal,
    Rect? screen,
    _TvTraversalCache cache,
  ) {
    Rect visible = rect;
    final Rect? v = cache.scrollableRect(vertical);
    if (v != null) visible = visible.intersect(v);
    final Rect? h = cache.scrollableRect(horizontal);
    if (h != null) visible = visible.intersect(h);
    if (screen != null) visible = visible.intersect(screen);
    return visible;
  }

  static bool _hasArea(Rect r) => r.width > 1.0 && r.height > 1.0;

  /// Whether [node] is inside [list] in the widget tree, such as in a list
  /// nested in it, rather than floating over it.
  static bool _isInsideList(FocusNode node, ScrollableState list) {
    final BuildContext? context = node.context;
    if (context == null || !context.mounted) return false;
    final BuildContext listContext = list.context;
    bool inside = false;
    context.visitAncestorElements((Element element) {
      if (identical(element, listContext)) {
        inside = true;
        return false;
      }
      return true;
    });
    return inside;
  }

  /// The part of [raw] that counts for a candidate, or null if it doesn't
  /// show. Along a list it shares with the focused node it's kept whole;
  /// along any other list it must show as the old rule chain asked (its centre
  /// inside, or half of the list), and is clipped to it and to the screen.
  Rect? _shownRect(
    Rect raw,
    ScrollableState? vertical,
    ScrollableState? horizontal, {
    required bool sharesVertical,
    required bool sharesHorizontal,
    required Rect? screen,
    required _TvTraversalCache cache,
  }) {
    double top = raw.top;
    double bottom = raw.bottom;
    double left = raw.left;
    double right = raw.right;
    if (!sharesVertical) {
      final Rect? list = cache.scrollableRect(vertical);
      if (list != null) {
        if (!TvFocusTraversalPolicy._isRectVisibleInScrollable(raw, list)) {
          return null;
        }
        top = math.max(top, list.top);
        bottom = math.min(bottom, list.bottom);
      }
      if (screen != null) {
        top = math.max(top, screen.top);
        bottom = math.min(bottom, screen.bottom);
      }
      if (bottom - top <= 1.0) return null;
    }
    if (!sharesHorizontal) {
      final Rect? list = cache.scrollableRect(horizontal);
      if (list != null) {
        if (!TvFocusTraversalPolicy._isRectVisibleHorizontallyInScrollable(
          raw,
          list,
        )) {
          return null;
        }
        left = math.max(left, list.left);
        right = math.min(right, list.right);
      }
      if (screen != null) {
        left = math.max(left, screen.left);
        right = math.min(right, screen.right);
      }
      if (right - left <= 1.0) return null;
    }
    return Rect.fromLTRB(left, top, right, bottom);
  }

  /// Whether [c] lies past [f] in [direction], and isn't level with it.
  static bool _inDirection(Rect c, Rect f, TraversalDirection direction) {
    final bool vertical =
        direction == TraversalDirection.up ||
        direction == TraversalDirection.down;
    final double overlapAlong = vertical
        ? math.min(c.bottom, f.bottom) - math.max(c.top, f.top)
        : math.min(c.right, f.right) - math.max(c.left, f.left);
    final double smaller = vertical
        ? math.min(c.height, f.height)
        : math.min(c.width, f.width);
    if (overlapAlong > smaller * 0.5) return false;
    return switch (direction) {
      TraversalDirection.down =>
        c.center.dy > f.center.dy + 0.5 && c.bottom > f.bottom + 0.5,
      TraversalDirection.up =>
        c.center.dy < f.center.dy - 0.5 && c.top < f.top - 0.5,
      TraversalDirection.right =>
        c.center.dx > f.center.dx + 0.5 && c.right > f.right + 0.5,
      TraversalDirection.left =>
        c.center.dx < f.center.dx - 0.5 && c.left < f.left - 0.5,
    };
  }

  /// Where [group], one of the focused node's groups, lies, or null if it
  /// isn't laid out. Looked up once per decision.
  static Rect? _groupRect(Object group, _TvTraversalCache cache) {
    if (group is ScrollableState) return cache.scrollableRect(group);
    final RenderObject? ro = (group as Element).renderObject;
    return ro is RenderBox && ro.attached && ro.hasSize
        ? cache.boxRect(ro)
        : null;
  }

  /// Whether [c] is in [group], one of the focused node's groups, which lies
  /// at [groupRect]: by its lists for a list, and by where it lies for a tab
  /// bar, rail or focus traversal group.
  static bool _inGroup(_TvCandidate c, Object group, Rect? groupRect) {
    // A list further out than the nearest one on each axis. A candidate that
    // isn't in one of the focused node's lists is scored at what shows of it,
    // so where it lies says whether it's inside.
    if (group is ScrollableState &&
        (c.vertical == group || c.horizontal == group)) {
      return true;
    }
    return groupRect != null && groupRect.contains(c.rect.center);
  }

  /// The score of [c] at [r], seen from [f]: lower is better.
  static double _score(
    _TvCandidate c,
    Rect r,
    Rect f,
    TraversalDirection direction,
    List<Object> focusedGroups,
    List<Rect?> groupRects,
  ) {
    final bool vertical =
        direction == TraversalDirection.up ||
        direction == TraversalDirection.down;
    final double along = math.max(0.0, switch (direction) {
      TraversalDirection.down => r.top - f.bottom,
      TraversalDirection.up => f.top - r.bottom,
      TraversalDirection.right => r.left - f.right,
      TraversalDirection.left => f.left - r.right,
    });
    final double cStart = vertical ? r.left : r.top;
    final double cEnd = vertical ? r.right : r.bottom;
    final double fStart = vertical ? f.left : f.top;
    final double fEnd = vertical ? f.right : f.bottom;
    final double gap = math.max(
      0.0,
      math.max(cStart - fEnd, fStart - cEnd),
    );
    final double overlap = math.max(
      0.0,
      math.min(cEnd, fEnd) - math.max(cStart, fStart),
    );
    final double narrower = math.min(cEnd - cStart, fEnd - fStart);
    final double missing = narrower > 0.0
        ? 1.0 - math.min(1.0, overlap / narrower)
        : 1.0;
    // On Up and Down, a candidate wholly inside a wider focused node is taken
    // in reading order, so a header leads to the start of the row under it;
    // otherwise the one whose centre is nearest across the move.
    final bool insideFocused =
        vertical &&
        cStart >= fStart - 1.0 &&
        cEnd <= fEnd + 1.0 &&
        (fEnd - fStart) > (cEnd - cStart) + 1.0;
    final double tie = insideFocused
        ? cStart - fStart
        : ((cStart + cEnd) - (fStart + fEnd)).abs() / 2.0;
    int left = 0;
    for (int i = 0; i < focusedGroups.length; i++) {
      if (!_inGroup(c, focusedGroups[i], groupRects[i])) left++;
    }
    return along +
        _TvScoreWeights.across * gap +
        (vertical
                ? _TvScoreWeights.missingOverlap
                : _TvScoreWeights.missingOverlapAcross) *
            missing +
        _TvScoreWeights.leaveGroup * left +
        _TvScoreWeights.tie * tie;
  }

  /// The scorer's pick for a move from [focusedChild] in [direction], among
  /// [allNodes] (the scope's focusable leaves past the focused node).
  FocusNode? _findScoredCandidate({
    required FocusNode focusedChild,
    required Rect visualTarget,
    required List<FocusNode> allNodes,
    required TraversalDirection direction,
    required _TvTraversalCache cache,
  }) {
    final bool record = TvFocusTraversalPolicy.debugRecordScores;
    final List<TvFocusScore>? scores = record ? <TvFocusScore>[] : null;

    // The focused node: its visible part, so a node cut off by its list is
    // measured by what shows of it (bug 8).
    final ScrollableState? fV = cache.verticalScrollableOf(focusedChild);
    final ScrollableState? fH = cache.horizontalScrollableOf(focusedChild);
    final Rect fRaw = cache.rectOf(focusedChild);
    final RenderObject? fRo = focusedChild.context?.findRenderObject();
    final Rect? screen = fRo is RenderBox ? cache.viewportRectOf(fRo) : null;
    Rect f = _visibleRect(fRaw, fV, fH, screen, cache);
    if (!_hasArea(f)) f = visualTarget;

    // 1. The snapshot: every candidate once, with its rect, lists and role.
    final Set<FocusNode> ancestors = focusedChild.ancestors.toSet();
    final List<_TvCandidate> kept = <_TvCandidate>[];
    for (final FocusNode node in allNodes) {
      if (ancestors.contains(node)) continue;
      final Rect raw = cache.rectOf(node);
      final ScrollableState? v = cache.verticalScrollableOf(node);
      final ScrollableState? h = cache.horizontalScrollableOf(node);
      // Along a list the focused node is in, a node gets scrolled into view,
      // so it counts wherever it is. Along any other list, or with no list,
      // it counts only if it shows, and is measured by what shows.
      final Rect? shown = _shownRect(
        raw,
        v,
        h,
        sharesVertical: fV != null && v == fV,
        sharesHorizontal: fH != null && h == fH,
        screen: screen,
        cache: cache,
      );
      if (shown == null) {
        scores?.add(TvFocusScore(node: node, rect: raw, dropped: 'off'));
        continue;
      }
      kept.add(
        _TvCandidate(
          node: node,
          raw: raw,
          rect: shown,
          vertical: v,
          horizontal: h,
        ),
      );
    }

    // The focused node's own card, when it's a button inside one.
    FocusNode? focusedOwner;
    final bool focusedIsAction = cache.enclosingActionOf(focusedChild) != null;
    // A focus ancestor with no tile or card above it in the element tree
    // can't be a card or tile itself, unless its own widget is a card, so
    // it's passed over without measuring it, which would walk to the root.
    // So the focused node's element ancestors are kept by depth, with the
    // depth of the outermost tile or card among them.
    List<Element?> chain = const <Element?>[];
    int outermost = 1 << 30;
    final BuildContext? fContext = focusedChild.context;
    if (focusedIsAction && fContext is Element && fContext.mounted) {
      chain = List<Element?>.filled(fContext.depth, null);
      fContext.visitAncestorElements((Element element) {
        if (element.depth < chain.length) chain[element.depth] = element;
        final Widget widget = element.widget;
        if (tvListTiles.isGroup(widget) || tvCards.isGroup(widget)) {
          outermost = element.depth;
        }
        return true;
      });
    }
    for (final FocusNode ancestor
        in focusedIsAction ? focusedChild.ancestors : const <FocusNode>[]) {
      final BuildContext? ac = ancestor.context;
      if (ac is Element &&
          ac.mounted &&
          ac.depth < chain.length &&
          identical(chain[ac.depth], ac) &&
          outermost >= ac.depth &&
          !tvCards.isGroup(ac.widget)) {
        continue;
      }
      if (cache.isEffectivelyFocusable(ancestor) &&
          TvFocusTraversalPolicy._isPrimaryContainer(ancestor, cache) &&
          TvFocusTraversalPolicy._isEmbeddedSecondaryOf(
            focusedChild,
            ancestor,
            cache,
          )) {
        focusedOwner = ancestor;
        break;
      }
    }
    final FocusNode? treeOwner = focusedOwner;

    // Roles, among the nodes that are in the snapshot: an action belongs to
    // the card or tile it's inside in the focus tree, or, if it's small, to
    // the one it's laid over. A node off screen in another list can't own
    // anything, so it can't hide the rail's buttons (bug 7).
    final Map<FocusNode, _TvCandidate> byNode = <FocusNode, _TvCandidate>{
      for (final _TvCandidate c in kept) c.node: c,
    };
    bool isContainer(FocusNode node) =>
        node == focusedChild || node == treeOwner || byNode.containsKey(node);
    // The cards a small action can be laid over, with what shows of each: a
    // card cut off by its list can only own the actions over its visible
    // part. Built once, on the first small action without an owner.
    List<(FocusNode, Rect)>? containers;
    for (final _TvCandidate c in kept) {
      for (final FocusNode ancestor in c.node.ancestors) {
        if (!isContainer(ancestor)) continue;
        if (TvFocusTraversalPolicy._isEmbeddedSecondaryOf(
          c.node,
          ancestor,
          cache,
        )) {
          c
            ..owner = ancestor
            ..ownedWholly = true;
          break;
        }
      }
      if (c.owner != null || !tvCards.isMicroAction(c.raw)) continue;
      containers ??= <(FocusNode, Rect)>[
        (focusedChild, f),
        for (final _TvCandidate k in kept) (k.node, k.rect),
      ];
      for (final (FocusNode container, Rect cr) in containers) {
        if (container == c.node) continue;
        if (tvCards.isSecondaryIn(c.raw, cr)) {
          c
            ..owner = container
            ..ownedWholly =
                cr.inflate(0.5).contains(c.raw.topLeft) &&
                cr.inflate(0.5).contains(c.raw.bottomRight);
          break;
        }
      }
    }

    // Or the card a small focused action is laid wholly over.
    if (focusedOwner == null && tvCards.isMicroAction(fRaw)) {
      for (final _TvCandidate c in kept) {
        if (c.owner == null &&
            TvFocusTraversalPolicy._isPrimaryContainer(c.node, cache) &&
            c.rect.inflate(0.5).contains(fRaw.topLeft) &&
            c.rect.inflate(0.5).contains(fRaw.bottomRight)) {
          focusedOwner = c.node;
          break;
        }
      }
    }

    final bool horizontalMove =
        direction == TraversalDirection.left ||
        direction == TraversalDirection.right;
    final bool isRight = direction == TraversalDirection.right;

    FocusNode? finish(FocusNode? chosen, {bool fromMemory = false}) {
      if (scores != null) {
        TvFocusTraversalPolicy.debugLastDecision.value = TvFocusDecision(
          focusedRect: f,
          direction: direction,
          scores: scores,
          chosen: chosen,
          fromMemory: fromMemory,
        );
      }
      return chosen;
    }

    // 2. Moves inside a tile or card, as the old rule chain made them.
    if (horizontalMove) {
      final Element? focusedRow = cache.enclosingRowOf(focusedChild);
      if (focusedRow != null) {
        // A tile's trailing control, and back.
        final List<FocusNode> inRow = <FocusNode>[
          for (final FocusNode node in allNodes)
            if (isRight
                ? node.ancestors.contains(focusedChild) &&
                      cache.enclosingRowOf(node) == focusedRow &&
                      tvListTiles.isSecondaryIn(cache.rectOf(node), fRaw)
                : focusedChild.ancestors.contains(node) &&
                      cache.enclosingRowOf(node) == focusedRow &&
                      tvListTiles.isSecondaryIn(fRaw, cache.rectOf(node)))
              node,
        ];
        if (inRow.isNotEmpty) {
          inRow.sort(
            (FocusNode a, FocusNode b) => isRight
                ? cache.rectOf(a).left.compareTo(cache.rectOf(b).left)
                : cache.rectOf(b).left.compareTo(cache.rectOf(a).left),
          );
          return finish(inRow.first);
        }
      }
      if (focusedOwner != null) {
        // Along a card's actions, and Left from the first back to the card.
        _TvCandidate? best;
        double bestDistance = double.infinity;
        for (final _TvCandidate c in kept) {
          if (c.owner != focusedOwner || !c.ownedWholly) continue;
          final Rect r = c.raw;
          if (r.bottom <= fRaw.top + 1.0 || r.top >= fRaw.bottom - 1.0) {
            continue;
          }
          final double distance = isRight
              ? r.center.dx - fRaw.center.dx
              : fRaw.center.dx - r.center.dx;
          if (distance <= 4.0) continue;
          if (distance < bestDistance) {
            best = c;
            bestDistance = distance;
          }
        }
        if (best != null) return finish(best.node);
        if (!isRight) return finish(focusedOwner);
      }
    }

    // 3. Score every candidate in the direction. Actions of other cards are
    // left out: they're reached from their own card. A control floating over
    // the focused list, such as 播放全部 or the reply button, counts as lying
    // just past the list's end, so it's reached once nothing in the list is
    // left in this direction (bug 2).
    final List<Object> focusedGroups =
        cache.groupsOf(focusedChild) ?? _tvGroupsOf(focusedChild);
    // The groups that cost to leave: every list, and a tab bar, rail or focus
    // traversal group only inside the nearest list, where what shows of a
    // candidate says whether it's in one.
    final int firstList = focusedGroups.indexWhere(
      (Object g) => g is ScrollableState,
    );
    final List<Object> costGroups = <Object>[
      for (int i = 0; i < focusedGroups.length; i++)
        if (focusedGroups[i] is ScrollableState ||
            firstList < 0 ||
            i < firstList)
          focusedGroups[i],
    ];
    final List<Rect?> groupRects = <Rect?>[
      for (final Object g in costGroups) _groupRect(g, cache),
    ];
    final ScrollableState? alongList = horizontalMove ? fH : fV;
    final Rect? alongRect = cache.scrollableRect(alongList);
    _TvCandidate? best;
    double bestScore = double.infinity;
    bool listAhead = false;
    final List<_TvCandidate> own = <_TvCandidate>[];
    final List<_TvCandidate> floating = <_TvCandidate>[];

    void consider(_TvCandidate c, Rect at, Rect from) {
      final double score = _score(
        c,
        at,
        from,
        direction,
        costGroups,
        groupRects,
      );
      c.considered = true;
      scores?.add(TvFocusScore(node: c.node, rect: c.rect, score: score));
      if (score < bestScore) {
        best = c;
        bestScore = score;
      }
    }

    for (final _TvCandidate c in kept) {
      if (c.owner != null) {
        if (c.owner == focusedChild &&
            c.ownedWholly &&
            cache.enclosingActionOf(c.node) != null) {
          own.add(c);
        }
        scores?.add(TvFocusScore(node: c.node, rect: c.rect, dropped: 'sec'));
        continue;
      }
      if (c.node == focusedOwner) {
        scores?.add(TvFocusScore(node: c.node, rect: c.rect, dropped: 'dir'));
        continue;
      }
      final ScrollableState? cList = horizontalMove ? c.horizontal : c.vertical;
      if (alongRect != null &&
          cList != alongList &&
          alongRect.contains(c.rect.center) &&
          !_isInsideList(c.node, alongList!)) {
        floating.add(c);
        continue;
      }
      // Up inside the focused list goes by scroll order: a pinned or
      // floating header is measured where it sits in the list, not where it's
      // drawn, as the old rule chain did.
      final Rect from =
          direction == TraversalDirection.up &&
              alongList != null &&
              cList == alongList
          ? fRaw
          : f;
      if (!_inDirection(c.rect, from, direction)) {
        scores?.add(TvFocusScore(node: c.node, rect: c.rect, dropped: 'dir'));
        continue;
      }
      if (alongList != null && cList == alongList) listAhead = true;
      consider(c, c.rect, from);
    }
    for (final _TvCandidate c in floating) {
      final Rect r = c.rect;
      final bool past = switch (direction) {
        TraversalDirection.down => r.center.dy > f.center.dy,
        TraversalDirection.up => r.center.dy < f.center.dy,
        TraversalDirection.right => r.center.dx > f.center.dx,
        TraversalDirection.left => r.center.dx < f.center.dx,
      };
      if (listAhead || !past) {
        scores?.add(TvFocusScore(node: c.node, rect: r, dropped: 'dir'));
        continue;
      }
      consider(
        c,
        switch (direction) {
          TraversalDirection.down => r.shift(
            Offset(0.0, math.max(0.0, f.bottom - r.top)),
          ),
          TraversalDirection.up => r.shift(
            Offset(0.0, math.min(0.0, f.top - r.bottom)),
          ),
          TraversalDirection.right => r.shift(
            Offset(math.max(0.0, f.right - r.left), 0.0),
          ),
          TraversalDirection.left => r.shift(
            Offset(math.min(0.0, f.left - r.right), 0.0),
          ),
        },
        f,
      );
    }

    final _TvCandidate? winner = best;
    if (winner == null) {
      // Right from a card with nothing past it: its own actions.
      if (isRight && focusedOwner == null && own.isNotEmpty) {
        return finish(
          TvFocusTraversalPolicy._findFirstReadingOrderNode(<FocusNode>[
            for (final _TvCandidate c in own) c.node,
          ], cache),
        );
      }
      return finish(null);
    }

    // 4. Column memory: entering a list focus left before returns to the
    // node it left from, if that node is still there in this direction.
    _memory.remember(focusedGroups, focusedChild);
    final List<Object> entered = _tvGroupsOf(
      winner.node,
      until: focusedGroups,
    );
    if (entered.isNotEmpty) {
      final FocusNode? remembered = _memory[entered.last];
      final _TvCandidate? c = remembered == null ? null : byNode[remembered];
      if (c != null && remembered != winner.node && c.considered) {
        if (_hasArea(
          _visibleRect(c.raw, c.vertical, c.horizontal, screen, cache),
        )) {
          return finish(remembered, fromMemory: true);
        }
      }
      // 5. With nothing to return to, focus coming into a tab bar from one of
      // its own pages lands on the tab that's showing, if that tab lies over
      // the focused node (the user's decision in M13.5). Otherwise it's the
      // tab the score picked, such as the one straight above a card.
      final FocusNode? showing = _showingTab(
        entered,
        focusedChild,
        allNodes,
        byNode,
        screen,
        cache,
      );
      if (showing != null) {
        final Rect r = byNode[showing]!.rect;
        final bool over = horizontalMove
            ? math.min(r.bottom, f.bottom) - math.max(r.top, f.top) > 0.0
            : math.min(r.right, f.right) - math.max(r.left, f.left) > 0.0;
        if (over) return finish(showing);
      }
    }
    return finish(winner.node);
  }

  /// The controller of [tabBar], if [focusedChild] is on one of its pages.
  /// It walks to the root, but only on a move into a tab bar.
  static TabController? _controllerOfPageOf(
    Element tabBar,
    FocusNode focusedChild,
  ) {
    final TabController? controller =
        (tabBar.widget as TabBar).controller ??
        DefaultTabController.maybeOf(tabBar);
    if (controller == null) return null;
    final BuildContext? context = focusedChild.context;
    if (context == null || !context.mounted) return null;
    bool onPage = false;
    context.visitAncestorElements((Element element) {
      final Widget widget = element.widget;
      if (widget is TabBarView &&
          identical(
            widget.controller ?? DefaultTabController.maybeOf(element),
            controller,
          )) {
        onPage = true;
        return false;
      }
      return true;
    });
    return onPage ? controller : null;
  }

  /// The tab that's showing in the first tab bar of [entered], if
  /// [focusedChild] is on one of that tab bar's pages, and that tab was
  /// scored in this decision and shows. The tabs are the candidates inside
  /// the tab bar, in focus order, one per tab.
  FocusNode? _showingTab(
    List<Object> entered,
    FocusNode focusedChild,
    List<FocusNode> allNodes,
    Map<FocusNode, _TvCandidate> byNode,
    Rect? screen,
    _TvTraversalCache cache,
  ) {
    Element? tabBar;
    for (final Object g in entered) {
      if (g is Element && g.widget is TabBar) {
        tabBar = g;
        break;
      }
    }
    if (tabBar == null) return null;
    final TabController? controller = _controllerOfPageOf(tabBar, focusedChild);
    if (controller == null) return null;
    final Element bar = tabBar;
    final List<FocusNode> tabs = <FocusNode>[
      for (final FocusNode node in allNodes)
        if (_isUnder(node, bar)) node,
    ];
    if (tabs.length != controller.length) return null;
    final _TvCandidate? c = byNode[tabs[controller.index]];
    if (c == null ||
        !c.considered ||
        !_hasArea(
          _visibleRect(c.raw, c.vertical, c.horizontal, screen, cache),
        )) {
      return null;
    }
    return c.node;
  }

  /// Whether [node] is inside [ancestor] in the widget tree.
  static bool _isUnder(FocusNode node, Element ancestor) {
    final BuildContext? context = node.context;
    if (context is! Element || !context.mounted) return false;
    if (context.depth <= ancestor.depth) return false;
    bool under = false;
    context.visitAncestorElements((Element element) {
      if (identical(element, ancestor)) {
        under = true;
        return false;
      }
      return element.depth > ancestor.depth;
    });
    return under;
  }
}

/// The debug overlay: each candidate of the scorer's last decision, outlined
/// with its score or why it was dropped. Built only while
/// [TvFocusTraversalPolicy.debugRecordScores] is on.
class _TvScoreOverlay extends StatelessWidget {
  const _TvScoreOverlay();

  @override
  Widget build(BuildContext context) => IgnorePointer(
    child: RepaintBoundary(
      child: ValueListenableBuilder<TvFocusDecision?>(
        valueListenable: TvFocusTraversalPolicy.debugLastDecision,
        builder: (BuildContext context, TvFocusDecision? decision, _) =>
            CustomPaint(painter: _TvScoreOverlayPainter(decision)),
      ),
    ),
  );
}

class _TvScoreOverlayPainter extends CustomPainter {
  const _TvScoreOverlayPainter(this.decision);

  final TvFocusDecision? decision;

  static const Color _chosen = Color(0xFF06D6A0);
  static const Color _scored = Color(0xFFFFFFFF);
  static const Color _dropped = Color(0x99888888);
  static const Color _focused = Color(0xFFEF476F);

  void _label(Canvas canvas, Offset at, String text, Color color) {
    TextPainter(
        text: TextSpan(
          text: text,
          style: TextStyle(
            color: color,
            fontSize: 10,
            backgroundColor: const Color(0xCC000000),
          ),
        ),
        textDirection: TextDirection.ltr,
      )
      ..layout()
      ..paint(canvas, at)
      ..dispose();
  }

  @override
  void paint(Canvas canvas, Size size) {
    final TvFocusDecision? d = decision;
    if (d == null) return;
    final Paint stroke = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;
    canvas.drawRect(d.focusedRect, stroke..color = _focused);
    for (final TvFocusScore s in d.scores) {
      final bool chosen = identical(s.node, d.chosen);
      final Color color = chosen
          ? _chosen
          : (s.score != null ? _scored : _dropped);
      canvas.drawRect(
        s.rect,
        stroke
          ..color = color
          ..strokeWidth = chosen ? 2.0 : 1.0,
      );
      final String text = s.score != null
          ? s.score!.toStringAsFixed(0) +
                (chosen && d.fromMemory ? ' (memory)' : '')
          : s.dropped!;
      _label(canvas, s.rect.topLeft + const Offset(2, 2), text, color);
    }
  }

  @override
  bool shouldRepaint(_TvScoreOverlayPainter oldDelegate) =>
      !identical(decision, oldDelegate.decision);
}
