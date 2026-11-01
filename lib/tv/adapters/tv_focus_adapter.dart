import 'package:flutter/widgets.dart';

/// The focus engine's view of one upstream source.
///
/// The engine in `tv_navigation.dart` knows Flutter and nothing of upstream's
/// widgets and pages. What it has to know about one of them comes from that
/// source's adapter: what to hide, which layers open over the page, which
/// controls are primary or secondary, and which nodes form a group. A source
/// overrides what it has, and the defaults say it adds nothing.
///
/// [hides] and [isGroup] run for every ancestor of every candidate on each
/// D-pad step, and [isSecondaryIn] for pairs of candidates, so the engine never
/// loops over adapters for them. It calls the `const` adapters in
/// `tv_adapters.dart` by name. Each one is a `final class`, so those calls bind
/// at compile time and inline into the walk, and a step pays only for the check
/// inside.
/// [layerProviders] and [didPushRoute] are cold, and the engine reaches them
/// through the list of all adapters.
abstract class TvFocusAdapter {
  const TvFocusAdapter();

  /// What to hide: whether [ancestor] keeps a focus node below it out of reach.
  /// [childSlot] is the slot of [ancestor]'s child on the way to that node.
  bool hides(Widget ancestor, Object? childSlot) => false;

  /// Groups: whether [widget] holds the focus nodes below it together.
  bool isGroup(Widget widget) => false;

  /// Roles: whether a node at [node] is secondary in the group at [container],
  /// an action embedded in it such as a comment's `回复` or a tile's trailing
  /// switch, and not a primary control of its own. Both are global rects.
  bool isSecondaryIn(Rect node, Rect container) => false;

  /// Layers: this source's kinds of focus layer, bottom first. [anchor] is the
  /// focus node above the root `Navigator`, and [rememberTrigger] records the
  /// node a route should give focus back to when it is uncovered.
  List<TvFocusLayerProvider> layerProviders({
    required FocusNode anchor,
    required ValueSetter<FocusNode> rememberTrigger,
  }) => const <TvFocusLayerProvider>[];

  /// Called on TV when [route] is pushed.
  void didPushRoute(Route<dynamic> route) {}
}

/// The parts of the traversal policy that a focus layer uses.
abstract interface class TvFocusFinder {
  /// Whether [node] can be focused right now, by the rules of
  /// `TvFocusTraversalPolicy.isEffectivelyFocusable`.
  bool isFocusable(FocusNode node);

  /// The first node to focus under [currentNode].
  FocusNode? findFirstFocus(FocusNode currentNode, {bool ignoreCurrentFocus});

  /// The node to focus among [candidates].
  FocusNode? findFirstFocusAmong(Iterable<FocusNode> candidates);
}

/// One modal layer drawn above the page that opened it.
///
/// "A new layer appears but focus stays on the page behind it" has had to be
/// fixed once per kind of layer: popup routes that skip auto-focus (M6), inline
/// `MiniScaffold` sheets (M9) and overlay dialogs outside the `Navigator`
/// (M10). A provider answers the same few questions for its kind of layer, and
/// the engine's layer stack owns the lifecycle they share: remember the
/// trigger, move focus into the layer, keep the page behind it unfocusable, and
/// give focus back to the trigger when the layer closes.
abstract class TvFocusLayer {
  /// Whether [node] belongs to this layer.
  bool contains(FocusNode node);

  /// Whether [node] sits behind this layer. Such a node is not focusable and
  /// gets no focus ring while the layer is open.
  bool occludes(FocusNode node);

  /// Where focus goes when the layer opens, or `null` while it has nothing
  /// focusable yet.
  FocusNode? firstFocus(TvFocusFinder policy);

  /// Called once when the stack starts tracking the layer, with the page
  /// control that had focus (`null` when there was none worth returning to).
  void opened(FocusNode? trigger) {}

  /// Moves focus to [target], which [firstFocus] returned.
  void promote(FocusNode target) {
    target
      ..requestFocus()
      ..consumeKeyboardToken();
  }
}

abstract class TvFocusLayerProvider {
  /// The layers of this kind that are open right now, bottom first.
  ///
  /// The stack asks every frame, so this must return a shared empty list
  /// without walking the tree when nothing is open.
  List<TvFocusLayer> discover(TvFocusFinder policy);
}

/// Whether [scope] or a scope above it is inactive: `skipTraversal` is set
/// while its route is covered.
bool tvIsScopeInactive(FocusScopeNode scope) {
  FocusScopeNode? current = scope;
  while (current != null) {
    if (current.skipTraversal) return true;
    current = current.enclosingScope;
  }
  return false;
}

/// The active scope next to the inactive branch that holds [scope]: the route
/// that covers it.
FocusScopeNode? tvFindActiveSiblingScope(FocusScopeNode scope) {
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
              !tvIsScopeInactive(child) &&
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

final Expando<ModalRoute<dynamic>> _routeOfScope = Expando<ModalRoute<dynamic>>(
  'tvRouteOfScope',
);

/// The route that owns [node]'s focus scope, looked up once per scope.
/// `ModalRoute.of(node.context)` registers an inherited dependency on the
/// focused widget itself, so that widget rebuilt whenever its route's modal
/// state changed. Asking the scope's own context once puts the dependency on
/// the scope, which holds the same child and rebuilds nothing below it.
ModalRoute<dynamic>? tvRouteOfFocusNode(FocusNode node) {
  final FocusScopeNode? scope = node.nearestScope;
  if (scope == null) return null;
  final ModalRoute<dynamic>? cached = _routeOfScope[scope];
  if (cached != null) return cached;
  final BuildContext? context = scope.context;
  if (context == null || !context.mounted) return null;
  final ModalRoute<dynamic>? route = ModalRoute.of(context);
  if (route != null) _routeOfScope[scope] = route;
  return route;
}
