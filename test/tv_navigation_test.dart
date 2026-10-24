import 'dart:io';

import 'package:PiliPlus/common/widgets/radio_widget.dart';
import 'package:PiliPlus/models/common/theme/theme_type.dart';
import 'package:PiliPlus/pages/setting/widgets/dual_slider_dialog.dart';
import 'package:PiliPlus/pages/setting/widgets/slider_dialog.dart';
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
        expect(selectedValue, 1);

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
      'preserves same-frame discrete KeyDownEvents while gating KeyRepeatEvents to one step per frame and 45ms interval',
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

        // 1. Two discrete directional KeyDownEvents within the same frame (before
        // pump) must both be processed (0 -> 1 -> 2), never swallowed.
        await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
        await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
        await tester.pump(const Duration(milliseconds: 50));
        expect(nodes[2].hasPrimaryFocus, isTrue);

        // 2. Simulate 5 seconds of idle screen time (no frames scheduled) before
        // pressing and holding arrowDown. The KeyDownEvent fires at +5000ms
        // while currentSystemFrameTimeStamp is still at the pre-idle frame,
        // and a same-frame KeyRepeatEvent + sub-45ms KeyRepeatEvent must be
        // gated so focus only steps once (2 -> 3).
        await tester.pump(const Duration(seconds: 5));
        await tester.sendKeyDownEvent(LogicalKeyboardKey.arrowDown);
        await tester.sendKeyRepeatEvent(LogicalKeyboardKey.arrowDown);
        await tester.pump(const Duration(milliseconds: 10));
        expect(nodes[3].hasPrimaryFocus, isTrue);

        // Sub-45ms repeat (at +10ms since KeyDown) is throttled.
        await tester.sendKeyRepeatEvent(LogicalKeyboardKey.arrowDown);
        await tester.pump(const Duration(milliseconds: 10));
        expect(nodes[3].hasPrimaryFocus, isTrue);

        // Advance past 45ms total since KeyDown and stream 14 paced repeats.
        await tester.pump(const Duration(milliseconds: 40));
        for (int step = 4; step <= 17; step++) {
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
      'processes rapid diagonal and boundary discrete D-pad presses while gating same-frame repeat bursts across lazy GridView.builder rows',
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

        // Same-frame discrete diagonal presses (Down + Right before pump) must
        // execute both discrete steps (0 -> 3 -> 4) without dropping the second key.
        await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
        await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
        await tester.pump(const Duration(milliseconds: 50));
        expect(nodes[4].hasPrimaryFocus, isTrue);

        // Move across the row to the right boundary (4 -> 5).
        await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
        await tester.pump(const Duration(milliseconds: 50));
        expect(nodes[5].hasPrimaryFocus, isTrue);

        // Pressing Right at the right boundary is a no-op, so a subsequent
        // Down steps cleanly to the next row (8).
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

    testWidgets(
      'MyApp._builder MediaQuery wrapping order preserves NavigationMode.directional across routes and showDialog',
      (tester) async {
        NavigationMode? routeNavigationMode;
        NavigationMode? dialogNavigationMode;
        TextScaler? routeTextScaler;
        TextScaler? dialogTextScaler;

        await tester.pumpWidget(
          MaterialApp(
            builder: (context, child) {
              // Mirrors MyApp._builder in lib/main.dart at HEAD: MediaQuery
              // wraps child first, and TvNavigation wraps the resulting
              // MediaQuery at the tail of _builder without touching upstream's
              // uiScale if/else block.
              final mediaQuery = MediaQuery.of(context);
              child = MediaQuery(
                data: mediaQuery.copyWith(
                  textScaler: TextScaler.noScaling,
                ),
                child: child!,
              );
              if (TvPlatform.isTv) {
                child = TvNavigation(child: child);
              }
              return child;
            },
            home: Builder(
              builder: (context) {
                routeNavigationMode = MediaQuery.navigationModeOf(context);
                routeTextScaler = MediaQuery.textScalerOf(context);
                return Scaffold(
                  body: Center(
                    child: ElevatedButton(
                      autofocus: true,
                      onPressed: () {
                        showDialog<void>(
                          context: context,
                          builder: (dialogContext) {
                            dialogNavigationMode = MediaQuery.navigationModeOf(
                              dialogContext,
                            );
                            dialogTextScaler = MediaQuery.textScalerOf(
                              dialogContext,
                            );
                            return AlertDialog(
                              title: const Text('Dialog'),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.pop(dialogContext),
                                  child: const Text('OK'),
                                ),
                              ],
                            );
                          },
                        );
                      },
                      child: const Text('Open Dialog'),
                    ),
                  ),
                );
              },
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(routeNavigationMode, NavigationMode.directional);
        expect(routeTextScaler, TextScaler.noScaling);

        await tester.sendKeyEvent(LogicalKeyboardKey.select);
        await tester.pumpAndSettle();
        expect(dialogNavigationMode, NavigationMode.directional);
        expect(dialogTextScaler, TextScaler.noScaling);
      },
    );

    testWidgets(
      'switchAccountDialog pattern (RadioGroup + RadioWidget / WrapRadioOptionsGroup) allows D-pad focus escape in single-option, multi-option, and Detailed (详细) states',
      (tester) async {
        Map<String, String> options = <String, String>{'0': '0'};
        final List<String> sectionTitles = <String>[
          '主站（推荐、搜索、个人动态等）',
          '番剧 / 影视',
          '直播',
          '心跳记录（观看历史）',
        ];
        List<String> selectedMids = List<String>.filled(
          sectionTitles.length,
          '0',
        );
        bool quickSelect = true;

        await tester.pumpWidget(
          MaterialApp(
            builder: (context, child) {
              final mediaQuery = MediaQuery.of(context);
              child = MediaQuery(
                data: mediaQuery.copyWith(
                  textScaler: TextScaler.noScaling,
                ),
                child: child!,
              );
              return TvNavigation(child: child);
            },
            home: Builder(
              builder: (context) => Scaffold(
                body: Center(
                  child: ElevatedButton(
                    autofocus: true,
                    onPressed: () {
                      showDialog<void>(
                        context: context,
                        builder: (dialogContext) => StatefulBuilder(
                          builder: (context, setState) => AlertDialog(
                            title: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text.rich(
                                  style: TextStyle(height: 1.5),
                                  TextSpan(
                                    children: [
                                      TextSpan(text: '选择账号'),
                                      TextSpan(
                                        text: '\n0代表匿名',
                                        style: TextStyle(fontSize: 13),
                                      ),
                                    ],
                                  ),
                                ),
                                const Spacer(),
                                Builder(
                                  builder: (btnContext) => TextButton(
                                    style: TextButton.styleFrom(
                                      visualDensity: VisualDensity.compact,
                                      tapTargetSize:
                                          MaterialTapTargetSize.shrinkWrap,
                                    ),
                                    onPressed: () {
                                      setState(() {
                                        quickSelect = !quickSelect;
                                      });
                                    },
                                    child: Text(quickSelect ? '详细' : '快速'),
                                  ),
                                ),
                                IconButton(
                                  visualDensity: VisualDensity.compact,
                                  tooltip: '登录',
                                  onPressed: () {},
                                  iconSize: 18,
                                  icon: const Icon(Icons.login_outlined),
                                ),
                              ],
                            ),
                            titlePadding: const EdgeInsets.only(
                              left: 22,
                              top: 16,
                              right: 22,
                              bottom: 3,
                            ),
                            contentPadding: const EdgeInsets.symmetric(
                              vertical: 5,
                            ),
                            actionsPadding: const EdgeInsets.only(
                              left: 16,
                              right: 16,
                              bottom: 10,
                            ),
                            content: SingleChildScrollView(
                              child: AnimatedSize(
                                curve: Curves.easeIn,
                                alignment: Alignment.topCenter,
                                duration: const Duration(milliseconds: 200),
                                child: quickSelect
                                    ? Builder(
                                        builder: (context) =>
                                            RadioGroup<String>(
                                              groupValue: selectedMids[0],
                                              onChanged: (v) {
                                                if (v != null) {
                                                  setState(() {
                                                    selectedMids.fillRange(
                                                      0,
                                                      selectedMids.length,
                                                      v,
                                                    );
                                                  });
                                                }
                                              },
                                              child: Column(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.start,
                                                children: options.entries
                                                    .map(
                                                      (entry) =>
                                                          RadioWidget<String>(
                                                            value: entry.key,
                                                            title: entry.value,
                                                            mainAxisSize:
                                                                MainAxisSize
                                                                    .max,
                                                            padding:
                                                                const EdgeInsets.only(
                                                                  left: 12,
                                                                  top: 2,
                                                                  bottom: 2,
                                                                ),
                                                          ),
                                                    )
                                                    .toList(),
                                              ),
                                            ),
                                      )
                                    : Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: List<Widget>.generate(
                                          sectionTitles.length,
                                          (index) => Builder(
                                            builder: (context) =>
                                                RadioGroup<String>(
                                                  groupValue:
                                                      selectedMids[index],
                                                  onChanged: (v) {
                                                    if (v != null) {
                                                      setState(() {
                                                        selectedMids[index] = v;
                                                      });
                                                    }
                                                  },
                                                  child:
                                                      WrapRadioOptionsGroup<
                                                        String
                                                      >(
                                                        groupTitle:
                                                            sectionTitles[index],
                                                        options: options,
                                                      ),
                                                ),
                                          ),
                                        ),
                                      ),
                              ),
                            ),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(dialogContext),
                                child: const Text('取消'),
                              ),
                              TextButton(
                                onPressed: () => Navigator.pop(dialogContext),
                                child: const Text('确定'),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                    child: const Text('切换账号'),
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        bool isFocusInside(Finder target) {
          final BuildContext? ctx = FocusManager.instance.primaryFocus?.context;
          if (ctx == null) return false;
          return find
              .ancestor(
                of: find.byElementPredicate((e) => e == ctx),
                matching: target,
                matchRoot: true,
              )
              .evaluate()
              .isNotEmpty;
        }

        // 1. Single-option state (logged-out: only '0').
        await tester.sendKeyEvent(LogicalKeyboardKey.select);
        await tester.pumpAndSettle();

        final Finder detailBtn = find.widgetWithText(TextButton, '详细');
        final Finder quickBtn = find.widgetWithText(TextButton, '快速');
        final Finder loginBtn = find.byTooltip('登录');
        final Finder anonRadio = find.widgetWithText(
          RadioWidget<String>,
          '0',
        );
        final Finder cancelBtn = find.widgetWithText(TextButton, '取消');
        final Finder confirmBtn = find.widgetWithText(TextButton, '确定');

        // Initial focus lands on header button ('详细'), and Right/Left navigates to/from '登录'.
        expect(isFocusInside(detailBtn), isTrue);
        await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
        await tester.pumpAndSettle();
        expect(isFocusInside(loginBtn), isTrue);
        await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
        await tester.pumpAndSettle();
        expect(isFocusInside(detailBtn), isTrue);

        // Navigate down to '0' RadioWidget.
        await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
        await tester.pumpAndSettle();
        expect(isFocusInside(anonRadio), isTrue);

        // Press D-pad Down from single RadioWidget -> must escape to dialog actions ('取消' or '确定').
        await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
        await tester.pumpAndSettle();
        expect(
          isFocusInside(cancelBtn) || isFocusInside(confirmBtn),
          isTrue,
          reason:
              'Expected D-pad Down from single RadioWidget to escape to 取消/确定',
        );

        // Verify horizontal traversal between '取消' and '确定'.
        if (isFocusInside(confirmBtn)) {
          await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
          await tester.pumpAndSettle();
          expect(isFocusInside(cancelBtn), isTrue);
          await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
          await tester.pumpAndSettle();
          expect(isFocusInside(confirmBtn), isTrue);
        } else {
          await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
          await tester.pumpAndSettle();
          expect(isFocusInside(confirmBtn), isTrue);
          await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
          await tester.pumpAndSettle();
          expect(isFocusInside(cancelBtn), isTrue);
        }

        // Press D-pad Up back to '0' RadioWidget, then Up again -> must escape to header ('详细'/'登录').
        await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
        await tester.pumpAndSettle();
        expect(isFocusInside(anonRadio), isTrue);

        await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
        await tester.pumpAndSettle();
        expect(
          isFocusInside(detailBtn) || isFocusInside(loginBtn),
          isTrue,
          reason:
              'Expected D-pad Up from single RadioWidget to escape to 详细/登录',
        );
        if (isFocusInside(loginBtn)) {
          await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
          await tester.pumpAndSettle();
        }
        expect(isFocusInside(detailBtn), isTrue);

        // Toggle '详细' mode (quickSelect = false -> 4 AccountType RadioGroup sections).
        await tester.sendKeyEvent(LogicalKeyboardKey.select);
        await tester.pumpAndSettle();
        expect(quickSelect, isFalse);
        expect(isFocusInside(quickBtn), isTrue);
        expect(anonRadio, findsNWidgets(4));

        // Step Down through all 4 AccountType RadioGroup sections in single-option Detailed mode.
        for (int i = 0; i < 4; i++) {
          await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
          await tester.pumpAndSettle();
          expect(
            isFocusInside(anonRadio.at(i)),
            isTrue,
            reason: 'Expected focus on section $i RadioWidget in Detailed mode',
          );
        }

        // Step Down from the 4th section -> must escape to dialog actions ('取消' or '确定').
        await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
        await tester.pumpAndSettle();
        expect(
          isFocusInside(cancelBtn) || isFocusInside(confirmBtn),
          isTrue,
          reason:
              'Expected D-pad Down from 4th section RadioWidget to escape to 取消/确定',
        );

        // Step Up from footer back through all 4 sections (3 -> 2 -> 1 -> 0) and Up to header ('快速'/'登录').
        for (int i = 3; i >= 0; i--) {
          await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
          await tester.pumpAndSettle();
          expect(
            isFocusInside(anonRadio.at(i)),
            isTrue,
            reason:
                'Expected D-pad Up to focus section $i RadioWidget in Detailed mode',
          );
        }
        await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
        await tester.pumpAndSettle();
        expect(
          isFocusInside(quickBtn) || isFocusInside(loginBtn),
          isTrue,
          reason:
              'Expected D-pad Up from section 0 RadioWidget to escape to 快速/登录',
        );

        // Close dialog.
        await tester.sendKeyEvent(LogicalKeyboardKey.escape);
        await tester.pumpAndSettle();

        // 2. Multi-option state ('0' and '1001') in both Quick and Detailed modes.
        options = <String, String>{'0': '0', '1001': '1001'};
        selectedMids = List<String>.filled(sectionTitles.length, '0');
        quickSelect = true;
        await tester.sendKeyEvent(LogicalKeyboardKey.select);
        await tester.pumpAndSettle();

        final Finder user1001Radio = find.widgetWithText(
          RadioWidget<String>,
          '1001',
        );

        // Step down from header -> '0' -> '1001' in Quick mode.
        await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
        await tester.pumpAndSettle();
        expect(isFocusInside(anonRadio), isTrue);
        expect(selectedMids[0], '0');

        await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
        await tester.pumpAndSettle();
        expect(isFocusInside(user1001Radio), isTrue);
        // Moving focus to '1001' must NOT auto-select '1001' before pressing Select.
        expect(selectedMids[0], '0');

        // Press Select to choose '1001'.
        await tester.sendKeyEvent(LogicalKeyboardKey.select);
        await tester.pumpAndSettle();
        expect(selectedMids[0], '1001');

        // Press Down again to escape RadioGroup to footer buttons ('取消'/'确定').
        await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
        await tester.pumpAndSettle();
        expect(
          isFocusInside(cancelBtn) || isFocusInside(confirmBtn),
          isTrue,
          reason:
              'Expected D-pad Down from last RadioWidget to escape to 取消/确定',
        );

        // Navigate Up back to header ('详细'), toggle Detailed mode, and verify multi-option WrapRadioOptionsGroup traversal.
        await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
        await tester.pumpAndSettle();
        await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
        await tester.pumpAndSettle();
        await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
        await tester.pumpAndSettle();
        if (isFocusInside(loginBtn)) {
          await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
          await tester.pumpAndSettle();
        }
        expect(isFocusInside(detailBtn), isTrue);

        await tester.sendKeyEvent(LogicalKeyboardKey.select);
        await tester.pumpAndSettle();
        expect(quickSelect, isFalse);
        expect(anonRadio, findsNWidgets(4));
        expect(user1001Radio, findsNWidgets(4));

        // Down from '快速' -> section 0 ('0' or '1001').
        await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
        await tester.pumpAndSettle();
        expect(
          isFocusInside(anonRadio.at(0)) || isFocusInside(user1001Radio.at(0)),
          isTrue,
        );
        if (isFocusInside(user1001Radio.at(0))) {
          await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
          await tester.pumpAndSettle();
        }
        expect(isFocusInside(anonRadio.at(0)), isTrue);

        // Right within section 0 Wrap row -> section 0 '1001'.
        await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
        await tester.pumpAndSettle();
        expect(isFocusInside(user1001Radio.at(0)), isTrue);

        // Down across sections 1, 2, 3 -> then Down to footer ('取消'/'确定').
        await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
        await tester.pumpAndSettle();
        expect(
          isFocusInside(anonRadio.at(1)) || isFocusInside(user1001Radio.at(1)),
          isTrue,
        );
        await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
        await tester.pumpAndSettle();
        expect(
          isFocusInside(anonRadio.at(2)) || isFocusInside(user1001Radio.at(2)),
          isTrue,
        );
        await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
        await tester.pumpAndSettle();
        expect(
          isFocusInside(anonRadio.at(3)) || isFocusInside(user1001Radio.at(3)),
          isTrue,
        );
        await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
        await tester.pumpAndSettle();
        expect(
          isFocusInside(cancelBtn) || isFocusInside(confirmBtn),
          isTrue,
          reason:
              'Expected D-pad Down from 4th section in multi-option Detailed mode to escape to 取消/确定',
        );
      },
    );

    testWidgets(
      'SliderDialog and DualSliderDialog adjust value with D-pad Left/Right and escape with D-pad Up/Down to dialog actions',
      (tester) async {
        double? sliderResult;
        (double, double)? dualSliderResult;

        bool isFocusInside(Finder target) {
          final BuildContext? ctx = FocusManager.instance.primaryFocus?.context;
          if (ctx == null) return false;
          return find
              .ancestor(
                of: find.byElementPredicate((e) => e == ctx),
                matching: target,
                matchRoot: true,
              )
              .evaluate()
              .isNotEmpty;
        }

        await tester.pumpWidget(
          MaterialApp(
            builder: (context, child) {
              final mediaQuery = MediaQuery.of(context);
              child = MediaQuery(
                data: mediaQuery.copyWith(
                  textScaler: TextScaler.noScaling,
                ),
                child: child!,
              );
              return TvNavigation(child: child);
            },
            home: Builder(
              builder: (context) => Scaffold(
                body: Column(
                  children: [
                    ElevatedButton(
                      autofocus: true,
                      onPressed: () async {
                        sliderResult = await showDialog<double>(
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
                        );
                      },
                      child: const Text('Open SliderDialog'),
                    ),
                    ElevatedButton(
                      onPressed: () async {
                        dualSliderResult = await showDialog<(double, double)>(
                          context: context,
                          builder: (_) => const DualSliderDialog(
                            title: Text('Dual Slider'),
                            description1: Text('Min'),
                            description2: Text('Max'),
                            value1: 20,
                            value2: 80,
                            min: 0,
                            max: 100,
                            divisions: 20,
                            precise: 0,
                          ),
                        );
                      },
                      child: const Text('Open DualSliderDialog'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // 1. Open SliderDialog ('图片质量').
        await tester.sendKeyEvent(LogicalKeyboardKey.select);
        await tester.pumpAndSettle();

        // Slider has primary focus; Right increases by 1 division (50 -> 51 -> 52), Left decreases (52 -> 51).
        await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
        await tester.pumpAndSettle();
        await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
        await tester.pumpAndSettle();
        await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
        await tester.pumpAndSettle();

        // Down escapes Slider to dialog actions ('取消' / '确定').
        await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
        await tester.pumpAndSettle();

        final Finder confirmBtn = find.widgetWithText(TextButton, '确定');
        if (!isFocusInside(confirmBtn)) {
          await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
          await tester.pumpAndSettle();
        }
        expect(isFocusInside(confirmBtn), isTrue);

        // Press Select on '确定' -> resolves SliderDialog with 51.0.
        await tester.sendKeyEvent(LogicalKeyboardKey.select);
        await tester.pumpAndSettle();
        expect(sliderResult, 51.0);

        // 2. Move down to 'Open DualSliderDialog' and open it.
        await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
        await tester.pumpAndSettle();
        await tester.sendKeyEvent(LogicalKeyboardKey.select);
        await tester.pumpAndSettle();

        // First slider focused: press Right (20 -> 25).
        await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
        await tester.pumpAndSettle();

        // Press Down to move from Slider 1 to Slider 2, then Left (80 -> 75).
        await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
        await tester.pumpAndSettle();
        await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
        await tester.pumpAndSettle();

        // Press Down to escape Slider 2 to dialog actions ('取消' / '确定').
        await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
        await tester.pumpAndSettle();
        final Finder dualConfirmBtn = find.widgetWithText(TextButton, '确定');
        if (!isFocusInside(dualConfirmBtn)) {
          await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
          await tester.pumpAndSettle();
        }
        expect(isFocusInside(dualConfirmBtn), isTrue);
        await tester.sendKeyEvent(LogicalKeyboardKey.select);
        await tester.pumpAndSettle();
        expect(dualSliderResult, (25.0, 75.0));
      },
    );

    testWidgets(
      'showMenu with requestFocus: false (PopupListTile pattern) requests focus on TV and allows D-pad item selection',
      (tester) async {
        int selectedItem = 1;

        await tester.pumpWidget(
          MaterialApp(
            builder: (context, child) {
              final mediaQuery = MediaQuery.of(context);
              child = MediaQuery(
                data: mediaQuery.copyWith(
                  navigationMode: NavigationMode.traditional,
                ),
                child: MediaQuery(
                  data: mediaQuery.copyWith(
                    navigationMode: NavigationMode.traditional,
                    textScaler: TextScaler.noScaling,
                  ),
                  child: child!,
                ),
              );
              return TvNavigation(child: child);
            },
            home: StatefulBuilder(
              builder: (context, setState) => Scaffold(
                body: Align(
                  alignment: Alignment.bottomCenter,
                  child: FocusScope(
                    debugLabel: 'NestedSettingsScope',
                    child: Builder(
                      builder: (tileContext) {
                        expect(
                          MediaQuery.navigationModeOf(tileContext),
                          NavigationMode.directional,
                        );
                        expect(
                          MediaQuery.textScalerOf(tileContext),
                          TextScaler.noScaling,
                        );
                        return ListTile(
                          autofocus: true,
                          title: const Text('动态页UP主显示位置'),
                          subtitle: Text('当前: $selectedItem'),
                          onTap: () async {
                            final RenderBox button =
                                tileContext.findRenderObject()! as RenderBox;
                            final RenderBox overlay =
                                Navigator.of(
                                      tileContext,
                                    ).overlay!.context.findRenderObject()!
                                    as RenderBox;
                            final RelativeRect position = RelativeRect.fromRect(
                              Rect.fromPoints(
                                button.localToGlobal(
                                  button.size.topRight(Offset.zero),
                                  ancestor: overlay,
                                ),
                                button.localToGlobal(
                                  button.size.bottomRight(Offset.zero),
                                  ancestor: overlay,
                                ),
                              ),
                              Offset.zero & overlay.size,
                            );
                            final int? res = await showMenu<int>(
                              context: tileContext,
                              initialValue: selectedItem,
                              requestFocus: false,
                              position: position,
                              items: const [
                                PopupMenuItem<int>(
                                  value: 1,
                                  child: Text('顶部'),
                                ),
                                PopupMenuItem<int>(
                                  value: 2,
                                  child: Text('左侧常驻'),
                                ),
                                PopupMenuItem<int>(
                                  value: 3,
                                  child: Text('右侧常驻'),
                                ),
                                PopupMenuItem<int>(
                                  value: 4,
                                  child: Text('底栏'),
                                ),
                              ],
                            );
                            if (res != null) {
                              setState(() => selectedItem = res);
                            }
                          },
                        );
                      },
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        final Finder ringFinder = find
            .descendant(
              of: find.byType(TvNavigation),
              matching: find.byType(CustomPaint),
            )
            .last;

        // Activate ListTile inside nested FocusScope via D-pad Select to open popup menu near screen bottom.
        await tester.sendKeyEvent(LogicalKeyboardKey.select);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 16));
        await tester.pump(const Duration(milliseconds: 16));
        final CustomPainter earlyMenuPainter =
            tester.widget<CustomPaint>(ringFinder).painter!;

        await tester.pumpAndSettle();
        final CustomPainter settledMenuPainter =
            tester.widget<CustomPaint>(ringFinder).painter!;

        // As _PopupMenu expands near the bottom of the screen, _PopupMenuRouteLayout
        // shifts its CustomSingleChildLayout ancestor upward; focus ring rect must
        // track the ancestor BoxParentData offset change instead of staying at the
        // early animation position.
        expect(settledMenuPainter.shouldRepaint(earlyMenuPainter), isTrue);

        // Verify primary focus moved into the first PopupMenuItem ('顶部').
        final FocusNode? menuFocus = FocusManager.instance.primaryFocus;
        expect(menuFocus, isNotNull);
        expect(menuFocus is FocusScopeNode, isFalse);
        expect(
          find.descendant(
            of: find.byElementPredicate((e) => e == menuFocus!.context),
            matching: find.text('顶部'),
          ),
          findsOneWidget,
        );

        // Navigate down to second PopupMenuItem ('左侧常驻', value: 2) and select with D-pad Select.
        await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
        await tester.pumpAndSettle();
        await tester.sendKeyEvent(LogicalKeyboardKey.select);
        await tester.pumpAndSettle();

        expect(selectedItem, 2);

        // Verify primary focus returns to the triggering ListTile after showMenu closes.
        final FocusNode? restoredFocus = FocusManager.instance.primaryFocus;
        expect(restoredFocus, isNotNull);
        expect(
          find.descendant(
            of: find.byElementPredicate((e) => e == restoredFocus!.context),
            matching: find.text('动态页UP主显示位置'),
          ),
          findsOneWidget,
        );

        // Edge case: same-frame focus change + showMenu(requestFocus: false,
        // popUpAnimationStyle: AnimationStyle.noAnimation) where _onFocus()
        // sets _focusSyncScheduled = true before drawFrame() runs and no
        // animation frames follow.
        restoredFocus!.unfocus();
        await tester.pump();
        restoredFocus.requestFocus();
        final BuildContext tileCtx = tester.element(
          find.text('动态页UP主显示位置'),
        );
        // ignore: unawaited_futures
        showMenu<int>(
          context: tileCtx,
          requestFocus: false,
          popUpAnimationStyle: AnimationStyle.noAnimation,
          position: const RelativeRect.fromLTRB(100, 100, 100, 100),
          items: const [
            PopupMenuItem<int>(value: 10, child: Text('无动画项A')),
            PopupMenuItem<int>(value: 20, child: Text('无动画项B')),
          ],
        );
        await tester.pump();
        final FocusNode? noAnimMenuFocus = FocusManager.instance.primaryFocus;
        expect(noAnimMenuFocus, isNotNull);
        expect(
          find.descendant(
            of: find.byElementPredicate((e) => e == noAnimMenuFocus!.context),
            matching: find.text('无动画项A'),
          ),
          findsOneWidget,
        );
        await tester.sendKeyEvent(LogicalKeyboardKey.escape);
        await tester.pumpAndSettle();
      },
    );

    testWidgets(
      'relocates primary focus from kept-alive offscreen PageView page without scrolling locked PageView (M7 Bug 1)',
      (tester) async {
        tester.view.physicalSize = const Size(1920, 1080);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        final pageController = PageController();
        final userAvatarNode = FocusNode(debugLabel: 'rail_user_avatar');
        final railHomeNode = FocusNode(debugLabel: 'rail_home');
        final railMineNode = FocusNode(debugLabel: 'rail_mine');
        final homeCardNode = FocusNode(debugLabel: 'home_card_0');
        final mineAccountNode = FocusNode(debugLabel: 'mine_account_icon');
        final mineSettingNode = FocusNode(debugLabel: 'mine_setting_icon');

        addTearDown(() {
          pageController.dispose();
          userAvatarNode.dispose();
          railHomeNode.dispose();
          railMineNode.dispose();
          homeCardNode.dispose();
          mineAccountNode.dispose();
          mineSettingNode.dispose();
        });

        int selectedIndex = 0;
        int homeCardTaps = 0;
        int accountIconTaps = 0;
        int settingIconTaps = 0;

        await tester.pumpWidget(
          MaterialApp(
            home: TvNavigation(
              child: StatefulBuilder(
                builder: (context, setState) => PopScope(
                  canPop: selectedIndex == 0,
                  onPopInvokedWithResult: (didPop, _) {
                    if (!didPop && selectedIndex != 0) {
                      setState(() => selectedIndex = 0);
                      pageController.jumpToPage(0);
                    }
                  },
                  child: Scaffold(
                    body: Row(
                      children: [
                        SizedBox(
                          width: 120,
                          child: Column(
                            children: [
                              // Topmost-leftmost widget in MainApp's sidebar is
                              // userAvatar, which navigates to MinePage (index 1).
                              ElevatedButton(
                                focusNode: userAvatarNode,
                                onPressed: () {
                                  setState(() => selectedIndex = 1);
                                  pageController.jumpToPage(1);
                                },
                                child: const Text('头像'),
                              ),
                              ElevatedButton(
                                focusNode: railHomeNode,
                                autofocus: true,
                                onPressed: () {
                                  setState(() => selectedIndex = 0);
                                  pageController.jumpToPage(0);
                                },
                                child: const Text('首页'),
                              ),
                              ElevatedButton(
                                focusNode: railMineNode,
                                onPressed: () {
                                  setState(() => selectedIndex = 1);
                                  pageController.jumpToPage(1);
                                },
                                child: const Text('我的'),
                              ),
                            ],
                          ),
                        ),
                        Expanded(
                          child: PageView(
                            controller: pageController,
                            physics: const NeverScrollableScrollPhysics(),
                            children: [
                              _KeepAliveTestPage(
                                child: Align(
                                  alignment: Alignment.topLeft,
                                  child: ElevatedButton(
                                    focusNode: homeCardNode,
                                    onPressed: () => homeCardTaps++,
                                    child: const Text('推荐视频卡片'),
                                  ),
                                ),
                              ),
                              _KeepAliveTestPage(
                                child: ListView(
                                  children: [
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.end,
                                      children: [
                                        IconButton(
                                          focusNode: mineAccountNode,
                                          icon: const Icon(
                                            Icons.switch_account_outlined,
                                          ),
                                          onPressed: () => accountIconTaps++,
                                        ),
                                        IconButton(
                                          focusNode: mineSettingNode,
                                          icon: const Icon(
                                            Icons.settings_outlined,
                                          ),
                                          onPressed: () => settingIconTaps++,
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ],
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
        expect(railHomeNode.hasPrimaryFocus, isTrue);

        // Scenario A: Navigate to "我的" (MinePage, index 1) and focus setting icon.
        await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
        await tester.pumpAndSettle();
        expect(railMineNode.hasPrimaryFocus, isTrue);

        await tester.sendKeyEvent(LogicalKeyboardKey.select);
        await tester.pumpAndSettle();
        expect(pageController.page, 1.0);

        await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
        await tester.pumpAndSettle();
        expect(mineAccountNode.hasPrimaryFocus, isTrue);

        await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
        await tester.pumpAndSettle();
        expect(mineSettingNode.hasPrimaryFocus, isTrue);

        // Simulate pressing D-pad Back/Return while focused on MinePage's setting icon,
        // exiting to the TV launcher (paused) and reopening PiliPlus TV (resumed).
        await tester.binding.handlePopRoute();
        tester.binding.handleAppLifecycleStateChanged(
          AppLifecycleState.paused,
        );
        tester.binding.handleAppLifecycleStateChanged(
          AppLifecycleState.resumed,
        );
        await tester.pumpAndSettle();

        final Finder ringFinder = find
            .descendant(
              of: find.byType(TvNavigation),
              matching: find.byType(CustomPaint),
            )
            .last;

        // 1. PageView must stay on HomePage (0.0) and never be scrolled back to 1.0.
        expect(pageController.page, 0.0);

        // 2. Offscreen kept-alive setting/account icons and userAvatar must NOT hold focus;
        //    focus must recover inside the PageView container onto HomePage's card, with
        //    a visible yellow selection border matching HomePage's card rect.
        expect(mineSettingNode.hasPrimaryFocus, isFalse);
        expect(mineAccountNode.hasPrimaryFocus, isFalse);
        expect(userAvatarNode.hasPrimaryFocus, isFalse);
        expect(homeCardNode.hasPrimaryFocus, isTrue);
        final CustomPainter painterA =
            tester.widget<CustomPaint>(ringFinder).painter!;
        expect(
          (painterA as dynamic).rect as Rect?,
          homeCardNode.rect,
        );

        // 3. Pressing Enter activates HomePage's video card, never the offscreen
        //    setting icon or userAvatar (toMinePage).
        await tester.sendKeyEvent(LogicalKeyboardKey.enter);
        await tester.pumpAndSettle();
        expect(homeCardTaps, 1);
        expect(settingIconTaps, 0);
        expect(accountIconTaps, 0);
        expect(pageController.page, 0.0);

        // Scenario B: Navigate back to "我的", focus account icon inside MinePage's
        // vertical ListView, and press Back/Return + resume.
        railMineNode.requestFocus();
        await tester.pumpAndSettle();
        await tester.sendKeyEvent(LogicalKeyboardKey.select);
        await tester.pumpAndSettle();
        expect(pageController.page, 1.0);

        await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
        await tester.pumpAndSettle();
        expect(mineAccountNode.hasPrimaryFocus, isTrue);

        await tester.binding.handlePopRoute();
        // Even if Enter is pressed immediately before post-frame callbacks settle,
        // the offscreen account icon must NOT be activated.
        await tester.sendKeyEvent(LogicalKeyboardKey.enter);
        expect(accountIconTaps, 0);
        expect(settingIconTaps, 0);

        tester.binding.handleAppLifecycleStateChanged(
          AppLifecycleState.paused,
        );
        tester.binding.handleAppLifecycleStateChanged(
          AppLifecycleState.resumed,
        );
        await tester.pumpAndSettle();

        expect(pageController.page, 0.0);
        expect(mineAccountNode.hasPrimaryFocus, isFalse);
        expect(userAvatarNode.hasPrimaryFocus, isFalse);
        expect(homeCardNode.hasPrimaryFocus, isTrue);
        final CustomPainter painterB =
            tester.widget<CustomPaint>(ringFinder).painter!;
        expect(
          (painterB as dynamic).rect as Rect?,
          homeCardNode.rect,
        );

        await tester.sendKeyEvent(LogicalKeyboardKey.enter);
        await tester.pumpAndSettle();
        expect(homeCardTaps, 2);
        expect(accountIconTaps, 0);
        expect(settingIconTaps, 0);
        expect(pageController.page, 0.0);
      },
    );

    testWidgets(
      'schedules frame in SchedulerPhase.idle and sustains rapid discrete D-pad key presses without freezing (M7 Bug 2)',
      (tester) async {
        final nodes = List<FocusNode>.generate(
          8,
          (i) => FocusNode(debugLabel: 'rapid_item_$i'),
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
                body: Column(
                  children: [
                    for (int i = 0; i < nodes.length; i++)
                      SizedBox(
                        height: 60,
                        width: 400,
                        child: ElevatedButton(
                          focusNode: nodes[i],
                          autofocus: i == 0,
                          onPressed: () {},
                          child: Text('Item $i'),
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

        // 1. Multiple discrete D-pad Down presses arriving within the same frame
        //    must all register without dropping keys (0 -> 1 -> 2 -> 3).
        await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
        await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
        await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
        expect(tester.binding.hasScheduledFrame, isTrue);
        await tester.pump(const Duration(milliseconds: 16));
        expect(nodes[3].hasPrimaryFocus, isTrue);

        // 2. Subsequent rapid discrete D-pad Down presses across consecutive 16ms
        //    frames advance every step cleanly to the end (3 -> 7).
        for (int i = 4; i < nodes.length; i++) {
          await tester.sendKeyDownEvent(LogicalKeyboardKey.arrowDown);
          expect(tester.binding.hasScheduledFrame, isTrue);
          await tester.sendKeyUpEvent(LogicalKeyboardKey.arrowDown);
          await tester.pump(const Duration(milliseconds: 16));
          expect(
            nodes[i].hasPrimaryFocus,
            isTrue,
            reason: 'Rapid D-pad step $i should advance without freezing',
          );
        }
      },
    );
  });
}

class _KeepAliveTestPage extends StatefulWidget {
  const _KeepAliveTestPage({required this.child});

  final Widget child;

  @override
  State<_KeepAliveTestPage> createState() => _KeepAliveTestPageState();
}

class _KeepAliveTestPageState extends State<_KeepAliveTestPage>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return widget.child;
  }
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
