# PiliPlus-LemonTeaV: TV Control Layer Implementation & Optimization Plan

> **Execution Rules**:
> 1. Execute strictly one task at a time in Milestone → Epic → Task order.
> 2. After completing each task, update [`docs/tv/PROGRESS.md`](./PROGRESS.md) with what changed, verification results, and design notes.
> 3. Create an atomic Git commit after each logical milestone/task (including the updated `docs/tv/PROGRESS.md`).
> 4. **Privacy & Sanitization Rule**: Never include LAN IP addresses/ports, local machine absolute paths, file-scheme URLs, local usernames, or device serials in committed files or commit messages. Always use relative repository paths and generic placeholders (`<vm-tv>`, `<physical-tv>`).

---

## Roadmap Overview

### Phase 1: Foundation & Initial TV Port (Milestones 0–6) — Completed

| Milestone | Epics | Tasks | Summary | Status |
| :--- | :--- | :--- | :--- | :--- |
| **M0: Architecture & Planning Docs** | Epic 0.1 | Task 0.1.1 | Initialize `docs/tv/` architecture, milestone plan, and progress log. | ✅ Completed |
| **M1: Android TV Platform Bridge & Defaults** | Epic 1.1, 1.2 | Task 1.1.1, 1.2.1, 1.2.2 | Native `TvBridge.kt`, Leanback manifest/banner, `TvPlatform` runtime detection, first-launch Hive defaults, soft-keyboard gate, and Ethernet recognition. | ✅ Completed |
| **M2: Spatial Focus Engine & Route Observer** | Epic 2.1, 2.2 | Task 2.1.1, 2.2.1, 2.2.2 | `TvFocusTraversalPolicy` (RenderBox geometry/offscreen introspection, loop escape, micro-stop filtering), `TvNavigation` root wrapper, `TvNavigationObserver` (focus restore + QR login auto-tab), and `main.dart` hook. | ✅ Completed |
| **M3: Build-Time SDK & Widget Patch Pipeline** | Epic 3.1, 3.2 | Task 3.1.1, 3.1.2, 3.1.3, 3.2.1 | Framework-level TV patches (`tv_gesture_detector.patch`, `tv_radio_group.patch`, `tv_ink_well.patch`) integrated into `lib/scripts/patch.ps1` + local `tool/tv_patch.sh` helper. | ✅ Completed |
| **M4: Self-Contained 10-Foot Player HUD** | Epic 4.1 | Task 4.1.1, 4.1.2 | `lib/tv/tv_player_hud.dart` with GetX/controller auto-discovery (transport controls, seek acceleration, OSD dialogs, triple-like) and 4-line hook in `player_focus.dart`. | ✅ Completed |
| **M5: CI/CD Upstream Sync & Verification** | Epic 5.1, 5.2 | Task 5.1.1, 5.2.1 | Sync from `lemonteaau/PiliPlus` & build Android APKs, add unit tests for `lib/tv/`, and verify full APK build + Android TV D-pad flows. | ✅ Completed |
| **M6: D-Pad Input & Traversal Hardening** | Epic 6.1 | Task 6.1.1, 6.1.2, 6.1.3 | Eliminate root rebuilds (`ValueNotifier<Rect?>` + `RepaintBoundary` + `CustomPaint`), deduplicate scroll animations, cache metadata (`_TvTraversalCache`), throttle rapid D-pad repeats (45ms). | ✅ Completed |

---

### Phase 2: TV Control Layer Optimization & Verification (Milestones M1–M5) — Completed

| Milestone | Focus Area | Scope | Dependencies | Status |
| :--- | :--- | :--- | :--- | :--- |
| **M1: Navigation & Traversal Optimization** | Performance & Efficiency | `lib/tv/tv_navigation.dart`, `lib/tv/tv_platform.dart`, `lib/scripts/tv_gesture_detector.patch` (F1, F2, F3, F4, F5, F10) | None | ✅ Completed |
| **M2: Player HUD & Native Bridge Optimization** | Reactivity & Memory Safety | `lib/tv/tv_player_hud.dart`, `android/.../TvBridge.kt` (F6, F7, F8, F9, F10) | None | ✅ Completed |
| **M3: Living Documentation & Atomic Git History** | Documentation & Hygiene | `docs/tv/PLAN.md`, `docs/tv/ARCHITECTURE.md`, `docs/tv/PROGRESS.md`, git commit history (F11, F12) | M1, M2 | ✅ Completed |
| **M4: Test Suite Expansion & Benchmarks** | Objective Verification | `test/tv_navigation_test.dart`, `test/tv_player_hud_test.dart` (F13, F14, F15) | None | ✅ Completed |
| **M5: Dual-Device Verification & Sanitization** | Release Validation | Split-ABI release APK build, live verification on `<vm-tv>` and `<physical-tv>`, privacy audit (F16, F17) | M1, M2, M3, M4 | ✅ Completed |

---

### Phase 3: Post-Release Regression Investigation & Remediation (Milestone M6: Account Switcher, Settings & Popup Menu Focus Remediation) — Completed

| Milestone | Focus Area | Scope | Dependencies | Status |
| :--- | :--- | :--- | :--- | :--- |
| **M6: Account Switcher, Settings & Popup Menu Focus Fix** | Regression Investigation, `MediaQuery` Hierarchy Fix & `showMenu` Directional Focus Patch | `docs/tv/PLAN.md`, `docs/tv/PROGRESS.md`, `lib/main.dart`, `lib/tv/tv_navigation.dart`, `lib/scripts/popup_menu.patch`, `lib/scripts/material/popup_menu.patch`, `test/tv_navigation_test.dart` (`M6.1`–`M6.5`) | Phase 1, Phase 2 | ✅ Completed |

---

## Feature Inventory (Optimization Phase)

| Feature | Description | Target Files | Milestone | Status |
| :--- | :--- | :--- | :--- | :--- |
| **F1: Idle Frame Callback Optimization** | Multi-attribute stationary caching in `_syncFocusRectAfterLayout` (node, target box, target size, root size, parent data offset, scroll offset) to skip RenderBox matrix climbs; direct `_rectNotifier` connection to `_TvFocusRingPainter` via `super.repaint`. | `lib/tv/tv_navigation.dart` | M1 | ✅ Done |
| **F2: Traversal Geometry Pre-filtering** | Opposite half-plane spatial pre-filtering (`_isInOppositeHalfPlane`) using `node.rect` before ancestor element walks; pre-calculated `adjacentColumnSpans` interval lookups in vertical candidate scoring. | `lib/tv/tv_navigation.dart` | M1 | ✅ Done |
| **F3: Bounded Micro-Action Filtering** | Restrict `_isEmbeddedSecondaryOf` checks strictly to candidate nodes qualifying as micro-actions ($w \le 36 \land h \le 36$ or area $\le 2500$), bypassing $O(N^2)$ candidate scans when no micro-actions exist. | `lib/tv/tv_navigation.dart` | M1 | ✅ Done |
| **F4: Single-Pass Reading-Order Min-Element** | Single-pass $O(N)$ min-element search in reading order (`_findFirstReadingOrderNode`); eliminate duplicate `isEffectivelyFocusable` filtering and $O(N \log N)$ sorting. | `lib/tv/tv_navigation.dart` | M1 | ✅ Done |
| **F5: Patch Key Handler Optimization** | Extract inline anonymous key handler in `lib/scripts/tv_gesture_detector.patch` into static method `_handleDirectionalKeyEvent` to eliminate closure allocations during builds in directional mode. | `lib/scripts/tv_gesture_detector.patch` | M1 | ✅ Done |
| **F6: Root Obx Elimination & PopScope Migration** | Remove top-level `Obx` in `TvPlayerHud.build`; subscribe to `isFullScreen.listen` with localized `setState()`; migrate deprecated `ModalRoute.addScopedWillPopCallback` to Flutter's `PopScope`. | `lib/tv/tv_player_hud.dart` | M2 | ✅ Done |
| **F7: Virtual Seek Target Accumulator** | Decouple rapid remote key repeats from hardware video decoder latency via `_virtualSeekTarget` accumulator (with 1x -> 2x -> 3x progressive multipliers), bounded clamping, and 1400ms idle timeout reset. | `lib/tv/tv_player_hud.dart` | M2 | ✅ Done |
| **F8: TV Dialog Boilerplate Consolidation** | Consolidate 5 modal dialog invocations into single `_showTvDialog()` helper; deduplicate `_isSelectKey()` across `_TvPlayerHudState`, `_TvHudPillButtonState`, and `_TvTripleLikePillState`. | `lib/tv/tv_player_hud.dart` | M2 | ✅ Done |
| **F9: Memory-Safe `TvBridge.kt`** | Replace strong Android Activity reference in `TvBridge.kt` with `java.lang.ref.WeakReference<Activity>` and add null-safe guards to eliminate activity memory leaks across configuration changes. | `android/.../TvBridge.kt` | M2 | ✅ Done |
| **F10: 15 Preserved TV Capability Invariants** | Preserve 100% of functional capabilities C1–C15 (2D grid traversal, RenderBox collapse/clip introspection, cacheExtent scrolling, nested focus deduplication, micro-buttons, soft keyboard gate, etc.). | `lib/tv/*`, `lib/scripts/*` | M1, M2 | ✅ Done |
| **F11: Living Documentation** | Update `docs/tv/PLAN.md`, `ARCHITECTURE.md`, `PROGRESS.md` with complete optimization milestones, before/after architecture, and performance metrics. | `docs/tv/*` | M3 | ✅ Done |
| **F12: Atomic Git Commits & Revert Discipline** | Revert patches before commits (`./tool/tv_patch.sh revert`); maintain 4 clean atomic commits on `main` without sensitive identifiers. | Git repository | M3 | ✅ Done |
| **F13: Deterministic Traversal Benchmarks** | Automated benchmark tests bounding directional traversal latency (<50ms/step) over 120+ focusable nodes, single-pass RenderBox evaluations, and 0 unnecessary child rebuilds. | `test/tv_navigation_test.dart` | M4 | ✅ Done |
| **F14: Idle Frame Callback Test** | Verify `_syncFocusRectAfterLayout` skips post-frame callbacks and repaints when stationary, and verify immediate focus ring repaint on movement. | `test/tv_navigation_test.dart` | M4 | ✅ Done |
| **F15: `TvPlayerHud` Automated Test Suite** | 14 automated widget tests in `test/tv_player_hud_test.dart` covering transport controls, split-screen quick strip, virtual seek acceleration/clamping/resets, PopScope back navigation, and dialog lifecycles. | `test/tv_player_hud_test.dart` | M4 | ✅ Done |
| **F16: Dual-Device Release APK Verification** | Build split-ABI release APKs, install on `<vm-tv>` and `<physical-tv>`, and verify live D-pad navigation with 0 logcat errors. | Android APK / Devices | M5 | ✅ Done |
| **F17: Privacy Sanitization Verification** | Audit all files in `docs/tv/`, `lib/tv/`, `test/`, and git history to ensure 0 occurrences of LAN IPs, remote ports, usernames, local paths, or device serials. | Repository | M5 | ✅ Done |

---

## Detailed Milestone Breakdown (Optimization Phase)

### Milestone M1: Navigation & Traversal Optimization
* **Goal**: Optimize spatial navigation algorithms, persistent frame callbacks, and framework patch closures for peak runtime efficiency and minimal CPU overhead.
* **Tasks**:
  * **Task M1.1 (F2)**: Spatial Candidate Pre-filtering: Filter out candidates located in the opposite half-plane before traversing ancestor element trees; pre-compute horizontal interval spans (`adjacentColumnSpans`) for vertical candidate alignment.
  * **Task M1.2 (F3)**: Bounded Micro-Action Filtering: Evaluate secondary micro-action relationships only for candidates with $(w \le 36 \land h \le 36)$ or small bounding areas, bypassing $O(N^2)$ candidate scans.
  * **Task M1.3 (F4)**: Single-Pass Reading-Order Min-Element: Implement `_findFirstReadingOrderNode` using $O(N)$ min-element scan instead of full $O(N \log N)$ sorting and eliminate duplicate `isEffectivelyFocusable` filtering.
  * **Task M1.4 (F1)**: Idle Frame Callback Optimization: Multi-attribute stationary caching in `_syncFocusRectAfterLayout` (`_lastFocusedNode`, `_lastTargetBox`, `_lastTargetSize`, `_lastRootSize`, `_lastParentDataOffset`, `_lastScrollOffset`) to skip matrix climbs; pass notifier to `_TvFocusRingPainter` via `super.repaint`.
  * **Task M1.5 (F5)**: Static Patch Key Handler: Replace anonymous closure in `tv_gesture_detector.patch` with static method `_handleDirectionalKeyEvent`.
* **Verification**: `flutter analyze --no-pub lib/tv/ test/tv_navigation_test.dart` passes with 0 issues; 15 original invariant tests pass 100%.

---

### Milestone M2: Player HUD & Native Bridge Optimization
* **Goal**: Eliminate reactive rebuild storms in 10-foot player HUD, decouple rapid remote scrubbing from hardware video decoder latency, consolidate dialog boilerplate, and eliminate Android Activity memory leaks.
* **Tasks**:
  * **Task M2.1 (F6)**: Root `Obx` Elimination & PopScope Migration: Remove root `Obx` in `TvPlayerHud.build`; subscribe to `isFullScreen.listen` with localized `setState()`; migrate deprecated `ModalRoute.addScopedWillPopCallback` to `PopScope(canPop: !_hudVisible, onPopInvokedWithResult: ...)`.
  * **Task M2.2 (F7)**: Virtual Seek Target Accumulator: Introduce `Duration? _virtualSeekTarget` in `_TvPlayerHudState` to accumulate target time during rapid key repeats (<450ms) instead of reading lagging decoder position; clamp to video bounds; reset on idle timeout (1400ms), play/pause toggle, and HUD dismissal.
  * **Task M2.3 (F8)**: TV Dialog Consolidation & Key Handler Deduplication: Consolidate `_showTvDialog()` helper across all 5 HUD modal dialogs; deduplicate `_isSelectKey()` into single top-level utility.
  * **Task M2.4 (F9)**: Memory-Safe `TvBridge.kt`: Replace strong Activity reference with `WeakReference<Activity>` and guard all platform channel methods with null safety.
* **Verification**: `flutter analyze --no-pub lib/tv/ test/tv_navigation_test.dart` passes with 0 issues; 15 unit/widget tests pass 100%.

---

### Milestone M3: Living Documentation & Atomic Git History
* **Goal**: Provide transparent, accurate living documentation and maintain atomic, clean git commit history with strict privacy sanitization.
* **Tasks**:
  * **Task M3.1 (F11)**: Update Living Documentation:
    * `docs/tv/PLAN.md`: Full milestone breakdown, feature inventory, completed vs planned milestones.
    * `docs/tv/ARCHITECTURE.md`: Document 3-tier architecture, F1–F10 technical mechanisms, capability invariants C1–C15, and before/after architectural and metric comparisons.
    * `docs/tv/PROGRESS.md`: Detailed changelog, timeline, before/after metrics, and test results.
  * **Task M3.2 (F12)**: Patch Revert & Git Hygiene:
    * Revert all patches via `./tool/tv_patch.sh revert` and confirm 38 patches are `[NOT APPLIED]`.
    * Perform strict privacy sanitization audit (0 occurrences of LAN IPs, remote ports, usernames, local paths, or device serials).
    * Create 4 clean, atomic git commits on `main`:
      1. `refactor(tv): optimize spatial navigation traversal and idle frame callbacks`
      2. `refactor(tv): optimize player hud reactivity and bridge memory safety`
      3. `test(tv): expand automated test suite and traversal benchmarks`
      4. `docs(tv): document TV optimization milestones and benchmarks`
* **Verification**: `git status` clean; `git log -n 5` clean; privacy grep returns 0 matches.

---

### Milestone M4: Automated Test Suite Expansion & Deterministic Benchmarks
* **Goal**: Objectively certify functional invariants, deterministic traversal performance bounds, idle frame callback skipping, and 10-foot player HUD lifecycles.
* **Tasks**:
  * **Task M4.1 (F13)**: Traversal Latency & Geometry Benchmarks: Add benchmark test asserting mean traversal latency < 50ms/step across 120-node widget grid; verify strictly single-pass RenderBox geometry evaluations per traversal step; verify 0 unnecessary widget rebuilds.
  * **Task M4.2 (F14)**: Idle Frame Callback & Focus Ring Repaint Tests: Verify `_syncFocusRectAfterLayout` skips post-frame callbacks and repaints when stationary (`shouldRepaint == false`); verify `_TvFocusRingPainter` repaints immediately when focus moves (`shouldRepaint == true`).
  * **Task M4.3 (F15)**: `TvPlayerHud` Automated Test Suite: Create `test/tv_player_hud_test.dart` with 14 comprehensive tests covering transport controls, virtual seek acceleration/clamping/timeouts, PopScope route interception, and modal dialogs.
* **Verification**: `flutter test --no-pub test/tv_navigation_test.dart test/tv_player_hud_test.dart` passes 34/34 tests; full repository suite passes 89/89 tests.

---

### Milestone M5: Dual-Device Release APK Verification & Sanitization
* **Goal**: Build split-ABI release APKs, install and test on physical and virtual TV targets, and verify zero runtime errors and zero privacy leaks.
* **Tasks**:
  * **Task M5.1 (F16)**: Dual-Device Release Validation: Build release APKs (`flutter build apk --release --split-per-abi --build-number=5720 --no-pub`); install on `<vm-tv>` (`arm64-v8a`) and `<physical-tv>` (`armeabi-v7a`); verify live D-pad navigation, rapid stress bursts, settings scrolling, and video playback with 0 logcat errors.
  * **Task M5.2 (F17)**: Repository Privacy Audit: Scan all committed files and commit messages to verify 0 occurrences of sensitive local identifiers.
* **Verification**: Logcat clean of `EXCEPTION`, `ANR`, or `FlutterError`; repository privacy scan returns 0 matches.

---

## Detailed Milestone Breakdown (Phase 3: Post-Release Regression Investigation & Remediation)

### Milestone M6: Account Switcher, Settings & Popup Menu Focus Remediation
* **Goal**: Investigate and remediate the D-pad focus trap regression in `LoginPageController.switchAccountDialog` (`lib/pages/login/controller.dart`) alongside its collateral impact across all `Slider` and `RadioGroup` settings dialogs/pages, remediate the independent `PopupListTile` / `showMenu(..., requestFocus: false)` D-pad focus bug affecting 15 popup menu settings/controls, document exact git commit provenance and runtime performance characteristics, and add comprehensive regression tests.
* **Tasks**:
  * **Task M6.1 (`✅ Done`) — Root-Cause Investigation, Historical Commit Provenance & Collateral Impact Analysis**:
    * **Primary Root Cause — Inverted `MediaQuery` Hierarchy in `MyApp._builder` (`lib/main.dart`, TV commit `d053ad2e5` vs. upstream `b9b54ce4f`)**:
      * *Commit Provenance*: Upstream commit `b9b54ce4f` (`2026-01-22`, `tweaks`) extracted `MyApp._builder` (`lib/main.dart`), reading `final mediaQuery = MediaQuery.of(context)` from the outer `GetMaterialApp` context (where `navigationMode` is `NavigationMode.traditional`) and wrapping `child!` (`Navigator`) in `MediaQuery(data: mediaQuery.copyWith(...), child: child!)` (subsequently refined in `0fb394cc3`, `c7864ff4a`, and `dbb865d72`). During Phase 1 Milestone M2 (Task `2.2.2`), TV fork commit `d053ad2e5` (`2026-10-21`, `feat(tv-main): hook TvPlatform and TvNavigation into main.dart`) appended `if (TvPlatform.isTv) { child = TvNavigation(onBack: _onBack, child: child); }` *after* the `MediaQuery` block in `MyApp._builder` (`lib/main.dart:418-423`).
      * *Runtime Consequence*: Even though `_TvNavigationState.build` (`lib/tv/tv_navigation.dart`) wraps its child in `MediaQuery(data: MediaQuery.of(context).copyWith(navigationMode: NavigationMode.directional), ...)`, the **inner** `MediaQuery` in `MyApp._builder` immediately overwrites `navigationMode` back to `NavigationMode.traditional` for the entire `Navigator` subtree (all page routes and all `showDialog` / `showMenu` overlays).
      * *Impact on Framework Patches*: `lib/scripts/tv_radio_group.patch` (`commit e6990d48e`) guards Flutter's `_RadioGroupState.build` shortcut manager with `if (MediaQuery.maybeNavigationModeOf(context) != NavigationMode.directional)`. Because `navigationMode` inside `Navigator` is overwritten to `NavigationMode.traditional`, this check always evaluates to `true` at runtime—leaving `_radioGroupShortcutManager` and `_SkipUnselectedRadioPolicy<T>` active! It also silently neutralizes `lib/scripts/tv_gesture_detector.patch` (`commit 643893b9c`), `lib/scripts/tv_ink_well.patch`, and `lib/scripts/material/tv_ink_well.patch` (`commit fffaee51a`), as well as Flutter's built-in `NavigationMode.directional` handling in `_SliderState`.
    * **Mechanics of the Trap in `LoginPageController.switchAccountDialog` (`lib/pages/login/controller.dart`) & `RadioWidget` (`lib/common/widgets/radio_widget.dart`)**:
      * `RadioWidgetState<T>` mixes in `RadioClient<T>`, owns a single `FocusNode` attached to its outer `InkWell`, wraps its inner `Radio<T>` in `ExcludeFocus` with a private no-op `_RadioRegistry<T>`, and registers its `InkWell` `focusNode` with the ancestor `RadioGroup` (`registry = RadioGroup.maybeOf(context)`).
      * When focus enters any `RadioWidget` row inside `switchAccountDialog`:
        * **Logged-out / 0 saved accounts (`_radios.length == 1`, only `AnonymousAccount(): '0'`)**: Flutter's `_RadioGroupState._selectRadioInDirection` returns early when `_radios.length < 2`, while `_RadioGroupShortcutManager.handleKeypress` still returns `KeyEventResult.handled` for `arrowLeft`, `arrowRight`, `arrowUp`, and `arrowDown`. Focus is 100% frozen on the `'0'` row and cannot reach the header (`详细`/`快速`, `登录`) or footer (`取消`, `确定`) buttons.
        * **Logged-in / 1+ saved accounts (`_radios.length >= 2`)**: `_selectRadioInDirection` loops infinitely within the same `RadioGroup` (`nextFocus ??= nodesInEffectiveOrder.first` / `.last`) and invokes `onChanged` on every arrow key press. Focus can never escape the `RadioGroup` to reach the header buttons (`详细`/`快速`, `登录`), move between the 4 `AccountType` `RadioGroup` sections in Detailed (`详细`) mode, or reach the footer buttons (`取消`, `确定`).
    * **Why `switchAccountDialog` Appeared Fixed in an Earlier Version and Why It Resurfaced (Three Converging History Factors)**:
      1. *Pre-Clean-Room Prototype vs. Clean-Room Refactor (`d053ad2e5`)*: The earlier prototype modified `lib/common/widgets/radio_widget.dart` and `lib/pages/login/controller.dart` directly in app code. During the Phase 1 clean-room refactor into `tv_radio_group.patch` (`e6990d48e`) + `TvNavigation` (`d053ad2e5`), `TvNavigation` was inadvertently placed *outside* `MyApp._builder`'s `MediaQuery`.
      2. *Upstream Commit `37a92d1fb` (`2026-10-22`, `tweaks (#3349)`) Merged via `51650b5c6` (`2026-10-23`, `v2.1.6.2-fork.5739`)*: Prior to `51650b5c6` (including in `v2.1.6.2-fork.5720`), `LoginPageController.switchAccountDialog` began with `if (Accounts.account.isEmpty) { SmartDialog.showToast('请先登录'); return Get.toNamed('/loginPage'); }`. On a logged-out TV installation, selecting "切换账号" bypassed `switchAccountDialog` completely and navigated straight to `/loginPage` (where `TvNavigationObserver` auto-selected the QR code tab). Upstream commit `37a92d1fb` commented out those 4 lines (`lib/pages/login/controller.dart:628-631`) and added an `IconButton(tooltip: '登录', icon: Icon(Icons.login_outlined))` to `AlertDialog.title`. Consequently, selecting "切换账号" when logged out now opens `switchAccountDialog` with only the single `'0'` (`AnonymousAccount`) radio row—immediately hitting the `_radios.length < 2` total D-pad freeze and preventing the user from reaching the new `登录` button or `取消`/`确定`!
      3. *False-Positive Unit Test (`test/tv_navigation_test.dart`, commit `9da6200ed`)*: The existing test `'patched RadioGroup allows D-pad arrow navigation to unselected options'` mounted `MaterialApp(home: TvNavigation(...))` directly (bypassing `MyApp._builder`'s inner `MediaQuery`), did not assert that `selectedValue` remained `1` after pressing `arrowDown` (before pressing `enter`), and lacked external focusable buttons above/below the `RadioGroup` to test escaping the group.
    * **Collateral Settings & Dialog Impact Across the Application (Caused by `NavigationMode.traditional` Overwrite in `MyApp._builder`)**:
      1. *Single-Slider Dialogs (9 `SliderDialog` settings + 1 custom `Slider` dialog — D-pad Up/Down trapped in `Slider`, unable to reach `重置`/`取消`/`确定`)*:
         * In Flutter's `_SliderState`, `SingleActivator(LogicalKeyboardKey.arrowUp)` and `SingleActivator(LogicalKeyboardKey.arrowDown)` are bound to `IncreaseAction` / `DecreaseAction` under `NavigationMode.traditional`, and are only unbound (leaving only Left/Right for value adjustment so Up/Down performs directional focus traversal) when `MediaQuery.navigationModeOf(context) == NavigationMode.directional`. Because `MyApp._builder` overwrites `navigationMode` to `NavigationMode.traditional`, pressing D-pad Up/Down inside any `Slider` adjusts the slider value instead of moving focus to the dialog's `重置` / `取消` / `确定` buttons!
         * Affected `SliderDialog` settings (9) + custom single-`Slider` dialog (1):
           1. `图片质量` (`SliderDialog` in `lib/pages/setting/models/style_settings.dart:279`)
           2. `查看大图质量` (`SliderDialog` in `lib/pages/setting/models/style_settings.dart:298`)
           3. `气泡提示不透明度` / `Toast不透明度` (`SliderDialog` in `lib/pages/setting/models/style_settings.dart:330, 837`)
           4. `倾斜角度阈值` (`SliderDialog` in `lib/pages/setting/models/play_settings.dart:458`)
           5. `播放器音量` (`SliderDialog` via `showVolumeDialog` in `lib/pages/setting/models/play_settings.dart:480, 529`)
           6. `最高音量` (`SliderDialog` via `showVolumeDialog` in `lib/pages/setting/models/play_settings.dart:498, 529`)
           7. `刷新指示器高度` (`SliderDialog` in `lib/pages/setting/models/extra_settings.dart:382`)
           8. `连接重试次数` (`SliderDialog` in `lib/pages/setting/models/extra_settings.dart:461`)
           9. `连接重试间隔` (`SliderDialog` in `lib/pages/setting/models/extra_settings.dart:483`)
           10. `界面缩放` (custom `AlertDialog` with single `Slider` + `TextFormField` + `重置`/`取消`/`确定` in `lib/pages/setting/models/style_settings.dart:102, 478`)
      2. *Multi-Slider Dialogs & Pages (6 dialogs/pages — D-pad Up/Down cannot traverse between stacked `Slider`s or reach action buttons)*:
         * Affected dialogs/pages (6):
           1. `列表宽度（dp）限制` (`DualSliderDialog` with 2 stacked `Slider`s + `重置`/`取消`/`确定` in `lib/pages/setting/models/style_settings.dart:712` and `lib/pages/setting/widgets/dual_slider_dialog.dart:61, 78`)
           2. `深色下图片颜色叠加` (`SlideColorPicker` in `lib/pages/setting/models/style_settings.dart:791` and `lib/pages/setting/slide_color_picker.dart:61`)
           3. `全屏SuperChat` (`FullScreenSc` page with 2 `Slider`s in `lib/pages/setting/pages/fullscreen_sc.dart:163, 182`)
           4. `App字体设置` (`FontSettingPage` with 2 `Slider`s in `lib/pages/setting/pages/font_setting.dart:319, 354`)
           5. Player `弹幕设置` sheet (10 `Slider`s in `lib/pages/video/widgets/header_mixin.dart:208-446`)
           6. Player `播放设置` sheet (7 `Slider`s in `lib/pages/video/widgets/header_control.dart:1390-1504`)
      3. *`RadioGroup` + `RadioListTile` Immediate-Close Selection Dialogs & Pages (33 historical `SelectDialog`/`CdnSelectDialog`/`_showFavDialog` radio dialogs before upstream `299905f47` migrated 12 to `PopupModel`; 21 active dialog settings across 22 dialog call sites + `DisplayModePage` — D-pad Up/Down prematurely fires `onChanged` and closes the dialog on the first arrow press)*:
         * Because `tv_radio_group.patch` is bypassed under `NavigationMode.traditional`, pressing D-pad Up/Down inside any `SelectDialog<T>`, `CdnSelectDialog`, `_showFavDialog`, or `DisplayModePage` invokes `_RadioGroupState._selectRadioInDirection`, which calls `widget.onChanged` on the adjacent radio item and immediately pops the dialog (`Navigator.pop`) on the first arrow key press instead of letting the user browse options with Up/Down and confirm with Select/OK!
         * Affected active `RadioGroup` + `RadioListTile` selection controls:
           * 5 filter/seek dialogs via `getVideoFilterSelectModel` (`lib/pages/setting/models/model.dart:306`): `点赞率过滤` (`title: '点赞率'`, `isFilter: true`), `视频时长过滤` (`title: '视频时长'`, `isFilter: true`), `播放量过滤` (`title: '播放量'`, `isFilter: true` in `lib/pages/setting/models/recommend_settings.dart:51, 77, 85`), `双击快进/快退时长`, and `滑动快进/快退时长` (`isFilter: false` in `lib/pages/setting/models/play_settings.dart:236, 250`).
           * 9 video settings dialogs across 10 call sites (`lib/pages/setting/models/video_settings.dart` & `header_control.dart`): `CDN 设置` (`CdnSelectDialog` at `video_settings.dart:326` and `header_control.dart:525`), `线程撕裂者：并发数` (`video_settings.dart:94`), `默认画质` (`385`), `蜂窝网络画质` (`403`), `默认音质` (`424`), `蜂窝网络音质` (`442`), `直播默认画质` (`463`), `蜂窝网络直播默认画质` (`481`), and `视频同步` (`564`).
           * 4 playback settings across 5 `SelectDialog`s (`lib/pages/setting/models/play_settings.dart`): `字幕选择偏好` (`425`), `默认全屏方向` (`446`), `超分辨率` (`550`), and the two-step `音量均衡` + `服务器无loudnorm配置时使用` dialogs (`586`).
           * 2 style settings dialogs (`lib/pages/setting/models/style_settings.dart`): `页面过渡动画` (`693`) and `用户页默认展示TAB` (`942`).
           * `主题模式` inside `ColorSelectPage` (`lib/pages/setting/pages/color_select.dart:93`), `选择默认收藏夹` (`_showFavDialog` in `lib/pages/setting/models/extra_settings.dart:426`), and `屏幕帧率` (`DisplayModePage` in `lib/pages/setting/pages/display_mode.dart:80`).
      4. *`RadioGroup` Confirmation Dialogs (3 dialogs — D-pad focus trapped inside `RadioGroup`, unable to reach `取消`/`确定`/`确认` or header buttons)*:
         * `LoginPageController.switchAccountDialog` (`lib/pages/login/controller.dart:705, 737`, using `RadioGroup<Account>` + `RadioWidget<Account>` with header `详细`/`快速`, `登录` and footer `取消`/`确定` buttons), `autoWrapReportDialog` (`lib/common/widgets/dialog/report.dart:22, 89`, `举报` dialog using `RadioGroup<int>` + `WrapRadioOptionsGroup<int>` / `RadioWidget<int>` with `取消`/`确定` buttons), and `RequestUtils.onCopyOrMove` (`lib/utils/request_utils.dart:435, 455`, `复制到`/`移动到` favorite folder dialog using `RadioGroup<int>` + `RadioListTile<int>` with `取消`/`确认` buttons).
    * **Independent `PopupListTile` / `showMenu` D-Pad Focus Bug (`lib/pages/setting/widgets/popup_item.dart` & `lib/scripts/popup_menu.patch`)**:
      * *Commit Provenance*:
        * `1ad710c1c` (`2026-02-05`, `opt settings`): Created `PopupListTile<T>` (`lib/pages/setting/widgets/popup_item.dart`) with `ListTile(onTapUp: (details) => _showButtonMenu(details, value))` (`onTap: null`) and `showMenu<T?>(..., requestFocus: false)`.
        * `7ab2cf973` (`2026-02-06`, `tweaks (#1826)`): Temporarily changed `PopupListTile._showButtonMenu` in `lib/pages/setting/widgets/popup_item.dart` from `requestFocus: false` to `requestFocus: true` (alongside wrapping `ListTile` in `KeyedSubtree`), without modifying `lib/scripts/popup_menu.patch` or `lib/scripts/material/popup_menu.patch`.
        * `0460030a2` (`2026-02-09`, `feat: tempPlayerConf add playRepeat (#1830)`): Reverted `requestFocus: true` back to `requestFocus: false` in `PopupListTile._showButtonMenu` (`lib/pages/setting/widgets/popup_item.dart:69`).
        * `0df637fb7` (`2026-06-28`) and `810c26a6e` (`2026-08-17`): Created `lib/scripts/popup_menu.patch` and `lib/scripts/material/popup_menu.patch` with a single hunk in `PopupMenuItemState.build` (`IconTheme.merge` for enabled items), leaving `showMenu`'s `bool? requestFocus` parameter untouched.
        * `299905f47` (`2026-08-25`, `opt: replace dialog with popup (#2683)`): Replaced `SelectDialog` with `PopupModel` / `PopupListTile` across 12 settings items.
        * `fffaee51a` (`2026-10-21`, `feat(tv-patch): add tv_ink_well.patch for ActionItem triple-like and PopupListTile support`): Patched `_InkResponseState.activateOnIntent` in `lib/scripts/tv_ink_well.patch` and `lib/scripts/material/tv_ink_well.patch` so `InkWell` with `onTap == null && (onTapDown != null || onTapUp != null)` synthesizes center `TapUpDetails` on D-pad Select/Enter, enabling `PopupListTile` to open its popup menu—**but** did not address `showMenu(..., requestFocus: false)` in `popup_item.dart:69`.
      * *Mechanics & Affected Controls (15 `PopupListTile` settings / 16 call sites + all `showMenu` / `PopupMenuButton` routes)*:
        * Even after restoring `NavigationMode.directional` in `MyApp._builder`, `PopupListTile._showButtonMenu` (`lib/pages/setting/widgets/popup_item.dart:69`) explicitly passes `requestFocus: false` to `showMenu<T>` (while other `showMenu` / `PopupMenuButton` callers omit `requestFocus`, leaving it `null` to defer to `Navigator.requestFocus`). Passing `requestFocus: false` prevents `_ModalScopeState` from auto-focusing `_PopupMenuRoute`'s `FocusScopeNode` when pushed, leaving `FocusManager.instance.primaryFocus` on the triggering widget in the underlying route (`focusScopeNode.skipTraversal == true` when `!route.isCurrent`). Detecting inactive route `FocusScopeNode`s via `skipTraversal` in `_TvNavigationState` (`_syncFocusRectAfterLayout` and `_onFocus` in `lib/tv/tv_navigation.dart`) and promoting focus to the first focusable item in the active sibling `FocusScopeNode` ensures all `PopupListTile` and `showMenu(..., requestFocus: false)` routes acquire focus on TV with zero modifications to upstream `popup_item.dart`, `popup_menu.patch`, or `material/popup_menu.patch`.
        * Affects 13 `PopupModel` settings (`动态页UP主显示位置`, `动态未读标记`, `消息未读标记`, `顶/底栏收起类型`, `主题模式`, `默认启动页` in `lib/pages/setting/models/style_settings.dart`; `SuperChat (醒目留言) 显示类型`, `底部进度条展示`, `播放顺序` in `lib/pages/setting/models/play_settings.dart`; `番剧片头/片尾跳过类型` in `lib/pages/setting/models/extra_settings.dart`; `评论展示`, `楼中楼评论展示` in `lib/pages/setting/models/reply_settings.dart`; `动态展示` in `lib/pages/setting/models/dyn_settings.dart`), plus `调色板风格` (`lib/pages/setting/pages/color_select.dart:118`) and `超分辨率` / `播放顺序` (`lib/pages/video/widgets/header_control.dart:472, 662`).
    * **Performance & Zero-Upstream-Conflict Impact Analysis**:
      * *Unwrapping Direct `MediaQuery` Children Inside `_TvNavigationState.build` (`lib/tv/tv_navigation.dart` — Zero Diff in `lib/main.dart`)*:
        * **Upstream Merge Isolation**: Keeps `if (TvPlatform.isTv) { child = TvNavigation(onBack: _onBack, child: child); }` at the tail of `MyApp._builder` (`lib/main.dart`) completely outside upstream's frequently modified `if (uiScale != 1.0) ... else ...` `MediaQuery` block (`0` diff against `HEAD` in `lib/main.dart`).
        * **Widget Tree Depth & Allocation**: Unwrapping direct `MediaQuery` children (`while (child is MediaQuery) { mediaQuery = child.data; child = child.child; }`) and applying `mediaQuery.copyWith(navigationMode: NavigationMode.directional)` **reduces** widget tree depth by eliminating redundant inner `MediaQuery` layers while preserving all `MyApp._builder` overrides (`textScaler`, `size`, `padding`, `viewPadding`, `viewInsets`, `devicePixelRatio`).
        * **Rebuild & Notification Cost**: Zero extra `MediaQuery` notifications or rebuilds. `MediaQuery` is an `InheritedModel<_MediaQueryAspect>`; widgets querying `MediaQuery.maybeNavigationModeOf(context)` subscribe exclusively to `_MediaQueryAspect.navigationMode`, which is a static $O(1)$ lookup (`NavigationMode.directional`) that never mutates during the app session.
        * **Frame & Traversal Cost**: Restoring `NavigationMode.directional` bypasses `_RadioGroupShortcutManager` and `_SkipUnselectedRadioPolicy`, delegating traversal to `TvFocusTraversalPolicy` (verified at ~3.2ms/step over 120 nodes and ~0.001ms/frame when idle).
      * *Promoting Focus into Active Sibling `FocusScopeNode` for `requestFocus: false` Routes in `_TvNavigationState` (`lib/tv/tv_navigation.dart` — Zero Diff in `popup_menu.patch` & `material/popup_menu.patch`)*:
        * **Upstream Merge Isolation**: Leaves `lib/scripts/popup_menu.patch` and `lib/scripts/material/popup_menu.patch` 100% untouched relative to `HEAD` (`0` diff).
        * **Steady-State & Invocation Cost**: Flutter's `_ModalScopeState.build` sets `focusScopeNode.skipTraversal = !widget.route.isCurrent`. On normal frames, `_isScopeInactive(currentScope)` performs a pure in-memory boolean walk up `enclosingScope` (`current.skipTraversal`), with zero `BuildContext` / `InheritedModel.inheritFrom` lookups (`false` whenever the focused route is topmost). Only when a `requestFocus: false` route (such as `showMenu` in `PopupListTile`) is pushed on top of the active route does the covered route's `FocusScopeNode.skipTraversal` become `true`, triggering `_findActiveSiblingScope` to climb to the outermost inactive `FocusScopeNode`, search the owning `NavigatorState.focusNode`, and focus the topmost sibling route's first `PopupMenuItem`.
  * **Task M6.2 (`✅ Done`) — Unwrap Direct `MediaQuery` Children in `_TvNavigationState.build` (`lib/tv/tv_navigation.dart`, Zero Diff in `lib/main.dart`)**:
    * Updated `_TvNavigationState.build` (`lib/tv/tv_navigation.dart`) so that when `widget.child` is wrapped in one or more `MediaQuery` widgets (as returned by `MyApp._builder` in `lib/main.dart`), `TvNavigation` unwraps `while (child is MediaQuery)` to extract the innermost `child.data` and `child.child` and wraps `child.child` in a single `MediaQuery(data: mediaQuery.copyWith(navigationMode: NavigationMode.directional), ...)`. This preserves all `MyApp._builder` `MediaQueryData` overrides while guaranteeing no inner `MediaQuery` overwrites `navigationMode` back to `NavigationMode.traditional`, with zero diff to `lib/main.dart`.
  * **Task M6.3 (`✅ Done`) — Self-Contained `requestFocus: false` Modal Focus Promotion & Popup Focus-Ring Tracking (`lib/tv/tv_navigation.dart`, Zero Diff in `popup_menu.patch`)**:
    * Updated `_TvNavigationState._syncFocusRectAfterLayout` and `_TvNavigationState._onFocus` in `lib/tv/tv_navigation.dart` to: (1) detect when the currently focused node's `FocusScopeNode` (or an ancestor route `FocusScopeNode` when nested inside an inner `FocusScope`) has `skipTraversal == true` (`_isScopeInactive(currentScope)`, which occurs when `showMenu(..., requestFocus: false)` pushes `_PopupMenuRoute` on top of the page route), climb to the outermost inactive `FocusScopeNode` and locate the active sibling `FocusScopeNode` under `NavigatorState.focusNode` via `_findActiveSiblingScope(currentScope)`, save the triggering node via `TvNavigationObserver.rememberFocusedNode(node)`, activate the popup's `FocusScopeNode` (`targetScope.enclosingScope?.setFirstFocus(targetScope)`), and focus its first visible `PopupMenuItem`; (2) retry `_policy.findFirstFocus(targetScope)` on subsequent frames while `primaryFocus` is a `FocusScopeNode`; and (3) accumulate `BoxParentData.offset` and `RenderFractionalTranslation` offsets up the `RenderObject` ancestor chain via `_accumulatedParentOffset(ro, rootRo)` so ancestor layout shifts (such as `_PopupMenuRouteLayout` shifting `_PopupMenu` upward as `Align.heightFactor` expands near the bottom of the screen) update `_rectNotifier` accurately.
    * Preserves zero diff in upstream `lib/main.dart`, `lib/pages/setting/widgets/popup_item.dart`, `lib/scripts/popup_menu.patch`, and `lib/scripts/material/popup_menu.patch` while making all 15 `PopupListTile` / `PopupModel` settings, player popup menus, and `PopupMenuButton` routes fully focusable and D-pad navigable on Android TV.
  * **Task M6.4 (`✅ Done`) — Strengthen Automated Regression Tests (`test/tv_navigation_test.dart`)**:
    * Added a widget test replicating `MyApp._builder`'s exact `HEAD` wrapping order (`MediaQuery` wrapped by `TvNavigation`) to assert both `MediaQuery.navigationModeOf(context) == NavigationMode.directional` and `MediaQuery.textScalerOf(context) == TextScaler.noScaling` inside page routes and `showDialog` overlays.
    * Tightened the existing `RadioGroup` test to assert `expect(selectedValue, 1)` immediately after `arrowDown` (confirming arrow keys only move focus and do not trigger `onChanged` until `enter`/`select`).
    * Added a comprehensive `switchAccountDialog` focus-escape regression test covering 1-option (`'0'`) and multi-option (`'0'`, `'1001'`) states across both Quick (`RadioWidget`) and Detailed (`详细`, 4 `AccountType` `RadioGroup` + `WrapRadioOptionsGroup` sections) modes, plus header (`详细`/`快速` <-> `登录`) and footer (`取消` <-> `确定`) traversal.
    * Added regression tests verifying D-pad Up/Down focus escape from `Slider` (`SliderDialog` / `DualSliderDialog`) to dialog action buttons and D-pad focus/selection, focus restoration, nested `FocusScope` trigger promotion, same-frame `requestFocus()` + `showMenu(requestFocus: false, popUpAnimationStyle: AnimationStyle.noAnimation)`, and bottom-edge focus-ring tracking inside `showMenu(..., requestFocus: false)` (`PopupListTile`) under `NavigationMode.directional`.
  * **Task M6.5 (`✅ Done`) — Patch Verification, Live TV Validation & Revert Discipline**:
    * Applied patches (`./tool/tv_patch.sh apply`), verified `flutter analyze --no-pub` (`0` issues) and `flutter test --no-pub test/tv_navigation_test.dart test/tv_player_hud_test.dart` (`24/24` in `test/tv_navigation_test.dart`, `14/14` in `test/tv_player_hud_test.dart`, `38/38` total TV tests), validated live D-pad traversal across `switchAccountDialog` (`账号切换`, including Quick and Detailed `详细` modes), `SelectDialog` (`页面过渡动画`), `DualSliderDialog` (`列表宽度 (dp) 限制`), `PopupListTile` / `showMenu` (`动态页UP主显示位置`), and `SliderDialog` (`图片质量`) on `<vm-tv>` with `0` logcat errors, and reverted all 38 patches (`./tool/tv_patch.sh revert`).
* **Verification**: `flutter analyze --no-pub` reports `No issues found!`; `flutter test --no-pub test/tv_navigation_test.dart test/tv_player_hud_test.dart` passes `38/38` TV tests; live `<vm-tv>` D-pad verification passed across all 5 target dialog/menu flows with `0` `FlutterError`/`EXCEPTION`/`ANR`; all 38 patches reverted cleanly (`[NOT APPLIED]`).
