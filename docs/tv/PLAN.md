# PiliPlus-LemonTeaV: TV Control Layer Implementation Plan

> **Execution Rules**:
> 1. Execute strictly one task at a time in Milestone → Epic → Task order.
> 2. After completing each task, update [`docs/tv/PROGRESS.md`](./PROGRESS.md) with what changed, verification results, and any design notes.
> 3. Create an atomic Git commit after each task (including the updated `docs/tv/PROGRESS.md`).
> 4. **Privacy & Sanitization Rule**: Never include LAN IP addresses/ports, local machine absolute paths, file-scheme URLs, or any other personal information in committed files or commit messages. Always use relative repository paths and generic placeholders (e.g., `$TV_DEVICE_ADDR` or `<physical-tv-adb>`).

---

## Roadmap Overview

| Milestone | Epics | Tasks | Summary |
| :--- | :--- | :--- | :--- |
| **M0: Architecture & Planning Docs** | Epic 0.1 | Task 0.1.1 | Initialize `docs/tv/` architecture, milestone plan, and progress log. |
| **M1: Android TV Platform Bridge & Defaults** | Epic 1.1, Epic 1.2 | Task 1.1.1, Task 1.2.1, Task 1.2.2 | Native `TvBridge.kt`, Leanback manifest/banner, `TvPlatform` runtime detection, first-launch Hive defaults, system soft-keyboard gate, and Ethernet broadband recognition. |
| **M2: Spatial Focus Engine & Route Observer** | Epic 2.1, Epic 2.2 | Task 2.1.1, Task 2.2.1, Task 2.2.2 | Hardened `TvFocusTraversalPolicy` (with `RenderBox` zero-size/offscreen introspection, loop escape, micro-stop filtering), `TvNavigation` root wrapper (`NavigationMode.directional`), `TvNavigationObserver` (focus restore + QR login auto-tab), and `lib/main.dart` micro-hook. |
| **M3: Build-Time SDK & Widget Patch Pipeline** | Epic 3.1, Epic 3.2 | Task 3.1.1, Task 3.1.2, Task 3.1.3, Task 3.2.1 | Framework-level TV patches (`tv_gesture_detector.patch`, `tv_radio_group.patch`, `tv_ink_well.patch`) integrated into `lib/scripts/patch.ps1` + local `tool/tv_patch.sh` helper. |
| **M4: Self-Contained 10-Foot Player HUD** | Epic 4.1 | Task 4.1.1, Task 4.1.2 | `lib/tv/tv_player_hud.dart` with GetX/controller auto-discovery (transport controls, seek acceleration, danmaku/quality/episode/speed OSD, triple-like) and 4-line hook in `player_focus.dart`. |
| **M5: CI/CD Upstream Sync & End-to-End Verification** | Epic 5.1, Epic 5.2 | Task 5.1.1, Task 5.2.1 | Configure `.github/workflows/sync-upstream-build.yml` to sync from `lemonteaau/PiliPlus` & build Android APKs, add unit tests for `lib/tv/`, and verify full APK build + Android TV D-pad flows. |
| **M6: D-Pad High-Frequency Input & Traversal Performance Hardening** | Epic 6.1 | Task 6.1.1, Task 6.1.2, Task 6.1.3 | Eliminate root widget rebuilds (`ValueNotifier<Rect?>` + `RepaintBoundary` + `CustomPaint`), deduplicate conflicting `120ms` `ensureVisible` animations, cache `O(N·D)` traversal metadata (`_TvTraversalCache`), throttle rapid D-pad repeats, and verify under high-frequency D-pad stress on both TV devices. |

---

## Milestone 0: Architecture & Planning Documentation

### Epic 0.1: Repository Documentation Bootstrap
Establish the architecture specification, milestone/epic/task breakdown, and progress tracker inside `docs/tv/`.

#### Task 0.1.1: Create `docs/tv/` Planning Suite
* **Files**:
  * `[NEW] docs/tv/README.md`
  * `[NEW] docs/tv/ARCHITECTURE.md`
  * `[NEW] docs/tv/PLAN.md`
  * `[NEW] docs/tv/PROGRESS.md`
* **Acceptance Criteria**:
  * All 4 documentation files are created and cross-linked.
  * Commit created before any code changes begin, holding for manual user review.
* **Commit Message**: `docs(tv): add TV control layer architecture and milestone plan`

---

## Milestone 1: Android TV Platform Bridge, Defaults & Network Adaptation

### Epic 1.1: Native Android TV Leanback & MethodChannel Bridge
Enable Android TV launcher discovery and expose native TV hardware/UI-mode capabilities to Dart with minimal changes to `android/`.

#### Task 1.1.1: Implement `TvBridge.kt` and Leanback Manifest Configuration
* **Files**:
  * `[NEW] android/app/src/main/kotlin/com/example/piliplus/TvBridge.kt`
  * `[NEW] android/app/src/main/res/drawable/tv_banner.xml`
  * `[MODIFY] android/app/src/main/AndroidManifest.xml`
  * `[MODIFY] android/app/src/main/kotlin/com/example/piliplus/MainActivity.kt`
* **Implementation Details**:
  * Create `TvBridge.kt` registering MethodChannel `com.example.piliplus/tv` with methods:
    * `getTvEnvironment`: returns `isTelevisionUiMode`, `hasLeanbackFeature`, `hasTouchscreen`, `smallestScreenWidthDp`.
    * `showSoftKeyboard` / `hideSoftKeyboard`: invokes `InputMethodManager` explicitly when requested by the user on a focused `TextField`.
  * Update `AndroidManifest.xml`:
    * Add `<uses-feature android:name="android.software.leanback" android:required="false" />` and `<uses-feature android:name="android.hardware.touchscreen" android:required="false" />`.
    * Add `android:banner="@drawable/tv_banner"` on `<application>` and `<category android:name="android.intent.category.LEANBACK_LAUNCHER" />` on `.MainActivity`.
  * Add 1 line in `MainActivity.configureFlutterEngine`: `TvBridge.register(flutterEngine, this)`.
* **Verification**:
  * Verify Kotlin syntax and manifest XML validity.
* **Commit Message**: `feat(tv-android): add TvBridge channel and Leanback launcher manifest`

---

### Epic 1.2: Dart `TvPlatform` Runtime, First-Launch Hive Defaults & Ethernet Support
Provide a single source of truth (`TvPlatform.isTv`) in Dart, seed TV-friendly preferences without editing `storage_pref.dart`, gate the Android TV soft keyboard so it only opens on explicit `OK`/`Enter` activation, and recognize Ethernet as broadband.

#### Task 1.2.1: Create `lib/tv/tv_platform.dart` with Hive Seeding & Soft-Keyboard Gate
* **Files**:
  * `[NEW] lib/tv/tv_platform.dart`
* **Implementation Details**:
  * Query `com.example.piliplus/tv` (`getTvEnvironment`) and support `--dart-define=PILI_FORCE_TV=true` override for testing.
  * Seed TV defaults into `GStorage.setting` on first TV launch (if not yet set by user):
    * `horizontalScreen`: `true`
    * `useSideBar`: `true`
    * `enableVerticalExpand`: `false`
    * `defaultFullScreen`: `true`
    * `autoPlayEnable`: `true`
  * Install a `SystemChannels.textInput` outgoing message gate when `TvPlatform.isTv`:
    * Suppresses automatic `TextInput.show` triggered merely by directional focus traversal landing on a `TextField`.
    * Exposes `TvPlatform.requestSoftKeyboard()` (called when user presses `Select`/`Enter` on a focused `EditableText` or `TextField`) which permits `TextInput.show` and invokes native `showSoftKeyboard`.
* **Verification**:
  * Run `flutter analyze lib/tv/tv_platform.dart`.
* **Commit Message**: `feat(tv-core): add TvPlatform runtime, Hive default seeding, and soft-keyboard gate`

#### Task 1.2.2: Support Wired Ethernet in `ConnectivityUtils.isWiFi`
* **Files**:
  * `[MODIFY] lib/utils/connectivity_utils.dart`
* **Implementation Details**:
  * Update `ConnectivityUtils.isWiFi` to check `results.contains(ConnectivityResult.wifi) || (TvPlatform.isTv && results.contains(ConnectivityResult.ethernet))` (and allow `TvPlatform.isTv` alongside `PlatformUtils.isMobile`).
  * Zero controllers need renaming (`isWiFi` remains the method name everywhere).
* **Verification**:
  * Run `flutter analyze lib/utils/connectivity_utils.dart`.
* **Commit Message**: `feat(tv-net): treat Ethernet as broadband inside ConnectivityUtils.isWiFi on TV`

---

## Milestone 2: Spatial 2D Focus Engine, Route Observer & App Root Integration

### Epic 2.1: Hardened 2D Focus Traversal Policy & Overlay Highlight (`lib/tv/tv_navigation.dart`)
Bring over the battle-tested 2D spatial focus traversal engine and enhance it with `RenderBox` geometry/offscreen introspection so zero upstream widget files (`animated_height.dart`, `app_bar_ani.dart`) need edits.

#### Task 2.1.1: Implement `lib/tv/tv_navigation.dart` (`TvFocusTraversalPolicy` & `TvNavigation`)
* **Files**:
  * `[NEW] lib/tv/tv_navigation.dart`
* **Implementation Details**:
  * Wrap app tree in `MediaQuery(data: mediaQuery.copyWith(navigationMode: NavigationMode.directional))` when `TvPlatform.isTv` (natively fixing `Slider` arrow-key traps across all dialogs/pages).
  * Implement `TvFocusTraversalPolicy`:
    * 2D directional cone scoring with primary-axis distance, cross-axis overlap, and same-row/column locking.
    * **RenderBox Geometry & Viewport Introspection**: Inside `_isEffectivelyFocusable(FocusNode node)`, inspect ancestor `RenderBox` sizes (`width < 1 || height < 1` → unfocusable, replacing `animated_height.dart` edits) and viewport intersection (`globalRect.intersect(screenRect)` empty → unfocusable, replacing `app_bar_ani.dart` edits).
    * **Nested Focus Deduplication & Micro-Button Filtering**: Skip parent wrapper if a descendant is already focusable; skip tiny secondary action buttons (`<= 36x36` inside a larger card) during vertical/horizontal grid navigation.
    * **Scroll Boundary & Dialog Escape**: Allow `Up`/`Down` at the edge of scrollable lists inside dialogs/sheets to escape to dialog header/footer buttons (`取消`/`确定`).
    * **EditableText Activation Handling**: When pressing `Select`/`Enter` while a `FocusNode` belonging to an `EditableText` (`TextField`) is focused, call `TvPlatform.requestSoftKeyboard()` to open the Android TV system keyboard.
    * **Visual Focus Ring**: Render a smooth, high-contrast focus border overlay around the active `FocusNode`.
* **Verification**:
  * Run `flutter analyze lib/tv/tv_navigation.dart`.
* **Commit Message**: `feat(tv-focus): add TvFocusTraversalPolicy with RenderBox introspection and focus ring`

---

### Epic 2.2: Route Focus Memory, Login QR Auto-Switch & `lib/main.dart` Hook
Ensure seamless page transitions, automatic QR-code tab selection on `LoginPage` without editing `lib/pages/login/`, and wire `TvNavigation` into `lib/main.dart`.

#### Task 2.2.1: Add `TvNavigationObserver` with Route Focus Restore & Login QR Auto-Tab
* **Files**:
  * `[MODIFY] lib/tv/tv_navigation.dart`
* **Implementation Details**:
  * Implement `TvNavigationObserver extends NavigatorObserver`:
    * Memorize last focused node before pushing a new route or dialog and restore it on pop.
    * When `route.settings.name == '/loginPage'` is pushed on TV, schedule a post-frame callback that looks up `Get.isRegistered<LoginPageController>()` and animates `tabController` to index `2` (`扫码登录`), avoiding any edits to `lib/pages/login/controller.dart` or `lib/pages/login/view.dart`.
* **Verification**:
  * Run `flutter analyze lib/tv/tv_navigation.dart`.
* **Commit Message**: `feat(tv-nav): add route focus memory and zero-touch LoginPage QR tab auto-switch`

#### Task 2.2.2: Wire `TvPlatform` & `TvNavigation` into `lib/main.dart`
* **Files**:
  * `[MODIFY] lib/main.dart`
* **Implementation Details**:
  * Call `await TvPlatform.initialize();` right after `GStorage.init()`.
  * Add `if (TvPlatform.isTv) TvNavigationObserver()` to `GetMaterialApp.navigatorObservers`.
  * Wrap the return widget of `MyApp._builder` with `TvNavigation(onBack: _onBack, child: child)`.
* **Verification**:
  * Run `flutter analyze lib/main.dart`.
* **Commit Message**: `feat(tv-main): hook TvPlatform and TvNavigation into main.dart`

---

## Milestone 3: Build-Time SDK & Widget Patch Pipeline (`lib/scripts/`)

### Epic 3.1: Flutter SDK & `material_ui` TV Patches
Eliminate the need to edit 40+ upstream PiliPlus page/widget files by adding 3 targeted build-time patches applied by `lib/scripts/patch.ps1`.

#### Task 3.1.1: Create `lib/scripts/tv_gesture_detector.patch` (Bare `GestureDetector` D-Pad Support)
* **Files**:
  * `[NEW] lib/scripts/tv_gesture_detector.patch`
* **Implementation Details**:
  * Patch `$FLUTTER_ROOT/packages/flutter/lib/src/widgets/gesture_detector.dart` in `GestureDetector.build`:
    * When `MediaQuery.maybeNavigationModeOf(context) == NavigationMode.directional` and `onTap != null` (or `onSecondaryTap != null`), wrap the returned `RawGestureDetector` with a `Focus` widget that handles `LogicalKeyboardKey.select`, `enter`, `numpadEnter`, and `gameButtonA` by invoking `onTap!()`.
* **Verification**:
  * Verify `git apply --check` against `$FLUTTER_ROOT`.
* **Commit Message**: `feat(tv-patch): add tv_gesture_detector.patch for automatic D-pad focus and activation`

#### Task 3.1.2: Create `lib/scripts/tv_radio_group.patch` (Un-trap `RadioGroup` Arrow Keys)
* **Files**:
  * `[NEW] lib/scripts/tv_radio_group.patch`
* **Implementation Details**:
  * Patch `$FLUTTER_ROOT/packages/flutter/lib/src/widgets/radio_group.dart`:
    * Bypass `RadioGroup`'s internal arrow-key (`arrowUp`, `arrowDown`, `arrowLeft`, `arrowRight`) shortcut map when `MediaQuery.maybeNavigationModeOf(context) == NavigationMode.directional`, allowing `TvFocusTraversalPolicy` to move focus freely across radio options and out to dialog buttons (`取消`/`确定`).
* **Verification**:
  * Verify `git apply --check` against `$FLUTTER_ROOT`.
* **Commit Message**: `feat(tv-patch): add tv_radio_group.patch to prevent arrow-key focus traps in dialogs`

#### Task 3.1.3: Create `lib/scripts/material/tv_ink_well.patch` & `lib/scripts/tv_ink_well.patch` (Triple-Like & Coordinate Popup Support)
* **Files**:
  * `[NEW] lib/scripts/material/tv_ink_well.patch`
  * `[NEW] lib/scripts/tv_ink_well.patch`
* **Implementation Details**:
  * Patch `_InkResponseState` in `material_ui` (`lib/src/ink_well.dart`) and Flutter SDK (`packages/flutter/lib/src/material/ink_well.dart`):
    1. Consider `InkResponse` enabled/focusable in `NavigationMode.directional` when `widget.onTap != null || widget.onTapDown != null || widget.onTapUp != null || widget.onLongPress != null`.
    2. In `activateOnIntent` (and OK key press/hold), if `widget.onTap == null`:
       * If `widget.onTapDown != null && widget.onTapUp != null` (e.g., `ActionItem` Like / Hold-to-Triple-Like), synthesize `onTapDown(TapDownDetails())` on key-down / intent and `onTapUp(TapUpDetails(...))` on key-up / intent so both single-press Like and long-press Triple-Like work natively on TV!
       * If `widget.onTapUp != null` (e.g., `PopupListTile` account switcher), compute the global center position of `context.findRenderObject() as RenderBox` and invoke `widget.onTapUp!(TapUpDetails(kind: PointerDeviceKind.unknown, globalPosition: center, localPosition: localCenter))`.
* **Verification**:
  * Verify `git apply --check` against both `$FLUTTER_ROOT` and `material_ui` in pub-cache.
* **Commit Message**: `feat(tv-patch): add tv_ink_well.patch for ActionItem triple-like and PopupListTile support`

---

### Epic 3.2: Patch Pipeline Integration & Local Developer Tooling
Register the TV patches in `lib/scripts/patch.ps1` and provide a cross-platform `tool/tv_patch.sh` script for local macOS/Linux development.

#### Task 3.2.1: Register TV Patches in `lib/scripts/patch.ps1` and Add `tool/tv_patch.sh`
* **Files**:
  * `[MODIFY] lib/scripts/patch.ps1`
  * `[NEW] tool/tv_patch.sh`
* **Implementation Details**:
  * Add `$TvGestureDetectorPatch`, `$TvRadioGroupPatch`, and `$TvInkWellPatch` to `lib/scripts/patch.ps1` (and `$TvInkWellPatchMaterial` to `$patches_material`).
  * Create executable `tool/tv_patch.sh` supporting `./tool/tv_patch.sh apply`, `./tool/tv_patch.sh revert`, and `./tool/tv_patch.sh status` on macOS/Linux.
* **Verification**:
  * Run `./tool/tv_patch.sh apply` and `./tool/tv_patch.sh status` locally to confirm clean application.
* **Commit Message**: `build(tv-patch): wire TV patches into patch.ps1 and add tool/tv_patch.sh helper`

---

## Milestone 4: Self-Contained 10-Foot TV Player HUD

### Epic 4.1: `TvPlayerHud` Overlay & `PlayerFocus` Micro-Hook
Provide a rich 10-foot D-pad player OSD that auto-discovers PiliPlus controllers (`PlPlayerController`, `CommonIntroController`, `VideoDetailController`, `LiveRoomController`) without requiring any edits to `video/view.dart` or `live_room/view.dart`.

#### Task 4.1.1: Implement `lib/tv/tv_player_hud.dart` with Controller Auto-Discovery
* **Files**:
  * `[NEW] lib/tv/tv_player_hud.dart`
* **Implementation Details**:
  * Build `TvPlayerHud` accepting `plPlayerController`, `introController`, `onSendDanmaku`, `canPlay`, `onSkipSegment`, `onRefresh`, and `child`.
  * When `plPlayerController.isFullScreen.value` (or when the player area holds focus on TV):
    * **HUD Hidden**:
      * `Left` / `Right`: Seek `-10s` / `+10s` (with hold-to-scrub acceleration and OSD time preview).
      * `Select` / `Enter` / `Space` / `MediaPlayPause`: Toggle Play/Pause.
      * `Up` / `Down` / `Menu` / `Info`: Show the TV HUD control bar and focus the primary transport button.
      * `Back` / `Escape`: Exit fullscreen if fullscreen, otherwise pop route.
    * **HUD Visible**:
      * Top/Bottom 10-foot OSD bar with D-pad focusable pills:
        * Play/Pause, Seek bar, Danmaku toggle, Danmaku settings, Quality selector, Playback speed selector, Episode/Part selector (auto-discovered from `introController`), Aspect ratio / View fit, Like / Hold-to-Triple-Like, Coin, Favorite.
      * Auto-hide timer (resets on D-pad activity; `Back` immediately hides HUD).
* **Verification**:
  * Run `flutter analyze lib/tv/tv_player_hud.dart`.
* **Commit Message**: `feat(tv-player): add self-contained TvPlayerHud with controller auto-discovery`

#### Task 4.1.2: Add 4-Line `TvPlayerHud` Micro-Hook in `lib/pages/video/widgets/player_focus.dart`
* **Files**:
  * `[MODIFY] lib/pages/video/widgets/player_focus.dart`
* **Implementation Details**:
  * Import `package:PiliPlus/tv/tv_platform.dart` and `package:PiliPlus/tv/tv_player_hud.dart`.
  * In `PlayerFocus.build`, when `TvPlatform.isTv`, return `TvPlayerHud(...)` wrapping the focus/player subtree.
* **Verification**:
  * Run `flutter analyze lib/pages/video/widgets/player_focus.dart`.
* **Commit Message**: `feat(tv-player): hook TvPlayerHud into PlayerFocus`

---

## Milestone 5: CI/CD Upstream Sync Configuration & End-to-End Verification

### Epic 5.1: GitHub Actions Sync from `lemonteaau/PiliPlus` & Android-Only Build
Configure CI so `PiliPlus-LemonTeaV` automatically syncs from `https://github.com/lemonteaau/PiliPlus.git` and builds Android APKs.

#### Task 5.1.1: Update `.github/workflows/sync-upstream-build.yml` and `.github/workflows/build.yml`
* **Files**:
  * `[MODIFY] .github/workflows/sync-upstream-build.yml`
  * `[MODIFY] .github/workflows/build.yml`
* **Implementation Details**:
  * Point the `upstream` git remote in `sync-upstream-build.yml` to `https://github.com/lemonteaau/PiliPlus.git` (inheriting both `bggRGjQaUbCoE/PiliPlus` official updates and `lemonteaau`'s BTR updates).
  * Streamline build jobs in `sync-upstream-build.yml` and `build.yml` to build Android APKs (`arm64-v8a`, `armeabi-v7a`, `x86_64`), removing unneeded iOS, Windows, macOS, and Linux CI build matrices.
* **Verification**:
  * Validate YAML syntax and workflow job dependencies (`sync` → `android` → `release`).
* **Commit Message**: `ci(sync): sync upstream from lemonteaau/PiliPlus and target Android APK builds`

---

### Epic 5.2: Unit Tests, Static Analysis & Dual-Device TV Verification
Verify that all patches apply cleanly, `flutter analyze` and unit tests pass, release/debug APKs build cleanly, and end-to-end TV controls are verified on both the Android TV VM (`arm64-v8a`) and the physical Android TV device over ADB.

#### Task 5.2.1: Add TV Unit/Widget Tests and Run Dual-Device Verification (VM TV `arm64-v8a` + Physical TV)
* **Files**:
  * `[NEW] test/tv_navigation_test.dart`
  * `[MODIFY] docs/tv/PROGRESS.md`
* **Implementation Details**:
  * Write unit/widget tests in `test/tv_navigation_test.dart` covering:
    * 2D spatial traversal (`TvFocusTraversalPolicy`) across grids and dialog buttons;
    * Automatic filtering of zero-height (`AnimatedSize` / `Align(heightFactor: 0)`) and off-screen (`SlideTransition`) nodes;
    * Patched `GestureDetector(onTap)` D-pad focus and `Select`/`Enter` activation in `NavigationMode.directional`;
    * Patched `RadioGroup` directional arrow-key escape;
    * Patched `InkWell` (`onTapDown`/`onTapUp` and `onTapUp(TapUpDetails)`) keyboard activation.
  * Run `flutter test test/tv_navigation_test.dart test/thread_ripper_test.dart test/thread_ripper_auto_test.dart` and `flutter analyze`.
  * Build split-ABI Android APKs (`armeabi-v7a`, `arm64-v8a`) and verify installation + live D-pad interaction on:
    1. **Android TV Virtual Machine (VM TV, `arm64-v8a`)**;
    2. **Physical Android TV Device** via ADB (`$TV_DEVICE_ADDR`, matching its `ro.product.cpu.abi` ABI).
  * Record sanitized verification results in `docs/tv/PROGRESS.md` (with no IP addresses, ports, or local machine paths).
* **Commit Message**: `test(tv): add TV control layer widget tests and complete dual-device verification`

---

## Milestone 6: D-Pad High-Frequency Input & Traversal Performance Hardening

### Epic 6.1: Focus Traversal Caching, Overlay Isolation & Input Pacing
Eliminate UI thread freezes, root widget rebuild storms, and Input Dispatching ANRs under rapid D-pad clicking or key-repeat holding while keeping all changes 100% self-contained inside `lib/tv/tv_navigation.dart` and `test/tv_navigation_test.dart`.

#### Task 6.1.1: Document Milestone 6 Plan in `docs/tv/`
* **Files**:
  * `[MODIFY] docs/tv/PLAN.md`
  * `[MODIFY] docs/tv/PROGRESS.md`
* **Implementation Details**:
  * Add Milestone 6 (`Epic 6.1`, `Task 6.1.1`, `Task 6.1.2`, `Task 6.1.3`) to `docs/tv/PLAN.md` and `docs/tv/PROGRESS.md`.
* **Commit Message**: `docs(tv): add Milestone 6 D-pad input and traversal performance hardening plan`

#### Task 6.1.2: Harden `TvFocusTraversalPolicy` & `TvNavigation` for High-Frequency D-Pad Input
* **Files**:
  * `[MODIFY] lib/tv/tv_navigation.dart`
  * `[MODIFY] docs/tv/PROGRESS.md`
* **Implementation Details**:
  * **Single-Pass Traversal Metadata Snapshot (`_TvNodeMeta` & `_TvTraversalCache`)**:
    * Collect each candidate node's `rect`, `verticalScrollable`, `horizontalScrollable`, `enclosingListTile`, `enclosingInkResponse`, and `enclosingWrap` in a single `visitAncestorElements` walk per node at the start of `inDirection()`.
    * Memoize ancestor `RenderBox` global bounds (`Map<RenderBox, Rect>`) and `ScrollableState` global rects (`Map<ScrollableState, Rect?>`) so `localToGlobal` is computed at most once per `RenderBox` per traversal pass.
    * Refactor `inDirection`, `_filterOutEmbeddedSecondaryActions`, `_findVerticalCandidate`, `_pickFromClosestRow`, and `_findHorizontalCandidate` to perform $O(1)$ metadata lookups instead of repeated `node.rect` and `visitAncestorElements` walks.
  * **Isolate Focus Ring Overlay (`ValueNotifier<Rect?>` + `RepaintBoundary` + `CustomPaint`)**:
    * Replace `Rect? _rect` and `_TvNavigationState.setState()` with `ValueNotifier<Rect?> _rectNotifier` driving a `Positioned.fill` → `IgnorePointer` → `RepaintBoundary` → `ValueListenableBuilder<Rect?>` → `CustomPaint(painter: _TvFocusRingPainter(rect))` layer so focus ring updates never rebuild `TvNavigation` or relayout the root `RenderStack`.
  * **Deduplicate `_onFocus` & Eliminate Competing `120ms` Scroll Animations**:
    * Guard `_onFocus` post-frame scheduling with `bool _focusSyncScheduled` so multiple `FocusManager` notifications in a single frame coalesce into one callback.
    * Track the last node scrolled by `TvFocusTraversalPolicy._focusNode` (`FocusNode? _lastPolicyScrolledNode`) so `_onFocus` does not start a second conflicting `Scrollable.ensureVisible` animation on directional focus steps; use synchronous `ScrollPositionAlignmentPolicy.explicit` (`Duration.zero`) for non-policy focus changes.
  * **Frame-Paced Directional Traversal & Key-Repeat Throttling**:
    * Gate `TvFocusTraversalPolicy.inDirection` to at most one directional step per rendered frame (`_traversalLockedThisFrame`, cleared via `addPostFrameCallback`) so buffered same-frame key events cannot traverse on stale pre-layout `RenderBox` coordinates.
    * Throttle held directional `KeyRepeatEvent`s (`arrowUp`, `arrowDown`, `arrowLeft`, `arrowRight`) in `_TvNavigationState._handleKeyEvent` to a `45ms` minimum interval (~22 steps/sec max repeat rate) while allowing distinct `KeyDownEvent` clicks to execute on every frame.
* **Verification**:
  * Run `flutter analyze --no-pub lib/tv/tv_navigation.dart`.
* **Commit Message**: `perf(tv-focus): cache traversal metadata, isolate focus ring repaint, and pace rapid D-pad input`

#### Task 6.1.3: Add Rapid D-Pad Stress & Zero-Root-Rebuild Tests and Verify on Dual TV Devices
* **Files**:
  * `[MODIFY] test/tv_navigation_test.dart`
  * `[MODIFY] docs/tv/PROGRESS.md`
* **Implementation Details**:
  * Add widget tests in `test/tv_navigation_test.dart` verifying:
    1. Zero `TvNavigation` child rebuilds across multiple D-pad focus moves and list scrolls (`buildCount == 1`).
    2. High-frequency D-pad burst & key-repeat throttling across a scrollable `ListView.builder` (30 rapid directional events with same-frame bursts and `KeyRepeatEvent`s) completing with zero exceptions and deterministic focus progression.
  * Run `flutter analyze --no-pub` and `flutter test --no-pub`.
  * Build split-ABI release APKs and stress-test rapid D-pad clicking and key-repeat holding on both `<vm-tv>` (`arm64-v8a`) and `<physical-tv>` (`armeabi-v7a`).
* **Commit Message**: `test(tv-focus): add rapid D-pad stress and zero-rebuild tests and verify on TV devices`

