#!/usr/bin/env bash
# ==============================================================================
# PiliPlus-LemonTeaV: Stress the Stop Path on the Video Plane (M16)
# ==============================================================================
# Does ending a run bring back the media service hang (docs/tv/PLAYBACK_PARAMETERS.md)?
# Runs CYCLES short runs, each ended by force-stop, and asks media.player for a
# dump after each. A timeout there means the hang is back: it stops at once, and
# the TV needs a restart. Plays at the dev app's stored quality, which can be
# 4K60: ask before the first 4K60 run of a session.
#
#   URL=... CYCLES=8 ./tool/tv_m16/stress.sh
# ==============================================================================
set -uo pipefail
: "${ANDROID_SERIAL:?}" "${M12_RUNS:?}"
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TMP="$(mktemp -d)"
trap 'rm -rf "${TMP}"' EXIT
DIR=/sdcard/Android/data/com.lemontea.piliplus.tv.dev/files
PKG=com.lemontea.piliplus.tv.dev
URL="${URL:?set URL to a video page}"
CYCLES="${CYCLES:-8}"
SECS="${SECS:-30}"
EXTRA="${EXTRA:-mpv.vd-queue-enable=yes\nmpv.vd-queue-max-samples=4\n}"
TAG="${TAG:-j}"

healthy() {
  local t0 t1 out
  t0=$(perl -MTime::HiRes=time -e 'print time')
  out="$(adb shell 'dumpsys -t 6 media.player 2>&1 | grep -c TIMEOUT')"
  t1=$(perl -MTime::HiRes=time -e 'print time')
  perl -e "printf \"%.2f\", $t1-$t0"
  [[ "${out//[$'\r\n ']/}" == 0 ]]
}

printf 'stats=1\ncodecs=AV1,AVC\n%b' "${EXTRA}" > "${TMP}/m16.conf"
adb push "${TMP}/m16.conf" "${DIR}/m16.conf" >/dev/null 2>&1
for i in $(seq 1 "${CYCLES}"); do
  name="m16-${TAG}-${i}"
  adb shell input keyevent KEYCODE_WAKEUP
  bash "${HERE}/run.sh" "${name}" "${SECS}" "${URL}" plane 2>&1 | grep -E '^GUARD|: lost|: rebooted'
  r="$(ls -td "${M12_RUNS}"/*"${name}" | head -n 1)"
  codec="$(grep -oE 'c2\.mtk\.[a-z0-9]+\.decoder' "${r}/logcat.txt" | sort -u | tr '\n' ' ')"
  pos="$(grep -E '\[m16\] stats' "${r}/logcat.txt" | tail -n 1 | grep -oE 'pos=[0-9.]+|size=[0-9x]+|drop=[0-9]+' | head -3 | tr '\n' ' ')"
  if ms="$(healthy)"; then
    echo "cycle ${i}: ok, media.player ${ms} s, ${codec}${pos}"
  else
    echo "cycle ${i}: HANG, media.player ${ms} s, ${codec}${pos}"
    echo stress-hang
    exit 1
  fi
done
echo stress-done
