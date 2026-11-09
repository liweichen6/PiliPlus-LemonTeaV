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

### Phase 5: Playback Stability, CI Checks, Focus Engine & Player HUD (Milestones M11–M17) — In Progress

| Milestone | Epic | Task ID | Task Title | Status | Target / Commit |
| :--- | :--- | :--- | :--- | :--- | :--- |
| **M11: TV Checks in CI** | Epic M11.1 | `M11.1` | TV Checks Workflow (`tv-checks.yml`: Patches, TV Analyze, TV Tests) | ✅ Done | `.github/workflows/tv-checks.yml` (`169a7434a`, `5b1168331`) |
| **M11: TV Checks in CI** | Epic M11.1 | `M11.2` | Release Gate in `tv-sync-build.yml` | ✅ Done | `.github/workflows/tv-sync-build.yml` (`169a7434a`) |
| **M11: TV Checks in CI** | Epic M11.1 | `M11.3` | Verification (a Failing Test Blocks Merge and Release) & Docs | ✅ Done (branch protection on `main` is a user action) | `docs/tv/*` (`4e4284b05`, `64c0b6983`); branch protection on `main` (user) |
| **M12: Playback Freeze on the Physical TV** | Epic M12.1 | `M12.1` | Device Profile (Model, SoC, RAM, Android, Decoder Capabilities) | ✅ Done | `<physical-tv>`, `tool/tv_codecs.sh` |
| **M12: Playback Freeze on the Physical TV** | Epic M12.1 | `M12.2` | Reproduction Matrix (Quality × Codec × Hardware Decoding × Thread Ripper; Upstream APK) | ✅ Done (two device sessions; thread ripper and software decoding not run, see the session 2 entry) | `<physical-tv>` |
| **M12: Playback Freeze on the Physical TV** | Epic M12.2 | `M12.3` | Root Cause & Fix Decision (Discussion Gate) | ✅ Decided: option A now, option G in M16, option F in M17 | `docs/tv/PLAN.md`, `docs/tv/PROGRESS.md`, `docs/tv/M12_CRASH_DEBUG.md` |
| **M12: Playback Freeze on the Physical TV** | Epic M12.2 | `M12.4` | Fix & Regression Tests | ✅ Done | `lib/tv/tv_platform.dart`, `test/tv_navigation_test.dart` (`25d0fa1e0`, `6004fa425`), `README.md`, `README.en.md` (`ed9bfea4d`) |
| **M12: Playback Freeze on the Physical TV** | Epic M12.3 | `M12.5` | Device Verification & Docs | ✅ Done (on `v2.1.6.2-fork.5870`) | `<physical-tv>`, `<vm-tv>`, `docs/tv/*` |
| **M16: 4K on the Video Plane** | Epic M16.1 | `M16.1` | Spike (Go/No-Go) | ✅ Done (go) | `-Pdev` build, `<physical-tv>`, `docs/tv/PLAN.md` (`b2c806ab1`) |
| **M16: 4K on the Video Plane** | Epic M16.2 | `M16.2` | Setting, `SurfaceView`, Hooks & Tests | ✅ Done | `lib/tv/tv_video_plane.dart`, `TvVideoPlane.kt`, `test/tv_video_plane_test.dart` (`04c52812b`) |
| **M16: 4K on the Video Plane** | Epic M16.2 | `M16.3` | Device Pass & Docs | ✅ Done (the media service hang stays an open risk) | `<physical-tv>`, `docs/tv/*` (`0744f0078`, `549916e58`) |
| **M16: 4K on the Video Plane** | Epic M16.3 | `M16.4` | Split Into the PiliPlus TVP Variant | ✅ Done on `variant/4k-passthrough` (the first CI build passed; that APK isn't checked on the TV yet) | `docs/tv/4K_VARIANT.md`, `docs/tv/PLAYBACK_PARAMETERS.md`, `.github/workflows/tv-variant-build.yml` (`c5097d7e1`, `fa35edb2f`) |
| **M13: Focus Engine** | Epic M13.0 | `M13.0` | Baseline on the TV (Step Time, Frame Times) & Focus-Bug Inventory | ✅ Done (released in `v2.1.6.2-fork.5889`; the inventory stays open for more bugs) | `<vm-tv>`, `<physical-tv>`, `docs/tv/M13_BASELINE.md`, `tool/tv_m13/` |
| **M13: Focus Engine** | Epic M13.0 | `M13.0a` | Fix Bug 1: Scroll Every List Level | ✅ Done | `lib/tv/tv_navigation.dart`, `test/tv_navigation_test.dart`, `<vm-tv>` |
| **M13: Focus Engine** | Epic M13.0 | `M13.0b` | Fix Bug 5: Reveal Cut-Off Cards in Rows | ✅ Done | `lib/tv/tv_navigation.dart`, `test/tv_navigation_test.dart`, `<vm-tv>` |
| **M13: Focus Engine** | Epic M13.1 | `M13.1` | Adapters for Upstream-Specific Knowledge (No Behavior Change) | ✅ Done | `lib/tv/adapters/`, `lib/tv/tv_navigation.dart`, `lib/tv/tv_focus_layers.dart`, `tool/tv_m13/logging.patch` |
| **M13: Focus Engine** | Epic M13.1 | `M13.1a` | Tests for What the Adapters Carry | ✅ Done | `test/tv_navigation_test.dart` |
| **M13: Focus Engine** | Epic M13.1 | `M13.2` | One Event-Driven Reconcile Loop; Inline Sheets on the Layer Stack | ✅ Done | `lib/tv/tv_navigation.dart`, `lib/tv/tv_focus_layers.dart`, `lib/tv/adapters/tv_sheet_adapter.dart`, `lib/tv/adapters/tv_focus_adapter.dart`, `tool/tv_m13/logging.patch` |
| **M13: Focus Engine** | Epic M13.2 | `M13.3` | Recorded D-Pad Paths for Key Screens | ✅ Done (13 known failures, for bugs 2–4 and 6–10, until M13.4) | `test/tv_paths_test.dart`, `test/tv_path_harness.dart`, `test/tv_player_hud_test.dart`, `.github/workflows/tv-checks.yml`, `docs/tv/M13_BASELINE.md` |
| **M13: Focus Engine** | Epic M13.2 | `M13.4` | Scoring Function & Column Memory Behind a Flag | ✅ Done (bugs 2–4 and 6–10 fixed under the flag; `decide` p90 on `<physical-tv>` 4.28 ms on home, 2.95 ms in settings, a little slower than the rule chain and inside the 6 ms limit) | `lib/tv/tv_focus_scorer.dart`, `lib/tv/tv_navigation.dart`, `test/tv_paths_test.dart`, `test/tv_path_harness.dart`, `.github/workflows/tv-checks.yml` |
| **M13: Focus Engine** | Epic M13.3 | `M13.5` | Switch, with the Old Rules Behind a Hidden Switch for One Release | ✅ Done (the scorer is the default; its extra cost is gone on settings and on like-for-like home steps on `<physical-tv>`; the bench meets four of six budget limits and misses `decide` on comments, for `M13.5a`) | `lib/tv/tv_focus_scorer.dart`, `lib/tv/tv_navigation.dart`, `lib/tv/tv_platform.dart`, `test/tv_paths_test.dart`, `test/tv_navigation_test.dart`, `.github/workflows/tv-checks.yml`, `docs/tv/*` |
| **M13: Focus Engine** | Epic M13.3 | `M13.5a` | Make the Shared Candidate Walk Cheaper on the Comments List | ✅ Done (closed after one attempt by the user's decision; memoizing render-object work was 20 % slower on `<physical-tv>` and was reverted; `decide` on comments still misses the budget) | `lib/tv/tv_navigation.dart`, `<physical-tv>` |
| **M13: Focus Engine** | Epic M13.3 | `M13.6` | Remove the Old Rules | ✅ Done (rule chain, hidden switch and CI's second run removed; every remaining decision unchanged; 153 TV tests pass; released in `v2.2.0.2-fork.5962`) | `lib/tv/tv_navigation.dart`, `lib/tv/tv_focus_scorer.dart`, `lib/tv/tv_platform.dart`, `test/tv_*.dart`, `.github/workflows/tv-checks.yml` |
| **M14: Player HUD, Video** | Epic M14.1 | `M14.1` | Button List (Discussion Gate) | ✅ Done (approach 1; the editor's layout is agreed separately, before `M14.3`) | `docs/tv/PLAN.md` |
| **M14: Player HUD, Video** | Epic M14.2 | `M14.2` | Actions & Upstream's Panels | ✅ Done (merging the pull request publishes a release) | `lib/tv/tv_hud_actions.dart`, `lib/tv/tv_player_hud.dart`, `lib/tv/tv_platform.dart`, `test/tv_player_hud_test.dart` (`1c9cf8f12`) |
| **M14: Player HUD, Video** | Epic M14.2 | `M14.3` | Layout, Editable Groups & Editor | ✅ Done (the editor's design agreed 2026-11-07; released in `v2.2.0.2-fork.5998`; the changes after the first device try land by their own pull request, and merging it publishes a release) | `lib/tv/tv_player_hud.dart`, `lib/tv/tv_hud_actions.dart`, `lib/tv/tv_hud_groups.dart`, `lib/tv/tv_hud_menu.dart`, `test/tv_player_hud_test.dart` |
| **M14: Player HUD, Video** | Epic M14.3 | `M14.4` | Tests, Device Pass & Docs | ✅ Done (M14 closed 2026-11-07; merging the pull request publishes a release) | `test/tv_player_hud_test.dart`, `lib/tv/tv_player_hud.dart`, `<vm-tv>`, `<physical-tv>`, `docs/tv/*` |
| **M15: Player HUD, Live** | Epic M15.1 | `M15.1` | Button List & Tasks (Discussion Gate) | ✅ Done (agreed 2026-11-08) | `docs/tv/PLAN.md` |
| **M15: Player HUD, Live** | Epic M15.2 | `M15.2` | Close a SuperChat | ✅ Done (the user's try on `<physical-tv>` 2026-11-08; merged) | `lib/tv/tv_player_hud.dart`, `LiveRoomController.fsSC`, `test/tv_player_hud_test.dart` |
| **M15: Player HUD, Live** | Epic M15.2 | `M15.3` | Live Entries & Groups | ✅ Done (merged) | `lib/tv/tv_hud_actions.dart`, `lib/tv/tv_hud_groups.dart`, `lib/tv/tv_hud_menu.dart`, `lib/tv/tv_player_hud.dart`, `test/tv_player_hud_test.dart` |
| **M15: Player HUD, Live** | Epic M15.3 | `M15.4` | Tests, Device Pass & Docs | ⏳ Planned | `test/tv_player_hud_test.dart`, `<vm-tv>`, `<physical-tv>`, `docs/tv/*` |
| **M17: ExoPlayer for HDR and Dolby Vision** | Epic M17.1 | `M17.1` | F1 Spike | ⏳ Planned (later) | `-Pdev` build, `<physical-tv>` |
| **M17: ExoPlayer for HDR and Dolby Vision** | Epic M17.1 | `M17.2` | F2 TV-Only Player | ⏳ Planned (later) | Decided at the start of M17 |

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
* **Status**: 🔄 In Progress. The freeze's mechanism is traced to the buffer level and one output path avoids it at every 4K codec, but 4K60 on that path panicked the TV's kernel three times (below).
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
* **TV reboot**: at about 17:35, after 40 s of 4K60 AV1 with `vo=mediacodec_embed`, the TV rebooted by itself (confirmed by the user). Logcat stops mid-stream at 17:34:59 with no shutdown, sleep or Wi-Fi messages. After reconnecting (wireless debugging gets a new port after a reboot):
  * `sys.boot.reason` is `kernel_panic,miup_hit_panic[cid:0xe000 …]`. The previous boot's kernel log (dropbox `SYSTEM_LAST_KMSG`) shows the memory-protection unit catching hardware client `CID 0xE000` reading a protected address (`[MIUP][HIT][CID:0xE000 read address: 0x1C3C5FD80 - 0x1C3C5FD9F block:24`), then `System Panic`. The panic notifiers that report it include the picture-quality driver (`pq_panic_notify`) and the AI accelerator driver (`[MDLA][MIUP]`). At that moment the decoder held 11 frame buffers of 15.6 MB for the stream (`vdec_fb`, owner `vid234.deque`).
  * The kernel had been up for 542,051 s (about 6.3 days): the TV survived all earlier freezes and ANRs without a reboot, and this was the first kernel panic in that time.
  * An app can't cause a memory-protection hit by itself; this is a fault inside the TV's video or picture-quality pipeline that our output path triggered once.
  * **Repeat** (with the user's go-ahead, accepting another reboot): the same video, 4K60 AV1 with `vo=mediacodec_embed`. The 2-minute measurement window saw 115 s of playback, 706 frames dropped (10.2 %), no `C2BqBuffer` failures and no panic, and was first recorded here as "doesn't reproduce". That was wrong: the run script didn't stop playback when the window ended, the stream kept playing, and the TV panicked again about 3 min 10 s into playback (kernel uptime 788.6 s, about 17:51:10). Same signature: `miup_hit_panic`, client `CID 0xE000`, block 24 (read address `0x1C3EAE200`), the same 11 decoder buffers of 15.6 MB. The run script now force-stops the dev app at the end of every run.
  * So 4K60 AV1 on `vo=mediacodec_embed` panicked the TV in both sessions it was played in, after about 40 s and about 190 s.
  * **10-minute 4K60 AVC run** (with the user's go-ahead, accepting a reboot; `BV1kMxM6FECM`, codec preference AVC only): 141 s of playback with 104 frames dropped (1.2 %) and no `C2BqBuffer` failures, the smoothest 4K run so far. Then the TV panicked about 2.5 minutes in (kernel uptime 435.5 s, about 17:58:45) with the same signature: `miup_hit_panic`, `CID 0xE000`, block 24 (read address `0x1C3BFD500`).
  * Three panics, all at 4K60 on `vo=mediacodec_embed` (AV1 twice, AVC once), after 40 s, 190 s and 150 s of playback. The shorter runs on this path (4K30 AVC, 4K60 HEVC, 1080P60, about a minute each) didn't panic, which doesn't show they're safe. With `vo=gpu`, 4K deadlocks within seconds, so that path never played 4K long enough to compare; the user's normal app ran for 6.3 days without a panic, through all the earlier freezes.
* **What this means for `M12.3`**:
  * The freeze is not a decoder capability problem and not CPU starvation. It's a buffer deadlock between MediaTek's tiled 4K output and mpv's `vo=gpu` image-reader path, which media_kit uses by default on Android, so upstream's APK has it too.
  * Candidate fix: `vo=mediacodec_embed` for TV playback (`VideoControllerConfiguration(vo: 'mediacodec_embed', hwdec: 'mediacodec')`). It removes the deadlock at every 4K codec tested and is also smoother at 1080P60. Costs to check: mpv's GLSL shaders (super-resolution, `超分辨率`) can't run; subtitles should be unaffected because PiliPlus draws them in Flutter (`SubtitleView`), to be verified; screenshots and the `video-rotate` option need checking; but 4K60 on this path panicked the TV's kernel three times (AV1 twice, AVC once) within minutes, so it is not a fix for 4K on this TV.
  * Other options to weigh: a 1080P60 quality cap as the TV default (safe, loses 4K); a stall watchdog that reloads at a lower quality when `time-pos` stops moving while playing; preferring AVC at 4K (fewest drops).
* **Next**: the `M12.3` write-up and decision. 4K is not playable on this TV with either mpv output path: `vo=gpu` deadlocks within seconds, `vo=mediacodec_embed` crashes the TV within minutes. 1080P60 played cleanly on both paths in short runs, so a 1080P60 cap on TV is the leading candidate; a long 1080P60 run on the chosen path belongs in `M12.5`.

---

### [2026-10-27] Milestone M12 (Task `M12.3`): Root-Cause Summary and Fix Options (Proposal)
* **Status**: 🔄 Proposal written; the fix and the "done" bar wait for the user's decision (discussion gate). No code changed.
* **Branch**: `docs/tv-m12-device-profile`
* **Files Changed**: `[MODIFY] docs/tv/PLAN.md` (Task M12.3: root cause, options A–E, recommendation, proposed "done" bar), `docs/tv/PROGRESS.md`.
* **`M12.2` closed**: the matrix ran quality (4K60, 4K30, 1080P60, 1080p30) × codec (AVC, HEVC, AV1) × output (`vo=gpu`, `vo=mediacodec_embed`) × hardware decoding (`mediacodec`, `mediacodec-copy`), plus upstream's APK (from the user and the ANR reports). Not run: thread ripper off and software decoding. The stall happens with data already buffered (the demuxer keeps reading), so the download path doesn't matter; and software decoding at 4K would be slower than `mediacodec-copy`, which already manages only a few frames per minute.
* **Summary**: two faults, both only at 4K and above on this MediaTek TV. (1) The reported freeze is a buffer deadlock between MediaTek's tiled 4K decoder output and media_kit's default `vo=gpu` path; the ANR follows when Dart waits on mpv's stuck core. (2) The alternative `vo=mediacodec_embed` path avoids the deadlock but triggers a firmware kernel panic within minutes at 4K60. So 4K can't play on this TV either way, while 1080P60 plays on both paths.
* **Recommendation**: option B in `PLAN.md`: a 1080P60 TV default, plus a hard cap at 1080P60 on MediaTek TV SoCs (detected through `TvBridge`), applied before the stream is picked and in the HUD's quality dialog; other TVs keep 4K. Keep `vo=gpu`.
* **Housekeeping**: the instrumentation stays uncommitted (saved as a patch outside the repository for the `M12.5` runs); the working tree is clean. The `PiliPlus TV dev` app is still installed on `<physical-tv>` and signed in through the app's login import; it should be uninstalled when M12 is done.


---

### [2026-10-29] Milestone M12 (Task `M12.3`): Option F Added, ExoPlayer for HDR and Dolby Vision
* **Status**: 🔄 Still awaiting the user's decision; option F added at the user's request. No code changed.
* **Branch**: `docs/tv-m12-device-profile`
* **Files Changed**: `[MODIFY] docs/tv/PLAN.md` (Task M12.3: option F), `docs/tv/PROGRESS.md`.
* **Question**: the user asked how much work a second player, ExoPlayer, would take so that HDR and Dolby Vision can play.
* **Findings from the code**: the app already requests HDR, Dolby Vision, 4K and 8K streams (`fnval` 4048 in `lib/http/video.dart`), and the panel reports Dolby Vision, HDR10, HLG and HDR10+ (M12.1). Today mpv renders into a texture that Flutter composites in SDR, so HDR reaches the panel at best tone-mapped. Only a `SurfaceView`, which gets its own hardware layer, can carry HDR to the panel; ExoPlayer through a Flutter `Texture` would still be SDR and is in effect the `vo=mediacodec_embed` path that panicked the kernel. The player is tied to media_kit in `lib/plugin/pl_player/controller.dart` (player creation, the `edl://` merge of video and audio, mpv options) and about 15 other files use media_kit or the player directly; mpv-only features are the GLSL shaders (`超分辨率`), audio normalization (`lavfi-complex`), `video-rotate` and screenshots.
* **Proposal**: F1, a 1–2 day spike on `<physical-tv>` (go/no-go on the kernel panic, HDR and Dolby Vision), then F2, an opt-in ExoPlayer for videos on TV only (about 9–13 days). Independent of B: B can ship first, and F2 would lift B's cap whenever ExoPlayer plays the video.
* **Open input** (owner: user): the five-minute check with another app on the TV (for example 云视听小电视) at 4K60 and 杜比视界.

---

### [2026-10-29] Milestone M12 (Task `M12.3`): Option F, Prior Work in PiliPlus Forks
* **Status**: 🔄 Still awaiting the user's decision. Research only; no code changed.
* **Branch**: `docs/tv-m12-device-profile`
* **Files Changed**: `[MODIFY] docs/tv/PLAN.md` (option F: prior work, F1 and F2 based on it, costs), `docs/tv/PROGRESS.md`.
* **Method**: read upstream PR 2145 (`gh pr view`, `gh pr diff`); fetched the Android build file of each of the 660 upstream forks pushed to since they were made and looked for Media3 or ExoPlayer (five hits); searched repositories and code for PiliPlus derivatives with HDR, ExoPlayer or TV work; read each hit's player code.
* **Findings** (details in `PLAN.md`, option F):
  * Upstream PR 2145 (an HDR-only Media3 player: `PlayerView` in a platform view, `MergingMediaSource`, `COLOR_MODE_HDR`) was closed unmerged on 2026-07-02 without a comment. Upstream's HDR issues were closed as not fixable.
  * `kkren/PiliPlus` has a Media3 option for every video on the same approach, the same thread-ripper proxy as this fork, and armeabi-v7a APKs: the closest base for F. `AvalonUltra/PiliPlus` keeps PR 2145's Kotlin merged with upstream.
  * `yifgu/PiliPlus` plays Dolby Vision Profile 5 only through a real Dolby Vision decoder; its codec check suggests Bilibili's 杜比视界 is Profile 5, which mpv can't show correctly.
  * `loneshu7/PiliPlusPlus` and `ws2bhhh/PiliPlus-mod` draw Media3 through a Flutter texture (no real HDR); loneshu7's has Media3 versions of audio normalization and super-resolution.
  * `chenx-dust/PiliPlus` keeps mpv and draws `vo=mediacodec_embed` into a `SurfaceView` platform view: HDR10, not Dolby Vision Profile 5.
  * None of them was tested on a TV, and all HDR-capable ones use Hybrid Composition for the `SurfaceView`.
* **Consequences for option F**: F1 adapts kkren's and PR 2145's Kotlin plus yifgu's Dolby Vision decoder rule instead of starting from scratch, and also measures frame times under Hybrid Composition with danmaku on; F2 probably shrinks by 3–4 days, and the transparent-Flutter-view approach becomes the fallback if Hybrid Composition is too slow.
* **Open input** (owner: user): unchanged, the five-minute check with another app on the TV at 4K60 and 杜比视界.

---

### [2026-10-30] Milestone M12 (Task `M12.3`): Crash-Debug Side Track Merged
* **Status**: 🔄 Still awaiting the user's decision on the fix, now with the track's evidence behind the options. No app code changed.
* **Branch**: `debug/tv-m12-crash`
* **Files Changed**: `[NEW] docs/tv/M12_CRASH_DEBUG.md` (plan, findings, run log), `[NEW] tool/tv_m12/*` (run tools, MediaCodec harness, probe app), `[MODIFY] docs/tv/PLAN.md` (M12: findings, root cause, options B, D, F and the new G, "done" bar), `docs/tv/PROGRESS.md`, `docs/tv/README.md`, `docs/tv/README.en.md`.
* **Method**: two device sessions on `<physical-tv>` without the app: a MediaCodec harness over `app_process`, a small probe app on a `SurfaceView` or a `TextureView`, MiXplorer's player, Just Player and mpv-android (the last two installed with the user's approval and removed afterwards). 27 numbered runs and 8 kernel panics in session 2. Everything is in [`M12_CRASH_DEBUG.md`](./M12_CRASH_DEBUG.md).
* **Findings**:
  * The panic needs 4K60 drawn to the screen by the GPU, on a warm TV, in any player. mpv, Flutter and PiliPlus are incidental. 1080p60, 4K30 and offscreen 4K60 each survived one 10-minute run in the same state, and on-screen 4K60 then panicked in about 11 s.
  * Nothing on the video plane panicked: 4K60 AVC four times for 10 minutes, across three players, and AV1 once for 10 minutes and twice for the file's full 5:32.
  * mpv itself can use the video plane: `vo=mediacodec_embed` into a real `SurfaceView`. It panicked in M12.2 because media_kit gives it a Flutter texture.
  * The decoder's log line names the path: `hwRender:1, gdec:0` on the video plane, `hwRender:0, gdec:1` on the 4K GPU path, `gdec:0` with no `Detile` step at 1080p.
  * The freeze is a fixed budget: surface slots are the decoder's buffer count plus 2, whatever the consumer's queue size. mpv-android froze in 5 of 6 runs at its defaults.
  * Not the cause, after testing: a second decoder that the TV refuses, a media session, audio focus. Each looked like the trigger until the unchanged survivor was repeated on a warm TV and panicked too; the earlier runs had been confounded by the TV warming up.
* **Consequences for `M12.3`**: option B stands as the recommendation, with evidence that 1080P60 holds on a warm TV. F's panic question is answered for local AVC and AV1. A new option G keeps mpv on a `SurfaceView`, with `chenx-dust/PiliPlus` as prior work. The `M12.5` bar now runs on a warm TV.
* **Not answered**: which hardware block client `0xE000` is, and whether heat or bandwidth sets the panic off (the TV reports no real temperature). Not tested: HDR, Dolby Vision, tunneled playback, network streams on the video plane, PiliPlus itself on the video plane, the TV's own media app, the TV's picture settings, and bilibili's own 4K30 streams.
* **Housekeeping**: the test apps and files are off the TV. `tool/tv_m12/` stays, for `M12.5` and for F1 or G, and is noted in the READMEs.
* **Open input** (owner: user): the fix decision, and the five-minute check with another app on the TV at 4K60 and 杜比视界.

---

### [2026-10-30] Milestone M12 (Tasks `M12.3`–`M12.4`): Fix Decided, Option A Built, Option G Estimated
* **Status**: `M12.3` ✅ Decided; `M12.4` 🔄 built, awaiting CI. There's no Flutter SDK on the development machine, so analyze and the tests haven't run; `tv-checks.yml` runs them on the pull request.
* **Branch**: `fix/tv-m12-default-quality`
* **Files Changed**: `[MODIFY] lib/tv/tv_platform.dart`, `test/tv_navigation_test.dart`, `README.md`, `README.en.md`, `docs/tv/PLAN.md`, `docs/tv/PROGRESS.md`, `docs/tv/ARCHITECTURE.md`, `docs/tv/REVIEW.md`, `docs/tv/README.md`, `docs/tv/README.en.md`.
* **Decision** (the user): option A now, with a README warning; option G as a temporary fix for 4K, estimate first; option F deprioritized to a long-term plan.
* **Option A**: `SettingBoxKey.defaultVideoQa: 116` joins `TvPlatform.defaultTvSettings`, seeded only when the key is missing. Installs that never chose a quality get 1080P60; a stored choice stays. On Android TV the value is read through `Pref.defaultVideoQa` on Wi-Fi and Ethernet. Known gap: picking 4K in the HUD still freezes, and is saved as the new default. The READMEs warn about it and give the way back.
* **Option G estimate** (details in `PLAN.md`): 8 code files, 3 new and 5 edited, 4–7 days after reading media_kit's Android controller and chenx-dust's fork. A design with no package change looks possible, because `vo` can be passed as configuration and `onLoadHooks` run in order. A 1–2 day spike decides. The fallback, a build-time patch of `media_kit_video`, adds 1–2 days.
* **"TV layer only"**: true today (5 upstream Dart files, 27 added lines) and for option A. Option G breaks it by a little: 2 more upstream files, both busy. Option F breaks it outright.
* **Option F**: moved to a new M16. Its place after M15 is proposed, not confirmed.
* **Open input** (owner: user): confirm M16's place; go-ahead for G's spike; the pull request for this branch.

---

### [2026-10-30] Milestone M12 (Task `M12.4`): Option A Merged, M12 Reorganized, Option G Moved to M16
* **Status**: `M12.4` ✅ Done, but option A is on `main` and not released. `M12.5` ⏳ is next and is the only M12 task left.
* **Branch**: `docs/tv-m12-plan`
* **Files Changed**: `[MODIFY] docs/tv/PLAN.md` (Phase 5 roadmap and ordering, M12, M14, new M16, M17), `docs/tv/PROGRESS.md`.
* **Verification**: on `6004fa425`, `tv-checks.yml` found no analyze issues and all 95 TV tests passed. The first run failed analyze, because the new test imported `video_quality.dart`, which is a `part` of `base_quality.dart`; `6004fa425` fixed the import. Option A hasn't been checked on a device yet.
* **Landed**: [PR 6](https://github.com/liweichen6/PiliPlus-LemonTeaV/pull/6) as one merge commit. It contains the branch of [PR 5](https://github.com/liweichen6/PiliPlus-LemonTeaV/pull/5), so both landed together, with one release run instead of one without the fix followed by a second.
* **Release failed**: the run on `95fbbc786` stopped in `Sync upstream main`, so nothing was built and `v2.1.6.2-fork.5799` is still the latest release.
  * Upstream's 28 new commits merged without conflicts, but GitHub refused the push to `main`. Upstream changed `.github/workflows/sync-upstream-build.yml` on 2026-10-27, and a push that changes a workflow file needs a token with workflow permission. `tv-sync-build.yml` asks for the `SYNC_TOKEN` secret, which was never set, so it falls back to `GITHUB_TOKEN`.
  * Option A didn't cause this, and every sync fails the same way until it's fixed, the weekly run included. The last good sync, on 2026-10-26, came before upstream's change.
  * The README on `main` already says TVs default to 1080P 60 fps, which is only true from the next release.
* **Branches**: deleted, after checking each one is on `main`: `fix/tv-m12-default-quality`, `docs/tv-m12-device-profile`, `debug/tv-m12-crash`, and the older merged `ci/tv-checks-m11` and `docs/tv-plan-m11-m15`. The local `docs/tv-m12-device-profile` had one commit under a different hash; `git cherry` showed the same patch on `main`.
* **Plan changes**:
  * Option G is now its own milestone, M16, with three tasks, and `M12.6` is gone. As a task it would have held M12 open, and M13 and M14 wait for M12. A failed spike now ends M16 and leaves M12's result standing.
  * Option F moves from M16 to M17, so G's spike comes before the work that depends on it. Earlier entries in this file that call F M16 stay as written. M13–M15 keep their numbers.
  * M16 is proposed right after M12, and M17 after M15. Neither place is confirmed, and the numbers don't show the order.
  * M12 went from about 80 lines to about 35. Root cause, decision, options, the "done" bar and tasks now sit at one level, and F's and G's details moved to their milestones. The refuted hypothesis, the two session summaries and the answered inputs left the plan; the session details stay in this file.
  * Two corrections. Option G's summary said it needs a change to the media_kit fork, but the estimate's preferred design needs none. Option B's line gave the HUD gap as the reason it wasn't taken, when that gap is the result of not taking it.
  * M14 gets the rule that a button shows by what the current player supports. It was a note under option F; M16 now needs it first.
* **Next**: unblock the release, then `M12.5`, on a warm `<physical-tv>`, with a release build that has option A.
* **Open input** (owner: user): a `SYNC_TOKEN` secret with workflow permission, or a pull request that merges upstream by hand; confirm the places of M16 and M17; go-ahead for M16's spike.

---

### [2026-10-30] Milestone M16 (Planning): Moved Ahead of M13, Plan Checked Against the Code, Release Unblocked
* **Status**: `M16.1` ⏳ is next. Option A is released in `v2.1.6.2-fork.5863`, so `M12.5` can run.
* **Branch**: `docs/tv-m12-plan`; the test fix is on `fix/tv-hud-fake-signatures`.
* **Files Changed**: `[MODIFY] docs/tv/PLAN.md` (Phase 5 roadmap and ordering, M16), `docs/tv/PROGRESS.md`; `test/tv_player_hud_test.dart` in [PR 8](https://github.com/liweichen6/PiliPlus-LemonTeaV/pull/8).
* **Decision** (the user): M16 moves ahead of M13, because 4K is needed sooner. It gets its own branch and release, because it isn't TV-layer-only. It keeps its number, since earlier entries refer to M13–M15.
* **Release**:
  * The user added `SYNC_TOKEN`, and the re-run pushed upstream's merge to `main` as `766a47ef5`.
  * TV checks then failed analyze on that merge, so the gate from M11 held the release back while the APKs built. Upstream changed `prevPlay` and `nextPlay` to `{bool skipPart = false}`, and the HUD test's fake still used a positional argument. The HUD calls both with no arguments, so app behaviour didn't change, and PR 8 changes only the fake.
  * PR 8 merged as `d34147f38`. Analyze found no issues and all 95 TV tests passed, on the pull request and again in the release run, and `v2.1.6.2-fork.5863` was published with option A and upstream's 28 commits. The README's 1080P 60 fps default is now true of the latest release.
  * The blocked runs left one unused tag, `v2.1.6.2-fork.5861`, with no release behind it.
* **Plan check**: M16 was read against `main` after the sync and `media_kit_video` `85f0a69ea`. Nothing is built.
  * The design holds. `vo` is configurable, Kotlin can create the surface reference, and the load hook can wait for the view without a deadlock.
  * Seven requirements were missing and are now in the plan: fail closed, option order, pinning `hwdec`, the surface lifecycle, sizing, a place for the setting, and what turning it off does.
  * Failing closed matters most. media_kit attaches mpv to Flutter's texture first and swallows hook errors, so a failed G hook would leave playback on the path that panics the TV at 4K60. The spike now starts at 1080p, and no 4K60 run happens until the decoder's log shows `hwRender:1, gdec:0`.
  * The estimate rises to 9 code files, 3 of them upstream, and 5–8 days, or 6–10 with G-b.
* **Correction**: earlier entries in this file say there's no Flutter SDK on the development machine. There is; it just isn't on `PATH`, and `tool/tv_patch.sh` already looks for it where it's installed. The SDK is one patch version behind what `main` now pins.
* **Next**: `M16.1`, and `M12.5` on `v2.1.6.2-fork.5863` or later.
* **Open input** (owner: user): confirm M17's place after M15.

---

### [2026-10-30] Development Setup and a Privacy Check
* **Status**: ✅ Done. No app code changed.
* **Branch**: `docs/tv-m16-prep`
* **Files Changed**: `[MODIFY] docs/tv/PLAN.md` (`M16.1`), `docs/tv/M12_CRASH_DEBUG.md`, `docs/tv/README.md`, `docs/tv/README.en.md`, `docs/tv/PROGRESS.md`.
* **Flutter**: the development machine's SDK is on `3.47.9`, channel `stable`, and on `PATH`. With the TV patches applied, analyze found no issues, all 95 TV tests passed and a `-Pdev` APK built, and the patches were reverted afterwards. So analyze, the tests and device builds can run locally as well as on CI.
* **Privacy check**: the docs, every commit unique to this fork, the pull request refs, the text of pull requests, issues and releases, and the latest release run's log were checked against Execution Rule 4. No LAN addresses, ports, serials, local paths, local usernames, tokens or keys turned up. One rule in `M12_CRASH_DEBUG.md` was reworded.
* **Stale facts fixed**: the no-Flutter note in `M12_CRASH_DEBUG.md`, the SDK step in `M16.1`, and the pinned version in `docs/tv/README.md` and `README.en.md`.
* **Next**: `M16.1`, and `M12.5` on `v2.1.6.2-fork.5863` or later.

---

### [2026-10-31] Milestone M16 (Task `M16.1`): Spike Passed, 4K60 Plays on the Video Plane Inside the App
* **Status**: `M16.1` ✅ Done, recommendation **go**. `M16.2` hasn't started and waits for the user's go-ahead.
* **Branch**: `feat/tv-m16-video-plane`. The spike code stays uncommitted, as the plan says: `lib/tv/tv_video_plane.dart`, `TvVideoPlane.kt`, one line in `TvBridge.kt`, and small hooks in `lib/plugin/pl_player/controller.dart` and `view/view.dart`. A copy is kept outside the repository with the run logs.
* **Files Changed**: `[MODIFY] docs/tv/PLAN.md` (M16, Phase 5 roadmap, M17), `docs/tv/PROGRESS.md`.
* **Result**: G-a works, with no change to `media_kit_video` (`85f0a69ea`, unchanged in `pubspec.lock`), so G-b isn't needed. mpv's `vo=mediacodec_embed` on a real `SurfaceView` played 4K60 AVC and AV1 inside the app on a warm `<physical-tv>` for about 41 minutes, with no panic, freeze or ANR. TV uptime ran unbroken from 6.1 to 7.8 hours. On the GPU path, 4K60 on a warm TV usually panicked within 5 minutes.
* **Spike list, in the plan's order**:

  | # | Item | Result | Evidence |
  | :--- | :--- | :--- | :--- |
  | 1 | `hwRender:1, gdec:0` at 1080p | ✅ Pass | `C2MtkVdecTv` logs it on the local clip and real streams; mpv reports `vo=mediacodec_embed`, `hwdec=mediacodec` and the plane's `wid`; the layer is `DEVICE` |
  | 2 | Hook fails on purpose | ✅ Pass | A thrown error and a surface timeout, repeated on the final build: `vo=null`, `wid=0`, no decoder opened, no `Detile` lines, position empty. The toast shows in the capture from the timeout run |
  | 3 | Next-video on one `Surface` | ✅ Pass | No `native_window_api_connect … -22`. Quality switches 1080P60 → 720P and 1080P60 → 4K on the same surface; a related video pushed over the page; Back to the first video. Each opened a new decoder with `hwRender:1`. A part switch on a multi-part video isn't run: none of the three test videos has one |
  | 4 | Hybrid Composition frame cost, Impeller off, danmaku on | 📊 Measured | Tables below. The cost is real, and it falls on danmaku and the UI, not on the video |
  | 5 | Above `FittedBox` and `Transform.flip` | ✅ Pass | `自动`: `0 0 3840 2160`. 4:3: `480 0 3360 2160`, centred, and the surface resized to 1440 × 1080 under a running decoder. `Transform.flip` isn't applied on this path, as planned |
  | 6 | D-pad focus stays in Flutter; split-screen to fullscreen keeps the rect | ✅ Pass | HUD, its dialogs, the Quick Strip and the related list all take the D-pad; focus returns to the card on Back; the window keeps Android focus. Rect `2332 × 1312` in split-screen and `3840 × 2160` in fullscreen, both ways |
  | 7 | Home, TV sleep and back | ✅ Pass at 1080P60 | mpv detached 1–2 ms after the surface went; a new surface re-attached in under 5 ms; a new decoder with `hwRender:1`; the position moved on; no ANR. 147 frames dropped catching up after Home, 35 after sleep. adb stayed connected through sleep. Not run at 4K |
  | 8 | 4K60 AVC and AV1, 10+ minutes, warm TV | ✅ Pass | Table below |

* **4K60 runs** (warm TV, danmaku on, `hwRender:1, gdec:0` in every run; 31–32 layer samples per run, all `DEVICE`; no ANR):

  | Run | Stream | Decoder buffers | Played | mpv dropped | UI fps | Frames over 16.7 ms | Frame total, p50 |
  | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- |
  | d1 | `M4`, local, AVC | 6 | 610 s | 18 (0.05 %) | 52.8 | 68.0 % | 21.4 ms |
  | d2 | `M2`, local, AV1, looped | 9 | 610 s | About 5 % (433 in the first 138 s of one pass) | 54.5 | 20.7 % | 13.1 ms |
  | d3 | `BV1kMxM6FECM`, real stream, AVC, picked in the HUD | 6 | 628 s | 599 (1.6 %) | 45.4 | 74.5 % | 22.8 ms |
  | d5 | `BV1kMxM6FECM`, real stream, AV1 | 9 | 630 s | 2,483 (6.6 %) | 53.7 | 59.4 % | 18.4 ms |

  * By the verdicts in `M12_CRASH_DEBUG.md`, 10 minutes twice makes a path **safe**: AVC and AV1 each have two passes on this path.
  * `Detile` logged one burst at start (40 lines on AVC, 52 on AV1), the same counts as mpv-android's safe plane runs in M12. The GPU path logged 39,644 in one run.
  * `BV1fiHN6zEfx` opened straight into 4K on the plane too, but it resumed from history at its end, so that attempt isn't counted. Its AV1 stream is `M2`, run d2.
  * One TV, one session. AV1's drops are mpv's counter; nobody judged the panel's smoothness by eye.
* **Frame times at 1080p, plane against texture** (same videos and quality, 90 s each, the first 30 s skipped):

  | Video | Path | UI fps | Frames over 16.7 ms | Raster, p50 | Frame total, p50 | Frame total, p90 |
  | :--- | :--- | :--- | :--- | :--- | :--- | :--- |
  | `BV1fiHN6zEfx`, moderate danmaku, 1080P60 | Plane | 54.7 | 26.4 % | 6.9 ms | 13.9 ms | 21.5 ms |
  | The same | Texture | 59.3 | 13.5 % | 6.1 ms | 8.6 ms | 15.4 ms |
  | `BV1NGZtBwELa`, heavy danmaku, 1080P | Plane | 42.3 | 85.7 % | 9.6 ms | 24.0 ms | 41.6 ms |
  | The same | Texture | 56.1 | 26.8 % | 7.4 ms | 10.4 ms | 25.6 ms |

  * Hybrid Composition adds 5–14 ms at p50. Raster itself adds only 1–2 ms, so most of it looks like frames waiting their turn. That wasn't traced. The worst case is heavy danmaku at about 42 fps.
  * The video isn't held back: the decoder goes straight to the plane, and at 1080P60 mpv dropped 36 frames in the 90 s run.
  * If this is too slow, the way out is the one F2 names: a transparent Flutter view over a `SurfaceView` behind it, which needs no platform view. Not tried.
* **What the spike changed in the plan**:
  * **The hook can't wait for the surface.** The plan said it could. With a saved speed other than 1x, `_initializePlayer` awaits an mpv reply, mpv events are handled one at a time, and the hook was holding that handler. The view mounted 0.2 s after the 8 s timeout. It failed closed, but the video would never have played. Now the hook never waits: with no surface yet, the file loads with `vid=no` and the surface attaches on arrival, through the same path as Back, Home and sleep. An 8 s timer still fails closed. Normal load, 1.5x speed and both forced failures were re-run on this build.
  * **Failing closed is stronger than planned.** With `vo` other than `gpu` and `androidAttachSurfaceAfterVideoParameters: true`, media_kit never hands mpv the texture at all, so a hook that doesn't run leaves `vo=null`. The hook also reads `vo` and `wid` back before it lets mpv go on.
  * **A stored 4K default is a hazard wherever the plane is off.** Picking 4K in the HUD saved it as the dev app's default, and opening the app without the plane would have put 4K60 on the GPU path. Restored and verified before the session ended. `M16.2` clamps it.
* **Items for `M16.2`**: in `PLAN.md`, under the task. Also, after a failure the page stays on `加载中…`, and AV1's drop rate needs a look.
* **Estimate**: 3.5–5.5 days remain, so 4–6 in all, down from 5–8. G-b's 1–2 days are gone.
* **Not run**: Home and TV sleep at 4K; a part switch on a multi-part video; live rooms, which stay on `vo=gpu`; HDR and Dolby Vision streams. `M16.3` runs the first two.
* **Device notes**:
  * If the first `adb` call of a session runs inside the tool sandbox, it starts the adb server there, and every later `adb connect` fails with `No route to host`, even from outside the sandbox. Restart the server outside it.
  * The launcher's home-screen preview also logs `hwRender:0`. A guard on that line has to check that the dev app is on top: the first version force-stopped the dev app and voided one Home test.
  * After Home, the launcher's preview left a decoder on an abandoned surface that logs `C2BqBuffer … consecutive failures` every 5 s. It isn't the app's, and it was left alone. Its counter started before the runs, and it shows up on the texture path too, so it isn't Fault 1.
  * `screencap` usually shows the picture on the video plane, but one early capture was black behind the danmaku, so a black capture proves nothing. The decoder's log is the evidence.
  * The HUD's quality list differs per video. Check the highlighted row before confirming: `4K` can sit one row above the default.
* **Safety**: the guard for plane runs force-stopped the dev app on `hwRender:0` with the dev app on top, on `Detile` past the start burst, and on a 4K layer on `CLIENT`. It never fired on a real problem. No panic in this session, and no 4K60 before the user's go-ahead.
* **Cleanup**: test clips, the config file and the work folder are off the TV; `READ_MEDIA_VIDEO` is revoked; nothing started by the session is running. `PiliPlus TV dev` stays installed with its login, for `M16.2`, with its default back at 1080P60 and AVC first. The user's normal app and MiXplorer weren't touched.
* **Next** (owner: user): go or no-go on `M16.2`. `M12.5` is still open too.

---

### [2026-10-31] Milestone M16 (Task `M16.2`): Build
* **Status**: `M16.2` ✅ Done. `M16.3` is next. Committed on `feat/tv-m16-video-plane`, not pushed.
* **Files Changed**:
  * `[NEW]` `lib/tv/tv_video_plane.dart`, `android/app/src/main/kotlin/com/example/piliplus/TvVideoPlane.kt`, `test/tv_video_plane_test.dart`.
  * `[MODIFY]` `TvBridge.kt`, `lib/tv/tv_player_hud.dart`, `test/tv_player_hud_test.dart`, `.github/workflows/tv-checks.yml`, `docs/tv/PLAN.md`, `docs/tv/PROGRESS.md`.
  * `[MODIFY]`, upstream hooks: `lib/plugin/pl_player/controller.dart`, `lib/plugin/pl_player/view/view.dart`, `lib/pages/setting/models/video_settings.dart`.
* **What's built**:
  * **The setting**: `4K 视频平面` in `音视频设置`, off by default, on TVs only. Its key is fork-only, so `storage_key.dart` stays upstream's.
  * **One plane per player**: `TvVideoPlane` owns the surface reference and the fitted rect, behind a small mpv interface so the fail-closed logic is tested without libmpv. All spike logging, overrides and config are gone.
  * **Surfaces**: the plane tracks the surface mpv is on as well as the newest one, so a new surface that arrives before the old one goes is picked up when the old one goes. Writing the tests found that bug in the spike's logic.
  * **Failure**: a black screen with the reason and what to do: `视频平面启动失败，已停止播放`, `按确认键重试，按返回键退出`. Select in the HUD retries. It restarts the video from the beginning, because stopping clears the position. A late surface can't undo a failure; only a new load attaches.
  * **Turning it off**: a stored quality above 1080P60 comes down to 1080P60, on both quality keys.
  * **HUD**: on the plane, the fit dialog offers the five modes that don't crop. A stored cropping mode falls back to `自动`.
* **Found while building**:
  * **The player is shared between pages.** A video opened from a live room reuses that room's `vo=gpu` player, which would put a stored 4K default on the GPU path. While the setting is on, a player not on the plane now refuses a video above 1080P60, with a toast. The page stays black until the user backs out. The other way round, a live room opened from a video runs on the plane, which nobody has tried.
  * **The crop modes can't work.** A `SurfaceView` can't be clipped, so they'd spill over the page in split-screen.
* **Decision**: `PLAN.md`'s note said to clamp a stored 4K default wherever the plane is off. A blanket clamp would break "with the setting off, playback is unchanged" and M12's decision not to take option B, and take 4K from other TVs. So it's capped when the setting goes from on to off, and refused as above while it's on.
* **Verification**:
  * `flutter analyze --no-pub` on `lib/tv`, the hook files and the three test files: no issues. 136 of 136 TV tests pass (95 before, 39 in `test/tv_video_plane_test.dart`, 2 in the HUD file).
  * **Mutation checks**: 18 single changes to `tv_video_plane.dart`, each removing one rule (the read-back, the attach flag, the pinned `hwdec`, each step of failing closed, the timer, surface tracking, the refusal, the cap, the crop filter, `ExcludeFocus`). All 18 now fail a test. The first pass missed 2: one mutation hit a doc comment, and the other was a real gap, a tall video whose width alone passes, which now has a test.
  * **`<physical-tv>`, at 1080p, no 4K60 in this task**:
    * Setting off: `hwRender:0`, the normal texture path, 1080P60, no errors.
    * The setting is found and toggled by D-pad; with it on, `hwRender:1, gdec:0`.
    * Failing the first load on purpose, in a temporary uncommitted build: no decoder opened, the failure screen showed, and `加载中…` no longer covers it. Select retried, and the video came back with `hwRender:1, gdec:0` and danmaku.
    * The fit dialog shows `拉伸`, `自动`, `限制`, `4:3` and `16:9`, with focus on the current mode.
* **Not done**: AV1's dropped frames need 4K60 runs, so they moved to `M16.3`, with the other checks listed there. The refusal and the turn-off cap are covered by unit tests, not yet on the device.
* **Hooks**: 28 added and 5 removed in 3 upstream files, against the 8–14 estimated. 5 of the added lines are re-indented `VideoControllerConfiguration`; the rest are the plane's creation, the refusal and the failure handler.
* **CI**: `tv-checks.yml` now analyzes the new hook files and runs the new test file.
* **Cleanup**: nothing of this session is running on the TV, and the work folder is gone. `PiliPlus TV dev` holds the clean final build with its login, with the setting on and the default at 1080P60. TV patches are reverted.
* **Next** (owner: user): go-ahead for `M16.3`, which needs 4K60 runs.

---

### [2026-10-31] Milestone M16 (Task `M16.3`): Device Pass and Docs
* **Status**: `M16.3` ✅ Done. M16 meets its "done" bar on `<physical-tv>`, with one risk left open, below. Committed on `feat/tv-m16-video-plane`, not pushed: the pull request and release wait for the user.
* **Files Changed**: `[MODIFY]` `lib/tv/tv_video_plane.dart`, `test/tv_video_plane_test.dart`, `README.md`, `README.en.md`, `docs/tv/README.md`, `docs/tv/README.en.md`, `docs/tv/ARCHITECTURE.md`, `docs/tv/REVIEW.md`, `docs/tv/PLAN.md`, `docs/tv/PROGRESS.md`.
* **Final runs** (warm TV, real streams, danmaku on, the final code plus a temporary logging patch that was never committed; `hwRender:1, gdec:0` throughout, 31 layer samples per run, all `DEVICE`, no ANR):

  | Stream | Decoder buffers | Played | mpv dropped | UI fps | Frames over 16.7 ms | Frame total, p50 |
  | :--- | :--- | :--- | :--- | :--- | :--- | :--- |
  | `BV1kMxM6FECM`, AVC, picked in the HUD | 6 | 610 s | 125 (0.3 %) | 48.2 | 65.2 % | 20.6 ms |
  | `BV1kMxM6FECM`, AV1 | 9 | 610 s | 59 (0.16 %) | 54.7 | 53.9 % | 17.5 ms |

* **AV1's dropped frames**: the plan suggested `video-sync`, and it does nothing. Measured on the real 4K60 AV1 stream, 90 s each, by mpv's counter and by SurfaceFlinger's timestamps for the frames reaching the video layer (`dumpsys SurfaceFlinger --latency`):

  | mpv option | mpv dropped | Layer fps | Intervals over 25 ms |
  | :--- | :--- | :--- | :--- |
  | Current (`display-resample`), two runs | 8.0 %, 5.7 % | 52.0, 52.2 | 10.3 %, 9.7 % |
  | `video-sync=audio` | 7.2 % | 52.7 | 9.3 % |
  | `video-latency-hacks=yes` | 7.0 % | 52.0 | 11.0 % |
  | `framedrop=no` | 0 %, which only hides it | 54.4 | 10.3 % |
  | `vd-queue-enable=yes`, 1 frame | 1.1 % | 55.1 | 6.8 % |
  | The same, 2 frames | 0.2 % | 57.1 | 5.1 % |
  | The same, 4 frames | 0.3 % | 58.7 | 2.1 % |

  * 4 frames is adopted, set only on the plane path, with a test that it stays at 4 or below: frames held from this decoder can deadlock it. On AVC, 90 s each, the queue took drops from 1.0 % to 0.4 %, layer fps from 54.9 to 56.2, and long intervals from 7.5 % to 6.1 %, with no deadlock.
  * 8 frames never ran: the hang below began first.
* **Other checks**, all on the plane unless noted:
  * **Home and TV sleep at 4K60**: a new decoder with `hwRender:1`, playing again within about 10 s. mpv drops 300–390 frames once while it catches up to the audio, then about 10 in the next 110 s.
  * **Fullscreen to split-screen at 4K60**: `3840 × 2160` to `2332 × 1312`, source still 4K. The other direction ran at 1080p and 720p only.
  * **Next-video at 4K60**: a related vertical 1080 × 1920 video, fitted correctly, and Back to the 4K video. No `native_window_api_connect` errors in any run.
  * **Part switch**: `下一集` on a 13-part video, on a new decoder. That series tops out at 1080p, so this wasn't at 4K.
  * **D-pad during 4K60**: four presses in about a second landed where they should.
  * **A live room opened from a video**: 1080p at 59 fps on the plane, `DEVICE`; Back returned to the 4K video.
  * **A 4K video opened from a live room**: refused. No new decoder, no `gdec:1`, no 4K frames. The toast explains, the rest of the page works, and Back returns to the live room, which picks up again. The toast's advice was wrong, because reopening from the live room is refused again, so it now says to go back to the home page first.
  * **Turning the setting off with a stored 4K default**: `stored 120` is capped, and a fresh launch opens at 1080p on the texture. Run with a guard that stops the app on `gdec:1`.
* **Open risk, a media service hang** (2026-10-31, 02:04):
  * **Symptom**: every new video stayed on the spinner and no decoder opened. `dumpsys media.player` timed out at 10 s, and `tool/tv_codecs.sh`, with none of the app's code, hung on the codec list. So the fault was in the TV's media service, and any app starting video could have hit it. Normal after `adb reboot`, at about 0.15 s.
  * **When**: after about 9.6 hours of uptime and dozens of runs, between two 4K AV1 runs, right after a force-stop.
  * **Cause: unknown.** The logs and thread list show nothing conclusive. One suspicion was the `DEAD_OBJECT` line `mediaserver` logs at that moment, but it follows every run. Two launcher preview decoders were stuck on abandoned surfaces, retrying about a million times; each force-stop passes through the launcher, which starts its preview.
  * **What was tried**: 8 force-stopped 4K AV1 cycles with the 4-frame queue, checking `media.player` after each, were all clean, and so was about 90 more minutes of testing after the reboot. That's evidence, not proof. Normal use has none of those repeated force-stops, but nothing here shows it can't happen there.
* **Also seen**: `adbd` restarted by itself once during a 4K60 run, on a new port, while the video played on. It looked like a crash until the user confirmed the picture. A `lost` run isn't always a lost TV: check the picture and the boot reason.
* **Verification**: `flutter analyze --no-pub` on `lib/tv`, the hook files and the three test files: no issues. 137 of 137 TV tests pass. Both new mutations to the queue rule fail a test. The clean build, with no logging, plays at 1080P60 on the texture with the setting off.
* **Device notes**:
  * `dumpsys -t 6 media.player` answers in about 0.15 s when healthy, so it's a cheap check for this hang between runs.
  * `dumpsys SurfaceFlinger --latency` on the video layer works on this path and doesn't depend on mpv's counters.
  * `pgrep -f NAME` over `adb shell` matches its own shell. Use `ps` with a bracketed pattern. An earlier "leftover sampler" came from this.
* **Cleanup**: nothing of this session is running on the TV, and its test files are gone. `PiliPlus TV dev` holds the clean build with its login, with the setting off, 1080P60 and AVC first. `READ_MEDIA_VIDEO` is revoked. The user's normal app and MiXplorer weren't touched. TV patches are reverted.
* **Next** (owner: user): the pull request and M16's own release.

---

### [2026-10-31] Milestone M16: Chinese Wording
* **Status**: ✅ Done, not pushed.
* **Files Changed**: `[MODIFY]` `lib/tv/tv_video_plane.dart`, `README.md`, `README.en.md`, `docs/tv/README.md`, `docs/tv/README.en.md`, `docs/tv/ARCHITECTURE.md`, `docs/tv/PROGRESS.md`.
* **Change** (the user's choice): the setting is now `4K 视频直通`. `视频平面` was a literal translation of "video plane", and `视频层` was a second name for the same thing, so both are gone from the app and the READMEs. The strings are simpler too: the subtitle says `画面由电视直接显示，不经过 GPU`, and the refusal says `当前无法播放 4K，请返回首页后重新打开视频`. Earlier entries in this file keep the old wording, as a record of what shipped in each task.
* **Not changed**: the code names (`TvVideoPlane`, the `tvVideoPlane` setting key) and "video plane" in the English engineering docs. They're for developers, and changing the key would lose the setting.
* **Verification**: analyze and all 137 TV tests pass. Wording only; not checked on the TV.

---

### [2026-10-31] Milestone M16 (Task `M16.4`): Split Into a Variant, Parameter Doc, Decode Queue Setting
* **Status**: ✅ Done locally on `variant/4k-passthrough` (renamed from `feat/tv-m16-video-plane`), not pushed. The first release needs the user's setup, in `4K_VARIANT.md`.
* **Decision** (the user): M16 gets its own branch and release instead of landing on `main`, because `main` follows upstream and publishes automatically with no TV in the loop. The recommendation had been to stay on `main` with a release check; the user chose the split.
* **Files Changed**:
  * `[NEW]` `docs/tv/4K_VARIANT.md`, `docs/tv/PLAYBACK_PARAMETERS.md`, `.github/workflows/tv-variant-release.yml`, `tool/tv_m16/`.
  * `[MODIFY]` `android/app/build.gradle.kts`, `lib/http/api.dart`, `lib/common/constants.dart`, `lib/tv/tv_video_plane.dart`, `lib/pages/setting/models/video_settings.dart`, `test/tv_video_plane_test.dart`, `README.md`, `README.en.md`, `docs/tv/README.md`, `docs/tv/README.en.md`, `docs/tv/ARCHITECTURE.md`, `docs/tv/PLAN.md`, `docs/tv/PROGRESS.md`.
* **Two traps found before building it**:
  * `Update.checkUpdate` takes `releases[0]` of its repository, pre-releases included, and that code is already on users' TVs. A variant release in this repository would be offered to everyone on the normal app, so releases go to `liweichen6/PiliPlus-LemonTeaV-4K`.
  * With the same application ID, a user going back to the normal app would keep a stored 4K default on a build with no video plane, which is the path that panics `<physical-tv>`. The variant is `com.lemontea.piliplus.tv.passthrough`, `PiliPlus TV 4K`, with its own data and its own login. `-Pdev` builds stay `PiliPlus TV dev`.
* **Release flow**: nothing follows upstream by itself. Merge `main`, pass the device check, push, tag `v*-4k`. A push builds and runs the TV checks; only the tag publishes, and a red check publishes nothing. The workflow pushes the commit to the release repository first, because the updater compares the release's commit with the build's.
* **The setting is on by default here**: installing the variant is the opt-in, and with it on 4K can't reach the GPU path.
* **Parameters**: `docs/tv/PLAYBACK_PARAMETERS.md` has every option tried, with results and the method. The scripts and the logging patch moved into `tool/tv_m16/` with their private paths removed, so the runs can be repeated.
* **`视频直通解码队列`**: of everything tried, only the decode queue changed the result, so it's the one new setting: 关闭, 1, 2 or 4 帧, default 4. Only tested sizes are offered, and a stored value that isn't one of them falls back to 4, because frames held from this decoder can deadlock it. `framedrop` and `video-latency-hacks` aren't offered: the first hides drops and the second did nothing. `vo` and `hwdec` are never offered, and there's no free-form mpv box, because either would walk around failing closed.
* **Verification**:
  * Analyze: no issues. 141 of 141 TV tests pass.
  * A release build reports `com.lemontea.piliplus.tv.passthrough`, `PiliPlus TV 4K`; a `-Pdev` build still reports `com.lemontea.piliplus.tv.dev`, `PiliPlus TV dev`.
  * On `<physical-tv>`, no 4K60: both settings render and the new subtitle wraps cleanly; the queue dialog works by D-pad, and `2 帧` saved and showed in the subtitle before going back to `4 帧`. Focus starts on the first row of the dialog, as in upstream's other `SelectDialog`s.
* **Not verified**: the release workflow has never run, because it needs the push, the release repository and the token. The release build hasn't been installed on a TV. The default-on path is covered by unit tests, since the dev app has the setting stored off. Queue sizes through the setting are unit-tested; the sizes themselves were measured by overriding mpv's options in the logging build.
* **Known cost**: `PLAN.md` and `PROGRESS.md` now differ between this branch and `main`, so each merge of `main` conflicts at their ends until M16's docs reach `main`.
* **Next** (owner: user): create the release repository, and decide on pushing this branch and sending the docs to `main`.

---

### [2026-10-31] Milestone M16 (Task `M16.4`): CI-Only Builds, PiliPlus TVP
* **Status**: ✅ Done on `variant/4k-passthrough`. The workflow reaches `main` through its own pull request, from `ci/tv-variant-build`.
* **Decision** (the user): no second repository and no releases. APKs live only in the Actions run, from a real Run button, and the user accepted the one extra normal release that putting the workflow on `main` causes. This replaces the release repository, the `v*-4k` tag and `VARIANT_REPO_TOKEN` from the previous entry.
* **Label**: `PiliPlus TVP`. The application ID stays `com.lemontea.piliplus.tv.passthrough`.
* **Files Changed**:
  * `[NEW]` `.github/workflows/tv-variant-build.yml`, replacing `tv-variant-release.yml`.
  * `[MODIFY]` `android/app/build.gradle.kts`, `lib/utils/update.dart`, `lib/tv/tv_video_plane.dart`, `test/tv_video_plane_test.dart`, `.github/workflows/tv-checks.yml`, `README.md`, `README.en.md`, `docs/tv/4K_VARIANT.md`, `docs/tv/PLAN.md`, `docs/tv/PROGRESS.md`.
  * `[RESTORE]` `lib/http/api.dart`, `lib/common/constants.dart`, which match `main` again.
* **Update check**: off in this variant through one line in `Update.checkUpdate`, because the only releases it could find are the normal app's. A manual check shows `此版本需手动更新，请到 GitHub Actions 下载`, and the automatic one stays silent.
* **Workflow**: a run on any branch but the variant's fails at once, because the Run button defaults to `main`. The build waits for the TV checks, so a red check means no APK.
* **Verification**:
  * Analyze: no errors or warnings, and two infos on upstream lines in `update.dart`. 144 of 144 TV tests pass. Removing the hook fails its test.
  * A release build reports `com.lemontea.piliplus.tv.passthrough`, `PiliPlus TVP`.
* **Not verified**: the workflow has never run, because the Run button needs the file on `main`. The release build hasn't been installed on a TV, so neither the label nor the update message has been seen there.
* **Next**: run the first build from the Run button, and check that APK on `<physical-tv>`.

---

### [2026-10-31] Milestone M12 (Task `M12.5`): Device Verification
* **Status**: ✅ Done, so M12 is closed. No app code changed.
* **Branch**: `docs/tv-m12-5-device-check`
* **Files Changed**: `[MODIFY] docs/tv/PLAN.md`, `docs/tv/PROGRESS.md`, `docs/tv/REVIEW.md`.
* **Build**: `v2.1.6.2-fork.5870`, the normal app, on `<physical-tv>`, and the same release on `<vm-tv>`.
* **Method**: each run recorded logcat and the kernel log, with a guard that would stop the app on `gdec:1`. Every 30 s a sidecar read the process, the top activity and a new screenshot. This build has no logging, so there are no dropped-frame or frame-time numbers: these runs show that playback kept going, not how smooth it was.
* **Runs on `<physical-tv>`**:

  | Video | Quality in the HUD | Time | Result |
  | :--- | :--- | :--- | :--- |
  | `BV1fiHN6zEfx` | 1080P60 | 650 s | ✅ Pass |
  | `BV1NGZtBwELa` | 1080P+ | 650 s | ✅ Pass |
  | `BV1kMxM6FECM`, a 4K60 video | 1080P60 | 650 s | ✅ Pass |
  | `BV1fiHN6zEfx` again, after about 30 minutes of playback | 1080P60 | 650 s | ✅ Pass |

  All four used `c2.mtk.av1.decoder` with `hwRender:0, gdec:0`. Each kept one process, and every screenshot differed from the others. No freeze, ANR, crash or kernel panic, and the guard never fired. The TV stayed up throughout, and `media.player` still answered at the end.
* **The "done" bar**:

  | Row | Result |
  | :--- | :--- |
  | Warm TV | ✅ On for about 3.6 hours before the first run. That run was the session's first playback, so `BV1fiHN6zEfx` was repeated once the TV had played for about 30 minutes |
  | No stored quality | ⚠️ Not provable. `默认画质` read 1080P 60帧, the seeded value, but the app can't show whether that value was stored, and its data was left alone |
  | 10+ minutes each | ✅ With D-pad seek-backs on two videos, which are shorter than that (5:31 and 3:38) |
  | A stored 4K choice stays | ✅ On `<vm-tv>`: 4K picked in `默认画质`, and still set after a full app restart. Not tried on `<physical-tv>`, where playing it can shut the TV down |
  | Switching at or below 1080P60 | ✅ 1080P60 → 1080P → 720P → 1080P60 on `<physical-tv>`, each with a new decoder and `gdec:0` |
  | D-pad stays responsive | ✅ Up showed the HUD and Left seeked at once during playback |
  | 4K stays selectable on `<vm-tv>` | ✅ In `默认画质`, which is where it was picked. `<vm-tv>` isn't signed in, so a video's own quality list stops at 1080P there. On `<physical-tv>`, signed in, the HUD list still shows `4K 超高清`, which wasn't picked |

* **Worth knowing**:
  * A HUD pick is saved as the default: after picking 720P, the next video opened at 720P. This is the same path as the known gap, where picking 4K in the HUD freezes and is saved. The test went back to 1080P60, and `默认画质` read 1080P 60帧 afterwards.
  * One attempt at `BV1NGZtBwELa` was thrown away: a Back press with the HUD already hidden left the player, as it should. That was a test mistake, not an app fault.
  * The known gap stays open: picking 4K in the HUD on `<physical-tv>` still leads to the freeze. It wasn't tried, and the README warning covers it. `variant/4k-passthrough` is the way to play 4K.
* **Cleanup**: the test script folder is off the TV, `<vm-tv>` is stopped with its default back at 1080P 60帧, and `PiliPlus TV dev` stays installed for later work. The runs used the signed-in account, so these videos' watch positions changed.
* **Next**: `M13.0`.

---

### [2026-10-31] Docs Synced Between `main` and `variant/4k-passthrough`
* **Status**: ✅ Done. Markdown only, so no app code changed and no release follows.
* **Branch**: `docs/tv-sync-status`
* **Why**: M16's docs were only on the variant and M12.5's only on `main`, so each branch's `PLAN.md` and `PROGRESS.md` were out of date about the other.
* **Now the same on both branches**: `PLAN.md`, `PROGRESS.md`, `4K_VARIANT.md` and `PLAYBACK_PARAMETERS.md`. Change them on `main` first, then merge `main` into the variant. This ends the conflicts at their ends that the first `M16.4` entry listed as a known cost.
* **Still different, because the code is**: `README*`, `docs/tv/README*`, `ARCHITECTURE.md` and `REVIEW.md`. Each describes the code on its own branch and points to the other for M16.
* **Stale facts fixed**:
  * TV test counts: `main` has 95 (65 navigation, 30 HUD), not 88, and the variant has 144 (49 of them for M16), not 137.
  * The variant's hooks now count `lib/utils/update.dart`: 9 Dart files and about 57 lines, 30 of them for M16.
  * The variant's `ARCHITECTURE.md` still gave the normal app's ID and label.
  * The doc index still said the variant has a release method.
* **First CI build**: the run from the Run button, on `a4db595eb`, passed all three jobs. Its `armeabi-v7a` APK, build 5875, reports `PiliPlus TVP` and `com.lemontea.piliplus.tv.passthrough`, and it's installed on `<physical-tv>` beside the normal app. It hasn't been opened.
* **Next**: `M13.0`. The TVP APK still needs its own login and a check on `<physical-tv>`.

---

### [2026-10-31] Milestone M13 (Task `M13.0`, Prep): D-Pad Step Tools and Protocol
* **Status**: 🔄 In progress. The tools and the protocol are ready. Nothing has been measured on `<physical-tv>` yet, and the bug inventory waits for the user's list.
* **Branch**: `feat/tv-m13-baseline`
* **Files Changed**: `[NEW] docs/tv/M13_BASELINE.md`, `tool/tv_m13/logging.patch`, `tool/tv_m13/run.sh`, `tool/tv_m13/steps.py`; `[MODIFY] docs/tv/PLAN.md`, `docs/tv/PROGRESS.md`, `docs/tv/README.md`, `docs/tv/README.en.md`. No app code changed: the probe exists only inside the patch.
* **Decision**: `-Pdev` release plus a logging patch instead of a profile build. `--profile` inherits the `debug` build type, so it would install as a separate `.debug` app with no login. This is how M16 measured frame times, and a profile build stays available if these numbers can't say where the time goes.
* **What the probe adds to M16's frame windows**:
  * One line per D-pad step, split into `input`, `decide`, `ring`, `wait`, `build`, `raster` and `total`. It times the frame that shows the moved ring, not the focus change, because the ring waits a frame when a step scrolls.
  * `engine`: the time `_onPersistentFrame` takes on every frame. M13.2 replaces that callback, and its cost has never been measured.
* **Verification**:
  * With the patch applied: analyze found no issues, all 95 TV tests passed, so the hooks change no behaviour, and those tests' real key handling printed 235 step lines.
  * A throwaway test fed the probe fake frames: it skipped a frame already building when the ring moved, ignored Enter, and gave up on a key that moved nothing.
  * `steps.py` gave the right figures on a sample log, and `run.sh` refuses Back and Select.
  * The patch applies to `main`, and `variant/4k-passthrough` has the same `tv_navigation.dart`.
  * A `-Pdev` release build compiled with the patch applied: `com.lemontea.piliplus.tv.dev`, `PiliPlus TV dev`, not debuggable, with the probe in the compiled code. It was built for `<vm-tv>`'s arm64, and it hasn't been installed anywhere.
* **Not verified**: the clocks. The probe assumes Android's key time, `Timeline.now` and `FrameTiming` share CLOCK_MONOTONIC, which only a real device can show. Until a run confirms it, `input` and `total` are unproven. `run.sh` hasn't run on a device.
* **Next** (owner: user): the list of screens where focus jumps or the ring disappears, and the TV on for a device session.

---

### [2026-10-31] Milestone M13 (Task `M13.0`, Prep): `<vm-tv>` Only, and the First Bug
* **Status**: 🔄 In progress. No run yet.
* **Branch**: `feat/tv-m13-baseline`
* **Files Changed**: `[MODIFY] docs/tv/M13_BASELINE.md`, `docs/tv/PLAN.md`, `docs/tv/PROGRESS.md`, `docs/tv/README.md`, `docs/tv/README.en.md`.
* **Decision** (the user): M13 runs on `<vm-tv>`. This replaces `<physical-tv>` in `M13.0`, `M13.5` and the "done" bar. The engine is the same code on both, but `<vm-tv>`'s times aren't the TV's, so these targets can't prove the lag seen on `<physical-tv>` is gone.
* **First inventory item** (the user): on 我的 with several sections on, focus stops at the `观看记录` header and nothing below it can be reached. Not reproduced yet: it needs a login on `<vm-tv>`. The lead in `M13_BASELINE.md`, that the page's lazy `ListView` hasn't built those sections, is unconfirmed.
* **Second inventory item** (the user): `播放全部` in 稍后再看 can't be selected. Not reproduced yet. It's a floating button, and the same one is in 收藏, so this may be a class of bugs. The lead is in `M13_BASELINE.md`, unconfirmed.
* **Next**: prove the probe's clocks on `<vm-tv>`, then the runs in `M13_BASELINE.md`.

---

### [2026-11-01] Milestone M13 (Task `M13.0`): Runs, Bug Causes and a Proposed Budget
* **Status**: 🔄 In progress. The six runs and the inventory's causes are done on `<vm-tv>`. The budget waits for the user, and more bugs may follow. `M13.1` hasn't started.
* **Branch**: `feat/tv-m13-baseline`
* **Files Changed**: `[MODIFY] docs/tv/M13_BASELINE.md`, `docs/tv/PLAN.md`, `docs/tv/PROGRESS.md`, `tool/tv_m13/logging.patch`. No app code changed.
* **Probe**:
  * The first `input` read about 66 s, the device's uptime. Android's key time arrives in milliseconds, in a field Dart reads as microseconds, so the patch now multiplies it by 1000. `input` can read up to 1 ms long.
  * A new `[m13] clock` line proves the clocks: `Timeline.now` taken just after a frame's `buildFinish` was always positive, 15 µs to 23 ms after it, over about 9,400 frames.
  * `run.sh` worked on the device, and needs `ANDROID_SERIAL` and `M12_RUNS`.
  * Blind spot: `moved=0 handled=1` means focus moved but the ring's rect didn't. None of the six runs had one, so no step is missing from the times.
* **Decision**: measured without a profile build, because these numbers do say where the time goes.
* **Runs**: the table is in `M13_BASELINE.md`.
  * `decide` is 0.5–6 % of `total` on most runs, and at most about 10 % on the comments run's 29 plain steps. Its worst p90 is 2.27 ms.
  * `_onPersistentFrame` costs 0.02 ms a frame, so M13.2 is justified by correctness, not speed.
  * On steps that scroll, `ring` is 17–21 % of `total`, mostly the one-frame wait by design since M7.
  * `raster` is the emulator's software GPU: 1.2 ms on the first frame after idle, and 33–48 ms on any frame after that.
  * `<vm-tv>`'s software GPU understates the engine's share compared with a real GPU, and it can't show the TV's CPU. `decide` would have to run about 7 times slower than here to fill a frame by itself.
* **Changes to the protocol**: runs 3 and 4 use `down down down up up up`, because `right` moves nothing there and `left` leaves the list. The first attempt at run 3 was thrown away for that reason. `开启硬解` was off for the playing runs, because the emulator's H.264 decoder never outputs a frame, so they used software decoding on a software GPU.
* **Inventory**, all reproduced on `<vm-tv>` after the user's QR login:
  * Bug 1: `_ensureVisibleInUserScrollables` reveals the same leaf in every scrollable, so an outer list never scrolls for a card inside a horizontal list. A throwaway build that passes each level its own child fixed it on the device. The lazy-build lead was wrong.
  * Bug 2: a class. The rules only accept a target outside the focused list, and a floating control sits over it. Reproduced in 稍后再看, on the comments reply button and on WebDAV save, and four layouts failed a 1,500-key test on the real engine. Sixteen more pages share the layout and weren't tested on the device. A throwaway change reached `播放全部`, but only from the end of the list, so it proves the cause and isn't the fix. The `AnimatedSlide` lead was wrong.
  * Bug 3, new: the `⋮` on video cards can't be reached, because it's a `Stack` sibling of the card.
  * Bug 4, new: Up from a right-column `×` in 稍后再看 lands in the left column.
* **Not the engine, so items of their own**: painting on `<physical-tv>`, which `<vm-tv>` can't measure; playback while the D-pad is in use, `total` 108–156 ms here on software decoding; and an ANR, where a stuck player blocked Android's main thread inside `libmpv` when leaving it.
* **Budget**: the proposal is in `M13_BASELINE.md`. The first proposal fails four of the six runs because of `raster`, so it stays the goal for `<physical-tv>`, and M13.5's gate on `<vm-tv>` moves to the parts the engine controls.
* **Verification**:
  * With the patch applied, analyze gives the same 41 `info` lines as without it, none in the TV code, and all 95 TV tests pass. The `analyze found no issues` in the earlier entry left those out.
  * The patch applies to this branch, and `main` and `variant/4k-passthrough` have the same `tv_navigation.dart`.
  * Both diagnostic changes passed the 95 TV tests. They and the scratch tests aren't on any branch.
* **Not verified**: anything on `<physical-tv>`, by the user's decision; the sixteen other floating-control pages and the other pages that share bug 1's path, on the device.
* **Cleanup**: `<vm-tv>` is stopped, with the clean probe build installed, and `开启硬解` and `我的页卡片` are back as they were. `PiliPlus TV dev` stays signed in for M13.3 and M13.5. No video was played while signed in, and nothing in the account's lists was changed.
* **Next** (owner: user): confirm the budget, decide whether bug 1's fix lands ahead of M13.3, and add any more bugs. `M13.1` waits for the go-ahead.

---

### [2026-11-01] Milestone M13 (Task `M13.0`): Bench on `<physical-tv>`, Budget Adjusted
* **Status**: 🔄 In progress. The six runs are done on `<physical-tv>` too. The adjusted budget waits for the user, and `M13.1` hasn't started.
* **Branch**: `feat/tv-m13-baseline`
* **Files Changed**: `[MODIFY] docs/tv/M13_BASELINE.md`, `docs/tv/PLAN.md`, `docs/tv/PROGRESS.md`. No app code changed.
* **Decision** (the user): bench `<physical-tv>` and adjust the budget. This is one exception to M13 running on `<vm-tv>`, and the work itself stays there.
* **Setup**: the same clean probe, built for `armeabi-v7a` as `-Pdev` and not debuggable. It installed over `PiliPlus TV dev`, and the normal app wasn't touched. `默认画质` read `1080P 60帧` before any video played, and a log guard adapted from `tool/tv_m16/run.sh` watched for `gdec:1` and `Detile`. It never fired. The playing runs used a video with about 1,900 danmaku, on hardware decoding, signed out, so no watch history changed.
* **What this changes**: the earlier entry today said M13's case is the bugs, not speed. That came from `<vm-tv>`, and the TV corrects it.
  * `decide` is 8–18 % of a step, against 0.5–6 %, and 3.4–4.6 times slower idle, or 10–12 times while a video plays. Its worst p99 is 20.59 ms, more than a frame by itself.
  * On the comments list, where every step scrolls, `decide` and the ring path together are 45–53 % of a step. `ring` is 31 ms there.
  * The per-frame callback is still only 0.08 ms, so that part holds: replacing it brings no speed.
  * `raster` isn't the bottleneck `<vm-tv>` suggested, at 4–10 ms against 33–48 ms, but the home grid's 15.3 ms is a real item.
* **Budget**: the goal stays `work` p90 at or under 16.7 ms and `total` p90 at or under 33.3 ms. The gate moves to `<physical-tv>` and to what the engine controls, in `M13_BASELINE.md`. Four of its limits fail today, so they ask for a faster engine. One, `total` p90 at or under 55 ms on scrolling comments, needs the ring to move in the frame that scrolls, and nobody has shown that yet. It falls back to 72 ms if M13.2 can't do it.
* **Consequence**: M13.5 and the "done" bar in `PLAN.md` now check the budget on `<physical-tv>`, so M13.5 needs one more bench. `decide` p90 at or under 1.75 ms on `<vm-tv>` is the stand-in for day-to-day work.
* **Not the engine, so items of their own**: painting the home grid, and video and danmaku on the UI thread. The ANR from `<vm-tv>` didn't happen on `<physical-tv>`.
* **Separate finding**: a thread in the TV's codec service had been retrying since about 13 minutes after the TV started, so `run.sh`'s `C2BqBuffer failures` count isn't from these runs. Its cause is unknown, and it isn't the M16.3 hang.
* **Verification**: the clocks hold on the TV, positive over 20,841 frames. There was no ANR, no guard trip and no `moved=0 handled=1` in the six runs.
* **Not verified**:
  * One bench in one session, so nothing shows how much these numbers vary between days.
  * The playing resolution wasn't read directly. The default was `1080P 60帧`, no `gdec:1` appeared, and no 4K layer was listed.
  * The probe can't split `ring` past `decide` into the wait and that frame's work.
  * Whether the dev app's process had exited: `pidof` still returned a line straight after the force-stop, and the TV stopped answering `adb` once asleep. It was no longer on top.
* **Cleanup**: the dev app is force-stopped, and the test folder is off the TV. `PiliPlus TV dev` stays installed with the probe build. The TV was put to sleep with `KEYCODE_SLEEP` (`mWakefulness=Asleep`), and `adb` is disconnected.
* **Next** (owner: user): confirm the budget, including the extra bench before M13.5, and decide on landing and on bug 1's fix. `M13.1` waits for the go-ahead.

---

### [2026-11-01] Milestone M13 (Task `M13.0`): Done
* **Status**: ✅ Done. The inventory stays open for bugs the user remembers.
* **Branch**: `feat/tv-m13-baseline`, merged in PR 13.
* **Files Changed**: `[MODIFY] docs/tv/M13_BASELINE.md`, `docs/tv/PLAN.md`, `docs/tv/PROGRESS.md`. No app code changed.
* **Decision** (the user): the adjusted budget in `M13_BASELINE.md` stands. So the gate for M13.5 is on `<physical-tv>`, one more bench comes before M13.5, and the 55 ms limit on scrolling comments falls back to 72 ms only if M13.2 can't move the ring in the frame that scrolls.
* **Next**: landing and bug 1's fix, both in the next entry.

---

### [2026-11-01] Milestone M13: `M13.0` Landed, and `M13.0a` Added for Bug 1
* **Status**: ✅ Done. Markdown only, so no app code changed and no release follows.
* **Branch**: `docs/tv-m13-0a-task`
* **Files Changed**: `[MODIFY] docs/tv/M13_BASELINE.md`, `docs/tv/PLAN.md`, `docs/tv/PROGRESS.md`.
* **Landed**: PR 13 merged, and `v2.1.6.2-fork.5889` is published. The run passed its TV checks. Its first step synced upstream, so the release also carries five upstream commits, none in `lib/tv/` or the TV tests: it ships upstream's app changes, not M13's. The second run, queued by that sync's push, published nothing.
* **Decision** (the user): bug 1's fix gets its own task between `M13.0` and `M13.1`. Until now it was only described, in `M13_BASELINE.md`, so nothing scheduled it. It's `M13.0a` because about 40 lines in these docs name `M13.1`–`M13.6`, and a letter keeps all of them correct.
* **Correction**: `M13_BASELINE.md` said the fix was proven on the device. The device build also carried the diagnostic change for bug 2, so only a widget test and the 95 TV tests cover the fix alone. `M13.0a` has its own device pass, and the change is now written out in that file, because the scratch builds aren't on any branch.
* **Next** (owner: user): the go-ahead for `M13.0a`. `M13.1` follows it.

---

### [2026-11-01] Milestone M13 (Task `M13.0a`): Bug 1 Fixed
* **Status**: ✅ Done. Down reaches every section of 我的 with the ring visible, Up comes back the same way, and all TV tests pass.
* **Branch**: `fix/tv-m13-0a-scroll-levels`
* **Files Changed**: `[MODIFY] lib/tv/tv_navigation.dart`, `test/tv_navigation_test.dart`, `docs/tv/M13_BASELINE.md`, `docs/tv/PLAN.md`, `docs/tv/PROGRESS.md`.
* **The Fix**: in `_ensureVisibleInUserScrollables`, each scrollable reveals its own child, with the focused card as the rect inside it, as `Scrollable.ensureVisible` does.
* **Changed From the Written Diff**: `M13_BASELINE.md` recorded `firstTarget` only on levels the user can scroll. A test of a `NeverScrollable` list inside a scrolling one showed that was worse than no fix: the first row went 600 px off screen, where the old code drifts 56 px at the sixth row. `firstTarget` is now recorded on every level, and the diff in that file matches.
* **Tests**: 97 TV tests pass, the 95 plus two new ones, and the TV analyze step finds no issues. Without the change, the section walk fails at `card_2_0` and the `NeverScrollable` test at `row_5`.
* **Device Pass** on `<vm-tv>`, in a `-Pdev` release build with this change alone:
  * 我的, with all four `我的页卡片` sections on: Down went from `观看记录` through `稍后再看` to `我的订阅` with the ring visible, Up came back to the top, and Down left a section correctly after scrolling it sideways. The setting is back to `我的收藏`, and it held after a restart.
  * `live`, `pgc` (`番剧`, `影视` and the timeline row, which has a `NeverScrollable` `TabBarView` between its two lists), `search_panel` and the pgc introduction: Down and Up kept focus on screen with the ring visible, and sideways rows scrolled.
  * The ugc introduction: Down and Up work, but the video used has no staff row and no parts, so its horizontal rows weren't reached.
  * The user page wasn't on the list. It was added because its collapsing header is the riskiest nesting for this change. Down collapses the header correctly.
  * No ANR or crash from the app in the log for the whole run.
* **Compared With `origin/main`** (same keys, same device, on the user page and `影视`):
  * `影视`: Up from `查看更多` into `最近追剧` left that row above the top of the screen, with only a sliver of ring showing. That's bug 1's symptom on `pgc`, and with the fix the row scrolls into view.
  * The user page: going back up, the header stopped a little short of fully open, and with the fix it opens fully.
* **Seen on the Way, on Both Builds and Not Fixed Here**:
  * `pgc`: Up into a row can land on a card cut off by the right edge of the screen, and the row doesn't scroll, so the ring runs off the edge. Right scrolls such a row correctly. It's bug 5, in `M13.0b`.
  * The user page: Up from the first `查看更多` does nothing, however often it's pressed, so the tabs and `编辑资料` can't be reached by going back up. It's bug 6, a `stuck` bug in the rule chain, for M13.3 and M13.4.
  * Up doesn't always return to the card Down left. That's the missing column memory, which is M13.4's.
* **Effect on the Account**: the two playing checks ran with `开启硬解` off, and it's back on. One opened a show from the top instead of its saved position, so that episode's position went from 35:19 to 1:39, and the show moved to the front of `最近追剧`. The other, a video from `观看记录`, may have moved too. The search history was empty, and is empty again after the one entry this run added.
* **Next**: `M13.0b`, in the next entry.

---

### [2026-11-01] Milestone M13: Bugs 5 and 6 Added, and `M13.0b` Planned
* **Status**: ✅ Done. Docs only.
* **Branch**: `fix/tv-m13-0a-scroll-levels`, so `M13.0a` and `M13.0b` land together in one release.
* **Files Changed**: `[MODIFY] docs/tv/M13_BASELINE.md`, `docs/tv/PLAN.md`, `docs/tv/PROGRESS.md`.
* **Decision** (the user): the two bugs seen during `M13.0a` go into the plan. The cut-off card is bug 5, fixed now as `M13.0b`, because its cause is outside the rule chain. The stuck Up on the user page is bug 6, with a recorded path in M13.3 and the fix in M13.4, because it's in the rule chain M13.4 replaces.
* **Next**: `M13.0b`, in the next entry.

---

### [2026-11-02] Milestone M13 (Task `M13.0b`): Bug 5 Fixed
* **Status**: ✅ Done. Up and Down land on a fully visible card in rows, bug 1's walk through 我的 still passes, and all TV tests pass.
* **Branch**: `fix/tv-m13-0a-scroll-levels`
* **Files Changed**: `[MODIFY] lib/tv/tv_navigation.dart`, `test/tv_navigation_test.dart`, `docs/tv/M13_BASELINE.md`, `docs/tv/PLAN.md`, `docs/tv/PROGRESS.md`.
* **The Fix**: after a move's reveal, `_focusNode` runs a second one on Up and Down with the policy for the other end, and `_ensureVisibleInUserScrollables` has a new `onlyAxis` argument that limits it to horizontal lists. Vertical lists keep their one policy, so the pinned-header and tall-card handling doesn't change.
* **Tests**: 99 TV tests pass, the 97 plus two new ones, and the TV analyze step finds no issues. Without the change, Up leaves the card 140 px past the right edge, and Down leaves one 100 px past the left edge.
* **Device Pass** on `<vm-tv>`, in a `-Pdev` release build with `M13.0a` and this change:
  * `影视`: Up from `查看更多` lands on a card that used to stay cut off, and the row scrolls to show all of it, with the whole ring on screen.
  * 我的, with all four `我的页卡片` sections on: the same keys as bug 1's walk give the same path both ways. After a row was scrolled sideways, Down onto a card cut off on the left scrolled the row back to show it. The setting is back to `我的收藏`, read back on the settings row.
  * `番剧`, with its timeline row, and `search_panel`, 18 and 30 steps: the ring stayed fully on screen at every step.
  * No ANR or crash from the app in the log. No video was played, and the search history is empty again after the one entry this run added.
* **Seen on the Way and Not Fixed**: the side rail on 我的 can skip two items, so search and the bell can't be reached until the page moves. The user added it to the inventory as bug 7, and `M13_BASELINE.md` has the key run and what's known.
  * The same keys do the same on the `M13.0a` build, so `M13.0b` didn't cause it. With the row not scrolled, the rail walks correctly on that build, and a scrolled row on `影视` doesn't trigger it, so the trigger isn't understood.
  * It hasn't been compared with `origin/main`, because bug 1 stops that build reaching the page position. From the code, neither fix changes which target the rules pick, only how far lists scroll, but that's read from the code and not tested.
* **Decision** (the user): `M13.1` starts now, on top of `M13.0a` and `M13.0b`, before they land.
* **Next**: `M13.1`.

---

### [2026-11-01] Milestone M13 (Task `M13.1`): Adapters
* **Status**: ✅ Done. All 99 TV tests pass unchanged, the TV analyze step finds no issues, and a D-pad step runs no more instructions than before.
* **Branch**: `claude/tv-m13-1-adapters-654465`, on top of `fix/tv-m13-0a-scroll-levels`.
* **Files Changed**: `[NEW] lib/tv/adapters/` (eight files); `[MODIFY] lib/tv/tv_navigation.dart`, `lib/tv/tv_focus_layers.dart`, `tool/tv_m13/logging.patch`, `docs/tv/M13_BASELINE.md`, `docs/tv/PLAN.md`, `docs/tv/PROGRESS.md`. Nothing in `test/` changed.
* **The Move**: `tv_navigation.dart` and `tv_focus_layers.dart` now import only `tv_adapters.dart` and `tv_platform.dart` from this project, and no code in them names an upstream class. An upstream rename now breaks one adapter, not the engine. The two files went from 4,173 lines to 3,586.

| Adapter | Source | Contributes |
| :--- | :--- | :--- |
| `TvSheetAdapter` | `MiniScaffold` / `BottomSheetLayout` | What to hide (`hides`), and reads of a layout and its sheet for the lifecycle the engine still keeps |
| `TvCardAdapter` | Comment and video cards and their embedded actions | Groups (`isGroup`, `isAction`) and roles (`isSecondaryIn`, `isMicroAction`) |
| `TvListTileAdapter` | `ListTile` trailing controls, in both classes | Groups (`isGroup`) and roles (`isSecondaryIn`) |
| `TvPopupAdapter` | Popup routes and overlay dialogs | Layers (`layerProviders`) |
| `TvPlayerHudAdapter` | Upstream's player bars, which `AppBarAni` slides away | What to hide (`isSlidAway`) |
| `TvLoginAdapter` | The login QR tab | `didPushRoute` |

* **The Contract**: `tv_focus_adapter.dart` holds `TvFocusAdapter`, the layer interfaces and three focus-tree helpers the engine and adapters share. It imports only Flutter, and no adapter imports the engine, so there's no import cycle.
* **Design Note, the Hot Paths**: `hides` and `isGroup` run per ancestor per candidate, and `isSecondaryIn` per pair of candidates, so the engine calls the `const` adapters by name and never loops over a list. They're `final class`es with `vm:prefer-inline` on what the walk calls. Only the cold `layerProviders` and `didPushRoute` go through `tvFocusAdapters`. A new source that fits rows, cards, actions, sheets or layers changes an adapter and not the engine. One that needs a new concept still needs an engine change until M13.4's scorer.
* **Left Where It Is**:
  * The inline sheets' lifecycle stays in `_TvNavigationState` for `M13.2`, reading layouts and sheets through `TvSheetAdapter`.
  * The rule chain stays for `M13.4`. It now reads rows, cards and actions. The engine still tests `InkResponse`, `IconButton` and `TextField` to see whether a control is enabled, which is Flutter and not upstream.
  * `Wrap` as a group, and the pinned sliver header handling, are Flutter types outside the six sources.
  * `tv_player_hud.dart` keeps its calls into upstream's player, because M14 owns that file and the plan keeps `M13.1` off it. So `TvPlayerHudAdapter` is small: the slide check is all the engine knew about the player.
* **Names for M13.5**: `ARCHITECTURE.md` and `REVIEW.md` keep the old names until that task's docs pass. `_TvFocusLayer` and `_TvFocusLayerProvider` lost their underscores and moved to `tv_focus_adapter.dart`. `_OverlayFocusLayer`, `_RouteFocusLayer` and `_RouteFocusLayerProvider` moved to `tv_popup_adapter.dart`. `_inspectBottomSheetNode` is `TvSheetAdapter.inspect`, and `_subtreeHasRequestableFocus` is `hasRequestableFocus`. `enclosingListTile`, `enclosingInkResponse` and `enclosingButton` are `enclosingRow`, `enclosingCard` and `enclosingAction`.
* **`logging.patch`**: regenerated, because its context held the removed imports. It has the same six hooks, and the probe file is byte for byte the same.
* **Tests**: 99 TV tests pass with no change to `test/`, and the TV analyze step finds no issues.
* **What the 99 Tests Don't See**: 29 mutants, each breaking one adapter contribution. 14 fail the tests. The other 15 pass all 99: the tile group in either class, the trailing role, sheets' opening and closing states, the body-slot fallback, micro actions, the slid-away check and the login switch. Passing tests prove little on those paths.
* **Differential Trace**: to cover those, a throwaway test drove seeded keys through tiles, cards, slid-away bars, sheets frame by frame, popups, overlay dialogs and the login tab, and logged focus, ring and scroll offsets at every step. Base and branch match on all 68,759 lines. It catches 11 of the 15 mutants. Of the other four, one is dead code and one only changes cost (see below); `trigger not remembered` changes nothing because `_onFocus` already remembers that node; and `no enclosing active sheet` only matters when a replaced sheet's record has no trigger. That last one wasn't exercised, and its code moved verbatim. The test isn't committed.
* **Speed, Machine Code**: the same `--split-debug-info` build of both, disassembled, instructions and direct calls:

| Function | Instructions | Direct calls | Notes |
| :--- | :--- | :--- | :--- |
| `evaluateNode`'s walk | 1,377 → 1,348 | 43 → 43 | No adapter code left out of line |
| `_findVerticalCandidate` | 927 → 927 | 49 → 49 | |
| `_filterOutEmbeddedSecondaryActions` | 376 → 376 | 30 → 30 | |
| `_isEmbeddedSecondaryOf` | 73 → 71 | 5 → 5 | |
| `inDirection`'s closure | 719 → 788 | 60 → 63 | `_isEmbeddedSecondaryOf` now inlines here: one call fewer on the path, with its body in line |
| `_findHorizontalCandidate` | 475 → 541 | 64 → 67 | The same |

  No new loop and no new call on the path. On the per-frame path `_discover` gains five instructions, for its new argument.
* **Speed, Timing** on `<vm-tv>`, `decide` in ms, with the same keys, alternating builds in A-B-B-A order:
  * Home, 8 runs and 991 steps on the final build: mean 0.945 → 0.938, p50 0.92 → 0.94, p90 1.32 → 1.28 (permutation test on run means, p = 0.77).
  * Settings, 音视频设置, 4 runs and 675 steps: mean 0.80 → 0.80, p50 0.78 → 0.79, p90 1.12 → 1.06.
  * Per frame, `engine` p50 over 20 home runs: 19.4 → 19.9 µs (p = 0.81). It follows the time of the session, not the build.
  * The settings runs and the per-frame comparison used builds from before the last change, which only made a role a `bool` instead of an enum. That first version read 5 % slower on home over 12 runs (0.923 → 0.972, p = 0.25). It wasn't proven, but it added a compare per pair of candidates, so it went.
  * Not timed: comments and the video page, which would need a video playing. They rest on the machine code. `<physical-tv>` wasn't used, so the budget's real check is still M13.5's bench.
* **Seen on the Way and Not Fixed**:
  * `_isPrimaryContainer` carries `w is InkResponse` from two copies of the old code. It can't be true: a focus node's context is a `Focus`, and `InkResponse` sits above it. Removing it changes nothing in the tests or the trace.
  * `TvNavigationObserver.didPush` still calls `ModalRoute.of(current.context!)`, the dependency on the focused widget that `R13` removed elsewhere.
  * Upstream's `MiniScaffold` trips a debug-only assert when a sheet replaces an open one. It doesn't exist in a release build.
* **Device Pass** on `<vm-tv>`: 20 home and 4 settings runs, D-pad keys plus Select on the rail, the gear and a settings pane, with a screenshot before each. No video was played and no setting changed. `PiliPlus TV dev` is left on a build of this branch without the probe.
* **Next**: `M13.2`, on the user's go-ahead. It reworks the sheets' lifecycle, and the 99 tests don't pin those opening and closing states, so the trace's sheet scenes should become real tests first.

---

### [2026-11-01] Milestone M13 (Task `M13.1a`): Tests for What the Adapters Carry
* **Status**: ✅ Done. 119 TV tests pass, the 99 plus 20 new ones, and the TV analyze step finds no issues.
* **Branch**: `claude/tv-m13-1-adapters-654465`.
* **Files Changed**: `[MODIFY] test/tv_navigation_test.dart`, `docs/tv/PLAN.md`, `docs/tv/PROGRESS.md`. No app code changed.
* **Decision** (the user): the paths `M13.1` found the tests couldn't see get real tests before `M13.2`, because that task reworks the sheets' lifecycle.
* **The Tests**, in the group `paths the adapters carry (M13.1a)`, which CI runs with no workflow change:

| Path | Tests |
| :--- | :--- |
| `ListTile` trailing controls, material and upstream | Right onto a button and back, Right onto a switch and back, and Up and Down staying on the tiles: 6 tests |
| A `⋮` over a card | Up and Down land on the card, also from a narrow control right above the `⋮` |
| A player bar slid out of its box | A list inside it stays out of reach until it slides back |
| The login QR tab | Controller registered first, or a frame late, or never, and another route leaves the tab alone |
| Inline sheets | Takes focus while opening, opened late from outside it, gives focus back as it starts closing, takes no keys while closing, closed while still opening, trigger gone with something left in the body, and with nothing left |

* **Checks**:
  * 25 of the 29 mutants from `M13.1` now fail a test, up from 14. The two tests that first missed theirs show why such a check matters. A full-width card hides the `⋮` rule, because the card under it is the nearer centre anyway. And `isAnimatingOpen` turned out to keep a late sheet from waiting out the 12-frame empty probe, about 200 ms, which an ordinary open never shows.
  * All 119 also pass on the engine from before `M13.1`, so they pin existing behavior and not something the refactor introduced.
  * No line of an existing test changed: the diff to the test file only adds lines.
* **Still Invisible**, the same four as in `M13.1`:
  * `no enclosing active sheet`: the guard only matters for a replaced sheet whose record has no trigger, and from the code the node it would save is gone by then.
  * `all subtrees requestable`: only changes cost, because the probe after it finds nothing either.
  * `trigger not remembered`: `_onFocus` already remembers that node, and the layer stack restores it anyway.
  * `drop the InkResponse check`: dead code, listed in `M13.1`.
* **Not Pinned, on Purpose**:
  * Right onto a `⋮`: that's bug 3, so the expected path belongs to M13.3 and the fix to M13.4.
  * One sheet replacing an open one: upstream's `MiniScaffold` trips a debug-only assert there, so a widget test fails on the assert. The trace in `M13.1` covered it and matched. `M13.2` should watch this path, because it has no test.
* **Device Pass**: none needed. No app code changed.
* **Next**: `M13.2`, on the user's go-ahead.

---

### [2026-11-02] Milestone M16 (Task `M16.5`): Live Rooms on the Video Plane
* **Status**: ✅ Done on `variant/4k-passthrough`. Signed-in 2K/4K live soak waits for a signed-in session.
* **Why**: the user tested a 2K live stream in a room opened directly (`vo=gpu`) and hit the kernel panic (`sys.boot.reason=watchdog`), showing that >1080p (`gdec:1`) on the GPU path is unsafe for live streams too (`M12_CRASH_DEBUG.md`, Question 5 & H5 update). In `M16.2`–`M16.4`, `TvVideoPlane.forNewPlayer` and `TvVideoPlane.refusesTexture` both exempted `isLive`, leaving directly opened >1080p live rooms on `vo=gpu` and refusing 4K videos opened from a live room.
* **Files Changed**:
  * `[MODIFY]` `lib/tv/tv_video_plane.dart`, `lib/plugin/pl_player/controller.dart`, `lib/tv/tv_player_hud.dart`, `lib/pages/live_room/controller.dart` (+1/−1), `.github/workflows/tv-checks.yml`, `tool/tv_m16/run.sh`, `test/tv_video_plane_test.dart`, `test/tv_player_hud_test.dart`.
  * `[MODIFY]` `README.md`, `README.en.md`, `docs/tv/README.md`, `docs/tv/README.en.md`, `docs/tv/ARCHITECTURE.md`, `docs/tv/REVIEW.md`, `docs/tv/4K_VARIANT.md`, `docs/tv/M12_CRASH_DEBUG.md`, `docs/tv/PLAYBACK_PARAMETERS.md`, `docs/tv/PLAN.md`, `docs/tv/PROGRESS.md`.
* **Changes**:
  * `TvVideoPlane.forNewPlayer()` drops `{required bool isLive}`: live rooms opened while `4K 视频直通` is on now run on `TvVideoPlane`, and videos opened from a live room reuse that plane player instead of being refused.
  * `TvVideoPlane.refusesTexture` refuses any live stream on a player not on the plane while `4K 视频直通` is on (even with `width == null && height == null`), showing `当前无法启用视频直通，请返回首页后重新打开直播`.
  * `TvVideoPlane.capStoredQuality` clamps stored `liveQuality` and `liveQualityCellular` above `原画` (`10000`, `LiveQuality.origin.code`) back to `10000` when `4K 视频直通` is turned off (`原画` is 1080p in Bilibili's multi-tier live ladder, below `15000` `2K`).
  * `TvPlayerHud._togglePlayPause` retries a plane failure via `(widget.onRefresh ?? _pl.refreshPlayer)()` so `Select` works on live rooms (`LiveRoomController.queryLiveUrl`) as well as videos.
  * `LiveRoomController.queryLiveUrl` marks `isLoaded.value = true` via `whenComplete` on `initLiveUrl` instead of waiting for `_fetchBlockRules` (10 s timeout + 2 retries), keeping live `_PlaneSurface` mount well inside the 8 s `surfaceTimeout`.
  * `tool/tv_m16/run.sh` checks both 2K (`2560 × 1440`) and 4K (`3840 × 2160`) `SurfaceView` layers for `CLIENT` composition.
* **Verification**:
  * Analyze (`tv-checks.yml` list including `lib/pages/live_room/controller.dart`): 0 errors, 0 warnings (2 pre-existing upstream infos in `lib/utils/update.dart`).
  * Automated tests: **146 / 146** TV tests pass (`65` navigation, `31` HUD, `50` video plane).
  * `-Pdev` `armeabi-v7a` release APK built and installed over `PiliPlus TV dev` on `<physical-tv>` (~34 h uptime, warm).
* **Device checks on `<physical-tv>`** (`PiliPlus TV dev` signed out after `M13.0`, under `tool/tv_m16/run.sh` guards):
  * **Direct landscape live room (`plane` guard)**: `c2.mtk.avc.decoder` opened with `hwRender:1, gdec:0` (`Detile 45` start burst only), `DEVICE(MM)` layer at `[0, 536, 2332, 1846]` in split-screen.
  * **Direct portrait live room, split-screen → fullscreen, and Home & back (`plane` guard)**: opened with `hwRender:1, gdec:0` and `DEVICE(MM)` 9:16 pillarbox rect `[622, 224, 1710, 2160]` in split-screen and `[1312, 0, 2526, 2160]` in fullscreen; `KEYCODE_HOME` detached cleanly and resuming `MainActivity` re-attached on a new `hwRender:1, gdec:0` decoder with picture restored (`Detile 71` across both attaches).
  * **Live room → video → Back to live room (`plane` guard)**: opened a live room (`hwRender:1, gdec:0`, `DEVICE(MM)`), opened `BV1kMxM6FECM` on top of it (`1920 × 1080` via `免登录1080P`, `hwRender:1, gdec:0`, `DEVICE(MM)` `[0, 0, 3840, 2160]`, not refused), and pressed Back twice to return to the live room, which resumed on a third `hwRender:1, gdec:0` `DEVICE(MM)` decoder.
  * **Toggling `4K 视频直通` off with `直播默认画质: 4K` + `gpuguard` check**: picked `4K` (`20000`) in `直播默认画质`, turned `4K 视频直通` off, verified `直播默认画质` automatically read `原画`, and ran a 20 s live launch under `gpuguard` (`hwRender:0, gdec:0`, `Detile 0` on Flutter's texture); restored `4K 视频直通` on afterwards.
* **Not verified**:
  * Signed-in `1080p` (`原画`), `2K` (`15000`) and `4K` (`20000` / `25000`) live streams and live → `4K60` video on `<physical-tv>`, because `PiliPlus TV dev` is currently signed out (`mid=0`) and Bilibili clamps unauthenticated live streams to `qn=150` (`854 × 480` / `540 × 960`) and videos to `1080P`.
* **Cleanup**: `PiliPlus TV dev` is force-stopped with `4K 视频直通` back on (`默认画质: 1080P 60帧`, `直播默认画质: 原画`, `免登录1080P` on); temporary `/data/local/tmp/m12` and screenshot files are removed from `<physical-tv>`; `dumpsys -t 6 media.player` answered in `< 1 s`; the user's normal app wasn't touched; all 38 SDK and pub-cache patches are reverted.
* **Next** (owner: user): optional signed-in 2K/4K live check on `<physical-tv>`, and upstream `main` sync when ready.

---

### [2026-11-04] Milestone M13 (Task `M13.2`): One Reconcile Loop, Inline Sheets on the Layer Stack
* **Status**: ✅ Done. All 119 TV tests pass unchanged, the TV analyze step finds no issues, a differential trace matches the engine before `M13.2` line for line, and a D-pad step runs the same machine code as before.
* **Branch**: `claude/tv-m13-2-reconcile-7332fc`, on top of `main` after `v2.2.0-fork.5907`. It lands through its pull request, and landing it publishes a release: the release job merges upstream first.
* **Files Changed**: `[MODIFY] lib/tv/tv_navigation.dart`, `lib/tv/tv_focus_layers.dart`, `lib/tv/adapters/tv_focus_adapter.dart`, `lib/tv/adapters/tv_sheet_adapter.dart`, `tool/tv_m13/logging.patch`, `docs/tv/M13_BASELINE.md`, `docs/tv/PLAN.md`, `docs/tv/PROGRESS.md`. Nothing in `test/` changed.
* **One Reconcile Pass**: `_reconcile(pass)` in `_TvNavigationState` is now the only place that moves focus or the ring after an event. Its steps always run in one order: layers (modal, then the inline sheets) → whether the focused node is still valid → recovery → reveal → ring. A pass carries its reason, which picks the steps:

| Reason | Trigger | Steps |
| :--- | :--- | :--- |
| `focus` | The focus listener, and app resume | All five |
| `layers` | A frame found a modal layer opening, closing or losing focus | Layers |
| `sheets` | A frame found an inline sheet with work | Layers, then validity and recovery |
| `scope` | A frame found focus resting on a scope | Layers, then validity and recovery |
| `invalid` | A frame found the focused node out of reach | Layers, then validity and recovery |
| `select` | Select with nothing reachable focused | Layers, then recovery, at once |
| `scroll` | A scroll notification | Validity, at once; the focus change it causes brings the rest |
| `ring` | A frame found the ring out of date | Ring |

  These replace seven post-frame closures in `_syncFocusRectAfterLayout`, the closure in `_onFocus`, and the recovery code in `_handleKeyEvent` and `_handleScrollNotification`. `_focusSyncScheduled` and `_rectSyncScheduled` became `_passPending` and `_ringPending`, with the same rules: the first request of a kind wins until it runs. Each recovery keeps the rules its trigger had, as a branch of step 3, for M13.4 to replace with the scorer and column memory.
* **The Frame Check**: layout can move the focused node with no event (a scroll animation, a list that grows, a sheet that slides), so a persistent frame callback stays. It's now `_onFrame`, a check that reads a few cheap signals and asks for a pass when one changed. It never asks for a frame itself, so a still screen costs nothing, and per-frame work happens only while something else animates. This is how "it replaces the per-frame callback" was read, and the user agreed to it in the plan.
* **Inline Sheets as a Non-Modal Layer**: the sheets' lifecycle moved out of `_TvNavigationState` into `_TvSheetLayers`, which `_TvFocusLayerStack` owns next to its modal records. `stack.reconcile()` runs the modal layers, then the sheets, as `_reconcileFocusLayers` did. Each tracked sheet is a `TvSheetLayer` (`tv_sheet_adapter.dart`), a `TvFocusLayer` with the new `isModal` set to `false`: it covers only its layout's body, which the adapter's `hides` keeps out of reach, focus moves in once (also when its content mounts late) unless the user went elsewhere first, nothing pulls focus back, and focus goes back to the trigger as soon as it starts closing. The modal stack's `occludes` still loops over modal records only. The lifecycle code moved with its rules unchanged; `_TvSheetRecord` now holds the layer instead of the sheet widget.
* **The Status Listener**: a `TvSheetLayer` listens to its sheet's `AnimationController` and marks the sheets dirty on each status change. That's what lets a frame skip the sheets' bookkeeping (the walk up the focused node's ancestors, and the loops over tracked and known layouts) while every tracked sheet is settled and nothing changed. A skipped frame still checks, cheaply, that each tracked sheet is still the one in its layout, that no known layout shows a new sheet, and that every sheet layout around the focused node shows the same sheet in the same state. Focus changes, registrations and passes mark the sheets dirty too. Closing still gives focus back on the same frame as before: the listener wakes the bookkeeping, and the pass runs at the end of the frame, as the old per-frame check did.
* **What Stayed the Same**: the rule chain and `inDirection`, `evaluateNode` and the traversal cache, the adapters' hot-path calls, `findRecoveryFocus` and `findFirstFocus`, the 45 ms repeat throttle, `_ensureVisibleInUserScrollables` with the bug 1 and bug 5 fixes, the 12-frame empty probe, the 500 ms settle window, the popup and overlay providers, and `TvNavigationObserver`. M7's one-frame ring wait on steps that scroll stays, so the baseline's 55 ms limit for scrolling steps isn't attempted here. Bugs 2, 3, 4, 6 and 7, the dead `InkResponse` check and `didPush`'s `ModalRoute.of` are untouched.
* **One Assumption**: a skipped frame relies on the focused widget keeping its ancestors. If a `GlobalKey` moved the focused widget into or out of a sheet's slot with no focus change, the bookkeeping would only see it on the next event. Nothing in the app was found to do that.
* **Tests**: 119 TV tests pass with no change to `test/`, including the `paths the adapters carry (M13.1a)` group, and the TV analyze step finds no issues.
* **Differential Trace**: the `M13.1` trace test was lost with its worktree, so a new one was written and not committed. It drives seeded keys, Select, Back, scrolls, page switches, unfocus and app resume through four sets of scenes, and logs the focused node, the ring, every scroll offset and whether a frame is scheduled after every frame:
  * tiles, cards with a `⋮` over them, both `ListTile` classes, a two-page `PageView`, and cards removed by Select (10 seeds);
  * a player bar sliding in and out (4 seeds);
  * inline sheets frame by frame, 18 frames per action (16 seeds): a plain sheet, a second layer with its own `MiniScaffold` and a third layer inside it, content that mounts late, a sheet with nothing focusable, a sheet opened late from the left column, the trigger removed while it's open, a popup menu over the page, and **one sheet replacing an open one**, the path no test covers;
  * routes pushed and popped, a dialog route and a `SmartDialog` overlay (6 seeds);
  * fixed scenes for the frame skip, in four sheet seeds: a second layer opened by code inside an open sheet, around the focused node, a sheet opened over an open one by code while focus is outside it, and focus asked for behind an open sheet.

  Base and branch give the same 27,200 lines, byte for byte, and base gives the same lines on a second run.
* **Mutants**: one break at a time, each run against the 119 tests and the trace (`M13.1`'s script, extended):
  * The 29 from `M13.1` give the same result as in `M13.1a`: 25 fail a test, and the same four change nothing either can see (`no enclosing active sheet`, `all subtrees requestable`, `trigger not remembered`, the dead `InkResponse` check).
  * 29 new ones break the pass, the sheet layer and the frame skip. 12 fail a test or change the trace, among them: no restore to the trigger, no body fallback, a replaced sheet keeping its promotion, the focus pass skipping the reveal, the frame's out-of-reach recovery dropped, select ignoring a pending scroll recovery, the frame skip ignoring its dirty flag, and **the sheet's status listener not reporting**, which the trace catches.
  * Eight change nothing either can see, on paths the old engine had: a scroll's unfocus, remembering the focused node, the scope branch clearing the ring, the sheets pass's own recovery, app resume clearing the pending flags, dropping nested sheets on close, and noting a user who left a sheet waiting for content (twice: the note itself, and the layer's `contains` it uses). The first seven, broken the same way on the engine before `M13.2`, are just as invisible, so these are old blind spots, not new ones. They moved without change.
  * The other nine are in the frame skip and the pass flags. The skip's single checks (tracked sheets, known layouts, the layouts around focus, the focused node, and settling only when every sheet is settled) each change nothing alone, because they cover each other. Tracked, known and around switched off together change the trace at the second-layer scene above. Setting the dirty flag on a focus change or on a pass also duplicates the focused-node check, and turning both off changes nothing either can see. `ring shares the pass flag` and `never skips` change nothing too; the second shouldn't.
* **Speed, Machine Code**: the same `-Pdev` `--split-debug-info` builds of both, with the probe, disassembled. Instructions and direct calls:

| Function | Instructions | Direct calls | Notes |
| :--- | :--- | :--- | :--- |
| `evaluateNode` and its closures | 1,768 → 1,768 | 70 → 70 | |
| `_findVerticalCandidate` | 927 → 927 | 49 → 49 | |
| `_findHorizontalCandidate` | 541 → 541 | 67 → 67 | |
| `_filterOutEmbeddedSecondaryActions` | 376 → 376 | 30 → 30 | |
| `_isEmbeddedSecondaryOf` | 71 → 71 | 5 → 5 | |
| `inDirection` and its closures | 875 → 875 | 71 → 71 | |
| `isEffectivelyFocusable` (both) | 15 → 15, 20 → 20 | 2 → 2, 4 → 4 | |
| `_computeFocusedRect` | 202 → 202 | 17 → 17 | |
| `_TvFocusLayerStack.occludes` | 71 → 81 | 5 → 5 | With no layer open, the path is the same instructions. With a dialog or popup open, each record costs one class-id compare more |
| Per frame: `_syncFocusRectAfterLayout` and its helpers → `_onFrame`, `frameHasWork` and its helpers | 1,308 → 844 | 102 → 63 | Smaller, because the passes left it. With no sheet in play, a frame makes one call more (`frameHasWork`) |
| Per focus change: `_onFocus` and its closure → `_onFocus`, `_requestReconcile`, `_reconcile` | 552 → 611 | 55 → 60 | One call more per focus change |
| `_handleScrollNotification` | 106 → 37 | 12 → 4 | Its body moved into the pass: two calls more per notification |

  The D-pad decision runs the same machine code. `occludes` first came out at 107 instructions with four calls more, because the compiler inlined the sheet layer's `occludes` into the modal loop, where a sheet never is. `TvSheetLayer.occludes` is now `vm:never-inline`, which leaves the one compare.
* **Speed, Timing** on `<vm-tv>`, `decide` in ms and `engine` per frame in µs, with the same keys as `M13.0`, alternating builds in A-B-B-A order, on the final builds:
  * Home, 8 runs and 491 steps each: mean 0.967 → 0.980, p50 0.97 → 0.98, p90 1.27 → 1.28, p99 1.46 → 1.46 (permutation test on run means, p = 0.80). `engine` p50 14.0 → 14.0.
  * Settings, 音视频设置, 4 runs and 334 and 336 steps: mean 0.841 → 0.790, p50 0.87 → 0.80, p90 1.06 → 1.02. `engine` p50 12.5 → 13.0.
  * Both follow the time of the session more than the build: home's base runs went from 0.885 to 1.016 over the session. The `decide` machine code is the same, so neither difference is the change.
  * Not timed: comments and the video page, which need a video playing, and a frame with a sheet open. They rest on the machine code. Timing wasn't repeated on `<physical-tv>`.
* **Device Pass** on `<vm-tv>`: the 12 timing runs, then the clean branch build: the home grid and the side rail with D-pad keys, then 我的 → the gear → 音视频设置 → the right pane, `CDN 设置` opened and closed with Back (focus went into the dialog, moved inside it, and came back to `CDN 设置`; the setting stayed 备用URL). A screenshot came before each Select. No video was played and no setting changed. `PiliPlus TV dev` is left on a build of this branch without the probe, and the emulator is stopped.
* **Device Pass** on `<physical-tv>` (32-bit `-Pdev` builds of the base commit and of this branch, without the probe):
  * Two fixed D-pad walks over the home grid from a fresh start, 23 and 18 keys: into the tabs, down the grid as it scrolls, Left across columns and onto the rail, up the rail to the avatar, back along the tabs, and Down from `影视`. A screenshot after every key, on both builds. The ring lands on the same item at every step in both, although the feed shows other videos on each start.
  * In the free walk before them, Right from a top-row card half under the tab bar went to `影视`, Down from `影视` went to the left column, and one Left went to the rail. The fixed walks give the same moves on base, so they come from the old rules, not from `M13.2`. They're left for M13.3's recorded paths and M13.4.
  * On this branch: 我的 → the gear → 音视频设置 → the right pane, then `CDN 设置` opened with Select, Down and Up inside the dialog, and closed with Back. Focus stayed in the dialog while it was open, came back to `CDN 设置`, and the setting stayed 备用URL.
  * The dev app there is signed in now, so only arrow keys were used away from those Selects, and there was a screenshot before each Select. No video was played and no setting changed. `PiliPlus TV dev` is left on this branch's build and stopped, the TV is on its home screen, and nothing was pushed to it.
* **Next**: `M13.3` (recorded D-pad paths), on the user's go-ahead.

---

### [2026-11-04] Milestone M13 (Task `M13.3`): Recorded D-Pad Paths
* **Status**: ✅ Done. 144 TV tests pass: the 119 from before, unchanged, and 25 recorded paths, 13 of them known failures. The TV analyze step finds no issues.
* **Branch**: `claude/tv-m13-3-paths-36ae14`, on top of `main` after PR 17 (`M13.2`) and the upstream merge after it.
* **Files Changed**: `[NEW] test/tv_path_harness.dart`, `test/tv_paths_test.dart`; `[MODIFY] test/tv_player_hud_test.dart` (lines added only), `.github/workflows/tv-checks.yml` (analyze and test the new files), `docs/tv/README.md`, `docs/tv/README.en.md`, `docs/tv/M13_BASELINE.md`, `docs/tv/PLAN.md`, `docs/tv/PROGRESS.md`. No app code changed, and nothing in `lib/tv/`.
* **How a Path Works** (`tv_path_harness.dart`): a path is a start node and a list of steps, each a key (the arrows, Select, or Back as the system back button) and the label of the node focus should land on. After each step the replay checks the focused node, that the ring is drawn on it, that all of the ring is on screen, and that the node isn't cut off by any list around it. Where more than one landing is right, a step lists them with `|`; there are four such steps, noted below. The expected path is the correct one, including the inventory's fixes.
* **Known Failures**: a `KnownFailure` names its bug and the step that goes wrong, and either where the old rules land (`landsOn`) or that they land on the right node but leave it cut off (`cutOff`). The replay checks every step before it as usual, then checks that this step goes wrong in exactly that way. If the bug is fixed the test fails with "no longer shows: make it an ordinary step", and if it goes wrong some other way it fails too. So the old scorer keeps passing, and M13.4 drops each `KnownFailure` as its scorer fixes that step. Each test's name starts with `[known failure: bug N]`.
* **The Scenes**: the real pages need GetX controllers, Hive and the network, so each scene copies its page's layout at the TV's logical size, 960×540, with the real containers where they're cheap: `NavigationRail` with the avatar, bell and search above it, the scrollable `TabBar`, `ExtendedNestedScrollView`, `SimpleScaffold`, `MiniScaffold`, upstream's `ListTile`, `SelectDialog`, `SliderDialog`, the home grid's `SliverGridDelegateWithExtentAndRatio` at the TV's card width, and the real `TvPlayerHud` with the HUD tests' fakes. Cards copy `VideoCardV`, `VideoCardH` and `VideoCardHLater`, comments copy `ReplyItemGrpc`. The video page's paths are in `tv_player_hud_test.dart` because the fakes are there.

| Screen | Paths | Known failures |
| :--- | :--- | :--- |
| Home grid with the rail | Columns and rows, Left from the first column onto the rail, Up onto the tabs; the rail from `首页` to the avatar and back | Bug 8: Right and Left from a card cut off by the tab bar land on `直播` and `影视`. Bug 10: Right onto a card cut off at the top and Left onto one cut off at the bottom leave it cut off. Bug 9: Down from a tab lands on the row's first card, after leaving from another card and with no card to return to |
| 我的, four sections | Down and Up through every section as the page scrolls (bug 1), a row walked to its end and back (bug 5) | Bug 7: with 观看记录 scrolled sideways, Up from `首页` skips search |
| User page | A tab's list walked down and up as the header folds away | Bug 6: Up from the first row stays there |
| Settings | The categories end to end; `SelectDialog` and `SliderDialog` opened, walked and closed with Back onto their tiles | Bug 9: Left from a setting lands on the category level with it, not the one it came from |
| 稍后再看 | Columns, and Right onto a card's `×` | Bug 4: Up from a `×` in the right column lands on the left card of its row. Bug 2: Down from the last card doesn't reach `播放全部` |
| Video page, split view | The quick strip, the introduction's actions, Right into the related list, Up onto its tabs | Bug 3: Right from a related card doesn't reach its `⋮` |
| Comments | The first layer and its actions, `评论详情` and `对话列表` opened from it, Back to each trigger | Bug 2: Down from the last comment doesn't reach the reply button |
| Player HUD | `播控` opens it, the D-pad walks its pills and the progress bar, Back closes it | None |

* **The Three Moves From `<physical-tv>`**, decided with the user:
  * Right from a top-row card half under the tab bar went to `影视`: wrong, reproduced in the scene, and it's bug 8. The rule measures the card by its whole rect, and a tab just past the card's edge counts as nearer than the next card.
  * Down from `影视` went to the left column: wrong by the user's decision. Down should return to the card focus left the grid from, and with nothing to return to, go to the card under the tab. It's bug 9, M13.4's column memory, and the same rule makes Left in settings return to the wrong category.
  * One Left from the grid went to the rail: not reproduced. In the scene, Left steps one column at a time, also from a card cut off at either edge, and reaches the rail only from the first column. That path passes.
* **Found While Recording**:
  * **Bug 10**: Left and Right onto a card cut off along its vertical list don't reveal it, the vertical counterpart of bug 5. `M13.0b` deliberately left Left and Right with one policy.
  * **Bug 7's likely cause**: the scene reproduced it. The first card of the row scrolled sideways sits under the rail, at x −114 to 66, over search and the bell, and `_filterOutEmbeddedSecondaryActions` drops a small button inside any candidate's rect before the off-screen card itself is dropped. Not proven on a device.
* **Steps With More Than One Right Landing**: Up from a card that every tab sits over (any tab); Up from the user page's first row (the tab focus left from, or the tab that's showing); Up from a `×` in bug 4 (the `×` or the card above); Back from the HUD (the strip's first pill, as today, or its trigger `播控`).
* **Kept as Today, by Design**: a second-layer sheet puts focus on its close button first, as M9 decided. `SelectDialog` lands on its first option, so the path selects the first value, where the first and the chosen option are the same. Neither is in the inventory.
* **Checks**: `flutter test --no-pub test/tv_navigation_test.dart test/tv_player_hud_test.dart test/tv_paths_test.dart` passes 144; no line of an existing test changed, only lines added to `tv_player_hud_test.dart`. The TV analyze step, with the two new files added, finds no issues. CI's `tv-checks.yml` now analyzes and runs them.
* **Limits**: the scenes copy the pages' layout; they aren't the pages. A path can pass in a scene and fail on the device if a page differs, as bug 7's two runs show. No device run was needed or done.
* **Next**: `M13.4` (scoring function and column memory behind a flag), on the user's go-ahead.

---

### [2026-11-04] Milestone M13 (Task `M13.4`): Scoring Function & Column Memory, Behind a Flag
* **Status**: ✅ Done. Under the new scorer all 25 recorded paths pass with no known failures, and all 119 older tests pass unchanged. The rule chain stays the default and still passes with the 13 known failures. 152 TV tests pass under each scorer: the 144 from before and 8 new ones. On `<vm-tv>`, `decide` p90 under the scorer is 1.46 ms on home and 1.12 ms in settings, under the 1.75 ms stand-in for the budget. The TV analyze step finds no issues.
* **Branch**: `claude/tv-m13-4-scorer-3c490b`, on top of `main` after PR 18 (`M13.3`). It lands through its pull request, and landing it publishes a release.
* **Files Changed**: `[NEW] lib/tv/tv_focus_scorer.dart` (a part of `tv_navigation.dart`); `[MODIFY] lib/tv/tv_navigation.dart` (lines added only: the flag, the dispatch in `inDirection`, the bug 10 reveal, the overlay), `test/tv_path_harness.dart` (`walkPath` ignores `known:` under the scorer), `test/tv_paths_test.dart` (lines added only), `.github/workflows/tv-checks.yml`, `docs/tv/README.md`, `docs/tv/README.en.md`, `docs/tv/M13_BASELINE.md`, `docs/tv/PLAN.md`, `docs/tv/PROGRESS.md`. `tv_player_hud.dart` isn't touched.
* **The Flag**: `TvFocusTraversalPolicy.scorer`, `TvFocusScorer.rules` or `TvFocusScorer.scored`. It defaults to `rules`, unless a build or test run passes `--dart-define=TV_FOCUS_SCORER=scored`. Tests can set it while the app runs. `inDirection` builds the same candidate list for both and hands it to one or the other, so the timing probe's `decide` covers both. Recovery, first focus and the reconcile loop are unchanged. M13.5 adds the hidden switch.
* **The Snapshot**: built once per decision from the candidates `inDirection` already collects. Each candidate gets:
  * **Its rect.** Along a list it shares with the focused node it keeps its whole rect, because it gets scrolled into view. Along any other list, or with no list, it must show as the rule chain asks (its centre inside, or half the list), and is clipped to that list and the screen. A node that doesn't show is dropped first, before anything else looks at it.
  * **Its lists and its role.** An action belongs to the card or tile it's inside in the focus tree. A small action also belongs to the visible part of a card it's laid over.
  * **The focused node's own measure.** It's measured by its visible part, so a card cut off by its list no longer reaches into the tab bar.
* **The Score** (lower wins), over candidates past the focused node. A candidate sharing more than half its height with the focused node (its width, for Left and Right) is level with it, so it doesn't count as above or below.
  * **The terms**: the gap along the move; the gap across it; how much of the narrower rect misses the other (weight 100 on Up and Down, 600 on Left and Right, where a level node comes first as in the rule chain); 1,000 for each group around the focused node that the candidate isn't in; and a small tie-break. The tie-break is reading order for a candidate wholly under a wider focused node on Up and Down, so a header leads to the start of its row; otherwise it's the offset between centres.
  * **What's left out**: actions of other cards.
  * **A floating control**: one over the focused list (in neither that list nor a list nested in it) counts as lying just past the list's end, so it's reached once nothing in the list is left in that direction.
  * **Up inside the focused list**: measured by scroll order, so a pinned or floating header is placed where it sits in the list, as in the rule chain.
* **Moves Inside a Tile or Card**: kept as the rule chain makes them.
  * Right from a tile reaches its trailing control, and Left comes back.
  * Left and Right move between a card's buttons, and Left from the first returns to the card.
  * Right from a card reaches its own buttons only when nothing lies past it. A `⋮` laid wholly over its card counts as one of them, as in `VideoCardH`.
* **Column Memory**: per group, for lists and tab bars. A group is a list the user can scroll, a `TabBar`, a `NavigationRail` or a `FocusTraversalGroup`. All of them count in the cost of leaving, but only lists and tab bars keep a memory. The plan named lists and `FocusTraversalGroup`. The tab bar was added because the user page's tab bar isn't a list. The rail was added because leaving it has to cost, or Up from `首页` goes to a card up and to the right.
  * **No memory for the rail**: on `<vm-tv>` the rail remembered the avatar, which has focus at start-up. So every Left from the grid went to the avatar, and the timing run parked there, where Left and Up do nothing. The overlay showed it. The rail is a menu, so Left now lands level with the card, as in the rule chain and M13.3's home path. A `FocusTraversalGroup` keeps no memory either.
  * **Saving**: at each scored decision, every group around the focused node remembers it.
  * **Restoring**: when the winner is in groups the focused node isn't in, the outermost of them is checked. If it remembers a node that's still a candidate in this direction and shows on screen, that node wins instead.
  * **What it doesn't see**: memory is written only on D-pad moves, not on Select, touch or recovery.
* **Bug 10**: on Left and Right, under the scorer, `_focusNode` reveals a second time along the vertical list, with the policy for its other end, as `M13.0b` does for rows on Up and Down. It's skipped for a node taller than the list, so tall cards and pinned headers keep the one policy.
* **How Each Bug Is Fixed**:

| Bug | What fixes it |
| :--- | :--- |
| 2 | A floating control counts as just past the end of the list under it |
| 3 | A `⋮` laid wholly over its card counts as the card's own |
| 4 | A candidate level with the `×` isn't above it |
| 6 | No rule asks for a target's list to be above or below the focused one |
| 7 | A card scrolled out of its row is dropped before it can own the rail's buttons, and it owns only by its visible part |
| 8 | The focused card is measured by its visible part, and leaving the grid costs |
| 9 | Column memory, and the centre offset when there's nothing to return to |
| 10 | The second reveal on Left and Right |

* **The Debug Overlay**: `--dart-define=TV_FOCUS_SCORES=true` (or `TvFocusTraversalPolicy.debugRecordScores` in a test) keeps each decision in `debugLastDecision`. A second `CustomPaint`, under the ring so the ring stays the last painter, outlines each candidate with its score, or with why it was dropped: `off` (doesn't show), `dir` (not in the direction) or `sec` (another card's action). The winner is green, and marked `(memory)` when memory chose it. Without the define it isn't built, and the scorer keeps no scores. With it on, all 151 tests still pass under the scorer.
* **Tests**:
  * The given command passes under the rule chain. The same command with `--dart-define=TV_FOCUS_SCORER=scored` passes under the scorer, where `walkPath` drops each `KnownFailure`. CI runs both.
  * Eight new tests in a `scorer and column memory (M13.4)` group in `tv_paths_test.dart`. One checks that the rail keeps no memory, so Left from the grid lands level with the card after focus left the rail from the avatar (it fails without that change). The others are: switching the flag while the app runs; memory kept while moving along the tabs; memory skipped once its card is scrolled out of view; Left back to the category after moving down the page beside it; Up back to the tab in a tab bar that isn't a list; the overlay's data and painter; and a list nested in the focused list, entered in order rather than passed over like a floating button (it fails without that check). No existing test line changed. The harness's `walkPath` changed so it can drop known failures.
* **Mutants**, under the scorer, one at a time, each run against all the TV tests. All 15 fail at least one test: the focused node unclipped; ownership by whole rects; no memory; no floating controls; no level rule; every `⋮` counted as the card's own; no tab bar or rail groups; every group costing; Up not by scroll order; the Left and Right overlap weight at 100; no cost for leaving; no bug 10 reveal; no reading-order tie; no own-button fallback; no moves between a card's buttons.
* **Three Older Tests Shaped the Weights**: none had to change.
  * The account dialog needed the nearest row to beat a far node that overlaps, so the overlap weight on Up and Down is 100.
  * A reply card's header isn't a button, so Right from a card looks only at its buttons, as in the rule chain.
  * A floating sort header in the comments needed scroll order on Up and the level-first weight on Left and Right.
* **Decided While Building, to Check With the User**:
  * **The home grid's `⋮` stays out of reach.** `VideoCardV`'s `⋮` hangs past the card's corner, and M13.3's home path records Right from the last column as staying put, so only a `⋮` wholly over its card counts as the card's own. The related list's `VideoCardH` `⋮` is reached (bug 3).
  * **With no memory, Up from the user page's first row lands on its first tab (`主页`).** It doesn't land on the one that's showing. The path allows either the tab focus came from or the showing one, and with memory it gets the one focus came from.
* **Speed**, measured locally in the widget tests (JIT, on the development Mac), so these are relative only. Each decision was run 20 times in place over every path and older test, with both scorers.
  * The scoring step itself takes 11–17 µs at p50 and 40–54 µs at p90, against 3–9 µs and 15–32 µs for the rule chain.
  * All of `decide` takes 202–463 µs at p50 and 737–857 µs at p90 under either scorer, by test file. The two scorers differ less than runs of the same one.
  * So the scorer adds a few percent to `decide`. Nearly all of `decide` is the walk over the scope's nodes before either scorer runs, which M13.4 didn't change. M13.4 isn't the speed fix the budget asks for: the comments run's `decide` p90 of 7.65 ms on `<physical-tv>` would need that walk made cheaper.
* **Limits**: the weights were tuned on the recorded scenes and the older tests, which copy the pages but aren't the pages. M13.5's device pass is where a page that differs would show.
* **Timing on `<vm-tv>`**: the user's go-ahead came after the commits above. Two `-Pdev` release builds of this branch with `tool/tv_m13/logging.patch`, the same source with and without `--dart-define=TV_FOCUS_SCORER=scored`, installed in turn.
  * Home ran in B-A-A-B order twice, eight runs of 120 s with M13.0's keys. Settings (音视频设置, the right pane) ran B-A-A-B, four runs of 90 s. Each home run started from a fresh launch with the ring on the first card, and each settings run on `CDN 设置`, each checked by screenshot. `decide` in ms:

| Run | Scorer | Steps | Mean | p50 | p90 | p99 |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| Home | Rule chain | 657 | 1.096 | 1.14 | 1.49 | 1.78 |
| Home | Scorer | 650 | 1.005 | 1.01 | 1.46 | 2.23 |
| Settings | Rule chain | 338 | 0.815 | 0.80 | 1.09 | 1.41 |
| Settings | Scorer | 337 | 0.874 | 0.87 | 1.12 | 1.55 |

  * Run means on home: rule chain 1.138, 0.957, 1.128, 1.165; scorer 1.099, 0.977, 0.955, 0.988 (permutation test, p = 0.14). In settings: rule chain 0.823, 0.808; scorer 0.884, 0.864 (p = 0.33, the smallest possible with two runs each). Neither difference is clear of the noise. M13.2 measured home at p90 1.27–1.28 ms in its session, so the session moves the numbers about as much as the build does. `engine` per frame is 12–26 µs in every run.
  * Both are under the 1.75 ms stand-in for the budget's 6 ms on `<physical-tv>`. Comments and the video page weren't timed, because they need a video open. That's where the budget fails today, and M13.4 doesn't change the shared walk that dominates there.
  * A first scorer run (discarded) found the rail's memory problem above. After the fix the scorer moved on 162–164 of the run's keys, against 163–166 for the rule chain.
  * **On the device**: only arrow keys away from navigation. Select was pressed on the 我的 rail item, the gear and 音视频设置, each after a screenshot. No video was played and no setting changed. The old rules can't go Up from 我的's user card to the header buttons (the gear row), so they were reached from the top of the rail. That's a case like bug 6 that the scorer handles; it isn't in the inventory.
  * `PiliPlus TV dev` is left on a build of this branch without the probe, with the rule chain as default. The emulator was synced and stopped.
* **Timing and Walks on `<physical-tv>`**, at the user's request, on 32-bit `-Pdev` release builds of the same source as on `<vm-tv>`, with the probe. Thermal status was 0 throughout. The same orders, keys, starts and screenshot checks as on `<vm-tv>` were used. `decide` in ms:

| Run | Scorer | Steps | Mean | p50 | p90 | p99 |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| Home | Rule chain | 619 | 3.285 | 3.33 | 4.07 | 4.79 |
| Home | Scorer | 609 | 3.467 | 3.36 | 4.28 | 6.64 |
| Settings | Rule chain | 316 | 2.316 | 2.28 | 2.86 | 3.20 |
| Settings | Scorer | 316 | 2.458 | 2.44 | 2.95 | 3.52 |

  * **Home run means**: rule chain 3.294, 3.268, 3.289, 3.288; scorer 3.513, 3.427, 3.428, 3.499. Every scorer run is slower than every rule-chain run (permutation test, p = 0.03, the smallest possible with four runs each). So on the TV the scorer costs about 0.18 ms a decision, 5–6 %, which `<vm-tv>`'s noise hid. Settings shows the same direction (+6 % mean). `engine` per frame is 60–83 µs in every run.
  * **Against the budget**: `decide` p90 stays under 6 ms on both screens, and p99 under 16.7 ms. The rule chain's home p90 today is 4.07 ms, against 3.48 ms on the M13.0 bench day, so the TV runs slower today than then. Comments and the video page weren't timed: they need a video open, and the comments run is where `decide` misses the budget today.
  * **Where the extra time likely goes**: the scorer walks the focused node's and the winner's ancestors to the root to find their groups, and looks up group rects per candidate. That's a lead for M13.5, not measured.
  * **Walks** on the scorer build, with a screenshot after every key (28 keys over two walks, from a fresh start on home):
    * Down ×3, Up, Right ×2, Left ×2, Up, Down, Right ×4, Down, Up, across rows partly under the tab bar. Every card the ring landed on was scrolled fully into view (bug 10), and Right or Left never landed on a tab (bug 8).
    * Right to card 0.1, Up to the tabs, then Down back to card 0.1 (bug 9). Up again, Right along the tabs to 分区, and Down still returned to card 0.1. Left ×2 to the rail landed on `search`, the rail item level with the first card, and Right returned to card 0.0. Up from card 0.1 landed on `直播`, the first tab over the card, not the one straight above it. M13.3's path allows any tab over the card.
  * **On the TV**: arrow keys only, apart from Select on the 我的 rail item, the gear and 音视频设置 (twice each), each after a screenshot. No video was played and no setting changed. The `m12` folder the run script made in the TV's temp folder was removed. `PiliPlus TV dev` is left on a build of this branch without the probe, with the rule chain as default, and stopped. The TV is on its home screen, and adb was disconnected.
* **Next**: `M13.5` (switch), on the user's go-ahead. The scorer's extra 0.18 ms on the TV is cut there, by the user's decision.

### [2026-11-05] Milestone M13 (Task `M13.5`): The Scorer Is the Default, the Old Rules Behind a Hidden Switch
* **Status**: ✅ Done. The scorer is the default, the rule chain stays behind a hidden switch, and the scorer's extra cost is cut. 159 TV tests pass under the scorer and again under the old rules, and the TV analyze step finds no issues. On `<vm-tv>` the scorer is level with the rule chain, and the device pass there passed. On `<physical-tv>` it's level in settings and on the home steps both rule sets make alike. The bench meets four of the six budget limits and misses `decide` on the comments list, as the rule chain does by more. By the user's decision M13.5 switches anyway, and `M13.5a` takes on the comments list.
* **Branch**: `claude/tv-m13-5-switch-3deaca`, on top of `main` after PR 19 (`M13.4`). It lands through its pull request, and landing it publishes a release.
* **Files Changed**: `[MODIFY] lib/tv/tv_focus_scorer.dart` (the cost cuts, the showing tab, comments), `lib/tv/tv_navigation.dart` (the default, the remote sequence, the focused node's groups in `evaluateNode`'s walk, the fit check in the reveal), `lib/tv/tv_platform.dart` (the stored switch and its toast), `test/tv_paths_test.dart` and `test/tv_navigation_test.dart` (lines added only), `.github/workflows/tv-checks.yml`, `docs/tv/ARCHITECTURE.md`, `docs/tv/REVIEW.md`, `docs/tv/README.md`, `docs/tv/README.en.md`, `docs/tv/PLAN.md`, `docs/tv/PROGRESS.md`. `tv_player_hud.dart` isn't touched.
* **The Switch**:
  * `TvFocusTraversalPolicy.scorer` starts from `resolveScorer`: a build's `--dart-define=TV_FOCUS_SCORER=rules` or `scored` if given; otherwise the setting `tvFocusScorer` (`rules` picks the old rules), which `TvPlatform.initialize` reads on a TV; otherwise the scorer.
  * **The hidden switch**: the remote sequence Up, Up, Down, Down, Left, Right, Left, Right, each press within 1.5 s of the last, flips the rules while the app runs, saves the setting and shows `已切换到旧的焦点规则` or `已切换到新的焦点规则`. Each press still moves focus as usual. The setting can also be set through 关于 → 导入/导出设置. The README says how, and asks anyone who needs the old rules to say why, because M13.6 removes them.
  * It's a setting and a sequence, not a build define alone, so a user of a release can switch back without a new build.
* **The Scorer's Cost**, cut with every pick unchanged. A throwaway probe (never committed) wrote each decision of every TV test to a file, the focused node and the winner by rect and label, with the decision repeated 9 or 15 times in place for its timing. The trace was the same before and after each change, under both scorers, in all three test files. Local times (JIT, on the development Mac) are relative only.
  * **Where it went** (p50 per decision, in µs, in `tv_paths_test.dart`): snapshot 3.7, roles 3.9, the focused node's groups 2.3, scoring 1.1, column memory 2.5. The roles step had the heavy tail: in `tv_navigation_test.dart` a focused button's search for its card took 3,354 of the step's 4,043 µs over the file, because it measured every focusable focus ancestor, and measuring one walks to the root.
  * **Not done as planned**: recording groups in `evaluateNode`'s walk for every node. It would add type checks to the walk over the scope's nodes for both scorers, which is most of `decide`, to save two walks of one node. Only the focused node's walk records them, and only under the scorer.
  * **The cuts**:
    * The focused node's groups come from its own walk in `evaluateNode` (`isFocusableRecordingGroups`), instead of a second walk to the root.
    * The winner's groups walk stops at the first group it shares with the focused node. Every group further out is around both, so the groups it enters are the same.
    * A focused button's card is looked for only among focus ancestors that can be a card or tile: one walk of the focused node's elements finds the outermost tile or card, and an ancestor above it, whose own widget isn't a card, is passed over without measuring it.
    * The cards a small action can lie over are listed once per decision instead of once per action, the group rects are looked up once per decision instead of once per candidate, and the per-decision map of scores is a flag on each candidate.
    * Bug 10's reveal checks whether the node fits in its own walk over the lists, instead of a separate walk first.
  * **After** (p50 / p90 per decision, µs; sum over each file):

| File | Scorer before | Scorer after | Rule chain |
| :--- | :--- | :--- | :--- |
| `tv_navigation_test.dart` | 12 / 52; 7,373 | 7 / 20; 2,926 | 3 / 31; 2,780 |
| `tv_paths_test.dart` | 18 / 42; 4,072 | 12 / 22; 2,251 | 8 / 22; 1,894 |
| `tv_player_hud_test.dart` | 12 / 44; 1,643 | 8 / 22; 993 | 4 / 14; 518 |

  * By part (`tv_paths_test.dart`, p50): the groups step went from 2.3 to 0.3 µs, memory from 2.5 to 1.1 and scoring from 1.1 to 0.5. The roles step lost its tail (3,354 µs over the navigation file to about 1,280 for the whole step).
  * Bug 10's reveal, which runs inside `decide` on every Left and Right under the scorer (7 of the 11 home keys), took 7 µs at p50 and 16 at p90 per step, against 1 µs with no reveal. The fit check was about 2 µs of that. Folding it into the reveal cut its total by 30 %. Skipping the reveal when it would do nothing isn't done: a pinned header scrolls even when wholly on screen, and telling those apart costs the render walk the reveal makes anyway.
  * **Mutants**, each run against all the TV tests: skipping every owner ancestor, the focused node's walk recording no lists, the fit check inverted, and the containers taken at their whole rect each fail. The winner's walk stopping at its first group passed every test at first: no test entered two nested lists at once. A new test covers it, and it fails now.
* **The Showing Tab** (the user's decision): with nothing to return to, focus coming into a tab bar from one of its own pages (a `TabBarView` with the same controller) lands on the tab that's showing, if that tab lies over the focused node. Otherwise it's the tab the score picked. So Up from the user page's first row reaches the showing tab instead of `主页`. Landing on the showing tab from any page would have changed M13.3's home path, where Up from card 0.0 lands on `直播`, the tab straight above it, so the user picked the narrower rule. Down from `编辑资料` into the tabs still lands on the nearest one.
* **Not changed** (the user's decision): the home grid's `VideoCardV` `⋮` stays out of reach, as M13.3's home path records.
* **Tests**: 7 new, 159 in all.
  * In a new `switch and the showing tab (M13.5)` group in `tv_paths_test.dart`: the starting rules from a define and a setting; the remote sequence, counted only whole and in time; the sequence flipping the rules while the app runs, and back; Up from a tab's first row landing on the showing tab; and two nested lists entered at once returning to the outer one's memory.
  * In `tv_navigation_test.dart`: the setting read from a Hive box, and left unset by the TV defaults.
  * No existing test line changed. CI runs the TV tests under the scorer, then again with `--dart-define=TV_FOCUS_SCORER=rules`, where `walkPath` keeps the 13 known failures.
* **Timing on `<vm-tv>`**: two `-Pdev` release builds of this branch with `tool/tv_m13/logging.patch`, the same source with and without `--dart-define=TV_FOCUS_SCORER=rules`, installed in turn. Home ran in B-A-A-B order twice (scorer first), eight runs of 120 s with M13.0's keys, each from a fresh launch with the ring on the first card. Settings (音视频设置, the right pane) ran B-A-A-B, four runs of 90 s, each started on `CDN 设置`. Every start was checked by screenshot. `decide` in ms:

| Run | Rules | Steps | Mean | p50 | p90 | p99 |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| Home | Rule chain | 659 | 1.012 | 0.99 | 1.49 | 2.01 |
| Home | Scorer | 652 | 0.962 | 0.95 | 1.46 | 2.11 |
| Settings | Rule chain | 339 | 0.811 | 0.76 | 1.20 | 1.87 |
| Settings | Scorer | 338 | 0.820 | 0.78 | 1.21 | 1.72 |

  * Run means on home: rule chain 1.077, 1.030, 0.916, 1.029; scorer 0.964, 0.945, 1.012, 0.928 (permutation test, p = 0.26). In settings: rule chain 0.831, 0.790; scorer 0.831, 0.810 (p = 0.67). `engine` per frame is 17–33 µs in every run. Both are under the 1.75 ms stand-in, and the difference is inside the noise, as in M13.4. Only `<physical-tv>` showed M13.4's cost, so it decides.
* **Device Pass on `<vm-tv>`**, on a clean `-Pdev` release build of this branch (the scorer, no probe), with a screenshot after every key:
  * **Home**: Down ×3, Up, Right ×2 and Left ×2 across rows partly under the tab bar landed on whole cards and never on a tab (bugs 8 and 10). From a fresh start the ring is on the avatar, and Right lands on `直播`, the tab level with it. After a start through `直播`, Up from card 0.1 returned to `直播` (memory), Right ×2 along the tabs reached `热门`, and Down returned to card 0.1 (bug 9). Left ×2 reached the rail's `search`, the item level with the card, Right returned to card 0.0, and Up returned to `热门`. From a start through the rail, with no tab remembered, Up from card 0.1 landed on `推荐`, the showing tab, which lies over that card.
  * **我的**, with all four `我的页卡片` sections on (a setting put back afterwards): Down walked every section. With `观看记录` scrolled five cards sideways, Down returned to the `稍后再看` card focus had left that row from, Left reached the rail, and Up stepped `我的`, `动态`, `首页`, search, the bell one at a time (bug 7). Right from the avatar returned to the page's last card. Up walked the page back to the user card and on to the header buttons, which the old rules couldn't do in M13.4.
  * **The user page** (Select on the user card): Down reached `编辑资料`, then the tab `收藏` and the content; Up came back through the tabs to `编辑资料`, the stats and search (bug 6).
  * **Settings**: the `我的页卡片` dialog, a slider (`查看大图质量`) and a popup (`主题模式`) each took focus when opened, and Back or `确定` returned it to the tile. Nothing was changed apart from the section setting, which is back to `我的收藏` alone.
  * **稍后再看**: Up from a `×` in the right column stayed in that column (bug 4), Down past the last card reached `播放全部`, and Up returned to the card it came from (bug 2). Back returned focus to the shortcut. No Select inside the list, and it still holds 37 videos.
  * **The switch**: the sequence on a settings page showed `已切换到旧的焦点规则`. After a restart the old rules were on (Right from the avatar went to the header row, as the rule chain does), so the setting was kept. The sequence again showed `已切换到新的焦点规则`, and after a restart Right from the avatar went to the user card again.
  * Not walked: the video page and comments (bug 3), which need a video open.
  * **On the device**: arrow keys, Select only on the 我的 rail item, the gear, 外观设置 and 音视频设置, the user card, the `稍后再看` shortcut and the dialog rows named above, each after a screenshot. No video was played. `PiliPlus TV dev` is left on the clean build of this branch, with the scorer on, and the emulator was synced and stopped.
* **Timing on `<physical-tv>`**, on 32-bit builds of the same source as on `<vm-tv>`, with the same orders, keys, starts and screenshot checks. Thermal status was 0 throughout. `decide` in ms:

| Run | Rules | Steps | Mean | p50 | p90 | p99 |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| Home | Rule chain | 618 | 3.271 | 3.32 | 4.03 | 4.68 |
| Home | Scorer | 608 | 3.361 | 3.27 | 4.13 | 6.07 |
| Settings | Rule chain | 318 | 2.416 | 2.36 | 2.90 | 3.64 |
| Settings | Scorer | 317 | 2.389 | 2.36 | 2.85 | 3.27 |

  * **Settings**, where both rule sets make the same moves (317 and 318 steps): run means 2.379, 2.452 for the rule chain and 2.368, 2.411 for the scorer (p = 0.67). M13.4 measured the scorer 6 % slower there; now it's 1 % faster, inside the noise.
  * **Home**: run means 3.279, 3.273, 3.254, 3.277 for the rule chain and 3.335, 3.372, 3.323, 3.415 for the scorer (p = 0.03), so +0.09 ms, half of M13.4's +0.18 ms. But the two don't make the same moves on home, so the means aren't like for like. On the keys both move alike, the scorer is level: Right 3.501 ms over 228 steps against 3.530 over 234, and Up 3.088 over 152 against 3.105 over 152. The rest differs: under the scorer, Down scrolls the grid under a ring that stays put 133 times (`moved=0 handled=1`, not timed), against 4 under the rule chain, and Left moves 209 times against 84, because the scorer's Left reaches the rail where the rule chain stops (220 presses with nothing to the left). Plain and scrolling steps are both a little slower, so it isn't the scroll inside `decide` either. Bug 10's reveal still runs on every Left and Right; locally it's about as long as the scoring step.
  * **p99 on home**: 6.07 ms under the scorer against 4.68, a tail from a few steps, still well under one frame.
* **Walks on `<physical-tv>`**, on the scorer build, with a screenshot after every key, from a fresh start on home: Down ×3, Up, Right ×2, Left ×2, Up ×2, Right, Down, Left ×2, Right. Every card the ring landed on was whole, with the grid scrolled to show it (bug 10), and no Left or Right landed on a tab (bug 8). Up ×2 walked back to card 0.0, Left ×2 from the second column reached the rail item level with the card, and Right returned to the card. The showing tab and the other pages were walked on `<vm-tv>` only.
* **The Bench on `<physical-tv>`** (the six M13.0 runs, on both builds the same day): written up in `M13_BASELINE.md`. Under the scorer:
  * Holds: `decide` p90 on home (4.13), settings (2.85) and the paused detail page (5.53); `decide` p99 everywhere but playing comments; `engine` (0.07–0.09); `work` p90 on settings, paused detail and paused comments (8.4, 14.1, 15.0, the last of which failed in M13.0 at 17.8); `total` p90 on plain steps (30.3, 34.8); and `total` p90 on scrolling comments at 53.4, under the 55 ms limit that M13.0 missed at 70.3.
  * Misses: `decide` p90 on paused comments, 6.58 ms against 6 (rule chain 6.72, M13.0 7.65), and `decide` p99 on playing comments, 18.22 ms against 16.7 (rule chain 19.04, M13.0 20.59). Both are in the walk over the scope's nodes, which both rule sets share.
  * **Decision** (the user, 2026-11-05): switch anyway, and add `M13.5a` to make that walk cheaper on the comments list, with its own bench, before M13 is done.
  * **How it ran**: `无痕模式` on (for this session only) before the video, `默认画质` read as `1080P 60帧` and not changed, `BV1kMxM6FECM` opened by link. It resumed near its end, so Left in fullscreen seeked back to about 28 minutes. Escape left fullscreen for the split view. Per build: the related list while playing, comments while playing, Select on `播/暂` to pause (checked with two identical screenshots 4 s apart), comments paused, the related list paused, 120 s each with M13.0's keys. The rule-chain build needed 无痕模式 again after it was installed, and it was checked by the avatar's badge.
  * **Seen on the way**: under the rule chain, Down from the `评论` tab lands on the `最热` sort button, and Up from the share button goes straight to `返回` on the player bar; under the scorer Down lands on the first comment and Up goes to the tab. Neither was timed.
* **On the TV**: arrow keys, Escape on the player, and Select only on the 我的 rail item, the gear, 音视频设置, 无痕模式, the two side tabs and `播/暂`, each after a screenshot. About 16 minutes of video played in all, in `无痕模式`, at 1080P60. No setting changed. Afterwards the clean build of this branch (the scorer, no probe) was installed, which closed the video and ended `无痕模式` (the avatar's badge was gone after a fresh start). The `m12` folder in the TV's temp folder was removed, `PiliPlus TV dev` was stopped, the TV is on its home screen, and adb was disconnected.
* **Next**: `M13.5a` (the shared walk on the comments list), then `M13.6` one release after this lands, unless the hidden switch was needed.

### [2026-11-05] Milestone M13 (Task `M13.5a`): A First Attempt at the Shared Walk, Measured Slower and Reverted
* **Status**: ✅ Done, closed after one attempt by the user's decision (2026-11-05). The attempt kept every pick but made `decide` on the comments list about 20 % slower on `<physical-tv>`, so it was reverted, and nothing of it is on `main`. The two comments limits still miss, so that part of M13's "done when" stays open.
* **Branch**: the attempt and its revert were made on top of PR 20 (`M13.5`) and never pushed. Only this entry and the status lines reach `main`, as a docs-only push, which builds no release.
* **Where the time goes**, from a throwaway probe in the widget tests (JIT, on the development Mac, relative only): the walk over the scope's nodes before either rule set runs is 95 % of `decide`, and `evaluateNode` is about 80 %. Of `evaluateNode`, about 15 % is measuring rects (`localToGlobal`). The rest is the walk itself: each candidate walks its elements to the root with about 20 type checks per element, and candidates in one list share nearly all of that walk.
* **What was tried** (one commit, with a debug `assert` that each new answer equals Flutter's own on every call in the widget tests):
  * An ancestor's render object taken from the one carried up the walk, instead of walking down from each ancestor (`Element.renderObject`).
  * Each render object's transform to the root built once per pass from its parent's, in the same order as `getTransformTo(null)`, so rects are equal to the bit.
  * Whether a render object is hidden off screen (offstage, kept alive, a page not showing) kept per render object for the pass.
  * Every decision of the TV tests picked the same node under both rule sets, all 160 tests passed, and the analyze step found no issues. A new test with two buttons on a kept-alive page failed on a broken memo and passed on the old code.
  * The local probe already showed no gain: `decide` summed over the navigation tests went from 99.2 to 102.6 ms. It was taken to the device anyway, since the TV's costs differ.
* **On `<physical-tv>`** (the user's go-ahead): A = PR 20's head, B = the attempt, 32-bit `-Pdev` release builds with the probe, run A, B, B, A. Comments only (the two limits that miss), 120 s per run with M13.0's keys, `BV1kMxM6FECM` from 27:15 in `无痕模式` at `1080P 60帧`, paused runs checked with two identical screenshots. Thermal status was 0 throughout. `decide` in ms:

| Run | Build | Steps | Mean | p50 | p90 | p99 | Run means |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| Comments paused | A (PR 20) | 421 | 5.952 | 5.93 | 6.49 | 7.13 | 5.999, 5.906 |
| Comments paused | B (attempt) | 419 | 7.059 | 6.97 | 7.67 | 8.86 | 6.997, 7.122 |
| Comments playing | A (PR 20) | 375 | 9.774 | 9.25 | 13.40 | 18.03 | 9.583, 9.965 |
| Comments playing | B (attempt) | 374 | 11.826 | 11.38 | 15.54 | 21.53 | 11.603, 12.052 |

  * Every B run was slower than every A run: +1.11 ms paused (+19 %) and +2.05 ms playing (+21 %). The A runs after B matched the ones before, so it isn't the TV drifting.
  * **Why**, most likely: on the TV's 32-bit CPU, a hash lookup and insert per render object, and a 16-double matrix copy for each, cost more than the cheap walks and type checks they replaced. The candidates share most of their ancestors, but the first candidate of each pass still paid for every render object up to the root, and the cache lasts only one pass.
  * **Today's A** (PR 20) misses the same two limits as M13.5's bench: `decide` p90 6.49 ms paused (limit 6) and p99 18.03 ms playing (limit 16.7).
* **What's left**, both bigger than this attempt: fewer element visits, not cheaper ones.
  * **Nearest first**: under the scorer, evaluate candidates in order of their raw distance along the move, and stop once the nearest one left can't beat the best score. It has to keep floating controls, column memory and the showing tab exact, and the rule chain would keep the full walk until M13.6.
  * **Summaries per list**: walk above each list once per pass and combine the result with each candidate's walk below it. That's a rewrite of `evaluateNode`'s state machine, the most central code in the engine.
* **On the TV**: arrow keys, Escape on the player, and Select only on the 我的 rail item, 无痕模式, the `评论` tab and `播/暂`, each after a screenshot. About 9 minutes of video played in all, in `无痕模式` at 1080P60. No setting changed. The TV had gone to sleep before the first run and was woken with `KEYCODE_WAKEUP`. Afterwards the clean `M13.5` build (PR 20) was installed, which ended `无痕模式` (checked by the avatar's badge). The `m12` folder was removed, `PiliPlus TV dev` was stopped, the TV is on its home screen, and adb was disconnected.
* **Next**: `M13.6` (remove the old rules), one release after `M13.5`, unless the hidden switch was needed.

### [2026-11-05] Milestone M13 (Task `M13.6`): The Old Rule Chain and Its Hidden Switch, Removed
* **Status**: ✅ Done. The scorer is the only way a D-pad target is picked. The old rule chain, the hidden switch and CI's run under the old rules are gone. Every decision of the remaining TV tests picks the same node as on `main` before, 153 TV tests pass, and the TV analyze step finds no issues.
* **When** (the user's decision): right after `M13.5` shipped as `v2.2.0.2-fork.5950`, the one release that carries the switch. Nobody needed it, so the next release ships the scorer alone.
* **Branch**: `claude/tv-m13-6-remove-rules`, on top of `main` after `M13.5a`'s docs. It lands through its pull request, and landing it publishes a release.
* **Files Changed**: `[MODIFY] lib/tv/tv_navigation.dart` (about 740 lines out), `lib/tv/tv_focus_scorer.dart` (the `TvFocusScorer` enum; comments), `lib/tv/tv_platform.dart` (the stored switch and its toast), `test/tv_path_harness.dart`, `test/tv_paths_test.dart`, `test/tv_player_hud_test.dart`, `test/tv_navigation_test.dart`, `.github/workflows/tv-checks.yml`, `docs/tv/ARCHITECTURE.md`, `docs/tv/REVIEW.md`, `docs/tv/README.md`, `docs/tv/README.en.md`, `docs/tv/PLAN.md`, `docs/tv/PROGRESS.md`. `tv_player_hud.dart` isn't touched.
* **Removed**:
  * **The rule chain**: `_findVerticalCandidate`, `_pickFromClosestRow` (with `preferLeadingOnRow` and `adjacentColumnSpans`), `_findHorizontalCandidate` (with `embeddedCardActionFallback`), `_filterOutEmbeddedSecondaryActions`, and the dispatch to them in `inDirection`. `inDirection` now always hands its candidates to `_findScoredCandidate`.
  * **`enclosingWrap`**: only the old horizontal rule read it, so `evaluateNode` no longer checks each ancestor for a `Wrap`.
  * **The switch**: `TvFocusScorer`, `TvFocusTraversalPolicy.scorer` and `resolveScorer`, the remote sequence (`TvSwitchSequence`) and its toast, the `TV_FOCUS_SCORER` define, and `TvPlatform`'s reader and writer for the `tvFocusScorer` setting. A value left in a user's settings is no longer read; it does nothing. Bug 10's second reveal and the focused node's group recording, which ran only under the scorer, now run always.
  * **CI**: the second test run, with `--dart-define=TV_FOCUS_SCORER=rules`.
* **Kept**, because recovery and first focus use them too: `_isEmbeddedSecondaryOf`, `_isPrimaryContainer`, `_isEmbeddedSecondaryOfFocusableAncestor`, `_preferPrimaryInitialCandidates`, `isVisibleInEnclosingScrollables` and the visibility helpers. The scorer's debug overlay (`TV_FOCUS_SCORES`) stays.
* **Proof**: the throwaway probe from M13.5 wrote every decision of the TV tests, the focused node and the winner by rect and label, on `main` and on the branch. All 565 decisions of the remaining tests are the same, in the same order. The 20 missing from the branch are the removed tests' moves: 4 from the flag test and 16 from the remote sequence's.
* **Tests** (the user agreed to change existing test lines for this task):
  * **Removed** (6): the flag picking the rules while the app runs; the starting rules from a define and a setting; the remote sequence counting only whole and in time; the sequence flipping the rules while the app runs; and, in `tv_navigation_test.dart`, the setting read from a Hive box and left unset by the TV defaults.
  * **Known failures**: the 13 recorded paths that the old rules got wrong lose their `KnownFailure` markers and are titled `[bug N]` instead of `[known failure: bug N]`. They pass as before. The harness's `walkPath` drops its `known:` parameter and the `KnownFailure` class.
  * **Kept as they were**: every other test, including the M13.4 and M13.5 scorer tests, minus the lines that pinned the scorer in their groups' setup. The M13.5 group is renamed `the showing tab and nested lists (M13.5)`.
* **Tools**: `tool/tv_m13/logging.patch` still applies, with its hunks at new line offsets.
* **Not done on a device**: the change only deletes code that no build ran by default since M13.5, and every remaining decision is unchanged in the widget tests, so no device run was made.
* **M13 as a whole**: with this, all its tasks are done. One part of its "done when" stays open by the user's decision: `decide` on the comments list is over the budget on `<physical-tv>` (`M13.5a`, closed after one attempt).

### [2026-11-07] Milestone M13: Closed; M14 Prepared
* **Status**: ✅ M13 is done, by the user's decision. `M14.1` is next.
* **Files Changed**: `[MODIFY] docs/tv/PLAN.md` (Phase 5 roadmap, M13 status), `docs/tv/PROGRESS.md`.
* **Landed**: PR 21 (`M13.6`) merged on 2026-11-06 and shipped in `v2.2.0.2-fork.5962`. The run passed its TV checks. Its sync merged upstream, so the release also carries upstream's new commits.
* **Closed with one part of the bar open**: the recorded paths pass and the inventoried lost-ring cases are fixed, but `decide` on the comments list is still over the budget on `<physical-tv>` (`M13.5a`).
* **For `M14.1`** (raised by the user, not yet agreed): let the user choose which buttons sit in the HUD's top-right and bottom-right groups, from the functions in upstream's `⋮` sheet (`showSettingSheet`) and the bar buttons, with a `⋮` button that always stays and holds the rest. To be settled in the button-list discussion before any code.
* **Next** (owner: user): the `M14.1` button-list discussion, including the editable groups.

### [2026-11-07] Milestone M14 (Task `M14.1`): Approach 1, Layout and Defaults Agreed
* **Status**: 🔄 In progress. The approach, the layout and both groups' defaults are agreed. The `⋮` menu's groups and two smaller points wait for the user. No code yet.
* **Files Changed**: `[MODIFY] docs/tv/PLAN.md` (M14 rewritten, Phase 5 roadmap), `docs/tv/PROGRESS.md`.
* **Decision** (the user): approach 1, of two compared in this session.
  * **1**: change the TV pill HUD in place, with editable groups and a menu of every option.
  * **2**: M14 as planned (upstream's icon-only layout with focus labels) plus editable groups.
  * Both cost the same at run time, since a D-pad step's cost depends on how many buttons show. 2 adds looks, not features, at about twice the layout work: a rebuild of the HUD's layout, nearly all of the 87 text finders in `test/tv_player_hud_test.dart`, and a new recorded path. 1 keeps a label on every button and the key routing tested since M7; its cost is space, handled by a cap per group.
* **Agreed layout**: top left `退出全屏` and the title; top right (editable) 弹幕开关, 弹幕设置, 高能进度条, then `⋮`; a time bar with a play/pause status icon, where Select plays and pauses and Left and Right seek; bottom (editable) (上集, 下集, 选集), 画质, 字幕, 倍速, 画面, with the episode entry becoming `下个视频` (the first related video) when the video isn't in a list. The `⋮` menu groups its options by importance to a TV player and holds `编辑按钮`. Full details in `PLAN.md`.
* **From the user's review of today's HUD**:
  * The TV's 弹幕设置 dialog has five of upstream's options. Upstream's panel (`HeaderMixin.showSetDanmaku`) replaces it, which also removes the `(遥控器方向键选择)` title. Its sliders already work with the D-pad.
  * The two orange seek icons are the `⏩` / `⏪` emoji in the seek preview, drawn by Android's emoji font. They're replaced with white Material icons.
  * The time bar's `◀ ▶ 快退/快进` hint is removed.
* **Found in the code**: 高能进度条 reads `VideoDetailController.dmTrend`, which loads only with upstream's `showDmChart` setting on (default off), so the TV defaults turn it on. `下个视频` is `UgcIntroController.playRelated()`. Both are public, so neither needs an upstream edit.
* **Next** (owner: user): agree the `⋮` menu's groups and entries, the caps (4 top right, 8 bottom), and where the clock and the viewer count go. `M14.2` starts after that.

### [2026-11-07] Milestone M14 (Task `M14.1`): Second Round of Answers
* **Status**: 🔄 In progress. The `⋮` menu's groups, the label for focused icon-only buttons, and the editor's layout wait for the user. No code yet.
* **Files Changed**: `[MODIFY] docs/tv/PLAN.md` (M14), `docs/tv/PROGRESS.md`.
* **Answers** (the user):
  * **Keys with the HUD hidden**: Select plays and pauses, Left and Right seek, and holding Select gives 3x speed, as today. The time bar adds these keys while the HUD shows; they aren't limited to it.
  * **Top left**: the title only, with the viewer count below it. No `退出全屏` button, since Back already does it.
  * **Top right**: icon only, at most 4, then the `⋮` button. No clock.
  * **Bottom**: no limit, scrolling as today, with a `显示按钮文字` option set in the editor.
  * **Split screen**: the Quick Strip becomes two icon-only buttons, 全屏 and 播放/暂停. `播控` and `返回` go; the menu key still opens the full HUD there.
  * **No remote key for danmaku.**
  * **The editor's layout and UI** need their own discussion.
* **Follow-on changes**: the caps of 4 and 8 become 4 top right and none at the bottom; `全屏播放` leaves the `⋮` menu, since the Quick Strip has 全屏.
* **Next** (owner: user): the `⋮` menu's groups, the focused-button label, then the editor's layout.

### [2026-11-07] Milestone M14 (Task `M14.1`): Done
* **Status**: ✅ Done. The button list is agreed. `M14.2` is next.
* **Files Changed**: `[MODIFY] docs/tv/PLAN.md` (M14, Phase 5 roadmap), `docs/tv/PROGRESS.md`.
* **Answers** (the user):
  * **The `⋮` menu**: the five groups as proposed (播放, 弹幕, 互动, 画面与声音, 其他).
  * **Icon-only buttons**: the focused one shows its name in a small label under it, drawn over the HUD so the row doesn't re-lay out.
* **Still open**: the editor's layout and UI, a discussion of its own before `M14.3`. `M14.2` doesn't need it, since it builds the actions and panels.
* **Next**: `M14.2` on its own branch, which lands by pull request and publishes a release.

### [2026-11-07] Milestone M14 (Task `M14.2`): Actions & Upstream's Panels
* **Status**: ✅ Done on its own branch; lands by pull request. Merging it publishes a release.
* **Files Changed**: `[NEW] lib/tv/tv_hud_actions.dart`, `[MODIFY] lib/tv/tv_player_hud.dart`, `lib/tv/tv_platform.dart`, `test/tv_player_hud_test.dart`, `docs/tv/PLAN.md`, `docs/tv/PROGRESS.md` (code in `1c9cf8f12`).
* **The action table** (`tv_hud_actions.dart`, a `part` of the HUD library so it reuses the HUD's pills and option lists):
  * `TvHudActionId` holds every entry of the agreed `⋮` menu in menu order, with its group (`TvHudMenuGroup`) and whether it's pinnable. The names are the ids `M14.3` will save, so they don't change.
  * `resolveAction(id)` returns the buttons an entry stands for now: none when it isn't available (so it's hidden), one for most entries, three for the episode entry in a list. Each button has a key, `TvHudAction.keyOf(buttonId)`, for tests.
  * Upstream's panels: 弹幕设置 is `HeaderMixin.showSetDanmaku`, mixed into the HUD's state; 画质, 音质, 解码格式, 弹幕列表, 完整设置 and 字幕设置 are `HeaderControlState`'s, through `headerCtrKey`. They hide while the header isn't mounted, for offline files where upstream does, and in picture-in-picture. While a panel is open the HUD is hidden; when the panel's route is popped, focus goes back to the player as after the TV's own lists.
  * TV lists over public APIs: 字幕 (the tracks, then upstream's 字幕设置), 翻译 (`setLanguage`, which reloads the streams; shown when the video offers other languages), 倍速, 画面比例, 播放顺序 and 超分辨率 (animation only). Live quality keeps the TV list.
  * 分段信息 opens upstream's chapter panel (`ViewPointsPage`) as upstream's player does in fullscreen: Select on a chapter jumps to it, and its switch shows or hides the marks on the bar. Shown under upstream's condition (its `showViewPoints` setting on and the video has chapters).
  * The episode entry: 上集 / 下集 / 选集 in a list, `下个视频` (`UgcIntroController.playRelated()`) outside one, nothing for a PGC without a list, an offline file or a live room.
  * 高能进度条 shows once the trend data has loaded and switches `showDmTrendChart`; `SettingBoxKey.showDmChart: true` joins the TV defaults so the data loads. Drawing the chart is `M14.3`.
  * 播放器音量, 定时关闭 and 播放信息 open upstream's dialogs; 重载视频 reloads the video, or refreshes a live room.
  * 编辑按钮 is in the table but never available until `M14.3` builds the editor.
* **The HUD now**: the bottom row is still the old one (play/pause, 全屏播放, then the actions), drawn from the table with 字幕 added, until `M14.3` rebuilds the layout. The TV's own danmaku dialog and its `(遥控器方向键选择)` title are gone, and so is its video-quality list. Actions with no button yet (高能进度条, 弹幕列表, 音质 and the rest) are reachable once `M14.3` adds the `⋮` menu.
* **Verification**:
  * TV analyze clean (the CI file list); `test/tv_navigation_test.dart`, `test/tv_player_hud_test.dart` and `test/tv_paths_test.dart`: 183 tests pass, SDK patches applied.
  * 32 new tests in `test/tv_player_hud_test.dart`: one per action (when it's available and what it does), the table's order, the new TV default, and two D-pad tests in the recorded-path scene: 弹幕设置 opens upstream's real panel with focus on its first slider, Down stays inside it, and Back returns focus to the Quick Strip; 画质 does the same through a recorded stand-in for `showSetVideoQa` that opens the same kind of route. The 画质 and old danmaku-dialog tests are replaced; the finders this task touched use keys.
  * No device run: none was needed for the done bar, and `M14.4` has the device pass.
* **Added during the task** (the user): upstream's AI 翻译 and 分段信息 buttons, in the 播放 group as 翻译 and 分段信息. They aren't in the HUD's bottom row; they're reachable once `M14.3` adds the `⋮` menu.
* **Next**: the editor's layout (owner: user), then `M14.3`.

### [2026-11-07] Fix: the D-pad couldn't reach the soft keyboard on `<physical-tv>`
* **Status**: ✅ Fixed on its own branch; lands by pull request. Merging it publishes a release.
* **Files Changed**: `[MODIFY] android/app/src/main/kotlin/com/example/piliplus/TvBridge.kt`, `docs/tv/PROGRESS.md`.
* **Symptom** (reported by the user): with Gboard open over a text field (Search), the D-pad moved the app's focus behind the keyboard instead of moving between its keys; the first key took focus off the field and closed the keyboard. `<vm-tv>` worked.
* **Cause**: `<physical-tv>` sets `config_preventImeStartupUnlessTextEditor` to `true` (a vendor overlay; `false` on `<vm-tv>`). Android then refuses to start a keyboard session for a focused view that doesn't report itself as a text editor (`InputMethodManagerService.shouldPreventImeStartupLocked`: the start-input returns `NO_EDITOR` and the keyboard service is unbound), and Flutter's `FlutterView` doesn't override `onCheckIsTextEditor()`. The explicit show still draws Gboard, but the app's input-method client is never bound (`mBindSequence=-1`, `Ignoring onBind: cur seq=-1`), so Android can't hand the remote's keys to the keyboard first and they go to the app. Found with `dumpsys input_method` (the TV's start-input history had no entries from this app, only Gboard's `SESSION_CREATED_BY_IME`) and by reading the TV's `framework.jar` and `services.jar`.
* **Fix**: while the keyboard is open, `TvBridge.showSoftKeyboard` gives Android focus to a 1 x 1 proxy view that reports itself as a text editor and passes everything else to the Flutter view: the input connection, Flutter's own input-method calls (`checkInputConnectionProxy`) and any key the keyboard doesn't take. `hideSoftKeyboard` puts focus back on the Flutter view. Nothing changes in Dart.
* **Verification** (2026-11-07, `-Pdev` builds, Search field only, nothing submitted): on `<physical-tv>` the client binds through the proxy, Right and Down move inside Gboard, Select types into the Flutter field, Back closes the keyboard and the D-pad moves the app's focus again, and a second open works the same; on `<vm-tv>` the same, as before the fix. Dart is unchanged, so the TV checks cover the rest.

### [2026-11-07] Milestone M14 (Task `M14.3`): Layout, Editable Groups & Editor
* **Status**: ✅ Done on its own branch; lands by pull request. Merging it publishes a release.
* **Files Changed**: `[NEW] lib/tv/tv_hud_groups.dart`, `lib/tv/tv_hud_menu.dart`; `[MODIFY] lib/tv/tv_player_hud.dart`, `lib/tv/tv_hud_actions.dart`, `test/tv_player_hud_test.dart`, `docs/tv/PLAN.md`, `docs/tv/PROGRESS.md`.
* **The editor's design** (proposed and agreed with the user before any editor code; recorded in PLAN.md, M14, Editor): a panel over the HUD with `[显示按钮文字] [恢复默认] [完成]` and the rows 右上角 n/4 (with the fixed `⋮`), 底部 and 未固定 (grouped as in the menu). Pick up and carry: Select picks a button up, Left and Right move it along its row, Up and Down move it to the end of the row above or below (into 未固定 unpins it; a full 右上角 refuses it with a toast), and Select or Back puts it down. Every change saves at once; Back or `完成` closes it; `恢复默认` asks `恢复默认按钮？` first, with focus on `取消`.
* **The layout** (`tv_player_hud.dart`):
  * Top bar: the title with `N人正在看` under it in a smaller font; the top-right group, icon-only, then `⋮`. No clock, and no `退出全屏` / `关闭面板` button.
  * The time bar is the HUD's first focus (the first bottom button in a live room). It has the play/pause status icon, the position, the bar and the duration. Select plays and pauses, holding it gives 3x and Left and Right seek, through the same handlers as with the HUD hidden; those keys are unchanged. The `◀ ▶ 快退/快进` hint and the play/pause and `全屏播放` pills are gone. The icon shows the action, as upstream's bar button does: pause while playing.
  * 高能进度条: upstream's `buildDmChart` over the bar, in its own `_TvDmChart` behind a `RepaintBoundary` and outside the bar's position `Obx`.
  * Seek preview: white Material `fast_forward_rounded` / `fast_rewind_rounded` in place of the emoji.
  * Quick Strip: icon-only 全屏 and 播放/暂停 (showing the current state), both with Hold-Select 3x as before. `播控` and `返回` are gone; the menu key opens the HUD.
  * Icon-only buttons (the top right, the Quick Strip, and the bottom row with `显示按钮文字` off) draw their name under them through an `OverlayPortal` while focused. Pills now keep their size when focused (the padding gives back the wider border's pixel), so neither the label nor the focus ring moves the row.
* **The groups** (`tv_hud_groups.dart`): `TvHudGroups` holds both lists and `显示按钮文字`, saved in the settings box under the TV-only keys `tvHudTopRight`, `tvHudBottom` and `tvHudShowLabels` and read each time the HUD opens. Ids that are unknown, not pinnable or already pinned are skipped, and the top right keeps its first 4. A missing list falls back to the agreed default; a saved empty list stays empty. The groups are an `Rx`, so a group's `Obx` always has something to listen to (a bottom row of 倍速 alone reads no other `Rx` and made GetX throw).
* **The `⋮` menu and the editor** (`tv_hud_menu.dart`): both open as dialog routes over the HUD, which stays visible behind them with its auto-hide paused. The menu is a panel on the right with every available entry under its group header, 翻译 and 分段信息 included; choosing an entry closes the menu and runs it, and focus returns to `⋮` once the dialog's route has finished closing (before that, the route below restores its own last focus). 编辑按钮 now opens the editor. The editor and its confirmation ask for their first focus explicitly, because the engine's first-focus pick skips buttons in a scroll view that hasn't laid out yet.
* **Verification**:
  * TV analyze is clean over the CI file list. `test/tv_navigation_test.dart`, `test/tv_player_hud_test.dart` and `test/tv_paths_test.dart`: 191 tests pass, with the SDK patches applied. `flutter pub get` was needed first, because upstream's sync bumped `nativeapi`.
  * The tests that relied on the old layout were moved to keys: the time bar, the Quick Strip, the seek preview and its icons, and the top bar (the R19 clock test became the top-bar layout test). New tests: the saved lists (unknown, unpinnable and repeated ids, the cap, empty lists, the defaults); both groups drawn from saved lists with `⋮` last; `显示按钮文字` off with the focus label and a row that doesn't move; the time bar's keys and the chart; the `⋮` menu (groups in order, 翻译 and 分段信息, auto-hide paused, focus back on `⋮`); the editor's carry moves, the top-right cap, Back while carrying and a restart; and `显示按钮文字` and `恢复默认` (取消 first) across a restart.
  * Recorded HUD paths, updated: the split view's Quick Strip; the default layout (menu key → time bar → bottom row → top right → `⋮` menu → Back → Back); and a custom layout (labels off, 点赞 and 收藏 pinned top right). The 弹幕设置 and 画质 D-pad tests now reach their buttons from the time bar.
  * The test settings box is in memory now: the HUD saves from inside widget tests, whose fake clock never lets a file write finish, and a stuck write stalled the next test's set-up.
  * No device run. `M14.4` has the device pass (`<vm-tv>` at both UI scales and text scale 1.6, and upstream's danmaku panel on `<physical-tv>`).
* **Next**: `M14.4`. Some of its tests were done here (saving, unknown ids, the cap, `显示按钮文字`, `恢复默认`, the keys with the HUD hidden, the default and custom recorded paths); the rest of the label-text finders and the device pass remain.

### [2026-11-07] Milestone M14 (Task `M14.3`): Changes After the First Device Try
* **Status**: ✅ Done on the `M14.3` branch. That pull request was merged (released in `v2.2.0.2-fork.5998`) before these commits were pushed, so they land by a pull request of their own. Merging it publishes a release.
* **Files Changed**: `[MODIFY] lib/tv/tv_player_hud.dart`, `lib/tv/tv_hud_groups.dart`, `lib/tv/tv_hud_menu.dart`, `test/tv_player_hud_test.dart`, `docs/tv/PLAN.md`, `docs/tv/PROGRESS.md`.
* **Device try**: a `-Pdev` build of the branch (`android-arm` and `android-arm64`) was installed over `PiliPlus TV dev` on `<physical-tv>` and `<vm-tv>`, and the user tried the HUD and the editor. On `<vm-tv>` the dev app was missing again after an emulator restart (as in M13.0b), and `install -r` brought it back. Afterwards the emulator was synced and stopped, and adb was disconnected from the TV.
* **The user's requests**, each built as asked:
  * **`按钮在时间条上方`**: a new editor option (key `tvHudButtonsAboveBar`, default off) that puts the bottom row above the time bar. The time bar stays the first focus. `恢复默认` turns it off. The editor's controls now wrap under its title, so four of them fit at text scale 1.6.
  * **The top right in rows**: up to 3 rows of 6 icon-only buttons, aligned right. `⋮` takes the first row's last place, so the group's cap went from 4 to 17. The episode entry stands for up to three buttons, so a full group can spill into a fourth row.
  * **The title**: up to 3 lines, with `…` only when 3 can't hold it.
* **Verification**: TV analyze clean over the CI file list; 194 TV tests pass. New or changed tests: the cap of 17 in the saved lists and in the editor (an 18th is refused); the rows (five buttons and `⋮` in the first, right edges aligned); `按钮在时间条上方` from the settings box and from the editor, with Up and Down between the buttons and the bar; a long title on exactly 3 lines with an ellipsis, and a short one on 1. No device run after these changes.

### [2026-11-07] Milestone M15: Task `M15.2` Added
* **Status**: ⏳ Planned. No code.
* **Files Changed**: `[MODIFY] docs/tv/PLAN.md` (Phase 5 roadmap, M15), `docs/tv/PROGRESS.md`.
* **The request** (the user): a SuperChat can't be closed with the remote. On a phone it's swiped away; on the TV it stays until it expires.
* **Found in upstream's code**:
  * SuperChats exist only in live rooms; normal videos don't have them.
  * In fullscreen with `全屏 SuperChat` on, the card is `LiveRoomController.fsSC`. It shows for up to 10 s, and its only close control is a touch `×`.
  * In split view, the chat and the SuperChat list are two pages of a `PageView`.
* **Next**: settled with the rest of the live HUD in `M15.1`, after M14.

### [2026-11-07] Fix: the TV defaults came back only after a cold start, following a settings reset
* **Status**: ✅ Fixed on the `M14.4` branch; lands with its pull request. Merging it publishes a release.
* **Files Changed**: `[MODIFY] lib/tv/tv_platform.dart`, `test/tv_navigation_test.dart`, `docs/tv/PROGRESS.md` (`29aabcee6`).
* **Asked by the user**: whether upstream's 关于 → 重置所有设置 (`重置可导出的设置`, which keeps the login, and `重置所有数据`) loses the TV defaults, and whether a reset should restore the TV defaults or reset everything and then apply them again.
* **Found**: both options clear the `setting` box and don't restart the app. `TvPlatform` only seeds missing TV defaults at a cold start, so until then the running app read upstream's defaults: 8K for `defaultVideoQa` (the TV default is 1080P 60帧, because 4K freezes or panics `<physical-tv>`), `showDmChart` off, `autoUpdate` on, the system theme. Upstream's getters for `horizontalScreen` and `fullScreenMode` also write a phone or tablet value the first time they read a missing key, and the launch seed never overwrites a key that's set, so those two were lost for good.
* **Fix** (reset everything, then apply the TV defaults again at once): `TvPlatform.watchForResets` watches the setting box. Hive's `clear()` sends a delete event for every key, so as soon as a TV default is deleted, the missing TV defaults are filled in, before upstream's getters can write their own. Hive marks a key as present as soon as a write starts, so an import (`导入设置` clears the box, then writes its map) keeps its own values, and only the TV defaults it lacks come back. No upstream file changed.
* **Verification**: two new tests (a reset puts every TV default back, and deleting another key does nothing; an import keeps its values and gets only the missing TV defaults). TV analyze clean; all TV tests pass.

### [2026-11-07] TV: Back on the Home Tab Asks First; 重启应用 in 关于
* **Status**: ✅ Done on the `M14.4` branch; lands with its pull request. Merging it publishes a release.
* **Files Changed**: `[NEW] lib/tv/tv_app_exit.dart`; `[MODIFY] android/app/src/main/kotlin/com/example/piliplus/TvBridge.kt`, `lib/pages/main/view.dart` (one-line hook), `lib/pages/about/view.dart` (one-line hook), `test/tv_navigation_test.dart`, `docs/tv/PROGRESS.md` (`7ac31f326`).
* **The request** (the user): the TV app had no way to exit or restart. Upstream's Back on the home tab only shows the launcher (`AndroidHelper.back()`), the process keeps running, Android TV has no recents screen to close it from, and some settings say `重启生效`. The user chose: Back on the home tab opens `返回桌面` / `退出应用`, and `重启应用` goes into 设置 → 关于.
* **Built**:
  * `TvAppExit.handleHomeBack()`, called first in upstream's `_onBack` (`lib/pages/main/view.dart`). Off a TV it returns `false` and upstream's Back runs. On a TV it opens `退出 PiliPlus？` (`返回桌面时应用继续在后台运行`) with focus on `返回桌面`, so a stray Back does no harm; Back closes it, and a second Back while it's open doesn't stack another.
  * `TvAppExit.restartTile`, the last row of 关于 on a TV (`if (TvPlatform.isTv)` in `lib/pages/about/view.dart`). It asks `重启应用？` with focus on `取消`.
  * `TvBridge`: `goHome` (upstream's HOME intent), `exitApp` (`finishAndRemoveTask()`, then the process ends) and `restartApp` (the launch activity in a new task via `Intent.makeRestartActivityTask`, and the process ends at once, so Android starts it in a fresh process).
* **Verification**: four new tests (off a TV upstream's Back runs; the dialog with focus on `返回桌面`, no second dialog, `goHome`; Back closes it, `退出应用`, and the dialog closing if Android can't end the app; `重启应用` asks with focus on `取消`, then `restartApp`). On `<vm-tv>`: `返回桌面` shows the launcher with the same process alive, and opening the app resumes it; `退出应用` ends the process and leaves no task in recents; `重启应用` comes back on the home page in a new process, with 界面缩放 applied.

### [2026-11-07] Milestone M14 (Task `M14.4`): Tests and the `<vm-tv>` Pass
* **Status**: 🔄 In progress. The tests and the `<vm-tv>` pass are done; upstream's danmaku panel with the D-pad on `<physical-tv>` is left, so M14 stays open.
* **Files Changed**: `[MODIFY] lib/tv/tv_player_hud.dart`, `test/tv_player_hud_test.dart`, `docs/tv/PLAN.md`, `docs/tv/PROGRESS.md` (`8dcbc71eb`, `f2124e218`).
* **Tests** (`8dcbc71eb`): the TV option lists (倍速, 画面比例, 选集, 字幕, 翻译, 播放顺序, 超分辨率) got `TvPlayerHud.optionListKey` and `optionItemKey(i)`. The tests now find HUD buttons by `TvHudAction.keyOf` and option rows by index, check focus by key (the `_pill` / `_pillHasPrimaryFocus` label helpers are gone), and check label text only under the button's or row's key. The speed, fit and episode tests now also check the row that starts focused. 37 text finders stay on purpose: absence checks (`播控`, `退出全屏`, `⏩`), upstream's own panels (`智能云屏蔽`, the chapter list), the stand-in routes (`showSetVideoQa 0`), the test app's `GoToPlayer` button and upstream's toast. The rest of M14.4's test list was done in `M14.3`.
* **`<vm-tv>` pass** (1080p, headless, `-Pdev` arm64 build, `开启硬解` off for the run and back on afterwards). `PiliPlus TV dev` there was signed out (`点击登录`), so nothing reached an account and `无痕模式` wasn't needed.
  * At `界面缩放` 1.0 with font size 1.2 (the TV default) and 1.6, and at 0.8 with 1.6: the HUD opens on the time bar; Select pauses and the status icon follows; Down, Right and Up walk the bottom row, the time bar and the top right, with focus labels; `选集` opens on the current part and Back closes it; the `⋮` menu lists its groups and returns focus to `⋮`; upstream's 弹幕设置 opens from the top right with focus on its first slider, Down and Right stay inside it, and Back closes it; the editor carries 倍速 from 底部 to 右上角 (4/17), turns off `显示按钮文字` and turns on `按钮在时间条上方`, and the HUD redraws when it closes; `恢复默认` asks with focus on `取消`, then resets both groups and both options. Nothing in the HUD, the menu or the editor was clipped or unreachable at 1.6, and the editor's controls fit on one row.
  * After the app was reinstalled (a restart), the edited groups and both options were still there.
  * With the HUD hidden: Left shows the white `fast_rewind_rounded` preview and seeks back; Select plays and pauses. Hold-Select (3x) couldn't be checked: `adb` sends no key repeats, and a held `KEY_SELECT` from the emulator console registered as a short press. The tests cover it, as before.
  * **Found and fixed** (`f2124e218`): with `按钮在时间条上方` on and `显示按钮文字` off, the focus label was drawn under the button, over the time bar's position. It's now drawn above the button in that layout. New test: the label sits above the button and clear of the time bar.
  * **Noted, not M14**: at font size 1.6 the home page's video cards cut their title's second line (upstream's card layout).
  * The emulator stalled once after a reinstall: its graphics services ran at 100% and both the launcher and the app hit input ANRs (`Application does not have a focused window`). It was synced, stopped and started again, and the pass ran through after that. As in M13.0b, this looks like the emulator's software GPU, not the app.
  * Afterwards 界面缩放 is back at 1.00, the font size at 1.20, `开启硬解` on, the HUD at its default layout, the files the run put on the emulator are deleted, and the emulator is synced and stopped.
* **Verification**: TV analyze clean over the CI file list (plus `lib/pages/main/view.dart` and `lib/pages/about/view.dart`); 201 TV tests pass, SDK patches applied.
* **Next**: upstream's 弹幕设置 panel with the D-pad on `<physical-tv>` (the user's go-ahead and the TV's address needed); then M14 closes if its "Done when" holds.

### [2026-11-07] Milestone M14 (Task `M14.4`): Done; M14 Closed
* **Status**: ✅ Done. M14 is closed: its "Done when" holds (every agreed action works with the D-pad, pinned or from the menu; the menus open upstream's panels with focus inside; the groups and both editor options survive a restart; the keys with the HUD hidden and on the time bar; the Quick Strip as agreed). Lands with the `M14.4` pull request, and merging it publishes a release.
* **Files Changed**: `[MODIFY] docs/tv/PLAN.md` (Phase 5 roadmap, M14), `docs/tv/PROGRESS.md`.
* **`<physical-tv>` pass** (`-Pdev` `android-arm` build installed over `PiliPlus TV dev`, which is signed in; the user's go-ahead and the TV's address given in chat): `无痕模式` turned on (`仅本次`) before playing and off afterwards. In a video in fullscreen at 1080P+, the HUD opened on the time bar; Up reached the top right and `⋮` (focus label `更多`); the `⋮` menu opened on `画质`, and Down reached `弹幕设置` under `弹幕`. Upstream's 弹幕设置 opened with focus on its first slider (`智能云屏蔽`); Down moved through the `按类型屏蔽` chips and the sliders, with the panel scrolling to keep focus in view; Right and Left moved `显示区域` from 50% to 60% and back; Back closed the panel to the player. Back then left fullscreen to split view, with the two-button Quick Strip, and Back again left the page.
* **Afterwards**: no setting changed on the TV (the danmaku area is back at 50%), `无痕模式` is off, the TV is asleep (`mWakefulness=Asleep`), and adb is disconnected and stopped.
* **Next**: M15 (live HUD), once the user picks it up.

### [2026-11-08] TV: SponsorBlock Segments and Chapters on the Time Bar, 片段信息, and Select on 上次看到第XP
* **Status**: ✅ Done on its own branch; lands by pull request. Merging it publishes a release.
* **Files Changed**: `[MODIFY] lib/tv/tv_player_hud.dart`, `lib/tv/tv_hud_actions.dart`, `test/tv_player_hud_test.dart`, `docs/tv/PLAN.md` (M14, `⋮` menu), `docs/tv/PROGRESS.md` (`f8a9a08f5`).
* **Asked by the user**: whether SponsorBlock segments show on the timeline, and how skipping works on the TV. Upstream's skip modes per category: 总是跳过 and 跳过一次 skip on their own; 手动跳过 shows a `跳过: 片头` card at the player's bottom left for about 4 s, which a tap or Enter answers; 仅显示 only marks the bar and lists the segment under 片段信息. The user kept the TV's existing behavior for 手动跳过: Select with the HUD hidden in fullscreen skips while the card shows (`onSkipSegment` before play and pause). They asked for two more things, built here:
* **Built**:
  * **The time bar draws the segments and the chapters**, with upstream's own bars and under upstream's conditions: SponsorBlock's segments (and Bilibili's own PGC 片头 / 片尾, which upstream's `跳过一次` default turns on) in their category colors, 2 px under the bar (`SegmentProgressBar`, when blocking is on and the video's segments loaded); the uploader's chapters (分段信息) as a strip with their titles just over the bar, with dividers across it (`ViewPointSegmentProgressBar`, while `showViewPoints` and the chapter switch are on). Each is its own widget behind a `RepaintBoundary`, like the 高能进度条 chart, so the bar's position updates don't repaint them. Before this, only upstream's thin bottom bar showed segments, and only while the HUD was hidden.
  * **片段信息 in the `⋮` menu** (`TvHudActionId.segments`), in the 播放 group after 分段信息, and pinnable. It opens upstream's `showSBDetail`, the list of every segment (仅显示 ones too) with its skip or jump button, under upstream's condition for its header button (blocking on and segments loaded); hidden offline and in picture-in-picture. Until now 片段信息 was only in upstream's header, which the TV doesn't show.
  * **Select opens `上次看到第XP，点击跳转`** with the HUD hidden. That card shares upstream's prompt list with the 手动跳过 card, but upstream opens it only by touch, and `onSkipSegment` leaves it alone. Select now answers the oldest prompt either way: a segment skips (upstream's `onSkipSegment`, unchanged), a part number plays that part (`onChangeEpisode`, toast `已跳至第XP`); with no prompt, Select plays and pauses as before.
* **Verification**:
  * TV analyze clean over the CI file list; 206 TV tests pass. New tests: 片段信息's availability (blocking off, no segments, offline, picture-in-picture) and that it opens upstream's list with the HUD hidden; its place in the `⋮` menu after 分段信息, opened with the D-pad; Select skipping a 手动跳过 prompt instead of pausing; Select opening 上次看到第3P, then playing and pausing once the prompt is gone; the segments under the bar and the chapters over it, each hidden under upstream's conditions. The two editor tests that pinned every entry now take the first 17, since there are 25 pinnable entries.
  * `<vm-tv>` (headless, signed out, `开启硬解` off and `空降助手` on for the runs, both back afterwards): an older free 番剧 episode with no segment data showed an unchanged time bar and no 片段信息 in the menu. On `BV1uyMG6gE3W` (the user's suggestion; 16:02, three SponsorBlock segments: 音乐:非音乐部分 at 03:32 and two 无偿/自我推广 at 06:21 and 14:11), the time bar showed one orange and two yellow marks under it, at the same places as upstream's thin bottom bar; the `⋮` menu listed 片段信息 after 下个视频, and it opened upstream's list with focus on the first segment; Down and Right reached the second segment's skip button, and Select skipped it (`已跳过推广片段`, playback resumed at 06:46, the played part ending at that mark). The video has no chapters, so the chapter strip and 上次看到第XP (which needs a signed-in watch history) are covered by their tests only.
  * `<physical-tv>` (`-Pdev` `android-arm` build over `PiliPlus TV dev`, signed in, `无痕模式` on (`仅本次`) and `空降助手` on for the run, both off afterwards; the TV slept and adb disconnected at the end): `BV1uyMG6gE3W` showed the same three marks under the time bar, with the user's own layout (buttons above the bar, labels off, three top-right rows). 片段信息 was in the `⋮` menu after 下个视频; it opened upstream's list with focus on the first segment, and the second segment's skip button skipped it (`已跳过推广片段`, resumed at 06:45). Along the way one Select landed on 收藏 by mistake and opened upstream's 添加到收藏夹 sheet; it was closed with Back, nothing ticked. Selecting a row in 片段信息 (rather than its skip button) opens upstream's vote dialog, so only the skip buttons were pressed.

### [2026-11-08] Milestone M15 (Task `M15.1`): Button List & Tasks Agreed
* **Status**: ✅ Done. No code. `M15.2` and `M15.3` are next.
* **Files Changed**: `[MODIFY] docs/tv/PLAN.md` (Phase 5 roadmap, M14's live-room note, M15 rewritten), `docs/tv/PROGRESS.md`.
* **Found** (the live HUD as M14 left it): a live room resolves 画质 (the TV's live list), 画面比例, 弹幕开关, 弹幕设置, 播放器音量, 定时关闭, 重载视频, 播放信息 and 编辑按钮. The HUD is handed `onSendDanmaku` but never uses it, so fullscreen can't send danmaku. With the HUD hidden, Left and Right do nothing in a live room. The shared video defaults leave a live room with two buttons in each group. Upstream's only private live picker is `_showLiveStreamDialog` (切换路线), over public `LiveRoomController` fields and `initLiveUrl`.
* **Proposed and agreed** (the user, 2026-11-08; recorded in PLAN.md, M15):
  * The live `⋮` menu: 画质, 切换路线 (new), 画面比例; 弹幕开关, 弹幕设置, 发弹幕 (new), 屏蔽词 (new), 醒目留言 (new); 播放器音量, 定时关闭; 刷新 (重载视频's live label), 播放信息, 编辑按钮. Left out: 点赞, 仅播放音频, 画中画, 后台播放, 置顶, 完整设置.
  * The title line: the streamer's name and the viewer count under the room title.
  * Live rooms keep their own saved lists (`tvHudLiveTopRight`, `tvHudLiveBottom`); `显示按钮文字` is shared; the editor in a live room edits the live lists and hides `按钮在时间条上方`.
  * Live defaults: top right 弹幕开关, 弹幕设置; bottom 刷新, 画质, 切换路线, 画面比例.
  * 切换路线 as one TV option list grouped by `协议 · 格式`, saving `SettingBoxKey.liveStream` as upstream does.
  * `M15.2`: Back closes a fullscreen SuperChat card while the HUD is hidden (Back unchanged otherwise); no minimizing; in split view a third Quick Strip button and the 醒目留言 entry switch between the chat and the SuperChat list.
* **Changed by the user**: 发弹幕 is not in the live top-right default (proposed: 弹幕开关, 弹幕设置, 发弹幕); the live quality list gets no mark on the rows above 1080p (proposed: a warning such as `可能导致电视关机`).
* **New tasks**: `M15.3` (live entries and groups) and `M15.4` (tests, device pass and docs). `M15.2` is renamed "Close a SuperChat", since minimizing is out.
* **Next**: `M15.2` and `M15.3`, each on its own branch; both touch the HUD files, so one after the other.

### [2026-11-08] Milestone M15 (Task `M15.3`): Live Entries & Groups
* **Status**: ✅ Done on its own branch; lands by pull request. Merging it publishes a release.
* **Files Changed**: `[MODIFY] lib/tv/tv_hud_actions.dart`, `lib/tv/tv_hud_groups.dart`, `lib/tv/tv_hud_menu.dart`, `lib/tv/tv_player_hud.dart`, `test/tv_player_hud_test.dart`, `docs/tv/PLAN.md`, `docs/tv/PROGRESS.md`.
* **Built** (as agreed in `M15.1`):
  * **Scopes**: every `TvHudActionId` has a `TvHudScope` (both, video or live). `resolveAction` gives nothing outside an entry's scope, the saved lists skip ids of the other kind, and the editor's `未固定` row only offers entries of its kind. The video-only entries were already hidden in live rooms by their own checks; the scope makes it one rule.
  * **New live entries**, pinnable: 切换路线 (播放), 发弹幕, 屏蔽词 and 醒目留言 (弹幕).
    * 切换路线: a TV option list over `LiveRoomController`'s public `stream` and indices, with `协议 · 格式` header rows (not focusable) and one row per codec and host (`avc (原画) · cn-….bilivideo.com`), focus starting on the current route. Choosing another calls `initLiveUrl(...)` and saves `SettingBoxKey.liveStream`, as upstream's `_showLiveStreamDialog` does; the current one changes nothing. Hidden until the room's URLs have loaded (`stream` is `late`).
    * 发弹幕: hides the HUD and calls the `onSendDanmaku` the HUD was already given (upstream's `PublishRoute` send sheet); focus comes back when it closes. Upstream's own not-signed-in toast applies.
    * 屏蔽词: upstream's `/liveDmBlockPage` (through `TvHudUpstream.openLiveDmBlock`), or the toast `账号未登录` when signed out. Upstream also lets debug builds through; the TV doesn't.
    * 醒目留言: in split view with SuperChat on, switches upstream's chat `PageView` to the SuperChat list (`醒目留言 (n)`) and back (`返回聊天`, shown active). Hidden in fullscreen, where the chat area is hidden too. The Quick Strip button and Back are `M15.2`.
  * **刷新**: 重载视频's label and editor name in a live room (`TvHudActionId.titleFor`).
  * **Title line**: under the room title, the streamer, upstream's viewer text (`N人看过`) and `高能观众(n)`, each once it has loaded, on one line.
  * **Live groups**: `TvHudGroups` has a `live` flag. A live room reads and saves `tvHudLiveTopRight` and `tvHudLiveBottom`, with the defaults top right 弹幕开关, 弹幕设置 and bottom 刷新, 画质, 切换路线, 画面比例; `显示按钮文字` is shared. A live room's groups never write `按钮在时间条上方`, and the editor there hides it; its `恢复默认` resets the live lists and says so.
  * **Long labels in lists**: a pill with an alignment (the option lists and the `⋮` menu rows, which have a bounded width) now ends a label that doesn't fit in `…`, instead of overflowing. 切换路线's hosts overflowed at a large text scale.
* **Tests** (`test/tv_player_hud_test.dart`, a `FakeLiveRoomController` and `TvPlayerHud.debugLiveRoom` for it): the scopes and the live entry list; no live entry in a video and no video entry in a live room; 切换路线's rows, headers, first focus, D-pad over the headers, choosing a route and the saved `liveStream`; hidden before the URLs load, and the current route changing nothing; 发弹幕; 屏蔽词 signed in and out; 醒目留言 switching the page and back, hidden in fullscreen and with SuperChat off; the title line; the live lists' parsing and saving; the live HUD's default groups and first focus with the video lists untouched; the editor in a live room (no `按钮在时间条上方`, live entries only, 刷新, carrying 发弹幕 into 底部 saves the live list only, `恢复默认`). The two tests that counted every pinnable entry now count a video's. The test set-up also clears `按钮在时间条上方`, the live lists and `liveStream`.
* **Verification**: TV analyze clean over the CI file list; 217 TV tests pass, with the SDK patches applied. No device run: `M15.4` has the device pass.
* **Next**: `M15.2` (closing a SuperChat), then `M15.4`.

### [2026-11-08] Milestone M15 (Task `M15.2`): Close a SuperChat, Built
* **Status**: 🔄 Built on its own branch; lands by pull request, and merging it publishes a release. The "Done when" still needs the user's try in a live room on `<physical-tv>`.
* **Files Changed**: `[MODIFY] lib/tv/tv_player_hud.dart`, `test/tv_player_hud_test.dart`, `docs/tv/PLAN.md`, `docs/tv/PROGRESS.md`.
* **Built** (as agreed in `M15.1`):
  * **Back closes a fullscreen card**: with the HUD hidden in a fullscreen live room and a SuperChat card on screen (`LiveRoomController.fsSC`), Back sets `fsSC` to `null`, as upstream's touch `×` does, and the player stays in fullscreen. Escape does the same, as on a keyboard. With no card, with the HUD shown, in split view and in videos, the keys are left alone.
  * **Why a key, not the `PopScope`**: Flutter calls every pop entry of the route when a Back is refused, and upstream's live page has its own (`PlPlayerController.onPopInvokedWithResult`), which leaves fullscreen. So the HUD takes the Back key itself before Android turns it into a pop. The press that closed a card also swallows its repeats and its release, so a held Back doesn't leave fullscreen afterwards.
  * **Quick Strip**: in split view with SuperChat on, a third icon-only button after 全屏 and 播放/暂停. It's the 醒目留言 entry from `M15.3`: `醒目留言 (n)` switches the chat area to the SuperChat list, and `返回聊天` (shown active) switches back. Not shown with SuperChat off, in videos, or before the chat area's `PageView` is attached.
* **Found while building** (unchanged): with the HUD shown in fullscreen, one Back hides the HUD and, through upstream's pop entry, also leaves fullscreen on the same press, in videos and live rooms alike. `M15.1`'s note "the first Back still closes the HUD" is true, but it isn't the only thing that press does. Not changed here.
* **Tests**: Back and Escape close a card with the HUD hidden and stay in fullscreen, and are not handled with no card; a held Back's repeats and release are swallowed, and the next press is a plain Back; Back leaves a card alone with the HUD shown, in split view and in a video; the Quick Strip's 醒目留言 button, reached with Right, switches the page and back; no button with SuperChat off or in a video. Back is sent as a key here, since that's how a remote's Back reaches the HUD.
* **Verification**: TV analyze clean over the CI file list; 222 TV tests pass, with the SDK patches applied. No device run yet. To check on `<physical-tv>`: that a Back key the HUD handles doesn't also reach Android as a Back (it shouldn't; the embedding only passes on unhandled keys), and that the card closes at once. A SuperChat only comes when someone pays for one, so this needs a busy room and some waiting.
* **Next**: the user's try on `<physical-tv>` (their go-ahead and the TV's address needed), then `M15.4`.

### [2026-11-08] Milestone M15 (Task `M15.2`): Done
* **Status**: ✅ Done. Merged to `main` (the release build runs from there).
* **Files Changed**: `[MODIFY] docs/tv/PLAN.md` (Phase 5 roadmap, M15), `docs/tv/PROGRESS.md`.
* **Device try** (`<physical-tv>`): a `-Pdev` `android-arm` build of the branch (`a4f6ba937`) was installed over `PiliPlus TV dev` with the user's go-ahead and the TV's address given in chat; nothing else was run on the TV. The user tried it in a live room and reported it works, so the "Done when" holds. Afterwards adb was disconnected and its server stopped.
* **Next**: `M15.4` (the recorded D-pad path for the live HUD, the `<vm-tv>` and `<physical-tv>` passes, docs).

### [2026-11-09] Fix: Back with the HUD shown also left fullscreen, or the page in split view
* **Status**: ✅ Fixed on its own branch; lands by pull request. Merging it publishes a release.
* **Files Changed**: `[MODIFY] lib/tv/tv_player_hud.dart`, `test/tv_player_hud_test.dart`, `docs/tv/PROGRESS.md`.
* **Found** (while building `M15.2`, and in the `M15.4` pass): with the HUD shown, the HUD's `PopScope` refuses the pop and hides the HUD, but Flutter's `ModalRoute.onPopInvokedWithResult` calls every pop entry of the route. Upstream's video and live pages register their own (`popScope` in `lib/pages/video/view.dart` and `lib/pages/live_room/view.dart`, calling `PlPlayerController.onPopInvokedWithResult`), which on a refused pop leaves fullscreen, or in split view calls `Get.back()`. So one Back with the HUD shown hid it and also left fullscreen, or left the video or live room from split view. Escape didn't, because the HUD already took it as a key.
* **Fix**: the remote's Back key is now taken by the HUD while it's shown, as Escape was, and as `M15.2` already does for a SuperChat card: it hides the HUD, and the press's repeats and release are swallowed, so Android never turns it into a pop (the `M15.2` and `M15.4` device runs showed a key the HUD handles doesn't also reach Android as a Back). `_handleSuperChatBack` became `_handleBackKey`, which covers both. With the HUD hidden, Back goes on to the route as before; Back in a dialog or panel over the HUD still closes only that, since the dialog's route takes the key. The `PopScope` stays for pops that don't come from a key.
* **Behavior now**: with the HUD shown, Back only hides it, in fullscreen and in split view, in videos and live rooms. The next Back does what it did before (leaves fullscreen, closes a SuperChat card, or leaves the page).
* **Tests**: a pop with the HUD shown reaching an upstream-style pop entry (why a key is needed); the Back key with the HUD shown in split view and fullscreen, in a live room and in a video, hiding only the HUD, never reaching the pop entry, and Back with the HUD hidden going on as before; a held Back that hid the HUD swallowing its repeats and release and leaving a SuperChat card for the next Back; Back in the `⋮` menu closing only the menu. The `M15.2` test that expected a Back key with the HUD shown to go unhandled now expects it to hide the HUD. 227 TV tests pass; TV analyze clean over the CI file list.
* **Not tried on a device yet.**
