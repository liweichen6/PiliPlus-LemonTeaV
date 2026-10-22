#!/usr/bin/env bash
# ==============================================================================
# PiliPlus-LemonTeaV: Idempotent Flutter SDK & pub-cache Patch Helper
# ==============================================================================
# Usage:
#   ./tool/tv_patch.sh apply   - Apply PiliPlus Android + TV patches
#   ./tool/tv_patch.sh revert  - Revert PiliPlus Android + TV patches
#   ./tool/tv_patch.sh status  - Check whether patches are applied
# ==============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

ACTION="${1:-apply}"

# 1. Resolve FLUTTER_ROOT
if [[ -z "${FLUTTER_ROOT:-}" ]]; then
  if command -v flutter >/dev/null 2>&1; then
    FLUTTER_BIN="$(command -v flutter)"
  elif [[ -x "${HOME}/.local/share/flutter/bin/flutter" ]]; then
    FLUTTER_BIN="${HOME}/.local/share/flutter/bin/flutter"
  else
    echo "Error: flutter binary not found in PATH and FLUTTER_ROOT is not set." >&2
    exit 1
  fi
  # Resolve symlinks to find SDK root
  FLUTTER_BIN_REAL="$(python3 -c 'import os,sys; print(os.path.realpath(sys.argv[1]))' "${FLUTTER_BIN}")"
  FLUTTER_ROOT="$(cd "$(dirname "${FLUTTER_BIN_REAL}")/.." && pwd)"
fi

# 2. Resolve PUB_CACHE and material_ui directory
PUB_CACHE_DIR="${PUB_CACHE:-${HOME}/.pub-cache}"
MATERIAL_UI_DIR="$(find "${PUB_CACHE_DIR}/hosted/pub.dev" -maxdepth 1 -type d -name 'material_ui-*' 2>/dev/null | sort -V | tail -n 1 || true)"

if [[ -z "${MATERIAL_UI_DIR}" || ! -d "${MATERIAL_UI_DIR}" ]]; then
  echo "Error: material_ui-* not found under ${PUB_CACHE_DIR}/hosted/pub.dev. Run 'flutter pub get' first." >&2
  exit 1
fi

FLUTTER_PATCHES=(
  "lib/scripts/modal_barrier.patch"
  "lib/scripts/text_selection.patch"
  "lib/scripts/mouse_cursor.patch"
  "lib/scripts/image_anim.patch"
  "lib/scripts/layout_builder.patch"
  "lib/scripts/navigation_drawer.patch"
  "lib/scripts/popup_menu.patch"
  "lib/scripts/fab.patch"
  "lib/scripts/null_safety_for_selectable_region.patch"
  "lib/scripts/selectable_region.patch"
  "lib/scripts/editable_text.patch"
  "lib/scripts/text_field.patch"
  "lib/scripts/scroll_position.patch"
  "lib/scripts/scrollable.patch"
  "lib/scripts/scrollable_gesture.patch"
  "lib/scripts/draggable_scrollable_sheet.patch"
  "lib/scripts/scaffold.patch"
  "lib/scripts/text.patch"
  "lib/scripts/text_painter.patch"
  "lib/scripts/sliver.patch"
  "lib/scripts/refresh_indicator.patch"
  "lib/scripts/double_tap_gesture.patch"
  "lib/scripts/bottom_sheet_android.patch"
  "lib/scripts/scroll_view.patch"
  "lib/scripts/navigator.patch"
  "lib/scripts/tv_gesture_detector.patch"
  "lib/scripts/tv_radio_group.patch"
  "lib/scripts/tv_ink_well.patch"
)

MATERIAL_PATCHES=(
  "lib/scripts/material/modal_barrier_material.patch"
  "lib/scripts/material/navigation_drawer.patch"
  "lib/scripts/material/popup_menu.patch"
  "lib/scripts/material/fab.patch"
  "lib/scripts/material/text_field.patch"
  "lib/scripts/material/scaffold.patch"
  "lib/scripts/material/refresh_indicator.patch"
  "lib/scripts/material/tabs.patch"
  "lib/scripts/material/bottom_sheet_android.patch"
  "lib/scripts/material/tv_ink_well.patch"
)

apply_one() {
  local target_dir="$1"
  local patch_rel="$2"
  local patch_file="${REPO_ROOT}/${patch_rel}"

  if git -C "${target_dir}" apply --reverse --check "${patch_file}" >/dev/null 2>&1; then
    echo "[SKIP] ${patch_rel} (already applied)"
  elif git -C "${target_dir}" apply --check "${patch_file}" >/dev/null 2>&1; then
    git -C "${target_dir}" apply "${patch_file}"
    echo "[APPLY] ${patch_rel}"
  else
    echo "[ERROR] ${patch_rel} cannot be cleanly applied or reversed in ${target_dir}" >&2
    exit 1
  fi
}

revert_one() {
  local target_dir="$1"
  local patch_rel="$2"
  local patch_file="${REPO_ROOT}/${patch_rel}"

  if git -C "${target_dir}" apply --reverse --check "${patch_file}" >/dev/null 2>&1; then
    git -C "${target_dir}" apply --reverse "${patch_file}"
    echo "[REVERT] ${patch_rel}"
  elif git -C "${target_dir}" apply --check "${patch_file}" >/dev/null 2>&1; then
    echo "[SKIP] ${patch_rel} (not currently applied)"
  else
    echo "[ERROR] ${patch_rel} is in an inconsistent state in ${target_dir}" >&2
    exit 1
  fi
}

status_one() {
  local target_dir="$1"
  local patch_rel="$2"
  local patch_file="${REPO_ROOT}/${patch_rel}"

  if git -C "${target_dir}" apply --reverse --check "${patch_file}" >/dev/null 2>&1; then
    echo "[APPLIED]     ${patch_rel}"
  elif git -C "${target_dir}" apply --check "${patch_file}" >/dev/null 2>&1; then
    echo "[NOT APPLIED] ${patch_rel}"
  else
    echo "[CONFLICT]    ${patch_rel}"
  fi
}

case "${ACTION}" in
  apply)
    for p in "${FLUTTER_PATCHES[@]}"; do
      apply_one "${FLUTTER_ROOT}" "${p}"
    done
    for p in "${MATERIAL_PATCHES[@]}"; do
      apply_one "${MATERIAL_UI_DIR}" "${p}"
    done
    ;;
  revert)
    for (( idx=${#FLUTTER_PATCHES[@]}-1 ; idx>=0 ; idx-- )); do
      revert_one "${FLUTTER_ROOT}" "${FLUTTER_PATCHES[idx]}"
    done
    for (( idx=${#MATERIAL_PATCHES[@]}-1 ; idx>=0 ; idx-- )); do
      revert_one "${MATERIAL_UI_DIR}" "${MATERIAL_PATCHES[idx]}"
    done
    ;;
  status)
    for p in "${FLUTTER_PATCHES[@]}"; do
      status_one "${FLUTTER_ROOT}" "${p}"
    done
    for p in "${MATERIAL_PATCHES[@]}"; do
      status_one "${MATERIAL_UI_DIR}" "${p}"
    done
    ;;
  *)
    echo "Usage: $0 {apply|revert|status}" >&2
    exit 1
    ;;
esac
