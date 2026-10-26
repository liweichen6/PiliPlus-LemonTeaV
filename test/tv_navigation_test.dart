import 'dart:io';

import 'package:PiliPlus/common/widgets/radio_widget.dart';
import 'package:PiliPlus/common/widgets/scaffold/mini_scaffold.dart';
import 'package:PiliPlus/common/widgets/sliver/sliver_floating_header.dart';
import 'package:PiliPlus/common/widgets/sliver/sliver_pinned_header.dart';
import 'package:PiliPlus/models/common/theme/theme_type.dart';
import 'package:PiliPlus/pages/setting/widgets/dual_slider_dialog.dart';
import 'package:PiliPlus/pages/setting/widgets/slider_dialog.dart';
import 'package:PiliPlus/plugin/pl_player/models/fullscreen_mode.dart';
import 'package:PiliPlus/tv/tv_navigation.dart';
import 'package:PiliPlus/tv/tv_platform.dart';
import 'package:PiliPlus/utils/storage_key.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_smart_dialog/flutter_smart_dialog.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
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
      expect(box.get(SettingBoxKey.keyboardControl), isTrue);

      // Modify a key and verify second invocation does not overwrite it.
      await box.put(SettingBoxKey.useSideBar, false);
      await TvPlatform.seedTvDefaultsToBox(box);
      expect(box.get(SettingBoxKey.useSideBar), isFalse);
    });

    test('preserves pre-existing user preferences when seeding', () async {
      await box.put(SettingBoxKey.defaultTextScale, 1.35);
      await box.put(SettingBoxKey.enableShowDanmaku, false);
      await box.put(SettingBoxKey.keyboardControl, false);

      await TvPlatform.seedTvDefaultsToBox(box);
      expect(box.get(SettingBoxKey.defaultTextScale), 1.35);
      expect(box.get(SettingBoxKey.enableShowDanmaku), isFalse);
      expect(box.get(SettingBoxKey.keyboardControl), isFalse);
      expect(box.get(SettingBoxKey.useSideBar), isTrue);
    });

    test('writes only the seeded keys, and a later launch refills only missing ones', () async {
      await TvPlatform.seedTvDefaultsToBox(box);
      expect(box.keys.toSet(), TvPlatform.defaultTvSettings.keys.toSet());

      // Seeding fills missing keys on every launch: a key that disappeared
      // (a settings reset) comes back, the rest stays as it is.
      await box.delete(SettingBoxKey.useSideBar);
      await box.put(SettingBoxKey.defaultTextScale, 1.0);
      await TvPlatform.seedTvDefaultsToBox(box);
      expect(box.get(SettingBoxKey.useSideBar), isTrue);
      expect(box.get(SettingBoxKey.defaultTextScale), 1.0);
    });

    test('every seeded key is a real SettingBoxKey, not a dead raw string', () {
      final String keys = File('lib/utils/storage_key.dart').readAsStringSync();
      for (final String key in TvPlatform.defaultTvSettings.keys) {
        expect(
          keys,
          contains("'$key'"),
          reason: '"$key" is not declared in SettingBoxKey',
        );
      }
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

    testWidgets(
      'MiniScaffold 2nd-layer comment (评论详情) & nested 3rd-layer dialogue (对话列表) promote focus, isolate occluded 1st-layer scroll/TabBar, and restore exact focus on Back (M9)',
      (tester) async {
        tester.view.physicalSize = const Size(960, 540);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        final outerMiniScaffoldKey = GlobalKey<MiniScaffoldState>();
        final innerMiniScaffoldKey = GlobalKey<MiniScaffoldState>();
        final firstLayerScrollController = ScrollController();
        final secondLayerScrollController = ScrollController();
        final thirdLayerScrollController = ScrollController();
        final playerFullscreenNode = FocusNode(debugLabel: 'player_fullscreen');
        final introActionNode = FocusNode(debugLabel: 'intro_like');
        final tabIntroNode = FocusNode(debugLabel: 'tab_intro');
        final tabCommentNode = FocusNode(debugLabel: 'tab_comment');
        final secondLayerCloseNode = FocusNode(debugLabel: 'reply_reply_close');
        final thirdLayerCloseNode = FocusNode(debugLabel: 'dialogue_close');
        final commentNodes = List<FocusNode>.generate(
          10,
          (i) => FocusNode(debugLabel: 'first_layer_comment_$i'),
        );
        final replyNodes = List<FocusNode>.generate(
          8,
          (i) => FocusNode(debugLabel: 'second_layer_reply_$i'),
        );
        final dialogueNodes = List<FocusNode>.generate(
          5,
          (i) => FocusNode(debugLabel: 'third_layer_dialogue_$i'),
        );
        addTearDown(() {
          firstLayerScrollController.dispose();
          secondLayerScrollController.dispose();
          thirdLayerScrollController.dispose();
          playerFullscreenNode.dispose();
          introActionNode.dispose();
          tabIntroNode.dispose();
          tabCommentNode.dispose();
          secondLayerCloseNode.dispose();
          thirdLayerCloseNode.dispose();
          for (final n in commentNodes) {
            n.dispose();
          }
          for (final n in replyNodes) {
            n.dispose();
          }
          for (final n in dialogueNodes) {
            n.dispose();
          }
        });

        void openThirdLayerDialogue() {
          innerMiniScaffoldKey.currentState!.showBottomSheet(
            constraints: const BoxConstraints(),
            (context) => ColoredBox(
              color: Colors.grey.shade900,
              child: Column(
                children: [
                  SizedBox(
                    height: 45,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('对话列表'),
                        IconButton(
                          focusNode: thirdLayerCloseNode,
                          tooltip: '关闭',
                          icon: const Icon(Icons.close, size: 20),
                          onPressed: Get.back,
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: ListView.builder(
                      controller: thirdLayerScrollController,
                      itemExtent: 90,
                      itemCount: dialogueNodes.length,
                      itemBuilder: (context, index) => InkWell(
                        focusNode: dialogueNodes[index],
                        onTap: () {},
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: Text('Dialogue #$index'),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        }

        void openSecondLayerReplies() {
          outerMiniScaffoldKey.currentState!.showBottomSheet(
            constraints: const BoxConstraints(),
            (context) => ColoredBox(
              color: Colors.grey.shade900,
              child: MiniScaffold(
                key: innerMiniScaffoldKey,
                body: Column(
                  children: [
                    SizedBox(
                      height: 45,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('评论详情'),
                          IconButton(
                            focusNode: secondLayerCloseNode,
                            tooltip: '关闭',
                            icon: const Icon(Icons.close, size: 20),
                            onPressed: Get.back,
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: ListView.builder(
                        controller: secondLayerScrollController,
                        itemExtent: 100,
                        itemCount: replyNodes.length,
                        itemBuilder: (context, index) => InkWell(
                          focusNode: replyNodes[index],
                          onTap: index == 1 ? openThirdLayerDialogue : () {},
                          child: Align(
                            alignment: Alignment.centerLeft,
                            child: Text('Second Layer Reply #$index'),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }

        await tester.pumpWidget(
          GetMaterialApp(
            builder: (context, child) => TvNavigation(child: child!),
            home: Scaffold(
              body: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: 560,
                    height: 540,
                    child: Column(
                      children: [
                        Container(
                          width: 560,
                          height: 315,
                          alignment: Alignment.center,
                          child: ElevatedButton(
                            focusNode: playerFullscreenNode,
                            onPressed: () {},
                            child: const Text('全屏'),
                          ),
                        ),
                        Container(
                          width: 560,
                          height: 225,
                          alignment: Alignment.center,
                          child: ElevatedButton(
                            focusNode: introActionNode,
                            onPressed: () {},
                            child: const Text('点赞'),
                          ),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(
                    width: 400,
                    height: 540,
                    child: MiniScaffold(
                      key: outerMiniScaffoldKey,
                      body: Column(
                        children: [
                          SizedBox(
                            height: 46,
                            child: Row(
                              children: [
                                Expanded(
                                  child: InkWell(
                                    focusNode: tabIntroNode,
                                    onTap: () {},
                                    child: const Center(child: Text('相关视频')),
                                  ),
                                ),
                                Expanded(
                                  child: InkWell(
                                    focusNode: tabCommentNode,
                                    onTap: () {},
                                    child: const Center(child: Text('评论')),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Expanded(
                            child: ListView.builder(
                              controller: firstLayerScrollController,
                              itemExtent: 140,
                              itemCount: commentNodes.length,
                              itemBuilder: (context, index) => InkWell(
                                focusNode: commentNodes[index],
                                autofocus: index == 0,
                                onTap: openSecondLayerReplies,
                                child: Align(
                                  alignment: Alignment.centerLeft,
                                  child: Text('First Layer Comment #$index'),
                                ),
                              ),
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
        );
        await tester.pumpAndSettle();
        expect(commentNodes[0].hasPrimaryFocus, isTrue);

        final Finder ringFinder = find
            .descendant(
              of: find.byType(TvNavigation),
              matching: find.byType(CustomPaint),
            )
            .last;

        // 1. Navigate down to 1st-layer Comment #3 so firstLayerScrollController scrolls > 0.
        for (int step = 1; step <= 3; step++) {
          await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
          await tester.pumpAndSettle();
          expect(commentNodes[step].hasPrimaryFocus, isTrue);
        }
        final double savedFirstLayerOffset = firstLayerScrollController.offset;
        expect(savedFirstLayerOffset, greaterThan(0.0));

        // 2. Press Select on Comment #3 to open 2nd-layer 评论详情.
        await tester.sendKeyEvent(LogicalKeyboardKey.select);

        // Pump frame-by-frame through the opening animation: focus must NEVER
        // jump to the left-column player button on frame 0, and occluded
        // 1st-layer items must immediately become non-focusable.
        for (int frame = 0; frame < 20; frame++) {
          await tester.pump(const Duration(milliseconds: 16));
          expect(
            playerFullscreenNode.hasPrimaryFocus,
            isFalse,
            reason:
                'Opening animation frame $frame must never jump focus to left player column',
          );
          expect(
            introActionNode.hasPrimaryFocus,
            isFalse,
            reason:
                'Opening animation frame $frame must never jump focus to left intro column',
          );
          expect(
            TvFocusTraversalPolicy.isEffectivelyFocusable(commentNodes[3]),
            isFalse,
            reason: '1st-layer Comment #3 must be occluded while 2nd layer is open',
          );
          expect(
            TvFocusTraversalPolicy.isEffectivelyFocusable(tabCommentNode),
            isFalse,
            reason: '1st-layer TabBar must be occluded while 2nd layer is open',
          );
        }
        await tester.pumpAndSettle();

        void expectSameFocusRect(Rect? actual, Rect expected) {
          expect(actual, isNotNull);
          expect(actual!.left, closeTo(expected.left, 0.5));
          expect(actual.top, closeTo(expected.top, 0.5));
          expect(actual.right, closeTo(expected.right, 0.5));
          expect(actual.bottom, closeTo(expected.bottom, 0.5));
        }

        // Focus promoted into 2nd-layer 评论详情 header close button, and ring rect matches.
        expect(secondLayerCloseNode.hasPrimaryFocus, isTrue);
        final CustomPainter settledSheetPainter =
            tester.widget<CustomPaint>(ringFinder).painter!;
        expectSameFocusRect(
          (settledSheetPainter as dynamic).rect as Rect?,
          secondLayerCloseNode.rect,
        );

        // Verify stationary fast-path works while 2nd-layer sheet is open (zero idle repaints).
        await tester.pump(const Duration(milliseconds: 16));
        await tester.pump(const Duration(milliseconds: 16));
        final CustomPainter idleSheetPainter =
            tester.widget<CustomPaint>(ringFinder).painter!;
        expect(idleSheetPainter.shouldRepaint(settledSheetPainter), isFalse);

        // 3. Step Down across 2nd-layer replies: 2nd-layer scrolls while 1st-layer
        //    scroll offset stays strictly unchanged.
        for (int i = 0; i <= 5; i++) {
          await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
          await tester.pumpAndSettle();
          expect(
            replyNodes[i].hasPrimaryFocus,
            isTrue,
            reason: 'Expected D-pad Down step $i to focus 2nd-layer Reply #$i',
          );
          expect(
            firstLayerScrollController.offset,
            equals(savedFirstLayerOffset),
            reason: '1st-layer scroll controller must never scroll while occluded',
          );
        }
        expect(secondLayerScrollController.offset, greaterThan(0.0));

        // 4. Step Up all the way to the top of 2nd-layer 评论详情: stops at
        //    secondLayerCloseNode and NEVER leaks to occluded 1st-layer TabBar.
        for (int i = 4; i >= 0; i--) {
          await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
          await tester.pumpAndSettle();
          expect(replyNodes[i].hasPrimaryFocus, isTrue);
        }
        await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
        await tester.pumpAndSettle();
        expect(secondLayerCloseNode.hasPrimaryFocus, isTrue);
        await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
        await tester.pumpAndSettle();
        expect(secondLayerCloseNode.hasPrimaryFocus, isTrue);
        expect(tabCommentNode.hasPrimaryFocus, isFalse);

        // 5. Cross-pane D-pad Left -> left column -> D-pad Right returns into
        //    visible 2nd-layer 评论详情 (never onto occluded 1st-layer items).
        await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
        await tester.pumpAndSettle();
        expect(replyNodes[0].hasPrimaryFocus, isTrue);
        await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
        await tester.pumpAndSettle();
        expect(replyNodes[1].hasPrimaryFocus, isTrue);

        await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
        await tester.pumpAndSettle();
        expect(
          playerFullscreenNode.hasPrimaryFocus || introActionNode.hasPrimaryFocus,
          isTrue,
        );

        await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
        await tester.pumpAndSettle();
        expect(
          replyNodes.any((n) => n.hasPrimaryFocus) ||
              secondLayerCloseNode.hasPrimaryFocus,
          isTrue,
          reason: 'Returning Right must land inside visible 2nd-layer sheet',
        );
        expect(commentNodes.any((n) => n.hasPrimaryFocus), isFalse);

        // 6. Focus Reply #1 in 2nd layer and press Select to open nested 3rd-layer 对话列表.
        if (!replyNodes[1].hasPrimaryFocus) {
          replyNodes[1].requestFocus();
          await tester.pumpAndSettle();
        }
        expect(replyNodes[1].hasPrimaryFocus, isTrue);

        await tester.sendKeyEvent(LogicalKeyboardKey.select);
        await tester.pumpAndSettle();
        expect(thirdLayerCloseNode.hasPrimaryFocus, isTrue);
        expect(
          TvFocusTraversalPolicy.isEffectivelyFocusable(replyNodes[1]),
          isFalse,
          reason: '2nd-layer Reply #1 must be occluded while 3rd-layer 对话列表 is open',
        );
        expect(
          TvFocusTraversalPolicy.isEffectivelyFocusable(commentNodes[3]),
          isFalse,
        );

        await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
        await tester.pumpAndSettle();
        expect(dialogueNodes[0].hasPrimaryFocus, isTrue);

        // 7. Press Back to close 3rd-layer 对话列表 -> restores exact 2nd-layer Reply #1.
        await tester.binding.handlePopRoute();
        await tester.pumpAndSettle();
        expect(replyNodes[1].hasPrimaryFocus, isTrue);
        expectSameFocusRect(
          (tester.widget<CustomPaint>(ringFinder).painter! as dynamic).rect
              as Rect?,
          replyNodes[1].rect,
        );

        // 8. Press Back to close 2nd-layer 评论详情 -> restores exact 1st-layer Comment #3.
        await tester.binding.handlePopRoute();
        await tester.pumpAndSettle();
        expect(commentNodes[3].hasPrimaryFocus, isTrue);
        expect(firstLayerScrollController.offset, equals(savedFirstLayerOffset));
        expectSameFocusRect(
          (tester.widget<CustomPaint>(ringFinder).painter! as dynamic).rect
              as Rect?,
          commentNodes[3].rect,
        );
      },
    );

    testWidgets(
      'MiniScaffold handles cross-column Enter trigger (选集 / AI总结), enableDrag: false Opacity sheet, and in-place sheet replacement while preserving saved focus (M9)',
      (tester) async {
        tester.view.physicalSize = const Size(960, 540);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        final miniScaffoldKey = GlobalKey<MiniScaffoldState>();
        final aiSummaryBtnNode = FocusNode(debugLabel: 'left_ai_summary_btn');
        final episodeBtnNode = FocusNode(debugLabel: 'left_episode_btn');
        final bodyCommentNode = FocusNode(debugLabel: 'right_body_comment_0');
        final aiSheetItemNode = FocusNode(debugLabel: 'ai_sheet_item_0');
        final episodeSheetItemNode = FocusNode(
          debugLabel: 'episode_sheet_item_0',
        );
        addTearDown(() {
          aiSummaryBtnNode.dispose();
          episodeBtnNode.dispose();
          bodyCommentNode.dispose();
          aiSheetItemNode.dispose();
          episodeSheetItemNode.dispose();
        });

        void openAiSheet() {
          miniScaffoldKey.currentState!.showBottomSheet(
            enableDrag: false,
            constraints: const BoxConstraints(),
            (context) => ColoredBox(
              color: Colors.grey.shade900,
              child: Center(
                child: ElevatedButton(
                  focusNode: aiSheetItemNode,
                  onPressed: () {},
                  child: const Text('AI总结内容'),
                ),
              ),
            ),
          );
        }

        void openEpisodeSheet() {
          miniScaffoldKey.currentState!.showBottomSheet(
            constraints: const BoxConstraints(),
            (context) => ColoredBox(
              color: Colors.grey.shade800,
              child: Center(
                child: ElevatedButton(
                  focusNode: episodeSheetItemNode,
                  onPressed: () {},
                  child: const Text('选集 P1'),
                ),
              ),
            ),
          );
        }

        await tester.pumpWidget(
          GetMaterialApp(
            builder: (context, child) => TvNavigation(child: child!),
            home: Scaffold(
              body: Row(
                children: [
                  SizedBox(
                    width: 560,
                    height: 540,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        ElevatedButton(
                          focusNode: aiSummaryBtnNode,
                          autofocus: true,
                          onPressed: openAiSheet,
                          child: const Text('AI总结'),
                        ),
                        const SizedBox(height: 16),
                        ElevatedButton(
                          focusNode: episodeBtnNode,
                          onPressed: openEpisodeSheet,
                          child: const Text('选集'),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(
                    width: 400,
                    height: 540,
                    child: MiniScaffold(
                      key: miniScaffoldKey,
                      body: Center(
                        child: ElevatedButton(
                          focusNode: bodyCommentNode,
                          onPressed: openAiSheet,
                          child: const Text('1st Layer Comment'),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(aiSummaryBtnNode.hasPrimaryFocus, isTrue);

        // 1. Press Enter on left-column AI总结 button (ElevatedButton consumes Enter
        //    before Focus.onKeyEvent bubbles) -> opens right-column enableDrag: false
        //    sheet and promotes focus into aiSheetItemNode.
        await tester.sendKeyEvent(LogicalKeyboardKey.enter);
        await tester.pumpAndSettle();
        expect(aiSheetItemNode.hasPrimaryFocus, isTrue);
        expect(
          TvFocusTraversalPolicy.isEffectivelyFocusable(bodyCommentNode),
          isFalse,
        );

        // Back restores focus to left-column AI总结 button.
        await tester.binding.handlePopRoute();
        await tester.pumpAndSettle();
        expect(aiSummaryBtnNode.hasPrimaryFocus, isTrue);

        // 2. Focus right-column bodyCommentNode, open AI sheet, then replace it
        //    in-place with Episode sheet -> promotes to episodeSheetItemNode and
        //    Back restores original bodyCommentNode.
        bodyCommentNode.requestFocus();
        await tester.pumpAndSettle();
        expect(bodyCommentNode.hasPrimaryFocus, isTrue);

        await tester.sendKeyEvent(LogicalKeyboardKey.select);
        await tester.pumpAndSettle();
        expect(aiSheetItemNode.hasPrimaryFocus, isTrue);

        openEpisodeSheet();
        await tester.pumpAndSettle();
        expect(episodeSheetItemNode.hasPrimaryFocus, isTrue);

        await tester.binding.handlePopRoute();
        await tester.pumpAndSettle();
        expect(bodyCommentNode.hasPrimaryFocus, isTrue);
      },
    );

    testWidgets(
      'MiniScaffold handles same-frame requestFocus + noAnimation showBottomSheet and recovers into MiniScaffold.body if saved node was deleted (M9)',
      (tester) async {
        tester.view.physicalSize = const Size(960, 540);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        final miniScaffoldKey = GlobalKey<MiniScaffoldState>();
        final leftPlayerNode = FocusNode(debugLabel: 'left_player');
        final comment0Node = FocusNode(debugLabel: 'body_comment_0');
        final comment1Node = FocusNode(debugLabel: 'body_comment_1');
        final sheetItemNode = FocusNode(debugLabel: 'instant_sheet_item');
        bool includeSecondComment = true;
        late StateSetter rebuildBody;

        addTearDown(() {
          leftPlayerNode.dispose();
          comment0Node.dispose();
          comment1Node.dispose();
          sheetItemNode.dispose();
        });

        await tester.pumpWidget(
          GetMaterialApp(
            builder: (context, child) => TvNavigation(child: child!),
            home: Scaffold(
              body: Row(
                children: [
                  SizedBox(
                    width: 560,
                    height: 540,
                    child: Center(
                      child: ElevatedButton(
                        focusNode: leftPlayerNode,
                        autofocus: true,
                        onPressed: () {},
                        child: const Text('Player'),
                      ),
                    ),
                  ),
                  SizedBox(
                    width: 400,
                    height: 540,
                    child: MiniScaffold(
                      key: miniScaffoldKey,
                      body: StatefulBuilder(
                        builder: (context, setState) {
                          rebuildBody = setState;
                          return Column(
                            children: [
                              SizedBox(
                                height: 80,
                                child: ElevatedButton(
                                  focusNode: comment0Node,
                                  onPressed: () {},
                                  child: const Text('Comment 0'),
                                ),
                              ),
                              if (includeSecondComment)
                                SizedBox(
                                  height: 80,
                                  child: ElevatedButton(
                                    focusNode: comment1Node,
                                    onPressed: () {},
                                    child: const Text('Comment 1'),
                                  ),
                                ),
                            ],
                          );
                        },
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(leftPlayerNode.hasPrimaryFocus, isTrue);

        // Same-frame programmatic focus on comment1Node + instant noAnimation sheet open.
        comment1Node.requestFocus();
        miniScaffoldKey.currentState!.showBottomSheet(
          sheetAnimationStyle: AnimationStyle.noAnimation,
          constraints: const BoxConstraints(),
          (context) => ColoredBox(
            color: Colors.black,
            child: Center(
              child: ElevatedButton(
                focusNode: sheetItemNode,
                onPressed: Get.back,
                child: const Text('Instant Sheet Action'),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(sheetItemNode.hasPrimaryFocus, isTrue);

        // Delete/unmount the saved 1st-layer comment1Node while the sheet is open.
        rebuildBody(() {
          includeSecondComment = false;
        });
        await tester.pump();

        // Close the sheet -> focus must recover to remaining comment0Node inside
        // MiniScaffold.body rather than jumping to leftPlayerNode.
        await tester.binding.handlePopRoute();
        await tester.pumpAndSettle();
        expect(comment0Node.hasPrimaryFocus, isTrue);
        expect(leftPlayerNode.hasPrimaryFocus, isFalse);
      },
    );

    testWidgets(
      'MiniScaffold async-loading sheet (HorizontalMemberPage pattern) promotes focus when focusables mount after animation completes, without idle frame spin, unless user manually moved focus (M9)',
      (tester) async {
        tester.view.physicalSize = const Size(960, 540);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        final miniScaffoldKey = GlobalKey<MiniScaffoldState>();
        final leftFullscreenNode = FocusNode(debugLabel: 'left_fullscreen');
        final upOwnerNode = FocusNode(debugLabel: 'left_up_owner');
        final bodyCommentNode = FocusNode(debugLabel: 'body_comment');
        final followBtnNode = FocusNode(debugLabel: 'member_follow_btn');
        final homeBtnNode = FocusNode(debugLabel: 'member_home_btn');

        addTearDown(() {
          leftFullscreenNode.dispose();
          upOwnerNode.dispose();
          bodyCommentNode.dispose();
          followBtnNode.dispose();
          homeBtnNode.dispose();
        });

        bool sheetLoaded = false;
        StateSetter? setSheetState;

        void openAsyncMemberSheet() {
          sheetLoaded = false;
          miniScaffoldKey.currentState!.showBottomSheet(
            constraints: const BoxConstraints(),
            (context) => StatefulBuilder(
              builder: (context, setState) {
                setSheetState = setState;
                return ColoredBox(
                  color: Colors.grey.shade900,
                  child: sheetLoaded
                      ? Column(
                          children: [
                            const SizedBox(height: 16),
                            FilledButton(
                              focusNode: followBtnNode,
                              onPressed: () {},
                              child: const Text('关注'),
                            ),
                            const SizedBox(height: 12),
                            OutlinedButton(
                              focusNode: homeBtnNode,
                              onPressed: () {},
                              child: const Text('查看主页'),
                            ),
                          ],
                        )
                      : const Center(
                          child: SizedBox(
                            width: 36,
                            height: 36,
                            child: CircularProgressIndicator(value: 0.4),
                          ),
                        ),
                );
              },
            ),
          );
        }

        await tester.pumpWidget(
          GetMaterialApp(
            builder: (context, child) => TvNavigation(child: child!),
            home: Scaffold(
              body: Row(
                children: [
                  SizedBox(
                    width: 560,
                    height: 540,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        ElevatedButton(
                          focusNode: leftFullscreenNode,
                          onPressed: () {},
                          child: const Text('全屏'),
                        ),
                        const SizedBox(height: 24),
                        InkWell(
                          focusNode: upOwnerNode,
                          autofocus: true,
                          onTap: openAsyncMemberSheet,
                          child: const Padding(
                            padding: EdgeInsets.all(12),
                            child: Text('UP主: 尴尬的铁根er'),
                          ),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(
                    width: 400,
                    height: 540,
                    child: MiniScaffold(
                      key: miniScaffoldKey,
                      body: Center(
                        child: ElevatedButton(
                          focusNode: bodyCommentNode,
                          onPressed: () {},
                          child: const Text('1st Layer Comment'),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(upOwnerNode.hasPrimaryFocus, isTrue);

        // 1. Click UP owner card -> opens HorizontalMemberPage in loading state
        //    past the 250ms StandardBottomSheet open animation (pumpAndSettle
        //    also verifies zero infinite frame spin while sheetLoaded == false).
        await tester.sendKeyEvent(LogicalKeyboardKey.select);
        await tester.pumpAndSettle();

        expect(
          TvFocusTraversalPolicy.isEffectivelyFocusable(bodyCommentNode),
          isFalse,
        );
        // Zero idle frame spin while waiting for async HTTP response.
        expect(tester.binding.hasScheduledFrame, isFalse);

        // HTTP finishes and mounts [关注] + [查看主页] -> focus promotes to [关注]!
        setSheetState!(() {
          sheetLoaded = true;
        });
        await tester.pump();
        await tester.pump();
        expect(followBtnNode.hasPrimaryFocus, isTrue);

        // Back closes HorizontalMemberPage and restores UP owner card focus.
        await tester.binding.handlePopRoute();
        await tester.pumpAndSettle();
        expect(upOwnerNode.hasPrimaryFocus, isTrue);

        // 2. Re-open loading sheet, manually navigate Up to [全屏] BEFORE async
        //    data arrives -> async mount must respect user's manual navigation.
        await tester.sendKeyEvent(LogicalKeyboardKey.select);
        await tester.pumpAndSettle();

        await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
        await tester.pump();
        expect(leftFullscreenNode.hasPrimaryFocus, isTrue);

        setSheetState!(() {
          sheetLoaded = true;
        });
        await tester.pump();
        await tester.pump();
        expect(leftFullscreenNode.hasPrimaryFocus, isTrue);
        expect(followBtnNode.hasPrimaryFocus, isFalse);

        await tester.binding.handlePopRoute();
        await tester.pumpAndSettle();
        expect(upOwnerNode.hasPrimaryFocus, isTrue);
      },
    );

    testWidgets(
      'MiniScaffold async-triggered & programmatic external sheets (_aiBtn / showMediaListPanel pattern) promote focus after delayed Future and restore trigger on Back (M9)',
      (tester) async {
        tester.view.physicalSize = const Size(960, 540);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        final miniScaffoldKey = GlobalKey<MiniScaffoldState>();
        final aiAsyncBtnNode = FocusNode(debugLabel: 'left_ai_async_btn');
        final bodyCommentNode = FocusNode(debugLabel: 'body_comment');
        final aiSheetCloseNode = FocusNode(debugLabel: 'ai_sheet_close');
        final programmaticSheetNode = FocusNode(
          debugLabel: 'programmatic_sheet_btn',
        );

        addTearDown(() {
          aiAsyncBtnNode.dispose();
          bodyCommentNode.dispose();
          aiSheetCloseNode.dispose();
          programmaticSheetNode.dispose();
        });

        void openProgrammaticSheet() {
          miniScaffoldKey.currentState!.showBottomSheet(
            enableDrag: false,
            constraints: const BoxConstraints(),
            (context) => ColoredBox(
              color: Colors.grey.shade900,
              child: Center(
                child: ElevatedButton(
                  focusNode: programmaticSheetNode,
                  onPressed: Get.back,
                  child: const Text('选集 #1'),
                ),
              ),
            ),
          );
        }

        await tester.pumpWidget(
          GetMaterialApp(
            builder: (context, child) => TvNavigation(child: child!),
            home: Scaffold(
              body: Row(
                children: [
                  SizedBox(
                    width: 560,
                    height: 540,
                    child: Center(
                      child: ElevatedButton(
                        focusNode: aiAsyncBtnNode,
                        autofocus: true,
                        onPressed: () async {
                          await Future<void>.delayed(
                            const Duration(milliseconds: 450),
                          );
                          miniScaffoldKey.currentState?.showBottomSheet(
                            enableDrag: false,
                            constraints: const BoxConstraints(),
                            (context) => ColoredBox(
                              color: Colors.grey.shade900,
                              child: Center(
                                child: IconButton(
                                  focusNode: aiSheetCloseNode,
                                  icon: const Icon(Icons.close),
                                  onPressed: Get.back,
                                ),
                              ),
                            ),
                          );
                        },
                        child: const Text('AI视频总结'),
                      ),
                    ),
                  ),
                  SizedBox(
                    width: 400,
                    height: 540,
                    child: MiniScaffold(
                      key: miniScaffoldKey,
                      body: Center(
                        child: ElevatedButton(
                          focusNode: bodyCommentNode,
                          onPressed: () {},
                          child: const Text('1st Layer Comment'),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(aiAsyncBtnNode.hasPrimaryFocus, isTrue);

        // 1. Programmatic external showBottomSheet WITHOUT any Select key press
        //    (detected via ModalRoute.willHandlePopInternally transition).
        openProgrammaticSheet();
        await tester.pumpAndSettle();
        expect(programmaticSheetNode.hasPrimaryFocus, isTrue);

        await tester.binding.handlePopRoute();
        await tester.pumpAndSettle();
        expect(aiAsyncBtnNode.hasPrimaryFocus, isTrue);

        // 2. Press Select on _aiBtn -> awaits 450ms HTTP Future (> 25 frames)
        //    before calling showBottomSheet -> promotes focus into AI sheet.
        await tester.sendKeyEvent(LogicalKeyboardKey.select);
        await tester.pump(const Duration(milliseconds: 100));
        expect(aiAsyncBtnNode.hasPrimaryFocus, isTrue);

        await tester.pump(const Duration(milliseconds: 400));
        await tester.pumpAndSettle();
        expect(aiSheetCloseNode.hasPrimaryFocus, isTrue);

        await tester.binding.handlePopRoute();
        await tester.pumpAndSettle();
        expect(aiAsyncBtnNode.hasPrimaryFocus, isTrue);
      },
    );

    testWidgets(
      'MiniScaffold zero-focusable sheet immediately unfocuses occluded GestureDetector, avoids hijacking focus to left column or spinning idle frames, and restores trigger on Back (M9)',
      (tester) async {
        tester.view.physicalSize = const Size(960, 540);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        final miniScaffoldKey = GlobalKey<MiniScaffoldState>();
        final leftFullscreenNode = FocusNode(debugLabel: 'left_fullscreen');
        int occludedGestureTaps = 0;

        addTearDown(leftFullscreenNode.dispose);

        void openZeroFocusableSheet() {
          miniScaffoldKey.currentState!.showBottomSheet(
            enableDrag: false,
            constraints: const BoxConstraints(),
            (context) => const ColoredBox(
              color: Colors.black,
              child: Center(child: Text('Zero Focusables')),
            ),
          );
        }

        await tester.pumpWidget(
          GetMaterialApp(
            builder: (context, child) => TvNavigation(child: child!),
            home: Scaffold(
              body: Row(
                children: [
                  SizedBox(
                    width: 560,
                    height: 540,
                    child: Center(
                      child: ElevatedButton(
                        focusNode: leftFullscreenNode,
                        onPressed: () {},
                        child: const Text('全屏'),
                      ),
                    ),
                  ),
                  SizedBox(
                    width: 400,
                    height: 540,
                    child: MiniScaffold(
                      key: miniScaffoldKey,
                      body: Center(
                        child: GestureDetector(
                          onTap: () {
                            occludedGestureTaps++;
                            openZeroFocusableSheet();
                          },
                          child: const SizedBox(
                            width: 180,
                            height: 60,
                            child: Center(child: Text('Image Thumbnail')),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Move focus from leftFullscreenNode to right-column GestureDetector.
        await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
        await tester.pumpAndSettle();
        expect(leftFullscreenNode.hasPrimaryFocus, isFalse);

        // Press Select once to open the zero-focusable sheet.
        await tester.sendKeyEvent(LogicalKeyboardKey.select);
        await tester.pump();
        expect(occludedGestureTaps, 1);

        // Mid-animation Select must NOT activate the occluded GestureDetector!
        await tester.pump(const Duration(milliseconds: 50));
        await tester.sendKeyEvent(LogicalKeyboardKey.select);
        await tester.pump();
        expect(occludedGestureTaps, 1);

        // Settle animation -> must NOT hijack focus to leftFullscreenNode,
        // must NOT activate occluded GestureDetector on Select, and must NOT
        // schedule idle frames.
        await tester.pump(const Duration(milliseconds: 350));
        await tester.pump();
        expect(leftFullscreenNode.hasPrimaryFocus, isFalse);
        expect(tester.binding.hasScheduledFrame, isFalse);

        await tester.sendKeyEvent(LogicalKeyboardKey.select);
        await tester.pump();
        expect(occludedGestureTaps, 1);
        expect(leftFullscreenNode.hasPrimaryFocus, isFalse);

        // Explicit D-pad Left still allows reaching the left column.
        await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
        await tester.pump();
        expect(leftFullscreenNode.hasPrimaryFocus, isTrue);

        // Back closes the zero-focusable sheet and restores focus to the
        // right-column GestureDetector thumbnail.
        await tester.binding.handlePopRoute();
        await tester.pumpAndSettle();
        expect(leftFullscreenNode.hasPrimaryFocus, isFalse);

        await tester.sendKeyEvent(LogicalKeyboardKey.select);
        await tester.pump();
        expect(occludedGestureTaps, 2);
      },
    );

    testWidgets(
      'ReplyItemGrpc pattern: D-pad Right steps into 回复 / 查看对话 / 点赞 to open 3rd-layer 对话列表 and 跳转回复 while preserving 1-card vertical steps and grid neighbors (M9)',
      (tester) async {
        tester.view.physicalSize = const Size(960, 540);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        final outerMiniScaffoldKey = GlobalKey<MiniScaffoldState>();
        final innerMiniScaffoldKey = GlobalKey<MiniScaffoldState>();
        final leftFullscreenNode = FocusNode(debugLabel: 'left_fullscreen');
        final gridLeftCardNode = FocusNode(debugLabel: 'grid_left_card');
        final gridLeftEmbeddedBtnNode = FocusNode(
          debugLabel: 'grid_left_embedded_btn',
        );
        final firstLayerCommentNode = FocusNode(debugLabel: 'first_comment');
        final secondCloseNode = FocusNode(debugLabel: 'second_close');
        final replyCardNodes = List<FocusNode>.generate(
          3,
          (i) => FocusNode(debugLabel: 'reply_card_$i'),
        );
        final replyHeaderNodes = List<FocusNode>.generate(
          3,
          (i) => FocusNode(debugLabel: 'reply_header_$i'),
        );
        final replyBtnNodes = List<FocusNode>.generate(
          3,
          (i) => FocusNode(debugLabel: 'reply_btn_$i'),
        );
        final viewDialogueBtnNode = FocusNode(debugLabel: 'view_dialogue_btn');
        final hateBtnNodes = List<FocusNode>.generate(
          3,
          (i) => FocusNode(debugLabel: 'hate_btn_$i'),
        );
        final likeBtnNodes = List<FocusNode>.generate(
          3,
          (i) => FocusNode(debugLabel: 'like_btn_$i'),
        );
        final thirdCloseNode = FocusNode(debugLabel: 'third_close');
        final thirdCardNode = FocusNode(debugLabel: 'third_card_0');
        final thirdReplyBtnNode = FocusNode(debugLabel: 'third_reply_btn');
        final jumpReplyBtnNode = FocusNode(debugLabel: 'jump_reply_btn');
        int jumpedToReplyCount = 0;

        addTearDown(() {
          leftFullscreenNode.dispose();
          gridLeftCardNode.dispose();
          gridLeftEmbeddedBtnNode.dispose();
          firstLayerCommentNode.dispose();
          secondCloseNode.dispose();
          for (final n in replyCardNodes) {
            n.dispose();
          }
          for (final n in replyHeaderNodes) {
            n.dispose();
          }
          for (final n in replyBtnNodes) {
            n.dispose();
          }
          viewDialogueBtnNode.dispose();
          for (final n in hateBtnNodes) {
            n.dispose();
          }
          for (final n in likeBtnNodes) {
            n.dispose();
          }
          thirdCloseNode.dispose();
          thirdCardNode.dispose();
          thirdReplyBtnNode.dispose();
          jumpReplyBtnNode.dispose();
        });

        void openThirdLayerDialogue() {
          innerMiniScaffoldKey.currentState!.showBottomSheet(
            constraints: const BoxConstraints(),
            (context) => ColoredBox(
              color: Colors.black,
              child: Column(
                children: [
                  SizedBox(
                    height: 45,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('对话列表'),
                        IconButton(
                          focusNode: thirdCloseNode,
                          icon: const Icon(Icons.close, size: 20),
                          onPressed: Get.back,
                        ),
                      ],
                    ),
                  ),
                  InkWell(
                    focusNode: thirdCardNode,
                    // Mirrors ReplyItemGrpc(replyLevel: 3): replyReply is null,
                    // so outer InkWell.onTap is a no-op closure.
                    onTap: () {},
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(12, 12, 8, 8),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(
                            height: 34,
                            child: Text('搞丢两个账号  10-09'),
                          ),
                          const Padding(
                            padding: EdgeInsets.symmetric(vertical: 8),
                            child: Text('回复 @想要fumo :给地球OL吗？'),
                          ),
                          Row(
                            children: [
                              const SizedBox(width: 36),
                              SizedBox(
                                height: 32,
                                child: TextButton(
                                  focusNode: thirdReplyBtnNode,
                                  onPressed: () {},
                                  child: const Text('回复'),
                                ),
                              ),
                              const SizedBox(width: 4),
                              SizedBox(
                                height: 32,
                                child: TextButton(
                                  focusNode: jumpReplyBtnNode,
                                  onPressed: () {
                                    jumpedToReplyCount++;
                                  },
                                  child: const Text('跳转回复'),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        }

        Widget buildReplyItemCard(int index) {
          return InkWell(
            focusNode: replyCardNodes[index],
            // Mirrors ReplyItemGrpc(replyLevel: 2): replyReply is null!
            onTap: () {},
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 12, 8, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Focus(
                    focusNode: replyHeaderNodes[index],
                    child: GestureDetector(
                      onTap: () {},
                      child: SizedBox(
                        width: 180,
                        height: 34,
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: Text('User #$index'),
                        ),
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Text('Second-layer reply content #$index'),
                  ),
                  Row(
                    children: [
                      const SizedBox(width: 36),
                      SizedBox(
                        height: 32,
                        child: TextButton(
                          focusNode: replyBtnNodes[index],
                          onPressed: () {},
                          child: const Text('回复'),
                        ),
                      ),
                      if (index == 1) ...[
                        const SizedBox(width: 4),
                        SizedBox(
                          height: 32,
                          child: TextButton(
                            focusNode: viewDialogueBtnNode,
                            onPressed: openThirdLayerDialogue,
                            child: const Text('查看对话'),
                          ),
                        ),
                      ],
                      const Spacer(),
                      SizedBox(
                        height: 32,
                        child: TextButton(
                          focusNode: hateBtnNodes[index],
                          onPressed: () {},
                          child: const Icon(Icons.thumb_down, size: 16),
                        ),
                      ),
                      SizedBox(
                        width: 72,
                        height: 32,
                        child: TextButton(
                          focusNode: likeBtnNodes[index],
                          onPressed: () {},
                          child: const Text('点赞 12.3万'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        }

        void openSecondLayerSheet() {
          outerMiniScaffoldKey.currentState!.showBottomSheet(
            constraints: const BoxConstraints(),
            (context) => ColoredBox(
              color: Colors.grey.shade900,
              child: MiniScaffold(
                key: innerMiniScaffoldKey,
                body: Column(
                  children: [
                    SizedBox(
                      height: 45,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('评论详情'),
                          IconButton(
                            focusNode: secondCloseNode,
                            icon: const Icon(Icons.close, size: 20),
                            onPressed: Get.back,
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: ListView.builder(
                        itemCount: 3,
                        itemBuilder: (context, index) =>
                            buildReplyItemCard(index),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }

        await tester.pumpWidget(
          GetMaterialApp(
            builder: (context, child) => TvNavigation(child: child!),
            home: Scaffold(
              body: Row(
                children: [
                  SizedBox(
                    width: 560,
                    height: 540,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        ElevatedButton(
                          focusNode: leftFullscreenNode,
                          onPressed: () {},
                          child: const Text('全屏'),
                        ),
                        const SizedBox(height: 24),
                        // Left-column InkWell card with an embedded TextButton
                        // AND a right-column neighbor: pressing Right must still
                        // cross to the right column rather than entering the
                        // embedded button!
                        InkWell(
                          focusNode: gridLeftCardNode,
                          onTap: () {},
                          child: SizedBox(
                            width: 300,
                            height: 110,
                            child: Align(
                              alignment: Alignment.bottomLeft,
                              child: SizedBox(
                                height: 32,
                                child: TextButton(
                                  focusNode: gridLeftEmbeddedBtnNode,
                                  onPressed: () {},
                                  child: const Text('Embedded Left Action'),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(
                    width: 400,
                    height: 540,
                    child: MiniScaffold(
                      key: outerMiniScaffoldKey,
                      body: Align(
                        alignment: Alignment.center,
                        child: SizedBox(
                          width: 380,
                          height: 110,
                          child: ElevatedButton(
                            focusNode: firstLayerCommentNode,
                            autofocus: true,
                            onPressed: openSecondLayerSheet,
                            child: const Text('1st Layer Comment'),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(firstLayerCommentNode.hasPrimaryFocus, isTrue);

        // Verify left-column card with external right neighbor crosses to right
        // column instead of getting trapped in its embedded button.
        gridLeftCardNode.requestFocus();
        await tester.pumpAndSettle();
        expect(gridLeftCardNode.hasPrimaryFocus, isTrue);
        await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
        await tester.pumpAndSettle();
        expect(firstLayerCommentNode.hasPrimaryFocus, isTrue);
        expect(gridLeftEmbeddedBtnNode.hasPrimaryFocus, isFalse);

        // Open 2nd-layer 评论详情 -> focuses close button -> Down steps 1 card per press!
        await tester.sendKeyEvent(LogicalKeyboardKey.select);
        await tester.pumpAndSettle();
        expect(secondCloseNode.hasPrimaryFocus, isTrue);

        await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
        await tester.pumpAndSettle();
        expect(replyCardNodes[0].hasPrimaryFocus, isTrue);

        await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
        await tester.pumpAndSettle();
        expect(replyCardNodes[1].hasPrimaryFocus, isTrue);

        // Right on Reply #1 steps across 回复 -> 查看对话 -> 点踩 -> 点赞 12.3万.
        await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
        await tester.pumpAndSettle();
        expect(replyBtnNodes[1].hasPrimaryFocus, isTrue);

        await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
        await tester.pumpAndSettle();
        expect(viewDialogueBtnNode.hasPrimaryFocus, isTrue);

        await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
        await tester.pumpAndSettle();
        expect(hateBtnNodes[1].hasPrimaryFocus, isTrue);

        await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
        await tester.pumpAndSettle();
        expect(likeBtnNodes[1].hasPrimaryFocus, isTrue);

        // Right at rightmost button stops at edge (does NOT jump to parent card).
        await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
        await tester.pumpAndSettle();
        expect(likeBtnNodes[1].hasPrimaryFocus, isTrue);

        // Step Left back to 查看对话 -> press Select -> opens 3rd-layer 对话列表!
        await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
        await tester.pumpAndSettle();
        await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
        await tester.pumpAndSettle();
        expect(viewDialogueBtnNode.hasPrimaryFocus, isTrue);

        await tester.sendKeyEvent(LogicalKeyboardKey.select);
        await tester.pumpAndSettle();
        expect(thirdCloseNode.hasPrimaryFocus, isTrue);

        // Down in 3rd-layer 对话列表 -> dialogue card -> Right -> 回复 -> Right -> 跳转回复.
        await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
        await tester.pumpAndSettle();
        expect(thirdCardNode.hasPrimaryFocus, isTrue);

        await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
        await tester.pumpAndSettle();
        expect(thirdReplyBtnNode.hasPrimaryFocus, isTrue);

        await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
        await tester.pumpAndSettle();
        expect(jumpReplyBtnNode.hasPrimaryFocus, isTrue);

        await tester.sendKeyEvent(LogicalKeyboardKey.select);
        await tester.pumpAndSettle();
        expect(jumpedToReplyCount, 1);

        // Back from 3rd-layer 对话列表 restores focus directly onto 查看对话!
        await tester.binding.handlePopRoute();
        await tester.pumpAndSettle();
        expect(viewDialogueBtnNode.hasPrimaryFocus, isTrue);

        // Down from 查看对话 steps directly to Reply #2's primary card (never
        // trapped on Reply #1's card or Reply #2's header GestureDetector).
        await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
        await tester.pumpAndSettle();
        expect(replyCardNodes[2].hasPrimaryFocus, isTrue);

        // Up returns to Reply #1's card -> Right -> 回复 -> Left returns to
        // Reply #1's card -> Left crosses to left column!
        await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
        await tester.pumpAndSettle();
        expect(replyCardNodes[1].hasPrimaryFocus, isTrue);

        await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
        await tester.pumpAndSettle();
        expect(replyBtnNodes[1].hasPrimaryFocus, isTrue);

        await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
        await tester.pumpAndSettle();
        expect(replyCardNodes[1].hasPrimaryFocus, isTrue);

        await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
        await tester.pumpAndSettle();
        expect(
          leftFullscreenNode.hasPrimaryFocus ||
              gridLeftCardNode.hasPrimaryFocus,
          isTrue,
        );

        // Back closes 2nd-layer 评论详情 and restores 1st-layer comment!
        await tester.binding.handlePopRoute();
        await tester.pumpAndSettle();
        expect(firstLayerCommentNode.hasPrimaryFocus, isTrue);
      },
    );

    testWidgets(
      'embedded IconButton micro-actions stepping and userMovedFocus retention across frames',
      (tester) async {
        final FocusNode sidebarNode = FocusNode(debugLabel: 'sidebarNode');
        final FocusNode cardNode = FocusNode(debugLabel: 'cardNode');
        final FocusNode iconBtn1Node = FocusNode(debugLabel: 'iconBtn1Node');
        final FocusNode iconBtn2Node = FocusNode(debugLabel: 'iconBtn2Node');
        final FocusNode sheetCloseNode = FocusNode(debugLabel: 'sheetCloseNode');
        final GlobalKey<MiniScaffoldState> miniScaffoldKey =
            GlobalKey<MiniScaffoldState>();

        addTearDown(() {
          sidebarNode.dispose();
          cardNode.dispose();
          iconBtn1Node.dispose();
          iconBtn2Node.dispose();
          sheetCloseNode.dispose();
        });

        void openSheet() {
          miniScaffoldKey.currentState!.showBottomSheet(
            constraints: const BoxConstraints(),
            (context) => ColoredBox(
              color: Colors.black87,
              child: SizedBox(
                height: 300,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Sheet Header'),
                    IconButton(
                      focusNode: sheetCloseNode,
                      icon: const Icon(Icons.close),
                      onPressed: Get.back,
                    ),
                  ],
                ),
              ),
            ),
          );
        }

        await tester.pumpWidget(
          GetMaterialApp(
            builder: (context, child) => TvNavigation(child: child!),
            home: Scaffold(
              body: Row(
                children: [
                  SizedBox(
                    width: 200,
                    child: ElevatedButton(
                      focusNode: sidebarNode,
                      onPressed: () {},
                      child: const Text('Sidebar'),
                    ),
                  ),
                  Expanded(
                    child: MiniScaffold(
                      key: miniScaffoldKey,
                      body: Center(
                        child: InkWell(
                          focusNode: cardNode,
                          onTap: openSheet,
                          child: Container(
                            width: 320,
                            height: 120,
                            padding: const EdgeInsets.all(8),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('Card with micro-actions'),
                                const Spacer(),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.end,
                                  children: [
                                    IconButton(
                                      focusNode: iconBtn1Node,
                                      icon: const Icon(Icons.thumb_up),
                                      onPressed: () {},
                                    ),
                                    const SizedBox(width: 8),
                                    IconButton(
                                      focusNode: iconBtn2Node,
                                      icon: const Icon(Icons.thumb_down),
                                      onPressed: () {},
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // 1. Verify stepping into and out of embedded IconButtons
        cardNode.requestFocus();
        await tester.pumpAndSettle();
        expect(cardNode.hasPrimaryFocus, isTrue);

        // Press Right -> steps into first embedded IconButton
        await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
        await tester.pumpAndSettle();
        expect(iconBtn1Node.hasPrimaryFocus, isTrue);

        // Press Right -> steps to second embedded IconButton
        await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
        await tester.pumpAndSettle();
        expect(iconBtn2Node.hasPrimaryFocus, isTrue);

        // Press Left -> steps back to first embedded IconButton
        await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
        await tester.pumpAndSettle();
        expect(iconBtn1Node.hasPrimaryFocus, isTrue);

        // Press Left -> steps back to the parent card
        await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
        await tester.pumpAndSettle();
        expect(cardNode.hasPrimaryFocus, isTrue);

        // 2. Open sheet -> focus promoted to sheetCloseNode
        await tester.sendKeyEvent(LogicalKeyboardKey.select);
        await tester.pumpAndSettle();
        expect(sheetCloseNode.hasPrimaryFocus, isTrue);

        // 3. Deliberately move focus to unoccluded sidebar
        await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
        await tester.pumpAndSettle();
        expect(sidebarNode.hasPrimaryFocus, isTrue);

        // Multiple frames / rebuilds while sheet remains open:
        // userMovedFocus must NOT be wiped out; focus must remain on sidebar
        for (int i = 0; i < 5; i++) {
          await tester.pump(const Duration(milliseconds: 50));
          expect(sidebarNode.hasPrimaryFocus, isTrue);
        }

        // 4. Press Back to close the sheet -> restores focus to cardNode
        await tester.binding.handlePopRoute();
        await tester.pumpAndSettle();
        expect(cardNode.hasPrimaryFocus, isTrue);
      },
    );

    testWidgets(
      'SliverPinnedHeader and SliverFloatingHeaderWidget do not hijack upward D-pad scrolling and half-scrolled cards do not leak initial focus to embedded buttons',
      (tester) async {
        final FocusNode closeNode = FocusNode(debugLabel: 'closeNode');
        final FocusNode firstFloorNode = FocusNode(debugLabel: 'firstFloor');
        final FocusNode firstFloorReplyBtn = FocusNode(
          debugLabel: 'firstFloorReplyBtn',
        );
        final FocusNode firstFloorLikeBtn = FocusNode(
          debugLabel: 'firstFloorLikeBtn',
        );
        final FocusNode pinnedSortNode = FocusNode(
          debugLabel: 'pinnedSortNode',
        );
        final List<FocusNode> replyCardNodes = List<FocusNode>.generate(
          5,
          (i) => FocusNode(debugLabel: 'replyCard_$i'),
        );
        final List<FocusNode> replyBtnNodes = List<FocusNode>.generate(
          5,
          (i) => FocusNode(debugLabel: 'replyBtn_$i'),
        );
        final List<FocusNode> likeBtnNodes = List<FocusNode>.generate(
          5,
          (i) => FocusNode(debugLabel: 'likeBtn_$i'),
        );
        final ScrollController scrollController = ScrollController();

        addTearDown(() {
          closeNode.dispose();
          firstFloorNode.dispose();
          firstFloorReplyBtn.dispose();
          firstFloorLikeBtn.dispose();
          pinnedSortNode.dispose();
          for (final n in replyCardNodes) {
            n.dispose();
          }
          for (final n in replyBtnNodes) {
            n.dispose();
          }
          for (final n in likeBtnNodes) {
            n.dispose();
          }
          scrollController.dispose();
        });

        Widget buildReplyCard({
          required FocusNode cardNode,
          required FocusNode replyBtnNode,
          required FocusNode likeBtnNode,
          required String title,
        }) {
          return InkWell(
            focusNode: cardNode,
            onTap: () {},
            child: SizedBox(
              height: 120,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 12, 8, 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title),
                    const Spacer(),
                    Row(
                      children: [
                        SizedBox(
                          height: 32,
                          child: TextButton(
                            focusNode: replyBtnNode,
                            onPressed: () {},
                            child: const Text('回复'),
                          ),
                        ),
                        const Spacer(),
                        SizedBox(
                          height: 32,
                          child: TextButton(
                            focusNode: likeBtnNode,
                            onPressed: () {},
                            child: const Text('点赞'),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          );
        }

        await tester.pumpWidget(
          GetMaterialApp(
            builder: (context, child) => TvNavigation(child: child!),
            home: Scaffold(
              body: Center(
                child: SizedBox(
                  width: 400,
                  height: 360,
                  child: Column(
                    children: [
                      SizedBox(
                        height: 45,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('评论详情'),
                            IconButton(
                              focusNode: closeNode,
                              autofocus: true,
                              icon: const Icon(Icons.close, size: 20),
                              onPressed: () {},
                            ),
                          ],
                        ),
                      ),
                      Expanded(
                        child: CustomScrollView(
                          controller: scrollController,
                          slivers: [
                            SliverToBoxAdapter(
                              child: buildReplyCard(
                                cardNode: firstFloorNode,
                                replyBtnNode: firstFloorReplyBtn,
                                likeBtnNode: firstFloorLikeBtn,
                                title: 'First floor comment',
                              ),
                            ),
                            SliverPinnedHeader(
                              child: ColoredBox(
                                color: Colors.black,
                                child: SizedBox(
                                  height: 36,
                                  child: Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      const Text('相关回复共5条'),
                                      SizedBox(
                                        height: 34,
                                        child: TextButton.icon(
                                          focusNode: pinnedSortNode,
                                          onPressed: () {},
                                          icon: const Icon(
                                            Icons.sort,
                                            size: 16,
                                          ),
                                          label: const Text('按热度'),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                            SliverList.builder(
                              itemCount: 5,
                              itemBuilder: (context, index) => buildReplyCard(
                                cardNode: replyCardNodes[index],
                                replyBtnNode: replyBtnNodes[index],
                                likeBtnNode: likeBtnNodes[index],
                                title: 'Reply #$index',
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
        );
        await tester.pumpAndSettle();
        expect(closeNode.hasPrimaryFocus, isTrue);

        // Step Down from closeNode -> firstFloor -> pinnedSortNode -> reply_0 -> reply_1 -> reply_2 -> reply_3.
        await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
        await tester.pumpAndSettle();
        expect(firstFloorNode.hasPrimaryFocus, isTrue);

        await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
        await tester.pumpAndSettle();
        expect(pinnedSortNode.hasPrimaryFocus, isTrue);

        for (int i = 0; i <= 3; i++) {
          await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
          await tester.pumpAndSettle();
          expect(replyCardNodes[i].hasPrimaryFocus, isTrue);
        }
        expect(scrollController.offset, greaterThan(150.0));

        // Now press Up repeatedly: must step reply_3 -> reply_2 -> reply_1 -> reply_0 -> pinnedSortNode -> firstFloor -> closeNode
        // without pinnedSortNode hijacking upward focus while scrolled down!
        for (int i = 2; i >= 0; i--) {
          await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
          await tester.pumpAndSettle();
          expect(
            replyCardNodes[i].hasPrimaryFocus,
            isTrue,
            reason: 'Expected replyCard_$i after pressing Up from reply_${i + 1}',
          );
          expect(pinnedSortNode.hasPrimaryFocus, isFalse);
        }

        await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
        await tester.pumpAndSettle();
        expect(pinnedSortNode.hasPrimaryFocus, isTrue);
        // Focusing pinnedSortNode must scroll CustomScrollView back to
        // precedingScrollExtent (120.0) so replyCard_0 is no longer occluded
        // behind the pinned header!
        expect(scrollController.offset, closeTo(120.0, 0.5));

        await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
        await tester.pumpAndSettle();
        expect(firstFloorNode.hasPrimaryFocus, isTrue);
        expect(scrollController.offset, closeTo(0.0, 0.5));

        await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
        await tester.pumpAndSettle();
        expect(closeNode.hasPrimaryFocus, isTrue);

        // Position scroll offset so firstFloorNode is half-scrolled off the top:
        // its vertical center (y = 60 in scroll coords) is above viewportTop (scrollOffset = 75),
        // while its bottom-row 回复 button (y = 80..112 in scroll coords) is still visible!
        scrollController.jumpTo(75.0);
        await tester.pumpAndSettle();

        final Element scrollViewElement = tester.element(
          find.byType(CustomScrollView),
        );
        final policy = TvFocusTraversalPolicy();
        final FocusNode? initialInList = policy.findFirstFocusInSubtree(
          scrollViewElement,
          FocusManager.instance.rootScope,
        );
        // Must pick a primary control (pinnedSortNode or replyCardNodes[0]),
        // NEVER firstFloorReplyBtn (an embedded secondary button of the half-scrolled card).
        expect(initialInList, isNot(equals(firstFloorReplyBtn)));
        expect(
          initialInList == pinnedSortNode || initialInList == replyCardNodes[0],
          isTrue,
        );

        // Also verify SliverFloatingHeaderWidget (used in 1st-layer VideoReplyPanel)
        // with an external TabBar (简介 / 评论) above it and a left-column control:
        // 1) Does not hijack upward D-pad traversal when floating back into view;
        // 2) Scrolls CustomScrollView back to 0.0 when floatingSortNode is focused;
        // 3) Exits upward from floatingSortNode to the external TabBar even if
        //    scrolled down when floatingSortNode is focused.
        final FocusNode leftPlayerNode = FocusNode(
          debugLabel: 'leftPlayerNode',
        );
        final FocusNode tabIntroNode = FocusNode(debugLabel: 'tabIntroNode');
        final FocusNode tabCommentNode = FocusNode(
          debugLabel: 'tabCommentNode',
        );
        final FocusNode floatingSortNode = FocusNode(
          debugLabel: 'floatingSortNode',
        );
        final List<FocusNode> commentNodes = List<FocusNode>.generate(
          5,
          (i) => FocusNode(debugLabel: 'comment_$i'),
        );
        final List<FocusNode> commentReplyBtns = List<FocusNode>.generate(
          5,
          (i) => FocusNode(debugLabel: 'commentReplyBtn_$i'),
        );
        final List<FocusNode> commentLikeBtns = List<FocusNode>.generate(
          5,
          (i) => FocusNode(debugLabel: 'commentLikeBtn_$i'),
        );
        final ScrollController floatingScrollController = ScrollController();
        addTearDown(() {
          leftPlayerNode.dispose();
          tabIntroNode.dispose();
          tabCommentNode.dispose();
          floatingSortNode.dispose();
          for (final n in commentNodes) {
            n.dispose();
          }
          for (final n in commentReplyBtns) {
            n.dispose();
          }
          for (final n in commentLikeBtns) {
            n.dispose();
          }
          floatingScrollController.dispose();
        });

        await tester.pumpWidget(
          GetMaterialApp(
            builder: (context, child) => TvNavigation(child: child!),
            home: Scaffold(
              body: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: 200,
                    height: 346,
                    child: Align(
                      alignment: const Alignment(0, -0.65),
                      child: ElevatedButton(
                        focusNode: leftPlayerNode,
                        onPressed: () {},
                        child: const Text('全屏'),
                      ),
                    ),
                  ),
                  SizedBox(
                    width: 400,
                    height: 346,
                    child: Column(
                      children: [
                        SizedBox(
                          height: 46,
                          child: Row(
                            children: [
                              Expanded(
                                child: InkWell(
                                  focusNode: tabIntroNode,
                                  onTap: () {},
                                  child: const Center(child: Text('简介')),
                                ),
                              ),
                              Expanded(
                                child: InkWell(
                                  focusNode: tabCommentNode,
                                  onTap: () {},
                                  child: const Center(child: Text('评论 100')),
                                ),
                              ),
                            ],
                          ),
                        ),
                        Expanded(
                          child: CustomScrollView(
                            controller: floatingScrollController,
                            slivers: [
                              SliverFloatingHeaderWidget(
                                backgroundColor: Colors.black,
                                child: SizedBox(
                                  height: 36,
                                  child: Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      const Text('100条回复'),
                                      SizedBox(
                                        height: 34,
                                        child: TextButton.icon(
                                          focusNode: floatingSortNode,
                                          autofocus: true,
                                          onPressed: () {},
                                          icon: const Icon(
                                            Icons.sort,
                                            size: 16,
                                          ),
                                          label: const Text('按热度'),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              SliverList.builder(
                                itemCount: 5,
                                itemBuilder: (context, index) => buildReplyCard(
                                  cardNode: commentNodes[index],
                                  replyBtnNode: commentReplyBtns[index],
                                  likeBtnNode: commentLikeBtns[index],
                                  title: 'Comment #$index',
                                ),
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
        );
        await tester.pumpAndSettle();
        expect(floatingSortNode.hasPrimaryFocus, isTrue);

        for (int i = 0; i <= 3; i++) {
          await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
          await tester.pumpAndSettle();
          expect(commentNodes[i].hasPrimaryFocus, isTrue);
        }
        expect(floatingScrollController.offset, greaterThan(150.0));

        for (int i = 2; i >= 0; i--) {
          await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
          await tester.pumpAndSettle();
          expect(
            commentNodes[i].hasPrimaryFocus,
            isTrue,
            reason:
                'Expected comment_$i after pressing Up from comment_${i + 1}',
          );
          expect(floatingSortNode.hasPrimaryFocus, isFalse);
        }

        await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
        await tester.pumpAndSettle();
        expect(floatingSortNode.hasPrimaryFocus, isTrue);
        // Focusing floatingSortNode must scroll CustomScrollView back to 0.0!
        expect(floatingScrollController.offset, closeTo(0.0, 0.5));

        // Pressing Up from floatingSortNode must exit CustomScrollView to the
        // external TabBar (tabCommentNode).
        await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
        await tester.pumpAndSettle();
        expect(tabCommentNode.hasPrimaryFocus, isTrue);

        // Even if floatingScrollController is scrolled down (e.g. 200px) while
        // floatingSortNode is focused, D-pad Up must still reach tabCommentNode,
        // D-pad Left must reach leftPlayerNode, and D-pad Down must reach the
        // visible comment below the floating header.
        floatingScrollController.jumpTo(200.0);
        await tester.pumpAndSettle();
        floatingSortNode.requestFocus();
        await tester.pump();
        expect(floatingSortNode.hasPrimaryFocus, isTrue);

        await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
        await tester.pumpAndSettle();
        expect(tabCommentNode.hasPrimaryFocus, isTrue);

        floatingScrollController.jumpTo(200.0);
        await tester.pumpAndSettle();
        floatingSortNode.requestFocus();
        await tester.pump();
        await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
        await tester.pumpAndSettle();
        expect(leftPlayerNode.hasPrimaryFocus, isTrue);

        floatingScrollController.jumpTo(200.0);
        await tester.pumpAndSettle();
        floatingSortNode.requestFocus();
        await tester.pump();
        await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
        await tester.pumpAndSettle();
        expect(commentNodes[2].hasPrimaryFocus, isTrue);

        // Also verify when SliverFloatingHeaderWidget is visibly floating in
        // the viewport at scrollOffset ~200 (after scrolling down to 240 and
        // dragging upward by 40px so effectiveScrollOffset == 0).
        floatingScrollController.jumpTo(240.0);
        await tester.pumpAndSettle();
        await tester.drag(
          find.byType(CustomScrollView).last,
          const Offset(0.0, 60.0),
        );
        await tester.pumpAndSettle();
        expect(floatingScrollController.offset, closeTo(200.0, 5.0));
        floatingSortNode.requestFocus();
        await tester.pump();
        await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
        await tester.pumpAndSettle();
        expect(leftPlayerNode.hasPrimaryFocus, isTrue);

        floatingSortNode.requestFocus();
        await tester.pump();
        await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
        await tester.pumpAndSettle();
        expect(tabCommentNode.hasPrimaryFocus, isTrue);

        floatingSortNode.requestFocus();
        await tester.pump();
        await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
        await tester.pumpAndSettle();
        expect(commentNodes[2].hasPrimaryFocus, isTrue);
      },
    );

    testWidgets(
      'compact item partially under SliverPinnedHeader can traverse Up to header and tall viewport-filling comment card receives primary focus',
      (tester) async {
        // Part 1: Compact reply item (height 50px) partially scrolled behind
        // SliverPinnedHeader (height 36px) so reply_0.bottom < pinnedHeader.boxRect.top + 36
        // and even when reply_0 is almost completely behind pinnedHeader, pressing
        // Up from reply_0 reaches pinnedSortNode without coordinate-space culling.
        final FocusNode firstFloorNode = FocusNode(debugLabel: 'firstFloor');
        final FocusNode pinnedSortNode = FocusNode(debugLabel: 'pinnedSort');
        final FocusNode compactReply0 = FocusNode(debugLabel: 'compactReply0');
        final FocusNode compactReply1 = FocusNode(debugLabel: 'compactReply1');
        final ScrollController scrollController = ScrollController();

        // Part 2: Tall root comment card (height 650px > 2x viewport height 300px)
        // with embedded secondary buttons at the top of CustomScrollView.
        final FocusNode leftButtonNode = FocusNode(debugLabel: 'leftButton');
        final FocusNode tallCardNode = FocusNode(debugLabel: 'tallCard');
        final FocusNode tallCardReplyBtn = FocusNode(
          debugLabel: 'tallCardReplyBtn',
        );
        final FocusNode tallCardLikeBtn = FocusNode(
          debugLabel: 'tallCardLikeBtn',
        );

        addTearDown(() {
          firstFloorNode.dispose();
          pinnedSortNode.dispose();
          compactReply0.dispose();
          compactReply1.dispose();
          scrollController.dispose();
          leftButtonNode.dispose();
          tallCardNode.dispose();
          tallCardReplyBtn.dispose();
          tallCardLikeBtn.dispose();
        });

        await tester.pumpWidget(
          GetMaterialApp(
            builder: (context, child) => TvNavigation(child: child!),
            home: Scaffold(
              body: SizedBox(
                width: 400,
                height: 300,
                child: CustomScrollView(
                  controller: scrollController,
                  slivers: [
                    SliverToBoxAdapter(
                      child: InkWell(
                        focusNode: firstFloorNode,
                        onTap: () {},
                        child: const SizedBox(
                          height: 120,
                          child: Text('First floor'),
                        ),
                      ),
                    ),
                    SliverPinnedHeader(
                      child: ColoredBox(
                        color: Colors.black,
                        child: SizedBox(
                          height: 36,
                          child: TextButton(
                            focusNode: pinnedSortNode,
                            onPressed: () {},
                            child: const Text('按热度'),
                          ),
                        ),
                      ),
                    ),
                    SliverToBoxAdapter(
                      child: InkWell(
                        focusNode: compactReply0,
                        onTap: () {},
                        child: const SizedBox(
                          height: 50,
                          child: Text('Compact Reply 0'),
                        ),
                      ),
                    ),
                    SliverToBoxAdapter(
                      child: InkWell(
                        focusNode: compactReply1,
                        onTap: () {},
                        child: const SizedBox(
                          height: 400,
                          child: Text('Reply 1'),
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

        // Scroll to 156.0 so pinnedSortNode is pinned at y = 0..36 (scroll-order y = -36..0)
        // and compactReply0 is at y = 0..50 (scroll-order y = 0..50).
        scrollController.jumpTo(156.0);
        await tester.pumpAndSettle();
        compactReply0.requestFocus();
        await tester.pumpAndSettle();
        expect(compactReply0.hasPrimaryFocus, isTrue);

        await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
        await tester.pumpAndSettle();
        expect(pinnedSortNode.hasPrimaryFocus, isTrue);
        expect(scrollController.offset, closeTo(120.0, 0.5));

        // Now test Part 2: Tall viewport-filling comment card (height 650px in
        // a 300px viewport) with an embedded 回复 button at y = 40..72 (inside viewport)
        // and a 点赞 button at the bottom.
        await tester.pumpWidget(
          GetMaterialApp(
            builder: (context, child) => TvNavigation(child: child!),
            home: Scaffold(
              body: Row(
                children: [
                  SizedBox(
                    width: 200,
                    height: 300,
                    child: Center(
                      child: ElevatedButton(
                        focusNode: leftButtonNode,
                        autofocus: true,
                        onPressed: () {},
                        child: const Text('左侧按钮'),
                      ),
                    ),
                  ),
                  SizedBox(
                    width: 400,
                    height: 300,
                    child: CustomScrollView(
                      slivers: [
                        SliverToBoxAdapter(
                          child: InkWell(
                            focusNode: tallCardNode,
                            onTap: () {},
                            child: SizedBox(
                              height: 650,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const SizedBox(height: 40),
                                  SizedBox(
                                    height: 32,
                                    child: TextButton(
                                      focusNode: tallCardReplyBtn,
                                      onPressed: () {},
                                      child: const Text('回复'),
                                    ),
                                  ),
                                  const Spacer(),
                                  SizedBox(
                                    height: 32,
                                    child: TextButton(
                                      focusNode: tallCardLikeBtn,
                                      onPressed: () {},
                                      child: const Text('点赞'),
                                    ),
                                  ),
                                ],
                              ),
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
        await tester.pumpAndSettle();
        expect(leftButtonNode.hasPrimaryFocus, isTrue);

        // Pressing D-pad Right from leftButtonNode into the CustomScrollView
        // must focus tallCardNode (the primary comment card filling 100% of the
        // viewport), NOT fail to enter the scrollable or land on tallCardReplyBtn.
        await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
        await tester.pumpAndSettle();
        expect(tallCardNode.hasPrimaryFocus, isTrue);

        // Also verify findFirstFocusInSubtree on the CustomScrollView picks
        // tallCardNode rather than tallCardReplyBtn.
        final Element tallScrollElement = tester.element(
          find.byType(CustomScrollView),
        );
        final FocusNode? firstInTall = TvFocusTraversalPolicy()
            .findFirstFocusInSubtree(
              tallScrollElement,
              FocusManager.instance.rootScope,
            );
        expect(firstInTall, equals(tallCardNode));
      },
    );
  });

  group('viewport follows the scaled root view (M10, R9)', () {
    setUp(() {
      TvPlatform.setTvModeForTesting(true);
    });

    tearDown(() {
      TvPlatform.setTvModeForTesting(false);
    });

    // ScaledWidgetsFlutterBinding lays the tree out in
    // `physicalSize / (devicePixelRatio * uiScale)`, while View.physicalSize and
    // View.devicePixelRatio stay the platform values. The tests model that by
    // giving the root RenderView a layout size that differs from
    // `physicalSize / devicePixelRatio` (1920x1080 here).
    Future<void> pumpScaledRoot(
      WidgetTester tester, {
      required Size layoutSize,
      required Map<FocusNode, Offset> buttons,
      required FocusNode autofocusNode,
    }) async {
      tester.view.physicalSize = const Size(1920, 1080);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.binding.setSurfaceSize(layoutSize);
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        MaterialApp(
          home: TvNavigation(
            child: Scaffold(
              body: Stack(
                clipBehavior: Clip.none,
                children: [
                  for (final MapEntry<FocusNode, Offset> entry
                      in buttons.entries)
                    Positioned(
                      left: entry.value.dx,
                      top: entry.value.dy,
                      width: 200,
                      height: 80,
                      child: ElevatedButton(
                        focusNode: entry.key,
                        autofocus: entry.key == autofocusNode,
                        onPressed: () {},
                        child: Text(entry.key.debugLabel ?? ''),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets(
      'uiScale < 1: controls in the right and bottom band beyond physicalSize / devicePixelRatio stay reachable',
      (tester) async {
        final top = FocusNode(debugLabel: 'top');
        final right = FocusNode(debugLabel: 'right');
        final bottom = FocusNode(debugLabel: 'bottom');
        addTearDown(() {
          top.dispose();
          right.dispose();
          bottom.dispose();
        });

        // uiScale 0.8: 1920x1080 / 0.8 = 2400x1350 of layout space.
        await pumpScaledRoot(
          tester,
          layoutSize: const Size(2400, 1350),
          buttons: {
            top: const Offset(100, 100),
            right: const Offset(2100, 100),
            bottom: const Offset(100, 1200),
          },
          autofocusNode: top,
        );
        expect(top.hasPrimaryFocus, isTrue);

        await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
        await tester.pumpAndSettle();
        expect(right.hasPrimaryFocus, isTrue);

        await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
        await tester.pumpAndSettle();
        expect(top.hasPrimaryFocus, isTrue);

        await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
        await tester.pumpAndSettle();
        expect(bottom.hasPrimaryFocus, isTrue);

        await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
        await tester.pumpAndSettle();
        expect(top.hasPrimaryFocus, isTrue);
      },
    );

    testWidgets(
      'uiScale < 1: focus on a control in the outer band is kept, not recovered away',
      (tester) async {
        final top = FocusNode(debugLabel: 'top');
        final right = FocusNode(debugLabel: 'right');
        addTearDown(() {
          top.dispose();
          right.dispose();
        });

        await pumpScaledRoot(
          tester,
          layoutSize: const Size(2400, 1350),
          buttons: {
            top: const Offset(100, 100),
            right: const Offset(2100, 100),
          },
          autofocusNode: right,
        );

        // The first frames after autofocus run focus recovery for unfocusable
        // nodes: focus must still be where it was put.
        expect(right.hasPrimaryFocus, isTrue);
        await tester.pump(const Duration(milliseconds: 200));
        expect(right.hasPrimaryFocus, isTrue);
      },
    );

    testWidgets(
      'uiScale > 1: controls beyond the layout space but inside physicalSize / devicePixelRatio are not reachable',
      (tester) async {
        final top = FocusNode(debugLabel: 'top');
        final offscreen = FocusNode(debugLabel: 'offscreen');
        addTearDown(() {
          top.dispose();
          offscreen.dispose();
        });

        // uiScale 1.25: 1920x1080 / 1.25 = 1536x864 of layout space, so a
        // control at x = 1700 is off screen even though 1700 < 1920.
        await pumpScaledRoot(
          tester,
          layoutSize: const Size(1536, 864),
          buttons: {
            top: const Offset(100, 100),
            offscreen: const Offset(1700, 100),
          },
          autofocusNode: top,
        );
        expect(top.hasPrimaryFocus, isTrue);

        await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
        await tester.pumpAndSettle();
        expect(offscreen.hasPrimaryFocus, isFalse);
        expect(top.hasPrimaryFocus, isTrue);
      },
    );

    testWidgets(
      'uiScale == 1: controls beyond the right edge stay unreachable',
      (tester) async {
        final top = FocusNode(debugLabel: 'top');
        final offscreen = FocusNode(debugLabel: 'offscreen');
        addTearDown(() {
          top.dispose();
          offscreen.dispose();
        });

        await pumpScaledRoot(
          tester,
          layoutSize: const Size(1920, 1080),
          buttons: {
            top: const Offset(100, 100),
            offscreen: const Offset(2000, 100),
          },
          autofocusNode: top,
        );
        expect(top.hasPrimaryFocus, isTrue);

        await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
        await tester.pumpAndSettle();
        expect(offscreen.hasPrimaryFocus, isFalse);
        expect(top.hasPrimaryFocus, isTrue);
      },
    );
  });

  group('inline sheet bookkeeping cost (M10, R13)', () {
    setUp(() {
      TvPlatform.setTvModeForTesting(true);
    });

    tearDown(() {
      TvPlatform.setTvModeForTesting(false);
    });

    testWidgets(
      'a sheet with nothing focusable is not re-walked every frame while it stays open',
      (tester) async {
        tester.view.physicalSize = const Size(960, 540);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        final miniScaffoldKey = GlobalKey<MiniScaffoldState>();
        final leftNode = FocusNode(debugLabel: 'left');
        final counter = _VisitCounter();
        addTearDown(leftNode.dispose);

        await tester.pumpWidget(
          GetMaterialApp(
            builder: (context, child) => TvNavigation(child: child!),
            home: Scaffold(
              body: Row(
                children: [
                  SizedBox(
                    width: 560,
                    height: 540,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        ElevatedButton(
                          focusNode: leftNode,
                          onPressed: () {},
                          child: const Text('全屏'),
                        ),
                        // Stands in for the video texture and danmaku: keeps a
                        // frame scheduled, as in a playing player.
                        const SizedBox(
                          width: 200,
                          child: LinearProgressIndicator(),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(
                    width: 400,
                    height: 540,
                    child: MiniScaffold(
                      key: miniScaffoldKey,
                      body: Center(
                        child: GestureDetector(
                          onTap: () {
                            miniScaffoldKey.currentState!.showBottomSheet(
                              enableDrag: false,
                              constraints: const BoxConstraints(),
                              (context) => _VisitCountingWidget(
                                counter: counter,
                                child: const ColoredBox(
                                  color: Colors.black,
                                  child: Center(child: Text('Zero Focusables')),
                                ),
                              ),
                            );
                          },
                          child: const SizedBox(
                            width: 180,
                            height: 60,
                            child: Center(child: Text('Image Thumbnail')),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
        await tester.pump(const Duration(milliseconds: 100));
        await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
        await tester.pump(const Duration(milliseconds: 100));
        await tester.sendKeyEvent(LogicalKeyboardKey.select);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 400));
        await tester.pump();
        expect(find.text('Zero Focusables'), findsOneWidget);

        // Sixty idle frames with the sheet open. Probing the sheet walks its
        // whole subtree, so the walks are counted through the sheet's content.
        counter.visits = 0;
        for (int i = 0; i < 60; i++) {
          await tester.pump(const Duration(milliseconds: 16));
        }
        expect(
          counter.visits,
          lessThan(10),
          reason: 'the sheet subtree was walked ${counter.visits} times in 60 frames',
        );
        expect(leftNode.hasPrimaryFocus, isFalse);

        // Back still closes the sheet.
        await tester.binding.handlePopRoute();
        for (int i = 0; i < 8; i++) {
          await tester.pump(const Duration(milliseconds: 100));
        }
        expect(find.text('Zero Focusables'), findsNothing);
      },
    );
  });

  group('route focus layers (M10: popup routes in the shared stack)', () {
    setUp(() {
      TvPlatform.setTvModeForTesting(true);
    });

    tearDown(() {
      TvPlatform.setTvModeForTesting(false);
    });

    testWidgets(
      'a popup menu opened inside a dialog hands focus back to the dialog control, then to the page control',
      (tester) async {
        final pageTile = FocusNode(debugLabel: 'pageTile');
        final dialogTile = FocusNode(debugLabel: 'dialogTile');
        addTearDown(() {
          pageTile.dispose();
          dialogTile.dispose();
        });

        await tester.pumpWidget(
          MaterialApp(
            builder: (context, child) => TvNavigation(child: child!),
            home: Builder(
              builder: (pageContext) => Scaffold(
                body: ListTile(
                  focusNode: pageTile,
                  autofocus: true,
                  title: const Text('页面项'),
                  onTap: () => showDialog<void>(
                    context: pageContext,
                    builder: (dialogContext) => AlertDialog(
                      content: ListTile(
                        focusNode: dialogTile,
                        title: const Text('对话框项'),
                        onTap: () => showMenu<int>(
                          context: dialogContext,
                          requestFocus: false,
                          position: const RelativeRect.fromLTRB(100, 100, 100, 100),
                          items: const [
                            PopupMenuItem<int>(value: 1, child: Text('菜单项1')),
                            PopupMenuItem<int>(value: 2, child: Text('菜单项2')),
                          ],
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
        expect(pageTile.hasPrimaryFocus, isTrue);

        bool onMenuItem(String label) {
          final FocusNode? primary = FocusManager.instance.primaryFocus;
          if (primary == null || primary is FocusScopeNode) return false;
          return find
              .descendant(
                of: find.byElementPredicate((e) => e == primary.context),
                matching: find.text(label),
              )
              .evaluate()
              .isNotEmpty;
        }

        // Page control -> dialog (its scope takes focus on its own).
        await tester.sendKeyEvent(LogicalKeyboardKey.select);
        await tester.pumpAndSettle();
        expect(find.text('对话框项'), findsOneWidget);
        expect(dialogTile.hasPrimaryFocus, isTrue);

        // Dialog control -> popup menu that never asks for focus.
        await tester.sendKeyEvent(LogicalKeyboardKey.select);
        await tester.pumpAndSettle();
        expect(find.text('菜单项1'), findsOneWidget);
        expect(onMenuItem('菜单项1'), isTrue);
        await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
        await tester.pumpAndSettle();
        expect(onMenuItem('菜单项2'), isTrue);

        // Closing the menu returns to the dialog control, not the page.
        await tester.sendKeyEvent(LogicalKeyboardKey.escape);
        await tester.pumpAndSettle();
        expect(find.text('菜单项1'), findsNothing);
        expect(find.text('对话框项'), findsOneWidget);
        expect(dialogTile.hasPrimaryFocus, isTrue);
        expect(pageTile.hasPrimaryFocus, isFalse);

        // Closing the dialog returns to the page control.
        await tester.sendKeyEvent(LogicalKeyboardKey.escape);
        await tester.pumpAndSettle();
        expect(find.text('对话框项'), findsNothing);
        expect(pageTile.hasPrimaryFocus, isTrue);
      },
    );

    // The player page is pushed over the home page and builds its controls a
    // while later. Until they exist, its scope is active while focus is still
    // behind it, which is what a popup that has not taken focus looks like.
    // A page takes focus itself, so it must not be held as a layer afterwards:
    // the sheet code parks focus on the scope while a sheet loads, and a layer
    // would read that as "focus left" and pull it to the page's first control.
    // Frames keep coming, as they do during playback.
    testWidgets(
      'a page pushed over another is not a focus layer: a sheet that is still loading holds focus instead of the page pulling it to its first control',
      (tester) async {
        tester.view.physicalSize = const Size(960, 540);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        final homeButton = FocusNode(debugLabel: 'home_button');
        final fullscreen = FocusNode(debugLabel: 'left_fullscreen');
        final trigger = FocusNode(debugLabel: 'comment_trigger');
        final follow = FocusNode(debugLabel: 'sheet_follow');
        final miniScaffoldKey = GlobalKey<MiniScaffoldState>();
        final ready = ValueNotifier<bool>(false);
        addTearDown(() {
          homeButton.dispose();
          fullscreen.dispose();
          trigger.dispose();
          follow.dispose();
          ready.dispose();
        });

        bool loaded = false;
        StateSetter? setSheetState;

        void openLoadingSheet() {
          loaded = false;
          miniScaffoldKey.currentState!.showBottomSheet(
            constraints: const BoxConstraints(),
            (context) => StatefulBuilder(
              builder: (context, setState) {
                setSheetState = setState;
                return ColoredBox(
                  color: Colors.grey.shade900,
                  child: loaded
                      ? Column(
                          children: [
                            FilledButton(
                              focusNode: follow,
                              onPressed: () {},
                              child: const Text('关注'),
                            ),
                          ],
                        )
                      : const Center(
                          child: SizedBox(
                            width: 36,
                            height: 36,
                            child: CircularProgressIndicator(value: 0.4),
                          ),
                        ),
                );
              },
            ),
          );
        }

        Widget videoPage() => Scaffold(
          body: ValueListenableBuilder<bool>(
            valueListenable: ready,
            builder: (context, isReady, _) => !isReady
                ? const SizedBox.expand()
                : Row(
                    children: [
                      SizedBox(
                        width: 560,
                        height: 540,
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            // Stands in for the video texture.
                            const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(),
                            ),
                            ElevatedButton(
                              focusNode: fullscreen,
                              onPressed: () {},
                              child: const Text('全屏'),
                            ),
                          ],
                        ),
                      ),
                      SizedBox(
                        width: 400,
                        height: 540,
                        child: MiniScaffold(
                          key: miniScaffoldKey,
                          // A comment card in the body, which the sheet covers.
                          body: Center(
                            child: InkWell(
                              focusNode: trigger,
                              onTap: openLoadingSheet,
                              child: const Padding(
                                padding: EdgeInsets.all(12),
                                child: Text('评论'),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
          ),
        );

        Future<void> pumpFrames(int count) async {
          for (int i = 0; i < count; i++) {
            await tester.pump(const Duration(milliseconds: 50));
          }
        }

        await tester.pumpWidget(
          GetMaterialApp(
            navigatorObservers: [TvNavigationObserver()],
            builder: (context, child) => TvNavigation(child: child!),
            home: Scaffold(
              body: Center(
                child: ElevatedButton(
                  focusNode: homeButton,
                  autofocus: true,
                  onPressed: () => Get.to<void>(videoPage),
                  child: const Text('打开视频页'),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(homeButton.hasPrimaryFocus, isTrue);

        // The page is pushed empty: nothing on it can take focus yet.
        await tester.sendKeyEvent(LogicalKeyboardKey.select);
        await pumpFrames(12);

        // Its controls arrive; focus goes to the first one, and the user then
        // moves on to the comment.
        ready.value = true;
        await pumpFrames(4);
        expect(fullscreen.hasPrimaryFocus, isTrue);
        await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
        await pumpFrames(2);
        expect(trigger.hasPrimaryFocus, isTrue);

        // The sheet opens with nothing to focus yet. Focus is held, not handed
        // to the first control of the page.
        await tester.sendKeyEvent(LogicalKeyboardKey.select);
        await pumpFrames(20);
        expect(fullscreen.hasPrimaryFocus, isFalse);
        expect(follow.hasPrimaryFocus, isFalse);

        // The content arrives and takes focus.
        setSheetState!(() {
          loaded = true;
        });
        await pumpFrames(2);
        expect(follow.hasPrimaryFocus, isTrue);

        // Back closes the sheet, then the page; each gives focus back.
        await tester.binding.handlePopRoute();
        await pumpFrames(12);
        expect(trigger.hasPrimaryFocus, isTrue);

        await tester.binding.handlePopRoute();
        await pumpFrames(12);
        expect(homeButton.hasPrimaryFocus, isTrue);
      },
    );

    testWidgets(
      'a popup menu opened on a pushed page still takes focus and hands it back to the control on that page',
      (tester) async {
        final homeButton = FocusNode(debugLabel: 'home_button');
        final pageTile = FocusNode(debugLabel: 'page_tile');
        addTearDown(() {
          homeButton.dispose();
          pageTile.dispose();
        });

        await tester.pumpWidget(
          GetMaterialApp(
            navigatorObservers: [TvNavigationObserver()],
            builder: (context, child) => TvNavigation(child: child!),
            home: Scaffold(
              body: Center(
                child: ElevatedButton(
                  focusNode: homeButton,
                  autofocus: true,
                  onPressed: () => Get.to<void>(
                    () => Builder(
                      builder: (pageContext) => Scaffold(
                        body: ListTile(
                          focusNode: pageTile,
                          autofocus: true,
                          title: const Text('页面项'),
                          onTap: () => showMenu<int>(
                            context: pageContext,
                            requestFocus: false,
                            position: const RelativeRect.fromLTRB(
                              100,
                              100,
                              100,
                              100,
                            ),
                            items: const [
                              PopupMenuItem<int>(
                                value: 1,
                                child: Text('菜单项1'),
                              ),
                              PopupMenuItem<int>(
                                value: 2,
                                child: Text('菜单项2'),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                  child: const Text('打开页面'),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        await tester.sendKeyEvent(LogicalKeyboardKey.select);
        await tester.pumpAndSettle();
        expect(pageTile.hasPrimaryFocus, isTrue);

        bool onMenuItem(String label) {
          final FocusNode? primary = FocusManager.instance.primaryFocus;
          if (primary == null || primary is FocusScopeNode) return false;
          return find
              .descendant(
                of: find.byElementPredicate((e) => e == primary.context),
                matching: find.text(label),
              )
              .evaluate()
              .isNotEmpty;
        }

        await tester.sendKeyEvent(LogicalKeyboardKey.select);
        await tester.pumpAndSettle();
        expect(find.text('菜单项1'), findsOneWidget);
        expect(onMenuItem('菜单项1'), isTrue);

        await tester.sendKeyEvent(LogicalKeyboardKey.escape);
        await tester.pumpAndSettle();
        expect(find.text('菜单项1'), findsNothing);
        expect(pageTile.hasPrimaryFocus, isTrue);

        await tester.binding.handlePopRoute();
        await tester.pumpAndSettle();
        expect(homeButton.hasPrimaryFocus, isTrue);
      },
    );
  });

  group('overlay dialogs outside the Navigator (M10, SmartDialog)', () {
    late FocusNode versionNode;
    late FocusNode otherNode;
    late FocusNode linkNode;
    late FocusNode cancelNode;
    late FocusNode updateNode;
    late FocusNode grantNode;

    setUp(() {
      TvPlatform.setTvModeForTesting(true);
      versionNode = FocusNode(debugLabel: 'version');
      otherNode = FocusNode(debugLabel: 'other');
      linkNode = FocusNode(debugLabel: 'link');
      cancelNode = FocusNode(debugLabel: 'cancel');
      updateNode = FocusNode(debugLabel: 'update');
      grantNode = FocusNode(debugLabel: 'grant');
      // Disposed while the test's FocusManager is still alive, as in the other
      // groups; a group-level tearDown runs too late for that.
      addTearDown(() {
        for (final FocusNode node in [
          versionNode,
          otherNode,
          linkNode,
          cancelNode,
          updateNode,
          grantNode,
        ]) {
          node.dispose();
        }
      });
    });

    tearDown(() {
      TvPlatform.setTvModeForTesting(false);
    });

    // Mirrors MyApp._builder: FlutterSmartDialog.init(builder: ...) passes the
    // builder a FlutterSmartDialog that wraps the Navigator, and TvNavigation
    // sits outside all of it, so overlay entries and the Navigator are
    // siblings below TvNavigation.
    Widget buildApp(Widget home) => MaterialApp(
      navigatorObservers: [FlutterSmartDialog.observer],
      builder: FlutterSmartDialog.init(
        builder: (BuildContext context, Widget? child) => TvNavigation(
          child: MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: TextScaler.noScaling),
            child: child!,
          ),
        ),
      ),
      home: home,
    );

    // An /about-like page: a tile that opens the dialog (after an awaited
    // Future, like Update.checkUpdate) and another tile below it.
    Widget aboutPage({
      Future<void> Function()? onVersionTap,
      bool autofocus = true,
    }) => Scaffold(
      body: ListView(
        children: [
          ListTile(
            focusNode: versionNode,
            autofocus: autofocus,
            title: const Text('版本'),
            // A ListTile without onTap is not focusable.
            onTap: onVersionTap ?? () {},
          ),
          ListTile(
            focusNode: otherNode,
            title: const Text('检查更新'),
            onTap: () {},
          ),
        ],
      ),
    );

    // The 🎉 发现新版本 dialog from lib/utils/update.dart.
    void showUpdateDialog() {
      SmartDialog.show<void>(
        animationType: SmartAnimationType.centerFade_otherSlide,
        builder: (context) => AlertDialog(
          title: const Text('🎉 发现新版本 '),
          content: SizedBox(
            height: 280,
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('v1.2.3', style: TextStyle(fontSize: 20)),
                  const SizedBox(height: 8),
                  const Text('release notes'),
                  TextButton(
                    focusNode: linkNode,
                    onPressed: () {},
                    child: const Text('点此查看完整更新(即commit)内容'),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              focusNode: cancelNode,
              onPressed: SmartDialog.dismiss,
              child: const Text('取消'),
            ),
            TextButton(
              focusNode: updateNode,
              onPressed: () {},
              child: const Text('更新'),
            ),
          ],
        ),
      );
    }

    // The storage-permission dialog from lib/utils/image_utils.dart: default
    // animation (scale) and a single button.
    void showPermissionDialog() {
      SmartDialog.show<void>(
        builder: (context) => AlertDialog(
          title: const Text('提示'),
          content: const Text('存储权限未授权'),
          actions: [
            TextButton(
              focusNode: grantNode,
              onPressed: SmartDialog.dismiss,
              child: const Text('去授权'),
            ),
          ],
        ),
      );
    }

    Future<void> pumpApp(WidgetTester tester, Widget home) async {
      tester.view.physicalSize = const Size(1280, 720);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(buildApp(home));
      await tester.pumpAndSettle();
    }

    Rect? ringRect(WidgetTester tester) {
      final Finder ring = find
          .descendant(
            of: find.byType(TvNavigation),
            matching: find.byType(CustomPaint),
          )
          .last;
      return (tester.widget<CustomPaint>(ring).painter! as dynamic).rect
          as Rect?;
    }

    void expectRingOn(WidgetTester tester, FocusNode node) {
      final Rect? ring = ringRect(tester);
      expect(ring, isNotNull, reason: 'no focus ring is shown');
      expect(ring!.left, closeTo(node.rect.left, 0.5));
      expect(ring.top, closeTo(node.rect.top, 0.5));
      expect(ring.right, closeTo(node.rect.right, 0.5));
      expect(ring.bottom, closeTo(node.rect.bottom, 0.5));
    }

    bool inDialog() =>
        linkNode.hasPrimaryFocus ||
        cancelNode.hasPrimaryFocus ||
        updateNode.hasPrimaryFocus ||
        grantNode.hasPrimaryFocus;

    testWidgets(
      'update dialog opened from a tile takes focus and the ring, and the page behind it is unreachable',
      (tester) async {
        await pumpApp(
          tester,
          aboutPage(
            onVersionTap: () async {
              await Future<void>.delayed(const Duration(milliseconds: 50));
              showUpdateDialog();
            },
          ),
        );
        expect(versionNode.hasPrimaryFocus, isTrue);
        expectRingOn(tester, versionNode);

        // Select on 版本: the dialog appears after the awaited Future.
        await tester.sendKeyEvent(LogicalKeyboardKey.select);
        await tester.pump(const Duration(milliseconds: 100));
        await tester.pumpAndSettle();
        expect(find.text('🎉 发现新版本 '), findsOneWidget);

        // Focus and the ring moved to the first control in reading order.
        expect(linkNode.hasPrimaryFocus, isTrue);
        expectRingOn(tester, linkNode);

        // The page behind the mask is neither focusable nor focused.
        expect(TvFocusTraversalPolicy.isEffectivelyFocusable(versionNode), isFalse);
        expect(TvFocusTraversalPolicy.isEffectivelyFocusable(otherNode), isFalse);
        expect(TvFocusTraversalPolicy.isEffectivelyFocusable(cancelNode), isTrue);
        expect(TvFocusTraversalPolicy.isEffectivelyFocusable(updateNode), isTrue);

        SmartDialog.dismiss();
        await tester.pumpAndSettle();
      },
    );

    testWidgets(
      'D-pad moves between the dialog controls and never lands on the page behind it',
      (tester) async {
        await pumpApp(tester, aboutPage());
        showUpdateDialog();
        await tester.pumpAndSettle();
        expect(linkNode.hasPrimaryFocus, isTrue);

        Future<void> press(LogicalKeyboardKey key) async {
          await tester.sendKeyEvent(key);
          await tester.pumpAndSettle();
          expect(
            versionNode.hasPrimaryFocus || otherNode.hasPrimaryFocus,
            isFalse,
            reason: 'focus leaked to the page behind the dialog on $key',
          );
          expect(inDialog(), isTrue, reason: 'focus left the dialog on $key');
          expectRingOn(tester, FocusManager.instance.primaryFocus!);
        }

        await press(LogicalKeyboardKey.arrowDown);
        expect(cancelNode.hasPrimaryFocus, isTrue);
        await press(LogicalKeyboardKey.arrowRight);
        expect(updateNode.hasPrimaryFocus, isTrue);
        await press(LogicalKeyboardKey.arrowLeft);
        expect(cancelNode.hasPrimaryFocus, isTrue);

        // Edges of the dialog: nothing beyond them to move to.
        await press(LogicalKeyboardKey.arrowDown);
        await press(LogicalKeyboardKey.arrowLeft);
        await press(LogicalKeyboardKey.arrowRight);
        await press(LogicalKeyboardKey.arrowRight);
        await press(LogicalKeyboardKey.arrowUp);
        await press(LogicalKeyboardKey.arrowUp);
        await press(LogicalKeyboardKey.arrowUp);
        expect(linkNode.hasPrimaryFocus, isTrue);

        SmartDialog.dismiss();
        await tester.pumpAndSettle();
      },
    );

    testWidgets(
      'Select on 取消 dismisses the dialog and focus and the ring return to 版本',
      (tester) async {
        await pumpApp(tester, aboutPage());
        showUpdateDialog();
        await tester.pumpAndSettle();

        await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
        await tester.pumpAndSettle();
        expect(cancelNode.hasPrimaryFocus, isTrue);

        await tester.sendKeyEvent(LogicalKeyboardKey.select);
        await tester.pumpAndSettle();

        expect(find.text('取消'), findsNothing);
        expect(versionNode.hasPrimaryFocus, isTrue);
        expectRingOn(tester, versionNode);
        expect(TvFocusTraversalPolicy.isEffectivelyFocusable(versionNode), isTrue);

        // The page responds to the D-pad again.
        await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
        await tester.pumpAndSettle();
        expect(otherNode.hasPrimaryFocus, isTrue);
        expectRingOn(tester, otherNode);
      },
    );

    testWidgets(
      'programmatic dismiss and the system Back both restore focus to the trigger',
      (tester) async {
        await pumpApp(tester, aboutPage());

        // SmartDialog.dismiss() from code.
        showUpdateDialog();
        await tester.pumpAndSettle();
        expect(linkNode.hasPrimaryFocus, isTrue);
        SmartDialog.dismiss();
        await tester.pumpAndSettle();
        expect(versionNode.hasPrimaryFocus, isTrue);
        expectRingOn(tester, versionNode);

        // The system Back is handled by SmartDialog and never pops the page.
        showUpdateDialog();
        await tester.pumpAndSettle();
        expect(linkNode.hasPrimaryFocus, isTrue);
        await tester.binding.handlePopRoute();
        await tester.pumpAndSettle();
        expect(find.text('取消'), findsNothing);
        expect(find.text('版本'), findsOneWidget);
        expect(versionNode.hasPrimaryFocus, isTrue);
        expectRingOn(tester, versionNode);
      },
    );

    testWidgets(
      'closing the dialog returns to the control that had focus when it opened',
      (tester) async {
        await pumpApp(tester, aboutPage());
        await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
        await tester.pumpAndSettle();
        expect(otherNode.hasPrimaryFocus, isTrue);

        showUpdateDialog();
        await tester.pumpAndSettle();
        expect(linkNode.hasPrimaryFocus, isTrue);

        SmartDialog.dismiss();
        await tester.pumpAndSettle();
        expect(otherNode.hasPrimaryFocus, isTrue);
        expectRingOn(tester, otherNode);
      },
    );

    testWidgets(
      'a dialog shown in the first frame, before the page has focus, takes focus, and closing hands focus to the page',
      (tester) async {
        // Auto-update dialog at startup: it opens before any page control has
        // focus, so the only candidate trigger is the Navigator's own node.
        tester.view.physicalSize = const Size(1280, 720);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        await tester.pumpWidget(buildApp(aboutPage(autofocus: false)));
        showUpdateDialog();
        await tester.pumpAndSettle();
        expect(find.text('取消'), findsOneWidget);
        expect(linkNode.hasPrimaryFocus, isTrue);
        expectRingOn(tester, linkNode);

        SmartDialog.dismiss();
        await tester.pumpAndSettle();
        expect(find.text('取消'), findsNothing);
        expect(
          versionNode.hasPrimaryFocus || otherNode.hasPrimaryFocus,
          isTrue,
          reason: 'focus must end up on a page control, not nowhere',
        );
        expectRingOn(tester, FocusManager.instance.primaryFocus!);
      },
    );

    testWidgets(
      'toast, loading and non-interactive dialogs leave focus and the D-pad on the page',
      (tester) async {
        await pumpApp(tester, aboutPage());
        expect(versionNode.hasPrimaryFocus, isTrue);

        SmartDialog.showToast('已是最新版本');
        await tester.pump(const Duration(milliseconds: 300));
        expect(find.text('已是最新版本'), findsOneWidget);
        expect(versionNode.hasPrimaryFocus, isTrue);
        expectRingOn(tester, versionNode);
        await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
        await tester.pump(const Duration(milliseconds: 100));
        expect(otherNode.hasPrimaryFocus, isTrue);
        await tester.pump(const Duration(seconds: 3));

        SmartDialog.showLoading();
        await tester.pump(const Duration(milliseconds: 300));
        expect(versionNode.hasPrimaryFocus || otherNode.hasPrimaryFocus, isTrue);
        await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
        await tester.pump(const Duration(milliseconds: 100));
        expect(versionNode.hasPrimaryFocus, isTrue);
        expectRingOn(tester, versionNode);
        SmartDialog.dismiss(status: SmartStatus.loading);
        await tester.pumpAndSettle();

        SmartDialog.show<void>(
          usePenetrate: true,
          builder: (context) => const Text('banner without controls'),
        );
        await tester.pumpAndSettle();
        expect(find.text('banner without controls'), findsOneWidget);
        expect(versionNode.hasPrimaryFocus, isTrue);
        await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
        await tester.pumpAndSettle();
        expect(otherNode.hasPrimaryFocus, isTrue);
        expectRingOn(tester, otherNode);
        SmartDialog.dismiss();
        await tester.pumpAndSettle();
        expect(otherNode.hasPrimaryFocus, isTrue);
      },
    );

    testWidgets(
      'single-button dialog with the default scale transition ends with the ring exactly on its button',
      (tester) async {
        await pumpApp(tester, aboutPage());
        showPermissionDialog();

        // Mid-transition: focus is already in the dialog.
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 60));
        expect(grantNode.hasPrimaryFocus, isTrue);

        await tester.pumpAndSettle();
        expect(grantNode.hasPrimaryFocus, isTrue);
        expectRingOn(tester, grantNode);

        // With a single control the D-pad has nowhere to go.
        for (final LogicalKeyboardKey key in [
          LogicalKeyboardKey.arrowUp,
          LogicalKeyboardKey.arrowDown,
          LogicalKeyboardKey.arrowLeft,
          LogicalKeyboardKey.arrowRight,
        ]) {
          await tester.sendKeyEvent(key);
          await tester.pumpAndSettle();
          expect(grantNode.hasPrimaryFocus, isTrue, reason: '$key');
        }

        await tester.sendKeyEvent(LogicalKeyboardKey.select);
        await tester.pumpAndSettle();
        expect(find.text('去授权'), findsNothing);
        expect(versionNode.hasPrimaryFocus, isTrue);
        expectRingOn(tester, versionNode);
      },
    );

    testWidgets(
      'focus pulled back to the page while the dialog is open returns to the dialog',
      (tester) async {
        await pumpApp(tester, aboutPage());
        showUpdateDialog();
        await tester.pumpAndSettle();
        expect(linkNode.hasPrimaryFocus, isTrue);

        // Something on the page asks for focus (an autofocus, a restored
        // route focus, ...).
        versionNode.requestFocus();
        await tester.pumpAndSettle();
        expect(versionNode.hasPrimaryFocus, isFalse);
        expect(inDialog(), isTrue);
        expectRingOn(tester, FocusManager.instance.primaryFocus!);

        // And closing still returns to the original trigger.
        SmartDialog.dismiss();
        await tester.pumpAndSettle();
        expect(versionNode.hasPrimaryFocus, isTrue);
        expectRingOn(tester, versionNode);
      },
    );

    testWidgets(
      'a dialog replaced by another in the same frame keeps focus in the overlay and still restores the page',
      (tester) async {
        await pumpApp(tester, aboutPage());
        showUpdateDialog();
        await tester.pumpAndSettle();
        expect(linkNode.hasPrimaryFocus, isTrue);

        SmartDialog.dismiss();
        showPermissionDialog();
        await tester.pumpAndSettle();
        expect(find.text('去授权'), findsOneWidget);
        expect(find.text('取消'), findsNothing);
        expect(grantNode.hasPrimaryFocus, isTrue);
        expect(versionNode.hasPrimaryFocus, isFalse);
        expectRingOn(tester, grantNode);

        await tester.sendKeyEvent(LogicalKeyboardKey.select);
        await tester.pumpAndSettle();
        expect(versionNode.hasPrimaryFocus, isTrue);
        expectRingOn(tester, versionNode);
      },
    );

    testWidgets(
      'stationary fast path holds while a settled dialog is open and once it is gone',
      (tester) async {
        await pumpApp(tester, aboutPage());
        showUpdateDialog();
        await tester.pumpAndSettle();
        // Past the settling window that follows the dialog opening.
        await tester.pump(const Duration(seconds: 1));

        final Finder ring = find
            .descendant(
              of: find.byType(TvNavigation),
              matching: find.byType(CustomPaint),
            )
            .last;
        final CustomPainter before = tester.widget<CustomPaint>(ring).painter!;
        for (int i = 0; i < 5; i++) {
          await tester.pump(const Duration(milliseconds: 16));
        }
        final CustomPainter after = tester.widget<CustomPaint>(ring).painter!;
        expect(after.shouldRepaint(before), isFalse);

        SmartDialog.dismiss();
        await tester.pumpAndSettle();
        await tester.pump(const Duration(seconds: 1));
        final CustomPainter pageBefore = tester
            .widget<CustomPaint>(ring)
            .painter!;
        for (int i = 0; i < 5; i++) {
          await tester.pump(const Duration(milliseconds: 16));
        }
        final CustomPainter pageAfter = tester
            .widget<CustomPaint>(ring)
            .painter!;
        expect(pageAfter.shouldRepaint(pageBefore), isFalse);
        expect(versionNode.hasPrimaryFocus, isTrue);
      },
    );
  });

  group('TvNavigation lifecycle (M10, R14)', () {
    setUp(() {
      TvPlatform.setTvModeForTesting(true);
    });

    tearDown(() {
      TvPlatform.setTvModeForTesting(false);
    });

    // A focused button that moves without focus changing, so the ring can only
    // follow it through the per-frame sync.
    Widget movingButton(FocusNode node, ValueNotifier<double> left) =>
        TvNavigation(
          child: Scaffold(
            body: ValueListenableBuilder<double>(
              valueListenable: left,
              builder: (BuildContext context, double x, Widget? _) => Stack(
                children: [
                  Positioned(
                    left: x,
                    top: 100,
                    width: 200,
                    height: 80,
                    child: ElevatedButton(
                      focusNode: node,
                      autofocus: true,
                      onPressed: () {},
                      child: const Text('moving'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );

    testWidgets(
      'a TvNavigation mounted after another was disposed still tracks its focused node',
      (tester) async {
        final first = FocusNode(debugLabel: 'first');
        final second = FocusNode(debugLabel: 'second');
        final left = ValueNotifier<double>(100);
        addTearDown(() {
          first.dispose();
          second.dispose();
          left.dispose();
        });

        await tester.pumpWidget(
          MaterialApp(home: movingButton(first, left)),
        );
        await tester.pumpAndSettle();
        expect(first.hasPrimaryFocus, isTrue);

        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pumpAndSettle();

        await tester.pumpWidget(
          MaterialApp(home: movingButton(second, left)),
        );
        await tester.pumpAndSettle();
        expect(second.hasPrimaryFocus, isTrue);
        _expectRingOn(tester, second);

        left.value = 400;
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 16));
        _expectRingOn(tester, second);
      },
    );

    testWidgets(
      'a TvNavigation replaced in a single frame hands the frame callback to the new one',
      (tester) async {
        final first = FocusNode(debugLabel: 'first');
        final second = FocusNode(debugLabel: 'second');
        final left = ValueNotifier<double>(100);
        addTearDown(() {
          first.dispose();
          second.dispose();
          left.dispose();
        });

        // The new state's initState runs before the old one is disposed, so the
        // old state must not clear the slot the new one just took.
        await tester.pumpWidget(
          MaterialApp(
            home: KeyedSubtree(
              key: const ValueKey<int>(1),
              child: movingButton(first, left),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(first.hasPrimaryFocus, isTrue);

        await tester.pumpWidget(
          MaterialApp(
            home: KeyedSubtree(
              key: const ValueKey<int>(2),
              child: movingButton(second, left),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(second.hasPrimaryFocus, isTrue);
        _expectRingOn(tester, second);

        left.value = 400;
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 16));
        _expectRingOn(tester, second);
      },
    );
  });

  group('login page QR tab (M10, R20)', () {
    test(
      '扫码 sits at TvNavigationObserver.loginQrTabIndex in both tab bars, and the controller polls the same index',
      () {
        final String view = File('lib/pages/login/view.dart').readAsStringSync();
        final String controller = File(
          'lib/pages/login/controller.dart',
        ).readAsStringSync();

        // One block per tab bar: the landscape app-bar one, then the portrait
        // one. Each lists the labels in tab order.
        final List<RegExpMatch> bars = RegExp(
          r'tabs:\s*const\s*\[(.*?)\n\s*\],',
          dotAll: true,
        ).allMatches(view).toList();
        expect(bars, hasLength(2), reason: 'login tab bars were restructured');
        for (final RegExpMatch bar in bars) {
          final List<String> labels = RegExp(
            r"(?:text:\s*|Text\(\s*)'\s*([^']+?)\s*'",
          ).allMatches(bar.group(1)!).map((RegExpMatch m) => m.group(1)!).toList();
          expect(labels, ['密码', '短信', '扫码', 'Cookie']);
          expect(labels[TvNavigationObserver.loginQrTabIndex], '扫码');
        }

        expect(controller, contains('TabController(length: 4'));
        expect(
          controller,
          contains('tabController.index != ${TvNavigationObserver.loginQrTabIndex}'),
        );
      },
    );
  });
}

// The ring is the last CustomPaint under TvNavigation; its painter exposes the
// rect it draws.
void _expectRingOn(WidgetTester tester, FocusNode node) {
  final Finder ring = find
      .descendant(
        of: find.byType(TvNavigation),
        matching: find.byType(CustomPaint),
      )
      .last;
  final Rect? rect =
      (tester.widget<CustomPaint>(ring).painter! as dynamic).rect as Rect?;
  expect(rect, isNotNull, reason: 'no focus ring is shown');
  expect(rect!.left, closeTo(node.rect.left, 0.5));
  expect(rect.top, closeTo(node.rect.top, 0.5));
  expect(rect.right, closeTo(node.rect.right, 0.5));
  expect(rect.bottom, closeTo(node.rect.bottom, 0.5));
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

/// Counts how often something walks the element tree through it.
class _VisitCounter {
  int visits = 0;
}

class _VisitCountingWidget extends StatelessWidget {
  const _VisitCountingWidget({required this.counter, required this.child});

  final _VisitCounter counter;
  final Widget child;

  @override
  StatelessElement createElement() => _VisitCountingElement(this);

  @override
  Widget build(BuildContext context) => child;
}

class _VisitCountingElement extends StatelessElement {
  _VisitCountingElement(_VisitCountingWidget super.widget);

  @override
  void visitChildren(ElementVisitor visitor) {
    (widget as _VisitCountingWidget).counter.visits++;
    super.visitChildren(visitor);
  }
}
