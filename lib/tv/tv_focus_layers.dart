part of 'tv_navigation.dart';

class _TvFocusLayerRecord {
  _TvFocusLayerRecord(
    this.layer, {
    this.savedFocusNode,
    this.savedScope,
    this.savedRect,
  });

  final TvFocusLayer layer;

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

  final List<TvFocusLayerProvider> providers;
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

  List<TvFocusLayer> _discover() {
    List<TvFocusLayer>? open;
    for (final TvFocusLayerProvider provider in providers) {
      final List<TvFocusLayer> layers = provider.discover(policy);
      if (layers.isEmpty) continue;
      open = open == null ? layers : <TvFocusLayer>[...open, ...layers];
    }
    return open ?? const <TvFocusLayer>[];
  }

  static bool _isInside(TvFocusLayer layer, FocusNode? node) =>
      node != null && node is! FocusScopeNode && layer.contains(node);

  /// Whether [reconcile] has something to do. Pure and cheap, so the per-frame
  /// callback can ask before its stationary fast path: with no layer open and
  /// none recorded it is a single empty-list check.
  bool hasPendingWork(FocusNode? primary) {
    final List<TvFocusLayer> open = _discover();
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
    final List<TvFocusLayer> open = _discover();
    if (open.isEmpty && _records.isEmpty) return false;
    final FocusNode? primary = FocusManager.instance.primaryFocus;
    final Duration now = SchedulerBinding.instance.currentSystemFrameTimeStamp;

    // Sync the records with the layers that are open now. The bottom-most
    // layer to close owns the page-level trigger focus returns to.
    final List<_TvFocusLayerRecord> next = <_TvFocusLayerRecord>[
      for (final TvFocusLayer layer in open)
        _recordOf(layer) ?? _openRecord(layer, primary),
    ];
    _TvFocusLayerRecord? closed;
    for (final _TvFocusLayerRecord record in _records) {
      if (!open.any((TvFocusLayer layer) => identical(layer, record.layer))) {
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
        restored
          ..requestFocus()
          ..consumeKeyboardToken();
        showRing(restored);
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
          top.layer.promote(first);
          showRing(first);
        }
        // Without a target the layer is still loading: wait, don't leak focus
        // onto the page behind it.
        acted = true;
      }
    }
    return acted;
  }

  _TvFocusLayerRecord? _recordOf(TvFocusLayer layer) {
    for (final _TvFocusLayerRecord record in _records) {
      if (identical(record.layer, layer)) return record;
    }
    return null;
  }

  _TvFocusLayerRecord _openRecord(TvFocusLayer layer, FocusNode? primary) {
    // Only a real control is worth returning to. At startup focus can sit on
    // the Navigator's own node, which is not traversable: leave the record
    // without a trigger and let the generic recovery pick a target on close.
    if (primary == null ||
        primary is FocusScopeNode ||
        !(primary.context?.mounted ?? false) ||
        layer.contains(primary) ||
        !TvFocusTraversalPolicy.isEffectivelyFocusable(primary)) {
      layer.opened(null);
      return _TvFocusLayerRecord(layer);
    }
    layer.opened(primary);
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
}
