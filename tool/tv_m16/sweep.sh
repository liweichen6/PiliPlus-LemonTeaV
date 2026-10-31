#!/usr/bin/env bash
# ==============================================================================
# PiliPlus-LemonTeaV: Compare mpv Options on the Video Plane (M16)
# ==============================================================================
# Each NAME=CONF plays URL on a fresh start, and prints mpv's drop rate and the
# cadence of the frames that reach the video layer. CONF lines use the logging
# build's config file: `mpv.OPTION=VALUE`, `codecs=AV1,AVC`, separated by \n.
#
#   SECS=120 ./tool/tv_m16/sweep.sh URL base= 'queue4=mpv.vd-queue-enable=yes\nmpv.vd-queue-max-samples=4\n'
#
# Needs the logging build (logging.patch), ANDROID_SERIAL and M12_RUNS. The
# stream must be above 1080p for the numbers to count.
# ==============================================================================
set -uo pipefail
: "${ANDROID_SERIAL:?}" "${M12_RUNS:?}"
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TMP="$(mktemp -d)"
trap 'rm -rf "${TMP}"' EXIT
PKG=com.lemontea.piliplus.tv.dev
DIR="/sdcard/Android/data/${PKG}/files"
SECS="${SECS:-120}"
URL="$1"; shift

run() {
  local name="$1" extra="$2" full="m16-sweep-$1" i out
  printf 'stats=1\n%b' "${extra}" > "${TMP}/m16.conf"
  adb push "${TMP}/m16.conf" "${DIR}/m16.conf" >/dev/null 2>&1
  adb shell am force-stop "${PKG}"
  sleep 2
  out="${TMP}/cadence-${name}.txt"; : > "${out}"
  (
    sleep 45
    for i in 1 2 3 4 5 6 7 8; do
      layer="$(adb shell dumpsys SurfaceFlinger --list 2>/dev/null | grep -E 'SurfaceView.*BLAST' | tail -n 1 | tr -d '\r')"
      adb shell "dumpsys SurfaceFlinger --latency '${layer}'" 2>/dev/null | python3 -I "${HERE}/cadence.py" >> "${out}"
      sleep 8
    done
  ) &
  local sampler=$!
  bash "${HERE}/run.sh" "${full}" "${SECS}" "${URL}" plane 2>&1 | grep -E '^GUARD|: lost|: rebooted'
  wait "${sampler}" 2>/dev/null
  python3 -I "${HERE}/sweep_summary.py" "${name}" "$(ls -td "${M12_RUNS}"/*"${full}" | head -n 1)/logcat.txt" "${out}"
}

for arg in "$@"; do
  run "${arg%%=*}" "${arg#*=}"
done
