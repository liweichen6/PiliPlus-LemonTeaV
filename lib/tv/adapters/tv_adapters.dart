import 'package:PiliPlus/tv/adapters/tv_card_adapter.dart';
import 'package:PiliPlus/tv/adapters/tv_focus_adapter.dart';
import 'package:PiliPlus/tv/adapters/tv_list_tile_adapter.dart';
import 'package:PiliPlus/tv/adapters/tv_login_adapter.dart';
import 'package:PiliPlus/tv/adapters/tv_player_hud_adapter.dart';
import 'package:PiliPlus/tv/adapters/tv_popup_adapter.dart';
import 'package:PiliPlus/tv/adapters/tv_sheet_adapter.dart';

export 'package:PiliPlus/tv/adapters/tv_card_adapter.dart';
export 'package:PiliPlus/tv/adapters/tv_focus_adapter.dart';
export 'package:PiliPlus/tv/adapters/tv_list_tile_adapter.dart';
export 'package:PiliPlus/tv/adapters/tv_login_adapter.dart';
export 'package:PiliPlus/tv/adapters/tv_player_hud_adapter.dart';
export 'package:PiliPlus/tv/adapters/tv_popup_adapter.dart';
export 'package:PiliPlus/tv/adapters/tv_sheet_adapter.dart';

const TvSheetAdapter tvSheets = TvSheetAdapter();
const TvCardAdapter tvCards = TvCardAdapter();
const TvListTileAdapter tvListTiles = TvListTileAdapter();
const TvPopupAdapter tvPopups = TvPopupAdapter();
const TvPlayerHudAdapter tvPlayerHud = TvPlayerHudAdapter();
const TvLoginAdapter tvLogin = TvLoginAdapter();

/// Every adapter, for the cold hooks. The per-key and per-frame paths call the
/// adapters above by name: see [TvFocusAdapter].
const List<TvFocusAdapter> tvFocusAdapters = <TvFocusAdapter>[
  tvSheets,
  tvCards,
  tvListTiles,
  tvPopups,
  tvPlayerHud,
  tvLogin,
];
