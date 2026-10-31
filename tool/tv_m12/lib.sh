# shellcheck shell=bash
# ==============================================================================
# PiliPlus-LemonTeaV: Shared Settings for the M12 Crash-Debug Tools
# ==============================================================================
# Sourced by the scripts in tool/tv_m12/. Everything machine- or network-
# specific comes from the environment, so nothing private lands in the repo:
#
#   ANDROID_SERIAL  the TV's adb address (wireless debugging; changes after a
#                   reboot)
#   M12_MEDIA       folder with the test videos (originals/ and variants/)
#   M12_RUNS        folder for run output (logs, samples, panic evidence)
#
# See docs/tv/M12_CRASH_DEBUG.md.
# ==============================================================================

set -euo pipefail

M12_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DEVICE_DIR=/data/local/tmp/m12
DEVICE_MEDIA="${DEVICE_DIR}/media"

m12_require() {
  local name
  for name in "$@"; do
    if [[ -z "${!name:-}" ]]; then
      echo "Error: set ${name} (see tool/tv_m12/lib.sh)." >&2
      exit 1
    fi
  done
}

m12_sdk() {
  SDK="${ANDROID_HOME:-${ANDROID_SDK_ROOT:-}}"
  if [[ -z "${SDK}" ]]; then
    for candidate in "${HOME}/Library/Android/sdk" "${HOME}/Android/Sdk"; do
      [[ -d "${candidate}" ]] && SDK="${candidate}" && break
    done
  fi
  if [[ -z "${SDK}" || ! -d "${SDK}" ]]; then
    echo "Error: Android SDK not found; set ANDROID_HOME." >&2
    exit 1
  fi
  D8="$(ls -d "${SDK}"/build-tools/*/d8 2>/dev/null | sort -V | tail -n 1 || true)"
  ANDROID_JAR="$(ls -d "${SDK}"/platforms/android-*/android.jar 2>/dev/null | sort -V | tail -n 1 || true)"
  if [[ -z "${D8}" || -z "${ANDROID_JAR}" ]]; then
    echo "Error: d8 (build-tools) or android.jar (platforms) missing under ${SDK}." >&2
    exit 1
  fi
}

# Seconds since the TV booted, or nothing when it doesn't answer.
m12_uptime() {
  timeout 5 adb shell 'read up rest < /proc/uptime; echo ${up%.*}' 2>/dev/null | tr -d '\r' || true
}
