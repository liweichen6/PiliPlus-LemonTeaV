import 'package:PiliPlus/tv/adapters/tv_focus_adapter.dart';
import 'package:flutter/rendering.dart'
    show RenderFractionalTranslation, RenderObject;

/// The player's controls. `TvPlayerHud` builds its own, and the engine treats
/// them as any other focus nodes. What it has to know is how upstream's player
/// bars leave the screen: `AppBarAni` slides them away with a
/// `SlideTransition`, so their buttons stay mounted and laid out, off screen.
final class TvPlayerHudAdapter extends TvFocusAdapter {
  const TvPlayerHudAdapter();

  /// Whether [ancestor] has moved its child out of place. Clip and viewport
  /// bounds then apply to what is below it even inside a scrollable, where
  /// they are otherwise skipped so that a list's offscreen items stay reachable.
  @pragma('vm:prefer-inline')
  bool isSlidAway(RenderObject ancestor) =>
      ancestor is RenderFractionalTranslation &&
      (ancestor.translation.dx.abs() > 0.01 ||
          ancestor.translation.dy.abs() > 0.01);
}
