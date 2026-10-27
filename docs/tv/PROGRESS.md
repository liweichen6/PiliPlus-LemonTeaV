# PiliPlus-LemonTeaV: TV Porting & Optimization Progress Log

This document tracks the task-by-task execution progress of [`docs/tv/PLAN.md`](./PLAN.md). Every completed task updates this file and is committed atomically.

> **Privacy & Sanitization Rule**: Never record LAN IP addresses/ports, local filesystem absolute paths, file-scheme URLs, local usernames, or device serials in this log or commit messages. Use relative paths and generic placeholders (`<vm-tv>`, `<physical-tv>`).

---

## Task Status Matrix

### Phase 1: Foundation & Initial TV Port (Milestones 0–6) — Completed

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
| **M6: D-Pad Perf** | Epic 6.1 | `6.1.1` | Document Milestone 6 D-pad performance hardening plan in `docs/tv/` | ✅ Done | `42592887e` |
| **M6: D-Pad Perf** | Epic 6.1 | `6.1.2` | Harden `TvFocusTraversalPolicy` & `TvNavigation` for high-frequency D-pad input | ✅ Done | `f5cf58d8e` |
| **M6: D-Pad Perf** | Epic 6.1 | `6.1.3` | Add rapid D-pad stress & zero-rebuild tests and verify on dual TV devices | ✅ Done | `5cf4d5713` |

---

### Phase 2: TV Control Layer Optimization & Verification (Milestones M1–M5) — Completed

| Milestone | Epic | Task ID | Task Title | Status | Target / Commit |
| :--- | :--- | :--- | :--- | :--- | :--- |
| **M1: Nav Opt** | Epic M1.1 | `M1.1` | Opposite Half-Plane Spatial Candidate Pre-Filtering (F2) | ✅ Done | `lib/tv/tv_navigation.dart` |
| **M1: Nav Opt** | Epic M1.1 | `M1.2` | Bounded Micro-Action Candidate Filtering (F3) | ✅ Done | `lib/tv/tv_navigation.dart` |
| **M1: Nav Opt** | Epic M1.1 | `M1.3` | Single-Pass Reading-Order Min-Element Search (F4) | ✅ Done | `lib/tv/tv_navigation.dart` |
| **M1: Nav Opt** | Epic M1.2 | `M1.4` | Idle Frame Callback Stationary Caching & Painter Connection (F1) | ✅ Done | `lib/tv/tv_navigation.dart` |
| **M1: Nav Opt** | Epic M1.2 | `M1.5` | Static Patch Key Handler in `tv_gesture_detector.patch` (F5) | ✅ Done | `lib/scripts/tv_gesture_detector.patch` |
| **M2: HUD & Bridge** | Epic M2.1 | `M2.1` | Root `Obx` Elimination & Modern `PopScope` Migration (F6) | ✅ Done | `lib/tv/tv_player_hud.dart` |
| **M2: HUD & Bridge** | Epic M2.2 | `M2.2` | Virtual Seek Target Accumulator with Multipliers (F7) | ✅ Done | `lib/tv/tv_player_hud.dart` |
| **M2: HUD & Bridge** | Epic M2.3 | `M2.3` | TV Modal Dialog Consolidation & Key Handler Deduplication (F8) | ✅ Done | `lib/tv/tv_player_hud.dart` |
| **M2: HUD & Bridge** | Epic M2.3 | `M2.4` | Memory-Safe `TvBridge.kt` using `WeakReference<Activity>` (F9) | ✅ Done | `android/.../TvBridge.kt` |
| **M4: Test & Bench** | Epic M4.1 | `M4.1` | Deterministic Traversal Latency Benchmark (<50ms/step) & Single-Pass RenderBox (F13) | ✅ Done | `test/tv_navigation_test.dart` |
| **M4: Test & Bench** | Epic M4.1 | `M4.2` | Idle Frame Callback Post-Frame Skip & Immediate Repaint Invariants (F14) | ✅ Done | `test/tv_navigation_test.dart` |
| **M4: Test & Bench** | Epic M4.2 | `M4.3` | 10-Foot Player HUD Automated Test Suite (F15) | ✅ Done | `test/tv_player_hud_test.dart` |
| **M3: Docs & Hygiene** | Epic M3.1 | `M3.1` | Living Documentation Update (`PLAN.md`, `ARCHITECTURE.md`, `PROGRESS.md`) (F11) | ✅ Done | `docs/tv/*` |
| **M3: Docs & Hygiene** | Epic M3.2 | `M3.2` | Patch Revert Discipline, Atomic Git Commits & Sanitization (F12) | ✅ Done | Git history on `main` |
| **M5: Dual Device** | Epic M5.1 | `M5.1` | Dual-Device Release APK Build & Live Verification (`<vm-tv>`, `<physical-tv>`) (F16) | ✅ Done | Android APK / Devices |
| **M5: Dual Device** | Epic M5.2 | `M5.2` | Privacy Sanitization Verification Audit (F17) | ✅ Done | Repository |
| **Release & Docs** | Epic M5.3 | `M5.3` | Point In-App Update Check & `sourceCodeUrl` to `liweichen6/PiliPlus-LemonTeaV` | ✅ Done | `bf0f3af54` |
| **Release & Docs** | Epic M5.3 | `M5.4` | Set `applicationId` to `com.lemontea.piliplus.tv` & Launcher Label to `PiliPlus TV` | ✅ Done | `f00bddcc7` |
| **Release & Docs** | Epic M5.3 | `M5.5` | Add Upstream Sync & Local Build Guide to `docs/tv/` and Update Bilingual Root READMEs | ✅ Done | `docs/tv/*`, `README*.md` |

---

### Phase 3: Post-Release Regression Investigation, Remediation & Audit (Milestones M6–M9) — Completed

| Milestone | Epic | Task ID | Task Title | Status | Target / Commit |
| :--- | :--- | :--- | :--- | :--- | :--- |
| **M6: Focus & Popup Remediation** | Epic M6.1 | `M6.1` | Root-Cause Investigation, Commit Provenance & Collateral Impact Analysis (`switchAccountDialog`, `Slider`, `SelectDialog`, `PopupListTile`) | ✅ Done | `docs/tv/PLAN.md`, `docs/tv/PROGRESS.md` (`20ff9e72d`) |
| **M6: Focus & Popup Remediation** | Epic M6.2 | `M6.2` | Fix `MediaQuery` Wrapping Order in `TvNavigation` (`lib/tv/tv_navigation.dart`, Zero Diff in `lib/main.dart`) | ✅ Done | `lib/tv/tv_navigation.dart` (`20ff9e72d`) |
| **M6: Focus & Popup Remediation** | Epic M6.2 | `M6.3` | Self-Contained `showMenu(..., requestFocus: false)` Focus Promotion & Popup Focus-Ring Tracking in `TvNavigation` (`lib/tv/tv_navigation.dart`, Zero Diff in `popup_menu.patch`) | ✅ Done | `lib/tv/tv_navigation.dart` (`20ff9e72d`) |
| **M6: Focus & Popup Remediation** | Epic M6.3 | `M6.4` | Strengthen Automated Regression Tests (`MyApp._builder` Hierarchy, `switchAccountDialog`, `SliderDialog` & `showMenu`) | ✅ Done | `test/tv_navigation_test.dart` (`20ff9e72d`) |
| **M6: Focus & Popup Remediation** | Epic M6.4 | `M6.5` | Patch Verification, Live TV Validation (`<vm-tv>`) & Revert Discipline | ✅ Done | Android APK / `<vm-tv>` (`20ff9e72d`) |
| **M7: Offscreen Focus, Rapid D-Pad & Hold 3x Speed** | Epic M7.1 | `M7.1` | Root-Cause Analysis & Milestone Planning (`MinePage` Offscreen Focus, Rapid D-Pad Freeze, Hold-Select 3x Speed) | ✅ Done | `docs/tv/PLAN.md`, `docs/tv/PROGRESS.md` (`1658c011e`) |
| **M7: Offscreen Focus, Rapid D-Pad & Hold 3x Speed** | Epic M7.2 | `M7.2` | Offscreen `PageView` / `TabBarView` / `KeepAlive` Focus Isolation & User-Scrollable-Only `ensureVisible` | ✅ Done | `lib/tv/tv_navigation.dart` (`1658c011e`) |
| **M7: Offscreen Focus, Rapid D-Pad & Hold 3x Speed** | Epic M7.2 | `M7.3` | Frame-Guaranteed Traversal Unlock & Immediate Focus-Ring Sync for Rapid Discrete D-Pad Presses | ✅ Done | `lib/tv/tv_navigation.dart` (`1658c011e`) |
| **M7: Offscreen Focus, Rapid D-Pad & Hold 3x Speed** | Epic M7.3 | `M7.4` | Hold D-Pad Enter/Select for 3x Temporary Playback Speed in `TvPlayerHud` | ✅ Done | `lib/tv/tv_player_hud.dart` (`1658c011e`) |
| **M7: Offscreen Focus, Rapid D-Pad & Hold 3x Speed** | Epic M7.4 | `M7.5` | Automated Regression Tests, Live `<vm-tv>` Verification & Patch Revert Discipline | ✅ Done | `test/tv_navigation_test.dart`, `test/tv_player_hud_test.dart` (`1658c011e`) |
| **M8: TV Layer Review & Doc Sync** | Epic M8.1 | `M8.1` | Comprehensive Code & Architectural Audit of Tier 1–3 TV Layer (`docs/tv/REVIEW.md`) | ✅ Done | `docs/tv/REVIEW.md` (`05fb31da1`) |
| **M8: TV Layer Review & Doc Sync** | Epic M8.2 | `M8.2` | Remediate Documentation Drift Across `docs/tv/*` & Bilingual Root `README*.md` | ✅ Done | `docs/tv/*`, `README*.md` (`05fb31da1`) |
| **M9: Second-Layer Comment & `MiniScaffold` Focus** | Epic M9.1 | `M9.1` | Root-Cause Analysis & Collateral `MiniScaffold` Impact Plan (`评论详情`, `对话列表`, Inline Panels) | ✅ Done | `docs/tv/PLAN.md`, `docs/tv/PROGRESS.md` (`e47b32395`) |
| **M9: Second-Layer Comment & `MiniScaffold` Focus** | Epic M9.2 | `M9.2` | Self-Contained `BottomSheetLayout` Occlusion Isolation, Opening Promotion & Focus Restoration (`lib/tv/tv_navigation.dart`) | ✅ Done | `lib/tv/tv_navigation.dart` (`eb746dd8f`) |
| **M9: Second-Layer Comment & `MiniScaffold` Focus** | Epic M9.3 | `M9.3` | Automated Regression Tests for Multi-Layer `MiniScaffold` Sheets (`test/tv_navigation_test.dart`) | ✅ Done | `test/tv_navigation_test.dart` (`eb746dd8f`) |
| **M9: Second-Layer Comment & `MiniScaffold` Focus** | Epic M9.4 | `M9.4` | Live `<vm-tv>` Verification, Documentation Sync (`C22`) & Patch Revert Discipline | ✅ Done | `docs/tv/*`, `README*.md`, `<vm-tv>` |
| **M9: Second-Layer Comment & `MiniScaffold` Focus** | Epic M9.5 | `M9.5` | Embedded Comment Actions (`R7`), Async/Delayed Sheets, Zero-Focusable Sheets & Route PopScope Tracking | ✅ Done | `lib/tv/tv_navigation.dart`, `test/tv_navigation_test.dart` |
| **M9: Second-Layer Comment & `MiniScaffold` Focus** | Epic M9.5 | `M9.6` | Restore F2 Dual-Target Opposite Half-Plane Candidate Culling & Target Viewport Clamping Refinement | ✅ Done | `lib/tv/tv_navigation.dart` (`c663e8ff8`) |

---

### Phase 4: Unified Modal Focus Layer Model & Code Review Remediation (Milestone M10) — Completed

| Milestone | Epic | Task ID | Task Title | Status | Target / Commit |
| :--- | :--- | :--- | :--- | :--- | :--- |
| **M10: Focus Layers, `SmartDialog` & Review Fixes** | Epic M10.1 | `M10.1` | Root-Cause Analysis (`🎉 发现新版本` `SmartDialog` outside `Navigator`) & Unified `_TvFocusLayerStack` Design | ✅ Done | `docs/tv/PLAN.md`, `docs/tv/PROGRESS.md` (`d12e992e0`) |
| **M10: Focus Layers, `SmartDialog` & Review Fixes** | Epic M10.1 | `M10.2` | TV Layer Code Review & Findings Triage (`R8`–`R20`) | ✅ Done | `docs/tv/PLAN.md`, `docs/tv/PROGRESS.md` (`d12e992e0`) |
| **M10: Focus Layers, `SmartDialog` & Review Fixes** | Epic M10.2 | `M10.3` | Player HUD Fixes: Nested Pill Focus, Long Episode List Autofocus, Stale Play/Pause Label, Separate Play/Pause Keys (`R8`, `R10`–`R12`) | ✅ Done | `lib/tv/tv_player_hud.dart`, `test/tv_player_hud_test.dart` (`d3faa0f0c`) |
| **M10: Focus Layers, `SmartDialog` & Review Fixes** | Epic M10.2 | `M10.4` | Use the Scaled Root View Size in the Viewport Check (`R9`) | ✅ Done | `lib/tv/tv_navigation.dart`, `test/tv_navigation_test.dart` (`ffae2ef3f`) |
| **M10: Focus Layers, `SmartDialog` & Review Fixes** | Epic M10.3 | `M10.5` | Focus-Layer Core + Generic `_OverlayFocusLayer` Provider (Promotion, Occlusion, Restoration; O(1) No-Layer Path) | ✅ Done | `lib/tv/tv_focus_layers.dart`, `lib/tv/tv_navigation.dart` (`eef4f1f7e`) |
| **M10: Focus Layers, `SmartDialog` & Review Fixes** | Epic M10.3 | `M10.6` | `SmartDialog` Regression Tests with Real `FlutterSmartDialog` Harness | ✅ Done | `test/tv_navigation_test.dart` (`eef4f1f7e`) |
| **M10: Focus Layers, `SmartDialog` & Review Fixes** | Epic M10.3 | `M10.7` | Live `<vm-tv>` Verification (`设置 → 关于 → 版本`, Review Fixes at `uiScale` `1.0` / `0.8`) | ✅ Done | Android APK / `<vm-tv>` (`3c940cf95`) |
| **M10: Focus Layers, `SmartDialog` & Review Fixes** | Epic M10.4 | `M10.8` | Consolidation I: Migrate M6 Popup-Route Promotion → `_RouteFocusLayer` | ✅ Done | `lib/tv/tv_focus_layers.dart`, `lib/tv/tv_navigation.dart`, `test/tv_navigation_test.dart` (`dcf925548`) |
| **M10: Focus Layers, `SmartDialog` & Review Fixes** | Epic M10.4 | `M10.9` | Consolidation II: Per-Frame Sheet Cost (`R13`) and Typed Sheet Check (`R15`) — **migration of M9 onto the stack deferred** | ✅ Done (`R13`, `R15`) | `lib/tv/tv_navigation.dart`, `test/tv_navigation_test.dart` (`3f894408b`) |
| **M10: Focus Layers, `SmartDialog` & Review Fixes** | Epic M10.5 | `M10.10` | Smaller Cleanups (`R14`, `R16`–`R20`, open `R2` / `R3` / `R5` item 4) | ✅ Done | `lib/tv/tv_navigation.dart`, `lib/tv/tv_player_hud.dart`, `lib/tv/tv_platform.dart`, `test/tv_navigation_test.dart`, `test/tv_player_hud_test.dart`, `docs/tv/*`, `README*.md` (`bad5fddc4`) |
| **M10: Focus Layers, `SmartDialog` & Review Fixes** | Epic M10.5 | `M10.11` | Documentation Sync (`C23`, `R8`–`R20`, `ARCHITECTURE.md` Corrections) & Release Hygiene | ✅ Done (one `M10.8` regression found on the device and fixed) | `docs/tv/*`, `README*.md`, `lib/tv/tv_focus_layers.dart`, `test/tv_navigation_test.dart` (`9bb027680`, `75edded59`, `3a169e16a`) |
| **M10: Focus Layers, `SmartDialog` & Review Fixes** | Epic M10.5 | `M10.12` | Post-Implementation Review Fixes (`R21`–`R24`) | ✅ Done | `lib/tv/tv_focus_layers.dart`, `lib/tv/tv_player_hud.dart`, `test/tv_navigation_test.dart`, `test/tv_player_hud_test.dart` |
| **M10: Focus Layers, `SmartDialog` & Review Fixes** | Epic M10.5 | `M10.13` | Fewer Upstream Merge Conflicts (Fork-Only `tv-sync-build.yml`, One-Line Connectivity Hook) | ✅ Done | `.github/workflows/`, `lib/utils/connectivity_utils.dart`, `lib/tv/tv_platform.dart`, `test/tv_navigation_test.dart`, `docs/tv/*` |

---

### Phase 5: Playback Stability, CI Checks, Focus Engine & Player HUD (Milestones M11–M15) — In Progress

| Milestone | Epic | Task ID | Task Title | Status | Target / Commit |
| :--- | :--- | :--- | :--- | :--- | :--- |
| **M11: TV Checks in CI** | Epic M11.1 | `M11.1` | TV Checks Workflow (`tv-checks.yml`: Patches, TV Analyze, TV Tests) | ✅ Done | `.github/workflows/tv-checks.yml` (`169a7434a`, `5b1168331`) |
| **M11: TV Checks in CI** | Epic M11.1 | `M11.2` | Release Gate in `tv-sync-build.yml` | ✅ Done | `.github/workflows/tv-sync-build.yml` (`169a7434a`) |
| **M11: TV Checks in CI** | Epic M11.1 | `M11.3` | Verification (a Failing Test Blocks Merge and Release) & Docs | ✅ Done (branch protection on `main` is a user action) | `docs/tv/*` (`4e4284b05`, `64c0b6983`); branch protection on `main` (user) |
| **M12: Playback Freeze on the Physical TV** | Epic M12.1 | `M12.1` | Device Profile (Model, SoC, RAM, Android, Decoder Capabilities) | ✅ Done | `<physical-tv>`, `tool/tv_codecs.sh` |
| **M12: Playback Freeze on the Physical TV** | Epic M12.1 | `M12.2` | Reproduction Matrix (Quality × Codec × Hardware Decoding × Thread Ripper; Upstream APK) | 🔄 In Progress (session 2: deadlock traced; `vo=mediacodec_embed` avoids it; TV reboot under investigation) | `<physical-tv>` |
| **M12: Playback Freeze on the Physical TV** | Epic M12.2 | `M12.3` | Root Cause & Fix Decision (Discussion Gate) | ⏳ Planned | `docs/tv/PLAN.md`, `docs/tv/PROGRESS.md` |
| **M12: Playback Freeze on the Physical TV** | Epic M12.2 | `M12.4` | Fix & Regression Tests | ⏳ Planned | Decided in `M12.3` |
| **M12: Playback Freeze on the Physical TV** | Epic M12.3 | `M12.5` | Device Verification & Docs | ⏳ Planned | `<physical-tv>`, `docs/tv/*` |
| **M13: Focus Engine** | Epic M13.0 | `M13.0` | Baseline on the TV (Step Time, Frame Times) & Focus-Bug Inventory | ⏳ Planned | `<physical-tv>` |
| **M13: Focus Engine** | Epic M13.1 | `M13.1` | Adapters for Upstream-Specific Knowledge (No Behavior Change) | ⏳ Planned | `lib/tv/adapters/` |
| **M13: Focus Engine** | Epic M13.1 | `M13.2` | One Event-Driven Reconcile Loop; Inline Sheets on the Layer Stack | ⏳ Planned | `lib/tv/tv_navigation.dart`, `lib/tv/tv_focus_layers.dart` |
| **M13: Focus Engine** | Epic M13.2 | `M13.3` | Recorded D-Pad Paths for Key Screens | ⏳ Planned | `test/tv_navigation_test.dart` |
| **M13: Focus Engine** | Epic M13.2 | `M13.4` | Scoring Function & Column Memory Behind a Flag | ⏳ Planned | `lib/tv/*` |
| **M13: Focus Engine** | Epic M13.3 | `M13.5` | Switch, with the Old Rules Behind a Hidden Switch for One Release | ⏳ Planned | `lib/tv/*`, `<vm-tv>`, `<physical-tv>`, `docs/tv/*` |
| **M13: Focus Engine** | Epic M13.3 | `M13.6` | Remove the Old Rules | ⏳ Planned | `lib/tv/tv_navigation.dart` |
| **M14: Player HUD, Video** | Epic M14.1 | `M14.1` | Button List (Discussion Gate) | ⏳ Planned | `docs/tv/PLAN.md` |
| **M14: Player HUD, Video** | Epic M14.2 | `M14.2` | Menus Through Upstream's Panels | ⏳ Planned | `lib/tv/tv_player_hud.dart` |
| **M14: Player HUD, Video** | Epic M14.2 | `M14.3` | Upstream Layout at TV Size | ⏳ Planned | `lib/tv/tv_player_hud.dart` |
| **M14: Player HUD, Video** | Epic M14.3 | `M14.4` | Tests, Device Pass & Docs | ⏳ Planned | `test/tv_player_hud_test.dart`, `<vm-tv>`, `<physical-tv>`, `docs/tv/*` |
| **M15: Player HUD, Live** | Epic M15.1 | `M15.1` | Button List & Tasks (After M14) | ⏳ Planned (later) | `lib/tv/tv_player_hud.dart` |

---

## Detailed Task Log (Phase 2 Optimization)

### [2026-10-22] Milestone M1: Spatial Navigation Traversal & Idle Frame Callback Optimization
* **Status**: ✅ Completed
* **Files Changed**:
  * `[MODIFY] lib/tv/tv_navigation.dart`
  * `[MODIFY] lib/scripts/tv_gesture_detector.patch`
* **Technical Details & Changes Summary**:
  1. **Idle Frame Persistent Callback Fast-Path (F1)**:
     * In `WidgetsBinding.instance.addPersistentFrameCallback(_syncFocusRectAfterLayout)`, added multi-attribute stationary caching: `_lastFocusedNode`, `_lastTargetBox`, `_lastTargetSize`, `_lastRootSize`, `_lastParentDataOffset`, and `_lastScrollOffset`.
     * When all attributes match the previous frame and `_rectNotifier.value != null`, the callback exits immediately in ~0.001ms without walking 50–100 `RenderObject` ancestors.
     * Updated `_TvFocusRingPainter` constructor to pass `_rectNotifier` to `super.repaint`, ensuring direct ValueListenable repaint dispatch.
  2. **Opposite Half-Plane Directional Pre-Filtering (F2)**:
     * Added `_isInOppositeHalfPlane(nr, target, direction)` to cull off-direction nodes using cached `node.rect` bounds before executing expensive `visitAncestorElements` tree traversals.
     * In `_findVerticalCandidate`, replaced the nested $O(N^2)$ candidate scan over `primaryNodes` with `adjacentColumnSpans` pre-calculated horizontal intervals `(double, double)`.
  3. **Bounded Micro-Action Filtering (F3)**:
     * In `_filterOutEmbeddedSecondaryActions`, restricted `_isEmbeddedSecondaryOf` checks strictly to candidate nodes qualifying as micro-actions ($w \le 36 \land h \le 36$ or area $\le 2500$). Bypasses the loop entirely when no micro-actions exist, eliminating $O(N^2)$ bottlenecks.
  4. **Single-Pass Reading-Order Min-Element Search (F4)**:
     * Replaced $O(N \log N)$ full sorting and duplicate `isEffectivelyFocusable` filtering passes in `findFirstFocus` with `_findFirstReadingOrderNode`, which resolves the top-leftmost focus candidate in two $O(N)$ single-pass comparisons.
  5. **Static Patch Key Event Handler (F5)**:
     * In `lib/scripts/tv_gesture_detector.patch`, extracted the inline anonymous closure inside `build()` into static method `_handleDirectionalKeyEvent` to eliminate closure allocations during builds in directional mode.
* **Verification**:
  * `flutter analyze --no-pub lib/tv/ test/tv_navigation_test.dart` completed with `No issues found!`.
  * `flutter test --no-pub test/tv_navigation_test.dart` passed 15/15 capability invariant tests (C1–C15) in 1.2s.
  * `./tool/tv_patch.sh revert` confirmed all 38 patches report `[NOT APPLIED]`.

---

### [2026-10-22] Milestone M2: Player HUD Reactivity & Native Bridge Memory Safety
* **Status**: ✅ Completed
* **Files Changed**:
  * `[MODIFY] lib/tv/tv_player_hud.dart`
  * `[MODIFY] android/app/src/main/kotlin/com/example/piliplus/TvBridge.kt`
* **Technical Details & Changes Summary**:
  1. **Root `Obx` Elimination & PopScope Migration (F6)**:
     * Removed the top-level `Obx` wrapping `TvPlayerHud.build()`, eliminating full HUD subtree and video player texture rebuilds on `showControls` toggle.
     * Subscribed directly to `_pl.isFullScreen.listen` in `_bindFullScreenListener` and updated `_isFullScreen` via localized `setState()`.
     * Migrated deprecated `ModalRoute.addScopedWillPopCallback` to Flutter's `PopScope(canPop: !_hudVisible, onPopInvokedWithResult: ...)` to cleanly intercept remote Back keys.
  2. **Virtual Seek Target Accumulator (F7)**:
     * Added `Duration? _virtualSeekTarget` in `_TvPlayerHudState` to buffer rapid D-pad scrubbing (<450ms cadence) against an accumulator instead of lagging hardware video decoder positions (150–300ms latency).
     * Applied progressive acceleration multipliers: 1x (10s) -> 2x (20s) -> 3x (30s) based on consecutive press count.
     * Clamped virtual seek bounds to `[Duration.zero, maxPos]` and reset cleanly on 1400ms idle timeout, play/pause toggle, and HUD dismissal.
  3. **TV Dialog Consolidation & Key Handler Deduplication (F8)**:
     * Consolidated 5 modal dialog methods (`_showEpisodeDialog`, `_showQualityDialog`, `_showSpeedDialog`, `_showVideoFitDialog`, `_showDanmakuSettingsDialog`) into unified `_showTvDialog(builder)` helper.
     * Extracted unified top-level `bool _isSelectKey(LogicalKeyboardKey key)` supporting `select`, `enter`, `numpadEnter`, `space`, and `gameButtonA`.
  4. **Memory-Safe `TvBridge.kt` (F9)**:
     * Replaced strong `Activity` reference with `java.lang.ref.WeakReference<Activity>`:
       ```kotlin
       private val activityRef = WeakReference(activity)
       private val activity: Activity? get() = activityRef.get()
       ```
     * Guarded all platform channel operations (`getTvEnvironment`, `isTelevision`, `showSoftKeyboard`, `hideSoftKeyboard`) with null-safe checks, preventing Android Activity memory leaks across configuration changes.
* **Verification**:
  * `flutter analyze --no-pub lib/tv/ test/tv_navigation_test.dart` completed with `No issues found!`.
  * `flutter test --no-pub test/tv_navigation_test.dart` passed 15/15 tests.
  * `./tool/tv_patch.sh revert` confirmed all 38 patches report `[NOT APPLIED]`.

---

### [2026-10-22] Milestone M4: Automated Test Suite Expansion & Deterministic Benchmarks
* **Status**: ✅ Completed
* **Files Changed / Added**:
  * `[MODIFY] test/tv_navigation_test.dart`
  * `[NEW] test/tv_player_hud_test.dart`
* **Technical Details & Changes Summary**:
  1. **Deterministic Traversal Latency Benchmark (F13)**:
     * In `test/tv_navigation_test.dart`, measured stopwatch elapsed time across 20 directional traversal steps over a 120-node widget grid. Divides elapsed time by total steps to compute `meanLatencyMs` and strictly asserts `meanLatencyMs < 50.0` ms/step.
     * Verified strictly single-pass RenderBox geometry evaluations (`localToGlobal` called at most once per node per step).
     * Verified zero unnecessary child widget rebuilds during focus transitions (`childBuildCount == 1`).
  2. **Idle Frame Callback & Repaint Invariant Tests (F14)**:
     * Verified `_syncFocusRectAfterLayout` skips post-frame callbacks and repaints when the focused node remains stationary (`debugNeedsPaint == false`, `shouldRepaint == false`).
     * Verified `_TvFocusRingPainter` repaints immediately when focus moves, updating its target rect and evaluating `shouldRepaint == true` without extra frame delay.
  3. **10-Foot Player HUD Automated Test Suite (F15)**:
     * Created `test/tv_player_hud_test.dart` with 14 comprehensive widget tests covering:
       - Fullscreen player transport controls and autofocus;
       - Split-screen quick control strip;
       - Virtual seek progressive acceleration (1x -> 2x -> 3x);
       - Virtual seek boundary clamping to `[0, totalDuration]`;
       - Virtual seek 1400ms idle timeout reset, >=450ms gap cadence reset, and play/pause toggle reset;
       - `PopScope` Back key HUD dismissal without route popping;
       - `PopScope` fullscreen exit and route popping when HUD is closed;
       - Modal dialog lifecycles for Playback Speed, Video Fit, Danmaku Settings, Episodes, and Video Quality.
* **Verification**:
  * `flutter analyze --no-pub test/tv_navigation_test.dart test/tv_player_hud_test.dart` completed with `No issues found!`.
  * `flutter test --no-pub test/tv_navigation_test.dart test/tv_player_hud_test.dart` passed 34/34 tests in 1.6s.
  * `flutter test --no-pub` passed 89/89 tests across the full repository.
  * Privacy grep returned 0 matches for all sensitive identifiers.

---

### [2026-10-22] Milestone M3: Living Documentation & Atomic Git History
* **Status**: ✅ Completed
* **Files Changed**:
  * `[MODIFY] docs/tv/PLAN.md`
  * `[MODIFY] docs/tv/ARCHITECTURE.md`
  * `[MODIFY] docs/tv/PROGRESS.md`
* **Technical Details & Changes Summary**:
  1. Updated `docs/tv/PLAN.md` with complete Phase 1 vs Phase 2 milestone roadmap, detailed feature inventory (F1–F17), and completed milestones (M1–M5).
  2. Updated `docs/tv/ARCHITECTURE.md` documenting the 3-tier decoupled TV architecture, technical mechanisms for F1–F10, capability invariants C1–C15, and before/after architecture and metric comparison tables.
  3. Updated `docs/tv/PROGRESS.md` recording task status matrix, detailed task logs, before/after metrics, and privacy compliance.
  4. Executed strict privacy sanitization scan across `docs/tv/`, `lib/tv/`, `test/`, and git history, confirming 0 sensitive identifiers.
  5. Maintained patch revert discipline via `./tool/tv_patch.sh revert`, confirming all 38 patches are `[NOT APPLIED]`.
  6. Recorded 4 clean, logical, atomic git commits on `main`.

---

### [2026-10-22] Milestone M5: Dual-Device Release APK Verification & Sanitization
* **Status**: ✅ Completed
* **Technical Details & Verification Summary**:
  1. Applied SDK/package patches (`./tool/tv_patch.sh apply`) and built split-ABI release APKs via `flutter build apk --release --split-per-abi --build-number=5720 --no-pub`.
  2. Installed `app-arm64-v8a-release.apk` on `<vm-tv>` and `app-armeabi-v7a-release.apk` on `<physical-tv>` via `adb install -r`.
  3. Verified live D-pad navigation, rapid key-repeat stress bursts, settings scrolling below `评论设置`, and 10-foot player HUD interactions with `0` `FlutterError`, `EXCEPTION`, or `ANR` entries in `adb logcat`.
  4. Reverted all patches via `./tool/tv_patch.sh revert` (`38/38` `[NOT APPLIED]`) and verified `0` privacy matches across the repository and git history.
  5. Updated `Constants.sourceCodeUrl` (`lib/common/constants.dart`) and `Api.latestApp` (`lib/http/api.dart`) to point to `liweichen6/PiliPlus-LemonTeaV` (`commit bf0f3af54`).
  6. Updated `applicationId` to `com.lemontea.piliplus.tv` and launcher label to `PiliPlus TV` (`commit f00bddcc7`) so `PiliPlus TV` coexists side-by-side with `com.example.piliplus` and `com.lemontea.piliplus`.
  7. Added upstream sync, local APK build, and CI/CD signing documentation to `docs/tv/README.md` and updated root `README.md` and `README.en.md`.

---

## Performance & Quality Metrics Summary

| Metric | Pre-Optimization Baseline | Post-Optimization Achieved | Target Criterion | Verification Method |
| :--- | :--- | :--- | :--- | :--- |
| **Mean Traversal Step Latency** | 40–80 ms / step (unbounded) | **~3.2 ms / step** | $< 50\text{ ms / step}$ | Automated benchmark in `tv_navigation_test.dart` |
| **Idle Frame Callback Time** | 0.3–0.8 ms / frame | **~0.001 ms / frame** (early exit) | Near-zero overhead | Stationary state cache test in `tv_navigation_test.dart` |
| **Root Widget Rebuilds on D-pad** | 1 rebuild per D-pad step | **0 rebuilds** (`childBuildCount == 1`) | Zero unnecessary rebuilds | Widget rebuild count test in `tv_navigation_test.dart` |
| **Player HUD Widget Rebuilds** | Full HUD subtree rebuilt on controls toggle | **0 texture rebuilds** (localized setState) | Isolated controls layer | PopScope & transport tests in `tv_player_hud_test.dart` |
| **Rapid Seek Responsiveness** | Desync & stutter due to 150–300ms decoder lag | **Instant responsive accumulator** (1x/2x/3x) | Smooth virtual scrubbing | 5 acceleration/timeout tests in `tv_player_hud_test.dart` |
| **Android Native Memory Leaks** | Strong `Activity` reference held in `TvBridge` | **0 leaks** (`WeakReference<Activity>`) | Leak-free lifecycle | Code review & null-safe platform channel fallbacks |
| **TV Test Suite Pass Rate** | 15 / 15 tests (100%) | **53 / 53 tests (100%)** | 100% pass rate | `flutter test --no-pub test/tv_*` |
| **Repository Test Pass Rate** | 70 / 70 tests (100%) | **108 / 108 tests (100%)** | 100% pass rate | `flutter test --no-pub` |
| **Static Analysis Diagnostics** | 0 issues | **0 issues** | `No issues found!` | `flutter analyze --no-pub` |
| **Privacy / Secret Leak Count** | 0 | **0 occurrences** | 0 leaks | Regex scan for IPs, ports, paths, usernames, serials |

---

## Dual-Device Verification Log (Sanitized)

* **Target 1: VM TV (`arm64-v8a`) — `<vm-tv>`**:
  * Build: Split-ABI release APK (`app-arm64-v8a-release.apk`)
  * Installation: Clean in-place install via `adb install -r`
  * D-Pad Traversal: Fast navigation across `RecommendPage` grid, `SettingPage` list, and `SearchPage` with 0 dropped frames.
  * 10-Foot Player HUD: Transport controls, virtual seek acceleration (1x/2x/3x), dialog popups (Quality, Speed, Episodes, Danmaku), and Back key HUD dismissal verified.
  * Logcat Analysis: `0` `FlutterError`, `0` `EXCEPTION`, `0` `ANR`.

* **Target 2: Physical TV (`armeabi-v7a`) — `<physical-tv>`**:
  * Build: Split-ABI release APK (`app-armeabi-v7a-release.apk`)
  * Installation: Clean in-place install via `adb install -r`
  * D-Pad Traversal: Smooth navigation on low-spec hardware; micro-action button filtering prevents accidental focus trapping.
  * 10-Foot Player HUD: Hold-to-seek scrubbing operates smoothly without decoder playback stutter; memory footprint stable across orientation and mode transitions.
  * Logcat Analysis: `0` `FlutterError`, `0` `EXCEPTION`, `0` `ANR`.

---

## Detailed Task Log (Phase 3: Post-Release Regression Investigation & Remediation)

### [2026-10-23] Milestone M6 (Task `M6.1`): Account Switcher (`switchAccountDialog`), Settings (`Slider` / `SelectDialog`), and `PopupListTile` (`showMenu`) Root-Cause Investigation, Commit Provenance & Remediation Plan
* **Status**: ✅ Completed
* **Files Updated**:
  * `[MODIFY] docs/tv/PLAN.md`
  * `[MODIFY] docs/tv/PROGRESS.md`
* **Verified Root Causes & Exact Git Commit Provenance**:
  1. **Primary Root Cause — Inverted `MediaQuery` Hierarchy in `MyApp._builder` (`lib/main.dart`, TV commit `d053ad2e5` vs. upstream `b9b54ce4f`)**:
     * **Commit Provenance**:
       * Upstream commit `b9b54ce4f` (`2026-01-22`, `tweaks`): Extracted `static Widget _builder(BuildContext context, Widget? child)` in `MyApp` (`lib/main.dart`), reading `final mediaQuery = MediaQuery.of(context)` from the outer `GetMaterialApp` context (where `navigationMode` is `NavigationMode.traditional`) and wrapping `child!` (`Navigator`) in `MediaQuery(data: mediaQuery.copyWith(...), child: child!)` (subsequently refined in `0fb394cc3`, `c7864ff4a`, and `dbb865d72`).
       * TV fork commit `d053ad2e5` (`2026-10-21`, Phase 1 Milestone M2 Task `2.2.2`, `feat(tv-main): hook TvPlatform and TvNavigation into main.dart`): Appended `if (TvPlatform.isTv) { child = TvNavigation(onBack: _onBack, child: child); }` *after* the `MediaQuery` block in `MyApp._builder` (`lib/main.dart:418-423`).
     * **Runtime Consequence**: Even though `_TvNavigationState.build` (`lib/tv/tv_navigation.dart`) wraps its child in `MediaQuery(data: MediaQuery.of(context).copyWith(navigationMode: NavigationMode.directional), ...)`, the **inner** `MediaQuery` in `MyApp._builder` immediately overwrites `navigationMode` back to `NavigationMode.traditional` for the entire `Navigator` subtree (all page routes and all `showDialog` / `showMenu` overlays).
     * **Impact on Framework Patches**: `lib/scripts/tv_radio_group.patch` (`commit e6990d48e`) guards Flutter's `_RadioGroupState.build` shortcut manager with `if (MediaQuery.maybeNavigationModeOf(context) != NavigationMode.directional)`. Because `navigationMode` inside `Navigator` is overwritten to `NavigationMode.traditional`, this check always evaluates to `true` at runtime—leaving `_radioGroupShortcutManager` and `_SkipUnselectedRadioPolicy<T>` active! It also silently neutralizes `lib/scripts/tv_gesture_detector.patch` (`commit 643893b9c`), `lib/scripts/tv_ink_well.patch`, and `lib/scripts/material/tv_ink_well.patch` (`commit fffaee51a`), as well as Flutter's built-in `NavigationMode.directional` handling in `_SliderState`.
  2. **Mechanics of the Trap in `LoginPageController.switchAccountDialog` (`lib/pages/login/controller.dart`) & `RadioWidget` (`lib/common/widgets/radio_widget.dart`)**:
     * `RadioWidgetState<T>` mixes in `RadioClient<T>`, owns a single `FocusNode` attached to its outer `InkWell`, wraps its inner `Radio<T>` in `ExcludeFocus` with a private no-op `_RadioRegistry<T>`, and registers its `InkWell` `focusNode` with the ancestor `RadioGroup` (`registry = RadioGroup.maybeOf(context)`).
     * When focus enters any `RadioWidget` row inside `switchAccountDialog`:
       * **Logged-out / 0 saved accounts (`_radios.length == 1`, only `AnonymousAccount(): '0'`)**: Flutter's `_RadioGroupState._selectRadioInDirection` returns early when `_radios.length < 2`, while `_RadioGroupShortcutManager.handleKeypress` still returns `KeyEventResult.handled` for `arrowLeft`, `arrowRight`, `arrowUp`, and `arrowDown`. Focus is 100% frozen on the `'0'` row and cannot reach the header (`详细`/`快速`, `登录`) or footer (`取消`, `确定`) buttons.
       * **Logged-in / 1+ saved accounts (`_radios.length >= 2`)**: `_selectRadioInDirection` loops infinitely within the same `RadioGroup` (`nextFocus ??= nodesInEffectiveOrder.first` / `.last`) and invokes `onChanged` on every arrow key press. Focus can never escape the `RadioGroup` to reach the header buttons (`详细`/`快速`, `登录`), move between the 4 `AccountType` `RadioGroup` sections in Detailed (`详细`) mode, or reach the footer buttons (`取消`, `确定`).
  3. **Why `switchAccountDialog` Appeared Fixed in an Earlier Version and Why It Resurfaced (Three Converging History Factors)**:
     * *Pre-Clean-Room Prototype vs. Clean-Room Refactor (`d053ad2e5`)*: The earlier prototype modified `lib/common/widgets/radio_widget.dart` and `lib/pages/login/controller.dart` directly in app code. During the Phase 1 clean-room refactor into `tv_radio_group.patch` (`e6990d48e`) + `TvNavigation` (`d053ad2e5`), `TvNavigation` was inadvertently placed *outside* `MyApp._builder`'s `MediaQuery`.
     * *Upstream Commit `37a92d1fb` (`2026-10-22`, `tweaks (#3349)`) Merged via `51650b5c6` (`2026-10-23`, `v2.1.6.2-fork.5739`)*: Prior to `51650b5c6` (including in `v2.1.6.2-fork.5720`), `LoginPageController.switchAccountDialog` began with `if (Accounts.account.isEmpty) { SmartDialog.showToast('请先登录'); return Get.toNamed('/loginPage'); }`. On a logged-out TV installation, selecting "切换账号" bypassed `switchAccountDialog` completely and navigated straight to `/loginPage` (where `TvNavigationObserver` auto-selected the QR code tab). Upstream commit `37a92d1fb` commented out those 4 lines (`lib/pages/login/controller.dart:628-631`) and added an `IconButton(tooltip: '登录', icon: Icon(Icons.login_outlined))` to `AlertDialog.title`. Consequently, selecting "切换账号" when logged out now opens `switchAccountDialog` with only the single `'0'` (`AnonymousAccount`) radio row—immediately hitting the `_radios.length < 2` total D-pad freeze and preventing the user from reaching the new `登录` button or `取消`/`确定`!
     * *False-Positive Unit Test (`test/tv_navigation_test.dart`, commit `9da6200ed`)*: The existing test `'patched RadioGroup allows D-pad arrow navigation to unselected options'` mounted `MaterialApp(home: TvNavigation(...))` directly (bypassing `MyApp._builder`'s inner `MediaQuery`), did not assert that `selectedValue` remained `1` after pressing `arrowDown` (before pressing `enter`), and lacked external focusable buttons above/below the `RadioGroup` to test escaping the group.
  4. **Collateral Settings & Dialog Impact Across the Application (Caused by `NavigationMode.traditional` Overwrite in `MyApp._builder`)**:
     * **Single-Slider Dialogs (9 `SliderDialog` settings + 1 custom `Slider` dialog — D-pad Up/Down trapped in `Slider`, unable to reach `重置`/`取消`/`确定`)**:
       * Flutter's `_SliderState` binds `arrowUp` and `arrowDown` to `IncreaseAction` / `DecreaseAction` under `NavigationMode.traditional` and only unbinds them under `NavigationMode.directional`. Because `MyApp._builder` overwrites `navigationMode` to `NavigationMode.traditional`, D-pad Up/Down adjusts the slider value instead of moving focus out of the `Slider` to `重置` / `取消` / `确定` across the 9 `SliderDialog` settings (`图片质量` at `style_settings.dart:279`, `查看大图质量` at `style_settings.dart:298`, `气泡提示不透明度` / `Toast不透明度` at `style_settings.dart:330, 837`, `倾斜角度阈值` at `play_settings.dart:458`, `播放器音量` at `play_settings.dart:480, 529`, `最高音量` at `play_settings.dart:498, 529`, `刷新指示器高度` at `extra_settings.dart:382`, `连接重试次数` at `extra_settings.dart:461`, and `连接重试间隔` at `extra_settings.dart:483`) plus the custom `界面缩放` single-`Slider` + `TextFormField` dialog (`style_settings.dart:102, 478`).
     * **Multi-Slider Dialogs & Pages (6 dialogs/pages — D-pad Up/Down cannot traverse between stacked `Slider`s or reach action buttons)**:
       * `列表宽度（dp）限制` (`DualSliderDialog` in `style_settings.dart:712`), `深色下图片颜色叠加` (`SlideColorPicker` in `style_settings.dart:791`), `全屏SuperChat` (`FullScreenSc` in `lib/pages/setting/pages/fullscreen_sc.dart:163, 182`), `App字体设置` (`FontSettingPage` in `lib/pages/setting/pages/font_setting.dart:319, 354`), Player `弹幕设置` sheet (10 `Slider`s in `lib/pages/video/widgets/header_mixin.dart:208-446`), and Player `播放设置` sheet (7 `Slider`s in `lib/pages/video/widgets/header_control.dart:1390-1504`).
     * **`RadioGroup` + `RadioListTile` Immediate-Close Selection Dialogs & Pages (33 historical `SelectDialog`/`CdnSelectDialog`/`_showFavDialog` radio dialogs before upstream `299905f47` migrated 12 to `PopupModel`; 21 active dialog settings across 22 dialog call sites + `DisplayModePage` — D-pad Up/Down prematurely fires `onChanged` and closes the dialog on the first arrow press)**:
       * 5 filter/seek dialogs via `getVideoFilterSelectModel` (`model.dart:306`: `点赞率过滤`, `视频时长过滤`, `播放量过滤` in `recommend_settings.dart:51, 77, 85`; `双击快进/快退时长`, `滑动快进/快退时长` in `play_settings.dart:236, 250`), 9 video settings across 10 dialog call sites (`CDN 设置` in `video_settings.dart:326` & `header_control.dart:525`, `线程撕裂者：并发数`, `默认画质`, `蜂窝网络画质`, `默认音质`, `蜂窝网络音质`, `直播默认画质`, `蜂窝网络直播默认画质`, `视频同步`), 4 playback settings across 5 `SelectDialog`s (`字幕选择偏好`, `默认全屏方向`, `超分辨率`, and two-step `音量均衡` + `服务器无loudnorm配置时使用`), 2 style settings dialogs (`页面过渡动画`, `用户页默认展示TAB`), `主题模式` (`color_select.dart:93`), `选择默认收藏夹` (`_showFavDialog` in `extra_settings.dart:426`), and `屏幕帧率` (`display_mode.dart:80`).
     * **`RadioGroup` Confirmation Dialogs (3 dialogs — D-pad focus trapped inside `RadioGroup`, unable to reach `取消`/`确定`/`确认` or header buttons)**:
       * `LoginPageController.switchAccountDialog` (`lib/pages/login/controller.dart:705, 737`, using `RadioGroup<Account>` + `RadioWidget<Account>`), `autoWrapReportDialog` (`lib/common/widgets/dialog/report.dart:22, 89`, `举报` dialog using `RadioGroup<int>` + `WrapRadioOptionsGroup<int>` / `RadioWidget<int>`), and `RequestUtils.onCopyOrMove` (`lib/utils/request_utils.dart:435, 455`, `复制到`/`移动到` favorite folder dialog using `RadioGroup<int>` + `RadioListTile<int>`).
  5. **Independent `PopupListTile` / `showMenu` D-Pad Focus Bug (`lib/pages/setting/widgets/popup_item.dart` & `lib/tv/tv_navigation.dart`)**:
     * **Commit Provenance**:
       * `1ad710c1c` (`2026-02-05`, `opt settings`): Created `PopupListTile<T>` (`lib/pages/setting/widgets/popup_item.dart`) with `ListTile(onTapUp: (details) => _showButtonMenu(details, value))` (`onTap: null`) and `showMenu<T?>(..., requestFocus: false)`.
       * `7ab2cf973` (`2026-02-06`, `tweaks (#1826)`): Temporarily changed `PopupListTile._showButtonMenu` in `lib/pages/setting/widgets/popup_item.dart` from `requestFocus: false` to `requestFocus: true` (alongside wrapping `ListTile` in `KeyedSubtree`), without modifying `lib/scripts/popup_menu.patch` or `lib/scripts/material/popup_menu.patch`.
       * `0460030a2` (`2026-02-09`, `feat: tempPlayerConf add playRepeat (#1830)`): Reverted `requestFocus: true` back to `requestFocus: false` in `PopupListTile._showButtonMenu` (`lib/pages/setting/widgets/popup_item.dart:69`).
       * `0df637fb7` (`2026-06-28`) and `810c26a6e` (`2026-08-17`): Created `lib/scripts/popup_menu.patch` and `lib/scripts/material/popup_menu.patch` with a single hunk in `PopupMenuItemState.build` (`IconTheme.merge` for enabled items), leaving `showMenu`'s `bool? requestFocus` parameter untouched.
       * `299905f47` (`2026-08-25`, `opt: replace dialog with popup (#2683)`): Replaced `SelectDialog` with `PopupModel` / `PopupListTile` across 12 settings items.
       * `fffaee51a` (`2026-10-21`, `feat(tv-patch): add tv_ink_well.patch for ActionItem triple-like and PopupListTile support`): Patched `_InkResponseState.activateOnIntent` in `lib/scripts/tv_ink_well.patch` and `lib/scripts/material/tv_ink_well.patch` so `PopupListTile` opens its popup menu on D-pad Select/Enter, **but** left `showMenu(..., requestFocus: false)` in `popup_item.dart:69` unaddressed.
     * **Mechanics & Affected Controls (15 `PopupListTile` settings / 16 call sites + all `showMenu` / `PopupMenuButton` routes)**:
       * `PopupListTile._showButtonMenu` explicitly passes `requestFocus: false` to `showMenu<T>` (while other `showMenu` / `PopupMenuButton` callers omit `requestFocus`, leaving it `null` to defer to `Navigator.requestFocus`). When `showMenu(..., requestFocus: false)` pushes `_PopupMenuRoute`, the underlying page's route `FocusScopeNode` has `skipTraversal` set to `true` (`!route.isCurrent`), while `_PopupMenuRoute`'s `FocusScopeNode` has `skipTraversal == false`, leaving `primaryFocus` stranded on the triggering `ListTile`. Promoting focus inside `_TvNavigationState` (`_syncFocusRectAfterLayout` and `_onFocus` in `lib/tv/tv_navigation.dart`) whenever `primaryFocus`'s `nearestScope` (or an ancestor route `FocusScopeNode`) has `skipTraversal == true` (`_isScopeInactive`) and an active sibling `FocusScopeNode` exists under `NavigatorState.focusNode` (`_findActiveSiblingScope`) ensures all `PopupListTile` and `showMenu(..., requestFocus: false)` routes receive focus on TV with zero modifications to `lib/scripts/popup_menu.patch`, `lib/scripts/material/popup_menu.patch`, or `lib/pages/setting/widgets/popup_item.dart`.
       * Affects 13 `PopupModel` settings (`动态页UP主显示位置`, `动态未读标记`, `消息未读标记`, `顶/底栏收起类型`, `主题模式`, `默认启动页`, `SuperChat (醒目留言) 显示类型`, `底部进度条展示`, `播放顺序`, `番剧片头/片尾跳过类型`, `评论展示`, `楼中楼评论展示`, `动态展示`), plus `调色板风格` (`color_select.dart:118`) and `超分辨率` / `播放顺序` (`header_control.dart:472, 662`).
  6. **Performance Impact Analysis**:
     * **Unwrapping `MediaQuery` inside `_TvNavigationState.build` (`lib/tv/tv_navigation.dart`, zero diff in `lib/main.dart`)**: Eliminates redundant inner `MediaQuery` layers (`while (child is MediaQuery)`); zero extra `MediaQuery` notifications or rebuilds (`MediaQuery.maybeNavigationModeOf(context)` is a static $O(1)$ `InheritedModel` aspect lookup); delegates traversal to `TvFocusTraversalPolicy` (~3.2ms/step over 120 nodes, ~0.001ms/frame when stationary).
     * **Self-Contained `showMenu(..., requestFocus: false)` Focus Promotion (`lib/tv/tv_navigation.dart`, zero diff in `popup_menu.patch`)**: Zero steady-state overhead during browsing, scrolling, or video playback (`_isScopeInactive(scope)` is a pure in-memory boolean walk up `enclosingScope` checking `current.skipTraversal`, with zero `BuildContext` or `InheritedModel.inheritFrom` lookups on active frames); when `showMenu(..., requestFocus: false)` pushes `_PopupMenuRoute`, promotes focus in a single frame and enables standard modal `FocusScope` traversal over 2–8 `PopupMenuItem` nodes (<0.1ms per key press).

---

### [2026-10-23] Milestone M6 (Tasks `M6.2`–`M6.5`): Self-Contained `TvNavigation` `MediaQuery` Unwrapping, `showMenu` Focus Promotion, Popup Focus-Ring Tracking & Live TV Verification
* **Status**: ✅ Completed
* **Files Changed**:
  * `[MODIFY] lib/tv/tv_navigation.dart`
  * `[MODIFY] test/tv_navigation_test.dart`
  * `[MODIFY] docs/tv/PLAN.md`
  * `[MODIFY] docs/tv/PROGRESS.md`
  * `[MODIFY] docs/tv/ARCHITECTURE.md`
* **Technical Details & Changes Summary**:
  1. **Task `M6.2` — Fix `MediaQuery` Wrapping Order in `TvNavigation` (`lib/tv/tv_navigation.dart`, Zero Diff in `lib/main.dart`)**:
     * Left `lib/main.dart` completely untouched relative to `HEAD` (`TvNavigation` remains at the tail of `MyApp._builder` outside upstream's `if (uiScale != 1.0) ... else ...` `MediaQuery` block).
     * Updated `_TvNavigationState.build` in `lib/tv/tv_navigation.dart` to inspect `widget.child`: while `child is MediaQuery`, unwrap its `MediaQueryData` (`mediaQuery = child.data; child = child.child;`) and apply `MediaQuery(data: mediaQuery.copyWith(navigationMode: NavigationMode.directional), ...)` directly around the inner `child` (`Navigator`).
     * Ensures `TvNavigation`'s `MediaQuery` is the innermost `MediaQuery` around `Navigator` while preserving all upstream `MediaQueryData` overrides (`textScaler`, `size`, `padding`, `viewPadding`, `viewInsets`) and keeping `lib/main.dart` conflict-free.
  2. **Task `M6.3` — Self-Contained `showMenu(..., requestFocus: false)` Focus Promotion & Popup Focus-Ring Tracking (`lib/tv/tv_navigation.dart`, Zero Diff in `popup_menu.patch`)**:
     * Left `lib/scripts/popup_menu.patch` and `lib/scripts/material/popup_menu.patch` completely untouched relative to `HEAD`.
     * Added self-contained `showMenu(..., requestFocus: false)` focus promotion and popup focus-ring tracking in `_TvNavigationState._syncFocusRectAfterLayout` and `_TvNavigationState._onFocus` (`lib/tv/tv_navigation.dart`):
       1. *Inactive Route Scope Detection & Sibling Popup Scope Promotion (`_isScopeInactive` & `_findActiveSiblingScope`)*: When `showMenu(..., requestFocus: false)` pushes `_PopupMenuRoute`, the underlying route's `FocusScopeNode` has `skipTraversal == true` (`!widget.route.isCurrent` in `_ModalScopeState.build`, so `_isScopeInactive(currentScope) == true`), while `_PopupMenuRoute` creates a sibling `FocusScopeNode` under `NavigatorState.focusNode` with `skipTraversal == false`. `_syncFocusRectAfterLayout` and `_onFocus` detect this transition (including when triggered from inside a nested `FocusScope` or on the same frame as `FocusNode.requestFocus()`), save the triggering node via `TvNavigationObserver.rememberFocusedNode(node)`, activate the popup's `FocusScopeNode` via `targetScope.enclosingScope?.setFirstFocus(targetScope)`, focus the first visible `PopupMenuItem` via `_policy.findFirstFocus(targetScope)`, and immediately update `_focusRect` via `_updateRect(_computeFocusedRect(first))`.
       2. *Deferred `PopupMenuItem` Mounting*: When a route's `FocusScopeNode` acquires primary focus on the first frame before its `PopupMenuItem` descendants finish mounting, `_syncFocusRectAfterLayout` and `_onFocus` retry `_policy.findFirstFocus(node)` on subsequent frames whenever `node is FocusScopeNode`.
       3. *Bottom-Edge `_PopupMenuRouteLayout` Ancestor Shift*: When a `PopupListTile` near the bottom of the screen opens `showMenu`, `_PopupMenuRouteLayout` (`CustomSingleChildLayout`) shifts the `_PopupMenu` container upward as `Align.heightFactor` animates from `0.0` to `1.0`. Because `ro.parentData.offset` on the `PopupMenuItem` itself remains `Offset.zero` while its ancestor's `BoxParentData.offset` changes, replaced the single-level `ro.parentData.offset` check with `_accumulatedParentOffset(ro, rootRo)` (summing `BoxParentData.offset` and `RenderFractionalTranslation` offsets up the `RenderObject` ancestor chain to `rootRo`). This tracks ancestor layout shifts accurately without allocating a `Matrix4` on stationary frames.
  3. **Task `M6.4` — Strengthen Automated Regression Tests (`test/tv_navigation_test.dart`)**:
     * Tightened `'patched RadioGroup allows D-pad arrow navigation to unselected options'` to assert `expect(selectedValue, 1)` immediately after `arrowDown` (before pressing `enter`).
     * Added 4 new Milestone M6 regression tests in `test/tv_navigation_test.dart` (`24` tests total in `test/tv_navigation_test.dart`):
       1. `'MyApp._builder MediaQuery wrapping order preserves NavigationMode.directional across routes and showDialog'` (using `HEAD`'s exact `MyApp._builder` wrapping order where `TvNavigation` wraps `MediaQuery(data: ...copyWith(textScaler: TextScaler.noScaling), child: child!)`);
       2. `'switchAccountDialog pattern (RadioGroup + RadioWidget / WrapRadioOptionsGroup) allows D-pad focus escape in single-option, multi-option, and Detailed (详细) states'`;
       3. `'SliderDialog and DualSliderDialog adjust value with D-pad Left/Right and escape with D-pad Up/Down to dialog actions'`;
       4. `'showMenu with requestFocus: false (PopupListTile pattern) requests focus on TV and allows D-pad item selection'` (including nested `FocusScope` trigger, same-frame `requestFocus()` + `showMenu(requestFocus: false, popUpAnimationStyle: AnimationStyle.noAnimation)`, and bottom-edge `_PopupMenuRouteLayout` upward shift).
  4. **Task `M6.5` — Patch Verification, Live TV Validation (`<vm-tv>`) & Revert Discipline**:
     * Applied all 38 patches via `./tool/tv_patch.sh apply`.
     * Ran `flutter analyze --no-pub lib/tv/ test/tv_navigation_test.dart test/tv_player_hud_test.dart` (`No issues found!`).
     * Ran `flutter test --no-pub test/tv_navigation_test.dart test/tv_player_hud_test.dart` (`38/38` passed: `24/24` in `test/tv_navigation_test.dart` + `14/14` in `test/tv_player_hud_test.dart`).
     * Built debug APK (`flutter build apk --debug`) and verified live D-pad navigation with visual screenshot inspection on `<vm-tv>` across:
       1. `switchAccountDialog` (`账号切换` in logged-out 1-option state across both Quick and Detailed `详细` modes): D-pad Right/Left traverses header buttons (`详细` <-> `登录`), D-pad Down from `详细` focuses `'0'` (`RadioWidget`), D-pad Down from `'0'` escapes `RadioGroup` to `取消`/`确定`, D-pad Up returns to `详细`, pressing Select on `详细` switches to `快速` (4 `AccountType` `RadioGroup` + `WrapRadioOptionsGroup` sections), D-pad Down/Up traverses across all 4 sections and escapes to `取消`/`确定` and `快速`/`登录`, and `取消` dismisses cleanly.
       2. `SelectDialog` (`页面过渡动画` in `设置` -> `外观设置`): D-pad Down/Up moves focus ring across radio items (`fade` -> `fadeIn` -> `rightToLeft`) without prematurely firing `onChanged` or closing the dialog.
       3. `DualSliderDialog` (`列表宽度 (dp) 限制` in `设置` -> `外观设置`): Opens with Slider 1 (`主页推荐流` `300.0dp`) focused, D-pad Down moves to Slider 2 (`其他` `240.0dp`), D-pad Right adjusts value (`240.0dp` -> `250.0dp`), and D-pad Down escapes Slider 2 to `取消`.
       4. `PopupListTile` / `showMenu` (`动态页UP主显示位置` in `设置` -> `外观设置`): Opens with focus ring accurately aligned on `顶部` (item 0), D-pad Down moves focus ring to `左侧常驻` (item 1), and D-pad Select selects the item and closes the menu.
       5. `SliderDialog` (`图片质量` in `设置` -> `外观设置`): Opens with `Slider` (`10%`) focused, D-pad Right adjusts value (`10%` -> `20%`), and D-pad Down escapes `Slider` to `取消`.
     * Confirmed `0` `FlutterError`, `EXCEPTION`, or `ANR` in `adb logcat`.
     * Reverted all 38 patches via `./tool/tv_patch.sh revert` and verified all 38 patches report `[NOT APPLIED]`.

---

### [2026-10-24] Milestone M7 (Task `M7.1`): Root-Cause Analysis for `MinePage` Offscreen Focus / Return-Key Exit, Rapid D-Pad Freeze & Player Hold-Select 3x Speed
* **Status**: ✅ Completed
* **Files Updated**:
  * `[MODIFY] docs/tv/PLAN.md`
  * `[MODIFY] docs/tv/PROGRESS.md`
* **Verified Root Causes**:
  1. **Bug 1 (`MinePage` "我的" D-Pad Return Exit & Re-Entry Phantom Offscreen Focus)**:
     * *Unconditional `Scrollable.ensureVisible` Scrolling `MainApp`'s `NeverScrollableScrollPhysics` `PageView`*: `MainApp` (`lib/pages/main/view.dart:330-334`) hosts `HomePage` (0), `DynamicsPage` (1), and `MinePage` (2) inside `PageView(physics: const NeverScrollableScrollPhysics(), controller: _mainController.pageController)`. `TvFocusTraversalPolicy` previously used `FocusTraversalPolicy.defaultRequestFocusCallback` (which calls `Scrollable.ensureVisible(node.context!)`), and `_TvNavigationState._onFocus` also called `Scrollable.ensureVisible(context)`. Replacing unconditional `Scrollable.ensureVisible` with `_ensureVisibleInUserScrollables` ensures only user-scrollable viewports (`_canUserScroll(scrollable)`) are scrolled during focus traversal.
     * *Kept-Alive Offscreen `PageView` Sliver Children, Inner `ListView` Masking & `findFirstFocus` Jumping to `userAvatar` (`_mainController.toMinePage`)*: Because `MinePage` uses `AutomaticKeepAliveClientMixin` (`wantKeepAlive => true`) and wraps its entire body (including its header row with `Icons.switch_account_outlined` and `Icons.settings_outlined`) inside a vertical `ListView(physics: const AlwaysScrollableScrollPhysics())`, when `MainApp` switches back to `HomePage` (`_mainController.setIndex(0)` -> `pageController.jumpToPage(0)`) or when re-entering PiliPlus from the TV launcher:
       1. `MinePage` stays mounted inside `PageView`'s `RenderSliverFillViewport` (wrapped in `SliverFillViewport`'s `RenderSliverPadding` inside `RenderViewport`).
       2. Because `MinePage`'s header icons are inside `MinePage`'s inner `ListView`, `_TvTraversalCache.evaluateNode` set `insideScrollable = true` and `verticalScrollable = mineListView` before reaching `MainApp`'s outer `PageView`, skipping viewport intersection against `PageView`.
       3. Even when offscreen `MinePage` nodes were detected as unfocusable, recovering focus via `_policy.findFirstFocus(currentScope)` searched the entire route `FocusScopeNode` in top-left reading order and selected the topmost-leftmost widget in `MainApp`: `userAvatar` (`x: 20, y: 21` above the `NavigationRail`), whose `onTap` calls `_mainController.toMinePage()`—causing Enter to navigate right back to `MinePage` (`我的`)!
       4. Additionally, `_TvNavigationState._computeFocusedRect` did not verify `_accumulatedParentOffset(target, root) != null` or `viewport.overlaps(candidate)`, `_TvNavigationState` lacked `WidgetsBindingObserver.didChangeAppLifecycleState(AppLifecycleState.resumed)`, and `pageController.jumpToPage(0)` did not synchronously unfocus invalidated offscreen nodes on `ScrollUpdateNotification`/`ScrollEndNotification`.
  2. **Bug 2 (Rapid Discrete D-Pad Press Selection Box Freeze / Multi-Step Pause)**:
     * *Unscheduled Frame Starvation on `addPostFrameCallback` & Same-Frame Discrete `KeyDownEvent` Dropping*: Registering `addPostFrameCallback` in `SchedulerPhase.idle` without `WidgetsBinding.instance.ensureVisualUpdate()` starved post-frame callbacks until an unrelated timer/animation scheduled a frame. Furthermore, locking `traversalLockedThisFrame` across all directional key events caused `_handleKeyEvent` to drop discrete `KeyDownEvent`s arriving within the same frame (`return KeyEventResult.handled`), rather than only throttling `KeyRepeatEvent` (`isRepeatLockedThisFrame`).
     * *Two-Frame Deferred `_rectNotifier` Update & `O(D^2)` Matrix Allocations*: Updating `_rectNotifier` synchronously in `_onFocus()` during `SchedulerPhase.idle` when `!_policy.didScrollInLastFocus` eliminates the extra frame delay on non-scrolling D-pad moves without flashing pre-scroll rects, and reading `RenderViewportBase.offset.pixels` directly in `_accumulatedParentOffset` eliminates per-ancestor `localToGlobal` `Matrix4` allocations.
  3. **Feature 3 (Video Player Hold D-Pad Enter/Select for 3x Speed)**:
     * `PlPlayerController.setLongPressStatus(bool)` already supports temporary 3.0x speed (`Pref.longPressSpeedDefault = 3.0`), and `TvPlayerHud` now distinguishes a short press (`KeyDownEvent` + `KeyUpEvent` < 250ms -> play/pause or fullscreen) from a long-press hold (`KeyDownEvent` + hold >= 250ms or `KeyRepeatEvent` -> `setLongPressStatus(true)`, `KeyUpEvent` -> `setLongPressStatus(false)`).

---

### [2026-10-24] Milestone M7 (Tasks `M7.2`–`M7.5`): `MinePage` Offscreen `PageView` Focus Isolation, Rapid D-Pad Freeze Remediation, Hold-Select 3x Speed & Live `<vm-tv>` Verification
* **Status**: ✅ Completed
* **Files Changed**:
  * `[MODIFY] lib/tv/tv_navigation.dart`
  * `[MODIFY] lib/tv/tv_player_hud.dart`
  * `[MODIFY] test/tv_navigation_test.dart`
  * `[MODIFY] test/tv_player_hud_test.dart`
  * `[MODIFY] docs/tv/PLAN.md`
  * `[MODIFY] docs/tv/PROGRESS.md`
  * `[MODIFY] docs/tv/ARCHITECTURE.md`
* **Technical Details & Changes Summary**:
  1. **Task `M7.2` — Offscreen `PageView` / `TabBarView` / `KeepAlive` Focus Isolation, `findRecoveryFocus` & Lifecycle / Scroll-Notification Recovery (`lib/tv/tv_navigation.dart`)**:
     * Supplied custom `requestFocusCallback: _defaultTvRequestFocusCallback` on `TvFocusTraversalPolicy` and replaced `Scrollable.ensureVisible` in both `_defaultTvRequestFocusCallback` and `_TvNavigationState._onFocus` with `_ensureVisibleInUserScrollables` (recording `_frameState.didScrollInLastFocus` when a viewport scrolls).
     * Updated `TvFocusTraversalPolicy._canUserScroll(ScrollableState)` to return `false` for `NeverScrollableScrollPhysics`, `PageScrollPhysics`, and `scrollable.position is PageMetrics` (covering both `MainApp`'s `PageView` and `HomePage`'s `_TabBarViewScrollPhysics` `TabBarView`).
     * Added `_TvTraversalCache._isKeptAliveOffscreen(RenderBox)` and updated `_TvNavigationState._accumulatedParentOffset` to detect `RenderOffstage`, `KeepAliveParentDataMixin.keptAlive`, and inactive `RenderSliverFillViewport` `PageMetrics` pages (`(page - pd.index!).abs() > 0.5`, walking past intermediate slivers such as `SliverFillViewport`'s `RenderSliverPadding` to `RenderViewportBase`).
     * Updated `_TvTraversalCache.evaluateNode` so that when a node is inside an inner user-scrollable (`verticalScrollable` / `horizontalScrollable`, such as `MinePage`'s `ListView`) nested inside an outer non-user-scrollable (`!_canUserScroll(scrollable)`, such as `MainApp`'s `PageView`), the inner scrollable's own viewport (`innerRect`) is intersected with `lockedViewport` (`innerVisible.width <= 1.0 || innerVisible.height <= 1.0` -> `focusable = false`).
     * Added `TvFocusTraversalPolicy.findRecoveryFocus(invalidNode, currentScope, {previousRect})` so focus recovery from an offscreen node inside a non-user-scrollable container (e.g. `MainApp`'s `PageView`) prefers focusable candidates inside that container (`HomePage` content) rather than jumping to outer sidebar items like `userAvatar` (`_mainController.toMinePage`).
     * Mixed `WidgetsBindingObserver` into `_TvNavigationState` (`didChangeAppLifecycleState(AppLifecycleState.resumed)`), wrapped the `TvNavigation` stack in `NotificationListener<ScrollNotification>(onNotification: _handleScrollNotification)` to synchronously unfocus invalidated offscreen nodes and clear `_rectNotifier` when `PageView` jumps pages, and updated `_computeFocusedRect` to require `_accumulatedParentOffset(target, root) != null` and `viewport.overlaps(candidate)`.
  2. **Task `M7.3` — Repeat-Only Frame Throttle, `ensureVisualUpdate` & Zero-Allocation `_accumulatedParentOffset` (`lib/tv/tv_navigation.dart`)**:
     * Replaced `traversalLockedThisFrame` (which dropped same-frame discrete `KeyDownEvent`s) with `repeatLockedThisFrame` (`isRepeatLockedThisFrame`), throttling only `KeyRepeatEvent`s to one step per rendered frame (plus the 45ms repeat interval floor) while allowing every discrete `KeyDownEvent` to execute immediately.
     * Added `WidgetsBinding.instance.ensureVisualUpdate()` whenever registering `addPostFrameCallback` in `TvFocusTraversalPolicy._focusNode`, `_TvNavigationState`, and `TvNavigationObserver`.
     * Updated `_TvNavigationState._onFocus` to synchronously compute and publish `_updateRect(_computeFocusedRect(immediateNode))` in `SchedulerPhase.idle` only when `!_policy.didScrollInLastFocus`, and optimized `_accumulatedParentOffset` to read `RenderViewportBase.offset.pixels` directly with zero matrix allocations.
  3. **Task `M7.4` — Hold D-Pad Enter/Select for 3x Temporary Speed in `TvPlayerHud` (`lib/tv/tv_player_hud.dart`)**:
     * Added `_kLongPressSpeedDelay = Duration(milliseconds: 250)`, `_longPressSpeedTimer`, `_selectKeyDown`, `_longPressSpeedActive`, `_startLongPressSpeed`, `_endLongPressSpeed`, and `_handleLongPressSelectKey` in `_TvPlayerHudState`.
     * When `_isSelectKey(key)` is pressed while fullscreen HUD is hidden (`_isFullScreen && !_hudVisible`), while focus is on Play/Pause (`_playPauseFocusNode`), or on split-screen Quick Strip (`_splitFullscreenFocusNode` / `_splitPlayPauseFocusNode`), holding D-pad Select/Enter (`>= 250ms` or `KeyRepeatEvent`) invokes `_pl.setLongPressStatus(true)` (activating 3.0x speed, displaying `'3.0倍速中'`, and pausing the HUD auto-hide timer), releasing (`KeyUpEvent`) invokes `_pl.setLongPressStatus(false)` (restoring normal speed without pausing), and a short press (`KeyDownEvent` + `KeyUpEvent` < 250ms) executes the normal play/pause or fullscreen action.
  4. **Task `M7.5` — Automated Regression Tests, Live `<vm-tv>` Verification & Patch Revert Discipline**:
     * Added 2 new regression tests in `test/tv_navigation_test.dart` (`26/26` passed) and 3 new regression tests in `test/tv_player_hud_test.dart` (`17/17` passed), bringing the TV test suite to `43/43` passing tests.
     * Verified live D-pad input on `<vm-tv>` and reverted all 38 patches via `./tool/tv_patch.sh revert` (`[NOT APPLIED]`).

---

### [2026-10-24] Milestone M8 (Tasks `M8.1`–`M8.2`): Comprehensive TV Layer Review (`docs/tv/REVIEW.md`) & Documentation Sync
* **Status**: ✅ Completed
* **Files Changed**:
  * `[NEW] docs/tv/REVIEW.md`
  * `[MODIFY] docs/tv/ARCHITECTURE.md`
  * `[MODIFY] docs/tv/README.md`
  * `[MODIFY] docs/tv/README.en.md`
  * `[MODIFY] docs/tv/PLAN.md`
  * `[MODIFY] docs/tv/PROGRESS.md`
  * `[MODIFY] README.md`
  * `[MODIFY] README.en.md`
* **Summary & Verification**:
  1. **Code-Level TV Layer Audit (`docs/tv/REVIEW.md`)**:
     * Audited 100% of the fork diff against `lemonteaau/PiliPlus` across Tier 1 (`lib/tv/tv_platform.dart`, `lib/tv/tv_navigation.dart`, `lib/tv/tv_player_hud.dart`, `TvBridge.kt`), Tier 2 (`lib/scripts/tv_*.patch`, `lib/scripts/patch.ps1`, `tool/tv_patch.sh`), Tier 3 hooks (`lib/main.dart`, `player_focus.dart`, `connectivity_utils.dart`, `constants.dart`, `api.dart`, `MainActivity.kt`, `AndroidManifest.xml`, `build.gradle.kts`, `.github/workflows/sync-upstream-build.yml`), and all 43 automated TV tests.
     * Verified `flutter analyze --no-pub` reports `No issues found!` across all TV modules, hooks, and tests, and `flutter test --no-pub test/tv_navigation_test.dart test/tv_player_hud_test.dart` passes `43/43` tests (`26` navigation + `17` player HUD) on Flutter `3.47.7`.
     * Documented the 7-dimension architecture scorecard, deep-dive module reviews, 6 Low/Informational code-hygiene observations (`R1`–`R6`: non-Leanback HDMI box predicate nuance, unused `TvNavigation.onBack` & `'defaultFullScreen'` seed key, `DateTime.now()` vs. `samplingClock` in `_seekRelative`, `LoginPage` tab-index coupling & retry `ensureVisualUpdate()`, minor `TvNavigation` leaf-painter/allocation polish, and intentional `space` key separation), and the upstream sync risk matrix.
  2. **Documentation Sync Across `docs/tv/*` & Root `README*.md`**:
     * Corrected M7 architectural details in `docs/tv/ARCHITECTURE.md` (`findRecoveryFocus` container-scoped recovery, `repeatLockedThisFrame` discrete-burst continuity, `PageMetrics`/`KeepAliveParentDataMixin` offscreen detection, $O(D)$ zero-allocation `_accumulatedParentOffset`), added Section 2.10 for M6 (`_unwrapMediaQueryChild`, `_promotePopupMenuFocusIfNeeded`, `_InkResponseState._canRequestFocus` directional fix), and expanded capability invariants to `C1`–`C21`.
     * Updated `docs/tv/README.md` and `docs/tv/README.en.md` to match the pinned Flutter SDK (`3.47.7`), align runtime TV detection criteria (`UI_MODE_TYPE_TELEVISION`, `FEATURE_LEANBACK`, or `PILI_FORCE_TV=true`), and index `REVIEW.md`.
     * Updated root `README.md` and `README.en.md` with Hold-Select `3.0x` temporary playback speed, Phase 3 roadmap coverage, and `docs/tv/REVIEW.md`.
  3. **Hygiene & Privacy Check**:
     * Confirmed `./tool/tv_patch.sh status` reports `[NOT APPLIED]` for all 38 patches and verified zero private paths, file-scheme URLs, LAN IPs, usernames, or device serials in committed files.

---

### [2026-10-24] Milestone M9 (Task `M9.1`): Root-Cause Analysis for Second-Layer Comment (`评论详情`) & `MiniScaffold` Inline Sheet Focus Bug
* **Status**: ✅ Completed
* **Files Updated**:
  * `[MODIFY] docs/tv/PLAN.md`
  * `[MODIFY] docs/tv/PROGRESS.md`
* **Verified Root Cause**:
  1. **Inline `LocalHistoryEntry` Sheet Instead of `Navigator` Route (`MiniScaffold` + `BottomSheetLayout`)**:
     * On landscape/split-pane pages (`VideoDetailPageV` in `lib/pages/video/view.dart`, `DynamicDetailPage` in `lib/pages/dynamics_detail/view.dart`, `ArticlePage` in `lib/pages/article/view.dart`, and `MusicDetailPage` in `lib/pages/music/view.dart`), the right-hand tab/comment column is wrapped in `MiniScaffold` (`lib/common/widgets/scaffold/mini_scaffold.dart`).
     * Clicking a first-layer comment invokes `MiniScaffoldState.showBottomSheet((context) => VideoReplyReplyPanel(...))` (`lib/pages/video/reply/controller.dart:67` and `lib/pages/common/dyn/common_dyn_page.dart:316`). Rather than pushing a `Route` onto `Navigator`, `MiniScaffoldState` adds a `LocalHistoryEntry` to the active `ModalRoute` and renders `BottomSheetLayout(body: widget.body, bottomSheet: _currentBottomSheet?.widget)` (`lib/common/widgets/scaffold/bottom_sheet_layout.dart`).
  2. **Simultaneous Dual-Slot Layout in One `FocusScopeNode` Without Focus Exclusion**:
     * `_RenderScaffoldLayout` (`BottomSheetLayout`) lays out both `BottomSheetType.body` (first-layer `TabBar` and comment list) and `BottomSheetType.bottomSheet` (`_StandardBottomSheet` -> `VideoReplyReplyPanel`) at full size inside the **same** `FocusScopeNode`, painting `bottomSheet` over `body` without wrapping `body` in `Offstage`, `Visibility`, `IgnorePointer`, or `ExcludeFocus`.
     * Consequently:
       1. `TvNavigationObserver.didPush` never fires because no `Route` was pushed; `FocusManager.instance.primaryFocus` remains on the clicked first-layer comment `InkWell` inside `BottomSheetType.body`.
       2. `_TvNavigationState._syncFocusRectAfterLayout` sees unchanged `targetBox`, `size`, `parentOffset` (`Offset.zero`), and `scrollPixels` on the occluded first-layer comment, hitting the `isStationary` fast-path and continuing to paint the yellow focus ring (`#FFFFD166`) over `评论详情` at the hidden first-layer card's coordinates (verified live on `<vm-tv>`).
       3. `_TvTraversalCache.evaluateNode` marks all nodes inside `BottomSheetType.body` as `isFocusable == true`, so D-pad Up/Down runs `_findVerticalCandidate` with `focusedScrollable` = first-layer `CustomScrollView`, scrolling and traversing the occluded first-layer comment list underneath while `评论详情` stays static.
       4. Cross-pane Left/Right navigation and closing `评论详情` via Android Back (`LocalHistoryEntry.onRemove` -> `animationController.reverse()`) lack occlusion isolation and focus-memory restoration.
  3. **Collateral Multi-Layer & Cross-Column `MiniScaffold` Surfaces**:
     * Nested third-layer dialogue sheets (`查看对话` -> `对话列表` via `VideoReplyReplyPanel`'s inner `MiniScaffold` in `lib/pages/video/reply_reply/view.dart:144, 331`), `NoteListPage` (`lib/pages/video/note/view.dart:60, 303`), `ImageGridView` `GalleryViewer` (`enableDrag: false`), and left-column `videoIntro` inline panels (`选集` `EpisodePanel`, `AI总结` `AiConclusionPanel`, `视频看点` `ViewPointsPage`, `PgcIntroPanel`, `HorizontalMemberPage`) all share `MiniScaffold.showBottomSheet` and will be remediated in Tier 1 (`lib/tv/tv_navigation.dart`) with zero upstream file modifications.

---

### [2026-10-24] Milestone M9 (Tasks `M9.2`–`M9.3`): Self-Contained `BottomSheetLayout` Focus Isolation, Promotion, Restoration & Regression Tests
* **Status**: ✅ Completed
* **Files Changed**:
  * `[MODIFY] lib/tv/tv_navigation.dart`
  * `[MODIFY] test/tv_navigation_test.dart`
  * `[MODIFY] docs/tv/PLAN.md`
  * `[MODIFY] docs/tv/PROGRESS.md`
* **Technical Details & Changes Summary**:
  1. **Task `M9.2` — `BottomSheetLayout` Occlusion Isolation, Opening Promotion & LIFO Focus Restoration (`lib/tv/tv_navigation.dart`, Zero Upstream Diff)**:
     * Imported `BottomSheetLayout` and `BottomSheetType` from `package:PiliPlus/common/widgets/scaffold/bottom_sheet_layout.dart`.
     * Added `_BottomSheetNodeStatus` and `_TvTraversalCache._isBottomSheetClosing`, `_isBottomSheetAnimatingOpen`, and `_inspectBottomSheetNode(FocusNode?)`, and updated `_TvTraversalCache.evaluateNode` to inspect `childSlot` at every `BottomSheetLayout` ancestor:
       * Rejects `BottomSheetType.body` descendants (`focusable = false`) whenever `BottomSheetLayout.bottomSheet` is opening or open (`!_isBottomSheetClosing(sheet)`), immediately isolating occluded first-layer comments and `TabBar` tabs from holding focus, painting a focus ring (`_computeFocusedRect`), or receiving D-pad traversal.
       * Rejects `BottomSheetType.bottomSheet` descendants (`focusable = false`) as soon as `StandardBottomSheet.animationController.status` enters `AnimationStatus.reverse` or `AnimationStatus.dismissed`.
     * Added `TvFocusTraversalPolicy.findFirstFocusInSubtree` and `BottomSheetLayout`-aware recovery in `TvFocusTraversalPolicy.findRecoveryFocus` (returning `null` while an occluding sheet is in `AnimationStatus.forward` before its children lay out, preventing frame-0 zero-height `Align(heightFactor: 0.0)` sheets from leaking focus onto the left-hand video player column).
     * Added `Expando<_MiniScaffoldSheetRecord> _bottomSheetRecords`, LIFO `_trackedBottomSheetLayouts`, `HardwareKeyboard.instance.addHandler(_observeHardwareKeyEvent)` (capturing `Select`/`Enter`/`NumpadEnter`/`GameButtonA` triggers even when a left-column `ButtonStyleButton` like `AI总结`/`选集` consumes `Enter` before ancestor `Focus.onKeyEvent` bubbles and opens a sheet on the right-column `MiniScaffold`), `_hasPendingBottomSheetWork` (preceding `isStationary` in `_syncFocusRectAfterLayout` while keeping `isStationary == true` at ~0.001ms/frame once settled inside the open sheet), and `_reconcileBottomSheets` for multi-level LIFO promotion and exact pre-sheet `FocusNode` restoration (with container-scoped fallback into `BottomSheetType.body` if the saved node was unmounted).
     * Refined `_onFocus`'s non-policy `_ensureVisibleInUserScrollables` call from `ScrollPositionAlignmentPolicy.explicit` (`alignment: 0.0`) to `keepVisibleAtEnd` + `keepVisibleAtStart`, so offscreen `autofocus` items still scroll into view while restoring focus to an already-visible comment card preserves the exact user scroll offset without snapping the card to the top edge.
  2. **Task `M9.3` — Automated Regression Tests (`test/tv_navigation_test.dart`)**:
     * Added 3 widget tests exercising real `MiniScaffold` + `GetMaterialApp` lifecycles:
       1. `'MiniScaffold 2nd-layer comment (评论详情) & nested 3rd-layer dialogue (对话列表) promote focus, isolate occluded 1st-layer scroll/TabBar, and restore exact focus on Back (M9)'`
       2. `'MiniScaffold handles cross-column Enter trigger (选集 / AI总结), enableDrag: false Opacity sheet, and in-place sheet replacement while preserving saved focus (M9)'`
       3. `'MiniScaffold handles same-frame requestFocus + noAnimation showBottomSheet and recovers into MiniScaffold.body if saved node was deleted (M9)'`
     * Verified `flutter analyze --no-pub lib/tv/ test/tv_navigation_test.dart test/tv_player_hud_test.dart` (`No issues found!`) and `flutter test --no-pub test/tv_navigation_test.dart test/tv_player_hud_test.dart` (`46/46` passed: `29` navigation + `17` player HUD).

---

### [2026-10-24] Milestone M9 (Task `M9.4`): Live `<vm-tv>` Verification, Documentation Sync (`C22`) & Patch Revert Discipline
* **Status**: ✅ Completed
* **Files Updated**:
  * `[MODIFY] docs/tv/ARCHITECTURE.md`
  * `[MODIFY] docs/tv/REVIEW.md`
  * `[MODIFY] docs/tv/README.md`
  * `[MODIFY] docs/tv/README.en.md`
  * `[MODIFY] docs/tv/PLAN.md`
  * `[MODIFY] docs/tv/PROGRESS.md`
  * `[MODIFY] README.md`
  * `[MODIFY] README.en.md`
* **Live Verification & Documentation Summary**:
  1. **APK Build, Side-by-Side Installation & Live D-Pad Verification on `<vm-tv>`**:
     * Applied all 38 patches (`./tool/tv_patch.sh apply`), built both split-ABI release (`app-arm64-v8a-release.apk`) and side-by-side debug (`app-debug.apk` / `com.lemontea.piliplus.tv.debug`) APKs, and immediately reverted all 38 patches (`./tool/tv_patch.sh revert`).
     * Installed `com.lemontea.piliplus.tv.debug` onto `<vm-tv>` alongside the pre-existing `com.lemontea.piliplus.tv` installation without disturbing user login state, navigated to `VideoDetailPageV` -> `评论 1958`, and verified via live frame captures + `adb logcat`:
       * **2nd-Layer Opening Promotion**: Pressing `DPAD_CENTER` on a 1st-layer comment opens `评论详情` (`VideoReplyReplyPanel`) and promotes the yellow focus ring immediately onto `评论详情`'s top-right `关闭` button (zero phantom focus ring on hidden 1st-layer cards).
       * **2nd-Layer D-Pad Traversal & Scroll Isolation**: Pressing `DPAD_DOWN` / `DPAD_UP` steps through 2nd-layer replies and scrolls `评论详情` smoothly while the occluded 1st-layer comment list underneath stays untouched.
       * **Cross-Pane Left/Right Isolation**: Pressing `DPAD_LEFT` crosses to the left video title/intro column and `DPAD_RIGHT` returns directly into the visible 2nd-layer `评论详情` reply.
       * **Nested 3rd-Layer `对话列表` (`VideoReplyDlgPanel`) & LIFO Stack**: Opening `对话列表` (`查看对话`) promotes focus into 3rd-layer `对话列表`, supports D-pad traversal across 3rd-layer replies, and unwinds cleanly across two `KEYCODE_BACK` presses (`3rd -> 2nd -> 1st`).
       * **Scrolled 1st-Layer Minimal-Scroll Restoration**: Opening `评论详情` from a scrolled bottom-half 1st-layer comment and closing via either `KEYCODE_BACK` or `DPAD_CENTER` on `关闭` restores the yellow focus ring to that exact 1st-layer comment at its pixel-identical scroll offset (`0` top-jump).
       * **Runtime Health**: `adb logcat` reported `0` `FlutterError`, `0` `FATAL EXCEPTION`, and `0` `ANR`.
  2. **Documentation & Invariant Sync (`C22`, `R7`)**:
     * Added Section `2.12` (*Multi-Layer `MiniScaffold` Inline Bottom Sheet Focus Isolation & Restoration (M9)*) and Invariant `C22` to `docs/tv/ARCHITECTURE.md`.
     * Updated `docs/tv/REVIEW.md` (baseline commit `eb746dd8f`, `46/46` TV tests, Section `2.2` M9 coverage, observation `R7` on `ReplyItemGrpc` card-level focus vs. nested `查看对话` button under Invariant `C12`), `docs/tv/README.md`, `docs/tv/README.en.md`, `README.md`, and `README.en.md`.
  3. **Patch Revert, Zero Upstream Diff & Privacy Audit**:
     * Confirmed `./tool/tv_patch.sh status` reports `[NOT APPLIED]` for all 38 patches, verified `0` diff across all upstream files outside `lib/tv/`, `test/`, `docs/tv/`, and `README*.md`, and verified zero private paths, file-scheme URLs, LAN IPs, usernames, or device serials in committed files or commit messages.
---

### [2026-10-25] Milestone M9 (Task `M9.5`): Embedded Comment Actions (`R7`), Async/Delayed Sheets, Zero-Focusable Sheets & Route PopScope Tracking
* **Status**: ✅ Completed
* **Files Changed**:
  * `[MODIFY] lib/tv/tv_navigation.dart`
  * `[MODIFY] test/tv_navigation_test.dart`
  * `[MODIFY] docs/tv/REVIEW.md`
  * `[MODIFY] docs/tv/ARCHITECTURE.md`
  * `[MODIFY] docs/tv/PLAN.md`
  * `[MODIFY] docs/tv/PROGRESS.md`
* **Technical Details & Changes Summary**:
  1. **Embedded Comment Action Reachability (`R7`, D1)**:
     * In `TvFocusTraversalPolicy`, implemented `embeddedCardActionFallback(FocusNode node, TraversalDirection direction)`: when a focused comment card (`InkResponse` / `InkWell` in `ReplyItemGrpc`) receives D-pad Right, it steps into its primary embedded action (`回复` / `ButtonStyleButton` / `IconButton`).
     * In `_TvTraversalCache._isEmbeddedSecondaryOf` and `_metaWithAncestors`, allowed horizontal traversal across sibling embedded `ButtonStyleButton` and `IconButton` micro-actions (`回复` <-> `查看对话` <-> `点赞` <-> `点踩`) while keeping them excluded from vertical candidate searches.
     * Pressing D-pad Left from any embedded action steps back to the parent card; pressing D-pad Up/Down from the card continues to step 1 full card per press, resolving `R7` with 0 impact on fast 10-foot list scrolling.
  2. **Async-Loading Sheet Focus Promotion (D2)**:
     * Added `_subtreeHasRequestableFocus` and pending promotion tracking in `_TvNavigationState` to handle sheets whose focusables mount asynchronously after the open animation finishes (such as `HorizontalMemberPage`).
     * Automatically promotes focus once content mounts without spinning idle frame callbacks, and respects manual user navigation (`userMovedFocus`) without allowing repeated layout passes to overwrite user focus.
  3. **Delayed & Programmatic External Sheets (D3)**:
     * Tracked programmatic sheets (`showMediaListPanel`) and delayed Future triggers (such as `_aiBtn` in `video_intro`) by observing `ModalRoute.willHandlePopInternally` transitions and `_knownBottomSheetLayouts`.
     * Focus promotes into newly opened sheets even when decoupled from the initial Select/Enter key press by asynchronous execution.
  4. **Zero-Focusable Sheet Isolation (D4)**:
     * When opening sheets that contain no focusable widgets (such as `ImageGridView` `GalleryViewer`), immediately unfocuses occluded body widgets (`GestureDetector`) without prematurely hijacking focus to the left-hand video column or spinning idle frames, and restores focus to the trigger on Back.
  5. **PopScope & Internal Route Pop Tracking (D5)**:
     * Tracked internal route pop transitions via `_routeWillHandlePop`, ensuring reliable LIFO focus restoration when sheets are dismissed via Android Back or programmatic pop.
  6. **Pinned/Floating Sliver Header Dual-Coordinate Translation, Scroll Reveal & Primary Card Focus Preference**:
     * In `_TvTraversalCache.evaluateNode`, accumulated `sliverScrollOffsetDelta` across `RenderSliverSingleBoxAdapter` and `RenderSliverPersistentHeader` ancestors (`SliverPinnedHeader` in 2nd-layer `VideoReplyReplyPanel` and `SliverFloatingHeaderWidget` in 1st-layer `VideoReplyPanel`), storing both `rect` (scroll-order coordinates) and `visualRect` (screen-space coordinates) on `_TvNodeMeta`.
     * Pressing D-pad Up from lower replies steps cleanly (`reply_3 -> reply_2 -> reply_1 -> reply_0 -> 按热度 -> firstFloor -> 关闭`) instead of jumping prematurely to the pinned `按热度` sort button; once `按热度` receives focus while scrolled, `_ensureVisibleInUserScrollables` scrolls the sliver header back to `precedingScrollExtent`, and directional exits (`Up`/`Down`/`Left`) from pinned/floating headers use `visualRect` while keeping `inBand` horizontal checks in scroll-order coordinates within the same vertical scrollable.
     * Added `_preferPrimaryInitialCandidates` and `_isEmbeddedSecondaryOfFocusableAncestor` in `TvFocusTraversalPolicy` (`findFirstFocusInSubtree`, `findRecoveryFocus`, `findFirstFocus`, `findFirstFocusInDirection`) and viewport-filling tall card detection (`>= 50%` viewport height) in `_isRectVisibleInScrollable` so initial or recovery focus in a partially scrolled or long-comment list lands on the first visible primary card/control rather than a micro secondary button (`回复`/`点赞`) of a half-scrolled-off card.
  7. **Automated Regression Tests & Verification**:
     * Added 7 comprehensive automated widget tests in `test/tv_navigation_test.dart` (`36/36` navigation tests, `53/53` total TV tests):
       1. Async-loading sheet promotion (`HorizontalMemberPage` pattern);
       2. Async-triggered and programmatic external sheets (`_aiBtn` / `showMediaListPanel` pattern);
       3. Zero-focusable sheet body isolation (`ImageGridView` pattern);
       4. Embedded comment action navigation (`ReplyItemGrpc` pattern: D-pad Right into `回复`/`查看对话`/`点赞`, 3rd-layer `对话列表` opening, D-pad Left return, and 1-card vertical step preservation);
       5. Embedded `IconButton` micro-action stepping and `userMovedFocus` retention across multiple frame ticks;
       6. `SliverPinnedHeader` and `SliverFloatingHeaderWidget` upward D-pad traversal without pinned header hijacking, plus half-scrolled primary card initial focus preference;
       7. Pinned/floating sliver header scroll-reveal to `precedingScrollExtent`, directional exits (`Up`/`Down`/`Left`) while scrolled, and tall viewport-filling comment card visibility.
     * Validated live on `<vm-tv>` with 0 logcat errors, 0 runtime exceptions, and clean patch revert discipline (`[NOT APPLIED]` for all 38 patches).

---

### [2026-10-25] Milestone M9 (Task `M9.6`): Restore F2 Dual-Target Opposite Half-Plane Candidate Culling & Target Viewport Clamping Refinement
* **Status**: ✅ Completed
* **Files Changed**:
  * `[MODIFY] lib/tv/tv_navigation.dart`
  * `[MODIFY] docs/tv/REVIEW.md`
  * `[MODIFY] docs/tv/README.md`
  * `[MODIFY] docs/tv/README.en.md`
  * `[MODIFY] README.md`
  * `[MODIFY] README.en.md`
  * `[MODIFY] docs/tv/PROGRESS.md`
* **Technical Details & Changes Summary**:
  1. **Dual-Target Opposite Half-Plane Candidate Culling (F2 Restoration)**:
     * In `TvFocusTraversalPolicy.inDirection`, restored spatial candidate pre-filtering to prune RenderBoxes situated completely in the opposite half-plane of both the scroll-order `target` Rect and the screen-space `visualTarget` Rect (`_isInOppositeHalfPlane(rawRect, target, direction) && _isInOppositeHalfPlane(rawRect, visualTarget, direction)`).
     * Preserves performance benefits of spatial culling during high-frequency D-pad traversal while seamlessly supporting dual-coordinate sliver headers.
  2. **Preservation of Scroll-Order Coordinates for Upward Traversal**:
     * Preserved scroll-order `target` coordinates (`cache.rectOf(focusedChild)`) during upward candidate selection while leveraging clamped `visualTarget` for downward, horizontal, and external boundary exits.
     * Prevents clobbering `sliverScrollOffsetDelta`-adjusted coordinates on pinned/floating sliver headers (`SliverPinnedHeader` / `SliverFloatingHeaderWidget`), guaranteeing robust directional exits while scrolled.
  3. **Test Suite Verification & Documentation Sync**:
     * Verified all 53 automated widget tests pass cleanly (`36/36` navigation tests in `test/tv_navigation_test.dart` and `17/17` player HUD tests in `test/tv_player_hud_test.dart`).
     * `flutter analyze` reports 0 issues.
     * Synchronized documentation suite across `docs/tv/REVIEW.md`, `README.md`, `README.en.md`, `docs/tv/README.md`, `docs/tv/README.en.md`, and `docs/tv/PROGRESS.md`.

---

## Detailed Task Log (Phase 4: Unified Modal Focus Layer Model & Code Review Remediation)

### [2026-10-25] Milestone M10 (Task `M10.1`): Root-Cause Analysis for `🎉 发现新版本` (`SmartDialog`) Focus \& Unified Focus-Layer Design
* **Status**: ✅ Completed
* **Files Changed**:
  * `[MODIFY] docs/tv/PLAN.md` (Phase 4 roadmap + Milestone M10 breakdown)
  * `[MODIFY] docs/tv/PROGRESS.md`
* **Findings**:
  1. `Update.checkUpdate` (`lib/utils/update.dart:85`) opens the update dialog with `SmartDialog.show` (`useSystem: false`). `flutter_smart_dialog` inserts a `SmartOverlayEntry` into its own `Overlay`, *next to* the root `Navigator` (`FlutterSmartDialog.init(builder: _builder)`). It never pushes a route, builds a `FocusScope`, or requests focus.
  2. The dialog's `FocusNode`s therefore attach as siblings of the root Navigator's focus branch under `TvNavigation`'s `FocusTraversalGroup`. The `/about` route scope stays active, so `TvNavigationObserver` (C11), M6 inactive-scope promotion (C18), and M9 inline-sheet promotion (C22) never fire. Focus and the ring stay on `版本` behind the mask, and D-pad and Select act on the hidden page.
  3. The same bug affects every interactive `SmartDialog` (storage-permission `去授权` in `lib/utils/image_utils.dart:59`, plus any added later). Toasts, loading, and notifications have no focusable nodes and must keep their current behavior.
  4. Cross-milestone pattern: M6 (`showMenu(requestFocus: false)`), M9 (`MiniScaffold` inline sheets), and this bug are all "a new layer appears but focus stays behind". Each was fixed with its own detect/save/promote/occlude/restore code inside `_syncFocusRectAfterLayout` / `_onFocus`.
* **Decision**: add one `_TvFocusLayer` interface (`discover` / `contains` / `occludes` / `firstFocus` / `isClosing`) and one shared `_TvFocusLayerStack` lifecycle. Ship the generic `_OverlayFocusLayer` provider first (M10.5–M10.7, the user-facing fix), then move M6 and M9 onto the same stack behind strict "existing assertions unchanged" gates (M10.8–M10.9). Task IDs in this entry follow the 2026-10-26 renumbering (see the `M10.2` entry). See [`PLAN.md` → Milestone M10](./PLAN.md).

---

### [2026-10-26] Milestone M10 (Task `M10.2`): TV Layer Code Review & Findings Triage (`R8`–`R20`) and M10/M11 Consolidation
* **Status**: ✅ Completed
* **Files Changed**:
  * `[MODIFY] docs/tv/PLAN.md` (review findings added to the Milestone M10 breakdown; the separate Milestone M11 was folded into M10 and the planned tasks renumbered)
  * `[MODIFY] docs/tv/PROGRESS.md`
* **Scope**: `lib/tv/tv_platform.dart`, `lib/tv/tv_navigation.dart`, `lib/tv/tv_player_hud.dart`, `TvBridge.kt`, `lib/scripts/tv_*.patch` (including `material/tv_ink_well.patch`), `tool/tv_patch.sh`, and the Tier 3 hooks (`lib/main.dart`, `player_focus.dart`, `connectivity_utils.dart`). Each finding was cross-checked against the upstream code the TV layer depends on (`PlPlayerController`, `MiniScaffold` / `BottomSheetLayout`, `ScaledWidgetsFlutterBinding`, `LoginPage`, setting deletes) and the Flutter SDK source (`RenderObject.getTransformTo`, `ModalRoute.of`).
* **Verification**: not run. The local Flutter SDK does not have the TV patches applied, and the review did not patch it, so `flutter analyze` / `flutter test` were not run and no finding was reproduced at runtime. Findings are confirmed by reading both sides of each code path.
* **Findings** (details, failure scenarios and planned fixes in [`PLAN.md` → Milestone M10, Task M10.2](./PLAN.md)):

  | ID | Severity | Location | Finding | Task |
  | :--- | :--- | :--- | :--- | :--- |
  | `R8` | High | `tv_player_hud.dart:1520-1539`, `tv_gesture_detector.patch` | The patched `GestureDetector` adds a second `Focus` inside `_TvHudPillButton`. D-pad traversal lands on it, so Select fires on key-down and Hold-Select 3x speed never starts on `暂停/播放`, `全屏`, `播/暂` after any D-pad move. Tests only hold Select on the autofocused node. | `M10.3` |
  | `R9` | High (`uiScale ≠ 1.0`) | `tv_navigation.dart:555-567` | The viewport check uses `view.physicalSize / devicePixelRatio`, but `ScaledWidgetsFlutterBinding` lays out in `physicalSize / (dpr × uiScale)`. Below `1.0`, focusables outside scrollables in the right/bottom `(1 − uiScale)` of the screen are unreachable (e.g. the fullscreen seek bar at `0.8`); above `1.0`, off-screen nodes count as visible. | `M10.4` |
  | `R10` | Medium | `tv_player_hud.dart:1735-1767` | Lazy `ListView.separated` in the 420 px option dialog never builds items past ~#14, so the current episode's `autofocus` never fires and focus lands on item 0. | `M10.3` |
  | `R11` | Medium | `tv_player_hud.dart:315-323, 1202-1205` | `playerStatus` updates asynchronously from the `playing` stream, but `_togglePlayPause` rebuilds immediately, so the HUD Play/Pause label shows the old state. | `M10.3` |
  | `R12` | Medium-Low | `tv_player_hud.dart:382-387` | `mediaPlay` and `mediaPause` both toggle, so separate Play/Pause remote and HDMI-CEC keys do the opposite when already in that state. | `M10.3` |
  | `R13` | Medium (perf) | `tv_navigation.dart:2806-2812, 2444-2465` | Ancestor walk + `ModalRoute.of` run every frame before the stationary check; an open zero-focusable sheet gets a full subtree walk every frame; `ModalRoute.of` registers rebuild dependencies on focused elements. The "~0.001 ms" stationary claim in `ARCHITECTURE.md` doesn't hold. | `M10.9` |
  | `R14` | Low | `tv_navigation.dart:2171-2183` | Persistent frame callback can't be removed and `dispose` doesn't clear tracked `Element` lists, so a remounted `TvNavigation` would keep the old state reachable. | `M10.10` |
  | `R2` | Low (still open) | `tv_navigation.dart:2104-2108` | `TvNavigation.onBack` is still unused. | `M10.10` |
  | `R15` | Low | `tv_navigation.dart:87-97` | `animationController` read through `dynamic` + `try/catch`; a typed `StandardBottomSheet` check is cheaper and fails at compile time on an upstream rename. | `M10.9` |
  | `R16` | Low | `tv_platform.dart:24, 116-118` | `tvDefaultsSeededV1` is written but never read; seeding runs on every launch (harmless), while docs say first launch. | `M10.10` |
  | `R17` | Low | `video/view.dart:1281`, `live_room/view.dart:252` | The TV HUD only mounts when upstream `keyboardControl` is on; turning it off on TV silently removes the HUD and Quick Strip. | `M10.10` |
  | `R18` | Info | `tv_player_hud.dart:327-345` | Seek acceleration multiplier carries over a direction change (`R3`, `DateTime.now()`, still open in the same function). | `M10.10` |
  | `R19` | Info | `tv_player_hud.dart:1079` | HUD clock is set at build time and doesn't tick. | `M10.10` |
  | `R20` | Info | `tv_navigation.dart:3405-3406` | Login QR tab index `2` is hard-coded; correct today, but an upstream reorder would open the wrong tab (`R4` fixed only the retry). | `M10.10` |
  | `R5` (4) | Info (still open) | `tv_navigation.dart:2061` | `_TvVerticalFocusIntent` handles all four arrows; rename to `_TvArrowFocusIntent`. | `M10.10` |

* **Checked and fine**: `TvBridge` `WeakReference` handling and null fallbacks; the soft-keyboard gate; `MediaQuery` unwrapping; the repeat throttle ordering (`didScrollInLastFocus` is set before `_onFocus` runs); route focus memory; media keys reach the HUD from anywhere on the player page (`PlayerFocus` wraps the whole page body); both `tv_ink_well.patch` copies have identical hunks; no seeded setting key is deleted upstream.
* **Decision**: fold the fixes into Milestone M10 instead of a separate Milestone M11, so all remaining TV focus work is one sequence. The review fixes go first (`M10.3` HUD, `M10.4` `uiScale`): they are small, don't depend on the focus-layer work, and include both High findings; `M10.4` must also land before the layer core (`M10.5`) because both edit `evaluateNode`. `R13` / `R15` join the inline-sheet migration (`M10.9`) so that code changes once, and `M10.5` must keep the no-layer path O(1). Live verification and the docs sync are each one combined task (`M10.7`, `M10.11`). Old → new task IDs: `M10.2`→`M10.5`, `M10.3`→`M10.6`, `M10.4`→`M10.7`, `M10.5`→`M10.8`, `M10.6`→`M10.9`, `M10.7`→`M10.11`; `M11.1`→`M10.2`, `M11.2` + `M11.4`→`M10.3`, `M11.3`→`M10.4`, `M11.5`→`M10.9`, `M11.6`→`M10.10` (except `R15`→`M10.9`), `M11.7`→`M10.7` (live checks) + `M10.11` (docs).

---

### [2026-10-26] Milestone M10 (Task `M10.3`): Player HUD Fixes `R8`, `R10`–`R12`
* **Status**: ✅ Completed
* **Files Changed**:
  * `[MODIFY] lib/tv/tv_player_hud.dart`
  * `[MODIFY] test/tv_player_hud_test.dart`
  * `[MODIFY] docs/tv/PLAN.md`
  * `[MODIFY] docs/tv/PROGRESS.md`
* **Method**: tests first. The 9 new tests were written and run against the unfixed code on a patched SDK: 7 failed and 2 passed (the 2 are guards for behavior that must not change). The M10.2 review was static reading only, so this is the first runtime confirmation of these four findings.
* **Changes**:

  | ID | Fix | Test (`test/tv_player_hud_test.dart`) |
  | :--- | :--- | :--- |
  | `R8` | `_TvHudPillButton` wraps its `GestureDetector` in `ExcludeFocus`. The pill's own `Focus` is now its only focusable node, so Select key-down no longer reaches the patched `GestureDetector`'s `onTap` first. Pointer taps still work. It is the only `GestureDetector` in `lib/tv`. | HUD `暂停` pill and Quick Strip `全屏` / `播/暂`: Right, Left, then hold Select ≥ 250 ms starts 3x speed, release restores it, a short press still acts once. Plus a touch-tap guard. |
  | `R10` | `_TvOptionListDialog` is stateful: `ListView.builder` with a fixed 52 px row extent (46 px pill + 3 px padding above and below, 6 px gap as before), a `ScrollController` whose initial offset centers the selected row, and the list box height computed from the same extent. `_TvHudPillButton` gained an optional `alignment` to keep the label vertically centered in the taller row. | 60 episodes, episode 45 current: the dialog opens on it, it is focused and inside the viewport, episode 1 is not built, Down steps to episode 46. Guard: a short list with the first item selected still starts at the top. |
  | `R11` | `_TvPlayerHudState` registers `_onPlayerStatusChanged` with `PlPlayerController.addStatusLister` and rebuilds from it. Registration is re-bound in `didUpdateWidget` and removed in `dispose`. The eager `setState` after `onDoubleTapCenter()` was removed. | Label flips only after the player's status event (80 ms later in the fake); external `paused` / `completed` / `playing` changes update it; the listener is registered once, follows a controller swap and is removed on dispose. |
  | `R12` | `mediaPlayPause` toggles; `mediaPlay` toggles only when not playing (so a `completed` player restarts); `mediaPause` toggles only when playing. | Each key in the playing, paused and completed states. |

* **Test harness**: `FakePlPlayerController` now implements `addStatusLister` / `removeStatusLister`, `emitPlayerStatus` (sets `playerStatus` first, then notifies, like the real `playing` stream handler) and an optional `statusFlipDelay` that makes `onDoubleTapCenter` report the new state asynchronously. The default leaves `playerStatus` untouched, so the existing tests are unchanged.
* **Design notes**:
  * `R11`: `addStatusLister` silently ignores registrations while the controller's internal player count is `0`. `PlPlayerController.getInstance()` raises it before a page builds the HUD, and `lib/pages/video/view.dart` and `lib/pages/live_room/view.dart` register status listeners the same way.
  * `R12` reads `_pl.playerStatus`, like the existing `_canTriggerLongPressSpeed`. A second Play or Pause key arriving before the player reports the first change can still toggle twice; the window is the player's event latency.
  * `R10`: the pill is 46 px tall in option lists (it was content-sized at about 40 px). Short lists no longer reserve the old `56 px × n + 16 px` box.
* **Verification** (patches applied, then reverted):
  * `flutter analyze --no-pub lib/tv/ test/tv_navigation_test.dart test/tv_player_hud_test.dart`: `No issues found!`. A whole-repo `flutter analyze --no-pub` reports 43 `info` items, all in upstream files this task does not touch.
  * `flutter test --no-pub test/tv_navigation_test.dart test/tv_player_hud_test.dart`: `62/62` passed (`36` navigation + `26` player HUD, up from `17`).
  * `./tool/tv_patch.sh status`: `[NOT APPLIED]` for all 38 patches after the revert.
  * Not run on a TV device: live verification of the review fixes is part of `M10.7`.

---

### [2026-10-26] Milestone M10 (Task `M10.4`): `uiScale` Viewport Fix `R9`
* **Status**: ✅ Completed
* **Files Changed**:
  * `[MODIFY] lib/tv/tv_navigation.dart`
  * `[MODIFY] test/tv_navigation_test.dart`
  * `[MODIFY] docs/tv/PLAN.md`
  * `[MODIFY] docs/tv/PROGRESS.md`
* **Method**: tests first. The 4 new tests ran against the unfixed code on a patched SDK: 3 failed (the three `uiScale ≠ 1.0` cases, on the predicted assertions) and 1 passed (the `uiScale == 1.0` guard). This is the first runtime confirmation of `R9`; the M10.2 review was static reading only.
* **Root cause**: `_TvTraversalCache.evaluateNode` clipped nodes outside user-scrollables to `View.physicalSize / View.devicePixelRatio`. `ScaledWidgetsFlutterBinding` lays the tree out in `physicalSize / (devicePixelRatio × uiScale)`, and `localToGlobal` reports in that space, so the viewport and the node rects were in different spaces whenever `uiScale ≠ 1.0`. At `0.8`, focusables outside scrollables in the right and bottom ~20% (the fullscreen HUD seek bar, non-scrolling right-column tabs, app-bar actions) were unfocusable, and focus recovery could move focus off them. At `1.25`, off-screen nodes outside scrollables counted as visible.
* **Fix**: `_TvTraversalCache.viewportRectOf(RenderBox)` returns `Offset.zero & RenderView.size` of the box's pipeline owner root, memoized per cache and per root. `evaluateNode` uses it in place of the `View` lookup. No `BuildContext` lookup, no inherited dependency, no per-node cost beyond an identity comparison. `_computeFocusedRect` already used the `TvNavigation` root box size, so the focus ring needed no change.
* **Tests** (`test/tv_navigation_test.dart`, group `viewport follows the scaled root view (M10, R9)`): the harness keeps `View.physicalSize` at `1920×1080` and `devicePixelRatio` at `1.0` while `tester.binding.setSurfaceSize` sets the root layout size.
  * `uiScale 0.8` (`2400×1350`): a control in the right band and one in the bottom band are reachable by D-pad in both directions.
  * `uiScale 0.8`: autofocus on a right-band control is kept through the first frames (no recovery away from it).
  * `uiScale 1.25` (`1536×864`): a control at `x = 1700` (beyond the layout width, inside `1920`) is not reachable.
  * `uiScale 1.0` guard: a control beyond the right edge stays unreachable.
* **Verification** (patches applied, then reverted):
  * `flutter analyze --no-pub lib/tv/ test/tv_navigation_test.dart test/tv_player_hud_test.dart`: `No issues found!`.
  * `flutter test --no-pub test/tv_navigation_test.dart test/tv_player_hud_test.dart`: `66/66` passed (`40` navigation, up from `36`, and `26` player HUD).
  * `./tool/tv_patch.sh status`: `[NOT APPLIED]` for all 38 patches after the revert.
  * Not run on a TV device: the live check at `uiScale 1.0` and `0.8` is part of `M10.7`.

---

### [2026-10-26] Milestone M10 (Tasks `M10.5`–`M10.6`): Unified Focus-Layer Core, Overlay (`SmartDialog`) Focus & Regression Tests
* **Status**: ✅ Completed (both tasks in one commit, as `M9.2`–`M9.3` were)
* **Files Changed**:
  * `[NEW] lib/tv/tv_focus_layers.dart` (`part of 'tv_navigation.dart'`)
  * `[MODIFY] lib/tv/tv_navigation.dart`
  * `[MODIFY] test/tv_navigation_test.dart`
  * `[MODIFY] docs/tv/PLAN.md`
  * `[MODIFY] docs/tv/PROGRESS.md`
* **Problem**: `设置 → 关于 → 版本 → 🎉 发现新版本` left focus and the focus ring on the `/about` page behind the dialog. `SmartDialog` renders in an `Overlay` entry next to the root `Navigator`: no route, no `FocusScope`, and `flutter_smart_dialog` never requests focus, so D-pad and Select kept acting on the hidden page. The storage-permission dialog (`去授权`) has the same bug.
* **What was built** (details in [`PLAN.md` → M10.5](./PLAN.md)):
  1. `_TvFocusLayer` / `_TvFocusLayerProvider` / `_TvFocusLayerStack`: the shared lifecycle every "new layer, focus stays behind" bug needs: save the trigger, promote into the layer, pull focus back if it escapes, restore the trigger on close, and keep the page behind the layer unfocusable with no focus ring.
  2. `_OverlayFocusLayer`, the first provider: an anchor `Focus` above `TvNavigation`'s child separates the root `Navigator`'s focus branch from overlay content; any other branch with a focusable node is a modal layer over the whole `Navigator`. Generic: nothing in `lib/tv` imports `flutter_smart_dialog`.
  3. Integration: per-frame check before the stationary fast path; occlusion in `evaluateNode` and `_computeFocusedRect`; `_reconcileFocusLayers()` (layers, then M9 sheets) at the five existing reconcile call sites; `TvFocusTraversalPolicy.findFirstFocusAmong`, extracted from `findFirstFocusInSubtree`.
  4. A 500 ms ring-settling window after promotion, because the default `SmartDialog.show` transition is a scale and the stationary fast path ignores transforms (measured: the ring stayed 35 px off the button without it).
* **Tests** (11, group `overlay dialogs outside the Navigator (M10, SmartDialog)`): a `FlutterSmartDialog.init` harness mirroring `MyApp._builder`, the real update and permission dialog shapes, and the real Select, D-pad, `SmartDialog.dismiss()` and system Back paths. Run against the original `lib/tv` code, 9 fail and 2 pass (the non-interactive-overlay guard and the stationary fast path). The first-frame startup test does not pin the "trigger must be effectively focusable" guard (it also passes without it); the guard is kept for correctness.
* **Verification** (patches applied, then reverted):
  * `flutter analyze --no-pub lib/tv/ test/tv_navigation_test.dart test/tv_player_hud_test.dart`: `No issues found!`.
  * `flutter test --no-pub test/tv_navigation_test.dart test/tv_player_hud_test.dart`: `77/77` passed (`51` navigation, up from `40`, and `26` player HUD). All M6/M7/M9 tests and the F1/F13/F14 benchmarks pass with unchanged assertions.
  * `./tool/tv_patch.sh status`: `[NOT APPLIED]` for all 38 patches after the revert; zero diff in upstream files.
  * Whole-repo `flutter test --no-pub`: `127` passed, `2` failed. Both failures are in `test/utils/accounts/deleted_account_test.dart` (upstream account / Hive `buvid` serialization) and fail identically against the unchanged `lib/` code at `HEAD`, so they predate this change and are not touched here.
  * Not run on a TV device: the live check of `设置 → 关于 → 版本` is `M10.7`.
* **Known limitations** (documented, not addressed): several overlay dialogs open at once are one layer, so a second dialog opened over the first does not take focus from it; an overlay with `usePenetrate: true` that contains focusable widgets would still be modal (the app has none).

---

### [2026-10-26] Milestone M10 (Task `M10.7`): Live `<vm-tv>` Verification
* **Status**: ✅ Completed
* **Files Changed**:
  * `[MODIFY] docs/tv/PLAN.md`
  * `[MODIFY] docs/tv/PROGRESS.md`
  * No source change: the verification found nothing to fix.
* **Device and build**: Android TV image (`arm64-v8a`, API 34, `1920×1080`) on the `<vm-tv>` emulator. Release-mode side-by-side build (`com.lemontea.piliplus.tv.dev`) from the `M10.5`–`M10.6` tree with the TV patches applied during the build and reverted straight after; the user's existing `com.lemontea.piliplus.tv` and `.debug` installs were not modified.
* **Verified live** (details and method in [`PLAN.md` → M10.7](./PLAN.md)):

  | Check | Result |
  | :--- | :--- |
  | `设置 → 关于 → 当前版本` opens the real `🎉 发现新版本` dialog | Focus and ring move to `取消`; page behind is dimmed and ringless; Right / Left move between `取消` and `更新`; Up does not escape to the page |
  | Dialog dismissal | Back (page not popped) and Select on `取消` both return focus and ring to `当前版本` |
  | `R8` Hold-Select after D-pad moves | `3.0倍速中`, 3x playback, no play/pause toggle |
  | `R9` at `uiScale 0.80` | Seek bar (bottom band) reachable with Up from the pills |
  | `R10` 29-part video | `选集` opens on the current episode with the ring on it |
  | `R11` / `R12` media keys | Pause and Play are idempotent, PlayPause toggles, label always follows the player |
  | `M9` comment sheet | Opens with the ring on `关闭`; Back restores the exact comment |
  | App resume, `界面缩放` slider dialog, soft-keyboard gate | Unchanged and working |
  | `adb logcat` | `0` `FlutterError` / `FATAL EXCEPTION` / `ANR` / `E/flutter`; app stayed alive |

* **Not run**: `更新` activation (downloads an APK and starts the installer, so it needs the user's go-ahead), Quick Strip Hold-Select on the device, the M6 popup menu on the device, toast / loading on the device, and a real remote or HDMI-CEC sending separate Play and Pause keys.
* **Method notes for future live checks**: hold a key with `input keycombination -t <ms> KEYCODE_DPAD_CENTER KEYCODE_SHIFT_LEFT`; the emulator console `event send` did not deliver key events, and `input keyevent --longpress` is instantaneous. The HUD auto-hides after 5 s, so send each HUD key sequence in a single command. One mis-counted key press toggled a setting in the test install (the theme mode and a switch); both were cycled back to their original values and the test install is separate from the user's data.

---

### [2026-10-26] Milestone M10 (Task `M10.8`): Consolidation I — M6 Popup-Route Promotion on the Shared Focus-Layer Stack
* **Status**: ✅ Completed
* **Files Changed**:
  * `[MODIFY] lib/tv/tv_focus_layers.dart` (`_TvFocusLayer` becomes an abstract base class with `opened` / `promote` hooks; new `_RouteFocusLayer` and `_RouteFocusLayerProvider`)
  * `[MODIFY] lib/tv/tv_navigation.dart` (the two `showMenu(requestFocus: false)` promotion branches removed; provider registered below the overlay layer)
  * `[MODIFY] test/tv_navigation_test.dart` (one new test; no existing test touched)
  * `[MODIFY] docs/tv/PLAN.md`
  * `[MODIFY] docs/tv/PROGRESS.md`
* **Result**: `tv_navigation.dart` is `47` lines smaller (`54` removed, `7` added) and the popup-menu promotion is no longer a second copy of the lifecycle the overlay layer uses. Behavior is the same by construction and by test.
* **Gate** (from the plan: all existing M6 tests with unchanged assertions): met. The M6 popup test and every other existing test pass untouched. A mutation check (provider removed from the stack) makes the M6 test fail, so the migrated code is what the test exercises.
* **New test**: a `requestFocus: false` popup inside a dialog restores focus in LIFO order (menu → dialog control → page control). It fails without the provider.
* **Verification** (patches applied, then reverted):
  * `flutter analyze --no-pub lib/tv/ test/tv_navigation_test.dart test/tv_player_hud_test.dart`: `No issues found!`.
  * `flutter test --no-pub test/tv_navigation_test.dart test/tv_player_hud_test.dart`: `78/78` passed (`52` navigation, up from `51`, and `26` player HUD).
  * Not yet run on a TV device: batched into the final live pass after `M10.9`.

---

### [2026-10-26] Milestone M10 (Task `M10.9`): Per-Frame Sheet Cost (`R13`) and Typed Sheet Check (`R15`)
* **Status**: ✅ Completed for `R13` / `R15`. The migration of the M9 sheet bookkeeping onto the focus-layer stack, which `M10.9` also listed, is deferred (below).
* **Files Changed**:
  * `[MODIFY] lib/tv/tv_navigation.dart`
  * `[MODIFY] test/tv_navigation_test.dart` (one new test, `_VisitCounter` helpers; no existing test touched)
  * `[MODIFY] docs/tv/PLAN.md`
  * `[MODIFY] docs/tv/PROGRESS.md`
* **`R13`, measured**: with a frame scheduled on every pump, a zero-focusable sheet's subtree was walked `60` times in `60` frames before and `4` after. The M10.2 review's static claim holds; it only reproduces when frames are actually produced, as they are during playback.
* **Changes** (details in [`PLAN.md` → M10.9](./PLAN.md)): empty-probe guard (12 frames or a focus-tree size change); per-frame sheet inspection gated on sheet state; route poll from a per-scope cached route with no dependency on the focused widget (also used by `TvNavigationObserver.rememberFocusedNode`); `FocusScope.of` replaced by a no-dependency `_scopeOf` in the sheet code; typed `StandardBottomSheet` read (`R15`).
* **Test finding worth keeping**: `tester.pump` only runs a frame when one is scheduled, so tests of per-frame cost need something that keeps frames coming (a running progress indicator), otherwise they pass for the wrong reason.
* **Deferred, with reasons** (`PLAN.md` → M10.9): the `_InlineSheetFocusLayer` migration. Sheet occlusion is per slot, focus handling is non-modal (`userMovedFocus`), restoration happens when a sheet starts closing, and discovery is event-driven, so it needs `isClosing`, a `userMovedFocus` flag and slot-scoped occlusion on the layer interface and would rewrite the most timing-sensitive code for a structural gain only.
* **Verification** (patches applied, then reverted):
  * `flutter analyze --no-pub lib/tv/ test/tv_navigation_test.dart test/tv_player_hud_test.dart`: `No issues found!`.
  * `flutter test --no-pub test/tv_navigation_test.dart test/tv_player_hud_test.dart`: `79/79` passed (`53` navigation, up from `52`, and `26` player HUD). All M9 tests pass with unchanged assertions.
  * Not yet run on a TV device: batched into the final live pass.


---

### [2026-10-26] Milestone M10 (Task `M10.10`): Smaller Cleanups (`R14`, `R16`–`R20`, `R2`, `R3`, `R5` item 4)
* **Status**: ✅ Completed
* **Files Changed**:
  * `[MODIFY] lib/tv/tv_player_hud.dart` (`R3`, `R18`, `R19`)
  * `[MODIFY] lib/tv/tv_navigation.dart` (`R14`, `R2` doc, `R5` rename, `R20` constant)
  * `[MODIFY] lib/tv/tv_platform.dart` (`R16`, `R17`, `R2` dead seed key)
  * `[MODIFY] test/tv_player_hud_test.dart` (two new tests; the cadence test now drives the fake clock)
  * `[MODIFY] test/tv_navigation_test.dart` (five new tests; one existing seeding test edited)
  * `[MODIFY] docs/tv/PLAN.md`, `docs/tv/PROGRESS.md`, `docs/tv/ARCHITECTURE.md` (seeding wording), `docs/tv/README.md`, `docs/tv/README.en.md`, `README.md`, `README.en.md` (TV defaults and the `keyboardControl` dependency)
* **What changed** (details in [`PLAN.md` → M10.10](./PLAN.md)):
  * `R3` / `R18`: seek cadence on the binding's sampling clock; a direction change restarts the acceleration but keeps the virtual target.
  * `R19`: the HUD clock ticks at minute boundaries while the HUD stays open.
  * `R14`: one static frame callback forwards to the mounted `TvNavigation`; `dispose` releases the sheet-tracking state.
  * `R2` / `R5`: `onBack` documented as unused, the dead `'defaultFullScreen'` seed removed, `_TvVerticalFocusIntent` → `_TvArrowFocusIntent`.
  * `R16` / `R17`: the unread seeding marker is gone ("fills missing keys on every launch"), `keyboardControl: true` is seeded, and the HUD's dependency on that switch is documented.
  * `R20`: `TvNavigationObserver.loginQrTabIndex` plus a test that reads the upstream login page to pin the tab order.
* **Test findings worth keeping**:
  * The first `R19` test passed with the clock stopped, because the HUD auto-hid and reopened in the loop and so re-created the clock. Every new test was mutation-checked (the fix undone, the test must fail); this is the one that needed a second draft.
  * `testWidgets` runs on a fake clock that starts at a UTC instant. Code that builds a local `DateTime` from a UTC one (`DateTime(now.year, ..., now.minute + 1)` against `now`) gets a delay that is off by the machine's UTC offset; computing the delay from the sub-minute part avoids it.
  * The `R14` retention fix has no test of its own (see `PLAN.md`); the two lifecycle tests protect the forwarding logic around it.
* **Verification** (patches applied, then reverted):
  * `flutter analyze --no-pub lib/tv/ test/tv_navigation_test.dart test/tv_player_hud_test.dart`: `No issues found!`.
  * `flutter test --no-pub test/tv_navigation_test.dart test/tv_player_hud_test.dart`: `86/86` passed (`58` navigation, up from `53`, and `28` player HUD, up from `26`).
  * `./tool/tv_patch.sh status`: all patches `[NOT APPLIED]`.
  * Not yet run on a TV device: batched into the final live pass.

---

### [2026-10-26] Milestone M10 (Task `M10.11`): Documentation Sync, Final Device Pass & One Regression Fix
* **Status**: ✅ Completed. Milestone M10 is done.
* **Commits**: `9bb027680` (`ARCHITECTURE.md`), `75edded59` (`REVIEW.md`, READMEs), `3a169e16a` (regression fix, tests, `ARCHITECTURE.md` note), and the commit that carries this entry.
* **Files Changed**:
  * `[MODIFY] docs/tv/ARCHITECTURE.md`, `docs/tv/REVIEW.md`, `docs/tv/README.md`, `docs/tv/README.en.md`, `README.md`, `README.en.md`
  * `[MODIFY] lib/tv/tv_focus_layers.dart` (route layers only for `PopupRoute`s)
  * `[MODIFY] test/tv_navigation_test.dart` (two new tests)
  * `[MODIFY] docs/tv/PLAN.md`, `docs/tv/PROGRESS.md`
* **Device and build**: Android TV image (`arm64-v8a`, API 34, `1920×1080`) on the `<vm-tv>` emulator. Release-mode side-by-side builds (`com.lemontea.piliplus.tv.dev`) of the final tree, TV patches applied during each build and reverted straight after. The test install was uninstalled at the end; the existing installs were not modified.
* **The finding the pass was for**: the comment sheet on the video page regressed with `M10.8` (the ring went to the Quick Strip's `全屏` instead of into the sheet). Cause, fix and tests are in [`PLAN.md` → M10.11](./PLAN.md). In short: a page pushed over another page was recorded as a popup-style route layer for its whole lifetime, and the stack pulled focus to the page's first control whenever the sheet code parked focus on the scope node.
* **Verified live** (the checks marked "after the fix" ran on the fixed build; the others ran on the build before it and do not touch the changed code):

  | Check | Result |
  | :--- | :--- |
  | `设置 → 关于 → 当前版本` update dialog (before and after the fix) | Ring on `取消`; Right moves to `更新`; Up stays in the dialog; Back closes it and the ring returns to `当前版本` with the About page still open |
  | Settings popup menu `动态展示` (before and after the fix) | Opens with the ring on `全部`; Down moves to `投稿`; Back closes it, the ring returns to `动态展示` and the value is unchanged |
  | Comment sheet `评论详情` | **Before the fix: ring on `全屏` (regression), also on a second open.** After the fix: ring on `关闭`; Back restores the ring to the exact comment |
  | Fullscreen HUD | Opens on `暂停`; the media Pause key flips the label to `播放` and pauses (`R11` / `R12`) |
  | HUD clock (`R19`) | Stayed open for about 30 s across a minute boundary (D-pad activity every 3.5 s): `12:13` → `12:14` |
  | HUD `选集` dialog, after the fix | Opens with the ring on the current episode (4th of 25), `R10`; Back closes it |
  | App start, home, sidebar, `我的`, settings, route focus memory | Working; Back from settings put the ring on the gear again |
  | `adb logcat` over the fixed-build runs | `0` `FATAL EXCEPTION` / `E/flutter` / `FlutterError` / ANR |

* **Not run**: `更新` activation (it downloads an APK and starts the installer, so it needs the user's go-ahead); Quick Strip Hold-Select and the `R18` direction change on the device (covered by the unit tests); a real remote or HDMI-CEC sending separate Play and Pause keys; toast and loading overlays on the device.
* **Method notes for future live checks**:
  * The HUD auto-hides after 5 s without a key, so send every HUD key sequence in one command. From a hidden HUD, `退出全屏` is Up, Up, Up, Select.
  * `adb shell input keyevent` sends key down and key up together.
  * To trace a focus path on the device, add temporary `print` lines to a throwaway release build and read them with `adb logcat`; revert the sources afterwards. One log line per `requestFocus` call site (a private `FocusNode` extension used inside the cascades) found the culprit in two rebuilds.
  * Unit tests of focus handoff must keep frames coming (a spinner stands in for the video texture) and must put the trigger inside the covered body; `pumpAndSettle` hides this class of bug.
  * Do not run `dart format` on `tv_navigation.dart` or `test/tv_navigation_test.dart`: it rewrites unrelated lines.
* **Verification** (patches applied, then reverted):
  * `flutter analyze --no-pub lib/tv/ test/tv_navigation_test.dart test/tv_player_hud_test.dart`: `No issues found!`.
  * `flutter test --no-pub test/tv_navigation_test.dart test/tv_player_hud_test.dart`: `88/88` passed (`60` navigation, up from `58`, and `28` player HUD).
  * `./tool/tv_patch.sh status`: all patches `[NOT APPLIED]`. Privacy scan of the added lines: clean.
  * The rest of the suite (`test/utils`, `video_utils`, `thread_ripper`) has `2` failures, both in `test/utils/accounts/deleted_account_test.dart`, an upstream account-deletion test that imports nothing from the TV layer. `M10` changed no file under `lib/` outside `lib/tv/`.

---

### [2026-10-26] Milestone M10 (Task `M10.12`): Post-Implementation Review Fixes (`R21`–`R24`)
* **Status**: ✅ Completed
* **Files Changed**:
  * `[MODIFY] lib/tv/tv_focus_layers.dart` (`R22`, `R24`)
  * `[MODIFY] lib/tv/tv_player_hud.dart` (`R21`, `R23`)
  * `[MODIFY] test/tv_navigation_test.dart`, `test/tv_player_hud_test.dart`
  * `[MODIFY] docs/tv/PLAN.md`, `docs/tv/PROGRESS.md`, `docs/tv/REVIEW.md`
* **Findings and fixes** (details in [`PLAN.md` → Task M10.12](./PLAN.md)):
  1. `R21`: option-dialog rows are measured from the label's text style and scale instead of a fixed 52 px, so labels are not clipped at large font sizes.
  2. `R22`: text selection handles, toolbars and context menus (root overlay, under a `TextFieldTapRegion`) are no longer treated as modal overlay layers.
  3. `R23`: `mediaPlay` / `mediaPause` call the idempotent `play()` / `pause()` instead of toggling from a status that lags behind.
  4. `R24`: focus scopes are never overlay promotion targets, so a `FocusScope`-wrapped dialog no longer re-promotes every frame.
* **Verification** (patches applied, then reverted):
  * `flutter analyze --no-pub lib/tv test/tv_navigation_test.dart test/tv_player_hud_test.dart`: `No issues found!`.
  * `flutter test --no-pub test/tv_navigation_test.dart test/tv_player_hud_test.dart`: `92/92` passed.
  * With only the `lib/tv` changes reverted, all four new tests fail: `R21` on a clipped label (`23.6` px of `32` px), `R23` on a second toggle, `R24` on focus not reaching the button, and `R22` on the field's selection overlay already being gone (the selection handles share the toolbar's root overlay and `TextFieldTapRegion`).
  * `./tool/tv_patch.sh status`: all patches `[NOT APPLIED]`. Not verified on a device.

---

### [2026-10-26] Milestone M10 (Task `M10.13`): Fewer Upstream Merge Conflicts
* **Status**: ✅ Completed
* **Why**: the sync job's merge of `lemonteaau/PiliPlus` `774871080` conflicted in `.github/workflows/sync-upstream-build.yml` and `lib/utils/connectivity_utils.dart`. It was resolved by hand in `26e8781c8` (merge verified on Flutter `3.47.8`: all 38 patches apply, no analyzer errors in `lib`, TV tests `92/92`).
* **Files Changed**:
  * `[NEW] .github/workflows/tv-sync-build.yml`: the fork's workflow, unchanged except for its header comment, `name` (`Sync upstream and build PiliPlus TV`) and concurrency group (`tv-sync-build`).
  * `[MODIFY] .github/workflows/sync-upstream-build.yml`: restored to upstream's exact content and disabled in Actions (it syncs `bggRGjQaUbCoE/PiliPlus` and builds every platform).
  * `[MODIFY] lib/tv/tv_platform.dart`: `TvPlatform.isOnWifiOrEthernet()`.
  * `[MODIFY] lib/utils/connectivity_utils.dart`: one-line hook plus import; otherwise identical to upstream.
  * `[MODIFY] test/tv_navigation_test.dart`: Ethernet / Wi-Fi / mobile / none cases on TV.
  * `[MODIFY] docs/tv/README.md`, `README.en.md`, `REVIEW.md`, `ARCHITECTURE.md`, `PLAN.md`, `PROGRESS.md`.
* **Not avoidable by this change**: other fork hooks in upstream files (`lib/main.dart`, `player_focus.dart`) can still conflict when upstream rewrites the same lines.

---

## Detailed Task Log (Phase 5: Playback Stability, CI Checks, Focus Engine & Player HUD)

### [2026-10-26] Phase 5 Planning: Objectives Alignment for M11–M15
* **Status**: ✅ Completed (planning only; no code changed)
* **Branch**: `docs/tv-plan-m11-m15`, the first change made under Execution Rule 5.
* **Files Changed**:
  * `[MODIFY] docs/tv/PLAN.md` (Execution Rule 5, Phase 5 roadmap, Milestones M11–M15)
  * `[MODIFY] docs/tv/PROGRESS.md`
* **Inputs**: a review of the TV architecture and the player HUD (summarized below), then a question-and-answer session on four goals: a new focus engine, missing HUD functions with a refined layout, TV checks in CI, and the playback freeze on the physical TV.
* **Architecture review summary**:
  1. The three-tier isolation works (fewer than 30 lines across 5 upstream files under `lib/`), but the focus engine guesses intent from widget types and size ratios, picks targets with a first-match rule chain, and recovers focus from five entry points coordinated by flags. Each new upstream layout has needed new special cases (M6, M7, M9, M10).
  2. CI never ran analyze or the TV tests before releasing.
  3. The player HUD is a separate UI because upstream's player is built for a pointer and a keyboard-shortcut handler. It re-implements several upstream menus (its quality picker has already drifted from upstream's) and lacks subtitles, audio quality, decode format, super-resolution, AI translate, highlights, the danmaku chart and the settings sheet. Upstream's menus are reachable without upstream edits (`HeaderMixin`, `headerCtrKey`).
* **Answers**:

  | Topic | Answer |
  | :--- | :--- |
  | Upstream's own APK on the same TV | Not tried yet |
  | When the freeze started | Unknown: the M5 pass did not play the same videos |
  | Which videos freeze | Some, quality-related |
  | Debugging on the TV | Network adb from the development machine |
  | Most urgent goal | The playback freeze (M12) |
  | Shipping work in progress | Branches, release on merge; no pre-release APKs |
  | A failing CI check | Blocks the release; the checks also run on pull requests |
  | CI scope | TV tests and TV analyze |
  | Focus engine approach | Staged and parity-gated |
  | Returning to a column | Restore the last item focused there |
  | Focus problems seen on the TV | Odd jumps; a lost or missing ring; a laggy D-pad |
  | Where the D-pad lags | Everywhere |
  | HUD look | Upstream's layout and icons at TV size, with the focused button's label shown |
  | HUD menus | Upstream's own panels |
  | Live room | Video first, live later (M15) |
  | Old focus rules after the switch | Kept one release behind a hidden switch |

* **Consequences recorded in the plan**:
  * Device tests use local `-Pdev` release builds over network adb. Debug builds are not used for codec or performance work: they use a different hardware-decoding default and run Dart code much slower.
  * The recorded D-pad paths (M13.3) encode correct behavior, not today's, and M13 starts with an on-device baseline (M13.0) because the existing traversal benchmark was measured on a development Mac.
  * Ordering: M11 → M12 → M13 and M14 → M15. M11 runs while the device is prepared for M12; M14 can run alongside M13.1–M13.2.
* **Open inputs** (owner: user): the M12 device details and test videos; the list of screens with focus problems for M13.0; branch protection on `main` for M11.3; the M14.1 button-list discussion.

---

### [2026-10-26] Milestone M11 (Tasks `M11.1`–`M11.3`): TV Checks in CI
* **Status**: ✅ Completed (branch protection on `main` is a user action, below)
* **Branch**: `ci/tv-checks-m11`
* **Files Changed**:
  * `[NEW] .github/workflows/tv-checks.yml`: job `TV analyze and tests`. Triggers: `pull_request` into `main`, `workflow_call` (input `ref`, the commit to check) and `workflow_dispatch`. Steps: checkout, Flutter from `pubspec.yaml`, `lib/scripts/patch.ps1 android` (which also runs `flutter pub get`), `flutter analyze --no-pub --no-fatal-infos` on `lib/tv`, the three hook files and the two TV tests, then `flutter test --no-pub` on the TV tests. Read-only permissions; a newer push to a pull request cancels its older run, release runs are never cancelled. Before the tests it installs `libgtk-3-dev`, `libx11-dev` and `libxi-dev`: `flutter test` builds native assets for the Linux host, and the `cnativeapi` build hook runs `pkg-config` for `gtk+-3.0`, `x11` and `xi` (the first run on GitHub failed there, before any test ran; analyze had passed).
  * `[MODIFY] .github/workflows/tv-sync-build.yml`: new `checks` job calls `tv-checks.yml` with the sync job's `commit_sha`, alongside `android`; `release` needs `checks` and `android` and runs only when both succeeded. The release notes say the checks passed.
  * `[MODIFY] docs/tv/README.md`, `README.en.md`: the TV checks, the release gate and the branch-protection setting; the local sync guide uses the same analyze command as CI and pushes a branch for a pull request instead of pushing to `main` (Execution Rule 5); Flutter version corrected to `3.47.8`.
  * `[MODIFY] docs/tv/PLAN.md`, `PROGRESS.md`.
* **Design notes**:
  * Docs-only pull requests run the checks too: a required check that is skipped by a path filter would keep the pull request waiting forever.
  * The sync job pushes the version tag before the build (see the comment in `tv-sync-build.yml`), so a red check can leave a tag without a release. The update check reads releases, not tags, and the next run force-moves the tag, so this is harmless.
  * The hook files are the upstream files that import `package:PiliPlus/tv/...`: `lib/main.dart`, `lib/pages/video/widgets/player_focus.dart`, `lib/utils/connectivity_utils.dart`.
* **Verification** (locally, Flutter `3.47.8`, patches applied with `./tool/tv_patch.sh apply`, then reverted):
  * The workflow's analyze command: `No issues found!`.
  * The workflow's test command: `95/95` passed.
  * Both workflow files parse as YAML.
* **Verification on GitHub** (`M11.3`):
  * This branch's pull request: **TV analyze and tests** green (analyze `No issues found!`, `95 tests passed`).
  * A throwaway draft pull request on top of this branch, adding `test('M11.3 deliberate failure', () => expect(1, 2))` to `test/tv_player_hud_test.dart`: the check went red (`95 tests passed, 1 failed`), naming the deliberate test. Closed unmerged and its branch deleted. Without branch protection GitHub still reported it mergeable (`UNSTABLE`), which is why the protection setting below is needed.
  * `./tool/tv_patch.sh status`: all 38 patches `[NOT APPLIED]`.
  * Release run after merging pull request #2 (merge commit `97d87d90b`): `Build Android APKs` and `TV checks / TV analyze and tests` started together; analyze `No issues found!`, `95 tests passed`. The checks took about 11 minutes against the build's 7.5 (cold caches plus the `apt-get` step), and `Publish custom release` started only after both finished. Release `v2.1.6.2-fork.5799` was published with the three APKs, and its notes say `Checks passed: TV analyze and tests.`
* **Remaining (user action)**: GitHub → Settings → Branches → protect `main` and require `TV analyze and tests`; a failing pull request then shows as blocked instead of `UNSTABLE`.

---

### [2026-10-27] Milestone M12 (Tasks `M12.1`–`M12.2`, Device Session 1): Device Profile, Codec List and First Reproduction
* **Status**: `M12.1` ✅ Completed; `M12.2` 🔄 In Progress (the freeze is reproduced and its mechanism located; the remaining matrix needs a `-Pdev` build, below)
* **Branch**: `docs/tv-m12-device-profile` (docs and a device tool only; no app code changed)
* **Files Changed**:
  * `[NEW] tool/tv_codecs.sh`, `tool/tv_codecs/CodecDump.java`: print, over adb, every decoder that `MediaCodecList` reports on a device (the list the app sees) with the sizes, frame rates, performance points and profile/level pairs it claims. A small dex runs through `app_process`, so no app install and no root are needed. Added because third-party apps (AIDA64) don't show what an app's `MediaCodecList` returns.
  * `[MODIFY] docs/tv/README.md`, `README.en.md` (the tool), `docs/tv/PLAN.md`, `PROGRESS.md`.
* **Inputs from the user**: network adb to `<physical-tv>`; the freeze hits every video at 4K and above, 1080P60 is the highest quality that plays; upstream's own APK (`com.lemontea.piliplus`, build 5746) freezes and crashes the same way (driven over scrcpy, since it has no TV controls); two freezing videos, `BV1NGZtBwELa` and `BV1fiHN6zEfx`; `BV1kMxM6FECM` (4K) didn't freeze in this session but was very laggy with many artifacts on the panel. The account has 大会员, so 4K is offered. The TV build's playback settings are the defaults (`硬解模式` `mediacodec,auto-safe`, `视频同步` `display-resample`, codec order AVC then AV1, thread ripper on), checked on the device.
* **Device profile (`M12.1`)**:

  | Item | Value |
  | :--- | :--- |
  | Model | Hisense `SmartTV 4K FFM` (manufacturer HVCL, device `wutaishan`) |
  | SoC | MediaTek MT9690 (`ro.board.platform=merak`), 4 × Cortex-A73 (`CPU part 0xd09`) running a 32-bit userspace: `armeabi-v7a` only, no 64-bit ABI |
  | GPU | Mali (`ro.hardware.egl=mali.mt9690`), OpenGL ES 3.2 |
  | RAM | 3.7 GB, plus 1 GB swap; `dalvik.vm.heapgrowthlimit` 192 MB |
  | Android | 14 (API 34), kernel 5.15 |
  | Panel | 3840 × 2160 at 60 Hz, one display mode; the UI runs at an override of 1920 × 1080 (density 320). HDR types reported: Dolby Vision, HDR10, HLG, HDR10+ |
  | Video decoders (hardware) | `c2.mtk.avc`, `c2.mtk.hevc`, `c2.mtk.av1`, `c2.mtk.vp9`, plus MPEG-2/4, H.263, VP8, VC-1, AVS/AVS2, SHVC, MJPEG, five Dolby Vision decoders and secure variants. AVC, HEVC, AV1 and VP9 each claim up to 4096 × 2304, a `3840x2160@60` performance point and 60 fps at 3840 × 2160; HEVC lists Main, Main10, HDR10 and HDR10+, AV1 lists Main 8-bit and 10-bit with HDR10 and HDR10+ |
  | Video decoders (software) | `c2.android.*` for AVC, HEVC, AV1, VP8, VP9, MPEG-4, H.263 |

  * Consequence: the decoders *claim* every stream bilibili serves up to 4K60, so filtering streams by `MediaCodecList` alone (one of the M12.3 directions) would not have excluded the freezing streams.
* **Evidence already on the device**:
  * The system dropbox holds 14 ANR reports for the app between 2026-10-24 and 2026-10-27: TV builds 5745 (5), 5762 (4) and 5793 (2), and upstream's build 5746 (3). All 14 have the same shape: the Android main thread (which runs Dart since Flutter merged the UI and platform threads) waits on a condition variable inside `libmpv.so` at the same offset (`+0x307c84`, not an exported symbol; the shipped `libmpv.so` has no symbol table), while the decoding thread sits in `MediaCodec.dequeueOutputBuffer`. `ApplicationExitInfo` records these exits as ANR kills (`Input dispatching timed out`, about 5 s after a key or touch event); none was a low-memory kill. So the "crash" is an ANR, the same in upstream's APK and ours.
* **Live reproduction (`M12.2`, session 1)** — installed TV release build 5799, default settings, logcat plus CPU and memory every 3 s:

  | Video | Stream | Result |
  | :--- | :--- | :--- |
  | `BV1kMxM6FECM` | 4K 59.94 fps AVC (`c2.mtk.avc.decoder`, 3840 × 2160; first recorded here as 29.97 fps, corrected in session 2) | Kept playing for 5+ minutes, including seeks and the HUD; about 21.5 of 60 frames per second reached the renderer (2–27 per second). The user saw heavy lag and many artifacts on the panel. CPU 0.7–2 cores of 4, graphics memory about 200 MB |
  | `BV1NGZtBwELa` | 4K 29.97 fps AVC | Opened over the previous video: froze after about 10 s |
  | `BV1fiHN6zEfx` | 4K 59.94 fps AVC | Fresh process: first frame decoded, then frozen about 3 s later; only 2 frames reached the renderer. Same result a second time with `视频同步` set to `audio` (setting restored afterwards) |

  * **What the freeze is**: from the moment the picture stops, the codec HAL logs `C2BqBuffer: last successful dequeue was … us ago, … consecutive failures` every 5 s, and the count only grows (still failing 230 s later). The hardware decoder can no longer get an output buffer back from the surface it decodes into, so no new frame is produced; the app's CPU drops to about 5 %. It never recovers on its own: after leaving the page, the shared player keeps the stalled decoder, and the next video opens with a black player. The main thread stayed responsive in these runs; the ANRs on record come from a later Dart call that needs mpv's core while that core is stuck in the decoder.
  * **The output path that stalls** (`hwdec=mediacodec`, media_kit's default `vo=gpu` on Android): MediaCodec decodes in surface mode into an `AImageReader` (mpv's `hwdec_aimagereader`; the reader thread is named `ImageReader-16x16f22u256m5`, i.e. at most 5 images); mpv's video-output thread imports each frame into GLES, and on this SoC every 4K frame goes through MediaTek's `Detile` step inside our process (`is_tiled_yuv: 1`, logged once per frame); mpv renders into a `SurfaceTexture` that media_kit sizes to the video (`android-surface-size` 3840 × 2160); Flutter then composites that texture into its 1920 × 1080 UI.
  * **Side finding**: opening a video while another is loaded makes Android's `ResourceManagerService` reclaim the app's own hardware decoder (`MediaCodec::reclaim … Released by resource manager`), and short-lived 4K decoders open in ByteBuffer (copy) mode, which the MediaTek driver rejects (`mtk_vcodec_unsupport=1`, `VIDIOC_STREAMON failed`). This is a likely source of the `无法加载解码器 … 可能会切换至软解` toast; not yet confirmed.
* **Hypothesis update** (for `M12.3`):
  * Refuted: "the hardware decoder can't open 4K, mpv falls back to software decoding, and the CPU starves". The hardware decoder opens and decodes 4K AVC; the freeze happens with the CPU nearly idle; free memory stayed around 850 MB during the stalls. (During upstream's ANR at 15:43 the TV was short of memory, 231 MB available and swap full, but the same stall happens without that.)
  * New leading hypothesis: at 4K, the path from decoder output back to the decoder (`AImageReader` → mpv's GLES import with detiling → 4K render target → Flutter) is too slow on this SoC, and at some point every output buffer is held on the consumer side while mpv's core waits inside the decoder for a new frame: a deadlock that only a process restart clears. `video-sync` is not the trigger (same with `audio`).
* **Next (rest of `M12.2`)**, with an uncommitted `-Pdev` build and mpv logging at `v` sent to logcat (the dev build installs next to the normal app, so it needs a QR login for 4K):
  1. mpv's own log around the stall: which frames the decoder and the video output hold.
  2. `vo=mediacodec_embed` (MediaCodec renders straight into Flutter's surface: no `AImageReader`, no GLES import or detiling in our process; mpv then can't draw subtitles or run shaders).
  3. The render target capped at 1920 × 1080 instead of the video's size.
  4. `hwdec=mediacodec-copy` and `no` at 4K, and HEVC and AV1 at 4K (only AVC was tested).
  5. 1080P60 for 10 minutes as the known-good baseline on the same videos.
* **Open inputs** (owner: user): a QR login on the `-Pdev` build when the instrumented runs start.

---

### [2026-10-27] Milestone M12 (Task `M12.2`, Device Session 2): Instrumented Dev Build, the Deadlock Traced, and the 4K Matrix
* **Status**: 🔄 In Progress. The freeze's mechanism is traced to the buffer level and one output path avoids it at every 4K codec; `<physical-tv>` rebooted by itself at the end of the last run, and that reboot is not yet explained.
* **Branch**: `docs/tv-m12-device-profile` (docs only; the instrumentation below is not committed)
* **Build**: a `-Pdev` release build (`ORG_GRADLE_PROJECT_dev=true flutter build apk --release --target-platform android-arm`, TV patches applied for the build and reverted straight after) with uncommitted instrumentation in `lib/plugin/pl_player/controller.dart`: mpv's log is printed to logcat at a chosen level; a text file in the app's external files dir (`Android/data/com.lemontea.piliplus.tv.dev/files/`, writable over adb) overrides `vo`, `hwdec` and any mpv option for the next player, can cap the `vo=gpu` render target, and turns on a readout of mpv's frame counters every 2 s. The user signed the dev app in with the app's own 设置 → 关于 → 导出/导入登录信息; the dev app's default quality was set to 4K and its codec preference changed per run. The user's normal app was not touched in this session.
  * Lesson: marking the dev build type debuggable (to get `run-as` and `debuggerd`) makes Flutter's Gradle plugin build in debug mode: no `libapp.so`, Dart in JIT, and the debug `hwdec` default. The first build did this and was caught before installing; the dev build must stay non-debuggable.
* **The deadlock, from mpv's and FFmpeg's trace log** (`BV1fiHN6zEfx`, 4K60 AVC, default `vo=gpu`):
  1. At 4K the decoder exposes 5 output buffers (indices 0–4). At 1080p no MediaTek `Detile` step runs at all; at 4K every buffer is tiled, and the decoder decodes straight into these buffers, which also serve as its reference frames.
  2. After the resume seek, mpv renders 2 frames (`Releasing output buffer … with render=1`), drops 1, and keeps 2 decoded frames pending while it waits for the next one.
  3. From then on FFmpeg only logs `No output buffer available, try again later`, and 1.5 s later the codec HAL starts logging `C2BqBuffer … consecutive failures`. Only 2 frames are ever rendered.
  4. So it's a circular wait. The decoder needs a free buffer, but 4 of its 5 are held outside it: the 2 rendered ones by the `AImageReader` and mpv's GLES import, the 2 pending ones in mpv's queue. mpv won't render the pending frames before the decoder delivers another one.
  * Not the trigger: `video-latency-hacks=yes` (mpv queues fewer frames) still deadlocks the same way; capping the `vo=gpu` render target at 1920 × 1080 still deadlocks (before the cap even applies); `video-sync=audio` (session 1).
  * With `vo=gpu`, mpv's image-reader path imports every frame anew (one MediaTek `Detile` per frame in our process); with `vo=mediacodec_embed`, `Detile` runs about 8 times per run, once per buffer. That per-frame import is why 4K was laggy even when it didn't deadlock.
* **Matrix** (dev build, about 60 s each; dropped frames from mpv's `frame-drop-count`; "deadlock" means the picture froze within seconds and `C2BqBuffer` failures kept growing):

  | Video | Stream | `vo=gpu` (default) | `vo=mediacodec_embed` |
  | :--- | :--- | :--- | :--- |
  | `BV1fiHN6zEfx` | 4K 59.94 fps AVC | Deadlock (5 runs) | Plays; 115 dropped in about 50 s (3.8 %) |
  | `BV1kMxM6FECM` | 4K 59.94 fps AVC | Deadlock at the resume position (limped along at about 21 fps in session 1) | Plays; 87 dropped in 60 s (2.4 %) |
  | `BV1NGZtBwELa` | 4K 29.97 fps AVC | Deadlock (session 1) | Plays; 0 dropped in 58 s |
  | `BV1fiHN6zEfx` | 4K 59.94 fps HEVC (`c2.mtk.hevc.decoder`) | Deadlock | Plays; 482 dropped in 56 s (14 %) |
  | `BV1fiHN6zEfx` | 4K 59.94 fps AV1 (`c2.mtk.av1.decoder`) | Deadlock | Played 40 s, 189 dropped (7.8 %); then the TV rebooted (below) |
  | `BV1fiHN6zEfx` | 1080P60 AVC | Plays; 69 dropped in 60 s (1.9 %) | Plays; 6 dropped in 54 s (0.2 %) |
  | `BV1fiHN6zEfx` | 1080p 29.97 fps AVC (logged out) | Plays; no `Detile`, no `C2BqBuffer` failures | Plays |

  * `hwdec=mediacodec-copy` at 4K60 AVC: the decoder opens in ByteBuffer mode and never deadlocks, but copying 4K frames through the CPU is far too slow (the picture changed about 3 times in 45 s, at 1–3.5 cores). Not an option.
* **TV reboot**: at about 17:35, after 40 s of 4K60 AV1 with `vo=mediacodec_embed`, the TV rebooted by itself (confirmed by the user). Logcat stops mid-stream at 17:34:59 with no shutdown, sleep or Wi-Fi messages. Wireless debugging gets a new port after a reboot, so the boot reason (`sys.boot.reason`, the last kernel log and dropbox entries) is not read yet. Until it is, 4K AV1 on this path counts as unsafe.
* **What this means for `M12.3`**:
  * The freeze is not a decoder capability problem and not CPU starvation. It's a buffer deadlock between MediaTek's tiled 4K output and mpv's `vo=gpu` image-reader path, which media_kit uses by default on Android, so upstream's APK has it too.
  * Candidate fix: `vo=mediacodec_embed` for TV playback (`VideoControllerConfiguration(vo: 'mediacodec_embed', hwdec: 'mediacodec')`). It removes the deadlock at every 4K codec tested and is also smoother at 1080P60. Costs to check: mpv's GLSL shaders (super-resolution, `超分辨率`) can't run; subtitles should be unaffected because PiliPlus draws them in Flutter (`SubtitleView`), to be verified; screenshots and the `video-rotate` option need checking; the AV1 reboot needs explaining first.
  * Other options to weigh: a 1080P60 quality cap as the TV default (safe, loses 4K); a stall watchdog that reloads at a lower quality when `time-pos` stops moving while playing; preferring AVC at 4K (fewest drops).
* **Next**: read the boot reason once adb is back; repeat 4K60 AV1 with `mediacodec_embed` to see if the reboot reproduces (and AVC for a longer stretch, 10+ minutes); check subtitles, danmaku and the HUD with `mediacodec_embed`; then the `M12.3` write-up and decision.
