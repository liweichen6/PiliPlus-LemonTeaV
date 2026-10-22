# PiliPlus-LemonTeaV: TV Porting Progress & Change Log

This document tracks the task-by-task execution progress of [`docs/tv/PLAN.md`](./PLAN.md). Every completed task updates this file and is committed atomically.

> **Privacy & Sanitization Rule**: Never record LAN IP addresses/ports, local filesystem absolute paths, file-scheme URLs, or any other personal information in this log or commit messages. Use relative paths and generic placeholders (`<vm-tv>`, `<physical-tv>`).

---

## Task Status Matrix

| Milestone | Epic | Task ID | Task Title | Status | Commit |
| :--- | :--- | :--- | :--- | :--- | :--- |
| **M0: Docs** | Epic 0.1 | `0.1.1` | Create `docs/tv/` Planning Suite | ✅ Done | `da93d93b2` |
| **M1: Platform** | Epic 1.1 | `1.1.1` | Implement `TvBridge.kt` & Leanback Manifest | ✅ Done | `198612d11` |
| **M1: Platform** | Epic 1.2 | `1.2.1` | Create `lib/tv/tv_platform.dart` (Hive seeding + Soft-keyboard gate) | ✅ Done | `c6d8e2c16` |
| **M1: Platform** | Epic 1.2 | `1.2.2` | Support Wired Ethernet in `ConnectivityUtils.isWiFi` | ✅ Done | `35ceaa5c3` |
| **M2: Focus** | Epic 2.1 | `2.1.1` | Implement `lib/tv/tv_navigation.dart` (`TvFocusTraversalPolicy` + `RenderBox` introspection) | ✅ Done | `2b51b7b32` |
| **M2: Focus** | Epic 2.2 | `2.2.1` | Add `TvNavigationObserver` (Focus restore + Login QR auto-tab) | ✅ Done | `540aaa9f5` |
| **M2: Focus** | Epic 2.2 | `2.2.2` | Wire `TvPlatform` & `TvNavigation` into `lib/main.dart` | ✅ Done | `d053ad2e5` |
| **M3: Patches** | Epic 3.1 | `3.1.1` | Create `lib/scripts/tv_gesture_detector.patch` | ✅ Done | `643893b9c` |
| **M3: Patches** | Epic 3.1 | `3.1.2` | Create `lib/scripts/tv_radio_group.patch` | ✅ Done | `e6990d48e` |
| **M3: Patches** | Epic 3.1 | `3.1.3` | Create `lib/scripts/material/tv_ink_well.patch` & `lib/scripts/tv_ink_well.patch` | ✅ Done | `fffaee51a` |
| **M3: Patches** | Epic 3.2 | `3.2.1` | Register TV patches in `patch.ps1` and add `tool/tv_patch.sh` | ✅ Done | `142f5ae6d` |
| **M4: Player HUD** | Epic 4.1 | `4.1.1` | Implement `lib/tv/tv_player_hud.dart` with controller auto-discovery | ✅ Done | `cbf030b75` |
| **M4: Player HUD** | Epic 4.1 | `4.1.2` | Add 4-line `TvPlayerHud` hook in `player_focus.dart` | ✅ Done | `e65f57eb4` |
| **M5: CI & Verify** | Epic 5.1 | `5.1.1` | Update `.github/workflows/` to sync `lemonteaau/PiliPlus` & build Android APKs | ✅ Done | `758b6fa5b` |
| **M5: CI & Verify** | Epic 5.2 | `5.2.1` | Add TV widget tests (`test/tv_navigation_test.dart`) & verify full build | ✅ Done | `9da6200ed` |

---

## Detailed Task Log

### [2026-10-21] Task 0.1.1: Create `docs/tv/` Planning Suite
* **Status**: ✅ Completed (`da93d93b2`)
* **Files Added**:
  * `docs/tv/README.md`
  * `docs/tv/ARCHITECTURE.md`
  * `docs/tv/PLAN.md`
  * `docs/tv/PROGRESS.md`
* **Key Decisions Recorded**:
  1. **Upstream Sync & CI**: Sync from `lemonteaau/PiliPlus` (inheriting both `bggRGjQaUbCoE/PiliPlus` and `lemonteaau`'s BTR updates) and build Android APKs only in CI.
  2. **SDK / Package Patching**: Use build-time patches in `lib/scripts/` (`tv_gesture_detector.patch`, `tv_radio_group.patch`, `tv_ink_well.patch`) plus a local `tool/tv_patch.sh` helper so **0 upstream page/widget files** need manual edits.
  3. **Text Input & Login**: Skip the LAN QR-Code Phone Input server; use the native Android TV system soft keyboard (gated to open only on explicit `OK`/`Enter` activation on a focused `TextField`) and auto-switch `LoginPage` to the QR login tab (`index == 2`) via `TvNavigationObserver`.
  4. **TV Defaults & Settings**: Seed TV-optimal defaults into Hive `GStorage.setting` on first TV launch inside `TvPlatform.initialize()` (**0 edits** to `storage_pref.dart` or `setting/view.dart`).

### [2026-10-21] Task 1.1.1: Implement `TvBridge.kt` and Leanback Manifest Configuration
* **Status**: ✅ Completed (`198612d11`)
* **Files Changed**:
  * `[NEW] android/app/src/main/kotlin/com/example/piliplus/TvBridge.kt`
  * `[NEW] android/app/src/main/res/drawable/tv_banner.xml`
  * `[MODIFY] android/app/src/main/AndroidManifest.xml`
  * `[MODIFY] android/app/src/main/kotlin/com/example/piliplus/MainActivity.kt`
* **Changes Summary**:
  * Created `TvBridge.kt` registering MethodChannel `com.example.piliplus/tv` with `getTvEnvironment`, `isTelevision`, `showSoftKeyboard`, and `hideSoftKeyboard`.
  * Added 320x180dp Leanback vector banner (`res/drawable/tv_banner.xml`) and updated `AndroidManifest.xml` with optional `android.software.leanback` / `android.hardware.touchscreen` features, `android:banner="@drawable/tv_banner"`, and `android.intent.category.LEANBACK_LAUNCHER`.
  * Registered `TvBridge.register(flutterEngine, this)` in `MainActivity.configureFlutterEngine` (1 line added).
* **Verification**:
  * `xmllint --noout android/app/src/main/AndroidManifest.xml android/app/src/main/res/drawable/tv_banner.xml` passed cleanly.

### [2026-10-21] Task 1.2.1: Create `lib/tv/tv_platform.dart` with Hive Seeding & Soft-Keyboard Gate
* **Status**: ✅ Completed (`c6d8e2c16`)
* **Files Changed**:
  * `[NEW] lib/tv/tv_platform.dart`
* **Changes Summary**:
  * Implemented `TvPlatform` querying `com.example.piliplus/tv` (`getTvEnvironment` with fallback to `isTelevision`) and supporting `--dart-define=PILI_FORCE_TV=true`.
  * Implemented `seedTvDefaultsToBox` to seed TV-optimal defaults (`horizontalScreen`, `useSideBar`, `enableVerticalExpand`, `enableAutoEnter`, `autoPlayEnable`, `enableShowDanmaku`, `fullScreenMode`, `recommendCardWidth`, `defaultTextScale`, `showFsScreenshotBtn`, `showFsLockBtn`, `themeMode`) into `GStorage.setting` on first TV launch without overwriting user-configured keys.
  * Installed `_TvTextInputGateControl` (`TextInputControl`) when `TvPlatform.isTv` to suppress automatic virtual keyboard popups during D-pad traversal, and exposed `TvPlatform.requestSoftKeyboard()` / `TvPlatform.hideSoftKeyboard()` for explicit `Select`/`Enter` activation on focused `EditableText` widgets.
* **Verification**:
  * `flutter analyze lib/tv/tv_platform.dart` passed with `No issues found!`.

### [2026-10-21] Task 1.2.2: Support Wired Ethernet in `ConnectivityUtils.isWiFi`
* **Status**: ✅ Completed (`35ceaa5c3`)
* **Files Changed**:
  * `[MODIFY] lib/utils/connectivity_utils.dart`
* **Changes Summary**:
  * Updated `ConnectivityUtils.isWiFi` to allow `TvPlatform.isTv` alongside `PlatformUtils.isMobile` and treat `ConnectivityResult.ethernet` as broadband when `TvPlatform.isTv` is true.
* **Verification**:
  * `flutter analyze lib/utils/connectivity_utils.dart` passed with `No issues found!`.

### [2026-10-21] Task 2.1.1: Implement `lib/tv/tv_navigation.dart` (`TvFocusTraversalPolicy` & `TvNavigation`)
* **Status**: ✅ Completed (`2b51b7b32`)
* **Files Changed**:
  * `[NEW] lib/tv/tv_navigation.dart`
* **Changes Summary**:
  * Implemented `TvFocusTraversalPolicy` with 2D row/column directional traversal, `RenderBox` ancestor size & viewport intersection introspection (eliminating edits to `animated_height.dart` and `app_bar_ani.dart`), nested focus deduplication, micro-button (`<= 36x36`) filtering, scrollable boundary/dialog escape, and `consumeKeyboardToken()` on focus transition.
  * Implemented `TvNavigation` wrapper setting `NavigationMode.directional`, intercepting `Select`/`Enter` on focused `EditableText` nodes to invoke `TvPlatform.requestSoftKeyboard()`, and rendering the `#FFFFD166` focus ring overlay.
* **Verification**:
  * `flutter analyze lib/tv/tv_navigation.dart` passed with `No issues found!`.

### [2026-10-21] Task 2.2.1: Add `TvNavigationObserver` with Route Focus Restore & Login QR Auto-Tab
* **Status**: ✅ Completed (`540aaa9f5`)
* **Files Changed**:
  * `[MODIFY] lib/tv/tv_navigation.dart`
* **Changes Summary**:
  * Added `TvNavigationObserver` using `Expando<FocusNode>` to memorize the last active `FocusNode` per `ModalRoute` and restore focus when popping routes/dialogs.
  * Added automatic post-frame tab switching for `/loginPage` on TV via `Get.find<LoginPageController>().tabController.animateTo(2)` (`扫码登录`), requiring **0 edits** to `lib/pages/login/`.
* **Verification**:
  * `flutter analyze lib/tv/tv_navigation.dart` passed with `No issues found!`.

### [2026-10-21] Task 2.2.2: Wire `TvPlatform` & `TvNavigation` into `lib/main.dart`
* **Status**: ✅ Completed (`d053ad2e5`)
* **Files Changed**:
  * `[MODIFY] lib/main.dart`
* **Changes Summary**:
  * Added `await TvPlatform.initialize();` immediately after `GStorage.init()`.
  * Added `if (TvPlatform.isTv) TvNavigationObserver()` to `GetMaterialApp.navigatorObservers`.
  * Wrapped the widget returned by `MyApp._builder` in `TvNavigation(onBack: _onBack, child: child)` when `TvPlatform.isTv` is true.
* **Verification**:
  * `flutter analyze lib/main.dart` passed with `No issues found!`.

### [2026-10-21] Task 3.1.1: Create `lib/scripts/tv_gesture_detector.patch`
* **Status**: ✅ Completed (`643893b9c`)
* **Files Changed**:
  * `[NEW] lib/scripts/tv_gesture_detector.patch`
* **Changes Summary**:
  * Patched `GestureDetector.build` in `packages/flutter/lib/src/widgets/gesture_detector.dart` so standalone `GestureDetector` widgets (`!excludeFromSemantics && (onTap != null || onLongPress != null)`) in `NavigationMode.directional` wrap `RawGestureDetector` in a `Focus` node that activates `onTap` on `KeyDownEvent` and `onLongPress` on `KeyRepeatEvent` for `Select`/`Enter` when holding primary focus.
* **Verification**:
  * `git apply --check lib/scripts/tv_gesture_detector.patch` against `$FLUTTER_ROOT` passed with exit code `0`.

### [2026-10-21] Task 3.1.2: Create `lib/scripts/tv_radio_group.patch`
* **Status**: ✅ Completed (`e6990d48e`)
* **Files Changed**:
  * `[NEW] lib/scripts/tv_radio_group.patch`
* **Changes Summary**:
  * Patched `_RadioGroupState.build` in `packages/flutter/lib/src/widgets/radio_group.dart` to bypass `_radioGroupShortcutManager` and `_SkipUnselectedRadioPolicy` when `MediaQuery.maybeNavigationModeOf(context) == NavigationMode.directional`, preventing arrow-key focus traps in dialogs while preserving `_RadioGroupStateScope`.
* **Verification**:
  * `git apply --check lib/scripts/tv_radio_group.patch` against `$FLUTTER_ROOT` passed with exit code `0`.

### [2026-10-21] Task 3.1.3: Create `lib/scripts/material/tv_ink_well.patch` & `lib/scripts/tv_ink_well.patch`
* **Status**: ✅ Completed (`fffaee51a`)
* **Files Changed**:
  * `[NEW] lib/scripts/material/tv_ink_well.patch`
  * `[NEW] lib/scripts/tv_ink_well.patch`
* **Changes Summary**:
  * Patched `_InkResponseState` in `material_ui` (`lib/src/ink_well.dart`) and Flutter SDK (`packages/flutter/lib/src/material/ink_well.dart`) to:
    * Respect `enabled && widget.canRequestFocus` in `NavigationMode.directional`.
    * Synthesize `TapDownDetails` and `TapUpDetails` using the `RenderBox` global/local center in `activateOnIntent` when `widget.onTap == null`, supporting coordinate-dependent popups such as `PopupListTile`.
    * Support D-pad `Select`/`Enter` key-down (`handleTapDown`) and key-up (`handleTapUp`) on `InkWell` widgets with `onTap == null && onTapDown != null && onTapUp != null`, enabling both single-press Like and hold-to-Triple-Like (`ActionItem`) on TV.
* **Verification**:
  * `git apply --check lib/scripts/material/tv_ink_well.patch` (against `material_ui`) and `git apply --check lib/scripts/tv_ink_well.patch` (against `$FLUTTER_ROOT`) both passed with exit code `0`.

### [2026-10-21] Task 3.2.1: Register TV Patches in `lib/scripts/patch.ps1` and Create `tool/tv_patch.sh`
* **Status**: ✅ Completed (`142f5ae6d`)
* **Files Changed**:
  * `[MODIFY] lib/scripts/patch.ps1`
  * `[NEW] tool/tv_patch.sh`
* **Changes Summary**:
  * Registered `tv_gesture_detector.patch`, `tv_radio_group.patch`, and `tv_ink_well.patch` in `lib/scripts/patch.ps1` (`$patches`), and `material/tv_ink_well.patch` in `$patches_material`.
  * Added idempotent `tool/tv_patch.sh` (`apply`, `revert`, `status`) for local developer patching of `$FLUTTER_ROOT` and `material_ui` in pub-cache.
* **Verification**:
  * `./tool/tv_patch.sh apply`, `./tool/tv_patch.sh status`, and `flutter analyze lib/tv/` passed with `No issues found!`.

### [2026-10-21] Task 4.1.1: Implement `lib/tv/tv_player_hud.dart` with Controller Auto-Discovery
* **Status**: ✅ Completed (`cbf030b75`)
* **Files Changed**:
  * `[NEW] lib/tv/tv_player_hud.dart`
* **Changes Summary**:
  * Implemented `TvPlayerHud` discovering `VideoDetailController`, `UgcIntroController`, `PgcIntroController`, and `LiveRoomController` dynamically via `Get.isRegistered<T>(tag: heroTag)` (requiring **0 edits** to `video/view.dart` or `live_room/view.dart`).
  * Implemented split-screen Quick Strip (`[⛶ 全屏播放]`, `[⏯ 播放/暂停]`, `[⚙ 播控面板]`, `[← 返回]`) that lets D-pad arrow keys pass through to `TvFocusTraversalPolicy` when `!isFullScreen` and `!_hudVisible`.
  * Implemented fullscreen / active 10-foot HUD mode with upstream touch-control suppression (`showControls.value = false`), `-10s/+10s` seeking with hold acceleration and centered OSD time preview (`⏪ 01:25 / 12:40`), 5-second inactivity auto-hide, and D-pad dialogs for Episodes/Parts, Video/Live Quality, Speed, Aspect Ratio (`VideoFitType`), Danmaku Toggle & Danmaku Settings (`DanmakuOptions`), plus Like / Hold-to-Triple-Like (`_TvTripleLikePill`), Coin, and Favorite pills.
* **Verification**:
  * `flutter analyze lib/tv/tv_player_hud.dart` passed with `No issues found!`.

### [2026-10-21] Task 4.1.2: Add `TvPlayerHud` Micro-Hook in `lib/pages/video/widgets/player_focus.dart`
* **Status**: ✅ Completed (`e65f57eb4`)
* **Files Changed**:
  * `[MODIFY] lib/pages/video/widgets/player_focus.dart`
* **Changes Summary**:
  * Added early return in `PlayerFocus.build(BuildContext context)` wrapping `child` in `TvPlayerHud` when `TvPlatform.isTv` is true.
* **Verification**:
  * `flutter analyze lib/pages/video/widgets/player_focus.dart` passed with `No issues found!`.

### [2026-10-21] Task 5.1.1: Update `.github/workflows/` to Sync `lemonteaau/PiliPlus` & Build Android APKs
* **Status**: ✅ Completed (`758b6fa5b`)
* **Files Changed**:
  * `[MODIFY] .github/workflows/sync-upstream-build.yml`
  * `[MODIFY] .github/workflows/build.yml`
* **Changes Summary**:
  * Updated `sync-upstream-build.yml` to fetch and merge `https://github.com/lemonteaau/PiliPlus.git` (`main`) and build Android APKs only (removing iOS, Windows, macOS, and Linux jobs).
  * Updated `build.yml` `workflow_dispatch` inputs so Android APK builds are enabled by default and desktop/iOS targets default to `false`.
* **Verification**:
  * YAML syntax check passed for both workflow files.

### [2026-10-21] Task 5.2.1: Add Unit/Widget Tests for TV Control Layer & Dual-Device Verification
* **Status**: ✅ Completed (`9da6200ed` + review hardening)
* **Files Changed**:
  * `[NEW] test/tv_navigation_test.dart`
  * `[MODIFY] lib/tv/tv_platform.dart`
  * `[MODIFY] lib/tv/tv_navigation.dart`
  * `[MODIFY] lib/tv/tv_player_hud.dart`
  * `[MODIFY] .github/workflows/sync-upstream-build.yml`
  * `[MODIFY] tool/tv_patch.sh`
* **Changes Summary**:
  * Created `test/tv_navigation_test.dart` with 11 unit/widget tests covering:
    * `TvPlatform.seedTvDefaultsToBox` idempotency, `FullScreenMode.none.index` (`1`), and preservation of user-customized settings.
    * `TvFocusTraversalPolicy` 2D grid directional movement, zero-height (`AnimatedHeightWidget`) and micro-button (`<= 36x36`) candidate filtering, ancestor clip-bounds (`RenderClipRect` / `RenderClipRRect` / `RenderClipPath`) filtering for slide-translated `AppBarAni` controls, and scrollable boundary exit to sibling buttons.
    * Patched `GestureDetector` D-pad `Select`/`Enter` `onTap` (`KeyDownEvent`) and `onLongPress` (`KeyRepeatEvent`) activation.
    * Patched `RadioGroup` unobstructed arrow-key traversal in `NavigationMode.directional`.
    * Patched `InkWell` (`material_ui`) D-pad key-down (`onTapDown`) and key-up (`onTapUp`) activation for `ActionItem` triple-like and coordinate-dependent `PopupListTile` callbacks.
    * `TvNavigationObserver` route focus restoration on dialog pop and soft-keyboard gating (`TextField` traversal without keyboard popup until explicit `Select`/`Enter`).
  * Updated `lib/tv/tv_navigation.dart` to import `package:material_ui/material_ui.dart` and intersect candidate rect visibility with ancestor clip layers (`RenderClipRect`, `RenderClipRRect`, `RenderClipPath`).
  * Hardened `lib/tv/tv_player_hud.dart` with `ExcludeFocus(excluding: isFullScreen || _hudVisible)` around `widget.child`, dedicated `_surfaceFocusNode` lifecycle tracking `isFullScreen` transitions and post-dialog focus restoration, and `ModalRoute.addScopedWillPopCallback` handling so Android TV `KEYCODE_BACK` closes only the active HUD or exits fullscreen without double-firing on `KeyDownEvent` + system `onBackPressed()`.
  * Fixed `SettingBoxKey.fullScreenMode` in `TvPlatform.defaultTvSettings` to `1` (`FullScreenMode.none.index`) and aligned `.github/workflows/sync-upstream-build.yml` to use `--no-pub` during `flutter build apk`.
  * Updated `tool/tv_patch.sh` to apply all upstream Android and TV patches idempotently for local testing and release builds.
* **Verification**:
  * `flutter test --no-pub` passed all 66 tests across the repository (`test/tv_navigation_test.dart` + existing test suites).
  * `flutter analyze --no-pub` passed with `No issues found!`.
  * Built release APKs (`flutter build apk --release --split-per-abi --no-pub`) and verified installation, Leanback launcher resolution, cold/warm launch, fullscreen auto-enter, `TvPlayerHud` overlay/dialogs, single-press Back HUD dismissal and fullscreen-to-split-screen transition, and D-pad navigation with zero runtime exceptions on both `<vm-tv>` (`arm64-v8a`) and `<physical-tv>` (`armeabi-v7a`).

