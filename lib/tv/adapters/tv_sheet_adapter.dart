import 'package:PiliPlus/common/widgets/scaffold/bottom_sheet_layout.dart'
    show BottomSheetLayout, BottomSheetType;
import 'package:PiliPlus/tv/adapters/tv_focus_adapter.dart';
import 'package:material_ui/material_ui.dart';

/// Where a focus node stands against the inline sheets around it.
class TvSheetNodeStatus {
  const TvSheetNodeStatus({
    this.occludingLayout,
    this.closingLayout,
    this.enclosingActiveSheetLayout,
  });

  final Element? occludingLayout;
  final Element? closingLayout;
  final Element? enclosingActiveSheetLayout;

  bool get isInvalidated => occludingLayout != null || closingLayout != null;
}

/// Inline sheets: `MiniScaffold` shows a sheet in place, as a slot of a
/// `BottomSheetLayout`, instead of pushing a route. An open sheet hides only
/// the `body` slot of its own layout, and a closing one is hidden itself while
/// its reverse animation runs.
///
/// The engine's layer stack keeps the sheets' lifecycle, with each sheet a
/// non-modal [TvSheetLayer]. It holds a layout as an [Element] and a sheet as a
/// [Widget], and reads both through here.
final class TvSheetAdapter extends TvFocusAdapter {
  const TvSheetAdapter();

  @override
  @pragma('vm:prefer-inline')
  bool hides(Widget ancestor, Object? childSlot) =>
      ancestor is BottomSheetLayout && _hidesSlot(ancestor, childSlot);

  @pragma('vm:prefer-inline')
  bool _hidesSlot(BottomSheetLayout layout, Object? childSlot) {
    final Widget? sheet = layout.bottomSheet;
    if (sheet == null) return false;
    return isClosing(sheet)
        ? childSlot == BottomSheetType.bottomSheet
        : childSlot == BottomSheetType.body;
  }

  /// Whether [element] is a sheet layout.
  @pragma('vm:prefer-inline')
  bool isLayout(Element element) => element.widget is BottomSheetLayout;

  /// The sheet in the layout at [layout], if one is showing.
  @pragma('vm:prefer-inline')
  Widget? sheetOf(Element layout) {
    final Widget widget = layout.widget;
    return widget is BottomSheetLayout ? widget.bottomSheet : null;
  }

  /// Every sheet `MiniScaffold` puts in a `BottomSheetLayout` is a
  /// [StandardBottomSheet]. A typed read means an upstream rename fails to
  /// compile, instead of every sheet silently counting as open.
  AnimationController? _animationController(Widget? sheet) =>
      sheet is StandardBottomSheet ? sheet.animationController : null;

  bool isClosing(Widget? sheet) {
    if (sheet == null) return true;
    final AnimationController? controller = _animationController(sheet);
    if (controller != null) {
      final status = controller.status;
      return status == AnimationStatus.reverse ||
          status == AnimationStatus.dismissed;
    }
    return false;
  }

  bool isAnimatingOpen(Widget? sheet) {
    final AnimationController? controller = _animationController(sheet);
    if (controller != null) {
      return controller.status == AnimationStatus.forward;
    }
    return false;
  }

  /// Walks [node]'s ancestors for the sheets it stands behind or inside.
  TvSheetNodeStatus inspect(FocusNode? node) {
    final BuildContext? context = node?.context;
    if (context == null || !context.mounted) {
      return const TvSheetNodeStatus();
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
          final bool closing = isClosing(sheet);
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
      return const TvSheetNodeStatus();
    }
    return TvSheetNodeStatus(
      occludingLayout: occludingLayout,
      closingLayout: closingLayout,
      enclosingActiveSheetLayout: enclosingActiveSheetLayout,
    );
  }

  /// The sheet layouts above [node], innermost first.
  List<Element> layoutsAround(FocusNode? node) {
    final BuildContext? context = node?.context;
    if (context == null || !context.mounted) return const <Element>[];
    List<Element>? found;
    context.visitAncestorElements((Element element) {
      if (element.widget is BottomSheetLayout) {
        (found ??= <Element>[]).add(element);
      }
      return true;
    });
    return found ?? const <Element>[];
  }

  /// The element that holds the sheet of the layout at [layout].
  Element? sheetSlotOf(Element layout) =>
      _slotChild(layout, BottomSheetType.bottomSheet);

  /// The element that holds the body of the layout at [layout].
  Element? bodySlotOf(Element layout) =>
      _slotChild(layout, BottomSheetType.body);

  Element? _slotChild(Element layout, BottomSheetType slot) {
    if (!layout.mounted || layout.widget is! BottomSheetLayout) {
      return null;
    }
    Element? found;
    layout.visitChildren((Element child) {
      if (child.slot == slot) {
        found = child;
      }
    });
    return found;
  }

  /// Whether anything under [root] could take focus, skipping what a sheet
  /// layout hides.
  bool hasRequestableFocus(Element root) {
    if (!root.mounted) return false;
    bool found = false;
    void visit(Element el) {
      if (found) return;
      final Widget w = el.widget;
      if (w is ExcludeFocus && w.excluding) return;
      if (w is Offstage && w.offstage) return;
      if (w is Visibility && !w.visible) return;
      if (w is IgnorePointer && w.ignoring) return;
      if (w is BottomSheetLayout) {
        final Widget? sheet = w.bottomSheet;
        if (sheet != null) {
          final bool sheetClosing = isClosing(sheet);
          el.visitChildren((Element child) {
            if (found) return;
            if (child.slot == BottomSheetType.body && !sheetClosing) return;
            if (child.slot == BottomSheetType.bottomSheet && sheetClosing) {
              return;
            }
            visit(child);
          });
          return;
        }
      }
      final RenderObject? ro = el.renderObject;
      if (ro is RenderBox &&
          (!ro.attached ||
              !ro.hasSize ||
              ro.size.width <= 1.0 ||
              ro.size.height <= 1.0)) {
        return;
      }
      if (w is Focus &&
          w is! FocusScope &&
          w.canRequestFocus &&
          (w.focusNode?.canRequestFocus ?? true) &&
          !w.skipTraversal &&
          !(w.focusNode?.skipTraversal ?? false)) {
        found = true;
        return;
      }
      el.visitChildren(visit);
    }

    visit(root);
    return found;
  }
}

/// One inline sheet as a non-modal focus layer: the sheet slot of a
/// `BottomSheetLayout`, which covers that layout's body and nothing else.
///
/// The layout's element stays while sheets come and go in it, so [sheet] is
/// replaced in place when another sheet takes the slot.
///
/// The layer listens to its sheet's animation status: each change calls
/// `onStatus`, so the layer stack learns that a sheet it tracks started
/// closing, or finished opening, without reading every sheet's animation on
/// every frame. Call [dispose] when the stack stops tracking the layer.
final class TvSheetLayer extends TvFocusLayer {
  /// [onStatus] is called on each change of the sheet's animation status.
  TvSheetLayer(this.layout, Widget sheet, this._onStatus) : _sheet = sheet {
    _watch();
  }

  static const TvSheetAdapter _sheets = TvSheetAdapter();

  /// The `BottomSheetLayout` the sheet shows in.
  final Element layout;
  final VoidCallback _onStatus;
  Widget _sheet;
  AnimationController? _watched;

  /// The sheet this layer stands for.
  Widget get sheet => _sheet;
  set sheet(Widget next) {
    if (identical(next, _sheet)) return;
    _unwatch();
    _sheet = next;
    _watch();
  }

  /// Stops listening to the sheet's animation. The listener is removed even
  /// if upstream has disposed the controller since: a disposed controller has
  /// dropped its listeners already, and removing one again does nothing.
  void dispose() => _unwatch();

  void _watch() {
    _watched = _sheets._animationController(_sheet)
      ?..addStatusListener(_statusChanged);
  }

  void _unwatch() {
    _watched?.removeStatusListener(_statusChanged);
    _watched = null;
  }

  void _statusChanged(AnimationStatus status) => _onStatus();

  @override
  bool get isModal => false;

  /// The focus scope the layout sits in, found without registering an
  /// inherited dependency: `FocusScope.of` would rebuild the layout on every
  /// focus change in that scope.
  FocusScopeNode? get scope => Focus.maybeOf(
    layout,
    scopeOk: true,
    createDependency: false,
  )?.nearestScope;

  @override
  bool contains(FocusNode node) {
    final Element? slot = _sheets.sheetSlotOf(layout);
    return slot != null && tvIsInSubtree(node.context, slot);
  }

  /// Kept out of line: the layer stack's `occludes` loop over its modal
  /// layers runs on every focusability check, and a sheet is never in it, so
  /// this body must not be inlined there.
  @override
  @pragma('vm:never-inline')
  bool occludes(FocusNode node) {
    if (_sheets.isClosing(_sheets.sheetOf(layout))) return false;
    final Element? body = _sheets.bodySlotOf(layout);
    return body != null && tvIsInSubtree(node.context, body);
  }

  @override
  FocusNode? firstFocus(TvFocusFinder policy) {
    final FocusScopeNode? scope = this.scope;
    if (scope == null || tvIsScopeInactive(scope) || !scope.canRequestFocus) {
      return null;
    }
    final Element? slot = _sheets.sheetSlotOf(layout);
    return slot != null ? policy.findFirstFocusInSubtree(slot, scope) : null;
  }

  /// Whether [firstFocus] would find a node, with a cheap walk for anything
  /// requestable first, so a sheet with nothing focusable (an image preview)
  /// costs one walk of its subtree.
  bool canTakeFocus(TvFocusFinder policy) {
    if (!layout.mounted || !_sheets.isLayout(layout)) return false;
    final FocusScopeNode? scope = this.scope;
    if (scope == null || tvIsScopeInactive(scope) || !scope.canRequestFocus) {
      return false;
    }
    final Element? slot = _sheets.sheetSlotOf(layout);
    if (slot == null || !_sheets.hasRequestableFocus(slot)) return false;
    return policy.findFirstFocusInSubtree(slot, scope) != null;
  }

  /// The first node in the layout's body, where focus goes when the sheet
  /// closes and its trigger is gone.
  FocusNode? bodyFocus(TvFocusFinder policy, FocusScopeNode scope) {
    final Element? body = _sheets.bodySlotOf(layout);
    return body != null ? policy.findFirstFocusInSubtree(body, scope) : null;
  }
}
