import 'dart:math' as math;

import 'package:PiliPlus/common/widgets/flutter/list_tile.dart'
    as custom_list_tile;
import 'package:PiliPlus/tv/tv_platform.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

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
class TvFocusTraversalPolicy extends FocusTraversalPolicy {
  TvFocusTraversalPolicy({super.requestFocusCallback});

  final ReadingOrderTraversalPolicy _readingOrderPolicy =
      ReadingOrderTraversalPolicy();

  /// Returns `true` when [node] is mounted, attached, has non-zero geometry
  /// across its ancestor `RenderBox` chain, intersects the visible viewport,
  /// and belongs to an enabled interactive widget.
  static bool isEffectivelyFocusable(FocusNode node) =>
      _isEffectivelyFocusable(node);

  static bool _isEffectivelyFocusable(FocusNode node) {
    if (!node.canRequestFocus || node.skipTraversal) return false;
    final BuildContext? context = node.context;
    if (context == null || !context.mounted) return false;
    final RenderObject? renderObject = context.findRenderObject();
    if (renderObject is! RenderBox ||
        !renderObject.attached ||
        !renderObject.hasSize) {
      return false;
    }
    final Size size = renderObject.size;
    if (size.width <= 1.0 || size.height <= 1.0) {
      return false;
    }

    final Rect globalRect = node.rect;
    if (globalRect.isEmpty ||
        globalRect.width <= 1.0 ||
        globalRect.height <= 1.0 ||
        globalRect.hasNaN ||
        globalRect.isInfinite) {
      return false;
    }

    final view = View.maybeOf(context);
    if (view != null && view.devicePixelRatio > 0) {
      final Size logicalSize = view.physicalSize / view.devicePixelRatio;
      if (logicalSize.width > 1.0 && logicalSize.height > 1.0) {
        final Rect viewport = Offset.zero & logicalSize;
        final Rect visible = globalRect.intersect(viewport);
        if (visible.width <= 1.0 || visible.height <= 1.0) {
          return false;
        }
      }
    }

    bool focusable = true;
    bool checkedOwner = false;
    context.visitAncestorElements((Element element) {
      final RenderObject? ancestorRo = element.renderObject;
      if (ancestorRo is RenderBox &&
          ancestorRo.attached &&
          ancestorRo.hasSize) {
        if (ancestorRo.size.width < 1.0 || ancestorRo.size.height < 1.0) {
          focusable = false;
          return false;
        }
      }

      final Widget widget = element.widget;
      if (widget is Offstage && widget.offstage) {
        focusable = false;
        return false;
      }
      if (widget is Visibility && !widget.visible) {
        focusable = false;
        return false;
      }
      if (widget is IgnorePointer && widget.ignoring) {
        focusable = false;
        return false;
      }
      if (widget is ExcludeFocus && widget.excluding) {
        focusable = false;
        return false;
      }
      if (widget is IconButton && widget.onPressed == null) {
        focusable = false;
        return false;
      }
      if (widget is ButtonStyleButton && !widget.enabled) {
        focusable = false;
        return false;
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
          if (!focusable) return false;
        } else if (widget is FocusableActionDetector) {
          checkedOwner = true;
          focusable = widget.enabled;
          if (!focusable) return false;
        } else if (widget is TextField) {
          checkedOwner = true;
          final bool enabled =
              widget.enabled ?? widget.decoration?.enabled ?? true;
          focusable = enabled && widget.canRequestFocus;
          if (!focusable) return false;
        } else if (widget is Focus) {
          checkedOwner = true;
        }
      }
      return true;
    });
    return focusable;
  }

  @override
  FocusNode? findFirstFocus(
    FocusNode currentNode, {
    bool ignoreCurrentFocus = false,
  }) {
    final FocusNode? candidate = super.findFirstFocus(
      currentNode,
      ignoreCurrentFocus: ignoreCurrentFocus,
    );
    if (candidate != null && _isEffectivelyFocusable(candidate)) {
      return candidate;
    }
    final List<FocusNode> candidates = currentNode.traversalDescendants
        .where(_isEffectivelyFocusable)
        .toList();
    if (candidates.isEmpty) return null;
    return sortDescendants(candidates, currentNode).firstOrNull;
  }

  @override
  Iterable<FocusNode> sortDescendants(
    Iterable<FocusNode> descendants,
    FocusNode currentNode,
  ) => _readingOrderPolicy.sortDescendants(
    descendants.where(
      (FocusNode node) =>
          node == currentNode ||
          !node.canRequestFocus ||
          _isEffectivelyFocusable(node),
    ),
    currentNode,
  );

  @override
  FocusNode? findFirstFocusInDirection(
    FocusNode currentNode,
    TraversalDirection direction,
  ) {
    final FocusNode? candidate = _readingOrderPolicy.findFirstFocusInDirection(
      currentNode,
      direction,
    );
    if (candidate != null && _isEffectivelyFocusable(candidate)) {
      return candidate;
    }
    final List<FocusNode> candidates = currentNode.traversalDescendants
        .where(_isEffectivelyFocusable)
        .toList();
    if (candidates.isEmpty) return null;
    return sortDescendants(candidates, currentNode).firstOrNull;
  }

  static bool _canUserScroll(ScrollableState scrollable) {
    return scrollable.widget.physics is! NeverScrollableScrollPhysics;
  }

  static ScrollableState? _verticalScrollableOf(FocusNode node) {
    final BuildContext? context = node.context;
    if (context == null) return null;
    ScrollableState? result;
    context.visitAncestorElements((Element element) {
      if (element is StatefulElement && element.state is ScrollableState) {
        final scrollable = element.state as ScrollableState;
        if (_canUserScroll(scrollable) &&
            (scrollable.axisDirection == AxisDirection.down ||
                scrollable.axisDirection == AxisDirection.up)) {
          result = scrollable;
          return false;
        }
      }
      return true;
    });
    return result;
  }

  static ScrollableState? _horizontalScrollableOf(FocusNode node) {
    final BuildContext? context = node.context;
    if (context == null) return null;
    ScrollableState? result;
    context.visitAncestorElements((Element element) {
      if (element is StatefulElement && element.state is ScrollableState) {
        final scrollable = element.state as ScrollableState;
        if (_canUserScroll(scrollable) &&
            (scrollable.axisDirection == AxisDirection.right ||
                scrollable.axisDirection == AxisDirection.left)) {
          result = scrollable;
          return false;
        }
      }
      return true;
    });
    return result;
  }

  static Element? _enclosingWrapOf(FocusNode node) {
    final BuildContext? context = node.context;
    if (context == null) return null;
    Element? result;
    context.visitAncestorElements((Element element) {
      if (element.widget is Wrap) {
        result = element;
        return false;
      }
      return true;
    });
    return result;
  }

  static Rect? _scrollableRect(ScrollableState? scrollable) {
    if (scrollable == null) return null;
    final RenderObject? ro = scrollable.context.findRenderObject();
    if (ro is RenderBox && ro.attached && ro.hasSize) {
      return ro.localToGlobal(Offset.zero) & ro.size;
    }
    return null;
  }

  static bool _isVisibleInScrollable(FocusNode node, Rect scrollableRect) {
    final Rect r = node.rect;
    return r.bottom > scrollableRect.top + 1.0 &&
        r.top < scrollableRect.bottom - 1.0 &&
        r.center.dy >= scrollableRect.top - 1.0 &&
        r.center.dy <= scrollableRect.bottom + 1.0;
  }

  static bool _isVisibleHorizontallyInScrollable(
    FocusNode node,
    Rect scrollableRect,
  ) {
    final Rect r = node.rect;
    return r.right > scrollableRect.left + 1.0 &&
        r.left < scrollableRect.right - 1.0 &&
        r.center.dx >= scrollableRect.left - 1.0 &&
        r.center.dx <= scrollableRect.right + 1.0;
  }

  static Element? _enclosingListTileOf(FocusNode node) {
    final BuildContext? context = node.context;
    if (context == null) return null;
    Element? result;
    context.visitAncestorElements((Element element) {
      if (element.widget is ListTile ||
          element.widget is custom_list_tile.ListTile) {
        result = element;
        return false;
      }
      return true;
    });
    return result;
  }

  static Element? _enclosingInkResponseOf(FocusNode node) {
    final BuildContext? context = node.context;
    if (context == null) return null;
    Element? result;
    context.visitAncestorElements((Element element) {
      if (element.widget is InkResponse) {
        result = element;
        return false;
      }
      return true;
    });
    return result;
  }

  /// Returns true when [secondary] is a small action widget (e.g. a trailing
  /// IconButton/Switch or an overlaid VideoPopupMenu) whose center lies inside
  /// a much larger primary container [container] (e.g. a ListTile or VideoCard).
  static bool _isEmbeddedSecondaryOf(FocusNode secondary, FocusNode container) {
    if (secondary == container) return false;
    final Rect cr = container.rect;
    final Rect sr = secondary.rect;
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
  ) {
    if (candidates.length <= 1) return candidates;
    return candidates.where((FocusNode node) {
      for (final FocusNode other in candidates) {
        if (other == node || other == focusedChild) continue;
        if (_isEmbeddedSecondaryOf(node, other)) {
          return false;
        }
      }
      return true;
    }).toList();
  }

  void _focusNode(FocusNode node, TraversalDirection direction) {
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
    final FocusScopeNode? nearestScope = currentNode.nearestScope;
    if (nearestScope == null) return false;
    nearestScope.directionalTraversalEdgeBehavior = TraversalEdgeBehavior.stop;
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

    final ScrollableState? focusedScrollable = _verticalScrollableOf(
      focusedChild,
    );
    final Rect? focusedScrollableRect = _scrollableRect(focusedScrollable);
    final ScrollableState? focusedHorizScrollable = _horizontalScrollableOf(
      focusedChild,
    );
    final Rect target = focusedChild.rect;

    final List<FocusNode> rawDescendants = nearestScope.traversalDescendants
        .where(
          (FocusNode node) =>
              node.context != null && _isEffectivelyFocusable(node),
        )
        .toList();
    final Set<FocusNode> rawSet = rawDescendants.toSet();
    final Set<FocusNode> nonLeafNodes = <FocusNode>{};
    for (final FocusNode node in rawDescendants) {
      final Element? nodeListTile = _enclosingListTileOf(node);
      final Rect nr = node.rect;
      for (final FocusNode ancestor in node.ancestors) {
        if (!rawSet.contains(ancestor)) continue;
        final Rect ar = ancestor.rect;
        final bool sameSizeWrapper =
            (ar.width - nr.width).abs() < 8.0 &&
            (ar.height - nr.height).abs() < 8.0;
        final bool isEnclosingListTileRow =
            nodeListTile != null &&
            !sameSizeWrapper &&
            _enclosingListTileOf(ancestor) == nodeListTile;
        final bool isPrimaryInkContainer =
            !sameSizeWrapper &&
            _enclosingInkResponseOf(ancestor) != null &&
            _isEmbeddedSecondaryOf(node, ancestor);
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
        ),
    };

    if (chosen != null) {
      _focusNode(chosen, direction);
      return true;
    }
    return false;
  }

  FocusNode? _findVerticalCandidate({
    required FocusNode focusedChild,
    required Rect target,
    required ScrollableState? focusedScrollable,
    required Rect? focusedScrollableRect,
    required ScrollableState? focusedHorizScrollable,
    required List<FocusNode> allNodes,
    required TraversalDirection direction,
  }) {
    final bool isDown = direction == TraversalDirection.down;
    final List<FocusNode> primaryNodes = _filterOutEmbeddedSecondaryActions(
      allNodes,
      focusedChild,
    ).where((FocusNode node) {
      final ScrollableState? nodeHorizScrollable = _horizontalScrollableOf(
        node,
      );
      if (nodeHorizScrollable != null &&
          nodeHorizScrollable != focusedHorizScrollable) {
        final Rect? horizRect = _scrollableRect(nodeHorizScrollable);
        if (horizRect != null &&
            !_isVisibleHorizontallyInScrollable(node, horizRect)) {
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
        if (_verticalScrollableOf(node) != focusedScrollable) return false;
        return isDown
            ? node.rect.center.dy >= target.bottom
            : node.rect.center.dy <= target.top;
      }).toList();
      if (sameScrollable.isNotEmpty) {
        return _pickFromClosestRow(
          referenceRect: target,
          candidates: sameScrollable,
          isDown: isDown,
          preferLeadingOnRow: false,
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
      final ScrollableState? nodeScrollable = _verticalScrollableOf(node);
      if (focusedScrollable != null && nodeScrollable == focusedScrollable) {
        continue;
      }
      final Rect? nodeScrollableRect = _scrollableRect(nodeScrollable);
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
        if (_isVisibleInScrollable(node, nodeScrollableRect)) {
          final bool nodeInDirection = isDown
              ? node.rect.center.dy >= target.bottom
              : node.rect.center.dy <= target.top;
          if (nodeInDirection) {
            externalCandidates.add(node);
          }
        } else {
          fallbackScrollableCandidates.add(node);
        }
      } else {
        if (focusedScrollableRect != null) {
          final bool overlapsFocusedScrollableHorizontally =
              node.rect.right > focusedScrollableRect.left + 2.0 &&
              node.rect.left < focusedScrollableRect.right - 2.0;
          if (!overlapsFocusedScrollableHorizontally) continue;
        } else {
          final bool overlapsTargetHorizontally =
              node.rect.right > target.left - 4.0 &&
              node.rect.left < target.right + 4.0;
          if (!overlapsTargetHorizontally) {
            // Reject candidates that belong to a separate side-by-side column
            // which already has items or a scrollable at target's vertical band.
            final bool belongsToAdjacentColumn = primaryNodes.any((
              FocusNode other,
            ) {
              if (other == node) return false;
              final Rect otherBounds =
                  _scrollableRect(_verticalScrollableOf(other)) ?? other.rect;
              final bool overlapsTargetVertically =
                  otherBounds.bottom > target.top + 1.0 &&
                  otherBounds.top < target.bottom - 1.0;
              final bool overlapsNodeHorizontally =
                  otherBounds.right > node.rect.left + 1.0 &&
                  otherBounds.left < node.rect.right - 1.0;
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
            ? node.rect.center.dy >= exitBoundary &&
                  node.rect.center.dy > target.center.dy
            : node.rect.center.dy <= exitBoundary &&
                  node.rect.center.dy < target.center.dy;
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
    );
  }

  static FocusNode _pickFromClosestRow({
    required Rect referenceRect,
    required List<FocusNode> candidates,
    required bool isDown,
    required bool preferLeadingOnRow,
  }) {
    FocusNode closestVertical = candidates.first;
    for (final FocusNode node in candidates.skip(1)) {
      if (isDown) {
        if (node.rect.center.dy < closestVertical.rect.center.dy) {
          closestVertical = node;
        }
      } else {
        if (node.rect.center.dy > closestVertical.rect.center.dy) {
          closestVertical = node;
        }
      }
    }

    final Rect rowBounds = closestVertical.rect;
    final List<FocusNode> row = candidates.where((FocusNode node) {
      final Rect r = node.rect;
      return r.top < rowBounds.bottom - 1.0 && r.bottom > rowBounds.top + 1.0;
    }).toList();

    if (row.length <= 1) return closestVertical;
    row.sort((FocusNode a, FocusNode b) => a.rect.left.compareTo(b.rect.left));
    if (preferLeadingOnRow && _verticalScrollableOf(row.first) != null) {
      return row.first;
    }

    final List<FocusNode> overlapping = row.where((FocusNode node) {
      final Rect r = node.rect;
      return r.right > referenceRect.left + 1.0 &&
          r.left < referenceRect.right - 1.0;
    }).toList();

    if (overlapping.isNotEmpty) {
      if (overlapping.length > 1 &&
          referenceRect.left <= overlapping.first.rect.center.dx &&
          referenceRect.right >= overlapping[1].rect.center.dx &&
          referenceRect.width > overlapping.first.rect.width * 1.5) {
        return overlapping.first;
      }
      overlapping.sort(
        (FocusNode a, FocusNode b) =>
            (a.rect.center.dx - referenceRect.center.dx).abs().compareTo(
              (b.rect.center.dx - referenceRect.center.dx).abs(),
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
      final int cmp = horizontalGap(a.rect).compareTo(horizontalGap(b.rect));
      if (cmp != 0) return cmp;
      return (a.rect.center.dx - referenceRect.center.dx).abs().compareTo(
        (b.rect.center.dx - referenceRect.center.dx).abs(),
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
  }) {
    final bool isRight = direction == TraversalDirection.right;

    // 0. Support stepping between a ListTile container and its trailing
    // focusable descendant (e.g. refresh IconButton or Switch).
    final Element? focusedListTile = _enclosingListTileOf(focusedChild);
    if (focusedListTile != null) {
      if (isRight) {
        final List<FocusNode> trailingChildren = allNodes.where((
          FocusNode node,
        ) {
          return node.ancestors.contains(focusedChild) &&
              _enclosingListTileOf(node) == focusedListTile &&
              node.rect.center.dx > target.center.dx + 8.0;
        }).toList();
        if (trailingChildren.isNotEmpty) {
          trailingChildren.sort(
            (FocusNode a, FocusNode b) => a.rect.left.compareTo(b.rect.left),
          );
          return trailingChildren.first;
        }
      } else {
        final List<FocusNode> parentContainers = allNodes.where((
          FocusNode node,
        ) {
          return focusedChild.ancestors.contains(node) &&
              _enclosingListTileOf(node) == focusedListTile &&
              node.rect.center.dx < target.center.dx - 8.0;
        }).toList();
        if (parentContainers.isNotEmpty) {
          parentContainers.sort(
            (FocusNode a, FocusNode b) => b.rect.left.compareTo(a.rect.left),
          );
          return parentContainers.first;
        }
      }
    }

    final List<FocusNode> primaryNodes = _filterOutEmbeddedSecondaryActions(
      allNodes,
      focusedChild,
    );

    // 1. If currently inside a horizontal scrollable, traverse remaining items
    // within that horizontal scrollable before exiting to a sidebar.
    if (focusedHorizScrollable != null) {
      final List<FocusNode> sameHorizScrollable = primaryNodes.where((
        FocusNode node,
      ) {
        if (_horizontalScrollableOf(node) != focusedHorizScrollable) {
          return false;
        }
        final Rect r = node.rect;
        final bool sameRow =
            r.bottom > target.top + 1.0 && r.top < target.bottom - 1.0;
        if (!sameRow) return false;
        return isRight
            ? r.center.dx >= target.right
            : r.center.dx <= target.left;
      }).toList();
      if (sameHorizScrollable.isNotEmpty) {
        sameHorizScrollable.sort((FocusNode a, FocusNode b) {
          final double distA = math.max(
            0.0,
            isRight ? a.rect.left - target.right : target.left - a.rect.right,
          );
          final double distB = math.max(
            0.0,
            isRight ? b.rect.left - target.right : target.left - b.rect.right,
          );
          final int cmp = distA.compareTo(distB);
          if (cmp != 0) return cmp;
          return (a.rect.center.dy - target.center.dy).abs().compareTo(
            (b.rect.center.dy - target.center.dy).abs(),
          );
        });
        return sameHorizScrollable.first;
      }
    }

    final List<FocusNode> directionalNodes = primaryNodes.where((
      FocusNode node,
    ) {
      final bool inHorizDirection = isRight
          ? node.rect.center.dx >= target.right
          : node.rect.center.dx <= target.left;
      if (!inHorizDirection) return false;
      final ScrollableState? nodeScrollable = _verticalScrollableOf(node);
      if (nodeScrollable != null && nodeScrollable != focusedScrollable) {
        final Rect? nodeScrollableRect = _scrollableRect(nodeScrollable);
        if (nodeScrollableRect != null &&
            !_isVisibleInScrollable(node, nodeScrollableRect)) {
          return false;
        }
      }
      final ScrollableState? nodeHorizScrollable = _horizontalScrollableOf(
        node,
      );
      if (nodeHorizScrollable != null &&
          nodeHorizScrollable != focusedHorizScrollable) {
        final Rect? horizRect = _scrollableRect(nodeHorizScrollable);
        if (horizRect != null &&
            !_isVisibleHorizontallyInScrollable(node, horizRect)) {
          return false;
        }
      }
      return true;
    }).toList();

    if (directionalNodes.isEmpty) return null;

    // 2. Prefer candidates on the same visual row (vertically overlapping target).
    final List<FocusNode> inBand = directionalNodes.where((FocusNode node) {
      final Rect r = node.rect;
      return r.bottom > target.top + 1.0 && r.top < target.bottom - 1.0;
    }).toList();

    if (inBand.isNotEmpty) {
      inBand.sort((FocusNode a, FocusNode b) {
        final double distA = math.max(
          0.0,
          isRight ? a.rect.left - target.right : target.left - a.rect.right,
        );
        final double distB = math.max(
          0.0,
          isRight ? b.rect.left - target.right : target.left - b.rect.right,
        );
        final int cmp = distA.compareTo(distB);
        if (cmp != 0) return cmp;
        final int centerCmp = (a.rect.center.dx - target.center.dx)
            .abs()
            .compareTo((b.rect.center.dx - target.center.dx).abs());
        if (centerCmp != 0) return centerCmp;
        return (a.rect.center.dy - target.center.dy).abs().compareTo(
          (b.rect.center.dy - target.center.dy).abs(),
        );
      });
      return inBand.first;
    }

    // 3. Only fall back to out-of-band candidates when crossing between
    // genuinely side-by-side panels (not vertically stacked rows/sections).
    final Element? focusedWrap = _enclosingWrapOf(focusedChild);
    final List<FocusNode> sideBySide = directionalNodes.where((FocusNode node) {
      final ScrollableState? nodeScrollable = _verticalScrollableOf(node);
      if (focusedScrollable != null && nodeScrollable == focusedScrollable) {
        return false;
      }
      if (focusedWrap != null && _enclosingWrapOf(node) == focusedWrap) {
        return false;
      }
      if (node.rect.right > target.left + 1.0 &&
          node.rect.left < target.right - 1.0) {
        return false;
      }
      if (focusedScrollableRect != null) {
        final bool overlapsFocusedScrollableVertically =
            node.rect.center.dy >= focusedScrollableRect.top + 4.0 &&
            node.rect.center.dy <= focusedScrollableRect.bottom - 4.0;
        final bool outsideFocusedScrollableHorizontally = isRight
            ? node.rect.left >= focusedScrollableRect.right - 2.0
            : node.rect.right <= focusedScrollableRect.left + 2.0;
        if (!overlapsFocusedScrollableVertically ||
            !outsideFocusedScrollableHorizontally) {
          return false;
        }
      }
      final Rect? nodeScrollableRect = _scrollableRect(nodeScrollable);
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
        final double minY = math.min(target.bottom, node.rect.bottom);
        final double maxY = math.max(target.top, node.rect.top);
        final double gapLeft = isRight ? target.right : node.rect.right;
        final double gapRight = isRight ? node.rect.left : target.left;
        final bool separatedByIntermediateSection = primaryNodes.any((
          FocusNode other,
        ) {
          if (other == node) return false;
          final Rect r =
              _scrollableRect(_verticalScrollableOf(other)) ?? other.rect;
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
      final int vCmp = (a.rect.center.dy - target.center.dy).abs().compareTo(
        (b.rect.center.dy - target.center.dy).abs(),
      );
      if (vCmp != 0) return vCmp;
      final double hDistA = isRight
          ? a.rect.left - target.right
          : target.left - a.rect.right;
      final double hDistB = isRight
          ? b.rect.left - target.right
          : target.left - b.rect.right;
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
  final GlobalKey _key = GlobalKey();
  final TvFocusTraversalPolicy _policy = TvFocusTraversalPolicy();
  late final Map<Type, Action<Intent>> _actions = <Type, Action<Intent>>{
    DirectionalFocusIntent: _TvDirectionalFocusAction(_policy),
    _TvVerticalFocusIntent: _TvVerticalFocusAction(_policy),
  };
  Rect? _rect;
  bool _rectSyncScheduled = false;

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

  void _syncFocusRectAfterLayout(Duration _) {
    if (!mounted || !TvPlatform.isTv || _rectSyncScheduled) return;
    final FocusNode? node = FocusManager.instance.primaryFocus;
    if (node is FocusScopeNode) return;
    final Rect? rect = _computeFocusedRect(node);
    if (_sameRect(rect, _rect)) return;
    _rectSyncScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _rectSyncScheduled = false;
      if (!mounted) return;
      final Rect? latest = _computeFocusedRect(
        FocusManager.instance.primaryFocus,
      );
      if (!_sameRect(latest, _rect)) {
        setState(() => _rect = latest);
      }
    });
  }

  void _onFocus() {
    if (!TvPlatform.isTv) return;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
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
        if (_rect != null) setState(() => _rect = null);
        return;
      }
      final BuildContext? context = node?.context;
      if (context != null && context.mounted && node is! FocusScopeNode) {
        await Scrollable.ensureVisible(
          context,
          duration: const Duration(milliseconds: 120),
          alignmentPolicy: ScrollPositionAlignmentPolicy.keepVisibleAtEnd,
        );
      }
      if (!mounted || node != FocusManager.instance.primaryFocus) return;
      final Rect? rect = _computeFocusedRect(node);
      setState(() => _rect = rect);
    });
    WidgetsBinding.instance.ensureVisualUpdate();
  }

  KeyEventResult _handleKeyEvent(FocusNode _, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;
    final LogicalKeyboardKey key = event.logicalKey;
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
      child: Focus(
        canRequestFocus: false,
        skipTraversal: true,
        onKeyEvent: _handleKeyEvent,
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
            child: Stack(
              key: _key,
              fit: StackFit.expand,
              children: <Widget>[
                FocusTraversalGroup(
                  policy: _policy,
                  child: widget.child,
                ),
                if (_rect case final Rect rect)
                  Positioned.fromRect(
                    rect: rect.inflate(2),
                    child: IgnorePointer(
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          border: Border.all(
                            color: const Color(0xFFFFD166),
                            width: 3,
                          ),
                          borderRadius: BorderRadius.circular(12),
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
