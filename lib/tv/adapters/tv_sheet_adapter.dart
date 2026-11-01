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
/// The engine still keeps the sheets' lifecycle (M13.2 moves it onto the layer
/// stack). It holds a layout as an [Element] and a sheet as a [Widget], and
/// reads both through here.
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
