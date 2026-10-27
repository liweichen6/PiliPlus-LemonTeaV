#!/usr/bin/env bash
# ==============================================================================
# PiliPlus-LemonTeaV: List the Decoders an Android Device Reports
# ==============================================================================
# Prints what android.media.MediaCodecList returns on the device (the list an
# app sees): every decoder, the sizes, frame rates and performance points it
# claims, and its profile/level pairs. No app install and no root needed: a
# small dex is pushed to /data/local/tmp and run with app_process.
#
# Usage:
#   ./tool/tv_codecs.sh          - video decoders
#   ./tool/tv_codecs.sh all      - video and audio decoders
#
# The device is the one adb picks; set ANDROID_SERIAL to choose one.
# Needs javac and the Android SDK (build-tools with d8, one platform).
# ==============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
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

WORK="$(mktemp -d)"
trap 'rm -rf "${WORK}"' EXIT

javac --release 17 -cp "${ANDROID_JAR}" -d "${WORK}/classes" "${SCRIPT_DIR}/tv_codecs/CodecDump.java"
"${D8}" --min-api 30 --lib "${ANDROID_JAR}" --output "${WORK}" "${WORK}"/classes/*.class

DEVICE_DEX=/data/local/tmp/tv_codecs.dex
adb push "${WORK}/classes.dex" "${DEVICE_DEX}" >/dev/null
adb shell CLASSPATH="${DEVICE_DEX}" app_process /system/bin CodecDump "${1:-}"
adb shell rm -f "${DEVICE_DEX}"
