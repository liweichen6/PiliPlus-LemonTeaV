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

/// The focus layers over the page: the modal ones (popup routes, overlay
/// dialogs) bottom first, and the non-modal inline sheets in [sheets].
class _TvFocusLayerStack {
  _TvFocusLayerStack({
    required this.providers,
    required this.policy,
    required this.showRing,
    required this.currentRing,
    required VoidCallback hideRing,
    required VoidCallback focusMoved,
  }) : sheets = _TvSheetLayers(
         policy: policy,
         showRing: showRing,
         hideRing: hideRing,
         focusMoved: focusMoved,
       );

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

  /// The inline sheets, non-modal layers. What a sheet covers is hidden by
  /// the sheet adapter's `hides` in the focusability walk, so [occludes] looks
  /// at the modal layers only.
  final _TvSheetLayers sheets;

  /// Open modal layers, bottom first.
  final List<_TvFocusLayerRecord> _records = <_TvFocusLayerRecord>[];

  void dispose() => sheets.dispose();

  /// Whether [node] is behind an open modal layer. O(1) when none is open.
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

  /// Whether the modal layers have something for [reconcile] to do. Pure and
  /// cheap, so the per-frame callback can ask before its stationary fast path:
  /// with no layer open and none recorded it is a single empty-list check. The
  /// sheets answer for themselves, in [_TvSheetLayers.frameHasWork].
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

  /// Runs the lifecycle once: the modal layers first, then the inline sheets.
  /// Call it outside of layout and paint.
  ///
  /// Returns `true` when it moved focus or is waiting on a layer that is not
  /// ready, so the caller must skip its own recovery: anything it would pick
  /// sits behind the layer.
  bool reconcile() => _reconcileModal() || sheets.reconcile();

  bool _reconcileModal() {
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

/// An inline sheet the stack tracks: its layer, the node focus goes back to,
/// and how far focus has gone in.
class _TvSheetRecord {
  _TvSheetRecord(this.layer, {this.savedFocusNode});

  final TvSheetLayer layer;
  FocusNode? savedFocusNode;
  bool promoted = false;
  bool userMovedFocus = false;

  /// Focus-tree size at the last probe that found nothing to promote into, and
  /// how many frames that result may still be trusted. Probing walks the whole
  /// sheet subtree, so a sheet with nothing focusable (an image preview) is
  /// not re-walked every frame: it is re-probed when focus nodes attach or
  /// detach, and otherwise now and then.
  int? emptyProbeTreeSize;
  int emptyProbeFramesLeft = 0;

  Element get layout => layer.layout;

  /// Focus went in, or the user went elsewhere: nothing left to promote.
  bool get settled => promoted || userMovedFocus;
}

/// The inline sheets: `MiniScaffold` shows a sheet in place, in a slot of a
/// `BottomSheetLayout`, instead of pushing a route. Each is a non-modal layer
/// ([TvSheetLayer]) over the body of its own layout and nothing else.
///
/// The lifecycle: a sheet is found when it opens, focus moves into it once it
/// has something focusable (also when its content mounts late), unless the
/// user has gone elsewhere first, and focus goes back to its trigger as soon
/// as it starts closing, or to the layout's body or the nearest node when the
/// trigger is gone. Nothing pulls focus back into an open sheet the user left.
///
/// A sheet is found by what can open one, as nothing announces it: a Select
/// (the focused scope is scanned for a few frames), the focused route starting
/// to handle pops itself (a sheet adds a local history entry), the focused
/// node ending up behind a sheet, or a known layout showing a new sheet.
class _TvSheetLayers {
  _TvSheetLayers({
    required this.policy,
    required this.showRing,
    required this.hideRing,
    required this.focusMoved,
  });

  /// Frames a probe that found nothing to promote into stays trusted while the
  /// focus tree does not change (about 200 ms at 60 Hz).
  static const int _kEmptySheetProbeFrames = 12;
  static final Expando<bool> _routeWillHandlePop = Expando<bool>(
    'tvRouteWillHandlePop',
  );

  final TvFocusTraversalPolicy policy;
  final void Function(FocusNode node) showRing;
  final VoidCallback hideRing;

  /// Called when a sheet moves focus, so a recovery still pending from a
  /// scroll is dropped.
  final VoidCallback focusMoved;

  /// Tracked sheets, oldest first.
  final List<_TvSheetRecord> _tracked = <_TvSheetRecord>[];

  /// Every sheet layout seen so far, for finding a new sheet in one of them.
  final List<Element> _known = <Element>[];
  FocusNode? _lastSelectTrigger;
  int _pendingSelectCheckFrames = 0;

  /// Whether something may have changed since the last frame that found the
  /// sheets with nothing to do. While it is `false` and every tracked sheet is
  /// settled, a frame skips the walk of the focused node's ancestors: see
  /// [_canSkipFrame].
  bool _dirty = true;
  FocusNode? _settledFocus;
  List<Element> _around = const <Element>[];
  List<Widget?> _aroundSheets = const <Widget?>[];
  List<bool> _aroundClosing = const <bool>[];

  /// Something that can change the sheets happened: focus moved, a tracked
  /// sheet's animation changed, the app resumed.
  void markDirty() => _dirty = true;

  void dispose() {
    for (final _TvSheetRecord record in _tracked) {
      record.layer.dispose();
    }
    _tracked.clear();
    _known.clear();
    _lastSelectTrigger = null;
    _settledFocus = null;
    _around = const <Element>[];
    _aroundSheets = const <Widget?>[];
  }

  void selectPressed(FocusNode? primary) {
    if (primary != null && primary is! FocusScopeNode) {
      _lastSelectTrigger = primary;
    }
    _pendingSelectCheckFrames = 4;
  }

  void selectReleased() {
    if (_pendingSelectCheckFrames < 4) _pendingSelectCheckFrames = 4;
  }

  _TvSheetRecord? _recordOf(Element layout) {
    for (int i = 0; i < _tracked.length; i++) {
      if (identical(_tracked[i].layout, layout)) return _tracked[i];
    }
    return null;
  }

  void _drop(_TvSheetRecord record) {
    _tracked.remove(record);
    record.layer.dispose();
  }

  void _register(
    Element layoutEl,
    Widget sheet,
    FocusNode? primary,
    TvSheetNodeStatus status, {
    required bool preferSelectTrigger,
  }) {
    _dirty = true;
    if (!_known.contains(layoutEl)) {
      _known.add(layoutEl);
    }
    final FocusNode? trigger = preferSelectTrigger
        ? ((_lastSelectTrigger?.context?.mounted ?? false)
              ? _lastSelectTrigger
              : (primary is FocusScopeNode ? null : primary))
        : ((primary != null && primary is! FocusScopeNode)
              ? primary
              : ((_lastSelectTrigger?.context?.mounted ?? false)
                    ? _lastSelectTrigger
                    : null));
    final _TvSheetRecord? rec = _recordOf(layoutEl);
    if (rec == null) {
      _tracked.add(
        _TvSheetRecord(
          TvSheetLayer(layoutEl, sheet, markDirty),
          savedFocusNode: trigger,
        ),
      );
    } else if (!identical(rec.layer.sheet, sheet)) {
      if (trigger != null && status.enclosingActiveSheetLayout != layoutEl) {
        rec.savedFocusNode ??= trigger;
      }
      rec
        ..layer.sheet = sheet
        ..promoted = false
        ..userMovedFocus = false;
      _tracked
        ..remove(rec)
        ..add(rec);
    } else {
      if (trigger != null && status.enclosingActiveSheetLayout != layoutEl) {
        rec.savedFocusNode ??= trigger;
      }
      if (!rec.userMovedFocus) {
        rec.promoted = false;
      }
    }
  }

  /// Notes when the route of [primary] starts handling pops itself, which is
  /// what a sheet does by registering a local history entry, and schedules a
  /// scan for the sheet. A cached route and a boolean: cheap enough for every
  /// frame.
  void _pollRouteWillHandlePop(FocusNode? primary) {
    if (primary == null) return;
    final ModalRoute<dynamic>? route = tvRouteOfFocusNode(primary);
    if (route == null) return;
    final bool prevWillPop = _routeWillHandlePop[route] ?? false;
    final bool currWillPop = route.willHandlePopInternally;
    _routeWillHandlePop[route] = currWillPop;
    if (!prevWillPop && currWillPop && _pendingSelectCheckFrames <= 0) {
      _pendingSelectCheckFrames = 1;
    }
  }

  /// Whether a known sheet layout has an open sheet that has not been
  /// registered yet.
  bool _hasUnregisteredOpenSheet() {
    for (int i = 0; i < _known.length; i++) {
      final Element el = _known[i];
      if (!el.mounted || !tvSheets.isLayout(el)) continue;
      final Widget? sheet = tvSheets.sheetOf(el);
      if (sheet == null || tvSheets.isClosing(sheet)) {
        continue;
      }
      final _TvSheetRecord? rec = _recordOf(el);
      if (rec == null || !identical(rec.layer.sheet, sheet)) return true;
    }
    return false;
  }

  /// Per frame: whether the sheets have work for a reconcile pass. On the way
  /// it registers sheets that opened and notes a user who left one that was
  /// still waiting for content, so it is not pure.
  ///
  /// With no sheet in play this is the route poll and a few field checks. With
  /// sheets in play it walks the focused node's ancestors, unless every
  /// tracked sheet is settled and nothing changed since ([_canSkipFrame]).
  bool frameHasWork(FocusNode? node) {
    _pollRouteWillHandlePop(node);
    if (_tracked.isEmpty &&
        _pendingSelectCheckFrames <= 0 &&
        !_hasUnregisteredOpenSheet()) {
      return false;
    }
    if (_canSkipFrame(node)) return false;
    final TvSheetNodeStatus status = tvSheets.inspect(node);
    _captureTransitions(node, status);
    if (_hasPendingWork(status)) return true;
    _settle(node);
    return false;
  }

  /// Whether this frame can skip the sheets' bookkeeping, because it would
  /// find what the last one found: nothing to do.
  ///
  /// That holds while nothing marked the sheets dirty (a focus change, a
  /// registration, a reconcile pass, or a tracked sheet's animation status,
  /// which its [TvSheetLayer] reports), no Select scan is due, every tracked
  /// sheet is still the one shown in its layout and settled, no known layout
  /// shows a new sheet, and every sheet layout around the focused node still
  /// shows the sheet it showed, in the same state. The last check is how a
  /// sheet that is not tracked, but holds or covers the focused node, is seen
  /// to change.
  bool _canSkipFrame(FocusNode? node) {
    if (_dirty ||
        _pendingSelectCheckFrames > 0 ||
        !identical(node, _settledFocus)) {
      return false;
    }
    for (int i = 0; i < _tracked.length; i++) {
      final _TvSheetRecord record = _tracked[i];
      final Element layout = record.layout;
      if (!record.settled ||
          !layout.mounted ||
          !identical(tvSheets.sheetOf(layout), record.layer.sheet)) {
        return false;
      }
    }
    for (int i = 0; i < _around.length; i++) {
      final Element layout = _around[i];
      if (!layout.mounted) return false;
      final Widget? sheet = tvSheets.sheetOf(layout);
      if (!identical(sheet, _aroundSheets[i]) ||
          tvSheets.isClosing(sheet) != _aroundClosing[i]) {
        return false;
      }
    }
    return !_hasUnregisteredOpenSheet();
  }

  /// Records what a frame that found nothing to do saw, for [_canSkipFrame].
  void _settle(FocusNode? node) {
    for (int i = 0; i < _tracked.length; i++) {
      if (!_tracked[i].settled) return;
    }
    final List<Element> around = tvSheets.layoutsAround(node);
    _around = around;
    _aroundSheets = <Widget?>[
      for (final Element layout in around) tvSheets.sheetOf(layout),
    ];
    _aroundClosing = <bool>[
      for (final Widget? sheet in _aroundSheets) tvSheets.isClosing(sheet),
    ];
    _settledFocus = node;
    _dirty = false;
  }

  void _captureTransitions(FocusNode? primary, TvSheetNodeStatus status) {
    _known.removeWhere((Element el) => !el.mounted || !tvSheets.isLayout(el));

    final Element? occluding = status.occludingLayout;
    if (occluding != null && tvSheets.isLayout(occluding)) {
      final Widget? sheet = tvSheets.sheetOf(occluding);
      if (sheet != null && !tvSheets.isClosing(sheet)) {
        _register(
          occluding,
          sheet,
          primary,
          status,
          preferSelectTrigger: false,
        );
      }
    }

    // O(1) check on already-discovered sheet layout elements in the scope
    // so async-triggered sheets (e.g. awaiting an HTTP Future after Select on a
    // left-column button) are caught immediately regardless of network latency.
    for (int i = 0; i < _known.length; i++) {
      final Element el = _known[i];
      final Widget? sheet = tvSheets.sheetOf(el);
      if (sheet != null && !tvSheets.isClosing(sheet)) {
        final _TvSheetRecord? rec = _recordOf(el);
        if (rec == null || !identical(rec.layer.sheet, sheet)) {
          _register(el, sheet, primary, status, preferSelectTrigger: false);
        }
      }
    }

    final FocusScopeNode? scope = primary is FocusScopeNode
        ? primary
        : primary?.nearestScope;
    final BuildContext? scopeCtx = scope?.context;

    if (_pendingSelectCheckFrames > 0) {
      _pendingSelectCheckFrames--;
      if (scope != null &&
          !tvIsScopeInactive(scope) &&
          scopeCtx is Element &&
          scopeCtx.mounted) {
        Element? newlyOpened;
        void scan(Element el) {
          if (tvSheets.isLayout(el)) {
            if (!_known.contains(el)) {
              _known.add(el);
            }
            final Widget? sheet = tvSheets.sheetOf(el);
            if (sheet != null && !tvSheets.isClosing(sheet)) {
              final _TvSheetRecord? rec = _recordOf(el);
              if (rec == null || !identical(rec.layer.sheet, sheet)) {
                newlyOpened = el;
              }
            }
          }
          el.visitChildren(scan);
        }

        scopeCtx.visitChildren(scan);
        if (newlyOpened != null) {
          final Widget sheet = tvSheets.sheetOf(newlyOpened!)!;
          _register(
            newlyOpened!,
            sheet,
            primary,
            status,
            preferSelectTrigger: true,
          );
          _pendingSelectCheckFrames = 0;
        }
      }
    }

    // If the user manually navigated to another non-occluded focus node while
    // an async/zero-focusable sheet was waiting to promote, respect the user's
    // navigation rather than overriding it when async content later mounts.
    if (primary != null &&
        primary is! FocusScopeNode &&
        !status.isInvalidated) {
      for (int i = _tracked.length - 1; i >= 0; i--) {
        final _TvSheetRecord rec = _tracked[i];
        final Element el = rec.layout;
        if (!el.mounted || !tvSheets.isLayout(el)) continue;
        final Widget? sheet = tvSheets.sheetOf(el);
        if (sheet == null || tvSheets.isClosing(sheet)) {
          continue;
        }
        if (!identical(rec.layer.sheet, sheet) ||
            rec.settled ||
            identical(primary, rec.savedFocusNode)) {
          continue;
        }
        if (rec.layer.contains(primary)) {
          rec.promoted = true;
        } else {
          rec
            ..userMovedFocus = true
            ..promoted = true;
        }
      }
    }
  }

  /// Whether a tracked sheet in [scope] is still waiting to take focus.
  bool hasUnpromotedIn(FocusScopeNode scope) {
    for (int i = _tracked.length - 1; i >= 0; i--) {
      final _TvSheetRecord rec = _tracked[i];
      final Element el = rec.layout;
      if (!el.mounted || !tvSheets.isLayout(el)) continue;
      final Widget? sheet = tvSheets.sheetOf(el);
      if (sheet == null || tvSheets.isClosing(sheet)) {
        continue;
      }
      if (identical(rec.layer.sheet, sheet) && rec.settled) {
        continue;
      }
      if (rec.layer.scope == scope) {
        return true;
      }
    }
    return false;
  }

  bool _hasPendingWork(TvSheetNodeStatus status) {
    if (status.isInvalidated) return true;
    for (int i = _tracked.length - 1; i >= 0; i--) {
      final _TvSheetRecord rec = _tracked[i];
      final Element el = rec.layout;
      if (!el.mounted || !tvSheets.isLayout(el)) return true;
      final Widget? sheet = tvSheets.sheetOf(el);
      if (sheet == null || tvSheets.isClosing(sheet)) {
        return true;
      }
      if (!identical(rec.layer.sheet, sheet)) {
        return true;
      }
      if (!rec.settled) {
        if (tvSheets.isAnimatingOpen(sheet)) return true;
        final int treeSize = rec.layer.scope?.descendants.length ?? -1;
        if (rec.emptyProbeTreeSize == treeSize &&
            rec.emptyProbeFramesLeft > 0) {
          rec.emptyProbeFramesLeft--;
          continue;
        }
        if (rec.layer.canTakeFocus(policy)) return true;
        rec
          ..emptyProbeTreeSize = treeSize
          ..emptyProbeFramesLeft = _kEmptySheetProbeFrames;
      }
    }
    return false;
  }

  void _unfocusIfInvalidated() {
    final FocusNode? current = FocusManager.instance.primaryFocus;
    if (current != null &&
        current is! FocusScopeNode &&
        tvSheets.inspect(current).isInvalidated) {
      current.unfocus(disposition: UnfocusDisposition.scope);
      hideRing();
    }
  }

  /// Runs the sheets' lifecycle once: gives focus back from a sheet that
  /// started closing, and moves focus into one that opened. Returns `true`
  /// when it moved focus or waits on a sheet that is still opening.
  bool reconcile() {
    _dirty = true;
    final FocusNode? primary = FocusManager.instance.primaryFocus;
    _pollRouteWillHandlePop(primary);
    final TvSheetNodeStatus status = tvSheets.inspect(primary);
    _captureTransitions(primary, status);

    for (int i = _tracked.length - 1; i >= 0; i--) {
      if (i >= _tracked.length) continue;
      final _TvSheetRecord record = _tracked[i];
      final Element layoutEl = record.layout;
      if (!layoutEl.mounted || !tvSheets.isLayout(layoutEl)) {
        _drop(record);
        continue;
      }
      final Widget? sheet = tvSheets.sheetOf(layoutEl);

      if (sheet == null || tvSheets.isClosing(sheet)) {
        final Element? closingSheetSlot = tvSheets.sheetSlotOf(layoutEl);
        _drop(record);
        if (closingSheetSlot != null) {
          for (final _TvSheetRecord other in List<_TvSheetRecord>.of(
            _tracked,
          )) {
            if (TvFocusTraversalPolicy._isElementInSubtree(
              other.layout,
              closingSheetSlot,
            )) {
              _drop(other);
            }
          }
        }
        final FocusNode? savedNode = record.savedFocusNode;
        if (savedNode != null &&
            savedNode.canRequestFocus &&
            (savedNode.context?.mounted ?? false) &&
            TvFocusTraversalPolicy.isEffectivelyFocusable(savedNode)) {
          focusMoved();
          savedNode
            ..requestFocus()
            ..consumeKeyboardToken();
          showRing(savedNode);
          return true;
        }
        final FocusScopeNode? sheetScope = record.layer.scope;
        if (sheetScope != null &&
            !tvIsScopeInactive(sheetScope) &&
            sheetScope.canRequestFocus) {
          final FocusNode? fallback =
              record.layer.bodyFocus(policy, sheetScope) ??
              policy.findRecoveryFocus(savedNode, sheetScope);
          if (fallback != null &&
              fallback.canRequestFocus &&
              (fallback.context?.mounted ?? false)) {
            focusMoved();
            fallback
              ..requestFocus()
              ..consumeKeyboardToken();
            showRing(fallback);
            return true;
          }
        }
        _unfocusIfInvalidated();
        hideRing();
        continue;
      }

      if (!identical(record.layer.sheet, sheet)) {
        record
          ..layer.sheet = sheet
          ..promoted = false
          ..userMovedFocus = false;
      }

      if (!record.settled) {
        final FocusScopeNode? sheetScope = record.layer.scope;
        if (sheetScope == null ||
            tvIsScopeInactive(sheetScope) ||
            !sheetScope.canRequestFocus) {
          continue;
        }
        final FocusNode? firstInSheet = record.layer.firstFocus(policy);
        if (firstInSheet != null &&
            firstInSheet.canRequestFocus &&
            (firstInSheet.context?.mounted ?? false)) {
          record.promoted = true;
          focusMoved();
          firstInSheet
            ..requestFocus()
            ..consumeKeyboardToken();
          showRing(firstInSheet);
          return true;
        }
        _unfocusIfInvalidated();
        if (tvSheets.isAnimatingOpen(sheet)) {
          WidgetsBinding.instance.ensureVisualUpdate();
          return true;
        }
      }
    }
    _unfocusIfInvalidated();
    return false;
  }
}
