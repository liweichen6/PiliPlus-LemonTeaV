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
