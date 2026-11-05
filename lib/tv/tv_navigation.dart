import 'dart:math' as math;

import 'package:PiliPlus/tv/adapters/tv_adapters.dart';
import 'package:PiliPlus/tv/tv_platform.dart';
import 'package:flutter/rendering.dart'
    show
        BoxParentData,
        KeepAliveParentDataMixin,
        RenderClipPath,
        RenderClipRRect,
        RenderClipRect,
        RenderFractionalTranslation,
        RenderOffstage,
        RenderSliverFillViewport,
        RenderSliverPersistentHeader,
        RenderSliverSingleBoxAdapter,
        RenderSliverToBoxAdapter,
        RenderView,
        RenderViewportBase,
        SliverLogicalParentData,
        SliverMultiBoxAdaptorParentData;
import 'package:flutter/scheduler.dart' show SchedulerBinding, SchedulerPhase;
import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';

part 'tv_focus_layers.dart';
part 'tv_focus_scorer.dart';

/// TV-aware 2D spatial focus traversal policy that:
/// 1. Introspects `RenderBox` sizes and viewport intersection up the ancestor
///    chain so collapsed (`AnimatedHeight`) or offscreen (`AppBarAni`) widgets
///    are skipped without modifying upstream widget files.
/// 2. Disables closed-loop wrapping inside scrollable containers so pressing
///    Up at the top or Down at the bottom of a dialog/list exits to header or
///    footer buttons (e.g. 取消 / 确定) instead of cycling infinitely.
/// 3. Steps row-by-row vertically so right-aligned buttons never skip
///    intermediate left-aligned rows.
/// 4. Prevents Left/Right from jumping diagonally to rows above or below when
///    at the horizontal edge of a row inside a dialog.
class _TvNodeMeta {
  const _TvNodeMeta({
    required this.rect,
    required this.visualRect,
    required this.isFocusable,
    required this.ancestorsComplete,
    required this.verticalScrollable,
    required this.horizontalScrollable,
    required this.enclosingRow,
    required this.enclosingCard,
    required this.enclosingAction,
    required this.enclosingWrap,
  });

  final Rect rect;
  final Rect visualRect;
  final bool isFocusable;
  final bool ancestorsComplete;
  final ScrollableState? verticalScrollable;
  final ScrollableState? horizontalScrollable;
  final Element? enclosingRow;
  final Element? enclosingCard;
  final Element? enclosingAction;
  final Element? enclosingWrap;
}

class _TvTraversalCache {
  final Map<FocusNode, _TvNodeMeta> _nodeMeta = <FocusNode, _TvNodeMeta>{};
  final Map<RenderBox, Rect> _boxRects = <RenderBox, Rect>{};
  final Map<ScrollableState, Rect?> _scrollableRects =
      <ScrollableState, Rect?>{};

  static bool _isKeptAliveOffscreen(RenderBox box) {
    RenderObject? current = box;
    while (current != null) {
      if (current is RenderOffstage && current.offstage) {
        return true;
      }
      final Object? pd = current.parentData;
      if (pd is KeepAliveParentDataMixin && pd.keptAlive) {
        return true;
      }
      final RenderObject? parent = current.parent;
      if (pd is SliverMultiBoxAdaptorParentData &&
          pd.index != null &&
          parent is RenderSliverFillViewport) {
        RenderObject? viewport = parent.parent;
        while (viewport != null && viewport is! RenderViewportBase) {
          viewport = viewport.parent;
        }
        if (viewport is RenderViewportBase) {
          final Object offset = viewport.offset;
          if (offset is PageMetrics &&
              offset.hasPixels &&
              offset.hasContentDimensions) {
            final double? page = offset.page;
            if (page != null && (page - pd.index!).abs() > 0.5) {
              return true;
            }
          }
        }
      }
      current = parent;
    }
    return false;
  }

  Rect boxRect(RenderBox box) => _boxRects.putIfAbsent(
    box,
    () => box.localToGlobal(Offset.zero) & box.size,
  );

  RenderView? _viewportRoot;
  Rect? _viewportRect;

  /// Layout-space bounds of the view [box] is attached to, or `null` when they
  /// are unknown.
  ///
  /// [boxRect] is in the root [RenderView]'s logical space, which
  /// `ScaledWidgetsFlutterBinding` lays out in
  /// `physicalSize / (devicePixelRatio * uiScale)`. `View.physicalSize /
  /// View.devicePixelRatio` leaves `uiScale` out and so is the wrong size to
  /// compare against whenever `uiScale != 1.0`.
  Rect? viewportRectOf(RenderBox box) {
    final RenderObject? root = box.owner?.rootNode;
    if (root is! RenderView) return null;
    if (!identical(root, _viewportRoot)) {
      _viewportRoot = root;
      final Size size = root.size;
      _viewportRect = size.width > 1.0 && size.height > 1.0
          ? Offset.zero & size
          : null;
    }
    return _viewportRect;
  }

  Rect? scrollableRect(ScrollableState? scrollable) {
    if (scrollable == null) return null;
    return _scrollableRects.putIfAbsent(scrollable, () {
      final RenderObject? ro = scrollable.context.findRenderObject();
      if (ro is RenderBox && ro.attached && ro.hasSize) {
        return boxRect(ro);
      }
      return null;
    });
  }

  _TvNodeMeta _metaWithAncestors(FocusNode node) {
    final _TvNodeMeta? existing = _nodeMeta[node];
    if (existing != null && existing.ancestorsComplete) {
      return existing;
    }
    return evaluateNode(node, includeAncestorsIfUnfocusable: true);
  }

  Rect rectOf(FocusNode node) =>
      (_nodeMeta[node] ?? evaluateNode(node)).rect;

  Rect visualRectOf(FocusNode node) =>
      (_nodeMeta[node] ?? evaluateNode(node)).visualRect;

  ScrollableState? verticalScrollableOf(FocusNode node) =>
      _metaWithAncestors(node).verticalScrollable;

  ScrollableState? horizontalScrollableOf(FocusNode node) =>
      _metaWithAncestors(node).horizontalScrollable;

  Element? enclosingRowOf(FocusNode node) =>
      _metaWithAncestors(node).enclosingRow;

  Element? enclosingCardOf(FocusNode node) =>
      _metaWithAncestors(node).enclosingCard;

  Element? enclosingActionOf(FocusNode node) =>
      _metaWithAncestors(node).enclosingAction;

  Element? enclosingWrapOf(FocusNode node) =>
      _metaWithAncestors(node).enclosingWrap;

  bool isEffectivelyFocusable(FocusNode node) =>
      evaluateNode(node).isFocusable;

  _TvNodeMeta evaluateNode(
    FocusNode node, {
    bool includeAncestorsIfUnfocusable = false,
  }) {
    final _TvNodeMeta? cached = _nodeMeta[node];
    if (cached != null &&
        (!includeAncestorsIfUnfocusable || cached.ancestorsComplete)) {
      return cached;
    }

    final BuildContext? context = node.context;
    if (context == null || !context.mounted) {
      const meta = _TvNodeMeta(
        rect: Rect.zero,
        visualRect: Rect.zero,
        isFocusable: false,
        ancestorsComplete: true,
        verticalScrollable: null,
        horizontalScrollable: null,
        enclosingRow: null,
        enclosingCard: null,
        enclosingAction: null,
        enclosingWrap: null,
      );
      _nodeMeta[node] = meta;
      return meta;
    }

    final RenderObject? renderObject = context.findRenderObject();
    final bool isAttachedBox =
        renderObject is RenderBox &&
        renderObject.attached &&
        renderObject.hasSize &&
        !_isKeptAliveOffscreen(renderObject);
    final Rect globalRect = isAttachedBox
        ? boxRect(renderObject)
        : node.rect;

    // Behind an open focus layer (an overlay dialog, ...): not reachable.
    final bool occluded = _TvFocusLayerStack.current?.occludes(node) ?? false;

    bool focusable =
        !occluded &&
        node.canRequestFocus &&
        !node.skipTraversal &&
        isAttachedBox &&
        renderObject.size.width > 1.0 &&
        renderObject.size.height > 1.0 &&
        !globalRect.isEmpty &&
        globalRect.width > 1.0 &&
        globalRect.height > 1.0 &&
        !globalRect.hasNaN &&
        !globalRect.isInfinite;

    if (!focusable && !includeAncestorsIfUnfocusable) {
      final meta = _TvNodeMeta(
        rect: globalRect,
        visualRect: globalRect,
        isFocusable: false,
        ancestorsComplete: false,
        verticalScrollable: null,
        horizontalScrollable: null,
        enclosingRow: null,
        enclosingCard: null,
        enclosingAction: null,
        enclosingWrap: null,
      );
      _nodeMeta[node] = meta;
      return meta;
    }

    Rect visible = globalRect;
    bool checkedOwner = false;
    bool insideScrollable = false;
    bool hasNonZeroTranslation = false;
    bool ancestorsComplete = true;
    double sliverScrollOffsetDelta = 0.0;
    ScrollableState? verticalScrollable;
    ScrollableState? horizontalScrollable;
    Element? enclosingRow;
    Element? enclosingCard;
    Element? enclosingAction;
    Element? enclosingWrap;

    bool stopOrContinue() {
      if (includeAncestorsIfUnfocusable) return true;
      ancestorsComplete = false;
      return false;
    }

    Element childElement = context as Element;
    context.visitAncestorElements((Element element) {
      final Object? childSlot = childElement.slot;
      childElement = element;
      if (element is StatefulElement && element.state is ScrollableState) {
        final scrollable = element.state as ScrollableState;
        if (TvFocusTraversalPolicy._canUserScroll(scrollable)) {
          insideScrollable = true;
          if (verticalScrollable == null &&
              (scrollable.axisDirection == AxisDirection.down ||
                  scrollable.axisDirection == AxisDirection.up)) {
            verticalScrollable = scrollable;
          }
          if (horizontalScrollable == null &&
              (scrollable.axisDirection == AxisDirection.right ||
                  scrollable.axisDirection == AxisDirection.left)) {
            horizontalScrollable = scrollable;
          }
        } else if (focusable) {
          final Rect? lockedViewport = scrollableRect(scrollable);
          if (lockedViewport != null &&
              !lockedViewport.hasNaN &&
              !lockedViewport.isInfinite) {
            if (!insideScrollable) {
              visible = visible.intersect(lockedViewport);
            } else {
              final ScrollableState? innerScrollable =
                  verticalScrollable ?? horizontalScrollable;
              final Rect? innerRect = scrollableRect(innerScrollable);
              if (innerRect != null &&
                  !innerRect.hasNaN &&
                  !innerRect.isInfinite) {
                final Rect innerVisible = innerRect.intersect(lockedViewport);
                if (innerVisible.width <= 1.0 || innerVisible.height <= 1.0) {
                  focusable = false;
                  return stopOrContinue();
                }
              }
              if (verticalScrollable == null) {
                final double top = math.max(visible.top, lockedViewport.top);
                final double bottom = math.min(
                  visible.bottom,
                  lockedViewport.bottom,
                );
                visible = Rect.fromLTRB(
                  visible.left,
                  top,
                  visible.right,
                  math.max(top, bottom),
                );
              }
              if (horizontalScrollable == null) {
                final double left = math.max(visible.left, lockedViewport.left);
                final double right = math.min(
                  visible.right,
                  lockedViewport.right,
                );
                visible = Rect.fromLTRB(
                  left,
                  visible.top,
                  math.max(left, right),
                  visible.bottom,
                );
              }
            }
            if (visible.width <= 1.0 || visible.height <= 1.0) {
              focusable = false;
              return stopOrContinue();
            }
          }
        }
      }

      final Widget widget = element.widget;
      if (enclosingRow == null && tvListTiles.isGroup(widget)) {
        enclosingRow = element;
      }
      if (enclosingCard == null && tvCards.isGroup(widget)) {
        enclosingCard = element;
      }
      if (enclosingAction == null && tvCards.isAction(widget)) {
        enclosingAction = element;
      }
      if (enclosingWrap == null && widget is Wrap) {
        enclosingWrap = element;
      }

      if (!focusable) return true;

      if (tvSheets.hides(widget, childSlot)) {
        focusable = false;
        return stopOrContinue();
      }

      final RenderObject? ancestorRo = element.renderObject;
      if (verticalScrollable == null) {
        if (ancestorRo is RenderSliverSingleBoxAdapter &&
            ancestorRo.child != null &&
            ancestorRo.constraints.axisDirection == AxisDirection.down &&
            ancestorRo.constraints.scrollOffset > 0.0) {
          final double delta =
              ancestorRo.constraints.scrollOffset +
              ancestorRo.childMainAxisPosition(ancestorRo.child!) +
              (ancestorRo.geometry?.paintOrigin ?? 0.0);
          if (delta > 0.5) {
            sliverScrollOffsetDelta += delta;
          }
        } else if (ancestorRo is RenderSliverPersistentHeader &&
            ancestorRo.child != null &&
            ancestorRo.constraints.axisDirection == AxisDirection.down &&
            ancestorRo.constraints.scrollOffset > 0.0) {
          final double delta =
              ancestorRo.constraints.scrollOffset +
              ancestorRo.childMainAxisPosition(ancestorRo.child!) +
              (ancestorRo.geometry?.paintOrigin ?? 0.0);
          if (delta > 0.5) {
            sliverScrollOffsetDelta += delta;
          }
        }
      }
      if (ancestorRo is RenderBox &&
          ancestorRo.attached &&
          ancestorRo.hasSize) {
        if (ancestorRo.size.width < 1.0 || ancestorRo.size.height < 1.0) {
          focusable = false;
          return stopOrContinue();
        }
        if (tvPlayerHud.isSlidAway(ancestorRo)) {
          hasNonZeroTranslation = true;
        }
        // Intersect clip bounds only below any enclosing Scrollable (or when
        // shifted by a SlideTransition/FractionalTranslation such as AppBarAni)
        // so items built in a Scrollable's offscreen cacheExtent remain
        // reachable for in-list D-pad scrolling.
        if ((!insideScrollable || hasNonZeroTranslation) &&
            ((ancestorRo is RenderClipRect &&
                    ancestorRo.clipBehavior != Clip.none) ||
                (ancestorRo is RenderClipRRect &&
                    ancestorRo.clipBehavior != Clip.none) ||
                (ancestorRo is RenderClipPath &&
                    ancestorRo.clipBehavior != Clip.none))) {
          final Rect clipBounds = boxRect(ancestorRo);
          if (!clipBounds.hasNaN && !clipBounds.isInfinite) {
            visible = visible.intersect(clipBounds);
            if (visible.width <= 1.0 || visible.height <= 1.0) {
              focusable = false;
              return stopOrContinue();
            }
          }
        }
      }

      if (widget is Offstage && widget.offstage) {
        focusable = false;
        return stopOrContinue();
      }
      if (widget is Visibility && !widget.visible) {
        focusable = false;
        return stopOrContinue();
      }
      if (widget is IgnorePointer && widget.ignoring) {
        focusable = false;
        return stopOrContinue();
      }
      if (widget is ExcludeFocus && widget.excluding) {
        focusable = false;
        return stopOrContinue();
      }
      if (widget is IconButton && widget.onPressed == null) {
        focusable = false;
        return stopOrContinue();
      }
      if (widget is ButtonStyleButton && !widget.enabled) {
        focusable = false;
        return stopOrContinue();
      }
      if (!checkedOwner) {
        if (widget is InkResponse) {
          checkedOwner = true;
          final bool enabled =
              widget.onTap != null ||
              widget.onDoubleTap != null ||
              widget.onLongPress != null ||
              widget.onTapUp != null ||
              widget.onTapDown != null ||
              widget.onSecondaryTap != null ||
              widget.onSecondaryTapUp != null ||
              widget.onSecondaryTapDown != null;
          focusable = enabled && widget.canRequestFocus;
          if (!focusable) return stopOrContinue();
        } else if (widget is FocusableActionDetector) {
          checkedOwner = true;
          focusable = widget.enabled;
          if (!focusable) return stopOrContinue();
        } else if (widget is TextField) {
          checkedOwner = true;
          final bool enabled =
              widget.enabled ?? widget.decoration?.enabled ?? true;
          focusable = enabled && widget.canRequestFocus;
          if (!focusable) return stopOrContinue();
        } else if (widget is Focus) {
          checkedOwner = true;
        }
      }
      return true;
    });

    if (focusable &&
        (!insideScrollable || hasNonZeroTranslation) &&
        renderObject is RenderBox) {
      final Rect? viewport = viewportRectOf(renderObject);
      if (viewport != null) {
        visible = visible.intersect(viewport);
        if (visible.width <= 1.0 || visible.height <= 1.0) {
          focusable = false;
        }
      }
    }

    final Rect effectiveRect =
        (verticalScrollable != null && sliverScrollOffsetDelta > 0.5)
        ? globalRect.translate(0.0, -sliverScrollOffsetDelta)
        : globalRect;

    final meta = _TvNodeMeta(
      rect: effectiveRect,
      visualRect: globalRect,
      isFocusable: focusable,
      ancestorsComplete: ancestorsComplete,
      verticalScrollable: verticalScrollable,
      horizontalScrollable: horizontalScrollable,
      enclosingRow: enclosingRow,
      enclosingCard: enclosingCard,
      enclosingAction: enclosingAction,
      enclosingWrap: enclosingWrap,
    );
    _nodeMeta[node] = meta;
    return meta;
  }

  bool isVisibleInEnclosingScrollables(FocusNode node) {
    final ScrollableState? vert = verticalScrollableOf(node);
    if (vert != null) {
      final Rect? vertRect = scrollableRect(vert);
      if (vertRect != null &&
          !TvFocusTraversalPolicy._isRectVisibleInScrollable(
            rectOf(node),
            vertRect,
          )) {
        return false;
      }
    }
    final ScrollableState? horiz = horizontalScrollableOf(node);
    if (horiz != null) {
      final Rect? horizRect = scrollableRect(horiz);
      if (horizRect != null &&
          !TvFocusTraversalPolicy._isRectVisibleHorizontallyInScrollable(
            rectOf(node),
            horizRect,
          )) {
        return false;
      }
    }
    return true;
  }
}

class _TvPolicyFrameState {
  bool repeatLockedThisFrame = false;
  bool didScrollInLastFocus = false;
  FocusNode? lastPolicyScrolledNode;
  _TvTraversalCache? activeCache;
}

class TvFocusTraversalPolicy extends FocusTraversalPolicy
    implements TvFocusFinder {
  TvFocusTraversalPolicy({
    TraversalRequestFocusCallback? requestFocusCallback,
  }) : super(
         requestFocusCallback:
             requestFocusCallback ?? _defaultTvRequestFocusCallback,
       );

  final ReadingOrderTraversalPolicy _readingOrderPolicy =
      ReadingOrderTraversalPolicy();
  final _TvPolicyFrameState _frameState = _TvPolicyFrameState();
  final _TvColumnMemory _memory = _TvColumnMemory();

  /// Which rules pick the target of a D-pad move: the rule chain unless the
  /// build passes `--dart-define=TV_FOCUS_SCORER=scored`. Tests set it.
  static TvFocusScorer scorer =
      const String.fromEnvironment('TV_FOCUS_SCORER') == 'scored'
      ? TvFocusScorer.scored
      : TvFocusScorer.rules;

  /// Whether the scorer keeps each decision's scores in [debugLastDecision],
  /// for the debug overlay: on with `--dart-define=TV_FOCUS_SCORES=true`.
  static bool debugRecordScores = const bool.fromEnvironment(
    'TV_FOCUS_SCORES',
  );

  /// The scorer's last decision, while [debugRecordScores] is on.
  static final ValueNotifier<TvFocusDecision?> debugLastDecision =
      ValueNotifier<TvFocusDecision?>(null);

  static void _defaultTvRequestFocusCallback(
    FocusNode node, {
    ScrollPositionAlignmentPolicy? alignmentPolicy,
    double? alignment,
    Duration? duration,
    Curve? curve,
  }) {
    node.requestFocus();
    final BuildContext? context = node.context;
    if (context != null && context.mounted) {
      _ensureVisibleInUserScrollables(
        context,
        alignmentPolicy:
            alignmentPolicy ?? ScrollPositionAlignmentPolicy.explicit,
        alignment: alignment ?? 0.0,
        duration: duration ?? Duration.zero,
        curve: curve ?? Curves.ease,
      );
    }
  }

  static void _ensureVisibleInUserScrollables(
    BuildContext context, {
    ScrollPositionAlignmentPolicy alignmentPolicy =
        ScrollPositionAlignmentPolicy.explicit,
    double alignment = 0.0,
    Duration duration = Duration.zero,
    Curve curve = Curves.ease,
    Axis? onlyAxis,
  }) {
    BuildContext current = context;
    RenderObject? firstTarget;
    ScrollableState? scrollable = Scrollable.maybeOf(context);
    while (scrollable != null) {
      final RenderObject? target = current.findRenderObject();
      if (_canUserScroll(scrollable) &&
          (onlyAxis == null || scrollable.position.axis == onlyAxis)) {
        if (target != null && target.attached) {
          double? pinnedSliverPrecedingExtent;
          final RenderObject? scrollableRo = scrollable.context
              .findRenderObject();
          RenderObject? ancestorRo = target.parent;
          while (ancestorRo != null && ancestorRo != scrollableRo) {
            if (ancestorRo is RenderSliverSingleBoxAdapter &&
                ancestorRo.child != null &&
                ancestorRo.constraints.axisDirection == AxisDirection.down &&
                ancestorRo.constraints.scrollOffset > 0.0) {
              final double delta =
                  ancestorRo.constraints.scrollOffset +
                  ancestorRo.childMainAxisPosition(ancestorRo.child!) +
                  (ancestorRo.geometry?.paintOrigin ?? 0.0);
              final bool isCustomHeaderSliver =
                  ancestorRo is! RenderSliverToBoxAdapter &&
                  (ancestorRo.geometry?.maxPaintExtent ?? double.infinity) <=
                      ancestorRo.constraints.viewportMainAxisExtent * 0.5;
              if (delta > 0.5 || isCustomHeaderSliver) {
                pinnedSliverPrecedingExtent =
                    ancestorRo.constraints.precedingScrollExtent;
                break;
              }
            } else if (ancestorRo is RenderSliverPersistentHeader &&
                ancestorRo.child != null &&
                ancestorRo.constraints.axisDirection == AxisDirection.down &&
                ancestorRo.constraints.scrollOffset > 0.0) {
              pinnedSliverPrecedingExtent =
                  ancestorRo.constraints.precedingScrollExtent;
              break;
            }
            ancestorRo = ancestorRo.parent;
          }
          scrollable.position.ensureVisible(
            target,
            alignment: alignment,
            duration: duration,
            curve: curve,
            alignmentPolicy: alignmentPolicy,
            targetRenderObject: firstTarget,
          );
          if (pinnedSliverPrecedingExtent != null &&
              scrollable.position.hasPixels &&
              scrollable.position.hasContentDimensions) {
            final double targetPixels = pinnedSliverPrecedingExtent.clamp(
              scrollable.position.minScrollExtent,
              scrollable.position.maxScrollExtent,
            );
            if (scrollable.position.pixels > targetPixels + 1e-3) {
              if (duration == Duration.zero) {
                scrollable.position.jumpTo(targetPixels);
              } else {
                scrollable.position.animateTo(
                  targetPixels,
                  duration: duration,
                  curve: curve,
                );
              }
            }
          }
        }
      }
      firstTarget ??= target;
      final BuildContext scrollableContext = scrollable.context;
      current = scrollableContext;
      scrollable = scrollableContext.mounted
          ? Scrollable.maybeOf(scrollableContext)
          : null;
    }
  }

  static double _sumUserScrollPixels(BuildContext? context) {
    if (context == null || !context.mounted) return 0.0;
    double sum = 0.0;
    ScrollableState? scrollable = Scrollable.maybeOf(context);
    while (scrollable != null) {
      if (_canUserScroll(scrollable) && scrollable.position.hasPixels) {
        sum += scrollable.position.pixels;
      }
      final BuildContext scrollableContext = scrollable.context;
      scrollable = scrollableContext.mounted
          ? Scrollable.maybeOf(scrollableContext)
          : null;
    }
    return sum;
  }

  /// Whether a directional traversal step has already occurred during the
  /// current frame, used to throttle auto-repeat (`KeyRepeatEvent`) to at most
  /// one step per rendered frame without dropping discrete `KeyDownEvent`s.
  bool get isRepeatLockedThisFrame => _frameState.repeatLockedThisFrame;

  /// Whether the most recent directional focus step scrolled an enclosing
  /// user-scrollable container.
  bool get didScrollInLastFocus => _frameState.didScrollInLastFocus;

  T _withCache<T>(T Function(_TvTraversalCache cache) action) {
    final _TvTraversalCache? existing = _frameState.activeCache;
    if (existing != null) return action(existing);
    final cache = _TvTraversalCache();
    _frameState.activeCache = cache;
    try {
      return action(cache);
    } finally {
      _frameState.activeCache = null;
    }
  }

  /// Consumes and clears the marker indicating [node] was just scrolled into
  /// view by [inDirection] via [requestFocusCallback].
  bool consumePolicyScrolledNode(FocusNode node) {
    if (identical(_frameState.lastPolicyScrolledNode, node)) {
      _frameState.lastPolicyScrolledNode = null;
      return true;
    }
    return false;
  }

  /// Returns `true` when [node] is mounted, attached, has non-zero geometry
  /// across its ancestor `RenderBox` chain, intersects the visible viewport,
  /// and belongs to an enabled interactive widget.
  static bool isEffectivelyFocusable(FocusNode node) =>
      _TvTraversalCache().isEffectivelyFocusable(node);

  @override
  bool isFocusable(FocusNode node) => isEffectivelyFocusable(node);

  static FocusNode? _findFirstReadingOrderNode(
    List<FocusNode> candidates,
    _TvTraversalCache cache,
  ) {
    if (candidates.isEmpty) return null;
    if (candidates.length == 1) return candidates.first;

    // Pass 1: find topmost node in reading order
    FocusNode topmost = candidates.first;
    Rect topmostRect = cache.rectOf(topmost);
    for (int i = 1; i < candidates.length; i++) {
      final FocusNode node = candidates[i];
      final Rect r = cache.rectOf(node);
      if (r.top < topmostRect.top) {
        topmost = node;
        topmostRect = r;
      }
    }

    // Pass 2: find leftmost node in the topmost node's horizontal band
    final double bandTop = topmostRect.top;
    final double bandBottom = topmostRect.bottom;
    FocusNode firstNode = topmost;
    Rect firstRect = topmostRect;

    for (int i = 0; i < candidates.length; i++) {
      final FocusNode node = candidates[i];
      if (node == topmost) continue;
      final Rect r = cache.rectOf(node);
      if (r.bottom > bandTop && r.top < bandBottom) {
        if (r.left < firstRect.left) {
          firstNode = node;
          firstRect = r;
        }
      }
    }
    return firstNode;
  }

  static bool _isElementInSubtree(BuildContext? context, Element subtreeRoot) {
    if (context == null || !context.mounted) return false;
    if (identical(context, subtreeRoot)) return true;
    bool found = false;
    context.visitAncestorElements((Element ancestor) {
      if (identical(ancestor, subtreeRoot)) {
        found = true;
        return false;
      }
      return true;
    });
    return found;
  }

  @override
  FocusNode? findFirstFocusInSubtree(
    Element subtreeRoot,
    FocusScopeNode currentScope,
  ) => _withCache((_TvTraversalCache cache) {
    if (!subtreeRoot.mounted) return null;
    return _firstFocusAmong(
      currentScope.traversalDescendants.where(
        (FocusNode node) => _isElementInSubtree(node.context, subtreeRoot),
      ),
      cache,
    );
  });

  /// The initial focus target among [candidates], with the same preferences as
  /// [findFirstFocusInSubtree]: an `autofocus` node first, otherwise the
  /// first one in reading order among those visible in their scrollables.
  @override
  FocusNode? findFirstFocusAmong(Iterable<FocusNode> candidates) => _withCache(
    (_TvTraversalCache cache) => _firstFocusAmong(candidates, cache),
  );

  static FocusNode? _firstFocusAmong(
    Iterable<FocusNode> candidates,
    _TvTraversalCache cache,
  ) {
    FocusNode? autofocusCandidate;
    final List<FocusNode> visibleInScrollables = <FocusNode>[];
    final List<FocusNode> fallbackCandidates = <FocusNode>[];
    final List<FocusNode> allFocusable = <FocusNode>[];
    for (final FocusNode node in candidates) {
      if (cache.isEffectivelyFocusable(node)) {
        allFocusable.add(node);
        final bool visible = cache.isVisibleInEnclosingScrollables(node);
        if (autofocusCandidate == null && visible) {
          final Widget? w = node.context?.widget;
          if (w is Focus && w.autofocus) {
            autofocusCandidate = node;
          }
        }
        if (visible) {
          visibleInScrollables.add(node);
        } else {
          fallbackCandidates.add(node);
        }
      }
    }
    if (autofocusCandidate != null) return autofocusCandidate;
    final List<FocusNode> rawPool = visibleInScrollables.isNotEmpty
        ? visibleInScrollables
        : fallbackCandidates;
    final List<FocusNode> pool = _preferPrimaryInitialCandidates(
      rawPool,
      allFocusable,
      cache,
    );
    return _findFirstReadingOrderNode(pool, cache);
  }

  /// Finds the best focus target in [currentScope] when [invalidNode] has
  /// become offscreen or unfocusable (e.g. after switching tabs in a
  /// `PageView`/`TabBarView`, opening/closing an inline sheet, or
  /// resuming the app on `HomePage`).
  ///
  /// When [invalidNode] (or [previousRect]) belonged to a non-user-scrollable
  /// container such as `MainApp`'s `PageView`, this prefers focusable targets
  /// inside that same container (e.g. `HomePage` content) rather than jumping
  /// to an outer sidebar item such as `userAvatar` (`toMinePage`).
  FocusNode? findRecoveryFocus(
    FocusNode? invalidNode,
    FocusScopeNode currentScope, {
    Rect? previousRect,
  }) => _withCache((_TvTraversalCache cache) {
    final TvSheetNodeStatus sheetStatus = tvSheets.inspect(invalidNode);
    final Element? occludingLayout = sheetStatus.occludingLayout;
    if (occludingLayout != null && tvSheets.isLayout(occludingLayout)) {
      final Element? sheetSlot = tvSheets.sheetSlotOf(occludingLayout);
      if (sheetSlot != null) {
        final FocusNode? inSheet = findFirstFocusInSubtree(
          sheetSlot,
          currentScope,
        );
        if (inSheet != null) return inSheet;
      }
      return null;
    }
    final Element? closingLayout = sheetStatus.closingLayout;
    if (closingLayout != null) {
      final Element? bodySlot = tvSheets.bodySlotOf(closingLayout);
      if (bodySlot != null) {
        final FocusNode? inBody = findFirstFocusInSubtree(
          bodySlot,
          currentScope,
        );
        if (inBody != null) return inBody;
      }
    }

    Rect? containerRect;
    final BuildContext? invalidContext = invalidNode?.context;
    if (invalidContext != null && invalidContext.mounted) {
      invalidContext.visitAncestorElements((Element element) {
        if (element is StatefulElement && element.state is ScrollableState) {
          final scrollable = element.state as ScrollableState;
          if (!_canUserScroll(scrollable)) {
            final Rect? r = cache.scrollableRect(scrollable);
            if (r != null && !r.isEmpty && !r.hasNaN && !r.isInfinite) {
              containerRect = r;
            }
          }
        }
        return true;
      });
    }

    if (containerRect == null && previousRect != null && !previousRect.isEmpty) {
      for (final FocusNode node in currentScope.traversalDescendants) {
        final BuildContext? ctx = node.context;
        if (ctx == null || !ctx.mounted) continue;
        ctx.visitAncestorElements((Element element) {
          if (element is StatefulElement && element.state is ScrollableState) {
            final scrollable = element.state as ScrollableState;
            if (!_canUserScroll(scrollable)) {
              final Rect? r = cache.scrollableRect(scrollable);
              if (r != null &&
                  !r.isEmpty &&
                  !r.hasNaN &&
                  !r.isInfinite &&
                  r.contains(previousRect.center)) {
                containerRect = r;
                return false;
              }
            }
          }
          return true;
        });
        if (containerRect != null) break;
      }
    }

    if (containerRect != null) {
      final List<FocusNode> visibleInContainer = <FocusNode>[];
      final List<FocusNode> fallbackInContainer = <FocusNode>[];
      final List<FocusNode> allInContainer = <FocusNode>[];
      for (final FocusNode node in currentScope.traversalDescendants) {
        if (node == invalidNode) continue;
        if (cache.isEffectivelyFocusable(node) &&
            containerRect!.contains(cache.rectOf(node).center)) {
          allInContainer.add(node);
          if (cache.isVisibleInEnclosingScrollables(node)) {
            visibleInContainer.add(node);
          } else {
            fallbackInContainer.add(node);
          }
        }
      }
      final List<FocusNode> rawContainerPool = visibleInContainer.isNotEmpty
          ? visibleInContainer
          : fallbackInContainer;
      final List<FocusNode> containerPool = _preferPrimaryInitialCandidates(
        rawContainerPool,
        allInContainer,
        cache,
      );
      final FocusNode? inContainer = _findFirstReadingOrderNode(
        containerPool,
        cache,
      );
      if (inContainer != null) return inContainer;
    }

    return findFirstFocus(currentScope, ignoreCurrentFocus: true);
  });

  @override
  FocusNode? findFirstFocus(
    FocusNode currentNode, {
    bool ignoreCurrentFocus = false,
  }) => _withCache((_TvTraversalCache cache) {
    final FocusNode? candidate = super.findFirstFocus(
      currentNode,
      ignoreCurrentFocus: ignoreCurrentFocus,
    );
    if (candidate != null &&
        cache.isEffectivelyFocusable(candidate) &&
        cache.isVisibleInEnclosingScrollables(candidate) &&
        !_isEmbeddedSecondaryOfFocusableAncestor(candidate, cache)) {
      return candidate;
    }
    final List<FocusNode> visibleInScrollables = <FocusNode>[];
    final List<FocusNode> fallbackCandidates = <FocusNode>[];
    final List<FocusNode> allFocusable = <FocusNode>[];
    for (final FocusNode node in currentNode.traversalDescendants) {
      if (cache.isEffectivelyFocusable(node)) {
        allFocusable.add(node);
        if (cache.isVisibleInEnclosingScrollables(node)) {
          visibleInScrollables.add(node);
        } else {
          fallbackCandidates.add(node);
        }
      }
    }
    final List<FocusNode> rawPool = visibleInScrollables.isNotEmpty
        ? visibleInScrollables
        : fallbackCandidates;
    final List<FocusNode> pool = _preferPrimaryInitialCandidates(
      rawPool,
      allFocusable,
      cache,
    );
    return _findFirstReadingOrderNode(pool, cache);
  });

  List<FocusNode> _sortDescendantsWithCache(
    Iterable<FocusNode> descendants,
    FocusNode currentNode,
    _TvTraversalCache cache,
  ) => _readingOrderPolicy
      .sortDescendants(
        descendants.where(
          (FocusNode node) =>
              node == currentNode ||
              !node.canRequestFocus ||
              cache.isEffectivelyFocusable(node),
        ),
        currentNode,
      )
      .toList();

  @override
  Iterable<FocusNode> sortDescendants(
    Iterable<FocusNode> descendants,
    FocusNode currentNode,
  ) => _withCache(
    (_TvTraversalCache cache) =>
        _sortDescendantsWithCache(descendants, currentNode, cache),
  );

  @override
  FocusNode? findFirstFocusInDirection(
    FocusNode currentNode,
    TraversalDirection direction,
  ) => _withCache((_TvTraversalCache cache) {
    final FocusNode? candidate = _readingOrderPolicy.findFirstFocusInDirection(
      currentNode,
      direction,
    );
    if (candidate != null &&
        cache.isEffectivelyFocusable(candidate) &&
        cache.isVisibleInEnclosingScrollables(candidate) &&
        !_isEmbeddedSecondaryOfFocusableAncestor(candidate, cache)) {
      return candidate;
    }
    final List<FocusNode> visibleInScrollables = <FocusNode>[];
    final List<FocusNode> fallbackCandidates = <FocusNode>[];
    final List<FocusNode> allFocusable = <FocusNode>[];
    for (final FocusNode node in currentNode.traversalDescendants) {
      if (cache.isEffectivelyFocusable(node)) {
        allFocusable.add(node);
        if (cache.isVisibleInEnclosingScrollables(node)) {
          visibleInScrollables.add(node);
        } else {
          fallbackCandidates.add(node);
        }
      }
    }
    final List<FocusNode> rawPool = visibleInScrollables.isNotEmpty
        ? visibleInScrollables
        : fallbackCandidates;
    final List<FocusNode> pool = _preferPrimaryInitialCandidates(
      rawPool,
      allFocusable,
      cache,
    );
    return _findFirstReadingOrderNode(pool, cache);
  });

  static bool _canUserScroll(ScrollableState scrollable) {
    final ScrollPhysics? physics = scrollable.widget.physics;
    return physics is! NeverScrollableScrollPhysics &&
        physics is! PageScrollPhysics &&
        scrollable.position is! PageMetrics;
  }

  static bool _isRectVisibleInScrollable(Rect r, Rect scrollableRect) {
    if (r.bottom <= scrollableRect.top + 1.0 ||
        r.top >= scrollableRect.bottom - 1.0) {
      return false;
    }
    if (r.center.dy >= scrollableRect.top - 1.0 &&
        r.center.dy <= scrollableRect.bottom + 1.0) {
      return true;
    }
    final double visibleHeight =
        math.min(r.bottom, scrollableRect.bottom) -
        math.max(r.top, scrollableRect.top);
    return visibleHeight >= scrollableRect.height * 0.5 - 1.0;
  }

  static bool _isInOppositeHalfPlane(
    Rect candidateRect,
    Rect targetRect,
    TraversalDirection direction,
  ) {
    if (candidateRect.isEmpty || targetRect.isEmpty) return false;
    return switch (direction) {
      TraversalDirection.down => candidateRect.bottom <= targetRect.top - 2.0,
      TraversalDirection.up => candidateRect.top >= targetRect.bottom + 2.0,
      TraversalDirection.right => candidateRect.right <= targetRect.left - 2.0,
      TraversalDirection.left => candidateRect.left >= targetRect.right + 2.0,
    };
  }

  static bool _isRectVisibleHorizontallyInScrollable(
    Rect r,
    Rect scrollableRect,
  ) {
    return r.right > scrollableRect.left + 1.0 &&
        r.left < scrollableRect.right - 1.0 &&
        r.center.dx >= scrollableRect.left - 1.0 &&
        r.center.dx <= scrollableRect.right + 1.0;
  }

  /// Returns true when [secondary] is an action embedded in the primary
  /// [container].
  static bool _isEmbeddedSecondaryOf(
    FocusNode secondary,
    FocusNode container,
    _TvTraversalCache cache,
  ) {
    if (secondary == container) return false;
    final Rect cr = cache.rectOf(container);
    final Rect sr = cache.rectOf(secondary);
    return tvCards.isSecondaryIn(sr, cr);
  }

  /// Whether [node] is a tile or card that actions can be embedded in.
  @pragma('vm:prefer-inline')
  static bool _isPrimaryContainer(FocusNode node, _TvTraversalCache cache) {
    final Widget? w = node.context?.widget;
    return (w != null && tvCards.isGroup(w)) ||
        cache.enclosingRowOf(node) != null ||
        cache.enclosingCardOf(node) != null;
  }

  static bool _isEmbeddedSecondaryOfFocusableAncestor(
    FocusNode node,
    _TvTraversalCache cache,
  ) {
    for (final FocusNode ancestor in node.ancestors) {
      if (!cache.isEffectivelyFocusable(ancestor)) continue;
      if (_isPrimaryContainer(ancestor, cache) &&
          _isEmbeddedSecondaryOf(node, ancestor, cache)) {
        return true;
      }
    }
    return false;
  }

  /// Excludes embedded secondary action buttons (such as comment `回复`/`点赞`
  /// buttons or trailing icon buttons) from initial/recovery focus candidate
  /// pools when their enclosing primary card/tile container is focusable in
  /// [allFocusable] and at least one primary candidate exists in [pool].
  ///
  /// Without this filter, when a primary card is half-scrolled off the top of
  /// a scrollable viewport (so its vertical center is above `scrollableRect.top`
  /// while its bottom-row action buttons remain inside the viewport), initial
  /// or recovery focus would land on a micro secondary button of the partially
  /// scrolled-out card instead of the first fully visible card.
  static List<FocusNode> _preferPrimaryInitialCandidates(
    List<FocusNode> pool,
    List<FocusNode> allFocusable,
    _TvTraversalCache cache,
  ) {
    if (pool.length <= 1) return pool;
    final Set<FocusNode> focusableSet = allFocusable.toSet();
    final List<FocusNode> primaryOnly = pool.where((FocusNode node) {
      for (final FocusNode ancestor in node.ancestors) {
        if (!focusableSet.contains(ancestor)) continue;
        if (_isPrimaryContainer(ancestor, cache) &&
            _isEmbeddedSecondaryOf(node, ancestor, cache)) {
          return false;
        }
      }
      return true;
    }).toList();
    return primaryOnly.isNotEmpty ? primaryOnly : pool;
  }

  /// Excludes embedded secondary action nodes whenever their enclosing primary
  /// container node is also present in [candidates] and [focusedChild] is not
  /// already that container.
  static List<FocusNode> _filterOutEmbeddedSecondaryActions(
    List<FocusNode> candidates,
    FocusNode focusedChild,
    _TvTraversalCache cache,
  ) {
    if (candidates.length <= 1) return candidates;

    final Set<FocusNode> candidateSet = candidates.toSet();
    final Set<FocusNode> excluded = <FocusNode>{};
    final List<FocusNode> microNodes = <FocusNode>[];

    for (final FocusNode node in candidates) {
      if (node == focusedChild) continue;
      bool excludedByAncestor = false;
      for (final FocusNode ancestor in node.ancestors) {
        if (ancestor == focusedChild || !candidateSet.contains(ancestor)) {
          continue;
        }
        if (_isEmbeddedSecondaryOf(node, ancestor, cache)) {
          excluded.add(node);
          excludedByAncestor = true;
          break;
        }
      }
      if (excludedByAncestor) continue;
      if (tvCards.isMicroAction(cache.rectOf(node))) {
        microNodes.add(node);
      }
    }

    for (final FocusNode secondary in microNodes) {
      for (final FocusNode container in candidates) {
        if (container == secondary || container == focusedChild) continue;
        if (_isEmbeddedSecondaryOf(secondary, container, cache)) {
          excluded.add(secondary);
          break;
        }
      }
    }

    if (excluded.isEmpty) return candidates;
    return candidates
        .where((FocusNode node) => !excluded.contains(node))
        .toList();
  }

  void _focusNode(FocusNode node, TraversalDirection direction) {
    _frameState.lastPolicyScrolledNode = node;
    if (!_frameState.repeatLockedThisFrame) {
      _frameState.repeatLockedThisFrame = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _frameState.repeatLockedThisFrame = false;
        _frameState.didScrollInLastFocus = false;
      });
      WidgetsBinding.instance.ensureVisualUpdate();
    }
    final double beforeScroll = _sumUserScrollPixels(node.context);
    requestFocusCallback(
      node,
      alignmentPolicy: switch (direction) {
        TraversalDirection.up || TraversalDirection.left =>
          ScrollPositionAlignmentPolicy.keepVisibleAtStart,
        TraversalDirection.down || TraversalDirection.right =>
          ScrollPositionAlignmentPolicy.keepVisibleAtEnd,
      },
    );
    // A row runs across an Up or Down move, so the policy above checks only
    // one of its ends, and the card can be cut off at the other.
    final BuildContext? context = node.context;
    if (context != null &&
        context.mounted &&
        (direction == TraversalDirection.up ||
            direction == TraversalDirection.down)) {
      _ensureVisibleInUserScrollables(
        context,
        alignmentPolicy: direction == TraversalDirection.up
            ? ScrollPositionAlignmentPolicy.keepVisibleAtEnd
            : ScrollPositionAlignmentPolicy.keepVisibleAtStart,
        onlyAxis: Axis.horizontal,
      );
    }
    // The same along a vertical list on Left and Right, under the scorer
    // (bug 10), unless the node is taller than the list.
    if (scorer == TvFocusScorer.scored &&
        context != null &&
        context.mounted &&
        (direction == TraversalDirection.left ||
            direction == TraversalDirection.right) &&
        _fitsInVerticalList(context)) {
      _ensureVisibleInUserScrollables(
        context,
        alignmentPolicy: direction == TraversalDirection.left
            ? ScrollPositionAlignmentPolicy.keepVisibleAtEnd
            : ScrollPositionAlignmentPolicy.keepVisibleAtStart,
        onlyAxis: Axis.vertical,
      );
    }
    final double afterScroll = _sumUserScrollPixels(node.context);
    if ((afterScroll - beforeScroll).abs() > 0.5) {
      _frameState.didScrollInLastFocus = true;
    }
    // Consume the keyboard token immediately so D-pad directional focus
    // landing on an EditableText does not automatically open the soft keyboard.
    node.consumeKeyboardToken();
  }

  /// Whether the node at [context] fits inside the nearest vertical list the
  /// user can scroll around it.
  static bool _fitsInVerticalList(BuildContext context) {
    final RenderObject? box = context.findRenderObject();
    if (box is! RenderBox || !box.hasSize) return false;
    ScrollableState? scrollable = Scrollable.maybeOf(context);
    while (scrollable != null) {
      if (_canUserScroll(scrollable) &&
          scrollable.position.axis == Axis.vertical) {
        return box.size.height <= scrollable.position.viewportDimension;
      }
      final BuildContext next = scrollable.context;
      scrollable = next.mounted ? Scrollable.maybeOf(next) : null;
    }
    return false;
  }

  @override
  bool inDirection(FocusNode currentNode, TraversalDirection direction) {
    final FocusScopeNode? nearestScope = currentNode.nearestScope;
    if (nearestScope == null) return false;
    nearestScope.directionalTraversalEdgeBehavior = TraversalEdgeBehavior.stop;
    return _withCache((_TvTraversalCache cache) {
      final FocusNode? focusedChild = nearestScope.focusedChild;
      if (focusedChild == null || !cache.isEffectivelyFocusable(focusedChild)) {
        final FocusNode? firstFocus =
            (focusedChild == null
                ? findFirstFocusInDirection(currentNode, direction)
                : findRecoveryFocus(focusedChild, nearestScope)) ??
            findFirstFocus(currentNode, ignoreCurrentFocus: true);
        if (firstFocus != null) {
          _focusNode(firstFocus, direction);
          return true;
        }
        return false;
      }

      cache.evaluateNode(focusedChild, includeAncestorsIfUnfocusable: true);
      final ScrollableState? focusedScrollable = cache.verticalScrollableOf(
        focusedChild,
      );
      final Rect? focusedScrollableRect = cache.scrollableRect(
        focusedScrollable,
      );
      final ScrollableState? focusedHorizScrollable = cache
          .horizontalScrollableOf(focusedChild);
      final Rect target = cache.rectOf(focusedChild);
      final Rect rawVisualTarget = cache.visualRectOf(focusedChild);
      final Rect visualTarget =
          focusedScrollableRect != null &&
              !rawVisualTarget.isEmpty &&
              !focusedScrollableRect.isEmpty
          ? (rawVisualTarget.bottom <= focusedScrollableRect.top + 0.5
                ? rawVisualTarget.translate(
                    0.0,
                    focusedScrollableRect.top - rawVisualTarget.top,
                  )
                : (rawVisualTarget.top >= focusedScrollableRect.bottom - 0.5
                      ? rawVisualTarget.translate(
                          0.0,
                          focusedScrollableRect.bottom - rawVisualTarget.bottom,
                        )
                      : rawVisualTarget))
          : rawVisualTarget;

      final List<FocusNode> rawDescendants = <FocusNode>[];
      for (final FocusNode node in nearestScope.traversalDescendants) {
        if (node.context == null) continue;
        final RenderObject? ro = node.context!.findRenderObject();
        if (ro is RenderBox && ro.attached && ro.hasSize) {
          final Rect rawRect = cache.boxRect(ro);
          if (_isInOppositeHalfPlane(rawRect, target, direction) &&
              _isInOppositeHalfPlane(rawRect, visualTarget, direction)) {
            continue;
          }
        }
        if (cache.isEffectivelyFocusable(node)) {
          final Rect nr = cache.rectOf(node);
          if (!_isInOppositeHalfPlane(nr, target, direction) ||
              !_isInOppositeHalfPlane(nr, visualTarget, direction)) {
            rawDescendants.add(node);
          }
        }
      }
      final Set<FocusNode> rawSet = rawDescendants.toSet();
      final Set<FocusNode> nonLeafNodes = <FocusNode>{};
      for (final FocusNode node in rawDescendants) {
        final Element? nodeRow = cache.enclosingRowOf(node);
        final Rect nr = cache.rectOf(node);
        for (final FocusNode ancestor in node.ancestors) {
          if (!rawSet.contains(ancestor)) continue;
          final Rect ar = cache.rectOf(ancestor);
          final bool sameSizeWrapper =
              (ar.width - nr.width).abs() < 8.0 &&
              (ar.height - nr.height).abs() < 8.0;
          final bool isEnclosingRow =
              nodeRow != null &&
              !sameSizeWrapper &&
              cache.enclosingRowOf(ancestor) == nodeRow;
          final bool isPrimaryCard =
              !sameSizeWrapper &&
              cache.enclosingCardOf(ancestor) != null &&
              _isEmbeddedSecondaryOf(node, ancestor, cache);
          if (!isEnclosingRow && !isPrimaryCard) {
            nonLeafNodes.add(ancestor);
          }
        }
      }

      final List<FocusNode> allNodes = rawDescendants
          .where(
            (FocusNode node) =>
                node != focusedChild && !nonLeafNodes.contains(node),
          )
          .toList();
      if (allNodes.isEmpty) return false;

      if (scorer == TvFocusScorer.scored) {
        final FocusNode? scored = _findScoredCandidate(
          focusedChild: focusedChild,
          visualTarget: visualTarget,
          allNodes: allNodes,
          direction: direction,
          cache: cache,
        );
        if (scored == null) return false;
        _focusNode(scored, direction);
        return true;
      }

      final FocusNode? chosen = switch (direction) {
        TraversalDirection.down || TraversalDirection.up =>
          _findVerticalCandidate(
            focusedChild: focusedChild,
            target: target,
            visualTarget: visualTarget,
            focusedScrollable: focusedScrollable,
            focusedScrollableRect: focusedScrollableRect,
            focusedHorizScrollable: focusedHorizScrollable,
            allNodes: allNodes,
            direction: direction,
            cache: cache,
          ),
        TraversalDirection.left || TraversalDirection.right =>
          _findHorizontalCandidate(
            focusedChild: focusedChild,
            target: visualTarget,
            focusedScrollable: focusedScrollable,
            focusedScrollableRect: focusedScrollableRect,
            focusedHorizScrollable: focusedHorizScrollable,
            allNodes: allNodes,
            direction: direction,
            cache: cache,
          ),
      };

      if (chosen != null) {
        _focusNode(chosen, direction);
        return true;
      }
      return false;
    });
  }

  FocusNode? _findVerticalCandidate({
    required FocusNode focusedChild,
    required Rect target,
    required Rect visualTarget,
    required ScrollableState? focusedScrollable,
    required Rect? focusedScrollableRect,
    required ScrollableState? focusedHorizScrollable,
    required List<FocusNode> allNodes,
    required TraversalDirection direction,
    required _TvTraversalCache cache,
  }) {
    final bool isDown = direction == TraversalDirection.down;
    final Rect sameScrollableTarget = isDown ? visualTarget : target;
    final List<FocusNode> primaryNodes = _filterOutEmbeddedSecondaryActions(
      allNodes,
      focusedChild,
    cache,
    ).where((FocusNode node) {
      if (focusedChild.ancestors.contains(node)) return false;
      final ScrollableState? nodeHorizScrollable = cache.horizontalScrollableOf(
        node,
      );
      if (nodeHorizScrollable != null &&
          nodeHorizScrollable != focusedHorizScrollable) {
        final Rect? horizRect = cache.scrollableRect(nodeHorizScrollable);
        if (horizRect != null &&
            !_isRectVisibleHorizontallyInScrollable(
              cache.rectOf(node),
              horizRect,
            )) {
          return false;
        }
      }
      return true;
    }).toList();

    // 1. If currently inside a vertical scrollable, first traverse remaining
    // items within the same scrollable in the requested direction.
    if (focusedScrollable != null) {
      final List<FocusNode> sameScrollable = primaryNodes.where((
        FocusNode node,
      ) {
        if (cache.verticalScrollableOf(node) != focusedScrollable) return false;
        final Rect r = cache.rectOf(node);
        return isDown
            ? r.center.dy >= sameScrollableTarget.bottom
            : r.center.dy <= sameScrollableTarget.top;
      }).toList();
      if (sameScrollable.isNotEmpty) {
        return _pickFromClosestRow(
          referenceRect: sameScrollableTarget,
          candidates: sameScrollable,
          isDown: isDown,
          preferLeadingOnRow: false,
          cache: cache,
        );
      }
    }

    // 2. Otherwise, look for candidates outside the current scrollable (e.g.
    // exiting a scrollable to 取消/确定 below or header actions above, or
    // entering a scrollable from header/footer buttons).
    final double exitBoundary = focusedScrollableRect != null
        ? (isDown
              ? math.max(
                  math.min(visualTarget.bottom, focusedScrollableRect.bottom) -
                      2.0,
                  focusedScrollableRect.bottom - 4.0,
                )
              : math.min(
                  math.max(visualTarget.top, focusedScrollableRect.top) + 2.0,
                  focusedScrollableRect.top + 4.0,
                ))
        : (isDown ? visualTarget.bottom : visualTarget.top);

    final Rect referenceHorizontalRect = focusedScrollableRect ?? visualTarget;
    final List<FocusNode> externalCandidates = <FocusNode>[];
    final List<FocusNode> fallbackScrollableCandidates = <FocusNode>[];

    // Pre-calculate column-disjoint vertical band bounds to eliminate O(N^2) candidate scans.
    final List<(double, double)> adjacentColumnSpans = <(double, double)>[];
    for (final FocusNode other in primaryNodes) {
      final Rect otherBounds =
          cache.scrollableRect(cache.verticalScrollableOf(other)) ??
          cache.rectOf(other);
      final bool overlapsTargetVertically =
          otherBounds.bottom > visualTarget.top + 1.0 &&
          otherBounds.top < visualTarget.bottom - 1.0;
      final bool disjointFromTargetHorizontally =
          otherBounds.left >= visualTarget.right - 2.0 ||
          otherBounds.right <= visualTarget.left + 2.0;
      if (overlapsTargetVertically && disjointFromTargetHorizontally) {
        adjacentColumnSpans.add((otherBounds.left, otherBounds.right));
      }
    }

    for (final FocusNode node in primaryNodes) {
      final ScrollableState? nodeScrollable = cache.verticalScrollableOf(node);
      if (focusedScrollable != null && nodeScrollable == focusedScrollable) {
        continue;
      }
      final Rect nr = cache.rectOf(node);
      final Rect? nodeScrollableRect = cache.scrollableRect(nodeScrollable);
      if (nodeScrollable != null && nodeScrollableRect != null) {
        final bool overlapsHorizontally =
            referenceHorizontalRect.right > nodeScrollableRect.left + 2.0 &&
            referenceHorizontalRect.left < nodeScrollableRect.right - 2.0;
        if (!overlapsHorizontally) continue;
        final bool scrollableInDirection = isDown
            ? visualTarget.center.dy <= nodeScrollableRect.top + 4.0 ||
                  nodeScrollableRect.top >= exitBoundary - 4.0
            : visualTarget.center.dy >= nodeScrollableRect.bottom - 4.0 ||
                  nodeScrollableRect.bottom <= exitBoundary + 4.0;
        if (!scrollableInDirection) continue;
        if (_isRectVisibleInScrollable(nr, nodeScrollableRect)) {
          final bool nodeInDirection = isDown
              ? nr.center.dy >= visualTarget.bottom
              : nr.center.dy <= visualTarget.top;
          if (nodeInDirection) {
            externalCandidates.add(node);
          }
        } else {
          fallbackScrollableCandidates.add(node);
        }
      } else {
        if (focusedScrollableRect != null) {
          final bool overlapsFocusedScrollableHorizontally =
              nr.right > focusedScrollableRect.left + 2.0 &&
              nr.left < focusedScrollableRect.right - 2.0;
          if (!overlapsFocusedScrollableHorizontally) continue;
        } else {
          final bool overlapsTargetHorizontally =
              nr.right > visualTarget.left - 4.0 &&
              nr.left < visualTarget.right + 4.0;
          if (!overlapsTargetHorizontally) {
            // Reject candidates that belong to a separate side-by-side column
            // which already has items or a scrollable at target's vertical band.
            final bool belongsToAdjacentColumn = adjacentColumnSpans.any(
              ((double, double) span) =>
                  span.$2 > nr.left + 1.0 && span.$1 < nr.right - 1.0,
            );
            if (belongsToAdjacentColumn) continue;
          }
        }
        final bool nodeInDirection = isDown
            ? nr.center.dy >= exitBoundary &&
                  nr.center.dy > visualTarget.center.dy
            : nr.center.dy <= exitBoundary &&
                  nr.center.dy < visualTarget.center.dy;
        if (nodeInDirection) {
          externalCandidates.add(node);
        }
      }
    }

    final List<FocusNode> pool = externalCandidates.isNotEmpty
        ? externalCandidates
        : fallbackScrollableCandidates;
    if (pool.isEmpty) return null;

    return _pickFromClosestRow(
      referenceRect: visualTarget,
      candidates: pool,
      isDown: isDown,
      preferLeadingOnRow: isDown && focusedScrollable == null,
      cache: cache,
    );
  }

  static FocusNode _pickFromClosestRow({
    required Rect referenceRect,
    required List<FocusNode> candidates,
    required bool isDown,
    required bool preferLeadingOnRow,
    required _TvTraversalCache cache,
  }) {
    FocusNode closestVertical = candidates.first;
    Rect closestRect = cache.rectOf(closestVertical);
    for (final FocusNode node in candidates.skip(1)) {
      final Rect nr = cache.rectOf(node);
      if (isDown) {
        if (nr.center.dy < closestRect.center.dy) {
          closestVertical = node;
          closestRect = nr;
        }
      } else {
        if (nr.center.dy > closestRect.center.dy) {
          closestVertical = node;
          closestRect = nr;
        }
      }
    }

    final Rect rowBounds = closestRect;
    final List<FocusNode> row = candidates.where((FocusNode node) {
      final Rect r = cache.rectOf(node);
      return r.top < rowBounds.bottom - 1.0 && r.bottom > rowBounds.top + 1.0;
    }).toList();

    if (row.length <= 1) return closestVertical;
    row.sort(
      (FocusNode a, FocusNode b) =>
          cache.rectOf(a).left.compareTo(cache.rectOf(b).left),
    );
    if (preferLeadingOnRow && cache.verticalScrollableOf(row.first) != null) {
      return row.first;
    }

    final List<FocusNode> overlapping = row.where((FocusNode node) {
      final Rect r = cache.rectOf(node);
      return r.right > referenceRect.left + 1.0 &&
          r.left < referenceRect.right - 1.0;
    }).toList();

    if (overlapping.isNotEmpty) {
      final Rect firstRect = cache.rectOf(overlapping.first);
      if (overlapping.length > 1 &&
          referenceRect.left <= firstRect.center.dx &&
          referenceRect.right >= cache.rectOf(overlapping[1]).center.dx &&
          referenceRect.width > firstRect.width * 1.5) {
        return overlapping.first;
      }
      overlapping.sort(
        (FocusNode a, FocusNode b) =>
            (cache.rectOf(a).center.dx - referenceRect.center.dx)
                .abs()
                .compareTo(
                  (cache.rectOf(b).center.dx - referenceRect.center.dx).abs(),
                ),
      );
      return overlapping.first;
    }

    double horizontalGap(Rect r) {
      if (r.right <= referenceRect.left) return referenceRect.left - r.right;
      if (r.left >= referenceRect.right) return r.left - referenceRect.right;
      return 0;
    }

    row.sort((FocusNode a, FocusNode b) {
      final Rect ra = cache.rectOf(a);
      final Rect rb = cache.rectOf(b);
      final int cmp = horizontalGap(ra).compareTo(horizontalGap(rb));
      if (cmp != 0) return cmp;
      return (ra.center.dx - referenceRect.center.dx).abs().compareTo(
        (rb.center.dx - referenceRect.center.dx).abs(),
      );
    });
    return row.first;
  }

  FocusNode? _findHorizontalCandidate({
    required FocusNode focusedChild,
    required Rect target,
    required ScrollableState? focusedScrollable,
    required Rect? focusedScrollableRect,
    required ScrollableState? focusedHorizScrollable,
    required List<FocusNode> allNodes,
    required TraversalDirection direction,
    required _TvTraversalCache cache,
  }) {
    final bool isRight = direction == TraversalDirection.right;

    // 0. Support stepping between a row and its trailing focusable descendant
    // (e.g. refresh IconButton or Switch).
    final Element? focusedRow = cache.enclosingRowOf(focusedChild);
    if (focusedRow != null) {
      if (isRight) {
        final List<FocusNode> trailingChildren = allNodes.where((
          FocusNode node,
        ) {
          return node.ancestors.contains(focusedChild) &&
              cache.enclosingRowOf(node) == focusedRow &&
              tvListTiles.isSecondaryIn(cache.rectOf(node), target);
        }).toList();
        if (trailingChildren.isNotEmpty) {
          trailingChildren.sort(
            (FocusNode a, FocusNode b) =>
                cache.rectOf(a).left.compareTo(cache.rectOf(b).left),
          );
          return trailingChildren.first;
        }
      } else {
        final List<FocusNode> parentContainers = allNodes.where((
          FocusNode node,
        ) {
          return focusedChild.ancestors.contains(node) &&
              cache.enclosingRowOf(node) == focusedRow &&
              tvListTiles.isSecondaryIn(target, cache.rectOf(node));
        }).toList();
        if (parentContainers.isNotEmpty) {
          parentContainers.sort(
            (FocusNode a, FocusNode b) =>
                cache.rectOf(b).left.compareTo(cache.rectOf(a).left),
          );
          return parentContainers.first;
        }
      }
    }

    // 0b. Support stepping across sibling actions embedded inside a primary
    // card and stepping Left from the leftmost action back to the enclosing
    // card.
    FocusNode? parentCard;
    if (focusedRow == null && cache.enclosingActionOf(focusedChild) != null) {
      for (final FocusNode ancestor in focusedChild.ancestors) {
        if (cache.isEffectivelyFocusable(ancestor) &&
            cache.enclosingCardOf(ancestor) != null &&
            cache.enclosingActionOf(ancestor) == null &&
            cache.enclosingRowOf(ancestor) == null &&
            _isEmbeddedSecondaryOf(focusedChild, ancestor, cache)) {
          parentCard = ancestor;
          break;
        }
      }
    }
    if (parentCard != null) {
      final List<FocusNode> siblingActions = allNodes.where((FocusNode node) {
        if (!node.ancestors.contains(parentCard)) return false;
        if (cache.enclosingActionOf(node) == null) return false;
        final Rect r = cache.rectOf(node);
        final bool sameBand =
            r.bottom > target.top + 1.0 && r.top < target.bottom - 1.0;
        if (!sameBand) return false;
        return isRight
            ? r.center.dx > target.center.dx + 4.0
            : r.center.dx < target.center.dx - 4.0;
      }).toList();
      if (siblingActions.isNotEmpty) {
        siblingActions.sort(
          (FocusNode a, FocusNode b) => isRight
              ? cache.rectOf(a).left.compareTo(cache.rectOf(b).left)
              : cache.rectOf(b).right.compareTo(cache.rectOf(a).right),
        );
        return siblingActions.first;
      }
      if (!isRight) {
        return parentCard;
      }
    }

    FocusNode? embeddedCardActionFallback() {
      if (!isRight ||
          focusedRow != null ||
          cache.enclosingCardOf(focusedChild) == null ||
          cache.enclosingActionOf(focusedChild) != null) {
        return null;
      }
      final List<FocusNode> embeddedActions = allNodes.where((FocusNode node) {
        return node.ancestors.contains(focusedChild) &&
            cache.enclosingActionOf(node) != null &&
            _isEmbeddedSecondaryOf(node, focusedChild, cache);
      }).toList();
      return _findFirstReadingOrderNode(embeddedActions, cache);
    }

    final List<FocusNode> primaryNodes = _filterOutEmbeddedSecondaryActions(
      allNodes,
      focusedChild,
      cache,
    ).where((FocusNode node) => !focusedChild.ancestors.contains(node)).toList();

    // 1. If currently inside a horizontal scrollable, traverse remaining items
    // within that horizontal scrollable before exiting to a sidebar.
    if (focusedHorizScrollable != null) {
      final List<FocusNode> sameHorizScrollable = primaryNodes.where((
        FocusNode node,
      ) {
        if (cache.horizontalScrollableOf(node) != focusedHorizScrollable) {
          return false;
        }
        final Rect r = cache.rectOf(node);
        final bool sameRow =
            r.bottom > target.top + 1.0 && r.top < target.bottom - 1.0;
        if (!sameRow) return false;
        return isRight
            ? r.center.dx >= target.right
            : r.center.dx <= target.left;
      }).toList();
      if (sameHorizScrollable.isNotEmpty) {
        sameHorizScrollable.sort((FocusNode a, FocusNode b) {
          final Rect ra = cache.rectOf(a);
          final Rect rb = cache.rectOf(b);
          final double distA = math.max(
            0.0,
            isRight ? ra.left - target.right : target.left - ra.right,
          );
          final double distB = math.max(
            0.0,
            isRight ? rb.left - target.right : target.left - rb.right,
          );
          final int cmp = distA.compareTo(distB);
          if (cmp != 0) return cmp;
          return (ra.center.dy - target.center.dy).abs().compareTo(
            (rb.center.dy - target.center.dy).abs(),
          );
        });
        return sameHorizScrollable.first;
      }
    }

    final List<FocusNode> directionalNodes = primaryNodes.where((
      FocusNode node,
    ) {
      final Rect nr = cache.rectOf(node);
      final bool inHorizDirection = isRight
          ? nr.center.dx >= target.right
          : nr.center.dx <= target.left;
      if (!inHorizDirection) return false;
      final ScrollableState? nodeScrollable = cache.verticalScrollableOf(node);
      if (nodeScrollable != null && nodeScrollable != focusedScrollable) {
        final Rect? nodeScrollableRect = cache.scrollableRect(nodeScrollable);
        if (nodeScrollableRect != null &&
            !_isRectVisibleInScrollable(nr, nodeScrollableRect)) {
          return false;
        }
      }
      final ScrollableState? nodeHorizScrollable = cache.horizontalScrollableOf(
        node,
      );
      if (nodeHorizScrollable != null &&
          nodeHorizScrollable != focusedHorizScrollable) {
        final Rect? horizRect = cache.scrollableRect(nodeHorizScrollable);
        if (horizRect != null &&
            !_isRectVisibleHorizontallyInScrollable(nr, horizRect)) {
          return false;
        }
      }
      return true;
    }).toList();

    if (directionalNodes.isEmpty) return embeddedCardActionFallback();

    // 2. Prefer candidates on the same visual row (vertically overlapping target).
    final Rect scrollTarget = cache.rectOf(focusedChild);
    final List<FocusNode> inBand = directionalNodes.where((FocusNode node) {
      final Rect r = cache.rectOf(node);
      final Rect bandTarget =
          (focusedScrollable != null &&
              cache.verticalScrollableOf(node) == focusedScrollable)
          ? scrollTarget
          : target;
      return r.bottom > bandTarget.top + 1.0 &&
          r.top < bandTarget.bottom - 1.0;
    }).toList();

    if (inBand.isNotEmpty) {
      inBand.sort((FocusNode a, FocusNode b) {
        final Rect ra = cache.rectOf(a);
        final Rect rb = cache.rectOf(b);
        final double distA = math.max(
          0.0,
          isRight ? ra.left - target.right : target.left - ra.right,
        );
        final double distB = math.max(
          0.0,
          isRight ? rb.left - target.right : target.left - rb.right,
        );
        final int cmp = distA.compareTo(distB);
        if (cmp != 0) return cmp;
        final int centerCmp = (ra.center.dx - target.center.dx).abs().compareTo(
          (rb.center.dx - target.center.dx).abs(),
        );
        if (centerCmp != 0) return centerCmp;
        return (ra.center.dy - target.center.dy).abs().compareTo(
          (rb.center.dy - target.center.dy).abs(),
        );
      });
      return inBand.first;
    }

    // 3. Only fall back to out-of-band candidates when crossing between
    // genuinely side-by-side panels (not vertically stacked rows/sections).
    final Element? focusedWrap = cache.enclosingWrapOf(focusedChild);
    final List<FocusNode> sideBySide = directionalNodes.where((FocusNode node) {
      final ScrollableState? nodeScrollable = cache.verticalScrollableOf(node);
      if (focusedScrollable != null && nodeScrollable == focusedScrollable) {
        return false;
      }
      if (focusedWrap != null && cache.enclosingWrapOf(node) == focusedWrap) {
        return false;
      }
      final Rect nr = cache.rectOf(node);
      if (nr.right > target.left + 1.0 && nr.left < target.right - 1.0) {
        return false;
      }
      if (focusedScrollableRect != null) {
        final bool overlapsFocusedScrollableVertically =
            nr.center.dy >= focusedScrollableRect.top + 4.0 &&
            nr.center.dy <= focusedScrollableRect.bottom - 4.0;
        final bool outsideFocusedScrollableHorizontally = isRight
            ? nr.left >= focusedScrollableRect.right - 2.0
            : nr.right <= focusedScrollableRect.left + 2.0;
        if (!overlapsFocusedScrollableVertically ||
            !outsideFocusedScrollableHorizontally) {
          return false;
        }
      }
      final Rect? nodeScrollableRect = cache.scrollableRect(nodeScrollable);
      if (nodeScrollableRect != null) {
        final bool targetOverlapsNodeScrollableVertically =
            target.center.dy >= nodeScrollableRect.top + 4.0 &&
            target.center.dy <= nodeScrollableRect.bottom - 4.0;
        final bool targetOutsideNodeScrollableHorizontally = isRight
            ? nodeScrollableRect.left >= target.right - 2.0
            : nodeScrollableRect.right <= target.left + 2.0;
        if (!targetOverlapsNodeScrollableVertically ||
            !targetOutsideNodeScrollableHorizontally) {
          return false;
        }
      }
      if (focusedScrollable == null && nodeScrollable == null) {
        final double minY = math.min(target.bottom, nr.bottom);
        final double maxY = math.max(target.top, nr.top);
        final double gapLeft = isRight ? target.right : nr.right;
        final double gapRight = isRight ? nr.left : target.left;
        final bool separatedByIntermediateSection = primaryNodes.any((
          FocusNode other,
        ) {
          if (other == node) return false;
          final Rect r =
              cache.scrollableRect(cache.verticalScrollableOf(other)) ??
              cache.rectOf(other);
          final bool verticallyBetween =
              r.center.dy > minY - 2.0 && r.center.dy < maxY + 2.0;
          final bool spansAcrossGap =
              r.left < gapRight + 4.0 && r.right > gapLeft - 4.0;
          return verticallyBetween && spansAcrossGap;
        });
        if (separatedByIntermediateSection) return false;
      }
      return true;
    }).toList();

    if (sideBySide.isEmpty) return embeddedCardActionFallback();

    sideBySide.sort((FocusNode a, FocusNode b) {
      final Rect ra = cache.rectOf(a);
      final Rect rb = cache.rectOf(b);
      final int vCmp = (ra.center.dy - target.center.dy).abs().compareTo(
        (rb.center.dy - target.center.dy).abs(),
      );
      if (vCmp != 0) return vCmp;
      final double hDistA = isRight
          ? ra.left - target.right
          : target.left - ra.right;
      final double hDistB = isRight
          ? rb.left - target.right
          : target.left - rb.right;
      return hDistA.compareTo(hDistB);
    });
    return sideBySide.first;
  }
}

class _TvArrowFocusIntent extends Intent {
  const _TvArrowFocusIntent(this.direction);

  final TraversalDirection direction;
}

class _TvDirectionalFocusAction extends Action<DirectionalFocusIntent> {
  _TvDirectionalFocusAction(this.policy);

  final FocusTraversalPolicy policy;

  @override
  bool invoke(DirectionalFocusIntent intent) {
    final FocusNode? primaryFocus = FocusManager.instance.primaryFocus;
    if (primaryFocus == null || primaryFocus.context == null) {
      return false;
    }
    return policy.inDirection(primaryFocus, intent.direction);
  }
}

class _TvArrowFocusAction extends Action<_TvArrowFocusIntent> {
  _TvArrowFocusAction(this.policy);

  final FocusTraversalPolicy policy;

  @override
  bool invoke(_TvArrowFocusIntent intent) {
    final FocusNode? primaryFocus = FocusManager.instance.primaryFocus;
    if (primaryFocus == null || primaryFocus.context == null) {
      return false;
    }
    return policy.inDirection(primaryFocus, intent.direction);
  }
}

/// Global TV wrapper that enables directional `NavigationMode`, installs
/// [TvFocusTraversalPolicy], gates soft-keyboard activation on `EditableText`
/// until explicit `Select`/`Enter` press, and renders a high-contrast focus
/// ring overlay around the active [FocusNode].
class TvNavigation extends StatefulWidget {
  const TvNavigation({
    super.key,
    this.onBack,
    required this.child,
  });

  /// Unused. Kept so the `onBack` argument `MyApp._builder` passes in
  /// `lib/main.dart` still compiles: Escape is handled by that file's early key
  /// handler, and Back by `PopScope` and the `Navigator`. Remove it together
  /// with the argument at an upstream-sync window.
  final VoidCallback? onBack;
  final Widget child;

  @override
  State<TvNavigation> createState() => _TvNavigationState();
}

/// Why a reconcile pass runs. The reason picks which steps of the pass apply;
/// the steps always run in one order, see [_TvNavigationState._reconcile].
enum _TvReconcileReason {
  /// Focus moved, or the app came back to the foreground: every step.
  focus,

  /// A frame found a modal layer that opened, closed or lost focus.
  layers,

  /// A frame found an inline sheet with work to do: one to register, to move
  /// focus into, or to give focus back from.
  sheets,

  /// A frame found focus resting on a scope with a node in it to focus.
  scope,

  /// A frame found the focused node out of reach.
  invalid,

  /// Select was pressed with nothing reachable focused.
  select,

  /// A scroll may have moved the focused node out of reach.
  scroll,

  /// A frame found the ring out of date: the last step alone.
  ring,
}

/// One reconcile pass, with what its trigger saw: the node it looked at, that
/// node's scope, the ring then, a node a recovery left pending, and the target
/// it found, which the pass falls back to.
class _TvPass {
  const _TvPass(
    this.reason, {
    this.node,
    this.scope,
    this.rect,
    this.invalidNode,
    this.target,
    this.clearRing = false,
  });

  final _TvReconcileReason reason;
  final FocusNode? node;
  final FocusScopeNode? scope;
  final Rect? rect;
  final FocusNode? invalidNode;
  final FocusNode? target;
  final bool clearRing;
}

class _TvNavigationState extends State<TvNavigation>
    with WidgetsBindingObserver {
  static const int _kDirectionalRepeatMinIntervalMs = 45;

  /// The mounted [TvNavigation]'s state. A persistent frame callback can't be
  /// removed, so one static callback is installed per process and forwards here
  /// instead of every state that ever existed registering (and staying
  /// reachable through) its own.
  static _TvNavigationState? _mounted;
  static bool _frameCallbackInstalled = false;

  static void _onPersistentFrame(Duration timeStamp) =>
      _mounted?._onFrame(timeStamp);

  final GlobalKey _key = GlobalKey();
  final TvFocusTraversalPolicy _policy = TvFocusTraversalPolicy();
  late final Map<Type, Action<Intent>> _actions = <Type, Action<Intent>>{
    DirectionalFocusIntent: _TvDirectionalFocusAction(_policy),
    _TvArrowFocusIntent: _TvArrowFocusAction(_policy),
  };
  final ValueNotifier<Rect?> _rectNotifier = ValueNotifier<Rect?>(null);
  final FocusNode _layerAnchor = FocusNode(
    debugLabel: 'TvFocusLayerAnchor',
    canRequestFocus: false,
    skipTraversal: true,
  );
  late final _TvFocusLayerStack _layers = _TvFocusLayerStack(
    providers: <TvFocusLayerProvider>[
      for (final TvFocusAdapter adapter in tvFocusAdapters)
        ...adapter.layerProviders(
          anchor: _layerAnchor,
          rememberTrigger: TvNavigationObserver.rememberFocusedNode,
        ),
    ],
    policy: _policy,
    showRing: (FocusNode node) => _updateRect(_computeFocusedRect(node)),
    currentRing: () => _rectNotifier.value,
    hideRing: () => _updateRect(null),
    focusMoved: () {
      _pendingInvalidNode = null;
      _pendingRecoveryRect = null;
    },
  );
  late final Stopwatch _repeatClock =
      WidgetsBinding.instance.samplingClock.stopwatch()..start();
  int? _lastDirectionalStepMs;

  /// A ring pass and a reconcile pass of another reason can each be pending
  /// once. A later request finds its kind pending and leaves it as it is.
  bool _ringPending = false;
  bool _passPending = false;
  FocusNode? _lastFocusedNode;
  FocusNode? _pendingInvalidNode;
  Rect? _pendingRecoveryRect;
  RenderBox? _lastTargetBox;
  Size? _lastTargetSize;
  Size? _lastRootSize;
  Offset? _lastParentDataOffset;
  double? _lastScrollOffset;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    HardwareKeyboard.instance.addHandler(_observeHardwareKeyEvent);
    FocusManager.instance.addListener(_onFocus);
    if (TvPlatform.isTv) {
      FocusManager.instance.highlightStrategy =
          FocusHighlightStrategy.alwaysTraditional;
    }
    _TvFocusLayerStack.current = _layers;
    _mounted = this;
    if (!_frameCallbackInstalled) {
      _frameCallbackInstalled = true;
      WidgetsBinding.instance.addPersistentFrameCallback(_onPersistentFrame);
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    HardwareKeyboard.instance.removeHandler(_observeHardwareKeyEvent);
    FocusManager.instance.removeListener(_onFocus);
    if (identical(_TvFocusLayerStack.current, _layers)) {
      _TvFocusLayerStack.current = null;
    }
    // A replacement state mounts (initState) before this one is disposed, so
    // only clear the slot if it still points here.
    if (identical(_mounted, this)) _mounted = null;
    _layers.dispose();
    _lastFocusedNode = null;
    _pendingInvalidNode = null;
    _lastTargetBox = null;
    _layerAnchor.dispose();
    _rectNotifier.dispose();
    super.dispose();
  }

  bool _observeHardwareKeyEvent(KeyEvent event) {
    if (!TvPlatform.isTv) return false;
    final LogicalKeyboardKey key = event.logicalKey;
    final bool isSelect =
        key == LogicalKeyboardKey.select ||
        key == LogicalKeyboardKey.enter ||
        key == LogicalKeyboardKey.numpadEnter ||
        key == LogicalKeyboardKey.gameButtonA;
    if (!isSelect) return false;
    if (event is KeyDownEvent) {
      _layers.sheets.selectPressed(FocusManager.instance.primaryFocus);
    } else if (event is KeyUpEvent) {
      _layers.sheets.selectReleased();
    }
    return false;
  }

  /// Focus layers: the modal ones first, then the inline sheets. Returns
  /// `true` when either moved focus or is waiting on a layer, so the caller
  /// skips its own recovery.
  bool _reconcileFocusLayers() {
    if (!mounted || !TvPlatform.isTv) return false;
    return _layers.reconcile();
  }

  /// Schedules [pass] for the end of the next frame, outside of layout and
  /// paint. The flag of its kind stays set until it runs.
  void _requestReconcile(_TvPass pass) {
    final bool ringOnly = pass.reason == _TvReconcileReason.ring;
    if (ringOnly) {
      _ringPending = true;
    } else {
      _passPending = true;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (ringOnly) {
        _ringPending = false;
      } else {
        _passPending = false;
      }
      if (!mounted) return;
      _reconcile(pass);
    });
    WidgetsBinding.instance.ensureVisualUpdate();
  }

  /// The reconcile pass. Its steps run in this order, and [pass]'s reason
  /// picks the ones that apply:
  ///
  /// 1. Layers: the modal layers, then the inline sheets. A layer that moved
  ///    focus, or waits for its content, ends the pass, because any node a
  ///    later step picked would be behind it.
  /// 2. Validity: whether the focused node can still be focused.
  /// 3. Recovery: which node to focus instead. Each frame trigger keeps the
  ///    rules it has always had, and M13.4 adds column memory here.
  /// 4. Reveal: scroll the focused node into view.
  /// 5. Ring.
  ///
  /// A focus pass runs every step. A ring pass is step 5 alone, and a scroll
  /// pass is step 2 alone: when it unfocuses a node, the focus change that
  /// follows brings the rest. The others stop after their recovery, which
  /// sets the ring itself.
  void _reconcile(_TvPass pass) {
    final _TvReconcileReason reason = pass.reason;
    if (reason == _TvReconcileReason.ring) {
      _updateRect(
        pass.clearRing
            ? null
            : _computeFocusedRect(FocusManager.instance.primaryFocus),
      );
      return;
    }
    if (reason == _TvReconcileReason.scroll) {
      _dropUnreachableFocus();
      return;
    }

    // 1. Layers. Select leaves them to the frame while a scroll's recovery is
    // pending.
    if (reason == _TvReconcileReason.select) {
      if (_pendingInvalidNode != null || _reconcileFocusLayers()) {
        WidgetsBinding.instance.ensureVisualUpdate();
        return;
      }
    } else if (_reconcileFocusLayers()) {
      return;
    }

    // 2–3. Validity and recovery, for what the trigger saw.
    switch (reason) {
      case _TvReconcileReason.layers:
        return;
      case _TvReconcileReason.sheets:
        _recoverAfterSheets();
        return;
      case _TvReconcileReason.scope:
        _recoverFromScope(pass);
        return;
      case _TvReconcileReason.invalid:
        _recoverInvalid(pass);
        return;
      case _TvReconcileReason.select:
        _recoverOnSelect(pass.node);
        return;
      case _TvReconcileReason.focus:
      case _TvReconcileReason.scroll:
      case _TvReconcileReason.ring:
        break;
    }

    final FocusNode? node = FocusManager.instance.primaryFocus;
    if (node is FocusScopeNode) {
      _focusFromScope(node);
      return;
    }
    final FocusScopeNode? currentScope = node?.nearestScope;
    if (node != null &&
        currentScope != null &&
        !tvIsScopeInactive(currentScope)) {
      // 2. Validity.
      if (!TvFocusTraversalPolicy.isEffectivelyFocusable(node)) {
        // 3. Recovery.
        final FocusNode? first = _policy.findRecoveryFocus(
          node,
          currentScope,
          previousRect: _rectNotifier.value,
        );
        if (first != null &&
            first != node &&
            first.canRequestFocus &&
            (first.context?.mounted ?? false)) {
          first
            ..requestFocus()
            ..consumeKeyboardToken();
          _updateRect(_computeFocusedRect(first));
          return;
        }
        _updateRect(null);
        return;
      }
      TvNavigationObserver.rememberFocusedNode(node);
    }
    // 4. Reveal.
    final BuildContext? context = node?.context;
    if (context != null && context.mounted && node != null) {
      if (!_policy.consumePolicyScrolledNode(node)) {
        TvFocusTraversalPolicy._ensureVisibleInUserScrollables(
          context,
          alignmentPolicy: ScrollPositionAlignmentPolicy.keepVisibleAtEnd,
        );
        TvFocusTraversalPolicy._ensureVisibleInUserScrollables(
          context,
          alignmentPolicy: ScrollPositionAlignmentPolicy.keepVisibleAtStart,
        );
      }
    }
    // 5. Ring.
    if (!mounted || node != FocusManager.instance.primaryFocus) return;
    _updateRect(_computeFocusedRect(node));
  }

  /// Recovery for a focus pass that found focus on a scope [node]: the node a
  /// scroll left pending, else the scope's first node.
  void _focusFromScope(FocusScopeNode node) {
    FocusScopeNode targetScope = node;
    if (tvIsScopeInactive(node)) {
      targetScope = tvFindActiveSiblingScope(node) ?? node;
    }
    final FocusNode? pendingInvalid = _pendingInvalidNode;
    final Rect? pendingRect = _pendingRecoveryRect;
    _pendingInvalidNode = null;
    _pendingRecoveryRect = null;
    if (_layers.sheets.hasUnpromotedIn(targetScope)) {
      _updateRect(null);
      return;
    }
    final FocusNode? first = pendingInvalid != null
        ? _policy.findRecoveryFocus(
            pendingInvalid,
            targetScope,
            previousRect: pendingRect,
          )
        : _policy.findFirstFocus(targetScope);
    if (first != null) {
      if (targetScope != node) {
        targetScope.enclosingScope?.setFirstFocus(targetScope);
      }
      first
        ..requestFocus()
        ..consumeKeyboardToken();
      _updateRect(_computeFocusedRect(first));
    } else {
      targetScope.nextFocus();
      _updateRect(null);
    }
  }

  /// Recovery for a sheets pass whose layers did nothing: focus on a scope, or
  /// on a node out of reach, moves to the nearest node.
  void _recoverAfterSheets() {
    final FocusNode? current = FocusManager.instance.primaryFocus;
    final FocusScopeNode? scope = current is FocusScopeNode
        ? current
        : current?.nearestScope;
    if (current == null || scope == null || tvIsScopeInactive(scope)) return;
    if (current is FocusScopeNode && _layers.sheets.hasUnpromotedIn(scope)) {
      _updateRect(null);
      return;
    }
    if (current is FocusScopeNode ||
        !TvFocusTraversalPolicy.isEffectivelyFocusable(current)) {
      final FocusNode? fallback = _policy.findRecoveryFocus(
        current is FocusScopeNode ? null : current,
        scope,
        previousRect: _rectNotifier.value,
      );
      if (fallback != null &&
          fallback != current &&
          fallback.canRequestFocus &&
          (fallback.context?.mounted ?? false)) {
        fallback
          ..requestFocus()
          ..consumeKeyboardToken();
        _updateRect(_computeFocusedRect(fallback));
        return;
      }
      _updateRect(null);
    }
  }

  /// Recovery for a frame that found focus on the scope [_TvPass.node], if
  /// focus is still there: what the frame found, looked up again.
  void _recoverFromScope(_TvPass pass) {
    final FocusScopeNode targetScope = pass.scope!;
    if (_layers.sheets.hasUnpromotedIn(targetScope)) {
      _updateRect(null);
      return;
    }
    final FocusNode? pendingInvalid = pass.invalidNode;
    final FocusNode resolvedFirst =
        (pendingInvalid != null
            ? _policy.findRecoveryFocus(
                pendingInvalid,
                targetScope,
                previousRect: pass.rect,
              )
            : _policy.findFirstFocus(targetScope)) ??
        pass.target!;
    if (FocusManager.instance.primaryFocus == pass.node &&
        !tvIsScopeInactive(targetScope) &&
        targetScope.canRequestFocus &&
        resolvedFirst.canRequestFocus &&
        (resolvedFirst.context?.mounted ?? false)) {
      _pendingInvalidNode = null;
      _pendingRecoveryRect = null;
      if (targetScope != pass.node) {
        targetScope.enclosingScope?.setFirstFocus(targetScope);
      }
      resolvedFirst
        ..requestFocus()
        ..consumeKeyboardToken();
      _updateRect(_computeFocusedRect(resolvedFirst));
    }
  }

  /// Recovery for a frame that found [_TvPass.node] out of reach, if it is
  /// still focused and still out of reach.
  void _recoverInvalid(_TvPass pass) {
    final FocusNode node = pass.node!;
    final FocusNode resolvedFirst =
        _policy.findRecoveryFocus(
          node,
          pass.scope!,
          previousRect: pass.rect,
        ) ??
        pass.target!;
    if (FocusManager.instance.primaryFocus == node &&
        !TvFocusTraversalPolicy.isEffectivelyFocusable(node) &&
        resolvedFirst.canRequestFocus &&
        (resolvedFirst.context?.mounted ?? false)) {
      resolvedFirst
        ..requestFocus()
        ..consumeKeyboardToken();
      _updateRect(_computeFocusedRect(resolvedFirst));
    }
  }

  /// Recovery for Select pressed on [primary], which was out of reach.
  void _recoverOnSelect(FocusNode? primary) {
    final FocusScopeNode? scope = primary is FocusScopeNode
        ? primary
        : primary?.nearestScope;
    if (scope == null || _layers.sheets.hasUnpromotedIn(scope)) return;
    final FocusNode? recovered = _policy.findRecoveryFocus(
      primary,
      scope,
      previousRect: _rectNotifier.value,
    );
    if (recovered != null &&
        recovered.canRequestFocus &&
        (recovered.context?.mounted ?? false)) {
      recovered
        ..requestFocus()
        ..consumeKeyboardToken();
      _updateRect(_computeFocusedRect(recovered));
    }
  }

  /// Validity for a scroll: a focused node the scroll moved out of reach is
  /// unfocused at once, and its ring is kept for the recovery that the focus
  /// change brings.
  void _dropUnreachableFocus() {
    final FocusNode? primary = FocusManager.instance.primaryFocus;
    if (primary != null &&
        primary is! FocusScopeNode &&
        !TvFocusTraversalPolicy.isEffectivelyFocusable(primary)) {
      _pendingInvalidNode = primary;
      _pendingRecoveryRect = _rectNotifier.value ?? _pendingRecoveryRect;
      _lastFocusedNode = null;
      _lastTargetBox = null;
      primary.unfocus(disposition: UnfocusDisposition.scope);
      _updateRect(null);
      WidgetsBinding.instance.ensureVisualUpdate();
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && mounted && TvPlatform.isTv) {
      _lastFocusedNode = null;
      _lastTargetBox = null;
      _lastTargetSize = null;
      _lastRootSize = null;
      _lastParentDataOffset = null;
      _lastScrollOffset = null;
      _passPending = false;
      _ringPending = false;
      _onFocus();
      WidgetsBinding.instance.ensureVisualUpdate();
    }
  }

  bool _handleScrollNotification(ScrollNotification notification) {
    if (notification is ScrollUpdateNotification ||
        notification is ScrollEndNotification) {
      _reconcile(const _TvPass(_TvReconcileReason.scroll));
    }
    return false;
  }

  Rect? _computeFocusedRect(FocusNode? node) {
    if (node == null ||
        node is FocusScopeNode ||
        !node.canRequestFocus ||
        node.skipTraversal ||
        _layers.occludes(node) ||
        tvSheets.inspect(node).isInvalidated) {
      return null;
    }
    final BuildContext? context = node.context;
    if (context == null || !context.mounted) return null;
    final RenderObject? target = context.findRenderObject();
    final RenderObject? root = _key.currentContext?.findRenderObject();
    if (target is RenderBox &&
        root is RenderBox &&
        target.attached &&
        target.hasSize &&
        root.hasSize &&
        _accumulatedParentOffset(target, root) != null) {
      final Rect candidate =
          target.localToGlobal(Offset.zero, ancestor: root) & target.size;
      final Rect viewport = Offset.zero & root.size;
      if (!candidate.hasNaN &&
          !candidate.isInfinite &&
          candidate.width > 0 &&
          candidate.height > 0 &&
          viewport.overlaps(candidate) &&
          candidate.width * candidate.height <
              root.size.width * root.size.height * .8) {
        return candidate;
      }
    }
    return null;
  }

  static bool _sameRect(Rect? a, Rect? b) {
    if (identical(a, b)) return true;
    if (a == null || b == null) return false;
    return (a.left - b.left).abs() < 0.5 &&
        (a.top - b.top).abs() < 0.5 &&
        (a.right - b.right).abs() < 0.5 &&
        (a.bottom - b.bottom).abs() < 0.5;
  }

  void _updateRect(Rect? next) {
    if (!_sameRect(next, _rectNotifier.value)) {
      _rectNotifier.value = next;
    }
  }

  static Offset? _accumulatedParentOffset(RenderBox ro, RenderBox rootRo) {
    double dx = 0.0;
    double dy = 0.0;
    RenderObject? current = ro;
    while (current != null && !identical(current, rootRo)) {
      if (current is RenderOffstage && current.offstage) {
        return null;
      }
      if (current is RenderBox &&
          (!current.hasSize ||
              current.size.width < 1.0 ||
              current.size.height < 1.0)) {
        return null;
      }
      final Object? pd = current.parentData;
      if (pd is KeepAliveParentDataMixin && pd.keptAlive) {
        return null;
      }
      final RenderObject? parent = current.parent;
      if (pd is SliverMultiBoxAdaptorParentData &&
          pd.index != null &&
          parent is RenderSliverFillViewport) {
        RenderObject? viewport = parent.parent;
        while (viewport != null && viewport is! RenderViewportBase) {
          viewport = viewport.parent;
        }
        if (viewport is RenderViewportBase) {
          final Object offset = viewport.offset;
          if (offset is PageMetrics &&
              offset.hasPixels &&
              offset.hasContentDimensions) {
            final double? page = offset.page;
            if (page != null && (page - pd.index!).abs() > 0.5) {
              return null;
            }
          }
        }
      }
      if (pd is BoxParentData) {
        dx += pd.offset.dx;
        dy += pd.offset.dy;
      } else if (pd is SliverLogicalParentData) {
        dy += pd.layoutOffset ?? 0.0;
      }
      if (current is RenderFractionalTranslation && current.hasSize) {
        dx += current.translation.dx * current.size.width;
        dy += current.translation.dy * current.size.height;
      }
      if (current is RenderViewportBase && current.offset.hasPixels) {
        switch (current.axisDirection) {
          case AxisDirection.down:
            dy -= current.offset.pixels;
          case AxisDirection.up:
            dy += current.offset.pixels;
          case AxisDirection.right:
            dx -= current.offset.pixels;
          case AxisDirection.left:
            dx += current.offset.pixels;
        }
      }
      current = parent;
    }
    return Offset(dx, dy);
  }

  /// The frame check. Layout can move the focused node without any event, so
  /// each frame something else produced looks at a few cheap signals and asks
  /// for a reconcile pass when one of them changed. It never asks for a frame
  /// by itself, so a still screen costs nothing.
  void _onFrame(Duration _) {
    if (!mounted || !TvPlatform.isTv) return;
    final FocusNode? node = FocusManager.instance.primaryFocus;

    // Focus layers come first, ahead of the stationary fast path: a layer that
    // opens, closes or loses focus must be handled even though the focused
    // node itself has not moved. With no layer open this is one empty-list
    // check.
    if (_layers.hasPendingWork(node)) {
      _lastFocusedNode = null;
      _lastTargetBox = null;
      if (!_passPending) {
        _requestReconcile(const _TvPass(_TvReconcileReason.layers));
      }
      return;
    }
    if (_layers.isSettling(
      SchedulerBinding.instance.currentSystemFrameTimeStamp,
    )) {
      // Re-measure the ring while the layer's open transition is still moving.
      _lastFocusedNode = null;
      _lastTargetBox = null;
    }

    if (_layers.sheets.frameHasWork(node)) {
      _lastFocusedNode = null;
      _lastTargetBox = null;
      if (!_passPending) {
        _requestReconcile(const _TvPass(_TvReconcileReason.sheets));
      }
      return;
    }
    if (_ringPending) return;
    if (node == null || node is FocusScopeNode) {
      if (node is FocusScopeNode && !_passPending) {
        FocusScopeNode targetScope = node;
        if (tvIsScopeInactive(node)) {
          targetScope = tvFindActiveSiblingScope(node) ?? node;
        }
        if (!_layers.sheets.hasUnpromotedIn(targetScope)) {
          final FocusNode? pendingInvalid = _pendingInvalidNode;
          final Rect? pendingRect = _pendingRecoveryRect;
          final FocusNode? first = pendingInvalid != null
              ? _policy.findRecoveryFocus(
                  pendingInvalid,
                  targetScope,
                  previousRect: pendingRect,
                )
              : _policy.findFirstFocus(targetScope);
          if (first != null) {
            _requestReconcile(
              _TvPass(
                _TvReconcileReason.scope,
                node: node,
                scope: targetScope,
                rect: pendingRect,
                invalidNode: pendingInvalid,
                target: first,
              ),
            );
            return;
          }
        }
      }
      _lastFocusedNode = null;
      _lastTargetBox = null;
      _lastTargetSize = null;
      _lastRootSize = null;
      _lastParentDataOffset = null;
      _lastScrollOffset = null;
      if (_rectNotifier.value != null) {
        _requestReconcile(
          const _TvPass(_TvReconcileReason.ring, clearRing: true),
        );
      }
      return;
    }

    // A popup route that is active but never took focus (showMenu with
    // requestFocus: false) is handled in the layer stack.
    final FocusScopeNode? currentScope = node.nearestScope;

    final BuildContext? context = node.context;
    final RenderObject? ro = (context != null && context.mounted)
        ? context.findRenderObject()
        : null;
    final RenderObject? rootRo = _key.currentContext?.findRenderObject();
    final RenderBox? targetBox = (ro is RenderBox && ro.attached && ro.hasSize)
        ? ro
        : null;
    final RenderBox? rootBox =
        (rootRo is RenderBox && rootRo.attached && rootRo.hasSize)
        ? rootRo
        : null;
    final Offset? parentOffset = (targetBox != null && rootBox != null)
        ? _accumulatedParentOffset(targetBox, rootBox)
        : null;
    final ScrollableState? scrollable = (context != null && context.mounted)
        ? Scrollable.maybeOf(context)
        : null;
    final double? scrollPixels = scrollable?.position.hasPixels == true
        ? scrollable!.position.pixels
        : null;

    final bool isStationary =
        targetBox != null &&
        rootBox != null &&
        parentOffset != null &&
        node.canRequestFocus &&
        !node.skipTraversal &&
        node == _lastFocusedNode &&
        targetBox == _lastTargetBox &&
        targetBox.size == _lastTargetSize &&
        rootBox.size == _lastRootSize &&
        parentOffset == _lastParentDataOffset &&
        scrollPixels == _lastScrollOffset &&
        _rectNotifier.value != null;

    if (isStationary) return;

    if (currentScope != null &&
        !tvIsScopeInactive(currentScope) &&
        !_passPending &&
        (parentOffset == null ||
            !TvFocusTraversalPolicy.isEffectivelyFocusable(node))) {
      final Rect? prevRect = _rectNotifier.value;
      final FocusNode? first = _policy.findRecoveryFocus(
        node,
        currentScope,
        previousRect: prevRect,
      );
      if (first != null && first != node) {
        _requestReconcile(
          _TvPass(
            _TvReconcileReason.invalid,
            node: node,
            scope: currentScope,
            rect: prevRect,
            target: first,
          ),
        );
        return;
      }
    }

    if (targetBox == null || rootBox == null) {
      if (_rectNotifier.value != null && !_passPending) {
        _requestReconcile(const _TvPass(_TvReconcileReason.ring));
      }
      return;
    }

    final Rect? rect = _computeFocusedRect(node);
    _lastFocusedNode = node;
    _lastTargetBox = targetBox;
    _lastTargetSize = targetBox.size;
    _lastRootSize = rootBox.size;
    _lastParentDataOffset = parentOffset;
    _lastScrollOffset = scrollPixels;

    if (_sameRect(rect, _rectNotifier.value) || _passPending) return;
    _requestReconcile(const _TvPass(_TvReconcileReason.ring));
  }

  /// The focus listener: a focus pass at the end of the next frame. When no
  /// frame is being built and the step didn't scroll, the ring moves at once
  /// as well, so it doesn't trail the key by a frame.
  void _onFocus() {
    _lastFocusedNode = null;
    _lastTargetBox = null;
    if (!TvPlatform.isTv) return;
    _layers.sheets.markDirty();
    final FocusNode? immediateNode = FocusManager.instance.primaryFocus;
    if (immediateNode != null &&
        immediateNode is! FocusScopeNode &&
        !identical(immediateNode, _pendingInvalidNode)) {
      _pendingInvalidNode = null;
      _pendingRecoveryRect = null;
    }
    if (SchedulerBinding.instance.schedulerPhase == SchedulerPhase.idle &&
        !_policy.didScrollInLastFocus) {
      final FocusScopeNode? immediateScope = immediateNode?.nearestScope;
      if (immediateNode != null &&
          immediateNode is! FocusScopeNode &&
          immediateScope != null &&
          !tvIsScopeInactive(immediateScope)) {
        _updateRect(_computeFocusedRect(immediateNode));
      }
    }
    if (_passPending) {
      WidgetsBinding.instance.ensureVisualUpdate();
      return;
    }
    _requestReconcile(const _TvPass(_TvReconcileReason.focus));
  }

  static bool _isDirectionalKey(LogicalKeyboardKey key) =>
      key == LogicalKeyboardKey.arrowUp ||
      key == LogicalKeyboardKey.arrowDown ||
      key == LogicalKeyboardKey.arrowLeft ||
      key == LogicalKeyboardKey.arrowRight;

  KeyEventResult _handleKeyEvent(FocusNode _, KeyEvent event) {
    final LogicalKeyboardKey key = event.logicalKey;
    if (_isDirectionalKey(key)) {
      if (event is KeyRepeatEvent) {
        final int nowMs = _repeatClock.elapsedMilliseconds;
        if (_policy.isRepeatLockedThisFrame ||
            (_lastDirectionalStepMs != null &&
                nowMs - _lastDirectionalStepMs! <
                    _kDirectionalRepeatMinIntervalMs)) {
          return KeyEventResult.handled;
        }
        _lastDirectionalStepMs = nowMs;
      } else if (event is KeyDownEvent) {
        _lastDirectionalStepMs = _repeatClock.elapsedMilliseconds;
      }
      return KeyEventResult.ignored;
    }

    if (event is! KeyDownEvent) return KeyEventResult.ignored;
    final bool isSelectKey =
        key == LogicalKeyboardKey.select ||
        key == LogicalKeyboardKey.enter ||
        key == LogicalKeyboardKey.numpadEnter ||
        key == LogicalKeyboardKey.gameButtonA;
    if (isSelectKey) {
      final FocusNode? primary = FocusManager.instance.primaryFocus;
      if (primary == null ||
          primary is FocusScopeNode ||
          !TvFocusTraversalPolicy.isEffectivelyFocusable(primary)) {
        _reconcile(_TvPass(_TvReconcileReason.select, node: primary));
        return KeyEventResult.handled;
      }
      if (TvPlatform.isFocusedOnEditableText()) {
        TvPlatform.requestSoftKeyboard();
        return KeyEventResult.handled;
      }
    }
    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    if (!TvPlatform.isTv) return widget.child;
    Widget child = widget.child;
    MediaQueryData mediaQuery = MediaQuery.of(context);
    while (child is MediaQuery) {
      mediaQuery = child.data;
      child = child.child;
    }
    return MediaQuery(
      data: mediaQuery.copyWith(navigationMode: NavigationMode.directional),
      child: Shortcuts(
        shortcuts: const <ShortcutActivator, Intent>{
          SingleActivator(LogicalKeyboardKey.select): ActivateIntent(),
          SingleActivator(LogicalKeyboardKey.gameButtonA): ActivateIntent(),
          SingleActivator(LogicalKeyboardKey.arrowUp): _TvArrowFocusIntent(
            TraversalDirection.up,
          ),
          SingleActivator(LogicalKeyboardKey.arrowDown):
              _TvArrowFocusIntent(
                TraversalDirection.down,
              ),
          SingleActivator(LogicalKeyboardKey.arrowLeft):
              _TvArrowFocusIntent(
                TraversalDirection.left,
              ),
          SingleActivator(LogicalKeyboardKey.arrowRight):
              _TvArrowFocusIntent(
                TraversalDirection.right,
              ),
        },
        child: Actions(
          actions: _actions,
          child: Focus(
            canRequestFocus: false,
            skipTraversal: true,
            onKeyEvent: _handleKeyEvent,
            child: NotificationListener<ScrollNotification>(
              onNotification: _handleScrollNotification,
              child: Stack(
                key: _key,
                fit: StackFit.expand,
                children: <Widget>[
                  FocusTraversalGroup(
                    policy: _policy,
                    // Top of the subtree: the root Navigator's focus branch and
                    // those of overlay dialogs attach below it (see
                    // tv_popup_adapter.dart).
                    child: Focus(
                      focusNode: _layerAnchor,
                      canRequestFocus: false,
                      skipTraversal: true,
                      includeSemantics: false,
                      child: child,
                    ),
                  ),
                  // Under the ring, so the ring stays the last painter.
                  if (TvFocusTraversalPolicy.debugRecordScores)
                    const Positioned.fill(child: _TvScoreOverlay()),
                  Positioned.fill(
                    child: IgnorePointer(
                      child: RepaintBoundary(
                        child: ValueListenableBuilder<Rect?>(
                          valueListenable: _rectNotifier,
                          builder: (BuildContext context, Rect? rect, _) {
                            return CustomPaint(
                              painter: _TvFocusRingPainter(
                                rect,
                                repaint: _rectNotifier,
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _TvFocusRingPainter extends CustomPainter {
  const _TvFocusRingPainter(this.rect, {super.repaint});

  final Rect? rect;

  static final Paint _borderPaint = Paint()
    ..color = const Color(0xFFFFD166)
    ..style = PaintingStyle.stroke
    ..strokeWidth = 3.0;

  @override
  void paint(Canvas canvas, Size size) {
    final Rect? r = rect;
    if (r == null || r.isEmpty) return;
    final RRect rrect = RRect.fromRectAndRadius(
      r.inflate(2.0),
      const Radius.circular(12.0),
    );
    canvas.drawRRect(rrect, _borderPaint);
  }

  @override
  bool shouldRepaint(_TvFocusRingPainter oldDelegate) =>
      !_TvNavigationState._sameRect(rect, oldDelegate.rect);
}

/// Route observer that:
/// 1. Memorizes the last focused [FocusNode] for each [Route] before pushing a
///    new route or dialog and restores it when popping back.
/// 2. Tells the adapters about each pushed route, so that [TvLoginAdapter] can
///    open `/loginPage` on its `扫码登录` tab ([loginQrTabIndex]).
class TvNavigationObserver extends NavigatorObserver {
  static final Expando<FocusNode> _savedFocusByRoute = Expando<FocusNode>(
    'tvSavedFocusByRoute',
  );

  /// Records [node] as the last active focus node for its enclosing [ModalRoute].
  static void rememberFocusedNode(FocusNode node) {
    if (node is FocusScopeNode) return;
    final BuildContext? context = node.context;
    if (context == null || !context.mounted) return;
    final ModalRoute<dynamic>? route = tvRouteOfFocusNode(node);
    if (route != null) {
      _savedFocusByRoute[route] = node;
    }
  }

  /// Index of the `扫码` tab on the login page.
  static const int loginQrTabIndex = TvLoginAdapter.qrTabIndex;

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    super.didPush(route, previousRoute);
    if (!TvPlatform.isTv) return;
    if (previousRoute != null) {
      final FocusNode? current = FocusManager.instance.primaryFocus;
      if (current != null &&
          current is! FocusScopeNode &&
          (current.context?.mounted ?? false) &&
          TvFocusTraversalPolicy.isEffectivelyFocusable(current)) {
        final ModalRoute<dynamic>? owner = ModalRoute.of(current.context!);
        if (owner == null || owner == previousRoute) {
          _savedFocusByRoute[previousRoute] = current;
        }
      }
    }

    for (final TvFocusAdapter adapter in tvFocusAdapters) {
      adapter.didPushRoute(route);
    }
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    super.didPop(route, previousRoute);
    if (!TvPlatform.isTv || previousRoute == null) return;
    final FocusNode? savedNode = _savedFocusByRoute[previousRoute];
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (savedNode != null &&
          savedNode.canRequestFocus &&
          (savedNode.context?.mounted ?? false) &&
          TvFocusTraversalPolicy.isEffectivelyFocusable(savedNode)) {
        savedNode
          ..requestFocus()
          ..consumeKeyboardToken();
        return;
      }
      final FocusNode? primary = FocusManager.instance.primaryFocus;
      if (primary != null &&
          primary is! FocusScopeNode &&
          !TvFocusTraversalPolicy.isEffectivelyFocusable(primary)) {
        final FocusScopeNode? scope = primary.nearestScope;
        if (scope != null) {
          final FocusNode? fallback = TvFocusTraversalPolicy()
              .findRecoveryFocus(
                primary,
                scope,
              );
          if (fallback != null &&
              fallback.canRequestFocus &&
              (fallback.context?.mounted ?? false)) {
            fallback
              ..requestFocus()
              ..consumeKeyboardToken();
          }
        }
      }
    });
    WidgetsBinding.instance.ensureVisualUpdate();
  }
}
