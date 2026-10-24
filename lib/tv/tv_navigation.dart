import 'dart:math' as math;

import 'package:PiliPlus/common/widgets/flutter/list_tile.dart'
    as custom_list_tile;
import 'package:PiliPlus/common/widgets/scaffold/bottom_sheet_layout.dart'
    show BottomSheetLayout, BottomSheetType;
import 'package:PiliPlus/pages/login/controller.dart';
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
        RenderViewportBase,
        SliverLogicalParentData,
        SliverMultiBoxAdaptorParentData;
import 'package:flutter/scheduler.dart' show SchedulerBinding, SchedulerPhase;
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:material_ui/material_ui.dart';

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
    required this.isFocusable,
    required this.ancestorsComplete,
    required this.verticalScrollable,
    required this.horizontalScrollable,
    required this.enclosingListTile,
    required this.enclosingInkResponse,
    required this.enclosingWrap,
  });

  final Rect rect;
  final bool isFocusable;
  final bool ancestorsComplete;
  final ScrollableState? verticalScrollable;
  final ScrollableState? horizontalScrollable;
  final Element? enclosingListTile;
  final Element? enclosingInkResponse;
  final Element? enclosingWrap;
}

class _BottomSheetNodeStatus {
  const _BottomSheetNodeStatus({
    this.occludingLayout,
    this.closingLayout,
    this.enclosingActiveSheetLayout,
  });

  final Element? occludingLayout;
  final Element? closingLayout;
  final Element? enclosingActiveSheetLayout;

  bool get isInvalidated => occludingLayout != null || closingLayout != null;
}

class _TvTraversalCache {
  final Map<FocusNode, _TvNodeMeta> _nodeMeta = <FocusNode, _TvNodeMeta>{};
  final Map<RenderBox, Rect> _boxRects = <RenderBox, Rect>{};
  final Map<ScrollableState, Rect?> _scrollableRects =
      <ScrollableState, Rect?>{};

  static bool _isBottomSheetClosing(Widget? sheet) {
    if (sheet == null) return true;
    if (sheet is StandardBottomSheet) {
      final status = sheet.animationController.status;
      return status == AnimationStatus.reverse ||
          status == AnimationStatus.dismissed;
    }
    return false;
  }

  static bool _isBottomSheetAnimatingOpen(Widget? sheet) {
    if (sheet is StandardBottomSheet) {
      return sheet.animationController.status == AnimationStatus.forward;
    }
    return false;
  }

  static _BottomSheetNodeStatus _inspectBottomSheetNode(FocusNode? node) {
    final BuildContext? context = node?.context;
    if (context == null || !context.mounted) {
      return const _BottomSheetNodeStatus();
    }
    Element? occludingLayout;
    Element? closingLayout;
    Element? enclosingActiveSheetLayout;
    Element childElement = context as Element;
    context.visitAncestorElements((Element element) {
      final Object? childSlot = childElement.slot;
      childElement = element;
      final Widget widget = element.widget;
      if (widget is BottomSheetLayout) {
        final Widget? sheet = widget.bottomSheet;
        if (sheet != null) {
          final bool closing = _isBottomSheetClosing(sheet);
          if (childSlot == BottomSheetType.body && !closing) {
            occludingLayout = element;
          } else if (childSlot == BottomSheetType.bottomSheet) {
            if (closing) {
              closingLayout = element;
            } else {
              enclosingActiveSheetLayout ??= element;
            }
          }
        }
      }
      return true;
    });
    if (occludingLayout == null &&
        closingLayout == null &&
        enclosingActiveSheetLayout == null) {
      return const _BottomSheetNodeStatus();
    }
    return _BottomSheetNodeStatus(
      occludingLayout: occludingLayout,
      closingLayout: closingLayout,
      enclosingActiveSheetLayout: enclosingActiveSheetLayout,
    );
  }

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

  ScrollableState? verticalScrollableOf(FocusNode node) =>
      _metaWithAncestors(node).verticalScrollable;

  ScrollableState? horizontalScrollableOf(FocusNode node) =>
      _metaWithAncestors(node).horizontalScrollable;

  Element? enclosingListTileOf(FocusNode node) =>
      _metaWithAncestors(node).enclosingListTile;

  Element? enclosingInkResponseOf(FocusNode node) =>
      _metaWithAncestors(node).enclosingInkResponse;

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
        isFocusable: false,
        ancestorsComplete: true,
        verticalScrollable: null,
        horizontalScrollable: null,
        enclosingListTile: null,
        enclosingInkResponse: null,
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

    bool focusable =
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
        isFocusable: false,
        ancestorsComplete: false,
        verticalScrollable: null,
        horizontalScrollable: null,
        enclosingListTile: null,
        enclosingInkResponse: null,
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
    ScrollableState? verticalScrollable;
    ScrollableState? horizontalScrollable;
    Element? enclosingListTile;
    Element? enclosingInkResponse;
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
      if (enclosingListTile == null &&
          (widget is ListTile || widget is custom_list_tile.ListTile)) {
        enclosingListTile = element;
      }
      if (enclosingInkResponse == null && widget is InkResponse) {
        enclosingInkResponse = element;
      }
      if (enclosingWrap == null && widget is Wrap) {
        enclosingWrap = element;
      }

      if (!focusable) return true;

      if (widget is BottomSheetLayout) {
        final Widget? sheet = widget.bottomSheet;
        if (sheet != null) {
          final bool sheetClosing = _isBottomSheetClosing(sheet);
          if (childSlot == BottomSheetType.body && !sheetClosing) {
            focusable = false;
            return stopOrContinue();
          }
          if (childSlot == BottomSheetType.bottomSheet && sheetClosing) {
            focusable = false;
            return stopOrContinue();
          }
        }
      }

      final RenderObject? ancestorRo = element.renderObject;
      if (ancestorRo is RenderBox &&
          ancestorRo.attached &&
          ancestorRo.hasSize) {
        if (ancestorRo.size.width < 1.0 || ancestorRo.size.height < 1.0) {
          focusable = false;
          return stopOrContinue();
        }
        if (ancestorRo is RenderFractionalTranslation &&
            (ancestorRo.translation.dx.abs() > 0.01 ||
                ancestorRo.translation.dy.abs() > 0.01)) {
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

    if (focusable && (!insideScrollable || hasNonZeroTranslation)) {
      final view = View.maybeOf(context);
      if (view != null && view.devicePixelRatio > 0) {
        final Size logicalSize = view.physicalSize / view.devicePixelRatio;
        if (logicalSize.width > 1.0 && logicalSize.height > 1.0) {
          final Rect viewport = Offset.zero & logicalSize;
          visible = visible.intersect(viewport);
          if (visible.width <= 1.0 || visible.height <= 1.0) {
            focusable = false;
          }
        }
      }
    }

    final meta = _TvNodeMeta(
      rect: globalRect,
      isFocusable: focusable,
      ancestorsComplete: ancestorsComplete,
      verticalScrollable: verticalScrollable,
      horizontalScrollable: horizontalScrollable,
      enclosingListTile: enclosingListTile,
      enclosingInkResponse: enclosingInkResponse,
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

class TvFocusTraversalPolicy extends FocusTraversalPolicy {
  TvFocusTraversalPolicy({
    TraversalRequestFocusCallback? requestFocusCallback,
  }) : super(
         requestFocusCallback:
             requestFocusCallback ?? _defaultTvRequestFocusCallback,
       );

  final ReadingOrderTraversalPolicy _readingOrderPolicy =
      ReadingOrderTraversalPolicy();
  final _TvPolicyFrameState _frameState = _TvPolicyFrameState();

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
  }) {
    ScrollableState? scrollable = Scrollable.maybeOf(context);
    while (scrollable != null) {
      if (_canUserScroll(scrollable)) {
        final RenderObject? target = context.findRenderObject();
        if (target != null && target.attached) {
          scrollable.position.ensureVisible(
            target,
            alignment: alignment,
            duration: duration,
            curve: curve,
            alignmentPolicy: alignmentPolicy,
          );
        }
      }
      final BuildContext scrollableContext = scrollable.context;
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

  static Element? _slotChildOfBottomSheetLayout(
    Element layoutElement,
    BottomSheetType slot,
  ) {
    if (!layoutElement.mounted || layoutElement.widget is! BottomSheetLayout) {
      return null;
    }
    Element? found;
    layoutElement.visitChildren((Element child) {
      if (child.slot == slot) {
        found = child;
      }
    });
    return found;
  }

  FocusNode? findFirstFocusInSubtree(
    Element subtreeRoot,
    FocusScopeNode currentScope,
  ) => _withCache((_TvTraversalCache cache) {
    if (!subtreeRoot.mounted) return null;
    FocusNode? autofocusCandidate;
    final List<FocusNode> visibleInScrollables = <FocusNode>[];
    final List<FocusNode> fallbackCandidates = <FocusNode>[];
    for (final FocusNode node in currentScope.traversalDescendants) {
      if (!_isElementInSubtree(node.context, subtreeRoot)) continue;
      if (cache.isEffectivelyFocusable(node)) {
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
    final List<FocusNode> pool = visibleInScrollables.isNotEmpty
        ? visibleInScrollables
        : fallbackCandidates;
    return _findFirstReadingOrderNode(pool, cache);
  });

  /// Finds the best focus target in [currentScope] when [invalidNode] has
  /// become offscreen or unfocusable (e.g. after switching tabs in a
  /// `PageView`/`TabBarView`, opening/closing a `MiniScaffold` sheet, or
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
    final _BottomSheetNodeStatus sheetStatus =
        _TvTraversalCache._inspectBottomSheetNode(invalidNode);
    final Element? occludingLayout = sheetStatus.occludingLayout;
    if (occludingLayout != null && occludingLayout.widget is BottomSheetLayout) {
      final Element? sheetSlot = _slotChildOfBottomSheetLayout(
        occludingLayout,
        BottomSheetType.bottomSheet,
      );
      if (sheetSlot != null) {
        final FocusNode? inSheet = findFirstFocusInSubtree(
          sheetSlot,
          currentScope,
        );
        if (inSheet != null) return inSheet;
      }
      final Widget? sheet =
          (occludingLayout.widget as BottomSheetLayout).bottomSheet;
      if (_TvTraversalCache._isBottomSheetAnimatingOpen(sheet)) {
        return null;
      }
    }
    final Element? closingLayout = sheetStatus.closingLayout;
    if (closingLayout != null) {
      final Element? bodySlot = _slotChildOfBottomSheetLayout(
        closingLayout,
        BottomSheetType.body,
      );
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
      for (final FocusNode node in currentScope.traversalDescendants) {
        if (node == invalidNode) continue;
        if (cache.isEffectivelyFocusable(node) &&
            containerRect!.contains(cache.rectOf(node).center)) {
          if (cache.isVisibleInEnclosingScrollables(node)) {
            visibleInContainer.add(node);
          } else {
            fallbackInContainer.add(node);
          }
        }
      }
      final List<FocusNode> containerPool = visibleInContainer.isNotEmpty
          ? visibleInContainer
          : fallbackInContainer;
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
        cache.isVisibleInEnclosingScrollables(candidate)) {
      return candidate;
    }
    final List<FocusNode> visibleInScrollables = <FocusNode>[];
    final List<FocusNode> fallbackCandidates = <FocusNode>[];
    for (final FocusNode node in currentNode.traversalDescendants) {
      if (cache.isEffectivelyFocusable(node)) {
        if (cache.isVisibleInEnclosingScrollables(node)) {
          visibleInScrollables.add(node);
        } else {
          fallbackCandidates.add(node);
        }
      }
    }
    final List<FocusNode> pool = visibleInScrollables.isNotEmpty
        ? visibleInScrollables
        : fallbackCandidates;
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
        cache.isVisibleInEnclosingScrollables(candidate)) {
      return candidate;
    }
    final List<FocusNode> visibleInScrollables = <FocusNode>[];
    final List<FocusNode> fallbackCandidates = <FocusNode>[];
    for (final FocusNode node in currentNode.traversalDescendants) {
      if (cache.isEffectivelyFocusable(node)) {
        if (cache.isVisibleInEnclosingScrollables(node)) {
          visibleInScrollables.add(node);
        } else {
          fallbackCandidates.add(node);
        }
      }
    }
    final List<FocusNode> pool = visibleInScrollables.isNotEmpty
        ? visibleInScrollables
        : fallbackCandidates;
    return _findFirstReadingOrderNode(pool, cache);
  });

  static bool _canUserScroll(ScrollableState scrollable) {
    final ScrollPhysics? physics = scrollable.widget.physics;
    return physics is! NeverScrollableScrollPhysics &&
        physics is! PageScrollPhysics &&
        scrollable.position is! PageMetrics;
  }

  static bool _isRectVisibleInScrollable(Rect r, Rect scrollableRect) {
    return r.bottom > scrollableRect.top + 1.0 &&
        r.top < scrollableRect.bottom - 1.0 &&
        r.center.dy >= scrollableRect.top - 1.0 &&
        r.center.dy <= scrollableRect.bottom + 1.0;
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

  /// Returns true when [secondary] is a small action widget (e.g. a trailing
  /// IconButton/Switch or an overlaid VideoPopupMenu) whose center lies inside
  /// a much larger primary container [container] (e.g. a ListTile or VideoCard).
  static bool _isEmbeddedSecondaryOf(
    FocusNode secondary,
    FocusNode container,
    _TvTraversalCache cache,
  ) {
    if (secondary == container) return false;
    final Rect cr = cache.rectOf(container);
    final Rect sr = cache.rectOf(secondary);
    if (!cr.contains(sr.center)) return false;
    final bool isMicroButton = sr.width <= 36.0 && sr.height <= 36.0;
    return isMicroButton ||
        cr.width > sr.width * 1.8 ||
        cr.height > sr.height * 1.8;
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

    // Fast check: identify potential secondary micro-actions (w, h <= 36 or small surface area)
    final List<FocusNode> microNodes = <FocusNode>[];
    for (final FocusNode node in candidates) {
      if (node == focusedChild) continue;
      final Rect r = cache.rectOf(node);
      if ((r.width <= 36.0 && r.height <= 36.0) ||
          (r.width <= 64.0 && r.height <= 64.0 && r.width * r.height <= 2500)) {
        microNodes.add(node);
      }
    }

    if (microNodes.isEmpty) {
      return candidates;
    }

    final Set<FocusNode> excluded = <FocusNode>{};
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
    final double afterScroll = _sumUserScrollPixels(node.context);
    if ((afterScroll - beforeScroll).abs() > 0.5) {
      _frameState.didScrollInLastFocus = true;
    }
    // Consume the keyboard token immediately so D-pad directional focus
    // landing on an EditableText does not automatically open the soft keyboard.
    node.consumeKeyboardToken();
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

      final List<FocusNode> rawDescendants = <FocusNode>[];
      for (final FocusNode node in nearestScope.traversalDescendants) {
        if (node.context == null) continue;
        final RenderObject? ro = node.context!.findRenderObject();
        if (ro is RenderBox && ro.attached && ro.hasSize) {
          final Rect nr = cache.boxRect(ro);
          if (_isInOppositeHalfPlane(nr, target, direction)) {
            continue;
          }
        }
        if (cache.isEffectivelyFocusable(node)) {
          rawDescendants.add(node);
        }
      }
      final Set<FocusNode> rawSet = rawDescendants.toSet();
      final Set<FocusNode> nonLeafNodes = <FocusNode>{};
      for (final FocusNode node in rawDescendants) {
        final Element? nodeListTile = cache.enclosingListTileOf(node);
        final Rect nr = cache.rectOf(node);
        for (final FocusNode ancestor in node.ancestors) {
          if (!rawSet.contains(ancestor)) continue;
          final Rect ar = cache.rectOf(ancestor);
          final bool sameSizeWrapper =
              (ar.width - nr.width).abs() < 8.0 &&
              (ar.height - nr.height).abs() < 8.0;
          final bool isEnclosingListTileRow =
              nodeListTile != null &&
              !sameSizeWrapper &&
              cache.enclosingListTileOf(ancestor) == nodeListTile;
          final bool isPrimaryInkContainer =
              !sameSizeWrapper &&
              cache.enclosingInkResponseOf(ancestor) != null &&
              _isEmbeddedSecondaryOf(node, ancestor, cache);
          if (!isEnclosingListTileRow && !isPrimaryInkContainer) {
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

      final FocusNode? chosen = switch (direction) {
        TraversalDirection.down || TraversalDirection.up =>
          _findVerticalCandidate(
            focusedChild: focusedChild,
            target: target,
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
            target: target,
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
    required ScrollableState? focusedScrollable,
    required Rect? focusedScrollableRect,
    required ScrollableState? focusedHorizScrollable,
    required List<FocusNode> allNodes,
    required TraversalDirection direction,
    required _TvTraversalCache cache,
  }) {
    final bool isDown = direction == TraversalDirection.down;
    final List<FocusNode> primaryNodes = _filterOutEmbeddedSecondaryActions(
      allNodes,
      focusedChild,
      cache,
    ).where((FocusNode node) {
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
        return isDown ? r.center.dy >= target.bottom : r.center.dy <= target.top;
      }).toList();
      if (sameScrollable.isNotEmpty) {
        return _pickFromClosestRow(
          referenceRect: target,
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
                  math.min(target.bottom, focusedScrollableRect.bottom) - 2.0,
                  focusedScrollableRect.bottom - 4.0,
                )
              : math.min(
                  math.max(target.top, focusedScrollableRect.top) + 2.0,
                  focusedScrollableRect.top + 4.0,
                ))
        : (isDown ? target.bottom : target.top);

    final Rect referenceHorizontalRect = focusedScrollableRect ?? target;
    final List<FocusNode> externalCandidates = <FocusNode>[];
    final List<FocusNode> fallbackScrollableCandidates = <FocusNode>[];

    // Pre-calculate column-disjoint vertical band bounds to eliminate O(N^2) candidate scans.
    final List<(double, double)> adjacentColumnSpans = <(double, double)>[];
    for (final FocusNode other in primaryNodes) {
      final Rect otherBounds =
          cache.scrollableRect(cache.verticalScrollableOf(other)) ??
          cache.rectOf(other);
      final bool overlapsTargetVertically =
          otherBounds.bottom > target.top + 1.0 &&
          otherBounds.top < target.bottom - 1.0;
      final bool disjointFromTargetHorizontally =
          otherBounds.left >= target.right - 2.0 ||
          otherBounds.right <= target.left + 2.0;
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
            ? target.center.dy <= nodeScrollableRect.top + 4.0 ||
                  nodeScrollableRect.top >= exitBoundary - 4.0
            : target.center.dy >= nodeScrollableRect.bottom - 4.0 ||
                  nodeScrollableRect.bottom <= exitBoundary + 4.0;
        if (!scrollableInDirection) continue;
        if (_isRectVisibleInScrollable(nr, nodeScrollableRect)) {
          final bool nodeInDirection = isDown
              ? nr.center.dy >= target.bottom
              : nr.center.dy <= target.top;
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
              nr.right > target.left - 4.0 && nr.left < target.right + 4.0;
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
            ? nr.center.dy >= exitBoundary && nr.center.dy > target.center.dy
            : nr.center.dy <= exitBoundary && nr.center.dy < target.center.dy;
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
      referenceRect: target,
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

    // 0. Support stepping between a ListTile container and its trailing
    // focusable descendant (e.g. refresh IconButton or Switch).
    final Element? focusedListTile = cache.enclosingListTileOf(focusedChild);
    if (focusedListTile != null) {
      if (isRight) {
        final List<FocusNode> trailingChildren = allNodes.where((
          FocusNode node,
        ) {
          return node.ancestors.contains(focusedChild) &&
              cache.enclosingListTileOf(node) == focusedListTile &&
              cache.rectOf(node).center.dx > target.center.dx + 8.0;
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
              cache.enclosingListTileOf(node) == focusedListTile &&
              cache.rectOf(node).center.dx < target.center.dx - 8.0;
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

    final List<FocusNode> primaryNodes = _filterOutEmbeddedSecondaryActions(
      allNodes,
      focusedChild,
      cache,
    );

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

    if (directionalNodes.isEmpty) return null;

    // 2. Prefer candidates on the same visual row (vertically overlapping target).
    final List<FocusNode> inBand = directionalNodes.where((FocusNode node) {
      final Rect r = cache.rectOf(node);
      return r.bottom > target.top + 1.0 && r.top < target.bottom - 1.0;
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

    if (sideBySide.isEmpty) return null;

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

class _TvVerticalFocusIntent extends Intent {
  const _TvVerticalFocusIntent(this.direction);

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

class _TvVerticalFocusAction extends Action<_TvVerticalFocusIntent> {
  _TvVerticalFocusAction(this.policy);

  final FocusTraversalPolicy policy;

  @override
  bool invoke(_TvVerticalFocusIntent intent) {
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

  final VoidCallback? onBack;
  final Widget child;

  @override
  State<TvNavigation> createState() => _TvNavigationState();
}

class _MiniScaffoldSheetRecord {
  _MiniScaffoldSheetRecord({
    required this.sheetWidget,
    this.savedFocusNode,
  });

  Widget sheetWidget;
  FocusNode? savedFocusNode;
  bool promoted = false;
}

class _TvNavigationState extends State<TvNavigation>
    with WidgetsBindingObserver {
  static const int _kDirectionalRepeatMinIntervalMs = 45;
  static final Expando<_MiniScaffoldSheetRecord> _bottomSheetRecords =
      Expando<_MiniScaffoldSheetRecord>('tvBottomSheetRecords');

  final GlobalKey _key = GlobalKey();
  final TvFocusTraversalPolicy _policy = TvFocusTraversalPolicy();
  late final Map<Type, Action<Intent>> _actions = <Type, Action<Intent>>{
    DirectionalFocusIntent: _TvDirectionalFocusAction(_policy),
    _TvVerticalFocusIntent: _TvVerticalFocusAction(_policy),
  };
  final ValueNotifier<Rect?> _rectNotifier = ValueNotifier<Rect?>(null);
  final List<Element> _trackedBottomSheetLayouts = <Element>[];
  late final Stopwatch _repeatClock =
      WidgetsBinding.instance.samplingClock.stopwatch()..start();
  int? _lastDirectionalStepMs;
  bool _rectSyncScheduled = false;
  bool _focusSyncScheduled = false;
  FocusNode? _lastFocusedNode;
  FocusNode? _pendingInvalidNode;
  Rect? _pendingRecoveryRect;
  FocusNode? _lastSelectTriggerNode;
  int _pendingSelectSheetCheckFrames = 0;
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
    WidgetsBinding.instance.addPersistentFrameCallback(
      _syncFocusRectAfterLayout,
    );
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    HardwareKeyboard.instance.removeHandler(_observeHardwareKeyEvent);
    FocusManager.instance.removeListener(_onFocus);
    _rectNotifier.dispose();
    super.dispose();
  }

  bool _observeHardwareKeyEvent(KeyEvent event) {
    if (TvPlatform.isTv && event is KeyDownEvent) {
      final LogicalKeyboardKey key = event.logicalKey;
      if (key == LogicalKeyboardKey.select ||
          key == LogicalKeyboardKey.enter ||
          key == LogicalKeyboardKey.numpadEnter ||
          key == LogicalKeyboardKey.gameButtonA) {
        final FocusNode? primary = FocusManager.instance.primaryFocus;
        if (primary != null && primary is! FocusScopeNode) {
          _lastSelectTriggerNode = primary;
          _pendingSelectSheetCheckFrames = 2;
        }
      }
    }
    return false;
  }

  void _captureBottomSheetTransitions(
    FocusNode? primary,
    _BottomSheetNodeStatus status,
  ) {
    final Element? occluding = status.occludingLayout;
    if (occluding != null && occluding.widget is BottomSheetLayout) {
      final Widget? sheet = (occluding.widget as BottomSheetLayout).bottomSheet;
      if (sheet != null && !_TvTraversalCache._isBottomSheetClosing(sheet)) {
        final _MiniScaffoldSheetRecord? existing =
            _bottomSheetRecords[occluding];
        if (existing == null) {
          _bottomSheetRecords[occluding] = _MiniScaffoldSheetRecord(
            sheetWidget: sheet,
            savedFocusNode: primary is FocusScopeNode ? null : primary,
          );
          if (!_trackedBottomSheetLayouts.contains(occluding)) {
            _trackedBottomSheetLayouts.add(occluding);
          }
        } else if (!identical(existing.sheetWidget, sheet)) {
          if (primary != null && primary is! FocusScopeNode) {
            existing.savedFocusNode ??= primary;
          }
          existing
            ..sheetWidget = sheet
            ..promoted = false;
          _trackedBottomSheetLayouts
            ..remove(occluding)
            ..add(occluding);
        } else {
          if (primary != null && primary is! FocusScopeNode) {
            existing.savedFocusNode ??= primary;
          }
          existing.promoted = false;
          if (!_trackedBottomSheetLayouts.contains(occluding)) {
            _trackedBottomSheetLayouts.add(occluding);
          }
        }
      }
    }

    if (_pendingSelectSheetCheckFrames > 0) {
      _pendingSelectSheetCheckFrames--;
      final FocusScopeNode? scope = primary is FocusScopeNode
          ? primary
          : primary?.nearestScope;
      final BuildContext? scopeCtx = scope?.context;
      if (scope != null &&
          !_isScopeInactive(scope) &&
          scopeCtx is Element &&
          scopeCtx.mounted) {
        Element? newlyOpened;
        void scan(Element el) {
          final Widget w = el.widget;
          if (w is BottomSheetLayout) {
            final Widget? sheet = w.bottomSheet;
            if (sheet != null &&
                !_TvTraversalCache._isBottomSheetClosing(sheet)) {
              final _MiniScaffoldSheetRecord? rec = _bottomSheetRecords[el];
              if (rec == null || !identical(rec.sheetWidget, sheet)) {
                newlyOpened = el;
              }
            }
          }
          el.visitChildren(scan);
        }

        scopeCtx.visitChildren(scan);
        if (newlyOpened != null) {
          final Widget sheet =
              (newlyOpened!.widget as BottomSheetLayout).bottomSheet!;
          final _MiniScaffoldSheetRecord? rec =
              _bottomSheetRecords[newlyOpened!];
          final FocusNode? trigger =
              (_lastSelectTriggerNode?.context?.mounted ?? false)
              ? _lastSelectTriggerNode
              : (primary is FocusScopeNode ? null : primary);
          if (rec == null) {
            _bottomSheetRecords[newlyOpened!] = _MiniScaffoldSheetRecord(
              sheetWidget: sheet,
              savedFocusNode: trigger,
            );
          } else {
            rec
              ..sheetWidget = sheet
              ..promoted = false;
            if (trigger != null &&
                status.enclosingActiveSheetLayout != newlyOpened) {
              rec.savedFocusNode ??= trigger;
            }
          }
          _trackedBottomSheetLayouts
            ..remove(newlyOpened!)
            ..add(newlyOpened!);
          _pendingSelectSheetCheckFrames = 0;
        }
      }
    }
  }

  bool _hasPendingBottomSheetWork(_BottomSheetNodeStatus status) {
    if (status.isInvalidated) return true;
    for (int i = _trackedBottomSheetLayouts.length - 1; i >= 0; i--) {
      final Element el = _trackedBottomSheetLayouts[i];
      if (!el.mounted || el.widget is! BottomSheetLayout) return true;
      final Widget? sheet = (el.widget as BottomSheetLayout).bottomSheet;
      if (sheet == null || _TvTraversalCache._isBottomSheetClosing(sheet)) {
        return true;
      }
      final _MiniScaffoldSheetRecord? rec = _bottomSheetRecords[el];
      if (rec == null || !identical(rec.sheetWidget, sheet) || !rec.promoted) {
        return true;
      }
    }
    return false;
  }

  bool _reconcileBottomSheets() {
    if (!mounted || !TvPlatform.isTv) return false;
    final FocusNode? primary = FocusManager.instance.primaryFocus;
    final _BottomSheetNodeStatus status =
        _TvTraversalCache._inspectBottomSheetNode(primary);
    _captureBottomSheetTransitions(primary, status);

    for (int i = _trackedBottomSheetLayouts.length - 1; i >= 0; i--) {
      if (i >= _trackedBottomSheetLayouts.length) continue;
      final Element layoutEl = _trackedBottomSheetLayouts[i];
      if (!layoutEl.mounted || layoutEl.widget is! BottomSheetLayout) {
        _trackedBottomSheetLayouts.removeAt(i);
        continue;
      }
      final BottomSheetLayout layoutWidget =
          layoutEl.widget as BottomSheetLayout;
      final Widget? sheet = layoutWidget.bottomSheet;
      final _MiniScaffoldSheetRecord? record = _bottomSheetRecords[layoutEl];

      if (sheet == null || _TvTraversalCache._isBottomSheetClosing(sheet)) {
        final Element? closingSheetSlot =
            TvFocusTraversalPolicy._slotChildOfBottomSheetLayout(
              layoutEl,
              BottomSheetType.bottomSheet,
            );
        _trackedBottomSheetLayouts.removeAt(i);
        _bottomSheetRecords[layoutEl] = null;
        if (closingSheetSlot != null) {
          _trackedBottomSheetLayouts.removeWhere((Element other) {
            if (TvFocusTraversalPolicy._isElementInSubtree(
              other,
              closingSheetSlot,
            )) {
              _bottomSheetRecords[other] = null;
              return true;
            }
            return false;
          });
        }
        final FocusNode? savedNode = record?.savedFocusNode;
        if (savedNode != null &&
            savedNode.canRequestFocus &&
            (savedNode.context?.mounted ?? false) &&
            TvFocusTraversalPolicy.isEffectivelyFocusable(savedNode)) {
          _pendingInvalidNode = null;
          _pendingRecoveryRect = null;
          savedNode
            ..requestFocus()
            ..consumeKeyboardToken();
          _updateRect(_computeFocusedRect(savedNode));
          return true;
        }
        final FocusScopeNode sheetScope = FocusScope.of(layoutEl);
        if (!_isScopeInactive(sheetScope) && sheetScope.canRequestFocus) {
          final Element? bodySlot =
              TvFocusTraversalPolicy._slotChildOfBottomSheetLayout(
                layoutEl,
                BottomSheetType.body,
              );
          final FocusNode? fallback =
              (bodySlot != null
                  ? _policy.findFirstFocusInSubtree(bodySlot, sheetScope)
                  : null) ??
              _policy.findRecoveryFocus(savedNode, sheetScope);
          if (fallback != null &&
              fallback.canRequestFocus &&
              (fallback.context?.mounted ?? false)) {
            _pendingInvalidNode = null;
            _pendingRecoveryRect = null;
            fallback
              ..requestFocus()
              ..consumeKeyboardToken();
            _updateRect(_computeFocusedRect(fallback));
            return true;
          }
        }
        _updateRect(null);
        continue;
      }

      final _MiniScaffoldSheetRecord activeRecord =
          record ??
          (_bottomSheetRecords[layoutEl] = _MiniScaffoldSheetRecord(
            sheetWidget: sheet,
          ));
      if (!identical(activeRecord.sheetWidget, sheet)) {
        activeRecord
          ..sheetWidget = sheet
          ..promoted = false;
      }

      if (!activeRecord.promoted) {
        final FocusScopeNode sheetScope = FocusScope.of(layoutEl);
        if (_isScopeInactive(sheetScope) || !sheetScope.canRequestFocus) {
          continue;
        }
        final Element? sheetSlot =
            TvFocusTraversalPolicy._slotChildOfBottomSheetLayout(
              layoutEl,
              BottomSheetType.bottomSheet,
            );
        final FocusNode? firstInSheet = sheetSlot != null
            ? _policy.findFirstFocusInSubtree(sheetSlot, sheetScope)
            : null;
        if (firstInSheet != null &&
            firstInSheet.canRequestFocus &&
            (firstInSheet.context?.mounted ?? false)) {
          activeRecord.promoted = true;
          _pendingInvalidNode = null;
          _pendingRecoveryRect = null;
          firstInSheet
            ..requestFocus()
            ..consumeKeyboardToken();
          _updateRect(_computeFocusedRect(firstInSheet));
          return true;
        }
        if (_TvTraversalCache._isBottomSheetAnimatingOpen(sheet)) {
          _updateRect(null);
          WidgetsBinding.instance.ensureVisualUpdate();
          return true;
        }
        activeRecord.promoted = true;
      }
    }
    return false;
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
      _focusSyncScheduled = false;
      _rectSyncScheduled = false;
      _onFocus();
      WidgetsBinding.instance.ensureVisualUpdate();
    }
  }

  bool _handleScrollNotification(ScrollNotification notification) {
    if (notification is ScrollUpdateNotification ||
        notification is ScrollEndNotification) {
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
    return false;
  }

  Rect? _computeFocusedRect(FocusNode? node) {
    if (node == null ||
        node is FocusScopeNode ||
        !node.canRequestFocus ||
        node.skipTraversal ||
        _TvTraversalCache._inspectBottomSheetNode(node).isInvalidated) {
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

  static bool _isScopeInactive(FocusScopeNode scope) {
    FocusScopeNode? current = scope;
    while (current != null) {
      if (current.skipTraversal) return true;
      current = current.enclosingScope;
    }
    return false;
  }

  static FocusScopeNode? _findActiveSiblingScope(FocusScopeNode scope) {
    FocusScopeNode inactiveRoot = scope;
    FocusScopeNode? current = scope.enclosingScope;
    while (current != null) {
      if (current.skipTraversal) {
        inactiveRoot = current;
      }
      current = current.enclosingScope;
    }

    FocusScopeNode? searchIn(FocusNode root) {
      FocusScopeNode? result;
      void visit(FocusNode parent) {
        for (final FocusNode child in parent.children) {
          if (child is FocusScopeNode) {
            if (child != inactiveRoot &&
                !_isScopeInactive(child) &&
                child.canRequestFocus) {
              result = child;
            }
          } else {
            visit(child);
          }
        }
      }

      visit(root);
      return result;
    }

    final FocusNode? parent = inactiveRoot.parent;
    if (parent != null) {
      final FocusScopeNode? found = searchIn(parent);
      if (found != null) return found;
    }
    final FocusScopeNode? enclosing = inactiveRoot.enclosingScope;
    if (enclosing != null && !identical(enclosing, parent)) {
      return searchIn(enclosing);
    }
    return null;
  }

  void _syncFocusRectAfterLayout(Duration _) {
    if (!mounted || !TvPlatform.isTv || _rectSyncScheduled) return;
    final FocusNode? node = FocusManager.instance.primaryFocus;
    final _BottomSheetNodeStatus sheetStatus =
        _TvTraversalCache._inspectBottomSheetNode(node);
    _captureBottomSheetTransitions(node, sheetStatus);
    if (_hasPendingBottomSheetWork(sheetStatus)) {
      _lastFocusedNode = null;
      _lastTargetBox = null;
      if (!_focusSyncScheduled) {
        _focusSyncScheduled = true;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _focusSyncScheduled = false;
          if (!mounted) return;
          if (_reconcileBottomSheets()) return;
          final FocusNode? current = FocusManager.instance.primaryFocus;
          final FocusScopeNode? scope = current is FocusScopeNode
              ? current
              : current?.nearestScope;
          if (current != null &&
              scope != null &&
              !_isScopeInactive(scope) &&
              (current is FocusScopeNode ||
                  !TvFocusTraversalPolicy.isEffectivelyFocusable(current))) {
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
        });
        WidgetsBinding.instance.ensureVisualUpdate();
      }
      return;
    }
    if (node == null || node is FocusScopeNode) {
      if (node is FocusScopeNode && !_focusSyncScheduled) {
        FocusScopeNode targetScope = node;
        if (_isScopeInactive(node)) {
          targetScope = _findActiveSiblingScope(node) ?? node;
        }
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
          _focusSyncScheduled = true;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _focusSyncScheduled = false;
            if (!mounted) return;
            if (_reconcileBottomSheets()) return;
            final FocusNode resolvedFirst =
                (pendingInvalid != null
                    ? _policy.findRecoveryFocus(
                        pendingInvalid,
                        targetScope,
                        previousRect: pendingRect,
                      )
                    : _policy.findFirstFocus(targetScope)) ??
                first;
            if (FocusManager.instance.primaryFocus == node &&
                !_isScopeInactive(targetScope) &&
                targetScope.canRequestFocus &&
                resolvedFirst.canRequestFocus &&
                (resolvedFirst.context?.mounted ?? false)) {
              _pendingInvalidNode = null;
              _pendingRecoveryRect = null;
              if (targetScope != node) {
                targetScope.enclosingScope?.setFirstFocus(targetScope);
              }
              resolvedFirst
                ..requestFocus()
                ..consumeKeyboardToken();
              _updateRect(_computeFocusedRect(resolvedFirst));
            }
          });
          WidgetsBinding.instance.ensureVisualUpdate();
          return;
        }
      }
      _lastFocusedNode = null;
      _lastTargetBox = null;
      _lastTargetSize = null;
      _lastRootSize = null;
      _lastParentDataOffset = null;
      _lastScrollOffset = null;
      if (_rectNotifier.value != null) {
        _rectSyncScheduled = true;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _rectSyncScheduled = false;
          if (!mounted) return;
          _updateRect(null);
        });
        WidgetsBinding.instance.ensureVisualUpdate();
      }
      return;
    }

    final FocusScopeNode? currentScope = node.nearestScope;
    if (currentScope != null &&
        _isScopeInactive(currentScope) &&
        !_focusSyncScheduled) {
      final FocusScopeNode? targetScope = _findActiveSiblingScope(currentScope);
      if (targetScope != null) {
        final FocusNode? first = _policy.findFirstFocus(targetScope);
        if (first != null) {
          TvNavigationObserver.rememberFocusedNode(node);
          _focusSyncScheduled = true;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _focusSyncScheduled = false;
            if (!mounted) return;
            final FocusNode resolvedFirst =
                _policy.findFirstFocus(targetScope) ?? first;
            if (FocusManager.instance.primaryFocus == node &&
                !_isScopeInactive(targetScope) &&
                targetScope.canRequestFocus &&
                resolvedFirst.canRequestFocus &&
                (resolvedFirst.context?.mounted ?? false)) {
              targetScope.enclosingScope?.setFirstFocus(targetScope);
              resolvedFirst
                ..requestFocus()
                ..consumeKeyboardToken();
              _updateRect(_computeFocusedRect(resolvedFirst));
            }
          });
          WidgetsBinding.instance.ensureVisualUpdate();
          return;
        }
      }
    }

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
        !_isScopeInactive(currentScope) &&
        !_focusSyncScheduled &&
        (parentOffset == null ||
            !TvFocusTraversalPolicy.isEffectivelyFocusable(node))) {
      final Rect? prevRect = _rectNotifier.value;
      final FocusNode? first = _policy.findRecoveryFocus(
        node,
        currentScope,
        previousRect: prevRect,
      );
      if (first != null && first != node) {
        _focusSyncScheduled = true;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _focusSyncScheduled = false;
          if (!mounted) return;
          if (_reconcileBottomSheets()) return;
          final FocusNode resolvedFirst =
              _policy.findRecoveryFocus(
                node,
                currentScope,
                previousRect: prevRect,
              ) ??
              first;
          if (FocusManager.instance.primaryFocus == node &&
              !TvFocusTraversalPolicy.isEffectivelyFocusable(node) &&
              resolvedFirst.canRequestFocus &&
              (resolvedFirst.context?.mounted ?? false)) {
            resolvedFirst
              ..requestFocus()
              ..consumeKeyboardToken();
            _updateRect(_computeFocusedRect(resolvedFirst));
          }
        });
        WidgetsBinding.instance.ensureVisualUpdate();
        return;
      }
    }

    if (targetBox == null || rootBox == null) {
      if (_rectNotifier.value != null && !_focusSyncScheduled) {
        _rectSyncScheduled = true;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _rectSyncScheduled = false;
          if (!mounted) return;
          _updateRect(
            _computeFocusedRect(FocusManager.instance.primaryFocus),
          );
        });
        WidgetsBinding.instance.ensureVisualUpdate();
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

    if (_sameRect(rect, _rectNotifier.value) || _focusSyncScheduled) return;
    _rectSyncScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _rectSyncScheduled = false;
      if (!mounted) return;
      final Rect? latest = _computeFocusedRect(
        FocusManager.instance.primaryFocus,
      );
      _updateRect(latest);
    });
    WidgetsBinding.instance.ensureVisualUpdate();
  }

  void _onFocus() {
    _lastFocusedNode = null;
    _lastTargetBox = null;
    if (!TvPlatform.isTv) return;
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
          !_isScopeInactive(immediateScope)) {
        _updateRect(_computeFocusedRect(immediateNode));
      }
    }
    if (_focusSyncScheduled) {
      WidgetsBinding.instance.ensureVisualUpdate();
      return;
    }
    _focusSyncScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _focusSyncScheduled = false;
      if (!mounted) return;
      if (_reconcileBottomSheets()) return;
      final FocusNode? node = FocusManager.instance.primaryFocus;
      if (node is FocusScopeNode) {
        FocusScopeNode targetScope = node;
        if (_isScopeInactive(node)) {
          targetScope = _findActiveSiblingScope(node) ?? node;
        }
        final FocusNode? pendingInvalid = _pendingInvalidNode;
        final Rect? pendingRect = _pendingRecoveryRect;
        _pendingInvalidNode = null;
        _pendingRecoveryRect = null;
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
        return;
      }
      final FocusScopeNode? currentScope = node?.nearestScope;
      if (node != null &&
          currentScope != null &&
          _isScopeInactive(currentScope)) {
        final FocusScopeNode? targetScope = _findActiveSiblingScope(
          currentScope,
        );
        if (targetScope != null) {
          final FocusNode? first = _policy.findFirstFocus(targetScope);
          if (first != null &&
              targetScope.canRequestFocus &&
              first.canRequestFocus &&
              (first.context?.mounted ?? false)) {
            TvNavigationObserver.rememberFocusedNode(node);
            targetScope.enclosingScope?.setFirstFocus(targetScope);
            first
              ..requestFocus()
              ..consumeKeyboardToken();
            _updateRect(_computeFocusedRect(first));
            return;
          }
        }
      }
      if (node != null &&
          currentScope != null &&
          !_isScopeInactive(currentScope)) {
        final bool effectivelyFocusable =
            TvFocusTraversalPolicy.isEffectivelyFocusable(node);
        if (!effectivelyFocusable) {
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
      final BuildContext? context = node?.context;
      if (context != null &&
          context.mounted &&
          node != null &&
          node is! FocusScopeNode) {
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
      if (!mounted || node != FocusManager.instance.primaryFocus) return;
      _updateRect(_computeFocusedRect(node));
    });
    WidgetsBinding.instance.ensureVisualUpdate();
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
        if (_pendingInvalidNode != null || _reconcileBottomSheets()) {
          WidgetsBinding.instance.ensureVisualUpdate();
          return KeyEventResult.handled;
        }
        final FocusScopeNode? scope = primary is FocusScopeNode
            ? primary
            : primary?.nearestScope;
        if (scope != null) {
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
          SingleActivator(LogicalKeyboardKey.arrowUp): _TvVerticalFocusIntent(
            TraversalDirection.up,
          ),
          SingleActivator(LogicalKeyboardKey.arrowDown):
              _TvVerticalFocusIntent(
                TraversalDirection.down,
              ),
          SingleActivator(LogicalKeyboardKey.arrowLeft):
              _TvVerticalFocusIntent(
                TraversalDirection.left,
              ),
          SingleActivator(LogicalKeyboardKey.arrowRight):
              _TvVerticalFocusIntent(
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
                    child: child,
                  ),
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
/// 2. Automatically switches `/loginPage` to tab index `2` (`扫码登录`) on TV
///    via `Get.find<LoginPageController>()` without touching `lib/pages/login/`.
class TvNavigationObserver extends NavigatorObserver {
  static final Expando<FocusNode> _savedFocusByRoute = Expando<FocusNode>(
    'tvSavedFocusByRoute',
  );

  /// Records [node] as the last active focus node for its enclosing [ModalRoute].
  static void rememberFocusedNode(FocusNode node) {
    if (node is FocusScopeNode) return;
    final BuildContext? context = node.context;
    if (context == null || !context.mounted) return;
    final ModalRoute<dynamic>? route = ModalRoute.of(context);
    if (route != null) {
      _savedFocusByRoute[route] = node;
    }
  }

  static void _switchLoginPageToQrTab({int remainingRetries = 2}) {
    if (!TvPlatform.isTv) return;
    if (Get.isRegistered<LoginPageController>()) {
      final LoginPageController ctr = Get.find<LoginPageController>();
      if (ctr.tabController.index != 2) {
        ctr.tabController.animateTo(2);
      }
      return;
    }
    if (remainingRetries > 0) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _switchLoginPageToQrTab(remainingRetries: remainingRetries - 1);
      });
    }
  }

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

    if (route.settings.name == '/loginPage') {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _switchLoginPageToQrTab();
      });
      WidgetsBinding.instance.ensureVisualUpdate();
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
