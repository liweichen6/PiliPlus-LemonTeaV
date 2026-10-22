#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

if [[ -z "${FLUTTER_ROOT:-}" ]]; then
  if command -v flutter >/dev/null 2>&1; then
    FLUTTER_BIN="$(command -v flutter)"
    FLUTTER_ROOT="$(cd "$(dirname "$FLUTTER_BIN")/.." && pwd)"
  elif [[ -d "$HOME/.local/share/flutter" ]]; then
    FLUTTER_ROOT="$HOME/.local/share/flutter"
  else
    echo "Error: FLUTTER_ROOT not set and flutter binary not found in PATH." >&2
    exit 1
  fi
fi

PUB_CACHE_DIR="${PUB_CACHE:-$HOME/.pub-cache}"
MATERIAL_UI_DIR="$(find "$PUB_CACHE_DIR/hosted/pub.dev" -maxdepth 1 -type d -name 'material_ui-*' | sort | tail -n 1)"

if [[ -z "$MATERIAL_UI_DIR" || ! -d "$MATERIAL_UI_DIR" ]]; then
  echo "Error: material_ui-* not found under $PUB_CACHE_DIR/hosted/pub.dev" >&2
  exit 1
fi

SDK_PATCHES=(
  "lib/scripts/tv_gesture_detector.patch"
  "lib/scripts/tv_radio_group.patch"
  "lib/scripts/tv_ink_well.patch"
)

MATERIAL_PATCHES=(
  "lib/scripts/material/tv_ink_well.patch"
)

apply_patch() {
  local target_dir="$1"
  local patch_rel="$2"
  local patch_path="$REPO_ROOT/$patch_rel"

  if (cd "$target_dir" && git apply --reverse --check "$patch_path" >/dev/null 2>&1); then
    echo "[SKIP] $patch_rel (already applied)"
  elif (cd "$target_dir" && git apply --check "$patch_path" >/dev/null 2>&1); then
    (cd "$target_dir" && git apply "$patch_path")
    echo "[APPLY] $patch_rel"
  else
    echo "[ERROR] Cannot cleanly apply $patch_rel in $target_dir" >&2
    return 1
  fi
}

revert_patch() {
  local target_dir="$1"
  local patch_rel="$2"
  local patch_path="$REPO_ROOT/$patch_rel"

  if (cd "$target_dir" && git apply --reverse --check "$patch_path" >/dev/null 2>&1); then
    (cd "$target_dir" && git apply --reverse "$patch_path")
    echo "[REVERT] $patch_rel"
  elif (cd "$target_dir" && git apply --check "$patch_path" >/dev/null 2>&1); then
    echo "[SKIP] $patch_rel (not currently applied)"
  else
    echo "[ERROR] Patch state ambiguous for $patch_rel in $target_dir" >&2
    return 1
  fi
}

status_patch() {
  local target_dir="$1"
  local patch_rel="$2"
  local patch_path="$REPO_ROOT/$patch_rel"

  if (cd "$target_dir" && git apply --reverse --check "$patch_path" >/dev/null 2>&1); then
    echo "[APPLIED]     $patch_rel"
  elif (cd "$target_dir" && git apply --check "$patch_path" >/dev/null 2>&1); then
    echo "[NOT APPLIED] $patch_rel"
  else
    echo "[CONFLICT]    $patch_rel"
    return 1
  fi
}

ACTION="${1:-status}"

case "$ACTION" in
  apply)
    for p in "${SDK_PATCHES[@]}"; do
      apply_patch "$FLUTTER_ROOT" "$p"
    done
    for p in "${MATERIAL_PATCHES[@]}"; do
      apply_patch "$MATERIAL_UI_DIR" "$p"
    done
    ;;
  revert)
    for (( idx=${#SDK_PATCHES[@]}-1 ; idx>=0 ; idx-- )); do
      revert_patch "$FLUTTER_ROOT" "${SDK_PATCHES[idx]}"
    done
    for (( idx=${#MATERIAL_PATCHES[@]}-1 ; idx>=0 ; idx-- )); do
      revert_patch "$MATERIAL_UI_DIR" "${MATERIAL_PATCHES[idx]}"
    done
    ;;
  status)
    for p in "${SDK_PATCHES[@]}"; do
      status_patch "$FLUTTER_ROOT" "$p"
    done
    for p in "${MATERIAL_PATCHES[@]}"; do
      status_patch "$MATERIAL_UI_DIR" "$p"
    done
    ;;
  *)
    echo "Usage: $0 {apply|revert|status}" >&2
    exit 1
    ;;
esac
