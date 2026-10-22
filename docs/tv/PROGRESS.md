# PiliPlus-LemonTeaV: TV Porting Progress & Change Log

This document tracks the task-by-task execution progress of [`docs/tv/PLAN.md`](./PLAN.md). Every completed task updates this file and is committed atomically.

> **Privacy & Sanitization Rule**: Never record LAN IP addresses/ports, local filesystem absolute paths, file-scheme URLs, or any other personal information in this log or commit messages. Use relative paths and generic placeholders (`<vm-tv>`, `<physical-tv>`).

---

## Task Status Matrix

| Milestone | Epic | Task ID | Task Title | Status | Commit |
| :--- | :--- | :--- | :--- | :--- | :--- |
| **M0: Docs** | Epic 0.1 | `0.1.1` | Create `docs/tv/` Planning Suite | ✅ Done | *(this commit)* |
| **M1: Platform** | Epic 1.1 | `1.1.1` | Implement `TvBridge.kt` & Leanback Manifest | ⏸️ Pending Review | — |
| **M1: Platform** | Epic 1.2 | `1.2.1` | Create `lib/tv/tv_platform.dart` (Hive seeding + Soft-keyboard gate) | ⏸️ Pending Review | — |
| **M1: Platform** | Epic 1.2 | `1.2.2` | Support Wired Ethernet in `ConnectivityUtils.isWiFi` | ⏸️ Pending Review | — |
| **M2: Focus** | Epic 2.1 | `2.1.1` | Implement `lib/tv/tv_navigation.dart` (`TvFocusTraversalPolicy` + `RenderBox` introspection) | ⏸️ Pending Review | — |
| **M2: Focus** | Epic 2.2 | `2.2.1` | Add `TvNavigationObserver` (Focus restore + Login QR auto-tab) | ⏸️ Pending Review | — |
| **M2: Focus** | Epic 2.2 | `2.2.2` | Wire `TvPlatform` & `TvNavigation` into `lib/main.dart` | ⏸️ Pending Review | — |
| **M3: Patches** | Epic 3.1 | `3.1.1` | Create `lib/scripts/tv_gesture_detector.patch` | ⏸️ Pending Review | — |
| **M3: Patches** | Epic 3.1 | `3.1.2` | Create `lib/scripts/tv_radio_group.patch` | ⏸️ Pending Review | — |
| **M3: Patches** | Epic 3.1 | `3.1.3` | Create `lib/scripts/material/tv_ink_well.patch` & `lib/scripts/tv_ink_well.patch` | ⏸️ Pending Review | — |
| **M3: Patches** | Epic 3.2 | `3.2.1` | Register TV patches in `patch.ps1` and add `tool/tv_patch.sh` | ⏸️ Pending Review | — |
| **M4: Player HUD** | Epic 4.1 | `4.1.1` | Implement `lib/tv/tv_player_hud.dart` with controller auto-discovery | ⏸️ Pending Review | — |
| **M4: Player HUD** | Epic 4.1 | `4.1.2` | Add 4-line `TvPlayerHud` hook in `player_focus.dart` | ⏸️ Pending Review | — |
| **M5: CI & Verify** | Epic 5.1 | `5.1.1` | Update `.github/workflows/` to sync `lemonteaau/PiliPlus` & build Android APKs | ⏸️ Pending Review | — |
| **M5: CI & Verify** | Epic 5.2 | `5.2.1` | Add TV widget tests (`test/tv_navigation_test.dart`) & verify full build | ⏸️ Pending Review | — |

---

## Detailed Task Log

### [2026-10-21] Task 0.1.1: Create `docs/tv/` Planning Suite
* **Status**: ✅ Completed (Holding code implementation for manual review)
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
