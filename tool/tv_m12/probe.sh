#!/usr/bin/env bash
# ==============================================================================
# PiliPlus-LemonTeaV: Build and Push the M12 MediaCodec Harness and Media
# ==============================================================================
# Compiles CodecProbe.java into a dex and pushes it to the TV's work folder
# (/data/local/tmp/m12), where run.sh starts it with app_process. With file
# names, also pushes those videos from ${M12_MEDIA} (originals/ or variants/).
#
# Usage:
#   ./tool/tv_m12/probe.sh                 build and push the harness
#   ./tool/tv_m12/probe.sh V-AVC60 M2...   also push these videos
#   ./tool/tv_m12/probe.sh --clean         remove the work folder from the TV
# ==============================================================================

source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"
m12_require ANDROID_SERIAL

if [[ "${1:-}" == --clean ]]; then
  adb shell rm -rf "${DEVICE_DIR}"
  echo "removed ${DEVICE_DIR} from the TV"
  exit 0
fi

m12_sdk
WORK="$(mktemp -d)"
trap 'rm -rf "${WORK}"' EXIT
javac --release 17 -cp "${ANDROID_JAR}" -d "${WORK}/classes" "${M12_DIR}/CodecProbe.java"
"${D8}" --min-api 30 --lib "${ANDROID_JAR}" --output "${WORK}" "${WORK}"/classes/*.class
adb shell mkdir -p "${DEVICE_MEDIA}"
adb push "${WORK}/classes.dex" "${DEVICE_DIR}/probe.dex" >/dev/null
echo "pushed the harness"

for id in "$@"; do
  m12_require M12_MEDIA
  src="$(ls "${M12_MEDIA}"/variants/"${id}".mp4 "${M12_MEDIA}"/originals/"${id}"_*.mp4 2>/dev/null | head -n 1 || true)"
  if [[ -z "${src}" ]]; then
    echo "Error: no video ${id} under ${M12_MEDIA}." >&2
    exit 1
  fi
  adb push "${src}" "${DEVICE_MEDIA}/${id}.mp4" >/dev/null
  echo "pushed ${id}"
done
adb shell df -h /data | tail -n 1
