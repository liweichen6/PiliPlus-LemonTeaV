import 'package:PiliPlus/tv/adapters/tv_focus_adapter.dart';
import 'package:material_ui/material_ui.dart';

/// Cards and the actions embedded in them: an `InkResponse` is one stop for
/// Up and Down, and the buttons inside it are reached from the card, such as
/// `ReplyItemGrpc`'s 回复 / 翻译 / 查看对话 / 跳转回复 / 点踩 / 点赞, or the
/// `VideoPopupMenu` over a video card.
final class TvCardAdapter extends TvFocusAdapter {
  const TvCardAdapter();

  @override
  @pragma('vm:prefer-inline')
  bool isGroup(Widget widget) => widget is InkResponse;

  /// Whether [widget] is a button that can be embedded in a card.
  @pragma('vm:prefer-inline')
  bool isAction(Widget widget) =>
      widget is ButtonStyleButton || widget is IconButton;

  /// Secondary when the node is a small action widget (e.g. a trailing
  /// IconButton/Switch or an overlaid VideoPopupMenu) whose center lies inside
  /// a much larger primary [container] (e.g. a ListTile or VideoCard).
  @override
  @pragma('vm:prefer-inline')
  bool isSecondaryIn(Rect node, Rect container) {
    if (!container.contains(node.center)) return false;
    final bool isMicroButton = node.width <= 36.0 && node.height <= 36.0;
    return isMicroButton ||
        container.width > node.width * 1.8 ||
        container.height > node.height * 1.8;
  }

  /// Whether [rect] is small enough to be an action inside some other
  /// candidate, whatever its place in the focus tree.
  @pragma('vm:prefer-inline')
  bool isMicroAction(Rect rect) =>
      (rect.width <= 36.0 && rect.height <= 36.0) ||
      (rect.width <= 64.0 &&
          rect.height <= 64.0 &&
          rect.width * rect.height <= 2500);
}
