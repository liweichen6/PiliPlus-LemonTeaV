import 'package:PiliPlus/common/widgets/flutter/list_tile.dart'
    as custom_list_tile;
import 'package:PiliPlus/tv/adapters/tv_focus_adapter.dart';
import 'package:material_ui/material_ui.dart';

/// List tiles and their trailing controls, such as a refresh `IconButton` or a
/// `Switch`: Right steps from the tile onto the control, and Left steps back.
/// Upstream keeps its own copy of `ListTile`, so a tile is either class.
final class TvListTileAdapter extends TvFocusAdapter {
  const TvListTileAdapter();

  @override
  @pragma('vm:prefer-inline')
  bool isGroup(Widget widget) =>
      widget is ListTile || widget is custom_list_tile.ListTile;

  /// Secondary when the node sits to the right of the tile's center: a trailing
  /// control, not a wrapper that fills the tile.
  @override
  @pragma('vm:prefer-inline')
  bool isSecondaryIn(Rect node, Rect container) =>
      node.center.dx > container.center.dx + 8.0;
}
