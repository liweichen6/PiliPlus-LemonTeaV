// Recorded D-pad paths (M13.3) for the home grid with the rail, 我的 and its
// rail, the user page, settings with their dialogs, and 稍后再看. The paths
// for the video page (split view, comments and the player HUD) are in
// `tv_player_hud_test.dart`, which has the player's fakes. How a path is
// replayed, and what a known failure is, is in `tv_path_harness.dart`.
//
// The real pages need GetX controllers, Hive and the network, so each scene
// copies its page's layout at the TV's logical size, using the same containers
// where that's cheap: `NavigationRail`, the scrollable `TabBar`,
// `ExtendedNestedScrollView`, `SimpleScaffold`, upstream's `ListTile` and
// `iconButton`, `SelectDialog`, `SliderDialog` and the home grid's delegate.
import 'package:PiliPlus/common/widgets/flutter/list_tile.dart' as upstream;
import 'package:PiliPlus/common/widgets/scaffold/simple_scaffold.dart';
import 'package:PiliPlus/pages/setting/widgets/select_dialog.dart';
import 'package:PiliPlus/pages/setting/widgets/slider_dialog.dart';
import 'package:PiliPlus/tv/tv_navigation.dart';
import 'package:PiliPlus/tv/tv_platform.dart';
import 'package:PiliPlus/utils/grid.dart'
    show SliverGridDelegateWithExtentAndRatio;
import 'package:extended_nested_scroll_view/extended_nested_scroll_view.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import 'tv_path_harness.dart';

/// Focuses the framework-made node that shows [text], such as a rail
/// destination or a tab.
Future<void> _focusText(WidgetTester tester, String text) async {
  Focus.of(tester.element(find.text(text).last)).requestFocus();
  await tester.pumpAndSettle();
}

Widget _app(Widget home) => MaterialApp(
  navigatorObservers: [TvNavigationObserver()],
  builder: (context, child) => TvNavigation(child: child!),
  home: home,
);

// ---------------------------------------------------------------------------
// The main shell: `NavigationRail` with the avatar, the bell and search above
// its destinations, as `MainApp._sideBar` builds it with `useSideBar` on.

class _Rail {
  _Rail()
    : avatar = pathNode('avatar'),
      bell = pathNode('bell'),
      search = pathNode('search');

  final FocusNode avatar;
  final FocusNode bell;
  final FocusNode search;

  Widget build({required int selected, required Widget body}) {
    return Scaffold(
      body: Row(
        children: [
          NavigationRail(
            groupAlignment: 0.5,
            labelType: NavigationRailLabelType.selected,
            backgroundColor: Colors.transparent,
            leading: Column(
              children: [
                // Signed in: a 34×34 avatar with an `InkWell` laid over it.
                SizedBox(
                  width: 34,
                  height: 34,
                  child: Material(
                    type: MaterialType.transparency,
                    child: InkWell(
                      focusNode: avatar,
                      onTap: () {},
                      customBorder: const CircleBorder(),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                IconButton(
                  focusNode: bell,
                  tooltip: '消息',
                  onPressed: () {},
                  icon: const Icon(Icons.notifications_none),
                ),
                IconButton(
                  focusNode: search,
                  tooltip: '搜索',
                  onPressed: () {},
                  icon: const Icon(Icons.search_outlined),
                ),
              ],
            ),
            selectedIndex: selected,
            onDestinationSelected: (_) {},
            destinations: const [
              NavigationRailDestination(
                icon: Icon(Icons.home_outlined),
                label: Text('首页'),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.motion_photos_on_outlined),
                label: Text('动态'),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.person_outline),
                label: Text('我的'),
              ),
            ],
          ),
          Expanded(child: body),
        ],
      ),
    );
  }
}

/// `VideoCardV`: an `InkWell` in a `Card`, with the `⋮` laid beside it in a
/// `Stack`, not inside the `InkWell`.
Widget _videoCardV(FocusNode card, FocusNode menu, String title) => Stack(
  clipBehavior: Clip.none,
  children: [
    Card(
      child: InkWell(
        focusNode: card,
        onTap: () {},
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const AspectRatio(aspectRatio: 16 / 10, child: Placeholder()),
            Expanded(child: Text(title)),
          ],
        ),
      ),
    ),
    Positioned(
      right: -5,
      bottom: -2,
      width: 29,
      height: 29,
      child: IconButton(
        focusNode: menu,
        padding: EdgeInsets.zero,
        iconSize: 17,
        onPressed: () {},
        icon: const Icon(Icons.more_vert_outlined),
      ),
    ),
  ],
);

// ---------------------------------------------------------------------------
// Home: the tab bar over the 推荐 grid, as `HomePage` and `RcmdPage` build
// them, with three columns of cards at the TV's `recommendCardWidth`.

const List<String> _homeTabs = <String>['直播', '推荐', '热门', '番剧', '影视'];

class _HomeScene {
  _HomeScene()
    : rail = _Rail(),
      grid = ScrollController(),
      cards = List<FocusNode>.generate(
        30,
        (i) => pathNode('card ${i ~/ 3}.${i % 3}'),
      ),
      menus = List<FocusNode>.generate(
        30,
        (i) => pathNode('⋮ ${i ~/ 3}.${i % 3}'),
      ) {
    addTearDown(grid.dispose);
  }

  final _Rail rail;
  final ScrollController grid;
  final List<FocusNode> cards;
  final List<FocusNode> menus;

  FocusNode card(int row, int column) => cards[row * 3 + column];

  Widget build() => DefaultTabController(
    length: _homeTabs.length,
    initialIndex: 1,
    child: rail.build(
      selected: 0,
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: SizedBox(
              height: 42,
              width: double.infinity,
              child: TabBar(
                isScrollable: true,
                tabAlignment: TabAlignment.center,
                dividerHeight: 0,
                tabs: [for (final String t in _homeTabs) Tab(text: t)],
              ),
            ),
          ),
          Expanded(
            child: TabBarView(
              children: [
                for (final String t in _homeTabs)
                  t == '推荐'
                      ? CustomScrollView(
                          controller: grid,
                          slivers: [
                            SliverPadding(
                              padding: const EdgeInsets.fromLTRB(
                                12,
                                8,
                                12,
                                100,
                              ),
                              sliver: SliverGrid.builder(
                                gridDelegate:
                                    SliverGridDelegateWithExtentAndRatio(
                                      mainAxisSpacing: 8,
                                      crossAxisSpacing: 8,
                                      maxCrossAxisExtent: 300,
                                      childAspectRatio: 16 / 10,
                                      mainAxisExtent: 90,
                                    ),
                                itemCount: cards.length,
                                itemBuilder: (context, i) => _videoCardV(
                                  cards[i],
                                  menus[i],
                                  'video $i',
                                ),
                              ),
                            ),
                          ],
                        )
                      : Center(child: Text('$t page')),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}

// ---------------------------------------------------------------------------
// 我的: the header's buttons over one list holding the user card, the four
// shortcuts and each `我的页卡片` section (a `ListTile` header with a refresh
// button over a horizontal list), as `MinePage` builds it.

const List<String> _mineSections = <String>['收藏', '观看记录', '稍后再看', '我的订阅'];

class _MineScene {
  _MineScene()
    : rail = _Rail(),
      page = ScrollController(),
      rows = List<ScrollController>.generate(4, (_) => ScrollController()),
      headerButtons = List<FocusNode>.generate(
        4,
        (i) => pathNode('header ${i + 1}'),
      ),
      user = pathNode('user card'),
      shortcuts = List<FocusNode>.generate(
        4,
        (i) => pathNode('shortcut ${i + 1}'),
      ),
      headers = [for (final String t in _mineSections) pathNode(t)],
      refresh = [for (final String t in _mineSections) pathNode('刷新 $t')],
      items = [
        for (final String t in _mineSections)
          List<FocusNode>.generate(10, (i) => pathNode('$t $i')),
      ] {
    addTearDown(page.dispose);
    for (final ScrollController c in rows) {
      addTearDown(c.dispose);
    }
  }

  final _Rail rail;
  final ScrollController page;
  final List<ScrollController> rows;
  final List<FocusNode> headerButtons;
  final FocusNode user;
  final List<FocusNode> shortcuts;
  final List<FocusNode> headers;
  final List<FocusNode> refresh;
  final List<List<FocusNode>> items;

  Widget _section(int s) => Column(
    children: [
      const Divider(height: 20),
      ListTile(
        focusNode: headers[s],
        dense: true,
        onTap: () {},
        title: Text(_mineSections[s]),
        trailing: IconButton(
          focusNode: refresh[s],
          tooltip: '刷新',
          onPressed: () {},
          icon: const Icon(Icons.refresh, size: 20),
        ),
      ),
      SizedBox(
        height: 180,
        child: ListView.separated(
          controller: rows[s],
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.only(left: 20, top: 10, right: 20),
          itemCount: items[s].length,
          separatorBuilder: (_, _) => const SizedBox(width: 14),
          itemBuilder: (context, i) => SizedBox(
            width: 180,
            child: InkWell(
              focusNode: items[s][i],
              onTap: () {},
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const AspectRatio(aspectRatio: 16 / 10, child: Placeholder()),
                  Text('${_mineSections[s]} $i'),
                ],
              ),
            ),
          ),
        ),
      ),
    ],
  );

  Widget build() => rail.build(
    selected: 2,
    body: Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              for (final FocusNode b in headerButtons)
                IconButton(
                  focusNode: b,
                  onPressed: () {},
                  icon: const Icon(Icons.settings_outlined),
                ),
              const SizedBox(width: 16),
            ],
          ),
        ),
        Expanded(
          child: ListView(
            controller: page,
            padding: const EdgeInsets.only(bottom: 150),
            children: [
              InkWell(
                focusNode: user,
                onTap: () {},
                child: const SizedBox(height: 110, child: Text('user')),
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  for (final FocusNode n in shortcuts)
                    Flexible(
                      child: InkWell(
                        focusNode: n,
                        onTap: () {},
                        child: const SizedBox.square(dimension: 80),
                      ),
                    ),
                ],
              ),
              for (int s = 0; s < _mineSections.length; s++) _section(s),
            ],
          ),
        ),
      ],
    ),
  );
}

// ---------------------------------------------------------------------------
// The user page: `ExtendedNestedScrollView` with the user card (`编辑资料`)
// in a pinned `SliverAppBar`, and the tab bar over the tabs' lists in its
// body, as `MemberPage` builds it.

const List<String> _memberTabs = <String>['主页', '动态', '投稿', '收藏'];

class _MemberScene {
  _MemberScene()
    : search = pathNode('搜索'),
      more = pathNode('更多'),
      edit = pathNode('编辑资料'),
      rows = List<FocusNode>.generate(12, (i) => pathNode('row $i'));

  final FocusNode search;
  final FocusNode more;
  final FocusNode edit;
  final List<FocusNode> rows;

  Widget build() => DefaultTabController(
    length: _memberTabs.length,
    initialIndex: 2,
    child: Scaffold(
      body: ExtendedNestedScrollView(
        onlyOneScrollInBody: true,
        pinnedHeaderSliverHeightBuilder: () => kToolbarHeight,
        headerSliverBuilder: (context, innerBoxIsScrolled) => [
          SliverAppBar(
            pinned: true,
            expandedHeight: 220,
            title: const Text('user'),
            actions: [
              IconButton(
                focusNode: search,
                onPressed: () {},
                icon: const Icon(Icons.search),
              ),
              IconButton(
                focusNode: more,
                onPressed: () {},
                icon: const Icon(Icons.more_vert),
              ),
            ],
            flexibleSpace: FlexibleSpaceBar(
              background: Padding(
                padding: const EdgeInsets.only(top: kToolbarHeight + 20),
                child: Align(
                  alignment: Alignment.topRight,
                  child: Padding(
                    padding: const EdgeInsets.only(right: 20),
                    child: FilledButton.tonal(
                      focusNode: edit,
                      onPressed: () {},
                      child: const Text('编辑资料'),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
        body: Column(
          children: [
            SizedBox(
              height: 45,
              child: TabBar(
                labelPadding: EdgeInsets.zero,
                tabs: [for (final String t in _memberTabs) Tab(text: t)],
              ),
            ),
            Expanded(
              child: TabBarView(
                children: [
                  for (final String t in _memberTabs)
                    t == '投稿'
                        ? CustomScrollView(
                            slivers: [
                              SliverList.builder(
                                itemCount: rows.length,
                                itemBuilder: (context, i) => SizedBox(
                                  height: 110,
                                  child: InkWell(
                                    focusNode: rows[i],
                                    onTap: () {},
                                    child: Text('video $i'),
                                  ),
                                ),
                              ),
                            ],
                          )
                        : Center(child: Text('$t page')),
                ],
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

// ---------------------------------------------------------------------------
// Settings in landscape: the categories on the left and the chosen page's
// tiles on the right, as `SettingPage` and `CommonSetting` build them, with
// upstream's `ListTile`, a switch, `SelectDialog` and `SliderDialog`.

const List<String> _settingCategories = <String>[
  '隐私设置',
  '推荐流设置',
  '音视频设置',
  '播放器设置',
  '外观设置',
  '其它设置',
  '关于',
];

class _SettingsScene {
  _SettingsScene()
    : searchItem = pathNode('搜索设置'),
      categories = [for (final String c in _settingCategories) pathNode(c)],
      tiles = List<FocusNode>.generate(10, (i) => pathNode('tile $i'));

  final FocusNode searchItem;
  final List<FocusNode> categories;
  final List<FocusNode> tiles;
  bool on = false;

  Widget _tile(BuildContext context, int i) {
    final String title = 'tile $i';
    return switch (i) {
      1 => upstream.ListTile(
        focusNode: tiles[i],
        onTap: () {},
        title: Text(title),
        subtitle: const Text('a switch'),
        trailing: StatefulBuilder(
          builder: (context, setState) => Switch(
            value: on,
            onChanged: (v) => setState(() => on = v),
          ),
        ),
      ),
      2 => upstream.ListTile(
        focusNode: tiles[i],
        onTap: () => showDialog<int>(
          context: context,
          builder: (_) => const SelectDialog<int>(
            title: '默认画质',
            value: 120,
            values: [
              (120, '4K'),
              (116, '1080P60'),
              (80, '1080P'),
              (64, '720P'),
            ],
          ),
        ),
        title: Text(title),
        subtitle: const Text('a select dialog'),
      ),
      3 => upstream.ListTile(
        focusNode: tiles[i],
        onTap: () => showDialog<double>(
          context: context,
          builder: (_) => const SliderDialog(
            title: Text('图片质量'),
            value: 50,
            min: 1,
            max: 100,
            divisions: 99,
            precise: 0,
            suffix: '%',
          ),
        ),
        title: Text(title),
        subtitle: const Text('a slider dialog'),
      ),
      _ => upstream.ListTile(
        focusNode: tiles[i],
        onTap: () {},
        title: Text(title),
        subtitle: const Text('a setting'),
      ),
    };
  }

  Widget build() => SimpleScaffold(
    appBar: AppBar(title: const Text('音视频设置')),
    body: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          flex: 4,
          child: ListView(
            padding: const EdgeInsets.only(bottom: 100),
            children: [
              upstream.ListTile(
                focusNode: searchItem,
                onTap: () {},
                leading: const Icon(Icons.search),
                title: const Text('搜索设置'),
              ),
              for (int i = 0; i < _settingCategories.length; i++)
                upstream.ListTile(
                  focusNode: categories[i],
                  onTap: () {},
                  leading: const Icon(Icons.settings),
                  title: Text(_settingCategories[i]),
                  subtitle: const Text('a category'),
                ),
            ],
          ),
        ),
        const VerticalDivider(width: 1),
        Expanded(
          flex: 6,
          child: Builder(
            builder: (context) => ListView(
              children: [
                for (int i = 0; i < tiles.length; i++) _tile(context, i),
              ],
            ),
          ),
        ),
      ],
    ),
  );
}

// ---------------------------------------------------------------------------
// 稍后再看: two columns of `VideoCardHLater`, each with a `×` (upstream's
// `iconButton`) inside the card's `InkWell`, under a floating `播放全部`, as
// `LaterPage` builds them in `SimpleScaffold`.

class _LaterScene {
  _LaterScene()
    : grid = ScrollController(),
      cards = List<FocusNode>.generate(
        12,
        (i) => pathNode('card ${i ~/ 2}.${i % 2}'),
      ),
      removes = List<FocusNode>.generate(
        12,
        (i) => pathNode('× ${i ~/ 2}.${i % 2}'),
      ),
      playAll = pathNode('播放全部') {
    addTearDown(grid.dispose);
  }

  final ScrollController grid;
  final List<FocusNode> cards;
  final List<FocusNode> removes;
  final FocusNode playAll;

  FocusNode card(int row, int column) => cards[row * 2 + column];
  FocusNode remove(int row, int column) => removes[row * 2 + column];

  Widget _card(int i) => Material(
    type: MaterialType.transparency,
    child: InkWell(
      focusNode: cards[i],
      onTap: () {},
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const AspectRatio(aspectRatio: 16 / 10, child: Placeholder()),
            const SizedBox(width: 10),
            Expanded(
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('video $i'),
                      const Spacer(),
                      const Text('stat'),
                    ],
                  ),
                  Positioned(
                    right: 0,
                    bottom: -8,
                    // Upstream's `iconButton`, given a focus node to name it.
                    child: SizedBox(
                      width: 36,
                      height: 36,
                      child: IconButton(
                        focusNode: removes[i],
                        tooltip: '移除',
                        style: IconButton.styleFrom(padding: EdgeInsets.zero),
                        onPressed: () {},
                        icon: const Icon(Icons.clear),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    ),
  );

  Widget build() => DefaultTabController(
    length: 2,
    child: SimpleScaffold(
      appBar: AppBar(title: const Text('稍后再看')),
      fab: Padding(
        padding: const EdgeInsets.only(
          right: kFloatingActionButtonMargin,
          bottom: kFloatingActionButtonMargin,
        ),
        child: FloatingActionButton.extended(
          focusNode: playAll,
          onPressed: () {},
          label: const Text('播放全部'),
          icon: const Icon(Icons.playlist_play),
        ),
      ),
      body: Column(
        children: [
          const TabBar(
            tabs: [
              Tab(text: '全部'),
              Tab(text: '未看完'),
            ],
          ),
          Expanded(
            child: TabBarView(
              children: [
                CustomScrollView(
                  controller: grid,
                  slivers: [
                    SliverPadding(
                      padding: const EdgeInsets.only(top: 7, bottom: 80),
                      sliver: SliverGrid.builder(
                        gridDelegate:
                            const SliverGridDelegateWithMaxCrossAxisExtent(
                              mainAxisSpacing: 2,
                              mainAxisExtent: 110,
                              maxCrossAxisExtent: 480,
                            ),
                        itemCount: cards.length,
                        itemBuilder: (context, i) => _card(i),
                      ),
                    ),
                  ],
                ),
                const Center(child: Text('未看完 page')),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}

Future<void> _pump(WidgetTester tester, Widget home) async {
  useTvScreen(tester);
  await tester.pumpWidget(_app(home));
  await tester.pumpAndSettle();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => TvPlatform.setTvModeForTesting(true));
  tearDown(() => TvPlatform.setTvModeForTesting(false));

  group('home grid with the rail (M13.3)', () {
    testWidgets('Right and Left step one column, Down and Up one row, and '
        'Left from the first column reaches the rail', (tester) async {
      final _HomeScene s = _HomeScene();
      await _pump(tester, s.build());
      await focusForPath(tester, s.card(0, 0));
      await walkPath(tester, 'card 0.0', [
        (dpadRight, 'card 0.1'),
        (dpadRight, 'card 0.2'),
        (dpadRight, 'card 0.2'),
        (dpadDown, 'card 1.2'),
        (dpadDown, 'card 2.2'),
        (dpadDown, 'card 3.2'),
        (dpadLeft, 'card 3.1'),
        (dpadLeft, 'card 3.0'),
        (dpadLeft, '动态'),
        (dpadRight, 'card 3.0'),
        (dpadUp, 'card 2.0'),
        (dpadUp, 'card 1.0'),
        (dpadUp, 'card 0.0'),
        (dpadUp, '直播'),
      ]);
    });

    testWidgets('the rail steps one item at a time from 首页 to the avatar '
        'and back', (tester) async {
      final _HomeScene s = _HomeScene();
      await _pump(tester, s.build());
      await _focusText(tester, '首页');
      await walkPath(tester, '首页', [
        (dpadUp, 'search'),
        (dpadUp, 'bell'),
        (dpadUp, 'avatar'),
        (dpadUp, 'avatar'),
        (dpadDown, 'bell'),
        (dpadDown, 'search'),
        (dpadDown, '首页'),
        (dpadDown, '动态'),
        (dpadDown, '我的'),
      ]);
    });

    // The grid scrolled so that its third row is 16 px under the tab bar.
    Future<_HomeScene> cutOffRow(WidgetTester tester, int column) async {
      final _HomeScene s = _HomeScene();
      await _pump(tester, s.build());
      await focusForPath(tester, s.card(2, column));
      s.grid.jumpTo(574);
      await tester.pumpAndSettle();
      return s;
    }

    testWidgets('[known failure: bug 8] Right from a card cut off by the tab '
        'bar steps to the next card, not onto a tab', (tester) async {
      await cutOffRow(tester, 0);
      await walkPath(tester, 'card 2.0', [
        (dpadRight, 'card 2.1'),
      ], known: const KnownFailure(bug: 8, step: 1, landsOn: '直播'));
    });

    testWidgets('[known failure: bug 8] Left from a card cut off by the tab '
        'bar steps to the next card, not onto a tab', (tester) async {
      await cutOffRow(tester, 2);
      await walkPath(tester, 'card 2.2', [
        (dpadLeft, 'card 2.1'),
      ], known: const KnownFailure(bug: 8, step: 1, landsOn: '影视'));
    });

    testWidgets('[known failure: bug 10] Right onto a card cut off by the '
        'tab bar scrolls the grid to show it', (tester) async {
      await cutOffRow(tester, 1);
      await walkPath(tester, 'card 2.1', [
        (dpadRight, 'card 2.2'),
      ], known: const KnownFailure.cutOff(bug: 10, step: 1));
    });

    testWidgets('[known failure: bug 10] Left onto a card cut off by the '
        'bottom edge scrolls the grid to show it', (tester) async {
      final _HomeScene s = _HomeScene();
      await _pump(tester, s.build());
      await focusForPath(tester, s.card(1, 1));
      s.grid.jumpTo(0);
      await tester.pumpAndSettle();
      await walkPath(tester, 'card 1.1', [
        (dpadLeft, 'card 1.0'),
      ], known: const KnownFailure.cutOff(bug: 10, step: 1));
    });

    testWidgets('[known failure: bug 9] Down from a tab returns to the card '
        'focus left the grid from', (tester) async {
      final _HomeScene s = _HomeScene();
      await _pump(tester, s.build());
      await focusForPath(tester, s.card(0, 1));
      await walkPath(tester, 'card 0.1', [
        // Every tab is over this card, so any of them is right.
        (dpadUp, _homeTabs.join('|')),
        (dpadDown, 'card 0.1'),
      ], known: const KnownFailure(bug: 9, step: 2, landsOn: 'card 0.0'));
    });

    testWidgets('[known failure: bug 9] Down from a tab, with no card to '
        'return to, lands on the card under the tab', (tester) async {
      final _HomeScene s = _HomeScene();
      await _pump(tester, s.build());
      await _focusText(tester, '热门');
      await walkPath(tester, '热门', [
        (dpadDown, 'card 0.1'),
      ], known: const KnownFailure(bug: 9, step: 1, landsOn: 'card 0.0'));
    });
  });

  group('我的 with all four sections (M13.3)', () {
    testWidgets('Down and Up walk every section as the page scrolls '
        '(bug 1, fixed in M13.0a)', (tester) async {
      final _MineScene s = _MineScene();
      await _pump(tester, s.build());
      await _focusText(tester, '我的');
      await walkPath(tester, '我的', [
        (dpadRight, '收藏 0'),
        (dpadDown, '观看记录'),
        (dpadDown, '观看记录 0'),
        (dpadDown, '稍后再看'),
        (dpadDown, '稍后再看 0'),
        (dpadDown, '我的订阅'),
        (dpadDown, '我的订阅 0'),
        (dpadDown, '我的订阅 0'),
        (dpadUp, '我的订阅'),
        (dpadUp, '稍后再看 0'),
        (dpadUp, '稍后再看'),
        (dpadUp, '观看记录 0'),
        (dpadUp, '观看记录'),
        (dpadUp, '收藏 0'),
        (dpadUp, '收藏'),
        (dpadUp, 'shortcut 1'),
        (dpadUp, 'user card'),
      ]);
    });

    testWidgets('Right walks a row to its end, keeping each card in view '
        '(bug 5, fixed in M13.0b)', (tester) async {
      final _MineScene s = _MineScene();
      await _pump(tester, s.build());
      await focusForPath(tester, s.items[1][0]);
      await walkPath(tester, '观看记录 0', [
        for (int i = 1; i < 10; i++) (dpadRight, '观看记录 $i'),
        (dpadRight, '观看记录 9'),
        for (int i = 8; i >= 0; i--) (dpadLeft, '观看记录 $i'),
      ]);
    });

    testWidgets('[known failure: bug 7] with a row scrolled sideways, the '
        'rail steps one item at a time from 首页 to the avatar', (
      tester,
    ) async {
      final _MineScene s = _MineScene();
      await _pump(tester, s.build());
      await _focusText(tester, '我的');
      await walkPath(
        tester,
        '我的',
        [
          (dpadRight, '收藏 0'),
          (dpadDown, '观看记录'),
          (dpadDown, '观看记录 0'),
          for (int i = 1; i <= 5; i++) (dpadRight, '观看记录 $i'),
          (dpadDown, '稍后再看'),
          (dpadDown, '稍后再看 0'),
          (dpadLeft, '我的'),
          (dpadUp, '动态'),
          (dpadUp, '首页'),
          (dpadUp, 'search'),
          (dpadUp, 'bell'),
          (dpadUp, 'avatar'),
        ],
        known: const KnownFailure(bug: 7, step: 14, landsOn: 'bell'),
      );
    });
  });

  group('user page (M13.3)', () {
    testWidgets('[known failure: bug 6] Up from the first row of a tab '
        'reaches the tabs, then 编辑资料', (tester) async {
      final _MemberScene s = _MemberScene();
      await _pump(tester, s.build());
      await focusForPath(tester, s.edit);
      await walkPath(
        tester,
        '编辑资料',
        [
          (dpadDown, '收藏'),
          (dpadDown, 'row 0'),
          (dpadDown, 'row 1'),
          (dpadUp, 'row 0'),
          // The tab focus left from, or the tab that's showing.
          (dpadUp, '收藏|投稿'),
          (dpadUp, '编辑资料'),
        ],
        known: const KnownFailure(bug: 6, step: 5, landsOn: 'row 0'),
      );
    });

    testWidgets('Down and Up walk a tab\'s list as the header folds away', (
      tester,
    ) async {
      final _MemberScene s = _MemberScene();
      await _pump(tester, s.build());
      await focusForPath(tester, s.rows[0]);
      await walkPath(tester, 'row 0', [
        for (int i = 1; i < 7; i++) (dpadDown, 'row $i'),
        for (int i = 5; i >= 0; i--) (dpadUp, 'row $i'),
      ]);
    });
  });

  group('settings with their dialogs (M13.3)', () {
    testWidgets('[known failure: bug 9] Right enters the page beside the '
        'categories, and Left returns to the category it came from', (
      tester,
    ) async {
      final _SettingsScene s = _SettingsScene();
      await _pump(tester, s.build());
      await focusForPath(tester, s.categories[2]);
      await walkPath(
        tester,
        '音视频设置',
        [
          (dpadRight, 'tile 3'),
          (dpadUp, 'tile 2'),
          (dpadUp, 'tile 1'),
          (dpadRight, 'Switch'),
          (dpadLeft, 'tile 1'),
          (dpadLeft, '音视频设置'),
        ],
        known: const KnownFailure(bug: 9, step: 6, landsOn: '隐私设置'),
      );
    });

    testWidgets('the categories walk from end to end', (tester) async {
      final _SettingsScene s = _SettingsScene();
      await _pump(tester, s.build());
      await focusForPath(tester, s.searchItem);
      await walkPath(tester, '搜索设置', [
        for (final String c in _settingCategories) (dpadDown, c),
        (dpadDown, '关于'),
        for (final String c in _settingCategories.reversed.skip(1)) (dpadUp, c),
        (dpadUp, '搜索设置'),
      ]);
    });

    testWidgets('a select dialog takes focus, moves inside, and Back '
        'returns to its tile', (tester) async {
      final _SettingsScene s = _SettingsScene();
      await _pump(tester, s.build());
      await focusForPath(tester, s.tiles[2]);
      await walkPath(tester, 'tile 2', [
        (dpadSelect, '4K'),
        (dpadDown, '1080P60'),
        (dpadDown, '1080P'),
        (dpadDown, '720P'),
        (dpadDown, '720P'),
        (dpadUp, '1080P'),
        (dpadBack, 'tile 2'),
        (dpadDown, 'tile 3'),
      ]);
    });

    testWidgets('a slider dialog: Down reaches its buttons, and Back '
        'returns to its tile', (tester) async {
      final _SettingsScene s = _SettingsScene();
      await _pump(tester, s.build());
      await focusForPath(tester, s.tiles[3]);
      await walkPath(tester, 'tile 3', [
        (dpadSelect, 'Slider'),
        (dpadRight, 'Slider'),
        (dpadDown, '取消'),
        (dpadRight, '确定'),
        (dpadLeft, '取消'),
        (dpadUp, 'Slider'),
        (dpadBack, 'tile 3'),
        (dpadUp, 'tile 2'),
      ]);
    });
  });

  group('稍后再看 (M13.3)', () {
    testWidgets('Up and Down keep to a column, and Right reaches a card\'s ×', (
      tester,
    ) async {
      final _LaterScene s = _LaterScene();
      await _pump(tester, s.build());
      await focusForPath(tester, s.card(0, 0));
      await walkPath(tester, 'card 0.0', [
        (dpadRight, 'card 0.1'),
        (dpadRight, '× 0.1'),
        (dpadDown, 'card 1.1'),
        (dpadDown, 'card 2.1'),
        (dpadLeft, 'card 2.0'),
        (dpadUp, 'card 1.0'),
        (dpadUp, 'card 0.0'),
        (dpadUp, '全部'),
      ]);
    });

    testWidgets('[known failure: bug 4] Up from a × in the right column '
        'stays in that column', (tester) async {
      final _LaterScene s = _LaterScene();
      await _pump(tester, s.build());
      await focusForPath(tester, s.remove(1, 1));
      await walkPath(tester, '× 1.1', [
        (dpadUp, '× 0.1|card 0.1'),
      ], known: const KnownFailure(bug: 4, step: 1, landsOn: 'card 1.0'));
    });

    testWidgets('[known failure: bug 2] Down from the last card reaches '
        '播放全部', (tester) async {
      final _LaterScene s = _LaterScene();
      await _pump(tester, s.build());
      await focusForPath(tester, s.card(0, 1));
      await walkPath(
        tester,
        'card 0.1',
        [
          for (int r = 1; r < 6; r++) (dpadDown, 'card $r.1'),
          (dpadDown, '播放全部'),
        ],
        known: const KnownFailure(bug: 2, step: 6, landsOn: 'card 5.1'),
      );
    });
  });

  group('scorer and column memory (M13.4)', () {
    late TvFocusScorer before;
    setUp(() {
      before = TvFocusTraversalPolicy.scorer;
      TvFocusTraversalPolicy.scorer = TvFocusScorer.scored;
    });
    tearDown(() => TvFocusTraversalPolicy.scorer = before);

    testWidgets('the flag picks the rules while the app runs', (
      tester,
    ) async {
      final _HomeScene s = _HomeScene();
      await _pump(tester, s.build());

      TvFocusTraversalPolicy.scorer = TvFocusScorer.rules;
      await focusForPath(tester, s.card(0, 2));
      await walkPath(tester, 'card 0.2', [
        (dpadUp, _homeTabs.join('|')),
        (dpadDown, 'card 0.0'),
      ]);

      TvFocusTraversalPolicy.scorer = TvFocusScorer.scored;
      await focusForPath(tester, s.card(0, 2));
      await walkPath(tester, 'card 0.2', [
        (dpadUp, _homeTabs.join('|')),
        (dpadDown, 'card 0.2'),
      ]);
    });

    testWidgets('moving along the tabs keeps the grid\'s memory', (
      tester,
    ) async {
      final _HomeScene s = _HomeScene();
      await _pump(tester, s.build());
      await focusForPath(tester, s.card(1, 2));
      await walkPath(tester, 'card 1.2', [
        (dpadUp, 'card 0.2'),
        (dpadUp, _homeTabs.join('|')),
      ]);
      final String tab = focusedLabel();
      await walkPath(tester, tab, [
        (dpadLeft, _homeTabs.join('|')),
        (dpadRight, tab),
        (dpadDown, 'card 0.2'),
      ]);
    });

    testWidgets('memory is skipped once the card it holds is scrolled out of '
        'view', (tester) async {
      final _HomeScene s = _HomeScene();
      await _pump(tester, s.build());
      await focusForPath(tester, s.card(0, 2));
      await walkPath(tester, 'card 0.2', [(dpadUp, _homeTabs.join('|'))]);
      s.grid.jumpTo(820);
      await tester.pumpAndSettle();
      await tester.sendKeyEvent(dpadDown);
      await tester.pumpAndSettle();
      expect(focusedLabel(), startsWith('card '));
      expect(focusedLabel(), isNot('card 0.2'));
      expect(ringProblem(tester), isNull);
    });

    testWidgets('Left returns to the category focus left from, after moving '
        'down the page beside it', (tester) async {
      final _SettingsScene s = _SettingsScene();
      await _pump(tester, s.build());
      await focusForPath(tester, s.categories[4]);
      await tester.sendKeyEvent(dpadRight);
      await tester.pumpAndSettle();
      expect(focusedLabel(), startsWith('tile '));
      final String entered = focusedLabel();
      await walkPath(tester, entered, [
        (dpadDown, 'tile ${int.parse(entered.substring(5)) + 1}'),
        (dpadDown, 'tile ${int.parse(entered.substring(5)) + 2}'),
        (dpadLeft, '外观设置'),
      ]);
    });

    testWidgets('Up from a tab\'s list returns to the tab focus came from, '
        'in a tab bar that is not a list', (tester) async {
      final _MemberScene s = _MemberScene();
      await _pump(tester, s.build());
      await _focusText(tester, '动态');
      await walkPath(tester, '动态', [
        (dpadDown, 'row 0'),
        (dpadUp, '动态'),
      ]);
    });

    testWidgets('the debug overlay shows each candidate\'s score', (
      tester,
    ) async {
      TvFocusTraversalPolicy.debugRecordScores = true;
      addTearDown(() {
        TvFocusTraversalPolicy.debugRecordScores = false;
        TvFocusTraversalPolicy.debugLastDecision.value = null;
      });
      final _HomeScene s = _HomeScene();
      await _pump(tester, s.build());
      await focusForPath(tester, s.card(0, 0));
      await walkPath(tester, 'card 0.0', [(dpadRight, 'card 0.1')]);

      final TvFocusDecision? d = TvFocusTraversalPolicy.debugLastDecision.value;
      expect(d, isNotNull);
      expect(d!.chosen, s.card(0, 1));
      expect(d.fromMemory, isFalse);
      final List<TvFocusScore> scored = [
        for (final TvFocusScore e in d.scores)
          if (e.score != null) e,
      ]..sort((a, b) => a.score!.compareTo(b.score!));
      expect(scored.first.node, s.card(0, 1));
      expect(
        d.scores.where((e) => e.node == s.card(1, 0)).single.dropped,
        'dir',
      );
      expect(
        d.scores.where((e) => e.node == s.menus[1]).single.dropped,
        'sec',
      );
      expect(
        find.byWidgetPredicate(
          (w) =>
              w is CustomPaint &&
              w.painter.runtimeType.toString() == '_TvScoreOverlayPainter',
        ),
        findsOneWidget,
      );
    });

    testWidgets('a list nested in the focused list is entered in order, not '
        'passed over like a floating button', (tester) async {
      final FocusNode above = pathNode('above');
      final FocusNode below = pathNode('below');
      final List<FocusNode> inner = List<FocusNode>.generate(
        4,
        (i) => pathNode('inner $i'),
      );
      Widget button(FocusNode node) => SizedBox(
        height: 60,
        child: InkWell(
          focusNode: node,
          onTap: () {},
          child: Text(node.debugLabel!),
        ),
      );
      await _pump(
        tester,
        Scaffold(
          body: ListView(
            children: [
              button(above),
              SizedBox(
                height: 200,
                child: ListView(
                  children: [for (final FocusNode n in inner) button(n)],
                ),
              ),
              button(below),
            ],
          ),
        ),
      );
      await focusForPath(tester, above);
      await walkPath(tester, 'above', [
        (dpadDown, 'inner 0'),
        (dpadDown, 'inner 1'),
        (dpadDown, 'inner 2'),
        (dpadDown, 'inner 3'),
        (dpadDown, 'below'),
        (dpadUp, 'inner 3'),
      ]);
    });

    testWidgets('the rail keeps no memory: Left from the grid lands level '
        'with the card, not on the avatar focus left the rail from', (
      tester,
    ) async {
      final _HomeScene s = _HomeScene();
      await _pump(tester, s.build());
      await focusForPath(tester, s.rail.avatar);
      await tester.sendKeyEvent(dpadRight);
      await tester.pumpAndSettle();
      expect(focusedLabel(), isNot('avatar'));
      await focusForPath(tester, s.card(1, 0));
      await walkPath(tester, 'card 1.0', [(dpadLeft, '首页|动态|我的')]);
    });
  });
}
