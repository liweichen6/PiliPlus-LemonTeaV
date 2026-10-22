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
| **M2: Focus** | Epic 2.1 | `2.1.1` | Implement `lib/tv/tv_navigation.dart` (`TvFocusTraversalPolicy` + `RenderBox` introspection) | ✅ Done | *(this commit)* |
| **M2: Focus** | Epic 2.2 | `2.2.1` | Add `TvNavigationObserver` (Focus restore + Login QR auto-tab) | ⏳ Next | — |
| **M2: Focus** | Epic 2.2 | `2.2.2` | Wire `TvPlatform` & `TvNavigation` into `lib/main.dart` | ⏸️ Pending | — |
| **M3: Patches** | Epic 3.1 | `3.1.1` | Create `lib/scripts/tv_gesture_detector.patch` | ⏸️ Pending | — |
| **M3: Patches** | Epic 3.1 | `3.1.2` | Create `lib/scripts/tv_radio_group.patch` | ⏸️ Pending | — |
| **M3: Patches** | Epic 3.1 | `3.1.3` | Create `lib/scripts/material/tv_ink_well.patch` & `lib/scripts/tv_ink_well.patch` | ⏸️ Pending | — |
| **M3: Patches** | Epic 3.2 | `3.2.1` | Register TV patches in `patch.ps1` and add `tool/tv_patch.sh` | ⏸️ Pending | — |
| **M4: Player HUD** | Epic 4.1 | `4.1.1` | Implement `lib/tv/tv_player_hud.dart` with controller auto-discovery | ⏸️ Pending | — |
| **M4: Player HUD** | Epic 4.1 | `4.1.2` | Add 4-line `TvPlayerHud` hook in `player_focus.dart` | ⏸️ Pending | — |
| **M5: CI & Verify** | Epic 5.1 | `5.1.1` | Update `.github/workflows/` to sync `lemonteaau/PiliPlus` & build Android APKs | ⏸️ Pending | — |
| **M5: CI & Verify** | Epic 5.2 | `5.2.1` | Add TV widget tests (`test/tv_navigation_test.dart`) & verify full build | ⏸️ Pending | — |

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
* **Status**: ✅ Completed
* **Files Changed**:
  * `[NEW] lib/tv/tv_navigation.dart`
* **Changes Summary**:
  * Implemented `TvFocusTraversalPolicy` with 2D row/column directional traversal, `RenderBox` ancestor size & viewport intersection introspection (eliminating edits to `animated_height.dart` and `app_bar_ani.dart`), nested focus deduplication, micro-button (`<= 36x36`) filtering, scrollable boundary/dialog escape, and `consumeKeyboardToken()` on focus transition.
  * Implemented `TvNavigation` wrapper setting `NavigationMode.directional`, intercepting `Select`/`Enter` on focused `EditableText` nodes to invoke `TvPlatform.requestSoftKeyboard()`, and rendering the `#FFFFD166` focus ring overlay.
* **Verification**:
  * `flutter analyze lib/tv/tv_navigation.dart` passed with `No issues found!`.
