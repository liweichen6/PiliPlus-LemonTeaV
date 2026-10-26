part of 'tv_navigation.dart';

/// One modal layer drawn above the page that opened it.
///
/// "A new layer appears but focus stays on the page behind it" has had to be
/// fixed once per kind of layer: popup routes that skip auto-focus (M6), inline
/// `MiniScaffold` sheets (M9) and overlay dialogs outside the `Navigator`
/// (M10). A provider answers the same few questions for its kind of layer, and
/// [_TvFocusLayerStack] owns the lifecycle they share: remember the trigger,
/// move focus into the layer, keep the page behind it unfocusable, and give
/// focus back to the trigger when the layer closes.
abstract class _TvFocusLayer {
  /// Whether [node] belongs to this layer.
  bool contains(FocusNode node);

  /// Whether [node] sits behind this layer. Such a node is not focusable and
  /// gets no focus ring while the layer is open.
  bool occludes(FocusNode node);

  /// Where focus goes when the layer opens, or `null` while it has nothing
  /// focusable yet.
  FocusNode? firstFocus(TvFocusTraversalPolicy policy);
}

abstract class _TvFocusLayerProvider {
  /// The layers of this kind that are open right now, bottom first.
  ///
  /// The stack asks every frame, so this must return a shared empty list
  /// without walking the tree when nothing is open.
  List<_TvFocusLayer> discover();
}

class _TvFocusLayerRecord {
  _TvFocusLayerRecord(
    this.layer, {
    this.savedFocusNode,
    this.savedScope,
    this.savedRect,
  });

  final _TvFocusLayer layer;

  /// The page node that had focus when the layer opened, where focus goes back
  /// to when the layer closes.
  final FocusNode? savedFocusNode;

  /// [savedFocusNode]'s scope and focus ring, for recovering near the trigger
  /// once the trigger itself is gone.
  final FocusScopeNode? savedScope;
  final Rect? savedRect;

  bool promoted = false;

  /// Until this frame time the focus ring is re-measured every frame. A layer
  /// that opens with a scale or slide transition keeps moving for a while after
  /// focus lands in it, and the stationary fast path ignores transforms.
  Duration? settleUntil;
}

class _TvFocusLayerStack {
  _TvFocusLayerStack({
    required this.providers,
    required this.policy,
    required this.showRing,
    required this.currentRing,
  });

  /// The stack of the mounted [TvNavigation]. [_TvTraversalCache] reads it so
  /// that every focusability check knows which layers are open, including the
  /// static [TvFocusTraversalPolicy.isEffectivelyFocusable].
  static _TvFocusLayerStack? current;

  static const Duration _kSettleWindow = Duration(milliseconds: 500);

  final List<_TvFocusLayerProvider> providers;
  final TvFocusTraversalPolicy policy;

  /// Publishes the focus ring around a node that just received focus.
  final void Function(FocusNode node) showRing;
  final Rect? Function() currentRing;

  /// Open layers, bottom first.
  final List<_TvFocusLayerRecord> _records = <_TvFocusLayerRecord>[];

  /// Whether [node] is behind an open layer. O(1) when no layer is open.
  bool occludes(FocusNode node) {
    if (_records.isEmpty) return false;
    for (final _TvFocusLayerRecord record in _records) {
      if (record.layer.occludes(node)) return true;
    }
    return false;
  }

  List<_TvFocusLayer> _discover() {
    List<_TvFocusLayer>? open;
    for (final _TvFocusLayerProvider provider in providers) {
      final List<_TvFocusLayer> layers = provider.discover();
      if (layers.isEmpty) continue;
      open = open == null ? layers : <_TvFocusLayer>[...open, ...layers];
    }
    return open ?? const <_TvFocusLayer>[];
  }

  static bool _isInside(_TvFocusLayer layer, FocusNode? node) =>
      node != null && node is! FocusScopeNode && layer.contains(node);

  /// Whether [reconcile] has something to do. Pure and cheap, so the per-frame
  /// callback can ask before its stationary fast path: with no layer open and
  /// none recorded it is a single empty-list check.
  bool hasPendingWork(FocusNode? primary) {
    final List<_TvFocusLayer> open = _discover();
    if (open.isEmpty) return _records.isNotEmpty;
    if (open.length != _records.length) return true;
    for (int i = 0; i < open.length; i++) {
      if (!identical(open[i], _records[i].layer)) return true;
    }
    final _TvFocusLayerRecord top = _records.last;
    if (_isInside(top.layer, primary)) return !top.promoted;
    // Focus is outside the layer. Only report work that can be done: a layer
    // with nothing focusable yet must not keep requesting frames.
    return top.layer.firstFocus(policy) != null;
  }

  /// Whether the topmost layer opened recently enough that its focus ring may
  /// still be on the move.
  bool isSettling(Duration frameTime) {
    if (_records.isEmpty) return false;
    final Duration? until = _records.last.settleUntil;
    return until != null && frameTime < until;
  }

  /// Runs the shared lifecycle once. Call it outside of layout and paint.
  ///
  /// Returns `true` when it moved focus or is waiting on a layer that is not
  /// ready, so the caller must skip its own recovery: anything it would pick
  /// sits behind the layer.
  bool reconcile() {
    final List<_TvFocusLayer> open = _discover();
    if (open.isEmpty && _records.isEmpty) return false;
    final FocusNode? primary = FocusManager.instance.primaryFocus;
    final Duration now = SchedulerBinding.instance.currentSystemFrameTimeStamp;

    // Sync the records with the layers that are open now. The bottom-most
    // layer to close owns the page-level trigger focus returns to.
    final List<_TvFocusLayerRecord> next = <_TvFocusLayerRecord>[
      for (final _TvFocusLayer layer in open)
        _recordOf(layer) ?? _openRecord(layer, primary),
    ];
    _TvFocusLayerRecord? closed;
    for (final _TvFocusLayerRecord record in _records) {
      if (!open.any((_TvFocusLayer layer) => identical(layer, record.layer))) {
        closed ??= record;
      }
    }
    _records
      ..clear()
      ..addAll(next);

    bool acted = false;
    FocusNode? owner = primary;
    if (closed != null) {
      final FocusNode? restored = _restoreTarget(closed);
      if (restored != null) {
        _focus(restored);
        owner = restored;
        acted = true;
      }
    }

    if (_records.isNotEmpty) {
      final _TvFocusLayerRecord top = _records.last;
      if (_isInside(top.layer, owner)) {
        top.promoted = true;
      } else {
        // Opening, or focus left the layer (the focused node was rebuilt away,
        // or something on the page behind it asked for focus): move it in.
        final FocusNode? first = top.layer.firstFocus(policy);
        if (first != null) {
          top
            ..promoted = true
            ..settleUntil = now + _kSettleWindow;
          _focus(first);
        }
        // Without a target the layer is still loading: wait, don't leak focus
        // onto the page behind it.
        acted = true;
      }
    }
    return acted;
  }

  _TvFocusLayerRecord? _recordOf(_TvFocusLayer layer) {
    for (final _TvFocusLayerRecord record in _records) {
      if (identical(record.layer, layer)) return record;
    }
    return null;
  }

  _TvFocusLayerRecord _openRecord(_TvFocusLayer layer, FocusNode? primary) {
    // Only a real control is worth returning to. At startup focus can sit on
    // the Navigator's own node, which is not traversable: leave the record
    // without a trigger and let the generic recovery pick a target on close.
    if (primary == null ||
        primary is FocusScopeNode ||
        !(primary.context?.mounted ?? false) ||
        layer.contains(primary) ||
        !TvFocusTraversalPolicy.isEffectivelyFocusable(primary)) {
      return _TvFocusLayerRecord(layer);
    }
    return _TvFocusLayerRecord(
      layer,
      savedFocusNode: primary,
      savedScope: primary.nearestScope,
      savedRect: currentRing(),
    );
  }

  /// Where focus goes after [closed] is gone: its trigger, or when the trigger
  /// has left the tree, the best node near it. `null` leaves it to the
  /// caller's generic recovery.
  FocusNode? _restoreTarget(_TvFocusLayerRecord closed) {
    final FocusNode? saved = closed.savedFocusNode;
    if (saved != null &&
        (saved.context?.mounted ?? false) &&
        saved.canRequestFocus &&
        TvFocusTraversalPolicy.isEffectivelyFocusable(saved)) {
      return saved;
    }
    final FocusScopeNode? scope = closed.savedScope;
    if (scope == null || !(scope.context?.mounted ?? false)) return null;
    final FocusNode? recovered = policy.findRecoveryFocus(
      saved,
      scope,
      previousRect: closed.savedRect,
    );
    return recovered != null &&
            recovered.canRequestFocus &&
            (recovered.context?.mounted ?? false)
        ? recovered
        : null;
  }

  void _focus(FocusNode node) {
    node
      ..requestFocus()
      ..consumeKeyboardToken();
    showRing(node);
  }
}

/// Focusable content that lives outside the root `Navigator`, such as the
/// overlay entries `flutter_smart_dialog` inserts next to it.
///
/// [TvNavigation] puts an anchor [FocusNode] above its whole subtree. The root
/// `Navigator` attaches its own branch below the anchor, and so does every
/// focusable widget of an overlay entry, because no route or `FocusScope`
/// stands between it and the anchor. Nothing hands that content focus
/// (`flutter_smart_dialog` has no focus handling at all), so the page behind
/// it keeps focus, the focus ring and the D-pad. Overlay content is modal over
/// the whole `Navigator`: it is always above every route.
///
/// Non-interactive overlay content (toasts, loading, notifications) has no
/// focusable node and never forms a layer. Several overlay dialogs open at
/// once are one layer: focus starts at the first node in reading order.
class _OverlayFocusLayer implements _TvFocusLayer, _TvFocusLayerProvider {
  _OverlayFocusLayer(this.anchor);

  final FocusNode anchor;
  late final List<_TvFocusLayer> _open = <_TvFocusLayer>[this];

  NavigatorState? _navigator;
  bool _navigatorSearched = false;

  /// The root `Navigator`, found once. An anchor without one has no overlay
  /// layers, which is also the answer for [TvNavigation] placed inside a route.
  NavigatorState? _findNavigator() {
    final BuildContext? context = anchor.context;
    if (context is! Element || !context.mounted) return null;
    NavigatorState? found;
    void visit(Element element) {
      if (found != null) return;
      if (element is StatefulElement && element.state is NavigatorState) {
        found = element.state as NavigatorState;
        return;
      }
      element.visitChildren(visit);
    }

    context.visitChildren(visit);
    return found;
  }

  /// The child of [anchor] whose subtree holds the `Navigator`'s focus node.
  FocusNode? _navigatorBranch() {
    final NavigatorState? existing = _navigator;
    if (existing == null ? !_navigatorSearched : !existing.mounted) {
      _navigatorSearched = true;
      _navigator = _findNavigator();
    }
    final NavigatorState? navigator = _navigator;
    return navigator == null ? null : _branchOf(navigator.focusNode);
  }

  /// The child of [anchor] whose subtree holds [node], or `null` when [node] is
  /// not below the anchor.
  FocusNode? _branchOf(FocusNode node) {
    FocusNode? branch = node;
    while (branch != null && !identical(branch.parent, anchor)) {
      branch = branch.parent;
    }
    return branch;
  }

  static bool _isFocusable(FocusNode node) =>
      node.canRequestFocus &&
      !node.skipTraversal &&
      TvFocusTraversalPolicy.isEffectivelyFocusable(node);

  @override
  List<_TvFocusLayer> discover() {
    // Only the Navigator's branch below the anchor: nothing else is mounted.
    if (anchor.children.length < 2) return const <_TvFocusLayer>[];
    final FocusNode? navigatorBranch = _navigatorBranch();
    if (navigatorBranch == null) return const <_TvFocusLayer>[];
    for (final FocusNode branch in anchor.children) {
      if (identical(branch, navigatorBranch)) continue;
      if (_isFocusable(branch)) return _open;
      for (final FocusNode node in branch.descendants) {
        if (_isFocusable(node)) return _open;
      }
    }
    return const <_TvFocusLayer>[];
  }

  @override
  bool contains(FocusNode node) {
    final FocusNode? branch = _branchOf(node);
    return branch != null && !identical(branch, _navigatorBranch());
  }

  @override
  bool occludes(FocusNode node) => !contains(node);

  @override
  FocusNode? firstFocus(TvFocusTraversalPolicy policy) {
    final FocusNode? navigatorBranch = _navigatorBranch();
    if (navigatorBranch == null) return null;
    final List<FocusNode> candidates = <FocusNode>[];
    for (final FocusNode branch in anchor.children) {
      if (identical(branch, navigatorBranch)) continue;
      if (branch.canRequestFocus && !branch.skipTraversal) {
        candidates.add(branch);
      }
      candidates.addAll(branch.traversalDescendants);
    }
    return policy.findFirstFocusAmong(candidates);
  }
}
