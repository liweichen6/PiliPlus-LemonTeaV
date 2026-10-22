import 'dart:io';

import 'package:PiliPlus/models/common/theme/theme_type.dart';
import 'package:PiliPlus/plugin/pl_player/models/fullscreen_mode.dart';
import 'package:PiliPlus/tv/tv_navigation.dart';
import 'package:PiliPlus/tv/tv_platform.dart';
import 'package:PiliPlus/utils/storage_key.dart';
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
        FullScreenMode.horizontal.index,
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
  });
}
