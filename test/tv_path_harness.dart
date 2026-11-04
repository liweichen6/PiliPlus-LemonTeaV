// Replays recorded D-pad paths (M13.3), for `tv_paths_test.dart` and the
// player HUD's paths in `tv_player_hud_test.dart`.
//
// A path is a start node and a list of steps, each a key and the node focus
// should land on. After every step the replay checks the focused node, that
// the ring is drawn on it, and that all of it is on screen and inside every
// list around it. The expected path is the correct behavior, including the
// fixes from the M13.0 bug inventory (`docs/tv/M13_BASELINE.md`).
//
// A path the current rules get wrong is a known failure, labelled with its
// bug: the replay checks every step before the bad one, then checks that the
// bad step goes wrong exactly as the old rules make it. If the bug is fixed,
// or goes wrong in some new way, the test fails and says so, so M13.4 sees
// exactly which paths its scorer changes.
import 'package:PiliPlus/tv/tv_navigation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

const LogicalKeyboardKey dpadUp = LogicalKeyboardKey.arrowUp;
const LogicalKeyboardKey dpadDown = LogicalKeyboardKey.arrowDown;
const LogicalKeyboardKey dpadLeft = LogicalKeyboardKey.arrowLeft;
const LogicalKeyboardKey dpadRight = LogicalKeyboardKey.arrowRight;
const LogicalKeyboardKey dpadSelect = LogicalKeyboardKey.select;

/// Back: replayed as the system's back button, which is how the TV sends it.
const LogicalKeyboardKey dpadBack = LogicalKeyboardKey.goBack;

Future<void> _press(WidgetTester tester, LogicalKeyboardKey key) async {
  if (key == dpadBack) {
    await tester.binding.handlePopRoute();
  } else {
    await tester.sendKeyEvent(key);
  }
  await tester.pumpAndSettle();
}

/// The TV's logical size: 1080p at a device pixel ratio of 2.
const Size tvScreen = Size(960, 540);

/// One step of a recorded path: a key, and the label of the node focus should
/// land on.
typedef PathStep = (LogicalKeyboardKey key, String lands);

/// A path the current rules get wrong, until M13.4.
class KnownFailure {
  /// Step [step] lands on [landsOn] instead of the expected node.
  const KnownFailure({
    required this.bug,
    required this.step,
    required String this.landsOn,
  }) : cutOff = false;

  /// Step [step] lands on the expected node, but leaves it cut off: the ring
  /// isn't all on screen, or the node isn't all inside a list around it.
  const KnownFailure.cutOff({required this.bug, required this.step})
    : landsOn = null,
      cutOff = true;

  /// The bug's number in the inventory in `docs/tv/M13_BASELINE.md`.
  final int bug;

  /// The 1-based step that goes wrong.
  final int step;

  /// Where that step lands with the current rules.
  final String? landsOn;

  final bool cutOff;
}

/// Labels for a scene's own focus nodes. A node that a framework widget makes
/// (a tab, a rail destination) is named by the first text under it.
final Map<FocusNode, String> _labels = <FocusNode, String>{};

/// A focus node labelled [label], disposed when the test ends.
FocusNode pathNode(String label) {
  final FocusNode node = FocusNode(debugLabel: label);
  _labels[node] = label;
  addTearDown(() {
    _labels.remove(node);
    node.dispose();
  });
  return node;
}

String? _textUnder(Element root) {
  String? found;
  void visit(Element element) {
    if (found != null) return;
    final Widget widget = element.widget;
    if (widget is Text && widget.data != null) {
      found = widget.data;
      return;
    }
    element.visitChildElements(visit);
  }

  visit(root);
  return found;
}

String _labelOf(FocusNode? node) {
  if (node == null) return '(none)';
  final String? own = _labels[node];
  if (own != null) return own;
  final BuildContext? context = node.context;
  if (context is Element) {
    final String? text = _textUnder(context);
    if (text != null) return text;
    // A control with no text, such as a slider, by the control's name.
    String? control;
    int depth = 0;
    context.visitAncestorElements((Element element) {
      final String type = element.widget.runtimeType.toString();
      if (const <String>{'Slider', 'Switch', 'Checkbox'}.contains(type)) {
        control = type;
        return false;
      }
      return ++depth < 20;
    });
    if (control != null) return control!;
  }
  return '(${node.debugLabel ?? node.runtimeType})';
}

/// The label of the node that has focus.
String focusedLabel() => _labelOf(FocusManager.instance.primaryFocus);

/// The rect the focus ring is drawn at, or null with no ring.
Rect? ringRect(WidgetTester tester) {
  for (final CustomPaint paint in tester.widgetList<CustomPaint>(
    find.descendant(
      of: find.byType(TvNavigation),
      matching: find.byType(CustomPaint),
    ),
  )) {
    final CustomPainter? painter = paint.painter;
    if (painter != null &&
        painter.runtimeType.toString() == '_TvFocusRingPainter') {
      return (painter as dynamic).rect as Rect?;
    }
  }
  return null;
}

bool _near(Rect a, Rect b) =>
    (a.left - b.left).abs() < 0.5 &&
    (a.top - b.top).abs() < 0.5 &&
    (a.right - b.right).abs() < 0.5 &&
    (a.bottom - b.bottom).abs() < 0.5;

/// Whether [inner] lies inside [outer] along [axis], or covers all of it when
/// it's the larger of the two.
bool _inside(Rect inner, Rect outer, Axis axis) {
  const double slack = 1.0;
  if (axis == Axis.vertical) {
    if (inner.height > outer.height) {
      return inner.top <= outer.top + slack &&
          inner.bottom >= outer.bottom - slack;
    }
    return inner.top >= outer.top - slack &&
        inner.bottom <= outer.bottom + slack;
  }
  if (inner.width > outer.width) {
    return inner.left <= outer.left + slack &&
        inner.right >= outer.right - slack;
  }
  return inner.left >= outer.left - slack && inner.right <= outer.right + slack;
}

/// What's wrong with the ring on the focused node, or null if nothing is.
String? ringProblem(WidgetTester tester) {
  final FocusNode? focus = FocusManager.instance.primaryFocus;
  if (focus == null || focus.context == null) return 'nothing has focus';
  final Rect? ring = ringRect(tester);
  if (ring == null) return 'no ring is drawn';
  final Rect node = focus.rect;
  if (!_near(ring, node)) return 'the ring $ring is not on the node $node';
  if (!_inside(ring, Offset.zero & tvScreen, Axis.vertical) ||
      !_inside(ring, Offset.zero & tvScreen, Axis.horizontal)) {
    return 'the ring $ring runs off the screen';
  }
  ScrollableState? scrollable = Scrollable.maybeOf(focus.context!);
  while (scrollable != null) {
    final RenderObject? box = scrollable.context.findRenderObject();
    if (box is RenderBox && box.hasSize) {
      final Rect viewport = box.localToGlobal(Offset.zero) & box.size;
      final Axis axis = axisDirectionToAxis(scrollable.axisDirection);
      if (!_inside(node, viewport, axis)) {
        return 'the node $node is cut off by its list $viewport';
      }
    }
    scrollable = Scrollable.maybeOf(scrollable.context);
  }
  return null;
}

/// Replays [path] from the node labelled [start]. [path]'s labels may list
/// alternatives with `|` where more than one landing is correct.
Future<void> walkPath(
  WidgetTester tester,
  String start,
  List<PathStep> path, {
  KnownFailure? known,
}) async {
  expect(focusedLabel(), start, reason: 'the path starts somewhere else');
  String from = start;
  for (int i = 0; i < path.length; i++) {
    final (LogicalKeyboardKey key, String want) = path[i];
    await _press(tester, key);
    final String got = focusedLabel();
    final String? problem = ringProblem(tester);
    final String where =
        'step ${i + 1}, ${key == dpadBack ? 'Back' : key.keyLabel} from $from';
    final bool landed = want.split('|').contains(got);
    if (known != null && i + 1 == known.step) {
      final String fixed =
          'bug ${known.bug} no longer shows at $where: '
          'make it an ordinary step';
      if (known.cutOff) {
        expect(landed, isTrue, reason: '$where lands on $got, not $want');
        expect(problem, isNotNull, reason: fixed);
      } else {
        expect(landed, isFalse, reason: fixed);
        expect(
          got,
          known.landsOn,
          reason: 'bug ${known.bug} now goes somewhere new at $where',
        );
      }
      return;
    }
    expect(landed, isTrue, reason: '$where lands on $got, not $want');
    expect(problem, isNull, reason: '$where, on $got');
    from = got;
  }
  expect(
    known,
    isNull,
    reason: 'the known failure is past the end of the path',
  );
}

/// Sets the test view to [tvScreen] for the rest of the test.
void useTvScreen(WidgetTester tester) {
  tester.view.physicalSize = tvScreen;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
}

/// Focuses [node] and settles, to start a path there.
Future<void> focusForPath(WidgetTester tester, FocusNode node) async {
  node.requestFocus();
  await tester.pumpAndSettle();
}

/// Prints where each of [keys] lands. For working out a path, not for tests.
Future<void> probePath(
  WidgetTester tester,
  List<LogicalKeyboardKey> keys,
) async {
  final StringBuffer out = StringBuffer(
    'start ${focusedLabel()} ${FocusManager.instance.primaryFocus?.rect}\n',
  );
  for (final LogicalKeyboardKey k in keys) {
    await _press(tester, k);
    final String? problem = ringProblem(tester);
    out.writeln(
      '${k.keyLabel.padRight(11)} -> ${focusedLabel()}  '
      '${FocusManager.instance.primaryFocus?.rect}'
      '${problem == null ? '' : '  !! $problem'}',
    );
  }
  // ignore: avoid_print
  print(out);
}
