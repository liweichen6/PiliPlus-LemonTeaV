import 'dart:math' as math;

import 'package:PiliPlus/common/widgets/flutter/list_tile.dart'
    as custom_list_tile;
import 'package:PiliPlus/pages/login/controller.dart';
import 'package:PiliPlus/tv/tv_platform.dart';
import 'package:flutter/rendering.dart'
    show
        RenderClipPath,
        RenderClipRRect,
        RenderClipRect,
        RenderFractionalTranslation;
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

class _TvTraversalCache {
  final Map<FocusNode, _TvNodeMeta> _nodeMeta = <FocusNode, _TvNodeMeta>{};
  final Map<RenderBox, Rect> _boxRects = <RenderBox, Rect>{};
  final Map<ScrollableState, Rect?> _scrollableRects =
      <ScrollableState, Rect?>{};

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
    final Rect globalRect =
        (renderObject is RenderBox &&
            renderObject.attached &&
            renderObject.hasSize)
        ? boxRect(renderObject)
        : node.rect;

    bool focusable =
        node.canRequestFocus &&
        !node.skipTraversal &&
        renderObject is RenderBox &&
        renderObject.attached &&
        renderObject.hasSize &&
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

    context.visitAncestorElements((Element element) {
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
  bool traversalLockedThisFrame = false;
  FocusNode? lastPolicyScrolledNode;
  _TvTraversalCache? activeCache;
}

class TvFocusTraversalPolicy extends FocusTraversalPolicy {
  TvFocusTraversalPolicy({super.requestFocusCallback});

  final ReadingOrderTraversalPolicy _readingOrderPolicy =
      ReadingOrderTraversalPolicy();
  final _TvPolicyFrameState _frameState = _TvPolicyFrameState();

  /// Whether a directional traversal step has already occurred during the
  /// current frame.
  bool get isTraversalLockedThisFrame => _frameState.traversalLockedThisFrame;

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
    final List<FocusNode> candidates = currentNode.traversalDescendants
        .where(cache.isEffectivelyFocusable)
        .toList();
    if (candidates.isEmpty) return null;
    final List<FocusNode> visibleInScrollables = candidates
        .where(cache.isVisibleInEnclosingScrollables)
        .toList();
    final List<FocusNode> pool = visibleInScrollables.isNotEmpty
        ? visibleInScrollables
        : candidates;
    return _sortDescendantsWithCache(pool, currentNode, cache).firstOrNull;
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
    final List<FocusNode> candidates = currentNode.traversalDescendants
        .where(cache.isEffectivelyFocusable)
        .toList();
    if (candidates.isEmpty) return null;
    final List<FocusNode> visibleInScrollables = candidates
        .where(cache.isVisibleInEnclosingScrollables)
        .toList();
    final List<FocusNode> pool = visibleInScrollables.isNotEmpty
        ? visibleInScrollables
        : candidates;
    return _sortDescendantsWithCache(pool, currentNode, cache).firstOrNull;
  });

  static bool _canUserScroll(ScrollableState scrollable) {
    return scrollable.widget.physics is! NeverScrollableScrollPhysics;
  }

  static bool _isRectVisibleInScrollable(Rect r, Rect scrollableRect) {
    return r.bottom > scrollableRect.top + 1.0 &&
        r.top < scrollableRect.bottom - 1.0 &&
        r.center.dy >= scrollableRect.top - 1.0 &&
        r.center.dy <= scrollableRect.bottom + 1.0;
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
    return candidates.where((FocusNode node) {
      for (final FocusNode other in candidates) {
        if (other == node || other == focusedChild) continue;
        if (_isEmbeddedSecondaryOf(node, other, cache)) {
          return false;
        }
      }
      return true;
    }).toList();
  }

  void _focusNode(FocusNode node, TraversalDirection direction) {
    _frameState.lastPolicyScrolledNode = node;
    if (!_frameState.traversalLockedThisFrame) {
      _frameState.traversalLockedThisFrame = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _frameState.traversalLockedThisFrame = false;
      });
    }
    requestFocusCallback(
      node,
      alignmentPolicy: switch (direction) {
        TraversalDirection.up || TraversalDirection.left =>
          ScrollPositionAlignmentPolicy.keepVisibleAtStart,
        TraversalDirection.down || TraversalDirection.right =>
          ScrollPositionAlignmentPolicy.keepVisibleAtEnd,
      },
    );
    // Consume the keyboard token immediately so D-pad directional focus
    // landing on an EditableText does not automatically open the soft keyboard.
    node.consumeKeyboardToken();
  }

  @override
  bool inDirection(FocusNode currentNode, TraversalDirection direction) {
    if (_frameState.traversalLockedThisFrame) return true;
    final FocusScopeNode? nearestScope = currentNode.nearestScope;
    if (nearestScope == null) return false;
    nearestScope.directionalTraversalEdgeBehavior = TraversalEdgeBehavior.stop;
    return _withCache((_TvTraversalCache cache) {
      final FocusNode? focusedChild = nearestScope.focusedChild;
      if (focusedChild == null) {
        final FocusNode? firstFocus =
            findFirstFocusInDirection(currentNode, direction) ??
            findFirstFocus(currentNode);
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

      final List<FocusNode> rawDescendants = nearestScope.traversalDescendants
          .where(
            (FocusNode node) =>
                node.context != null && cache.isEffectivelyFocusable(node),
          )
          .toList();
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
            final bool belongsToAdjacentColumn = primaryNodes.any((
              FocusNode other,
            ) {
              if (other == node) return false;
              final Rect otherBounds =
                  cache.scrollableRect(cache.verticalScrollableOf(other)) ??
                  cache.rectOf(other);
              final bool overlapsTargetVertically =
                  otherBounds.bottom > target.top + 1.0 &&
                  otherBounds.top < target.bottom - 1.0;
              final bool overlapsNodeHorizontally =
                  otherBounds.right > nr.left + 1.0 &&
                  otherBounds.left < nr.right - 1.0;
              final bool disjointFromTargetHorizontally =
                  otherBounds.left >= target.right - 2.0 ||
                  otherBounds.right <= target.left + 2.0;
              return overlapsTargetVertically &&
                  overlapsNodeHorizontally &&
                  disjointFromTargetHorizontally;
            });
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

class _TvNavigationState extends State<TvNavigation> {
  static const int _kDirectionalRepeatMinIntervalMs = 45;

  final GlobalKey _key = GlobalKey();
  final TvFocusTraversalPolicy _policy = TvFocusTraversalPolicy();
  late final Map<Type, Action<Intent>> _actions = <Type, Action<Intent>>{
    DirectionalFocusIntent: _TvDirectionalFocusAction(_policy),
    _TvVerticalFocusIntent: _TvVerticalFocusAction(_policy),
  };
  final ValueNotifier<Rect?> _rectNotifier = ValueNotifier<Rect?>(null);
  late final Stopwatch _repeatClock =
      WidgetsBinding.instance.samplingClock.stopwatch()..start();
  int? _lastDirectionalStepMs;
  bool _rectSyncScheduled = false;
  bool _focusSyncScheduled = false;

  @override
  void initState() {
    super.initState();
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
    FocusManager.instance.removeListener(_onFocus);
    _rectNotifier.dispose();
    super.dispose();
  }

  Rect? _computeFocusedRect(FocusNode? node) {
    if (node == null || node is FocusScopeNode) return null;
    final BuildContext? context = node.context;
    if (context == null || !context.mounted) return null;
    final RenderObject? target = context.findRenderObject();
    final RenderObject? root = _key.currentContext?.findRenderObject();
    if (target is RenderBox &&
        root is RenderBox &&
        target.attached &&
        target.hasSize &&
        root.hasSize) {
      final Rect candidate =
          target.localToGlobal(Offset.zero, ancestor: root) & target.size;
      if (candidate.width > 0 &&
          candidate.height > 0 &&
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

  void _syncFocusRectAfterLayout(Duration _) {
    if (!mounted || !TvPlatform.isTv || _rectSyncScheduled) return;
    final FocusNode? node = FocusManager.instance.primaryFocus;
    if (node is FocusScopeNode) return;
    final Rect? rect = _computeFocusedRect(node);
    if (_sameRect(rect, _rectNotifier.value)) return;
    _rectSyncScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _rectSyncScheduled = false;
      if (!mounted) return;
      final Rect? latest = _computeFocusedRect(
        FocusManager.instance.primaryFocus,
      );
      _updateRect(latest);
    });
  }

  void _onFocus() {
    if (!TvPlatform.isTv || _focusSyncScheduled) return;
    _focusSyncScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _focusSyncScheduled = false;
      if (!mounted) return;
      final FocusNode? node = FocusManager.instance.primaryFocus;
      if (node is FocusScopeNode) {
        final FocusNode? first = _policy.findFirstFocus(node);
        if (first != null) {
          first
            ..requestFocus()
            ..consumeKeyboardToken();
        } else {
          node.nextFocus();
        }
        _updateRect(null);
        return;
      }
      final BuildContext? context = node?.context;
      if (context != null &&
          context.mounted &&
          node != null &&
          node is! FocusScopeNode) {
        TvNavigationObserver.rememberFocusedNode(node);
        if (!_policy.consumePolicyScrolledNode(node)) {
          Scrollable.ensureVisible(
            context,
            alignmentPolicy: ScrollPositionAlignmentPolicy.explicit,
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
      if (event is KeyDownEvent || event is KeyRepeatEvent) {
        if (_policy.isTraversalLockedThisFrame) {
          return KeyEventResult.handled;
        }
        final int nowMs = _repeatClock.elapsedMilliseconds;
        if (event is KeyRepeatEvent &&
            _lastDirectionalStepMs != null &&
            nowMs - _lastDirectionalStepMs! <
                _kDirectionalRepeatMinIntervalMs) {
          return KeyEventResult.handled;
        }
        _lastDirectionalStepMs = nowMs;
      }
      return KeyEventResult.ignored;
    }

    if (event is! KeyDownEvent) return KeyEventResult.ignored;
    final bool isSelectKey =
        key == LogicalKeyboardKey.select ||
        key == LogicalKeyboardKey.enter ||
        key == LogicalKeyboardKey.numpadEnter ||
        key == LogicalKeyboardKey.gameButtonA;
    if (isSelectKey && TvPlatform.isFocusedOnEditableText()) {
      TvPlatform.requestSoftKeyboard();
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    if (!TvPlatform.isTv) return widget.child;
    return MediaQuery(
      data: MediaQuery.of(
        context,
      ).copyWith(navigationMode: NavigationMode.directional),
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
            child: Stack(
              key: _key,
              fit: StackFit.expand,
              children: <Widget>[
                FocusTraversalGroup(
                  policy: _policy,
                  child: widget.child,
                ),
                Positioned.fill(
                  child: IgnorePointer(
                    child: RepaintBoundary(
                      child: ValueListenableBuilder<Rect?>(
                        valueListenable: _rectNotifier,
                        builder: (BuildContext context, Rect? rect, _) {
                          return CustomPaint(
                            painter: _TvFocusRingPainter(rect),
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
    );
  }
}

class _TvFocusRingPainter extends CustomPainter {
  const _TvFocusRingPainter(this.rect);

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
          (current.context?.mounted ?? false)) {
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
    }
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    super.didPop(route, previousRoute);
    if (!TvPlatform.isTv || previousRoute == null) return;
    final FocusNode? savedNode = _savedFocusByRoute[previousRoute];
    if (savedNode == null) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (savedNode.canRequestFocus &&
          (savedNode.context?.mounted ?? false) &&
          TvFocusTraversalPolicy.isEffectivelyFocusable(savedNode)) {
        savedNode
          ..requestFocus()
          ..consumeKeyboardToken();
      }
    });
  }
}
