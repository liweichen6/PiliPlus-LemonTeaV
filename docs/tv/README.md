# PiliPlus-LemonTeaV: Decoupled TV Control Layer Documentation

This directory (`docs/tv/`) contains the architectural design, milestone/epic/task implementation plan, and live progress log for porting **PiliPlus-LemonTeaV** to Android TV using a **Three-Tier Decoupled TV Control Layer**.

## Design Goals

1. **Near-Zero Upstream Merge Conflicts**: Keep upstream touches to an absolute minimum (**only 3 Dart files in `lib/`, `< 15 lines` total**) so daily automated merges from `lemonteaau/PiliPlus` (which in turn syncs with `bggRGjQaUbCoE/PiliPlus`) run cleanly without manual conflict resolution.
2. **10-Foot D-Pad First Experience**: Provide spatial 2D directional focus traversal (`TvFocusTraversalPolicy`), visible high-contrast focus highlights, automatic scroll-into-view, closed-loop escape from scrollable dialogs/lists, and a dedicated TV Player HUD (`TvPlayerHud`).
3. **Framework-Level Widget Adaptation (`patch.ps1`)**: Fix Flutter/Material D-pad hostility (`GestureDetector` lacking focus, `RadioGroup` trapping arrow keys, `InkResponse` missing keyboard activation for `onTapDown`/`onTapUp` hold-to-triple-like and `onTapUp` coordinate menus) at the SDK/package patch layer rather than scattering edits across 40+ business pages.
4. **Native Android TV System Keyboard & QR Login**: Use the native Android TV soft keyboard on explicit `OK`/`Enter` activation (without auto-popping the keyboard during directional focus traversal) and automatically switch `LoginPage` to the QR-code login tab via `TvNavigationObserver`.

---

## Documentation Index

| Document | Purpose |
| :--- | :--- |
| [**ARCHITECTURE.md**](./ARCHITECTURE.md) | Deep dive into the Three-Tier Decoupled TV Control Layer (`lib/tv/*`, `lib/scripts/tv_*.patch`, and the 3 micro-hooks in `lib/`). |
| [**PLAN.md**](./PLAN.md) | Complete implementation roadmap organized by **Milestones → Epics → Tasks**, with exact files, verification criteria, and commit rules. |
| [**PROGRESS.md**](./PROGRESS.md) | Task-by-task execution log, commit hashes, verification results, and change notes updated after every task. |
