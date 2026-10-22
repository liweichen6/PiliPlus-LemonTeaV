import 'dart:io';

import 'package:PiliPlus/models/common/theme/theme_type.dart';
import 'package:PiliPlus/plugin/pl_player/models/fullscreen_mode.dart';
import 'package:PiliPlus/tv/tv_navigation.dart';
import 'package:PiliPlus/tv/tv_platform.dart';
import 'package:PiliPlus/utils/storage_key.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive.dart';
import 'package:material_ui/material_ui.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('TvPlatform Hive default seeding', () {
    late Directory tempDir;
    late Box<dynamic> box;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('pili_tv_test_');
      Hive.init(tempDir.path);
      box = await Hive.openBox<dynamic>('tv_setting_test');
    });

    tearDown(() async {
      await box.close();
      await Hive.close();
      if (tempDir.existsSync()) {
        await tempDir.delete(recursive: true);
      }
    });

    test('seeds TV-optimal defaults on first run and is idempotent', () async {
      await TvPlatform.seedTvDefaultsToBox(box);
      expect(box.get('tvDefaultsSeededV1'), isTrue);
      expect(box.get(SettingBoxKey.horizontalScreen), isTrue);
      expect(box.get(SettingBoxKey.useSideBar), isTrue);
      expect(box.get(SettingBoxKey.enableVerticalExpand), isFalse);
      expect(box.get(SettingBoxKey.enableAutoEnter), isTrue);
      expect(box.get(SettingBoxKey.autoPlayEnable), isTrue);
      expect(box.get(SettingBoxKey.enableShowDanmaku), isTrue);
      expect(
        box.get(SettingBoxKey.fullScreenMode),
        FullScreenMode.none.index,
      );
      expect(box.get(SettingBoxKey.recommendCardWidth), 300.0);
      expect(box.get(SettingBoxKey.defaultTextScale), 1.2);
      expect(box.get(SettingBoxKey.showFsScreenshotBtn), isFalse);
      expect(box.get(SettingBoxKey.showFsLockBtn), isFalse);
      expect(box.get(SettingBoxKey.themeMode), ThemeType.dark.index);

      // Modify a key and verify second invocation does not overwrite it.
      await box.put(SettingBoxKey.useSideBar, false);
      await TvPlatform.seedTvDefaultsToBox(box);
      expect(box.get(SettingBoxKey.useSideBar), isFalse);
    });

    test('preserves pre-existing user preferences when seeding', () async {
      await box.put(SettingBoxKey.defaultTextScale, 1.35);
      await box.put(SettingBoxKey.enableShowDanmaku, false);

      await TvPlatform.seedTvDefaultsToBox(box);
      expect(box.get(SettingBoxKey.defaultTextScale), 1.35);
      expect(box.get(SettingBoxKey.enableShowDanmaku), isFalse);
      expect(box.get(SettingBoxKey.useSideBar), isTrue);
    });
  });

  group('TvFocusTraversalPolicy & TvNavigation', () {
    setUp(() {
      TvPlatform.setTvModeForTesting(true);
    });

    tearDown(() {
      TvPlatform.setTvModeForTesting(false);
    });

    testWidgets('navigates 2D grid accurately with D-pad arrow keys', (
      tester,
    ) async {
      final nodes = List.generate(
        4,
        (i) => FocusNode(debugLabel: 'card_$i'),
      );
      addTearDown(() {
        for (final node in nodes) {
          node.dispose();
        }
      });

      await tester.pumpWidget(
        MaterialApp(
          home: TvNavigation(
            child: Scaffold(
              body: Column(
                children: [
                  Row(
                    children: [
                      SizedBox(
                        width: 200,
                        height: 100,
                        child: ElevatedButton(
                          focusNode: nodes[0],
                          autofocus: true,
                          onPressed: () {},
                          child: const Text('TopLeft'),
                        ),
                      ),
                      const SizedBox(width: 24),
                      SizedBox(
                        width: 200,
                        height: 100,
                        child: ElevatedButton(
                          focusNode: nodes[1],
                          onPressed: () {},
                          child: const Text('TopRight'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  Row(
                    children: [
                      SizedBox(
                        width: 200,
                        height: 100,
                        child: ElevatedButton(
                          focusNode: nodes[2],
                          onPressed: () {},
                          child: const Text('BottomLeft'),
                        ),
                      ),
                      const SizedBox(width: 24),
                      SizedBox(
                        width: 200,
                        height: 100,
                        child: ElevatedButton(
                          focusNode: nodes[3],
                          onPressed: () {},
                          child: const Text('BottomRight'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(nodes[0].hasPrimaryFocus, isTrue);

      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await tester.pumpAndSettle();
      expect(nodes[1].hasPrimaryFocus, isTrue);

      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.pumpAndSettle();
      expect(nodes[3].hasPrimaryFocus, isTrue);

      await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
      await tester.pumpAndSettle();
      expect(nodes[2].hasPrimaryFocus, isTrue);

      await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
      await tester.pumpAndSettle();
      expect(nodes[0].hasPrimaryFocus, isTrue);
    });

    testWidgets(
      'skips zero-height collapsed subtrees and overlaid micro-buttons (<=36x36)',
      (tester) async {
        final firstNode = FocusNode(debugLabel: 'first');
        final collapsedNode = FocusNode(debugLabel: 'collapsed');
        final microNode = FocusNode(debugLabel: 'micro');
        final targetNode = FocusNode(debugLabel: 'target');
        addTearDown(() {
          firstNode.dispose();
          collapsedNode.dispose();
          microNode.dispose();
          targetNode.dispose();
        });

        await tester.pumpWidget(
          MaterialApp(
            home: TvNavigation(
              child: Scaffold(
                body: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      width: 200,
                      height: 60,
                      child: ElevatedButton(
                        focusNode: firstNode,
                        autofocus: true,
                        onPressed: () {},
                        child: const Text('First'),
                      ),
                    ),
                    // Zero-height collapsed container simulating AnimatedHeight(0)
                    ClipRect(
                      child: SizedBox(
                        width: 200,
                        height: 0,
                        child: OverflowBox(
                          maxHeight: 60,
                          child: ElevatedButton(
                            focusNode: collapsedNode,
                            onPressed: () {},
                            child: const Text('Collapsed'),
                          ),
                        ),
                      ),
                    ),
                    // Primary card with an overlaid 28x28 micro button (VideoPopupMenu pattern)
                    SizedBox(
                      width: 200,
                      height: 80,
                      child: InkWell(
                        focusNode: targetNode,
                        onTap: () {},
                        child: Stack(
                          children: [
                            const Center(child: Text('Target')),
                            Positioned(
                              right: 4,
                              bottom: 4,
                              width: 28,
                              height: 28,
                              child: Focus(
                                focusNode: microNode,
                                child: const SizedBox.expand(),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(firstNode.hasPrimaryFocus, isTrue);

        await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
        await tester.pumpAndSettle();

        expect(collapsedNode.hasPrimaryFocus, isFalse);
        expect(microNode.hasPrimaryFocus, isFalse);
        expect(targetNode.hasPrimaryFocus, isTrue);
      },
    );

    testWidgets(
      'skips SlideTransition controls clipped out by an ancestor ClipRect (AppBarAni split-screen pattern)',
      (tester) async {
        final topQuickNode = FocusNode(debugLabel: 'quick_strip');
        final clippedBottomBarNode = FocusNode(debugLabel: 'clipped_bottom_bar');
        final belowPlayerBtnNode = FocusNode(debugLabel: 'below_player_btn');
        addTearDown(() {
          topQuickNode.dispose();
          clippedBottomBarNode.dispose();
          belowPlayerBtnNode.dispose();
        });

        await tester.pumpWidget(
          MaterialApp(
            home: TvNavigation(
              child: Scaffold(
                body: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Split-screen player box clipped at height 240 (inside 600px screen)
                    ClipRect(
                      child: SizedBox(
                        width: 400,
                        height: 240,
                        child: Stack(
                          children: [
                            Positioned(
                              top: 8,
                              left: 8,
                              width: 140,
                              height: 44,
                              child: ElevatedButton(
                                focusNode: topQuickNode,
                                autofocus: true,
                                onPressed: () {},
                                child: const Text('QuickFullscreen'),
                              ),
                            ),
                            // Bottom control bar translated down by Offset(0, 1.2)
                            // so its global rect is still within the 600px screen
                            // (y = 240..288) but outside the 240px player ClipRect.
                            Positioned(
                              left: 0,
                              right: 0,
                              bottom: 0,
                              height: 48,
                              child: FractionalTranslation(
                                translation: const Offset(0, 1.2),
                                child: ElevatedButton(
                                  focusNode: clippedBottomBarNode,
                                  onPressed: () {},
                                  child: const Text('HiddenPlayerBottomBtn'),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: 200,
                      height: 52,
                      child: ElevatedButton(
                        focusNode: belowPlayerBtnNode,
                        onPressed: () {},
                        child: const Text('LikeActionItem'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(topQuickNode.hasPrimaryFocus, isTrue);

        // Pressing Down skips clippedBottomBarNode and lands on belowPlayerBtnNode.
        await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
        await tester.pumpAndSettle();

        expect(clippedBottomBarNode.hasPrimaryFocus, isFalse);
        expect(belowPlayerBtnNode.hasPrimaryFocus, isTrue);
      },
    );

    testWidgets(
      'patched GestureDetector receives D-pad focus and activates onTap & onLongPress',
      (tester) async {
        int tapCount = 0;
        int longPressCount = 0;

        await tester.pumpWidget(
          MaterialApp(
            home: TvNavigation(
              child: Scaffold(
                body: Center(
                  child: GestureDetector(
                    onTap: () => tapCount++,
                    onLongPress: () => longPressCount++,
                    child: const SizedBox(
                      width: 180,
                      height: 64,
                      child: Center(child: Text('GestureCard')),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Trigger initial focus discovery via D-pad arrow key.
        await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
        await tester.pumpAndSettle();

        // Activate onTap via LogicalKeyboardKey.select.
        await tester.sendKeyDownEvent(LogicalKeyboardKey.select);
        await tester.sendKeyUpEvent(LogicalKeyboardKey.select);
        await tester.pumpAndSettle();
        expect(tapCount, 1);

        // Activate onLongPress via KeyRepeatEvent on LogicalKeyboardKey.select.
        await tester.sendKeyDownEvent(LogicalKeyboardKey.select);
        await tester.sendKeyRepeatEvent(LogicalKeyboardKey.select);
        await tester.sendKeyUpEvent(LogicalKeyboardKey.select);
        await tester.pumpAndSettle();
        expect(longPressCount, 1);
      },
    );

    testWidgets(
      'patched RadioGroup allows D-pad arrow navigation to unselected options',
      (tester) async {
        int selectedValue = 1;

        await tester.pumpWidget(
          MaterialApp(
            home: TvNavigation(
              child: Scaffold(
                body: StatefulBuilder(
                  builder: (context, setState) {
                    return RadioGroup<int>(
                      groupValue: selectedValue,
                      onChanged: (v) {
                        if (v != null) {
                          setState(() => selectedValue = v);
                        }
                      },
                      child: const Column(
                        children: [
                          RadioListTile<int>(
                            value: 1,
                            title: Text('Option 1'),
                            autofocus: true,
                          ),
                          RadioListTile<int>(
                            value: 2,
                            title: Text('Option 2'),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Navigate down from selected Option 1 to unselected Option 2.
        await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
        await tester.pumpAndSettle();

        // Select Option 2 via D-pad Enter.
        await tester.sendKeyEvent(LogicalKeyboardKey.enter);
        await tester.pumpAndSettle();

        expect(selectedValue, 2);
      },
    );

    testWidgets(
      'patched InkWell with onTapDown/onTapUp (ActionItem pattern) responds to D-pad Select',
      (tester) async {
        int downCount = 0;
        int upCount = 0;
        final focusNode = FocusNode(debugLabel: 'action_item');
        addTearDown(focusNode.dispose);

        await tester.pumpWidget(
          MaterialApp(
            home: TvNavigation(
              child: Scaffold(
                body: Center(
                  child: SizedBox(
                    width: 160,
                    height: 60,
                    child: InkWell(
                      focusNode: focusNode,
                      autofocus: true,
                      onTapDown: (_) => downCount++,
                      onTapUp: (_) => upCount++,
                      child: const Center(child: Text('TripleLikeBtn')),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(focusNode.hasPrimaryFocus, isTrue);

        await tester.sendKeyDownEvent(LogicalKeyboardKey.select);
        await tester.pump();
        expect(downCount, 1);

        await tester.sendKeyUpEvent(LogicalKeyboardKey.select);
        await tester.pump();
        expect(upCount, 1);
      },
    );

    testWidgets(
      'TvNavigationObserver restores previous route focus after popping dialog/page',
      (tester) async {
        final firstBtnNode = FocusNode(debugLabel: 'btn_1');
        final secondBtnNode = FocusNode(debugLabel: 'btn_2');
        addTearDown(() {
          firstBtnNode.dispose();
          secondBtnNode.dispose();
        });

        final observer = TvNavigationObserver();

        await tester.pumpWidget(
          MaterialApp(
            navigatorObservers: [observer],
            home: TvNavigation(
              child: Builder(
                builder: (context) => Scaffold(
                  body: Column(
                    children: [
                      SizedBox(
                        width: 200,
                        height: 60,
                        child: ElevatedButton(
                          focusNode: firstBtnNode,
                          autofocus: true,
                          onPressed: () {},
                          child: const Text('FirstBtn'),
                        ),
                      ),
                      const SizedBox(height: 16),
                      SizedBox(
                        width: 200,
                        height: 60,
                        child: ElevatedButton(
                          focusNode: secondBtnNode,
                          onPressed: () {
                            Navigator.of(context).push<void>(
                              MaterialPageRoute<void>(
                                builder: (pageContext) => Scaffold(
                                  body: Center(
                                    child: ElevatedButton(
                                      autofocus: true,
                                      onPressed: () =>
                                          Navigator.of(pageContext).pop(),
                                      child: const Text('PopRoute'),
                                    ),
                                  ),
                                ),
                              ),
                            );
                          },
                          child: const Text('SecondBtn'),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Move focus to secondBtnNode and activate it to push a new route.
        await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
        await tester.pumpAndSettle();
        expect(secondBtnNode.hasPrimaryFocus, isTrue);

        await tester.sendKeyEvent(LogicalKeyboardKey.enter);
        await tester.pumpAndSettle();
        expect(find.text('PopRoute'), findsOneWidget);

        // Pop the second route and verify focus returns to secondBtnNode.
        await tester.sendKeyEvent(LogicalKeyboardKey.enter);
        await tester.pumpAndSettle();
        expect(secondBtnNode.hasPrimaryFocus, isTrue);
      },
    );

    testWidgets(
      'soft-keyboard gate stays locked on directional focus and unlocks only on explicit Select/Enter',
      (tester) async {
        final topBtnNode = FocusNode(debugLabel: 'top_btn');
        final textFieldNode = FocusNode(debugLabel: 'search_input');
        addTearDown(() {
          topBtnNode.dispose();
          textFieldNode.dispose();
        });

        await tester.pumpWidget(
          MaterialApp(
            home: TvNavigation(
              child: Scaffold(
                body: Column(
                  children: [
                    SizedBox(
                      width: 240,
                      height: 56,
                      child: ElevatedButton(
                        focusNode: topBtnNode,
                        autofocus: true,
                        onPressed: () {},
                        child: const Text('TopBtn'),
                      ),
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: 240,
                      height: 56,
                      child: TextField(
                        focusNode: textFieldNode,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(topBtnNode.hasPrimaryFocus, isTrue);
        expect(TvPlatform.isSoftKeyboardAllowed, isFalse);

        // Directional D-pad Down moves focus onto TextField without unlocking soft keyboard.
        await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
        await tester.pumpAndSettle();
        expect(textFieldNode.hasPrimaryFocus, isTrue);
        expect(TvPlatform.isSoftKeyboardAllowed, isFalse);

        // Explicit Select press unlocks the soft keyboard for the focused TextField.
        await tester.sendKeyDownEvent(LogicalKeyboardKey.select);
        await tester.sendKeyUpEvent(LogicalKeyboardKey.select);
        await tester.pumpAndSettle();
        expect(TvPlatform.isSoftKeyboardAllowed, isTrue);

        // Moving focus back up to TopBtn automatically re-arms the soft-keyboard gate.
        await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
        await tester.pumpAndSettle();
        expect(topBtnNode.hasPrimaryFocus, isTrue);
        expect(TvPlatform.isSoftKeyboardAllowed, isFalse);
      },
    );

    testWidgets(
      'exits scrollable list at bottom boundary to reach footer action buttons',
      (tester) async {
        final item0Node = FocusNode(debugLabel: 'item_0');
        final item1Node = FocusNode(debugLabel: 'item_1');
        final confirmNode = FocusNode(debugLabel: 'confirm_btn');
        addTearDown(() {
          item0Node.dispose();
          item1Node.dispose();
          confirmNode.dispose();
        });

        await tester.pumpWidget(
          MaterialApp(
            home: TvNavigation(
              child: Scaffold(
                body: Center(
                  child: SizedBox(
                    width: 320,
                    height: 260,
                    child: Column(
                      children: [
                        Expanded(
                          child: ListView(
                            children: [
                              ListTile(
                                focusNode: item0Node,
                                autofocus: true,
                                title: const Text('Item 0'),
                                onTap: () {},
                              ),
                              ListTile(
                                focusNode: item1Node,
                                title: const Text('Item 1'),
                                onTap: () {},
                              ),
                            ],
                          ),
                        ),
                        SizedBox(
                          width: 320,
                          height: 52,
                          child: ElevatedButton(
                            focusNode: confirmNode,
                            onPressed: () {},
                            child: const Text('Confirm'),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(item0Node.hasPrimaryFocus, isTrue);

        await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
        await tester.pumpAndSettle();
        expect(item1Node.hasPrimaryFocus, isTrue);

        // Pressing Down at the bottom of the ListView exits to Confirm instead of wrapping.
        await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
        await tester.pumpAndSettle();
        expect(confirmNode.hasPrimaryFocus, isTrue);
      },
    );

    testWidgets(
      'scrolls full-screen ListView down past bottom viewport edge through cacheExtent items',
      (tester) async {
        final nodes = List<FocusNode>.generate(
          12,
          (i) => FocusNode(debugLabel: 'setting_item_$i'),
        );
        addTearDown(() {
          for (final n in nodes) {
            n.dispose();
          }
        });

        await tester.pumpWidget(
          MaterialApp(
            home: TvNavigation(
              child: Scaffold(
                body: ListView.builder(
                  itemCount: nodes.length,
                  itemBuilder: (context, index) => SizedBox(
                    height: 100,
                    child: ListTile(
                      focusNode: nodes[index],
                      autofocus: index == 0,
                      title: Text('Setting $index'),
                      onTap: () {},
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(nodes[0].hasPrimaryFocus, isTrue);

        for (int i = 1; i < nodes.length; i++) {
          await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
          await tester.pumpAndSettle();
          expect(
            nodes[i].hasPrimaryFocus,
            isTrue,
            reason: 'Expected focus to advance and scroll to Setting $i',
          );
        }
      },
    );

    testWidgets(
      'focus ring updates do not rebuild TvNavigation child subtree across D-pad moves',
      (tester) async {
        final nodes = List<FocusNode>.generate(
          8,
          (i) => FocusNode(debugLabel: 'perf_item_$i'),
        );
        addTearDown(() {
          for (final n in nodes) {
            n.dispose();
          }
        });

        int childBuildCount = 0;

        await tester.pumpWidget(
          MaterialApp(
            home: TvNavigation(
              child: Builder(
                builder: (context) {
                  childBuildCount++;
                  return Scaffold(
                    body: ListView.builder(
                      itemCount: nodes.length,
                      itemBuilder: (context, index) => SizedBox(
                        height: 96,
                        child: ListTile(
                          focusNode: nodes[index],
                          autofocus: index == 0,
                          title: Text('Perf Item $index'),
                          onTap: () {},
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(nodes[0].hasPrimaryFocus, isTrue);
        expect(childBuildCount, 1);

        for (int i = 1; i < nodes.length; i++) {
          await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
          await tester.pumpAndSettle();
          expect(nodes[i].hasPrimaryFocus, isTrue);
        }

        for (int i = nodes.length - 2; i >= 0; i--) {
          await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
          await tester.pumpAndSettle();
          expect(nodes[i].hasPrimaryFocus, isTrue);
        }

        // Shifting the focused item's position via scroll offset without
        // changing primaryFocus must synchronize the focus ring overlay rect
        // via _syncFocusRectAfterLayout without rebuilding TvNavigation.child.
        final Finder ringCustomPaintFinder = find
            .descendant(
              of: find.byType(TvNavigation),
              matching: find.byType(CustomPaint),
            )
            .last;
        final CustomPainter painterBeforeScroll = tester
            .widget<CustomPaint>(ringCustomPaintFinder)
            .painter!;
        final ScrollableState scrollable = tester.state<ScrollableState>(
          find.byType(Scrollable),
        );
        final double topBeforeScroll = tester
            .getRect(
              find.byWidgetPredicate(
                (w) => w is ListTile && w.focusNode == nodes[0],
              ),
            )
            .top;
        scrollable.position.jumpTo(24.0);
        await tester.pumpAndSettle();
        final double topAfterScroll = tester
            .getRect(
              find.byWidgetPredicate(
                (w) => w is ListTile && w.focusNode == nodes[0],
              ),
            )
            .top;
        expect(topAfterScroll, closeTo(topBeforeScroll - 24.0, 0.5));
        final CustomPainter painterAfterScroll = tester
            .widget<CustomPaint>(ringCustomPaintFinder)
            .painter!;
        expect(painterAfterScroll.shouldRepaint(painterBeforeScroll), isTrue);

        // Moving focus and updating the focus ring overlay must never rebuild
        // TvNavigation's child widget subtree.
        expect(childBuildCount, 1);
      },
    );

    testWidgets(
      'gates same-frame D-pad bursts to one step per frame and paces KeyRepeatEvents at 45ms including after idle periods',
      (tester) async {
        final nodes = List<FocusNode>.generate(
          30,
          (i) => FocusNode(debugLabel: 'burst_item_$i'),
        );
        addTearDown(() {
          for (final n in nodes) {
            n.dispose();
          }
        });

        await tester.pumpWidget(
          MaterialApp(
            home: TvNavigation(
              child: Scaffold(
                body: ListView.builder(
                  itemCount: nodes.length,
                  itemBuilder: (context, index) => SizedBox(
                    height: 88,
                    child: ListTile(
                      focusNode: nodes[index],
                      autofocus: index == 0,
                      title: Text('Burst Item $index'),
                      onTap: () {},
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(nodes[0].hasPrimaryFocus, isTrue);

        // 1. Two directional KeyDownEvents within the same frame (before pump)
        // must only advance focus by 1 item, preventing layout-stale multi-jumps.
        await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
        await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
        await tester.pump(const Duration(milliseconds: 50));
        expect(nodes[1].hasPrimaryFocus, isTrue);

        // 2. Simulate 5 seconds of idle screen time (no frames scheduled) before
        // pressing and holding arrowDown. The KeyDownEvent fires at +5000ms
        // while currentSystemFrameTimeStamp is still at the pre-idle frame,
        // and the resulting frame renders at +5010ms. A sub-45ms KeyRepeatEvent
        // at +5010ms (+10ms after KeyDown) must still be throttled.
        await tester.pump(const Duration(seconds: 5));
        await tester.sendKeyDownEvent(LogicalKeyboardKey.arrowDown);
        await tester.pump(const Duration(milliseconds: 10));
        expect(nodes[2].hasPrimaryFocus, isTrue);

        // Sub-45ms repeat (at +10ms since KeyDown) is throttled.
        await tester.sendKeyRepeatEvent(LogicalKeyboardKey.arrowDown);
        await tester.pump(const Duration(milliseconds: 10));
        expect(nodes[2].hasPrimaryFocus, isTrue);

        // Advance past 45ms total since KeyDown and stream 15 paced repeats.
        await tester.pump(const Duration(milliseconds: 40));
        for (int step = 3; step <= 17; step++) {
          await tester.sendKeyRepeatEvent(LogicalKeyboardKey.arrowDown);
          await tester.pump(const Duration(milliseconds: 50));
          expect(
            nodes[step].hasPrimaryFocus,
            isTrue,
            reason: 'Expected paced KeyRepeatEvent to land on Burst Item $step',
          );
        }
        await tester.sendKeyUpEvent(LogicalKeyboardKey.arrowDown);
        await tester.pumpAndSettle();
        expect(nodes[17].hasPrimaryFocus, isTrue);
      },
    );

    testWidgets(
      'gates rapid diagonal and boundary D-pad bursts across lazy GridView.builder rows',
      (tester) async {
        final nodes = List<FocusNode>.generate(
          24,
          (i) => FocusNode(debugLabel: 'grid_item_$i'),
        );
        addTearDown(() {
          for (final n in nodes) {
            n.dispose();
          }
        });

        await tester.pumpWidget(
          MaterialApp(
            home: TvNavigation(
              child: Scaffold(
                body: SizedBox(
                  width: 600,
                  height: 300,
                  child: GridView.builder(
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 3,
                          mainAxisExtent: 120,
                        ),
                    itemCount: nodes.length,
                    itemBuilder: (context, index) => InkWell(
                      focusNode: nodes[index],
                      autofocus: index == 0,
                      onTap: () {},
                      child: Center(child: Text('Grid $index')),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(nodes[0].hasPrimaryFocus, isTrue);

        // Same-frame diagonal burst (Down + Right before pump) must only apply
        // the first directional move (0 -> 3) and gate the second move.
        await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
        await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
        await tester.pump(const Duration(milliseconds: 50));
        expect(nodes[3].hasPrimaryFocus, isTrue);

        // Move across the row to the right boundary (3 -> 4 -> 5).
        await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
        await tester.pump(const Duration(milliseconds: 50));
        expect(nodes[4].hasPrimaryFocus, isTrue);
        await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
        await tester.pump(const Duration(milliseconds: 50));
        expect(nodes[5].hasPrimaryFocus, isTrue);

        // Pressing Right at the right boundary is a no-op (does not lock
        // traversal), so a subsequent Down steps cleanly to the next row (8).
        await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
        await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
        await tester.pump(const Duration(milliseconds: 50));
        expect(nodes[8].hasPrimaryFocus, isTrue);

        // Step down through remaining lazy rows to the bottom-right item (23).
        for (int row = 3; row < 8; row++) {
          await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
          await tester.pumpAndSettle();
          expect(
            nodes[row * 3 + 2].hasPrimaryFocus,
            isTrue,
            reason: 'Expected focus to reach row $row col 2 (item ${row * 3 + 2})',
          );
        }
      },
    );

    testWidgets(
      'bounds directional candidate traversal latency under large element tree (100+ focusable items)',
      (tester) async {
        // Build 120 focusable items arranged in a 10-column grid (12 rows x 10 cols).
        final nodes = List<FocusNode>.generate(
          120,
          (i) => FocusNode(debugLabel: 'bench_item_$i'),
        );
        addTearDown(() {
          for (final n in nodes) {
            n.dispose();
          }
        });

        await tester.pumpWidget(
          MaterialApp(
            home: TvNavigation(
              child: Scaffold(
                body: SizedBox(
                  width: 1000,
                  height: 1200,
                  child: GridView.builder(
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 10,
                          mainAxisExtent: 80,
                        ),
                    itemCount: nodes.length,
                    itemBuilder: (context, index) => SizedBox(
                      width: 90,
                      height: 70,
                      child: ElevatedButton(
                        focusNode: nodes[index],
                        autofocus: index == 0,
                        onPressed: () {},
                        child: Text('$index'),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(nodes[0].hasPrimaryFocus, isTrue);

        // Step through 11 rows down (0 -> 10 -> 20 -> ... -> 110)
        // and 9 columns right (110 -> 111 -> ... -> 119)
        final stopwatch = Stopwatch()..start();
        const int stepsDown = 11;
        const int stepsRight = 9;

        for (int i = 1; i <= stepsDown; i++) {
          await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
          await tester.pump(const Duration(milliseconds: 50));
          expect(
            nodes[i * 10].hasPrimaryFocus,
            isTrue,
            reason: 'Step down $i expected node index ${i * 10}',
          );
        }

        for (int j = 1; j <= stepsRight; j++) {
          await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
          await tester.pump(const Duration(milliseconds: 50));
          expect(
            nodes[110 + j].hasPrimaryFocus,
            isTrue,
            reason: 'Step right $j expected node index ${110 + j}',
          );
        }

        stopwatch.stop();
        const int totalSteps = stepsDown + stepsRight;
        final double meanLatencyMs = stopwatch.elapsedMilliseconds / totalSteps;

        // Verify destination focus and authentic bounded traversal latency (< 50ms / step).
        expect(nodes[119].hasPrimaryFocus, isTrue);
        expect(
          meanLatencyMs,
          lessThan(50.0),
          reason:
              'Mean traversal step latency must be bounded below 50ms (measured: ${meanLatencyMs.toStringAsFixed(2)}ms/step)',
        );
      },
    );

    testWidgets(
      'evaluates localToGlobal and RenderBox geometry strictly single-pass per traversal step',
      (tester) async {
        final nodes = List<FocusNode>.generate(
          16,
          (i) => FocusNode(debugLabel: 'single_pass_node_$i'),
        );
        final boxes = <_CallCountingRenderBox>[];
        addTearDown(() {
          for (final n in nodes) {
            n.dispose();
          }
        });

        await tester.pumpWidget(
          MaterialApp(
            home: TvNavigation(
              child: Scaffold(
                body: SizedBox(
                  width: 400,
                  height: 400,
                  child: GridView.builder(
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 4,
                          mainAxisExtent: 80,
                        ),
                    itemCount: nodes.length,
                    itemBuilder: (context, index) => Focus(
                      focusNode: nodes[index],
                      autofocus: index == 0,
                      child: _CallCountingWidget(
                        onRenderBoxCreated: boxes.add,
                        child: Container(
                          width: 80,
                          height: 70,
                          color: Colors.blue,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(nodes[0].hasPrimaryFocus, isTrue);
        expect(boxes.length, 16);

        // Reset call counters after initial layout and settle.
        for (final box in boxes) {
          box.localToGlobalCalls = 0;
        }

        // Execute exactly one directional traversal step (0 -> 4)
        await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
        await tester.pump(const Duration(milliseconds: 50));
        expect(nodes[4].hasPrimaryFocus, isTrue);

        // Verify that for EVERY candidate in the tree, localToGlobal was evaluated
        // strictly single-pass (at most 1 call per node during the step, memoized via _TvTraversalCache).
        for (int i = 0; i < boxes.length; i++) {
          expect(
            boxes[i].localToGlobalCalls,
            lessThanOrEqualTo(1),
            reason:
                'Box $i called localToGlobal ${boxes[i].localToGlobalCalls} times (expected <= 1)',
          );
        }
      },
    );

    testWidgets(
      'ensures zero child widget rebuilds during spatial navigation and focus rect sync',
      (tester) async {
        final nodes = List<FocusNode>.generate(
          6,
          (i) => FocusNode(debugLabel: 'rebuild_node_$i'),
        );
        final itemBuildCounts = List<int>.filled(nodes.length, 0);
        addTearDown(() {
          for (final n in nodes) {
            n.dispose();
          }
        });

        await tester.pumpWidget(
          MaterialApp(
            home: TvNavigation(
              child: Scaffold(
                body: Row(
                  children: [
                    for (int i = 0; i < nodes.length; i++)
                      Builder(
                        builder: (context) {
                          itemBuildCounts[i]++;
                          return SizedBox(
                            width: 100,
                            height: 60,
                            child: ElevatedButton(
                              focusNode: nodes[i],
                              autofocus: i == 0,
                              onPressed: () {},
                              child: Text('Item $i'),
                            ),
                          );
                        },
                      ),
                  ],
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(nodes[0].hasPrimaryFocus, isTrue);

        // All items have been built exactly once initially.
        for (int i = 0; i < nodes.length; i++) {
          expect(itemBuildCounts[i], 1);
        }

        // Move focus across 4 items (0 -> 1 -> 2 -> 3 -> 4).
        for (int step = 1; step <= 4; step++) {
          await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
          await tester.pumpAndSettle();
          expect(nodes[step].hasPrimaryFocus, isTrue);
        }

        // ElevatedButton without custom Focus/State builders does not rebuild
        // sibling items or child widgets on focus change. All build counts remain 1.
        for (int i = 0; i < nodes.length; i++) {
          expect(
            itemBuildCounts[i],
            1,
            reason: 'Item $i rebuilt unnecessarily (count=${itemBuildCounts[i]})',
          );
        }
      },
    );

    testWidgets(
      '_syncFocusRectAfterLayout skips post-frame callbacks and repaints when focused node is stationary',
      (tester) async {
        final node = FocusNode(debugLabel: 'stationary_node');
        addTearDown(node.dispose);

        await tester.pumpWidget(
          MaterialApp(
            home: TvNavigation(
              child: Scaffold(
                body: Center(
                  child: SizedBox(
                    width: 200,
                    height: 80,
                    child: ElevatedButton(
                      focusNode: node,
                      autofocus: true,
                      onPressed: () {},
                      child: const Text('Stationary'),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(node.hasPrimaryFocus, isTrue);

        final Finder ringFinder = find
            .descendant(
              of: find.byType(TvNavigation),
              matching: find.byType(CustomPaint),
            )
            .last;
        final CustomPainter initialPainter =
            tester.widget<CustomPaint>(ringFinder).painter!;

        // Pump multiple idle frames where the focused node has not moved,
        // scrolled, or changed size.
        await tester.pump(const Duration(milliseconds: 16));
        await tester.pump(const Duration(milliseconds: 16));
        await tester.pump(const Duration(milliseconds: 16));

        final CustomPainter currentPainter =
            tester.widget<CustomPaint>(ringFinder).painter!;

        // shouldRepaint must return false because the rect is identical.
        expect(currentPainter.shouldRepaint(initialPainter), isFalse);
      },
    );

    testWidgets(
      'focus ring CustomPainter repaints immediately when focus rect updates without extra frame delay',
      (tester) async {
        final nodes = [
          FocusNode(debugLabel: 'fast_node_0'),
          FocusNode(debugLabel: 'fast_node_1'),
        ];
        addTearDown(() {
          for (final n in nodes) {
            n.dispose();
          }
        });

        await tester.pumpWidget(
          MaterialApp(
            home: TvNavigation(
              child: Scaffold(
                body: Column(
                  children: [
                    SizedBox(
                      width: 200,
                      height: 80,
                      child: ElevatedButton(
                        focusNode: nodes[0],
                        autofocus: true,
                        onPressed: () {},
                        child: const Text('Node 0'),
                      ),
                    ),
                    const SizedBox(height: 40),
                    SizedBox(
                      width: 200,
                      height: 80,
                      child: ElevatedButton(
                        focusNode: nodes[1],
                        onPressed: () {},
                        child: const Text('Node 1'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(nodes[0].hasPrimaryFocus, isTrue);

        final Finder ringFinder = find
            .descendant(
              of: find.byType(TvNavigation),
              matching: find.byType(CustomPaint),
            )
            .last;
        final RenderCustomPaint renderObject =
            tester.renderObject(ringFinder) as RenderCustomPaint;

        // Render object has finished painting the settled frame.
        expect(renderObject.debugNeedsPaint, isFalse);

        final CustomPainter painterBefore =
            tester.widget<CustomPaint>(ringFinder).painter!;
        final Rect? rectBefore = (painterBefore as dynamic).rect as Rect?;
        expect(
          rectBefore,
          tester.getRect(find.widgetWithText(ElevatedButton, 'Node 0')),
        );

        // Move focus down to nodes[1].
        await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
        await tester.pumpAndSettle();
        expect(nodes[1].hasPrimaryFocus, isTrue);

        final CustomPainter painterAfter =
            tester.widget<CustomPaint>(ringFinder).painter!;
        final Rect? rectAfter = (painterAfter as dynamic).rect as Rect?;
        final Rect expectedRect1 =
            tester.getRect(find.widgetWithText(ElevatedButton, 'Node 1'));

        // Authentically verify that focus ring painter repainted and updated its rect
        // to match the newly focused node geometry.
        expect(rectAfter, expectedRect1);
        expect(rectAfter, isNot(equals(rectBefore)));
        expect(painterAfter.shouldRepaint(painterBefore), isTrue);
      },
    );
  });
}

class _CallCountingRenderBox extends RenderProxyBox {
  int localToGlobalCalls = 0;

  @override
  Offset localToGlobal(Offset point, {RenderObject? ancestor}) {
    localToGlobalCalls++;
    return super.localToGlobal(point, ancestor: ancestor);
  }
}

class _CallCountingWidget extends SingleChildRenderObjectWidget {
  const _CallCountingWidget({
    required super.child,
    required this.onRenderBoxCreated,
  });

  final void Function(_CallCountingRenderBox) onRenderBoxCreated;

  @override
  RenderObject createRenderObject(BuildContext context) {
    final box = _CallCountingRenderBox();
    onRenderBoxCreated(box);
    return box;
  }
}


