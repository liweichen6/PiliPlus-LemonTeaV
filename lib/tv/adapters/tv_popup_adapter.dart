import 'package:PiliPlus/tv/adapters/tv_focus_adapter.dart';
import 'package:flutter/widgets.dart';

/// Popup routes and overlay dialogs, the two kinds of focus layer that open
/// over a page.
final class TvPopupAdapter extends TvFocusAdapter {
  const TvPopupAdapter();

  @override
  List<TvFocusLayerProvider> layerProviders({
    required FocusNode anchor,
    required ValueSetter<FocusNode> rememberTrigger,
  }) => <TvFocusLayerProvider>[
    // Bottom first: popup routes sit below overlay content.
    _RouteFocusLayerProvider(rememberTrigger),
    _OverlayFocusLayer(anchor),
  ];
}

/// Focusable content that lives outside the root `Navigator`, such as the
/// overlay entries `flutter_smart_dialog` inserts next to it.
///
/// `TvNavigation` puts an anchor [FocusNode] above its whole subtree. The root
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
class _OverlayFocusLayer extends TvFocusLayer implements TvFocusLayerProvider {
  _OverlayFocusLayer(this.anchor);

  final FocusNode anchor;
  late final List<TvFocusLayer> _open = <TvFocusLayer>[this];

  NavigatorState? _navigator;
  bool _navigatorSearched = false;

  /// The root `Navigator`, found once. An anchor without one has no overlay
  /// layers, which is also the answer for `TvNavigation` placed inside a route.
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

  static final Expando<bool> _textSelectionBranches = Expando<bool>(
    'tvTextSelectionBranch',
  );

  /// Whether [branch] belongs to a text field's selection toolbar or context
  /// menu. Flutter inserts those into the root overlay, which is this one, and
  /// wraps them in a [TextFieldTapRegion]. They are not modal: the text field
  /// must keep focus, because it disposes the toolbar as soon as it loses it.
  static bool _isTextSelectionBranch(FocusNode branch) {
    final bool? cached = _textSelectionBranches[branch];
    if (cached != null) return cached;
    final BuildContext? context = branch.context;
    if (context == null || !context.mounted) return false;
    final bool result =
        context.findAncestorWidgetOfExactType<TextFieldTapRegion>() != null;
    _textSelectionBranches[branch] = result;
    return result;
  }

  /// The children of [anchor] that hold modal overlay content: neither the
  /// Navigator's branch nor a text selection toolbar.
  Iterable<FocusNode> _modalBranches(FocusNode navigatorBranch) =>
      anchor.children.where(
        (FocusNode branch) =>
            !identical(branch, navigatorBranch) &&
            !_isTextSelectionBranch(branch),
      );

  /// A focusable leaf. A focus scope is never a target: requesting focus on a
  /// scope with no focused child leaves primary focus on the scope itself,
  /// which the stack does not count as inside the layer, so it would promote
  /// the same scope again on every frame.
  static bool _isFocusable(FocusNode node, TvFocusFinder policy) =>
      node is! FocusScopeNode &&
      node.canRequestFocus &&
      !node.skipTraversal &&
      policy.isFocusable(node);

  @override
  List<TvFocusLayer> discover(TvFocusFinder policy) {
    // Only the Navigator's branch below the anchor: nothing else is mounted.
    if (anchor.children.length < 2) return const <TvFocusLayer>[];
    final FocusNode? navigatorBranch = _navigatorBranch();
    if (navigatorBranch == null) return const <TvFocusLayer>[];
    for (final FocusNode branch in _modalBranches(navigatorBranch)) {
      if (_isFocusable(branch, policy)) return _open;
      for (final FocusNode node in branch.descendants) {
        if (_isFocusable(node, policy)) return _open;
      }
    }
    return const <TvFocusLayer>[];
  }

  @override
  bool contains(FocusNode node) {
    final FocusNode? branch = _branchOf(node);
    return branch != null &&
        !identical(branch, _navigatorBranch()) &&
        !_isTextSelectionBranch(branch);
  }

  @override
  bool occludes(FocusNode node) => !contains(node);

  @override
  FocusNode? firstFocus(TvFocusFinder policy) {
    final FocusNode? navigatorBranch = _navigatorBranch();
    if (navigatorBranch == null) return null;
    final List<FocusNode> candidates = <FocusNode>[];
    for (final FocusNode branch in _modalBranches(navigatorBranch)) {
      if (branch is! FocusScopeNode &&
          branch.canRequestFocus &&
          !branch.skipTraversal) {
        candidates.add(branch);
      }
      candidates.addAll(
        branch.traversalDescendants.where(
          (FocusNode node) => node is! FocusScopeNode,
        ),
      );
    }
    return policy.findFirstFocusAmong(candidates);
  }
}

/// A route whose own focus scope is active but never received focus, such as
/// a `showMenu(requestFocus: false)` popup (`PopupListTile`).
///
/// The covered page's scope turns inactive (`skipTraversal` is set while its
/// route is not current) yet primary focus stays on the control that opened
/// the popup, so nothing in the popup is reachable by D-pad. Unlike an overlay
/// layer there is nothing to occlude: traversal only looks inside the scope of
/// the focused node, and the covered scope is inactive.
class _RouteFocusLayer extends TvFocusLayer {
  _RouteFocusLayer(this.scope, this.rememberTrigger);

  /// The popup route's focus scope.
  final FocusScopeNode scope;
  final ValueSetter<FocusNode> rememberTrigger;

  /// Still mounted and still the active route scope.
  bool get isOpen =>
      (scope.context?.mounted ?? false) && !tvIsScopeInactive(scope);

  @override
  bool contains(FocusNode node) {
    FocusScopeNode? current = node.nearestScope;
    while (current != null) {
      if (identical(current, scope)) return true;
      current = current.enclosingScope;
    }
    return false;
  }

  @override
  bool occludes(FocusNode node) => false;

  @override
  FocusNode? firstFocus(TvFocusFinder policy) =>
      scope.canRequestFocus ? policy.findFirstFocus(scope) : null;

  @override
  void opened(FocusNode? trigger) {
    // The Navigator observer restores this node when the popup route pops.
    if (trigger != null) rememberTrigger(trigger);
  }

  @override
  void promote(FocusNode target) {
    scope.enclosingScope?.setFirstFocus(scope);
    super.promote(target);
  }
}

/// Finds popup routes that are active while primary focus is stuck in the
/// scope they cover, and keeps a layer for each until its scope goes away.
///
/// Only [PopupRoute]s qualify (menus, dialogs, sheets). A page route pushed
/// over another one is in the same state until it takes focus, but a page takes
/// focus itself and must not be held as a modal layer for as long as it is on
/// screen: the layer would pull focus back to the page's first control whenever
/// primary focus is parked on a scope node, which is how the inline-sheet code
/// holds focus while a sheet is still loading.
class _RouteFocusLayerProvider implements TvFocusLayerProvider {
  _RouteFocusLayerProvider(this.rememberTrigger);

  final ValueSetter<FocusNode> rememberTrigger;

  final Map<FocusScopeNode, _RouteFocusLayer> _layers =
      <FocusScopeNode, _RouteFocusLayer>{};

  /// What [discover] returns, rebuilt only when the set of layers changes: the
  /// stack asks every frame.
  List<TvFocusLayer> _open = const <TvFocusLayer>[];

  @override
  List<TvFocusLayer> discover(TvFocusFinder policy) {
    bool changed = false;
    if (_layers.isNotEmpty) {
      final int before = _layers.length;
      _layers.removeWhere((_, _RouteFocusLayer layer) => !layer.isOpen);
      changed = _layers.length != before;
    }
    final FocusNode? primary = FocusManager.instance.primaryFocus;
    if (primary != null && primary is! FocusScopeNode) {
      final FocusScopeNode? covered = primary.nearestScope;
      if (covered != null && tvIsScopeInactive(covered)) {
        final FocusScopeNode? popup = tvFindActiveSiblingScope(covered);
        if (popup != null &&
            !_layers.containsKey(popup) &&
            tvRouteOfFocusNode(popup) is PopupRoute<dynamic>) {
          _layers[popup] = _RouteFocusLayer(popup, rememberTrigger);
          changed = true;
        }
      }
    }
    if (changed) {
      _open = _layers.isEmpty
          ? const <TvFocusLayer>[]
          : _layers.values.toList(growable: false);
    }
    return _open;
  }
}
