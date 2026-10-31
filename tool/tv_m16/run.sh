#!/usr/bin/env bash
# ==============================================================================
# PiliPlus-LemonTeaV: One Run of the Dev App, Guarded (M16)
# ==============================================================================
# Plays URL in `PiliPlus TV dev`, recorded by tool/tv_m12/run.sh. See
# docs/tv/PLAYBACK_PARAMETERS.md.
#
#   ./tool/tv_m16/run.sh NAME SECS URL [plane|gpuguard|texture]
#
#   plane     for a run on the video plane: stops the dev app on hwRender:0, on
#             Detile past the start burst, or on a 4K layer composed by the GPU
#   gpuguard  for a run on the texture that must stay off the 4K GPU path:
#             stops the dev app on gdec:1
#   texture   no guard
#
# It only ever stops the dev app. Needs ANDROID_SERIAL and M12_RUNS.
# ==============================================================================
set -uo pipefail
: "${ANDROID_SERIAL:?set ANDROID_SERIAL}" "${M12_RUNS:?set M12_RUNS}"

NAME="$1"; SECS="$2"; URL="$3"; MODE="${4:-plane}"
PKG=com.lemontea.piliplus.tv.dev
ACT=com.example.piliplus.MainActivity
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

GUARD_LOG="${M12_RUNS}/m16-guard-${NAME}.txt"
: > "${GUARD_LOG}"
GUARD_PID=""
if [[ "${MODE}" == plane || "${MODE}" == gpuguard ]]; then
  (
    detile=0
    adb logcat -b main -v threadtime -T 1 2>/dev/null \
      | grep --line-buffered -E 'hwRender:[0-9]|Detile' \
      | while IFS= read -r line; do
          if [[ "${line}" == *Detile* ]]; then
            # The video plane logs one burst of 40-52 lines at start; the GPU
            # path logs about 1,000 a second.
            detile=$((detile + 1))
            if (( detile == 200 )); then
              adb shell am force-stop "${PKG}"
              echo "GUARD: Detile past the start burst, force-stopped ${PKG}" | tee -a "${GUARD_LOG}"
            fi
            continue
          fi
          echo "${line}" >> "${GUARD_LOG}"
          # plane: anything off the plane. gpuguard: a texture run may play, but
          # never the 4K GPU path.
          bad=no
          [[ "${MODE}" == plane && "${line}" == *hwRender:0* ]] && bad=yes
          [[ "${MODE}" == gpuguard && "${line}" == *"gdec:1"* ]] && bad=yes
          if [[ "${bad}" == yes ]]; then
            # The launcher's own preview video logs hwRender:0 too, so only
            # act while the dev app is on top.
            top="$(adb shell dumpsys activity activities 2>/dev/null | grep -m 1 topResumedActivity)"
            if [[ "${top}" == *"${PKG}"* ]]; then
              adb shell am force-stop "${PKG}"
              echo "GUARD: ${line##*bufferQueue}, force-stopped ${PKG}" | tee -a "${GUARD_LOG}"
            else
              echo "GUARD: hwRender:0 from another app, ignored" | tee -a "${GUARD_LOG}"
            fi
          fi
        done
  ) &
  GUARD_PID=$!
fi
COMP_PID=""
if [[ "${MODE}" == plane ]]; then
  # A 4K video layer must stay DEVICE: CLIENT means the GPU is composing it.
  (
    while sleep 20; do
      row="$(adb shell dumpsys SurfaceFlinger 2>/dev/null \
        | grep -E '^ SurfaceView.*BLAST' -A1 | grep -E ' 3840\.0 +2160\.0' | tail -n 1)"
      [[ -z "${row}" ]] && continue
      echo "$(date +%H:%M:%S) ${row}" | sed -E 's/ +/ /g' >> "${GUARD_LOG}"
      if [[ "${row}" == *CLIENT* ]]; then
        adb shell am force-stop "${PKG}"
        echo "GUARD: 4K layer on CLIENT, force-stopped ${PKG}" | tee -a "${GUARD_LOG}"
      fi
    done
  ) &
  COMP_PID=$!
fi
cleanup() {
  [[ -n "${GUARD_PID}" ]] && pkill -P "${GUARD_PID}" 2>/dev/null
  [[ -n "${GUARD_PID}" ]] && kill "${GUARD_PID}" 2>/dev/null
  [[ -n "${COMP_PID}" ]] && pkill -P "${COMP_PID}" 2>/dev/null
  [[ -n "${COMP_PID}" ]] && kill "${COMP_PID}" 2>/dev/null
}
trap cleanup EXIT

"${HERE}/../tv_m12/run.sh" "${NAME}" "${SECS}" shell \
  "am start -a android.intent.action.VIEW -d '${URL}' -n ${PKG}/${ACT}" \
  "am force-stop ${PKG}"
